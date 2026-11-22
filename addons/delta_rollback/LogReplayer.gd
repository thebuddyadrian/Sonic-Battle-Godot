extends Node
class_name DeltaLogReplayer

## In-game replayer, debugger and TAS tool for Delta Rollback.
##
## Unlike [code]SyncReplay.gd[/code] (which is driven frame-by-frame by the Log
## Inspector's replay server), this node re-simulates a match locally: it feeds
## the inputs recorded in a [code].log[/code] file into [code]SyncManager[/code]
## tick after tick and lets the game run normally. That makes it usable as a
## replay viewer, a desync/bug-hunting tool and a TAS (tool assisted
## speedrun/scripting) recorder.
##
## The match can be watched through the eyes of any of the players that played
## it: the replay_view_N actions pick one, going by the nodes that produced the
## recorded input. A match scene that implements
## [code]set_replay_view(player_node: Node, peer_id: int)[/code] decides what
## that means (usually pointing its camera at that player, the way it does for
## the local player during a match), so that a replay shows the view that player
## really had. Without it the view does not move, and the free camera (C) is
## there to look around with.
##
## [b]Setup[/b]
## [codeblock]
## - Create a scene inheriting from the scene a match is played in, and add a
##   Node with this script to it. That inherited scene is your replay scene.
## - Set "replay_file_path" to the log to replay (e.g. "user://my_match.log"),
##   or set "log_directory" to replay the most recent log of a directory.
## - Run that scene (F6).
## [/codeblock]
## Keep the root node of the inherited scene named like the match scene's root:
## recorded input and state are keyed by absolute node path, so renaming it
## would stop every recorded input from reaching its node.
## The replay scene stays that light: everything else lives here, in the addon.
## A replayer that is NOT inside a match scene (a scene of its own, or an
## autoload) instantiates the match scene itself instead, from
## "match_scene_path" or from the project setting
## "network/rollback/log_inspector/replay_match_scene_path".
## The match scene must implement the same setup method used by the Log
## Inspector's replay feature (by default
## [code]setup_match_for_replay(my_peer_id: int, peer_ids: Array, match_info: Dictionary)[/code]):
## restore the match from [code]match_info[/code] (seed, player list, options...)
## and spawn the level exactly as it was spawned when the log was recorded.
## [code]my_peer_id[/code] is the peer that recorded the log and
## [code]peer_ids[/code] the other peers of the match, exactly like the Log
## Inspector passes them, so an existing implementation works as is. Node
## authority has to end up matching the recorded match, since that is what maps
## a recorded input to a node.
##
## [b]Actions[/b]
## Every command is an input action, registered on startup with the default
## binding below unless the project already defines an action of that name (add
## it to Project Settings > Input Map to rebind). Nothing responds when no log
## is being replayed.
## [codeblock]
## replay_speed_up           N, KP +      x2 playback speed
## replay_speed_down         B, KP -      /2 playback speed (pauses at 1 tick/s)
## replay_pause              KP *         pause / unpause
## replay_normal_speed       M, KP 0      back to normal speed
## replay_step               . , KP /     simulate a single tick (pauses first)
## replay_restart            R            watch it again from the start
## replay_screenshot         P, KP 5      save a screenshot to user://
## replay_status             KP 7         print the rollback status to the console
## replay_inject_rollbacks   KP 8         toggle injected random rollbacks
## replay_toggle_hud         H
## replay_view_1 ... _10     1-9, 0       watch the match as that player saw it
## replay_view_next          tab          watch the next player
## replay_toggle_camera      C            free camera on / off (see free_camera)
## replay_camera_left/right/up/down        arrows, pan the free camera
## replay_supertas           Y            toggle SUPER-TAS mode: the match only
##                                        advances one tick when the local input
##                                        changes (or while replay_tas is held)
## replay_overwrite          O            overwrite the replayed log with what
##                                        has been recorded (TAS mode, twice)
## replay_tas                shift        hand the keyboard the input of
##                                        tas_peer_id, instead of the log's
## [/codeblock]
##
## [b]TAS[/b]
## Holding [member tas_hold_action] plays the input of the player being watched
## from the keyboard instead of from the log, so a run can be redone by hand
## from any point, including past the end of the log. Watching another player
## (replay_view_N) hands the keyboard to them instead. SUPER-TAS (replay_supertas) does
## the same one tick at a time: the match only moves while something is held
## down, which is how a run is authored input by input.
##
## Turning [member record_replay] on records all of that to
## [code]<replay_file_path>_next.log[/code], and replay_overwrite then swaps
## that recording in as the new reference log.

const DummyNetworkAdaptor = preload("res://addons/delta_rollback/DummyNetworkAdaptor.gd")
const DeltaRollbackLogger = preload("res://addons/delta_rollback/DeltaRollbackLogger.gd")
const LogData = preload("res://addons/delta_rollback/log_inspector/LogData.gd")

const MATCH_SCENE_PATH_SETTING := 'network/rollback/log_inspector/replay_match_scene_path'
const MATCH_SCENE_METHOD_SETTING := 'network/rollback/log_inspector/replay_match_scene_method'

const ACTION_SPEED_UP := 'replay_speed_up'
const ACTION_SPEED_DOWN := 'replay_speed_down'
const ACTION_PAUSE := 'replay_pause'
const ACTION_NORMAL_SPEED := 'replay_normal_speed'
const ACTION_STEP := 'replay_step'
const ACTION_RESTART := 'replay_restart'
const ACTION_SCREENSHOT := 'replay_screenshot'
const ACTION_STATUS := 'replay_status'
const ACTION_INJECT_ROLLBACKS := 'replay_inject_rollbacks'
const ACTION_TOGGLE_HUD := 'replay_toggle_hud'
const ACTION_TOGGLE_CAMERA := 'replay_toggle_camera'
const ACTION_VIEW_NEXT := 'replay_view_next'
## One action per player of the match, formatted with its number: replay_view_2.
const ACTION_VIEW := 'replay_view_%s'
const ACTION_CAMERA_LEFT := 'replay_camera_left'
const ACTION_CAMERA_RIGHT := 'replay_camera_right'
const ACTION_CAMERA_UP := 'replay_camera_up'
const ACTION_CAMERA_DOWN := 'replay_camera_down'
const ACTION_SUPERTAS := 'replay_supertas'
const ACTION_OVERWRITE := 'replay_overwrite'
const ACTION_TAS := 'replay_tas'

