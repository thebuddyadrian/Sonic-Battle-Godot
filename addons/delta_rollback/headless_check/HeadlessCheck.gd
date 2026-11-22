extends Node
## Plays a local match of a game's scene with scripted inputs, headless, and
## prints a hash of the final state: the same inputs must give the same hash
## whatever the rollbacks, and the state consistency check must report nothing.
## It prints every tick's state hash too, as "STATE <tick> <hash>", once the
## tick is retired (final): run_checks.sh compares them between runs, on the
## ticks both saved (a rollback skips saving some). A state that differs only
## for a while (a record that expires) leaves the final one the same.
## run_checks.sh, next to it, plays a dozen variants (rollbacks, late packets,
## interpolation...) and compares them.
##
##   godot --headless --fixed-fps 60 --path . res://addons/delta_rollback/headless_check/HeadlessCheck.tscn -- \
##       --scene=res://Main.tscn --inputs=res://tests/MyInputs.gd --rollback=4 --ticks=600
##
## --scene=PATH: the match scene to play. Default: Project Settings -> Network
##     -> Rollback -> Log Inspector -> Replay Match Scene Path.
## --inputs=PATH: the input script (below). Without one, no input is pressed.
## --rollback=N: a forced N tick rollback every tick (0: none).
## --late-packet=T:P:I: a T tick rollback every P ticks, all but the last I
##     ticks complete (SyncManager.debug_late_packet_ticks).
## --ticks=N: how many ticks to play.
## --interpolation=0|1: overrides the project setting.
## --logging=0|1: sets the scene's logging_enabled, if it has one (off by
##     default: logging keeps every state, so no save can be skipped).
## --reuse=0|1: SpawnManager reuses despawned nodes (off by default).
## --forward=0|1: the forward load check before every tick
##     (SyncManager.debug_check_local_state_consistency_forward): what a replay
##     seeking into a log rebuilds must save back the same. Slow.
## --defer=N[:cost[:usecs]]: rollback deferral (see SyncManager).
## --toggle-interpolation=N: interpolation paused and resumed every N ticks.
## --perf=0|1: SyncManager's perf summary, printed when the match stops.
## --idle=A:B: no input from tick A until tick B, for things to settle (bodies
##     falling asleep...).
## --physics-process-msecs=N: the slow tick alarm (0, the default: off), an
##     error that fails run_checks.sh.
##
## The input script is instantiated (extends RefCounted, or nothing) and has:
##
##   func inputs_for_tick(tick: int) -> Array
##       The input actions held on that tick: pressed with
##       Input.action_press(), every other action it pressed released.
##   func start(main: Node) -> void                    (optional)
##       Starts a local match on the scene, once it is in the tree. Default:
##       main._on_LocalButton_pressed(), as in the addon's demos.
##   func tick_finished(main: Node) -> Variant         (optional)
##       Called after each tick (not re-simulated ones): what the runs must
##       agree on besides the state, hashed into the result (what a spawn
##       parent holds, so that spawns a tick early or late show), and the
##       time to read what inputs_for_tick() needs, as where a character
##       faces. Read it here, not when inputs_for_tick() is called: with
##       interpolation, the tree shows the tick before by then. Default: the
##       names of the network nodes under main's SpawnParent, if it has one.

var _main: Node
var _inputs: Object
var _ticks := 600
var _idle_from := 0
var _idle_until := 0
var _started := false
# The actions pressed on the last tick, to release.
var _pressed := {}
# What tick_finished() returned after each tick (not re-simulated ones).
var _trace := []
# Frames run, so that a match that never ends (a script error in _finish())
# fails instead of hanging.
var _frames := 0

# The last one given: a wrapper script's defaults come before its own arguments.
func _arg(prefix: String, default: String) -> String:
	var value := default
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			value = argument.trim_prefix(prefix)
	return value

