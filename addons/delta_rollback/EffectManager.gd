extends Node

# Visual effects that the simulation starts (a poof where a collectible
# bounces...) and that nothing in the game reads: plain nodes, outside the
# rollback state, rather than network nodes spawned through SpawnManager,
# which saves, loads and re-spawns them in every rollback.
#
# A rollback re-simulates the ticks that started them. spawn() for an effect
# already started on that tick, with the same key and arguments, keeps it going
# rather than starting it again; the effects of re-simulated ticks that no
# longer start are ended once the rollback is done (a misprediction), as a load
# despawns a network node.
#
# Sounds (play_sound(), for SyncManager.play_sound()) are kept the same way,
# with their own rules, as the SoundManager this replaces had them: played at
# once, during the tick; the first play of an identifier on a tick wins (they
# pick their stream at random); not cut when a rollback no longer plays them.
#
# end_by_key() asks an effect to end (a firefly once its collectible is picked
# up), the same way: asked again on the same tick by a re-simulation, it
# stands; no longer asked, the effect resumes as if never asked.
#
# They show when a network node spawned on the same tick would: with
# interpolation, the display is a tick behind, and SpawnManager's backward load
# takes a node spawned on the last tick out of the tree until the next tick.
#
# An effect scene implements:
#   _effect_spawn(args...)  called when it shows;
#   _effect_ending()        when asked to end (end_by_key()), if it can be;
#   _effect_resume()        when that is undone;
#   _effect_end()           when it ends, if anything is to stop then;
# and calls SyncManager.end_effect(self) once over. It is then taken out of the
# tree and kept, to be reused under the same parent: _effect_spawn() restarts
# whatever calls end_effect() (a timer...), or _effect_end() stops it, so that a
# call meant for an effect already over doesn't end the next one (a timer out
# of the tree pauses, and resumes with the node).

var SyncManager

# {tick: {key: Entry}}, for the ticks a rollback can still go back to.
var _entries := {}
# {tick: {key: Entry}}: the ends asked, for the same ticks.
var _end_requests := {}
# {key: Entry}: the last effect started under each key, while not over.
var _active := {}
# Spawned on the last tick, to show at the next.
var _pending := []
# During a rollback: the first re-simulated tick, and the starts and ends
# asked again since.
var _rollback_from_tick := -1
var _confirmed := {}
var _confirmed_ends := {}
# {parent instance id + scene path: [nodes out of the tree]}, and the parent of
# each pool: a pool whose parent is freed is freed too.
var _pools := {}
var _pool_parents := {}
# {scene path: [nodes instanced in advance, outside the tree]}
var _prewarmed := {}
var _counter := 0
const DEFAULT_SOUND_BUS_SETTING := 'network/rollback/sound_manager/default_sound_bus'
var default_bus := "Master"
# Audio players done playing, for reuse: [global ones, positional ones].
var _sound_pools := [[], []]
# For perf summaries: how many show now and at most, how many were shown,
# reused, ended by a rollback, asked to end, and had that undone.
var stats := {showing = 0, max_showing = 0, shown = 0, reused = 0, ended_by_rollback = 0, ends_asked = 0, ends_undone = 0, sounds = 0}

class Entry:
	var tick: int
	var key: String
	var parent: Node
	var scene: PackedScene
	var args: Array
	var args_hash: int
	var node = null
	var ended := false
	# The tick of the end asked (end_by_key()), -1 for none.
	var ending_tick := -1
	# A sound: neither ended nor forgotten by a rollback that no longer plays it.
	var keep := false

func _ready() -> void:
	if ProjectSettings.has_setting(DEFAULT_SOUND_BUS_SETTING):
		default_bus = ProjectSettings.get_setting(DEFAULT_SOUND_BUS_SETTING)

func reset_stats() -> void:
	for key in stats:
		stats[key] = 0

func setup_effect_manager(p_sync_manager) -> void:
	SyncManager = p_sync_manager
	SyncManager.tick_retired.connect(_on_tick_retired)
	SyncManager.sync_stopped.connect(_on_sync_stopped)

# Instances made now rather than at a first spawn, which would hitch.
func prewarm(scene: PackedScene, count: int) -> void:
	var nodes: Array = _prewarmed.get(scene.resource_path, [])
	for i in count:
		nodes.append(scene.instantiate())
	_prewarmed[scene.resource_path] = nodes

func spawn(key: String, parent: Node, scene: PackedScene, args: Array) -> void:
	var tick: int = SyncManager.current_tick
	var args_hash := args.hash()
	var at_tick: Dictionary = _entries.get(tick, {})
	var existing: Entry = at_tick.get(key)
	if existing != null:
		if existing.args_hash == args_hash and existing.parent == parent and existing.scene == scene:
			if _rollback_from_tick >= 0:
				_confirmed[existing] = true
			return
		_end_entry(existing)
	var entry := Entry.new()
	entry.tick = tick
	entry.key = key
	entry.parent = parent
	entry.scene = scene
	entry.args = args.duplicate()
	entry.args_hash = args_hash
	at_tick[key] = entry
	_entries[tick] = at_tick
	_active[key] = entry
	if _rollback_from_tick >= 0:
		_confirmed[entry] = true
	if SyncManager._in_rollback or not SyncManager._interpolating:
		_show(entry)
	else:
		_pending.append(entry)