## Physical keys bound to each action when the project doesn't define it.
const DEFAULT_BINDINGS := {
	ACTION_SPEED_UP: [KEY_N, KEY_KP_ADD],
	ACTION_SPEED_DOWN: [KEY_B, KEY_KP_SUBTRACT],
	ACTION_PAUSE: [KEY_KP_MULTIPLY],
	ACTION_NORMAL_SPEED: [KEY_M, KEY_KP_0],
	ACTION_STEP: [KEY_PERIOD, KEY_KP_PERIOD, KEY_KP_DIVIDE],
	ACTION_RESTART: [KEY_R],
	ACTION_SCREENSHOT: [KEY_P, KEY_KP_5],
	ACTION_STATUS: [KEY_KP_7],
	ACTION_INJECT_ROLLBACKS: [KEY_KP_8],
	ACTION_TOGGLE_HUD: [KEY_H],
	ACTION_TOGGLE_CAMERA: [KEY_C],
	ACTION_VIEW_NEXT: [KEY_TAB],
	ACTION_CAMERA_LEFT: [KEY_LEFT],
	ACTION_CAMERA_RIGHT: [KEY_RIGHT],
	ACTION_CAMERA_UP: [KEY_UP],
	ACTION_CAMERA_DOWN: [KEY_DOWN],
	ACTION_SUPERTAS: [KEY_Y],
	ACTION_OVERWRITE: [KEY_O],
	ACTION_TAS: [KEY_SHIFT],
}

## How many players the replay_view_N actions cover.
const VIEW_COUNT := 10

## Group SyncManager puts the nodes that provide input into, once started.
## Label only: input nodes live in SyncManager's registry, not in a group.
const INPUT_GROUP := 'network_sync_input'

## Emitted once the match has been set up and inputs start being replayed.
signal replay_started ()
## Emitted after the state has been reloaded from the log (see [method load_tick]
## and the overwrite command), so the game can reset whatever state loading
## doesn't cover.
signal replay_reloaded ()
## Emitted when the replay is watched through another player's eyes.
signal view_changed (player_node, peer_id)

@export_file("*.log") var replay_file_path: String
## Used when [member replay_file_path] is empty: the most recent log of that
## directory is replayed (logs recorded by this tool are skipped). When it is of
## a peer who joined the match in progress, the log of a peer who played from
## the start of that match is replayed instead, if there is one.
@export_dir var log_directory: String
## Scene instantiated to host the match, when this node is not already inside
## one. Leave empty to use the project setting used by the Log Inspector.
@export_file("*.tscn", "*.scn") var match_scene_path: String
## Method called on the match scene, with (my_peer_id, peer_ids, match_info).
@export var match_scene_method := ""
## Peer id used locally while replaying. It must NOT be one of the recorded
## peers, so that our own local input never overwrites a replayed input.
@export var replay_peer_id := 65536
## How many ticks of input are queued ahead of SyncManager. Must be >= 1.
@export var input_lead := 2
## Seconds to wait between setting the match up and starting SyncManager.
@export var start_delay := 0.0
## Call SyncManager.start() after the match scene has been set up. Turn off if
## the match scene starts SyncManager itself.
@export var auto_start := true
## Autoload singletons to remove before replaying (debug menus, analytics...).
@export var autoloads_to_disable: PackedStringArray = []

@export_group("Playback")
## Replay at full speed up to this tick, then drop back to normal speed. 0 to
## always play at normal speed.
@export var ticks_forward := 0
@export var fast_forward_fps := 120
@export var fast_forward_time_scale := 8.0
## Physics ticks per second used at normal speed. 0 uses the project setting.
@export var normal_fps := 0
## Jump to this tick before replaying (requires a state logged for that tick).
@export var start_tick := 0
## Ticks of rollback injected by the KP 8 key, to surface state that isn't
## saved and loaded properly.
@export var injected_rollback_ticks := 10

@export_group("TAS")
## Record what is replayed to <replay_file_path>_next.log, so that a run redone
## by hand can be saved over the original with replay_overwrite. Taking the
## input over does not need it: holding replay_tas, or SUPER-TAS, is enough.
@export var record_replay := false
## Action that hands control of [member tas_peer_id] to the keyboard while it is
## held. Point it at one of the game's own actions to use that instead.
@export var tas_hold_action: String = ACTION_TAS
## Peer whose input can be overridden. 0 picks the peer that recorded the log,
## and watching a player (replay_view_N) hands TAS over to that player's peer.
@export var tas_peer_id := 0
## Suffix of the log recorded while replaying.
@export var recorded_log_suffix := "_next"
## Group whose nodes get [member reset_method] called after a state reload.
@export var reset_group := ""
@export var reset_method := "reset"

@export_group("Debug view")
@export var show_hud := true
## Takes the view over with a Camera2D of ours, following the watched player and
## pannable around them with the camera actions (arrow keys) at [member
## camera_pan_speed]. replay_toggle_camera (C) turns it on and off.
@export var free_camera := false
## Nodes the replay_view_N actions pick from. Empty uses the nodes that produced
## the recorded input, which is what a player is as far as rollback is concerned.
@export var player_group := ""
## Player to watch as soon as the replay starts, 0 to leave the game's own view
## alone until a view action is pressed.
@export var initial_view := 0
## Pixels per second the free camera pans at, at a zoom of 1.
@export var camera_pan_speed := 800.0

