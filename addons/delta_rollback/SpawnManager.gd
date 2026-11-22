extends Node

const REUSE_DESPAWNED_NODES_SETTING := 'network/rollback/spawn_manager/reuse_despawned_nodes'

# The state holds what a load can disagree about, and nothing more:
# - records: spawns and despawns of the last ticks_before_remove ticks, as
#   {internal name: [spawn tick, despawn tick, parent path, name, scene path]}
#   (-1 for an event older than the record, or that has not happened).
# - settled: nodes spawned longer ago and still there, as
#   {internal name: [parent path, name, scene path]}. The same in every state a
#   load can bring back; only loading forward from a log reads it.
# - counter: how many nodes of each name were spawned, for naming them.
# A load only has to look at records. All three are shared with the saved
# states and copied only before being changed. They used to be one full list
# of spawned nodes, copied on every save and walked through on every load.
var records := {}
var settled := {}
var counter := {}
var _records_shared := false
var _settled_shared := false
var _counter_shared := false
# The last tick network_process ran, to date despawns as the old per-tick
# countdown did (see despawn()).
var _np_tick := -1
# The tick the current state is the one of: the last loaded, or the last
# processed. Not current_tick, which an interpolation backward load leaves on
# the next tick.
var _state_tick := -1

enum {
	RECORD_SPAWN_TICK,
	RECORD_DESPAWN_TICK,
	RECORD_PARENT,
	RECORD_NAME,
	RECORD_SCENE,
}

var spawned_nodes := {}
var retired_nodes := {}
var interpolation_nodes := {}
var ticks_before_remove: = 20
var connections: = {}

enum {
	UNDO_DESPAWN,
	UNDO_SPAWN,
}

# Where a node must be at the tick being loaded.
enum {
	TARGET_IN_TREE,
	TARGET_WAITING,
	TARGET_ABSENT,
}

var reuse_despawned_nodes := false

var _frame_spawn_parents := {}

func _ready() -> void:
	if ProjectSettings.has_setting(REUSE_DESPAWNED_NODES_SETTING):
		reuse_despawned_nodes = ProjectSettings.get_setting(REUSE_DESPAWNED_NODES_SETTING)
	ticks_before_remove = ProjectSettings.get_setting("network/rollback/max_buffer_size") + 2

func reset() -> void:
	# New dictionaries: the current ones may be shared with saved states.
	records = {}
	settled = {}
	counter = {}
	_records_shared = false
	_settled_shared = false
	_counter_shared = false
	_np_tick = -1
	_state_tick = -1
	connections.clear()
	
	for node in spawned_nodes.values():
		node.queue_free()
	spawned_nodes.clear()
	
	interpolation_nodes.clear()
	
	for nodes in retired_nodes.values():
		for node in nodes:
			node.queue_free()
	retired_nodes.clear()

func _writable_records() -> Dictionary:
	if _records_shared:
		records = records.duplicate()
		_records_shared = false
	return records

func _writable_settled() -> Dictionary:
	if _settled_shared:
		settled = settled.duplicate()
		_settled_shared = false
	return settled

func _writable_counter() -> Dictionary:
	if _counter_shared:
		counter = counter.duplicate()
		_counter_shared = false
	return counter

func _rename_node(name: String) -> String:
	var writable := _writable_counter()
	if not writable.has(name):
		writable[name] = 0
	writable[name] += 1
	return name + str(writable[name])

func _remove_colliding_node(name: String, parent: Node) -> void:
	var existing_node = parent.get_node_or_null(name)
	if existing_node:
		if not existing_node.is_queued_for_deletion():
			push_warning("Removing node %s which is in the way of new spawn" % existing_node)
		parent.remove_child(existing_node)
		existing_node.queue_free()

# Native: only moves the children that are out of place, usually just the ones
# added, and tells the registry about it.
func _alphabetize_children(parent: Node) -> void:
	SyncManager.sync_booster.alphabetize_children(parent)

func _instance_scene(scene: PackedScene) -> Node:
	var resource_path: = scene.resource_path
	if retired_nodes.has(resource_path):
		var nodes: Array = retired_nodes[resource_path]
		var node: Node

		while nodes.size() > 0:
			node = retired_nodes[resource_path].pop_front()
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				break
			else:
				node = null

		if nodes.size() == 0:
			retired_nodes.erase(resource_path)

		if node:
			return node

	return scene.instantiate()

func add_node_in_pool(scene: PackedScene) -> void:
	var resource_path: = scene.resource_path
	if not retired_nodes.has(resource_path):
		retired_nodes[resource_path] = []
	var array: Array = retired_nodes[resource_path]
	array.append(scene.instantiate())