# info: position (positional if given), volume_db, pitch_scale, bus.
func play_sound(identifier: String, sound: AudioStream, info: Dictionary = {}) -> void:
	var tick: int = SyncManager.current_tick
	# Apart from the effects' keys.
	var key := "sound:" + identifier
	var at_tick: Dictionary = _entries.get(tick, {})
	if at_tick.has(key):
		return
	var entry := Entry.new()
	entry.tick = tick
	entry.key = key
	entry.keep = true
	entry.ended = true
	at_tick[key] = entry
	_entries[tick] = at_tick
	
	var positional := info.has("position")
	var pool: Array = _sound_pools[1 if positional else 0]
	var node = null
	while node == null and not pool.is_empty():
		var candidate = pool.pop_back()
		if is_instance_valid(candidate):
			node = candidate
	if node == null:
		node = AudioStreamPlayer2D.new() if positional else AudioStreamPlayer.new()
		_counter += 1
		node.name = "Sound%d" % _counter
		add_child(node)
		node.finished.connect(_on_sound_finished.bind(node, positional))
	node.stream = sound
	node.volume_db = info.get("volume_db", 0.0)
	node.pitch_scale = info.get("pitch_scale", 1.0)
	node.bus = info.get("bus", default_bus)
	if positional:
		node.global_position = info["position"]
	node.play()
	stats.sounds += 1

func _on_sound_finished(node, positional: bool) -> void:
	_sound_pools[1 if positional else 0].append(node)

func end_by_key(key: String) -> void:
	var tick: int = SyncManager.current_tick
	var entry: Entry = _active.get(key)
	if entry == null or entry.ended:
		return
	if entry.ending_tick >= 0:
		if entry.ending_tick == tick:
			# Asked again by a re-simulation.
			if _rollback_from_tick >= 0:
				_confirmed_ends[entry] = true
			return
		if _rollback_from_tick < 0 or entry.ending_tick < _rollback_from_tick or _confirmed_ends.has(entry):
			# Already ending, from a tick that stands.
			return
		# The re-simulation asks it on another tick: moved there, still ending.
		var previous: Dictionary = _end_requests.get(entry.ending_tick, {})
		previous.erase(key)
		if previous.is_empty():
			_end_requests.erase(entry.ending_tick)
	elif entry.node != null and entry.node.has_method("_effect_ending"):
		# Not showing yet: _show() ends it right away.
		entry.node._effect_ending()
	if entry.ending_tick < 0:
		stats.ends_asked += 1
	entry.ending_tick = tick
	var at_tick: Dictionary = _end_requests.get(tick, {})
	at_tick[key] = entry
	_end_requests[tick] = at_tick
	if _rollback_from_tick >= 0:
		_confirmed_ends[entry] = true

# The effect is over: taken out of the tree, and kept for reuse. Not shown again
# if a rollback re-simulates the tick that started it.
func end_effect(node: Node) -> void:
	var entry = node.get_meta("effect_entry", null)
	if entry == null:
		# Already out of the tree, a rollback having ended it: pooled once only.
		return
	if entry.node == node:
		entry.ended = true
		entry.node = null
		if _active.get(entry.key) == entry:
			_active.erase(entry.key)
	_hide(node)

# At the start of a tick, where the display reaches the last one.
func show_pending() -> void:
	if _pending.is_empty():
		return
	var pending := _pending
	_pending = []
	for entry in pending:
		if not entry.ended and entry.node == null:
			_show(entry)

func begin_rollback(loaded_tick: int) -> void:
	_rollback_from_tick = loaded_tick + 1
	_confirmed.clear()
	_confirmed_ends.clear()

func end_rollback() -> void:
	# Ends first: an effect that no longer starts goes anyway.
	for tick in _end_requests.keys():
		if tick < _rollback_from_tick:
			continue
		var at_tick: Dictionary = _end_requests[tick]
		for key in at_tick.keys():
			var entry: Entry = at_tick[key]
			if not _confirmed_ends.has(entry):
				at_tick.erase(key)
				if entry.ending_tick == tick:
					entry.ending_tick = -1
					stats.ends_undone += 1
					if not entry.ended and entry.node != null and is_instance_valid(entry.node) \
							and entry.node.has_method("_effect_resume"):
						entry.node._effect_resume()
		if at_tick.is_empty():
			_end_requests.erase(tick)
	for tick in _entries.keys():
		if tick < _rollback_from_tick:
			continue
		var at_tick: Dictionary = _entries[tick]
		for key in at_tick.keys():
			var entry: Entry = at_tick[key]
			if not entry.keep and not _confirmed.has(entry):
				if not entry.ended:
					stats.ended_by_rollback += 1
				_end_entry(entry)
				at_tick.erase(key)
		if at_tick.is_empty():
			_entries.erase(tick)
	_rollback_from_tick = -1
	_confirmed.clear()
	_confirmed_ends.clear()