var log_data
## True once a log has been loaded and is being replayed. Everything this node
## does is gated on it: without a log it stays inert.
var replaying := false
## Node the match runs in.
var match_scene: Node
var match_info := {}
## Peers whose recorded input is replayed.
var peer_ids := []
## Peer we stand in for: it is passed to the match scene as its own peer id,
## and it is the peer the keyboard takes over in TAS mode.
var log_peer_id := 0
## Tick we are currently queueing input for: a tick of the log, which the
## simulation goes by too, even after seeking (see [method load_tick]).
var tick := 1
## Path of the log recorded while replaying (TAS mode).
var recording_path := ""
var supertas_mode := false
var overwrite_pressed := false
## Index in [method get_player_nodes] of the player currently being watched.
var view_index := 0
var fps := 60.0

var _hud: CanvasLayer
var _status_label: Label
var _warning_label: Label
var _view_node: Node
var _camera: Camera2D
var _game_camera: Camera2D
var _camera_target: Node2D
var _camera_offset := Vector2.ZERO
var _load_error := ""
var _took_over := false
var _fast_forward_done := false
var _seeked := false
var _default_fps := 60
var _default_max_physics_steps := 8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	if Engine.is_editor_hint():
		return

	_register_default_actions()
	if not InputMap.has_action(tas_hold_action):
		push_warning("[LogReplayer] No such input action: %s" % tas_hold_action)

	_default_fps = Engine.physics_ticks_per_second
	_default_max_physics_steps = Engine.max_physics_steps_per_frame
	fps = _get_normal_fps()

	# When the Log Inspector's replay server drives this session, SyncReplay is
	# in charge and we must stay out of the way.
	var sync_replay := get_node_or_null("/root/SyncReplay")
	if sync_replay and sync_replay.get("active"):
		return

	for autoload_name in autoloads_to_disable:
		var autoload := get_node_or_null("/root/" + autoload_name)
		if is_instance_valid(autoload):
			autoload.queue_free()

	if show_hud:
		_create_hud()

	replaying = true

	# Everything below has to happen before the match scene's _ready(): when we
	# are a node of that scene, ours runs first (children are ready first), and
	# it must not start a match of its own.
	_resolve_match_scene()
	if match_scene and match_scene.has_method("set_launched_from_replay"):
		match_scene.call("set_launched_from_replay")
	_take_over_sync_manager()

	var loaded: bool = await _load_log_data()
	if not loaded:
		return

	peer_ids = _collect_input_peer_ids()
	if peer_ids.is_empty():
		_fail("No input found in %s" % replay_file_path)
		return
	_resolve_peer_roles()
	match_info = log_data.match_info.duplicate(true)

	var ready_to_start: bool = await _setup_match()
	if not ready_to_start:
		return

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if auto_start and not SyncManager.started:
		SyncManager.start()


## Adds every action this node reacts to, unless the project defines its own
## binding for it.
func _register_default_actions() -> void:
	for action in DEFAULT_BINDINGS:
		_register_action(action, DEFAULT_BINDINGS[action])
	for view_number in range(1, VIEW_COUNT + 1):
		# replay_view_1 on the 1 key, and replay_view_10 on the 0 key.
		_register_action(ACTION_VIEW % view_number, [KEY_0 + (view_number % 10)])


## What to call an action on screen: the key it is bound to, as labelled on the
## user's keyboard layout, since every binding here can be remapped.
func get_action_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event: InputEventKey = event
			if key_event.physical_keycode != KEY_NONE:
				return OS.get_keycode_string(
					DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode))
			return OS.get_keycode_string(key_event.keycode)
		return event.as_text()
	return action


func _register_action(action: String, physical_keycodes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in physical_keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _default_fps
	Engine.max_physics_steps_per_frame = _default_max_physics_steps
	if is_inside_tree():
		get_tree().paused = false

	if _took_over:
		# Whatever comes next, a menu or another match, gets a SyncManager that
		# logs and ticks again. Its network adaptor is not restored: installing
		# ours freed the previous one, so the game sets its own when it starts a
		# match, as it does on its first one.
		SyncManager.stop_logging()
		SyncManager.stop()
		SyncManager.mechanized_replay = false
		SyncManager.set_physics_process(true)
		_took_over = false


#
# Loading
#

## Returns the log to replay: [member replay_file_path], or the most recent log
## of [member log_directory] when no path is set.
func _resolve_replay_file_path() -> String:
	if not replay_file_path.is_empty():
		return replay_file_path
	if log_directory.is_empty():
		return ""

	var recorded_suffix: String = recorded_log_suffix + ".log"
	var modified_times := {}
	var newest := ""
	for file_name in DirAccess.get_files_at(log_directory):
		if not file_name.ends_with(".log") or file_name.ends_with(recorded_suffix):
			continue
		var path: String = log_directory.path_join(file_name)
		modified_times[path] = int(FileAccess.get_modified_time(path))
		if newest.is_empty() or modified_times[path] > modified_times[newest]:
			newest = path
	if newest.is_empty():
		return ""

	# A peer who joined the match in progress logs from the tick it joined:
	# replay the log of a peer who played from the start, of the same match,
	# instead. The logs don't say which match they are of, but those of a
	# match overlap in time: each starts with the match or the join, and is
	# last written when the match ends.
	var newest_start := _read_log_start(newest)
	if not newest_start.is_empty() and not newest_start.from_start:
		var match_log := ""
		for path in modified_times:
			if modified_times[path] < newest_start.time:
				continue
			var start := _read_log_start(path)
			if start.is_empty() or not start.from_start or start.time > modified_times[newest]:
				continue
			if match_log.is_empty() or modified_times[path] > modified_times[match_log]:
				match_log = path
		if not match_log.is_empty():
			print("[LogReplayer] The most recent log of %s, %s, is of a peer who joined the match in progress: replaying %s, of a peer who played from the start" % [log_directory, newest.get_file(), match_log.get_file()])
			return match_log
	print("[LogReplayer] Replaying the most recent log of %s: %s" % [log_directory, newest.get_file()])
	return newest


## Reads how a log starts, from its first frame: when (in seconds of system
## time) and whether from the start of the match, or from a join. Empty if the
## log has no frame.
func _read_log_start(path: String) -> Dictionary:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_FASTLZ)
	if not file:
		return {}
	# The header, then the events of a join's snapshot come before any frame.
	while file.get_length() - file.get_position() >= 4:
		var data = file.get_var()
		if data is Dictionary and data.get("log_type") == DeltaRollbackLogger.LogType.FRAME:
			return {
				from_start = int(data.get("tick", 0)) <= 0,
				time = int(data.get("start_time", 0)) / 1000,
			}
	return {}