func spawn(name: String, parent: Node, scene: PackedScene, data, rename: bool = true) -> Node:
	var spawned_node = _instance_scene(scene)
	var internal_name = _rename_node(name)
	if rename:
		name = internal_name
	_remove_colliding_node(name, parent)
	spawned_node.name = name
	parent.add_child(spawned_node)
	for n in get_tree().get_nodes_in_group("network_sync"):
		SyncManager.set_groups_for_node(n)
	_frame_spawn_parents[parent] = true
	
	_writable_records()[internal_name] = [SyncManager.current_tick, -1, parent.get_path(), spawned_node.name, scene.resource_path]
	spawned_nodes[internal_name] = spawned_node

	spawned_node.set_meta("spawn_tick", SyncManager.current_tick)
	spawned_node.set_meta("spawn_name", internal_name)
	# For _delete_node(), to put it back in the right pool.
	spawned_node.set_meta("spawn_scene", scene.resource_path)
	_init_node(spawned_node, data)

	return spawned_node

func despawn(node: Node) -> void:
	if node.has_method("_network_despawn"):
		node._network_despawn()
	
	if not node.has_meta("spawn_name"):
		push_error("Can't despawn a node that was not spawned")
		return
	
	var internal_name: String = node.get_meta("spawn_name")
	if node.get_parent():
		node.get_parent().remove_child(node)
	
	# Dated like the per-tick countdown this replaces, which network_process
	# advanced: a despawn after this tick's network_process counts from the
	# next tick.
	var tick: int = SyncManager.current_tick + (1 if _np_tick == SyncManager.current_tick else 0)
	var record
	if records.has(internal_name):
		# Records are shared with saved states: replaced, never changed.
		record = records[internal_name].duplicate()
	else:
		var entry: Array = settled[internal_name]
		record = [-1, -1, entry[0], entry[1], entry[2]]
	record[RECORD_DESPAWN_TICK] = tick
	_writable_records()[internal_name] = record

func _network_process(_data: Dictionary) -> void:
	for p in _frame_spawn_parents:
		_alphabetize_children(p)
	_frame_spawn_parents.clear()
	_np_tick = SyncManager.current_tick
	_state_tick = SyncManager.current_tick
	# A record expires once no load can go back before its last event: a
	# despawned node is then deleted, a spawned one becomes settled.
	var expired := []
	for internal_name in records:
		var record: Array = records[internal_name]
		var last_event = max(record[RECORD_SPAWN_TICK], record[RECORD_DESPAWN_TICK])
		if SyncManager.current_tick - last_event + 1 > ticks_before_remove:
			expired.append(internal_name)
	for internal_name in expired:
		var record: Array = records[internal_name]
		if record[RECORD_DESPAWN_TICK] != -1:
			_delete_node(internal_name)
			if settled.has(internal_name):
				_writable_settled().erase(internal_name)
		else:
			_writable_settled()[internal_name] = [record[RECORD_PARENT], record[RECORD_NAME], record[RECORD_SCENE]]
		_writable_records().erase(internal_name)

# Removes the node for good (to the pool if reused). Records and settled are
# the caller's business.
func _delete_node(internal_name: String) -> void:
	if not spawned_nodes.has(internal_name):
		return
	
	var node: Node = spawned_nodes[internal_name]
	if node.get_parent():
		node.get_parent().remove_child(node)
	
	if reuse_despawned_nodes and is_instance_valid(node) and not node.is_queued_for_deletion():
		# Switched on, as registered, and its NetworkAnimationPlayers and
		# NetworkTimers back to their scene's values, to start over.
		SyncManager.sync_booster.prepare_for_reuse(node)
		if node.has_method('_network_prepare_for_reuse'):
			node._network_prepare_for_reuse()
		if connections.has(node):
			for connection in connections[node]:
				var callable = Callable(connection[1], connection[2])
				node.disconnect(connection[0], callable)
			connections.erase(node)
		var scene_path: String = node.get_meta("spawn_scene")
		if not retired_nodes.has(scene_path):
			retired_nodes[scene_path] = []
		retired_nodes[scene_path].append(node)
	else:
		node.queue_free()

	spawned_nodes.erase(internal_name)


func _init_node(node: Node, args) -> void:
	if not node.has_method("_network_spawn"):
		return
	
	var processed_data = args
	if node.has_method("_network_spawn_preprocess"):
		processed_data = node.callv("_network_spawn_preprocess", args) if args is Array \
			else node._network_spawn_preprocess(args)
	SyncManager.register_event(self, {
			type = "init",
			node = node.get_meta("spawn_name", "default"),
			data = processed_data,
		})
	# Disable event registration because registering the call is enough
	var was_disabled: bool = SyncManager.disable_event_registration
	SyncManager.disable_event_registration = true
	if processed_data is Array:
		node.callv("_network_spawn", processed_data)
	else:
		node._network_spawn(processed_data)
	SyncManager.disable_event_registration = was_disabled