func _ready() -> void:
	_ticks = int(_arg("--ticks=", "600"))
	var idle: PackedStringArray = _arg("--idle=", "").split(":", false)
	if idle.size() == 2:
		_idle_from = int(idle[0])
		_idle_until = int(idle[1])
	SyncManager.debug_rollback_ticks = int(_arg("--rollback=", "0"))
	# --late-packet=ticks:period:incomplete
	var late: PackedStringArray = _arg("--late-packet=", "").split(":", false)
	if late.size() == 3:
		SyncManager.debug_late_packet_ticks = int(late[0])
		SyncManager.debug_late_packet_period = int(late[1])
		SyncManager.debug_late_packet_incomplete = int(late[2])
	SyncManager.debug_check_local_state_consistency = true
	SyncManager.debug_check_local_state_consistency_forward = _arg("--forward=", "0") == "1"
	SyncManager._spawn_manager.reuse_despawned_nodes = _arg("--reuse=", "0") == "1"
	if _arg("--physics-process-msecs=", "") != "":
		SyncManager.debug_physics_process_msecs = float(_arg("--physics-process-msecs=", ""))
	if _arg("--perf=", "") != "":
		SyncManager.debug_perf_summary = _arg("--perf=", "") == "1"
	# --defer=N: every rollback put off for up to N ticks; N:cost[:usecs]: only
	# the ones estimated over usecs (default: the adaptive budget).
	var defer: PackedStringArray = _arg("--defer=", "").split(":", false)
	if defer.size() > 0:
		SyncManager.max_rollback_deferral_ticks = int(defer[0])
		SyncManager.debug_defer_all_rollbacks = defer.size() < 2 or defer[1] != "cost"
		if defer.size() > 2:
			SyncManager.rollback_deferral_budget_usecs = int(defer[2])
	if _arg("--toggle-interpolation=", "") != "":
		SyncManager.interpolation = true
		SyncManager.debug_toggle_interpolation_ticks = int(_arg("--toggle-interpolation=", ""))
	if _arg("--interpolation=", "") != "":
		SyncManager.interpolation = _arg("--interpolation=", "") == "1"
	SyncManager.sync_started.connect(func (): _started = true)
	SyncManager.tick_finished.connect(_on_tick_finished)
	SyncManager.tick_retired.connect(_on_tick_retired)

	var inputs_path := _arg("--inputs=", "")
	if inputs_path != "":
		_inputs = load(inputs_path).new()
	var scene_path := _arg("--scene=", ProjectSettings.get_setting("network/rollback/log_inspector/replay_match_scene_path", ""))
	if scene_path == "":
		_fail("no match scene: pass --scene=PATH, or set the Replay Match Scene Path project setting")
		return
	_main = load(scene_path).instantiate()
	if "logging_enabled" in _main:
		_main.logging_enabled = _arg("--logging=", "0") == "1"
	elif _arg("--logging=", "0") == "1":
		_fail("--logging=1, but %s has no logging_enabled" % scene_path)
		return
	add_child(_main)
	if _inputs and _inputs.has_method("start"):
		_inputs.start.call_deferred(_main)
	else:
		_main._on_LocalButton_pressed.call_deferred()

func _fail(message: String) -> void:
	# A script error, which a headless run doesn't stop at: an ERROR line and a
	# failing exit code.
	printerr("ERROR: HeadlessCheck: ", message)
	set_process(false)
	set_physics_process(false)
	get_tree().quit.call_deferred(1)

func _physics_process(_delta: float) -> void:
	if not _started:
		return
	var tick: int = SyncManager.current_tick
	var pressed := {}
	if _inputs and (tick < _idle_from or tick >= _idle_until):
		for action in _inputs.inputs_for_tick(tick):
			pressed[action] = true
	for action in _pressed:
		if not pressed.has(action):
			Input.action_release(action)
	for action in pressed:
		Input.action_press(action)
	_pressed = pressed
	if tick >= _ticks:
		_finish()

func _on_tick_finished(is_rollback: bool) -> void:
	if is_rollback or not is_instance_valid(_main):
		return
	var traced: Variant
	if _inputs and _inputs.has_method("tick_finished"):
		traced = _inputs.tick_finished(_main)
	else:
		traced = _spawned_names()
	_trace.append([SyncManager.current_tick, traced])

# The network nodes under the scene's SpawnParent, not the effects showing.
func _spawned_names() -> Array:
	var names := []
	var spawn_parent := _main.get_node_or_null("SpawnParent")
	if spawn_parent:
		for child in spawn_parent.get_children():
			if child.has_meta("spawn_name"):
				names.append(str(child.name))
		names.sort()
	return names

func _process(_delta: float) -> void:
	_frames += 1
	if _frames > _ticks * 4 + 600:
		print("ERROR: the match did not finish")
		get_tree().quit(1)

func _on_tick_retired(tick: int) -> void:
	var frame = SyncManager._get_state_hash_frame(tick)
	if frame and frame.state_hash != SyncManager.SKIPPED_STATE_HASH:
		print("STATE %d %d" % [tick, frame.state_hash])

func _finish() -> void:
	set_physics_process(false)
	for action in _pressed:
		Input.action_release(action)
	var frame = SyncManager.state_buffer[-1]
	# Not the scene's nodes as they are now: with interpolation, the display
	# (and so the tree) is a tick behind. The last state, and what the nodes
	# held after each tick.
	print("RESULT tick=%d state_hash=%d trace=%d last=%s" % [
		frame.tick, SyncManager._calculate_data_hash(frame.data), hash(_trace), _trace[-1][1]])
	var effects: Dictionary = SyncManager._effect_manager.stats
	print("STATS state_saves_skipped=%d rollbacks_deferred=%d interpolation_paused_ticks=%d effects_shown=%d reused=%d ended_by_rollback=%d" % [
		SyncManager.state_saves_skipped, SyncManager.rollbacks_deferred, SyncManager.interpolation_paused_ticks,
		effects.shown, effects.reused, effects.ended_by_rollback])
	SyncManager.stop()
	get_tree().quit()