func _load_log_data() -> bool:
	replay_file_path = _resolve_replay_file_path()
	if replay_file_path.is_empty():
		_fail("No log to replay: set replay_file_path or log_directory")
		return false
	log_data = LogData.new()
	_load_error = ""
	log_data.load_error.connect(_on_load_error)
	log_data.load_log_file(replay_file_path)

	# LogData always parses on a thread, and clears the flag on every code path.
	while log_data.is_loading():
		await get_tree().process_frame
	# It clears that flag before its deferred load_error reaches us, and that
	# error says a lot more than the empty log it leaves behind.
	await get_tree().process_frame

	if _load_error != "":
		_fail(_load_error)
		return false
	if log_data.input.is_empty():
		_fail("No input logged in %s" % replay_file_path)
		return false
	return true


func _on_load_error(message: String) -> void:
	_load_error = message


func _collect_input_peer_ids() -> Array:
	var found := {}
	for logged_tick in log_data.input:
		for peer_id in log_data.input[logged_tick].input:
			found[int(peer_id)] = true
	found.erase(replay_peer_id)
	var ids: Array = found.keys()
	if ids.is_empty():
		ids = log_data.peer_ids.duplicate()
	ids.sort()
	return ids


func _resolve_peer_roles() -> void:
	# Stand in for the peer that wrote the log, like the Log Inspector's replay
	# does: the match scene expects one of the recorded peer ids, not the dummy
	# id we use locally.
	if log_data.peer_ids.size() > 0 and peer_ids.has(int(log_data.peer_ids[0])):
		log_peer_id = int(log_data.peer_ids[0])
	else:
		log_peer_id = peer_ids[0]

	if tas_peer_id > 0 and not peer_ids.has(tas_peer_id):
		push_warning("[LogReplayer] Peer %s has no input in the log, TAS'ing peer %s instead" % [tas_peer_id, log_peer_id])
		tas_peer_id = 0
	if tas_peer_id <= 0:
		tas_peer_id = log_peer_id


## The match scene is the scene we are part of, if any: a replay scene is
## usually just an inherited match scene with this node added to it.
func _resolve_match_scene() -> void:
	if get_parent() == get_tree().root:
		# A scene (or autoload) of our own: we'll instantiate the match instead.
		return
	match_scene = owner if owner else get_parent()


func _take_over_sync_manager() -> void:
	_took_over = true
	SyncManager.stop()
	SyncManager.clear_peers()
	SyncManager.network_adaptor = DummyNetworkAdaptor.new(replay_peer_id)
	# NB: mechanized_replay is set directly instead of going through
	# set_mechanized(): we want SyncManager to keep running its own
	# _physics_process() and simulate the match, we only replace the input it
	# would have received from the network. The recorded peers are deliberately
	# *not* added with add_peer(), so SyncManager never waits on them.
	SyncManager.mechanized_replay = true

	if not SyncManager.sync_started.is_connected(_on_sync_started):
		SyncManager.sync_started.connect(_on_sync_started)


func _setup_match() -> bool:
	var method: String = match_scene_method
	if method.is_empty():
		method = ProjectSettings.get_setting(MATCH_SCENE_METHOD_SETTING, "setup_match_for_replay")

	if match_scene == null:
		var scene_path: String = match_scene_path
		if scene_path.is_empty() and ProjectSettings.has_setting(MATCH_SCENE_PATH_SETTING):
			scene_path = ProjectSettings.get_setting(MATCH_SCENE_PATH_SETTING)
		if scene_path.is_empty():
			_fail("No match scene: add this node to a scene inheriting from one, or set match_scene_path")
			return false
		var packed_scene = load(scene_path)
		if packed_scene == null:
			_fail("Unable to load match scene: %s" % scene_path)
			return false
		var tree := get_tree()
		var previous_scene := tree.current_scene
		if previous_scene and previous_scene != self and not is_ancestor_of(previous_scene):
			previous_scene.queue_free()
		match_scene = packed_scene.instantiate()
		if match_scene.has_method("set_launched_from_replay"):
			match_scene.call("set_launched_from_replay")
		tree.root.add_child(match_scene)
		tree.current_scene = match_scene

	# Its own _ready() has to have run before we set it up.
	if not match_scene.is_node_ready():
		await match_scene.ready

	if not match_scene.has_method(method):
		_fail("Match scene %s has no such method: %s" % [match_scene.name, method])
		return false

	if not match_scene.has_method("set_replay_view"):
		push_warning("[LogReplayer] %s has no set_replay_view(player_node, peer_id): watching a player cannot move the view, press C for the free camera" % match_scene.name)

	# Same arguments as the Log Inspector's replay: the peer whose log we are
	# replaying, then the other peers of the match.
	var other_peer_ids := peer_ids.duplicate()
	other_peer_ids.erase(log_peer_id)
	match_scene.call(method, log_peer_id, other_peer_ids, match_info)
	return true


## Says what happened where the user is looking, not only in the console.
func _warn_on_screen(message: String, as_error := false) -> void:
	if as_error:
		push_error("[LogReplayer] " + message)
	else:
		print("[LogReplayer] " + message)
	if _warning_label:
		_warning_label.text = message
		_warning_label.show()


func _fail(message: String) -> void:
	replaying = false
	push_error("[LogReplayer] " + message)
	if _warning_label:
		_warning_label.text = message
		_warning_label.show()


#
# Replaying
#