func _save_state() -> Dictionary:
	_records_shared = true
	_settled_shared = true
	_counter_shared = true
	return {
		tick = _state_tick if _state_tick >= 0 else SyncManager.current_tick,
		records = records,
		settled = settled,
		counter = counter,
	}

func _load_state(state: Dictionary) -> void:
	if not state.has("records"):
		push_error("SpawnManager can't load a state from before its records format")
		return
	if SyncManager._logger:
		SyncManager._logger.start_timing("spawn_manager_load_state_%s" % SyncManager.load_type)
	var load_type: int = SyncManager.load_type
	_frame_spawn_parents.clear()
	var state_records: Dictionary = state.records
	
	# Same records (the very same Dictionary: == compares contents in Godot 4)
	# and nothing set aside for interpolation: the nodes are already where the
	# loaded state has them.
	if not (is_same(state_records, records) and interpolation_nodes.is_empty()):
		# Only nodes with a recent record, in either state, or set aside for
		# interpolation can be somewhere else than in the loaded state.
		var names := {}
		for internal_name in records:
			names[internal_name] = true
		for internal_name in state_records:
			names[internal_name] = true
		for internal_name in interpolation_nodes:
			names[internal_name] = true
		for internal_name in names:
			_load_node(internal_name, state.tick, state_records, load_type)
	
	for p in _frame_spawn_parents:
		_alphabetize_children(p)
	_frame_spawn_parents.clear()
	
	# After a backward load, what was set aside is needed by the forward one;
	# after any other load, the nodes are exactly as in the loaded state.
	if load_type != SyncManager.LoadType.INTERPOLATION_BACKWARD:
		interpolation_nodes.clear()
	
	records = state_records
	settled = state.settled
	counter = state.counter
	_records_shared = true
	_settled_shared = true
	_counter_shared = true
	_state_tick = state.tick
	# The state's network_process has run: a rollback running the next tick
	# again, the one processed last, mustn't date its despawns a tick later.
	_np_tick = state.tick
	if SyncManager._logger:
		SyncManager._logger.stop_timing("spawn_manager_load_state_%s" % SyncManager.load_type)

# Puts one node where it is at tick state_tick.
func _load_node(internal_name: String, state_tick: int, state_records: Dictionary, load_type: int) -> void:
	var node: Node = spawned_nodes.get(internal_name)
	if node == null:
		return
	var backward: bool = load_type == SyncManager.LoadType.INTERPOLATION_BACKWARD
	
	var target: int
	var state_record = state_records.get(internal_name)
	if state_record != null:
		target = TARGET_WAITING if state_record[RECORD_DESPAWN_TICK] != -1 else TARGET_IN_TREE
	elif node.get_meta("spawn_tick", -1) > state_tick:
		target = TARGET_ABSENT
	else:
		# No record at that tick: spawned long enough before it to be settled.
		target = TARGET_IN_TREE
	
	match target:
		TARGET_IN_TREE:
			if not node.is_inside_tree():
				var parent: Node = get_node(_node_parent_path(internal_name, state_record))
				parent.add_child(node)
				_frame_spawn_parents[parent] = true
				if backward:
					interpolation_nodes[internal_name] = {type = UNDO_DESPAWN}
		TARGET_WAITING:
			if node.get_parent():
				node.get_parent().remove_child(node)
		TARGET_ABSENT:
			if backward:
				# Kept for the forward load that follows.
				if node.get_parent():
					node.get_parent().remove_child(node)
				interpolation_nodes[internal_name] = {type = UNDO_SPAWN}
			else:
				_delete_node(internal_name)

func _node_parent_path(internal_name: String, state_record) -> NodePath:
	if state_record != null:
		return state_record[RECORD_PARENT]
	if records.has(internal_name):
		return records[internal_name][RECORD_PARENT]
	return settled[internal_name][0]