func _end_entry(entry: Entry) -> void:
	entry.ended = true
	if _active.get(entry.key) == entry:
		_active.erase(entry.key)
	if entry.node != null:
		# Untyped: the node may have been freed with its parent.
		var node = entry.node
		entry.node = null
		_hide(node)

func _show(entry: Entry) -> void:
	if not is_instance_valid(entry.parent) or not entry.parent.is_inside_tree():
		entry.ended = true
		return
	var pool_key := "%d:%s" % [entry.parent.get_instance_id(), entry.scene.resource_path]
	var pool: Array = _pools.get(pool_key, [])
	var node: Node = null
	while node == null and not pool.is_empty():
		var candidate = pool.pop_back()
		if is_instance_valid(candidate) and candidate.get_parent() == null:
			node = candidate
	if node != null:
		stats.reused += 1
	else:
		var prewarmed: Array = _prewarmed.get(entry.scene.resource_path, [])
		node = prewarmed.pop_back() if not prewarmed.is_empty() else entry.scene.instantiate()
	# Named after its key, which starts with the name of the node that started
	# it: it sorts right after that node, as a network node spawned under that
	# name would. Out of the tree: no rename to watch.
	_counter += 1
	node.name = "%s_%d" % [entry.key, _counter]
	_add_by_name(entry.parent, node)
	node.set_meta("effect_pool", pool_key)
	_pool_parents[pool_key] = entry.parent
	node.set_meta("effect_entry", entry)
	entry.node = node
	stats.shown += 1
	stats.showing += 1
	stats.max_showing = max(stats.max_showing, stats.showing)
	node.callv("_effect_spawn", entry.args)
	if entry.ending_tick >= 0 and node.has_method("_effect_ending"):
		node._effect_ending()

# Among siblings that SpawnManager keeps sorted by name, where it would put a
# network node: also the order a YSort draws them in at the same y.
func _add_by_name(parent: Node, node: Node) -> void:
	parent.add_child(node)
	var node_name := str(node.name)
	var low := 0
	var high := parent.get_child_count() - 1
	while low < high:
		var middle := (low + high) >> 1
		if str(parent.get_child(middle).name).casecmp_to(node_name) < 0:
			low = middle + 1
		else:
			high = middle
	if low < parent.get_child_count() - 1:
		parent.move_child(node, low)

func _hide(node) -> void:
	if not is_instance_valid(node):
		return
	stats.showing -= 1
	node.set_meta("effect_entry", null)
	if node.has_method("_effect_end"):
		node._effect_end()
	var pool_key: String = node.get_meta("effect_pool", "")
	if pool_key == "" or not is_instance_valid(_pool_parents.get(pool_key)):
		node.queue_free()
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	var pool: Array = _pools.get(pool_key, [])
	pool.append(node)
	_pools[pool_key] = pool

func _on_tick_retired(tick: int) -> void:
	# No rollback goes back there any more: its effects and ends stand.
	_entries.erase(tick)
	_end_requests.erase(tick)
	# Out of the tree, pooled nodes are not freed with their parent.
	for pool_key in _pool_parents.keys():
		if not is_instance_valid(_pool_parents[pool_key]):
			_free_pool(pool_key)
			_pool_parents.erase(pool_key)

# A replay seeking (SyncManager._start_from_state()): the effects showing are
# from another point of the match, and the ticks it records may come again.
func end_all() -> void:
	for at_tick in _entries.values():
		for entry in at_tick.values():
			_end_entry(entry)
	for entry in _active.values():
		_end_entry(entry)
	_entries.clear()
	_end_requests.clear()
	_active.clear()
	_pending.clear()
	_confirmed.clear()
	_confirmed_ends.clear()
	_rollback_from_tick = -1

func _on_sync_stopped() -> void:
	_entries.clear()
	_end_requests.clear()
	_active.clear()
	_pending.clear()
	_confirmed.clear()
	_confirmed_ends.clear()
	_rollback_from_tick = -1
	# Pooled nodes are freed; those still showing end on their own, and are
	# freed then. Sounds still playing finish on their own, and are reused after.
	_free_pools()
	_free_prewarmed()

func _free_pool(pool_key: String) -> void:
	for node in _pools.get(pool_key, []):
		if is_instance_valid(node):
			node.free()
	_pools.erase(pool_key)

func _free_pools() -> void:
	for pool_key in _pools.keys():
		_free_pool(pool_key)
	_pool_parents.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_pools()
		_free_prewarmed()

func _free_prewarmed() -> void:
	for path in _prewarmed:
		for node in _prewarmed[path]:
			if is_instance_valid(node):
				node.free()
	_prewarmed.clear()