func _on_sync_started() -> void:
	tick = 1
	# A log recorded from a seek and saved over the reference starts there.
	var from_tick := maxi(start_tick, _first_logged_tick())
	if from_tick > 0 and not _seeked:
		_seeked = true
		load_tick(from_tick)
	_schedule_logged_joins()
	if record_replay:
		_start_recording()
	_check_logged_paths()
	_prime_input_lead()
	if initial_view > 0:
		set_view(initial_view - 1)
	replay_started.emit()


## Recorded input and state are keyed by absolute node path, so a scene whose
## nodes sit elsewhere than when the log was recorded replays as if every player
## stood still. Renaming the scene's root is all it takes, so say it out loud
## rather than let the replay look broken.
func _check_logged_paths() -> void:
	for logged_tick in log_data.input:
		var peers_input: Dictionary = log_data.input[logged_tick].input
		for peer_id in peers_input:
			var missing := PackedStringArray()
			var paths := 0
			for key in peers_input[peer_id]:
				var node_path := String(key)
				# "$" holds the input's hash, keys starting with "_" are left
				# out of hashing, and "@join" says when a peer who joined plays:
				# none of them addresses a node.
				if node_path == "$" or node_path.begins_with("_") or node_path == SyncManager.JOIN_INPUT_KEY:
					continue
				paths += 1
				if get_node_or_null(NodePath(node_path)) == null:
					missing.append(node_path)
			if paths == 0:
				# Nobody pressed anything on this tick, try the next one.
				continue
			if not missing.is_empty():
				_warn_on_screen("The log's input is addressed to %s, which this scene has no node for. Recorded input and state go by absolute node path: the replayed scene has to keep the node names, the root's included, that it had when the log was recorded." % ", ".join(missing), true)
			# One sampled tick is enough to tell whether the paths line up.
			return


## Queues the first ticks of input so that we always stay ahead of SyncManager.
func _prime_input_lead() -> void:
	# Playing from a new point, so a fast forward to ticks_forward is due again.
	_fast_forward_done = false
	for _i in maxi(input_lead, 1):
		_physics_process(0.0)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not replaying or not SyncManager.started:
		return
	if get_tree().paused:
		return

	if ticks_forward > 0 and not _fast_forward_done:
		if tick < ticks_forward:
			set_speed(fast_forward_fps, fast_forward_time_scale, false)
		else:
			# Not "== ticks_forward": a step can carry the tick past it, and the
			# replay would stay at the fast forward speed for good.
			_fast_forward_done = true
			set_speed(_get_normal_fps(), 1.0, false)

	if supertas_mode:
		# The match only moves while the keyboard says something: it is frozen
		# when nothing is held, and advances a tick per frame otherwise, which
		# is how a run gets authored input by input. Holding replay_tas advances
		# it with no input at all.
		# NB: this needs _get_local_input() to return {} when the player is
		# doing nothing, which is the convention as it also saves bandwidth.
		if _tas_live_input().is_empty() and not _is_tas_pressed():
			return
		SyncManager._physics_process(delta)

	_queue_tick_input()


## Queues one tick of recorded (or TAS'd) input for every replayed peer.
func _queue_tick_input() -> void:
	var input_frame = SyncManager._get_or_create_input_frame(tick)
	var logged_input := {}
	if log_data.input.has(tick):
		logged_input = log_data.input[tick].input

	var tas_active: bool = supertas_mode or _is_tas_pressed()
	for peer_id in peer_ids:
		var input := _logged_input_for(logged_input, peer_id)
		if tas_active and peer_id == tas_peer_id:
			input = _tas_input(input)
		input_frame.add_input_for_player(peer_id, input, false)

	# Complete input never comes in from the network here, so flag it ourselves.
	SyncManager._update_input_complete_tick()
	tick += 1

	# Once the log's last tick has been queued too.
	if tick - 1 > log_data.max_tick and overwrite_pressed:
		# Deferred: it reloads the log file, don't do that mid-tick.
		call_deferred("_overwrite_now")


## What the keyboard is saying, as the input of the player being watched. The
## other players of that peer are left alone: in a local match one peer owns
## several of them, and only the one on screen should answer to the keyboard.
func _tas_live_input() -> Dictionary:
	var live: Dictionary = SyncManager.sync_booster.call_get_local_input(tas_peer_id)
	if not is_instance_valid(_view_node):
		# No player picked yet: the whole peer answers, as the log recorded it.
		return live
	var node_path := String(_view_node.get_path())
	var input := {}
	if live.has(node_path):
		input[node_path] = live[node_path]
	return input


## The peer's recorded input for this tick, with the watched player's part
## replaced by the keyboard's, empty included so that letting go stands still.
func _tas_input(logged: Dictionary) -> Dictionary:
	var live := _tas_live_input()
	if not is_instance_valid(_view_node):
		return live
	var node_path := String(_view_node.get_path())
	var input := logged.duplicate(true)
	if live.has(node_path):
		input[node_path] = live[node_path]
	else:
		input.erase(node_path)
	return input


func _logged_input_for(logged_input: Dictionary, peer_id: int) -> Dictionary:
	if logged_input.has(peer_id):
		return logged_input[peer_id]
	# Some serializers turn integer keys into strings.
	if logged_input.has(str(peer_id)):
		return logged_input[str(peer_id)]
	return {}


func _is_tas_pressed() -> bool:
	return InputMap.has_action(tas_hold_action) and Input.is_action_pressed(tas_hold_action)


## Changes how fast the replay runs. The simulation itself is unaffected:
## SyncManager keeps using the tick duration it was started with.
func set_speed(p_fps: float, time_scale: float, paused: bool) -> void:
	if not SyncManager.started:
		return
	fps = maxf(p_fps, 1.0)
	Engine.physics_ticks_per_second = int(fps)
	Engine.time_scale = time_scale
	# Godot only runs a handful of physics steps per rendered frame by default,
	# which would silently cap fast-forward.
	Engine.max_physics_steps_per_frame = maxi(_default_max_physics_steps, ceili(fps * time_scale / 30.0))
	get_tree().paused = paused
	set_physics_process(not paused)