func _load_state_forward(state: Dictionary, events) -> void:
	if not events:
		events = {}
	if not state.has("records"):
		push_error("SpawnManager can't load a state from before its records format")
		return
	# Every node there at that tick: settled, or with a record and spawned.
	var nodes := {}
	for internal_name in state.settled:
		var entry: Array = state.settled[internal_name]
		nodes[internal_name] = [-1, entry[0], entry[1], entry[2]]
	for internal_name in state.records:
		var record: Array = state.records[internal_name]
		nodes[internal_name] = [record[RECORD_SPAWN_TICK], record[RECORD_PARENT], record[RECORD_NAME], record[RECORD_SCENE]]
	# Parents first: a node spawned under another spawned node goes under the
	# new one, not under the one being freed (the check), or nothing (a seek).
	# Within a depth, as listed (sort_custom() isn't stable).
	var internal_names := nodes.keys()
	var order := {}
	for internal_name in internal_names:
		order[internal_name] = [String(nodes[internal_name][1]).count("/"), order.size()]
	internal_names.sort_custom(func(a, b): return order[a] < order[b])
	for internal_name in internal_names:
		if not spawned_nodes.has(internal_name):
			var entry: Array = nodes[internal_name]
			var spawned_node = _instance_scene(load(entry[3]))
			var name: String = entry[2]
			var parent = get_node(entry[1])
			_remove_colliding_node(name, parent)
			spawned_node.name = name
			spawned_node.set_meta("spawn_name", internal_name)
			spawned_node.set_meta("spawn_scene", entry[3])
			spawned_node.set_meta("spawn_tick", entry[0])
			spawned_nodes[internal_name] = spawned_node
			parent.add_child(spawned_node)
			_alphabetize_children(parent)
	for n in get_tree().get_nodes_in_group("network_sync"):
		SyncManager.set_groups_for_node(n)
	
	records = state.records
	settled = state.settled
	counter = state.counter
	_records_shared = true
	_settled_shared = true
	_counter_shared = true
	_state_tick = state.tick
	_np_tick = state.tick
	_load_events(events)

# After the rest of the forward load: nodes had to be in the tree to do their
# events, and for the PropertyManager to set what it holds of them (the states
# of their switched off nodes), which a rollback putting them back needs. Now
# the despawned ones go.
func _remove_despawned_after_forward_load() -> void:
	for internal_name in records:
		if records[internal_name][RECORD_DESPAWN_TICK] != -1:
			var node = spawned_nodes[internal_name]
			if node.get_parent():
				node.get_parent().remove_child(node)


func _load_events(events: Dictionary) -> void:
	# Already registered, as when spawned (_init_node()).
	var was_disabled: bool = SyncManager.disable_event_registration
	SyncManager.disable_event_registration = true
	for internal_name in events.keys():
		var node = spawned_nodes.get(internal_name)
		if node == null:
			continue
		for e in events[internal_name]:
			if e['type'] == "init" and node.has_method("_network_spawn"):
				var args = e['data']
				if args is Array:
					node.callv("_network_spawn", args)
				else:
					node._network_spawn(args)
			elif e['type'] == "connect":
				var data = e['data'].duplicate()
				var target := get_node(data[1])
				var callable := Callable(target, data[2]).bindv(data[3])
				node.connect(data[0], callable, data[4])
				# For _delete_node() to disconnect it, as connect_signal() does.
				if not connections.has(node):
					connections[node] = []
				connections[node].append([data[0], target, data[2]])
	SyncManager.disable_event_registration = was_disabled


# The events of the nodes that are still there: spawn names are never used
# again, so one gone by then is in no later state.
static func _compact_events(events: Dictionary, _tick: int, state) -> Dictionary:
	if state == null:
		return events
	var compacted := {}
	for t in events:
		var kept := []
		for e in events[t]:
			if state.records.has(e['node']) or state.settled.has(e['node']):
				kept.append(e)
		if not kept.is_empty():
			compacted[t] = kept
	return compacted


static func _prepare_events_up_to_tick(_sync_manager: Node, tick_number: int, events: Dictionary, state: Dictionary) -> Dictionary:
	# only keep the last tick for each node
	var prepared_events := {}
	for t in events.keys():
		# Only load up to the asked tick
		if t > tick_number:
			break
		var new_event = events[t]
		for e in new_event:
			var path = e['node']
			if not (state.records.has(path) or state.settled.has(path)):
				continue
			if not prepared_events.has(path):
				prepared_events[path] = []
			prepared_events[path].append(e)
	return prepared_events


func connect_signal(node: Node, name: String, target: Node, method: String, binds := [], flags := 0) -> void:
	if (not node.has_meta("spawn_tick")) or node.get_meta("spawn_tick") != SyncManager.current_tick:
		push_error("connect_signal only connects nodes on the tick they were spawn (desync risk)")
		return
	
	var callable: = Callable(target, method).bindv(binds)
	node.connect(name, callable, flags)
	SyncManager.register_event(self, {
		type = "connect",
		node = node.get_meta("spawn_name"),
		data = [name, target.get_path(), method, binds.duplicate(true), flags],
	})
	if not connections.has(node):
		connections[node] = []
	connections[node].append([name, target, method])