## Plays the log again from the beginning, or from [member start_tick].
func restart() -> void:
	if not replaying:
		return
	load_tick(maxi(start_tick, _first_logged_tick()))
	# A run being recorded starts over as well, so that the two stay in step.
	_start_recording()
	_notify_reloaded()
	_prime_input_lead()


## Simulates exactly one tick, pausing the replay first. Handy to inspect a
## desync or a physics glitch tick by tick.
func step_tick() -> void:
	if not SyncManager.started:
		return
	if not get_tree().paused:
		set_speed(fps, Engine.time_scale, true)
	SyncManager._physics_process(SyncManager.tick_time)
	_queue_tick_input()
	print("[LogReplayer] stepped to tick %s" % SyncManager.current_tick)


func _get_normal_fps() -> int:
	if normal_fps > 0:
		return normal_fps
	return int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))


#
# State loading
#

## The first tick with a state logged: 0, but for a log recorded from
## start_tick, which has none before.
func _first_logged_tick() -> int:
	return log_data.state.keys().min() if not log_data.state.is_empty() else 0


## Rewinds (or fast forwards) the match to a tick that has a state logged for
## it. The match goes on from there with the log's tick numbers, which the
## state holds (timeouts, animation starts...).
func load_tick(tick_number: int) -> void:
	var state_data = log_data.state.get(tick_number, null)
	if state_data == null:
		push_error("[LogReplayer] No state logged for tick %s" % tick_number)
		return

	var state: Dictionary = state_data.state
	var events: Dictionary = SyncManager.get_events_up_to_tick(tick_number, state.duplicate(), log_data.events, log_data._events_scripts)
	state = SyncManager.sync_booster.unserialize(state)
	events = SyncManager.sync_booster.unserialize(events)
	# For the forward load check, which rebuilds the spawned nodes from all the
	# events, those before the seek included.
	var past_events = null
	if SyncManager.debug_check_local_state_consistency_forward:
		past_events = {}
		for path in log_data.events:
			var by_tick := {}
			for logged_tick in log_data.events[path]:
				if logged_tick <= tick_number:
					by_tick[logged_tick] = SyncManager.sync_booster.unserialize(log_data.events[path][logged_tick])
			past_events[path] = by_tick
	SyncManager._start_from_state(state, events, tick_number, past_events, log_data._events_scripts.duplicate())
	_schedule_logged_joins()
	tick = tick_number + 1


## The peers who joined the match in progress to play: SyncManager emits
## player_joined on the tick each plays from. All of them, whatever the tick
## the replay starts or seeks to, the host's input saying so maybe before it.
func _schedule_logged_joins() -> void:
	for logged_tick in log_data.input:
		var peers_input: Dictionary = log_data.input[logged_tick].input
		for peer_id in peers_input:
			var input: Dictionary = peers_input[peer_id]
			if input.has(SyncManager.JOIN_INPUT_KEY):
				SyncManager._schedule_player_joins(input[SyncManager.JOIN_INPUT_KEY])


func _notify_reloaded() -> void:
	if not reset_group.is_empty() and not reset_method.is_empty():
		for node in get_tree().get_nodes_in_group(reset_group):
			if node.has_method(reset_method):
				node.call(reset_method)
	replay_reloaded.emit()


#
# TAS recording
#

func _start_recording() -> void:
	if not record_replay:
		return
	recording_path = "%s%s.%s" % [replay_file_path.get_basename(), recorded_log_suffix, replay_file_path.get_extension()]
	# SyncManager.start_logging() refuses to log while mechanized_replay is set;
	# the flag is only read when logging starts, so flip it off for the call.
	var was_replaying: bool = SyncManager.mechanized_replay
	SyncManager.mechanized_replay = false
	SyncManager.start_logging(recording_path, match_info.duplicate(true))
	SyncManager.mechanized_replay = was_replaying
	_record_log_before(tick - 1)


## A recording from a seek starts with what the log has before it: its input,
## states and events up to the seek, so that it replays from its start as the
## log did (a forward load needs the events since the start), and overwriting
## the log with it loses nothing. SyncManager logs the rest: the seek tick's
## state, then everything after.
func _record_log_before(seek_tick: int) -> void:
	var logger = SyncManager._logger
	# From the log's first tick on: its events and scripts, which SyncManager
	# doesn't log for the seek tick.
	if logger == null or seek_tick < _first_logged_tick():
		return
	var booster = SyncManager.sync_booster
	# As SyncManager logs them.
	var script_frame = SyncManager.EventBufferFrame.new(0, {})
	for node_path in log_data._events_scripts:
		var script = log_data._events_scripts[node_path]
		script_frame._add_script_event(node_path, script if script is String else script.resource_path)
	var scripts: Array = script_frame.data.get("", [])
	var events_by_tick := {}
	for path in log_data.events:
		for logged_tick in log_data.events[path]:
			if logged_tick <= seek_tick:
				var at_tick: Dictionary = events_by_tick.get(logged_tick, {})
				at_tick[path] = log_data.events[path][logged_tick]
				events_by_tick[logged_tick] = at_tick
	for logged_tick in range(_first_logged_tick(), seek_tick + 1):
		if log_data.input.has(logged_tick):
			var players := {}
			var logged_input: Dictionary = log_data.input[logged_tick].input
			for peer_id in logged_input:
				players[peer_id] = [booster.unserialize(logged_input[peer_id])]
			logger.write_input(logged_tick, players)
		if logged_tick < seek_tick and log_data.state.has(logged_tick):
			logger.write_state(logged_tick, booster.unserialize(log_data.state[logged_tick].state))
		var events: Dictionary = booster.unserialize(events_by_tick.get(logged_tick, {}))
		if not scripts.is_empty():
			# Once, first: the scripts that prepare each node's events.
			events[""] = scripts
			scripts = []
		logger.write_event(logged_tick, events)


## Replaces the log being replayed with the one recorded so far, then restarts
## the replay from it. This is how a TAS'd run becomes the new reference.
func _overwrite_now() -> void:
	overwrite_pressed = false
	if recording_path.is_empty():
		_warn_on_screen("Nothing was recorded, nothing to overwrite")
		return

	SyncManager.stop_logging()
	set_physics_process(false)

	# Keep the log we are replacing until the replacement is in place, so that a
	# failure here leaves the reference log where it was.
	var backup_path: String = replay_file_path + ".bak"
	DirAccess.remove_absolute(backup_path)
	var err := DirAccess.rename_absolute(replay_file_path, backup_path)
	if err != OK:
		_fail("Unable to move %s out of the way (error %s)" % [replay_file_path, err])
		return
	err = DirAccess.rename_absolute(recording_path, replay_file_path)
	if err != OK:
		DirAccess.rename_absolute(backup_path, replay_file_path)
		_fail("Unable to move %s over %s (error %s), the log is untouched" % [
			recording_path, replay_file_path, err])
		return
	DirAccess.remove_absolute(backup_path)
	recording_path = ""

	var reloaded: bool = await _load_log_data()
	if not reloaded:
		return
	peer_ids = _collect_input_peer_ids()
	load_tick(_first_logged_tick())
	_start_recording()
	_notify_reloaded()

	supertas_mode = false
	SyncManager.set_physics_process(true)
	if _warning_label:
		_warning_label.hide()
	_prime_input_lead()


#
# Controls
#

func _unhandled_input(event: InputEvent) -> void:
	if not replaying or event is InputEventMouseMotion:
		return

	if overwrite_pressed and event.is_action_pressed("ui_cancel"):
		cancel_overwrite()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(ACTION_SPEED_UP):
		set_speed(fps * 2.0, Engine.time_scale * 2.0, false)
	elif event.is_action_pressed(ACTION_SPEED_DOWN):
		if fps / 2.0 > 1.0:
			set_speed(fps / 2.0, Engine.time_scale / 2.0, false)
		else:
			# Can't go any slower: pause instead.
			set_speed(fps, Engine.time_scale, not get_tree().paused)
	elif event.is_action_pressed(ACTION_PAUSE):
		set_speed(fps, Engine.time_scale, not get_tree().paused)
	elif event.is_action_pressed(ACTION_NORMAL_SPEED):
		# Also gives up on a fast forward still in progress.
		_fast_forward_done = true
		set_speed(_get_normal_fps(), 1.0, false)
	elif event.is_action_pressed(ACTION_STEP):
		step_tick()
	elif event.is_action_pressed(ACTION_RESTART):
		restart()
	elif event.is_action_pressed(ACTION_SCREENSHOT):
		_save_screenshot()
	elif event.is_action_pressed(ACTION_STATUS):
		print_status()
	elif event.is_action_pressed(ACTION_INJECT_ROLLBACKS):
		toggle_injected_rollbacks()
	elif event.is_action_pressed(ACTION_SUPERTAS):
		set_supertas_mode(not supertas_mode)
	elif event.is_action_pressed(ACTION_OVERWRITE):
		_on_overwrite_pressed()
	elif event.is_action_pressed(ACTION_TOGGLE_CAMERA):
		free_camera = not free_camera
		if free_camera:
			_ensure_camera()
		else:
			_remove_camera()
	elif event.is_action_pressed(ACTION_TOGGLE_HUD):
		if _hud:
			_hud.visible = not _hud.visible
	elif event.is_action_pressed(ACTION_VIEW_NEXT):
		next_view()
	else:
		var view_number := _get_view_action_number(event)
		if view_number < 1:
			return
		set_view(view_number - 1)
	get_viewport().set_input_as_handled()


## Player number of the replay_view_N action this event triggers, 0 for none.
func _get_view_action_number(event: InputEvent) -> int:
	for view_number in range(1, VIEW_COUNT + 1):
		if event.is_action_pressed(ACTION_VIEW % view_number):
			return view_number
	return 0


func _on_overwrite_pressed() -> void:
	if log_data == null:
		return
	if recording_path.is_empty():
		# Nothing was recorded, so there is nothing to put in the log's place.
		_warn_on_screen("Turn record_replay on to be able to overwrite %s" % replay_file_path.get_file())
		return
	if overwrite_pressed or tick > log_data.max_tick:
		call_deferred("_overwrite_now")
		return
	# Confirm first: this discards everything logged after the current tick.
	# Waiting for the log to run out keeps the ticks that have not been replayed
	# yet, pressing again cuts the log here instead.
	overwrite_pressed = true
	_warn_on_screen("Overwriting %s once its %s remaining ticks have played. %s again to cut it at tick %s instead, escape to cancel." % [
		replay_file_path.get_file(), log_data.max_tick - tick,
		get_action_label(ACTION_OVERWRITE), tick])


## Forgets a pending overwrite, leaving the log alone.
func cancel_overwrite() -> void:
	overwrite_pressed = false
	if _warning_label:
		_warning_label.hide()
	print("[LogReplayer] overwrite cancelled")


func set_supertas_mode(enabled: bool) -> void:
	supertas_mode = enabled
	# In SUPER-TAS mode we call SyncManager._physics_process() ourselves, one
	# tick per input change.
	SyncManager.set_physics_process(not enabled)


## Makes SyncManager roll back every tick, which surfaces state that isn't
## saved and loaded properly (the usual cause of desyncs).
func toggle_injected_rollbacks() -> void:
	if SyncManager.debug_random_rollback_ticks > 0:
		SyncManager.debug_random_rollback_ticks = 0
		# It picks a new debug_rollback_ticks every tick, clear the last one.
		SyncManager.debug_rollback_ticks = 0
	else:
		SyncManager.debug_random_rollback_ticks = injected_rollback_ticks
	print("[LogReplayer] debug_random_rollback_ticks = %s" % SyncManager.debug_random_rollback_ticks)


func print_status() -> void:
	if not SyncManager.started:
		print("[LogReplayer] SyncManager isn't started")
		return
	print("[LogReplayer] tick %s (input tick %s), rollback_ticks %s, skip_ticks %s, %s fps x%.2f%s" % [
		SyncManager.current_tick, SyncManager.input_tick, SyncManager.rollback_ticks,
		SyncManager.skip_ticks, int(fps), Engine.time_scale,
		" [PAUSED]" if get_tree().paused else ""])
	print("    replaying tick %s of %s from %s" % [tick, log_data.max_tick, replay_file_path])
	print("    peers %s, standing in for peer %s" % [peer_ids, log_peer_id])
	var nodes := get_player_nodes()
	if nodes.is_empty():
		print("    no player node found in group '%s' with one of those peers as authority" % (
			player_group if not player_group.is_empty() else INPUT_GROUP))
	for index in nodes.size():
		var node: Node = nodes[index]
		print("    player %s: %s (peer %s)%s" % [index + 1, node.get_path(),
			node.get_multiplayer_authority(), "  <- watching" if node == _view_node else ""])
	for peer in SyncManager.peers.values():
		print("    peer %s: rtt %sms, local lag %s, remote lag %s, advantage %.2f" % [
			peer.peer_id, peer.rtt, peer.local_lag, peer.remote_lag, peer.calculated_advantage])


func _save_screenshot() -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "user://replay_screenshot_%s.png" % SyncManager.current_tick
	if image.save_png(path) == OK:
		print("[LogReplayer] Screenshot saved to %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("[LogReplayer] Unable to save screenshot to %s" % path)


#
# Camera
#

## The players of the replayed match: the nodes that produced the recorded
## input, in a stable order (by peer, then by node path). One peer can own
## several of them, as in a local match played on one keyboard.
func get_player_nodes() -> Array:
	var candidates := (get_tree().get_nodes_in_group(player_group) if not player_group.is_empty()
		else Array(SyncManager.sync_booster.get_input_nodes()))
	var nodes := candidates.filter(
		func (node): return peer_ids.has(node.get_multiplayer_authority()))
	nodes.sort_custom(func (a, b):
		var a_peer: int = a.get_multiplayer_authority()
		var b_peer: int = b.get_multiplayer_authority()
		if a_peer != b_peer:
			return a_peer < b_peer
		return String(a.get_path()) < String(b.get_path()))
	return nodes


## Watches the replay through the eyes of the [param index]th player (0 based).
## What that means is the game's business: a match scene implementing
## [code]set_replay_view(node, peer_id)[/code] gets called and can point its own
## camera wherever it wants. Without it, a Camera2D of ours follows the node.
func set_view(index: int) -> void:
	var nodes := get_player_nodes()
	if nodes.is_empty():
		push_warning("[LogReplayer] No node of the replayed peers to watch")
		return

	view_index = wrapi(index, 0, nodes.size())
	_view_node = nodes[view_index]
	var peer_id: int = _view_node.get_multiplayer_authority()
	# The player being watched is the one the keyboard takes over in TAS.
	tas_peer_id = peer_id
	print("[LogReplayer] watching player %s of %s: %s (peer %s)" % [
		view_index + 1, nodes.size(), _view_node.get_path(), peer_id])
	view_changed.emit(_view_node, peer_id)

	# Whoever we watch is what the free camera follows, when it is turned on.
	_camera_target = _view_node as Node2D
	_camera_offset = Vector2.ZERO

	# The game shows its own view of that player.
	if match_scene and match_scene.has_method("set_replay_view"):
		match_scene.call("set_replay_view", _view_node, peer_id)


## Switches to the next player of the match.
func next_view() -> void:
	set_view(view_index + 1)


## Takes the view over with a Camera2D of our own, starting where the game's
## camera was.
func _ensure_camera() -> void:
	if is_instance_valid(_camera):
		return
	_camera = Camera2D.new()
	_game_camera = get_viewport().get_camera_2d()
	if is_instance_valid(_game_camera):
		_camera.global_position = _game_camera.get_screen_center_position()
		_camera.zoom = _game_camera.zoom
	add_child(_camera)
	_camera.make_current()


## Gives the view back to the game's own camera.
func _remove_camera() -> void:
	if is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	if is_instance_valid(_game_camera):
		_game_camera.make_current()


func _process(delta: float) -> void:
	if not replaying:
		return
	_update_camera(delta)
	_update_hud()


func _update_camera(delta: float) -> void:
	if not is_instance_valid(_camera):
		return

	var pan := Input.get_vector(ACTION_CAMERA_LEFT, ACTION_CAMERA_RIGHT, ACTION_CAMERA_UP, ACTION_CAMERA_DOWN)
	# delta is scaled by Engine.time_scale, panning shouldn't be.
	var step: float = delta / maxf(Engine.time_scale, 0.001)
	# Divided by the zoom so that panning covers the same screen distance.
	_camera_offset += pan * camera_pan_speed * step / maxf(_camera.zoom.x, 0.001)

	var origin := Vector2.ZERO
	if is_instance_valid(_camera_target):
		origin = _camera_target.global_position
	_camera.global_position = origin + _camera_offset


#
# HUD
#

func _create_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 128
	add_child(_hud)
	var box := VBoxContainer.new()
	box.position = Vector2(12, 8)
	_hud.add_child(box)
	_status_label = _create_label(Color.WHITE)
	box.add_child(_status_label)
	_warning_label = _create_label(Color(1.0, 0.45, 0.35))
	_warning_label.hide()
	box.add_child(_warning_label)


func _create_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _update_hud() -> void:
	if not _status_label or not _hud.visible or log_data == null:
		return

	var flags := PackedStringArray()
	if get_tree().paused:
		flags.append("PAUSED")
	if supertas_mode:
		flags.append("SUPER-TAS")
	elif _is_tas_pressed():
		flags.append("TAS")
	if not recording_path.is_empty():
		flags.append("REC")
	if is_instance_valid(_view_node):
		flags.append("watching %s (peer %s)" % [
			_view_node.name, _view_node.get_multiplayer_authority()])

	_status_label.text = "tick %s / %s   %s fps x%.2f   %s" % [
		tick, log_data.max_tick, int(fps), Engine.time_scale, " ".join(flags)]
