@tool
extends Node

const PropertyManagerScript = preload("res://addons/delta_rollback/PropertyManager.gd")
const SpawnManager = preload("res://addons/delta_rollback/SpawnManager.gd")
const EffectManager = preload("res://addons/delta_rollback/EffectManager.gd")
const NetworkAdaptor = preload("res://addons/delta_rollback/NetworkAdaptor.gd")
const MessageSerializer = preload("res://addons/delta_rollback/MessageSerializer.gd")
const DeltaRollbackLogger = preload("res://addons/delta_rollback/DeltaRollbackLogger.gd")
const DebugStateComparer = preload("res://addons/delta_rollback/DebugStateComparer.gd")

class Peer extends RefCounted:
	var peer_id: int
	# Watches the match without playing in it (see add_peer()).
	var spectator := false
	# A spectator joining a match in progress (request_join()): it loads the
	# match from a tick, then catches up. Not dropped for being behind until it
	# is in sync (late_join_synced), only for making no progress
	# (LATE_JOIN_TIMEOUT_MSECS): for not getting less behind, once it loaded.
	var joining := false
	var join_tick := 0
	# The first tick it plays: 0 for the players the match started with, the
	# tick a joiner became one at (request_join(true)). Not a player before it.
	var player_from_tick := 0
	var join_least_behind := 0
	var join_progress_msecs := 0
	# A joiner sent nothing until it says it loaded the match: the same ticks
	# every tick would compete with the snapshot.
	var join_heard := false
	# Its request's id (from the host's pin, on the players): told with it that the match stopped,
	# not with a remote stop, which an attempt of its later could take.
	var join_id := 0
	# When a spectator last sent us anything: one silent for
	# LATE_JOIN_TIMEOUT_MSECS is gone (0: not yet counted).
	var heard_msecs := 0
	
	var rtt: int
	var last_ping_received: int
	var time_delta: float
	
	var last_remote_input_tick_received: int = 0
	var next_local_input_tick_requested: int = 1
	var last_remote_hash_tick_received: int = 0
	var next_local_hash_tick_requested: int = 1
	
	var remote_lag: int
	var local_lag: int
	
	var calculated_advantage: float
	var advantage_list := []
	
	func _init(_peer_id: int, _spectator := false) -> void:
		peer_id = _peer_id
		spectator = _spectator
	
	# Returns whether a new average was calculated.
	func record_advantage(ticks_to_calculate_advantage: int) -> bool:
		advantage_list.append(local_lag - remote_lag)
		if advantage_list.size() >= ticks_to_calculate_advantage:
			var total: float = 0
			for x in advantage_list:
				total += x
			calculated_advantage = total / advantage_list.size()
			advantage_list.clear()
			return true
		return false
	
	func clear_advantage() -> void:
		calculated_advantage = 0.0
		advantage_list.clear()
	
	func clear() -> void:
		rtt = 0
		last_ping_received = 0
		time_delta = 0
		last_remote_input_tick_received = 0
		next_local_input_tick_requested = 0
		last_remote_hash_tick_received = 0
		next_local_hash_tick_requested = 0
		remote_lag = 0
		local_lag = 0
		clear_advantage()
		# A joiner is one no longer: those that played are spectators again
		# (see _on_received_remote_stop()).
		joining = false
		join_tick = 0
		player_from_tick = 0
		join_least_behind = 0
		join_progress_msecs = 0
		join_heard = false
		join_id = 0
		heard_msecs = 0

# The state hash of a tick whose state was not saved (_can_skip_state()).
const SKIPPED_STATE_HASH := -1

class StateBufferFrame:
	var tick: int
	var data: Dictionary
	# Not saved (see _can_skip_state()): data is empty, and the frame only
	# keeps the buffer's one frame per tick.
	var skipped := false

	func _init(_tick, _data) -> void:
		tick = _tick
		data = _data

class StateHashFrame:
	var tick: int
	var state_hash: int
	
	var peer_hashes := {}
	var mismatch := false
	
	func _init(_tick: int, _state_hash: int) -> void:
		tick = _tick
		state_hash = _state_hash
	
	func record_peer_hash(peer_id: int, peer_hash: int) -> bool:
		peer_hashes[peer_id] = peer_hash
		# SKIPPED_STATE_HASH on either side: that peer did not save this tick.
		if peer_hash == SKIPPED_STATE_HASH or state_hash == SKIPPED_STATE_HASH:
			return true
		if peer_hash != state_hash:
			mismatch = true
			return false
		return true
	
	func has_peer_hash(peer_id: int) -> bool:
		return peer_hashes.has(peer_id)
	
	func is_complete(peers: Dictionary) -> bool:
		for peer_id in peers:
			if not peer_hashes.has(peer_id):
				return false
		return true
	
	func get_missing_peers(peers: Dictionary) -> Array:
		var missing := []
		for peer_id in peers:
			if not peer_hashes.has(peer_id):
				missing.append(peer_id)
		return missing

class EventBufferFrame:
	var tick: int
	var data: Dictionary

	func _init(_tick, _data) -> void:
		tick = _tick
		data = _data
	
	func _add_script_event(node_path: String, script_path: String) -> void:
		if not data.has(""):
			data[""] = []
		data[""].append({
			type = "script",
			node_path = node_path,
			script_path = script_path
		})

enum LoadType {
	ROLLBACK,
	INTERPOLATION_BACKWARD,
	INTERPOLATION_FORWARD,
}

const DEFAULT_NETWORK_ADAPTOR_PATH := "res://addons/delta_rollback/RPCNetworkAdaptor.gd"
const DEFAULT_MESSAGE_SERIALIZER_PATH := "res://addons/delta_rollback/MessageSerializer.gd"
const SYNC_DEBUGGER_PATH = "res://addons/delta_rollback/SyncDebugger.gd"

var network_adaptor: NetworkAdaptor:
	set = set_network_adaptor
var message_serializer: MessageSerializer:
	set = set_message_serializer
var sync_booster: = SyncBooster.new()

var peers := {}
# The peers that play, spectators left out: only they have input and state
# hashes to wait for.
var _player_peers := {}
## Set before the match starts, to watch it without playing: no input is
## gathered nor sent, and the players never wait for us.
var spectating := false:
	set(value):
		# Only a joiner becoming a player (_become_player()) changes it during a
		# match.
		if started and not _becoming_player:
			push_warning("Cannot change spectating after sync'ing has already started")
			return
		spectating = value
var _becoming_player := false
var input_buffer := []
var state_buffer := []
var state_hashes := []
var event_buffer := []
var mechanized := false:
	set = set_mechanized
var mechanized_replay := false
var mechanized_input_received := {}
var mechanized_rollback_ticks := 0

var max_buffer_size := 20
## Rollback deferral: a rollback this peer is too slow to do at once can be
## put off for up to this many ticks, and done as one longer rollback, which
## re-simulates fewer ticks in all. The result is the same, as a rollback always
## starts from the first mispredicted tick: only when this peer shows the
## correction changes. 0 turns it off.
##
## Deferring does not make a rollback shorter: it merges the ones that come on
## consecutive ticks, as when a peer's inputs keep arriving late and
## mispredicted. If each of them takes longer than a frame has, every frame is
## late; put off for D ticks, one frame in D is.
var max_rollback_deferral_ticks := 0
## A rollback is put off while it would take longer than this, as estimated
## from the time the last ones took per tick re-simulated, and only if the
## previous tick asked for one too: rollbacks that recur are what deferring
## merges. One after ticks without any (the inputs a packet loss held back,
## arriving at once) is done at once, before it grows.
##
## 0 adapts it to what frames have room for, which rendering decides as much as
## the simulation, and which cannot be measured directly (the wait for vsync
## hides it): from half a frame, a frame shown late with a rollback in it
## lowers it below that rollback, and one shown in time raises it a little, up
## to a frame. Only if the late frame's work (SyncManager's _physics_process
## and _process, the network callbacks included) took longer than that of any
## frame shown in time lately: otherwise the work did not make it late (render
## jitter, the OS...), and putting rollbacks off would not help.
var rollback_deferral_budget_usecs := 0
## func(peer_ids: Array, first_tick: int) -> bool, to decide instead of the
## estimate whether the rollback for these peers' mispredicted inputs, from
## first_tick, can wait. A local choice (peers need not agree), so it can use
## anything.
var rollback_deferral_policy := Callable()
## Defers every rollback, the debug ones included, as long as allowed: to test
## deferral.
var debug_defer_all_rollbacks := false
## How many ticks rollbacks were put off since the match started.
var rollbacks_deferred := 0
var _last_deferred_tick := -1
# The first tick of the rollback being put off (-1 for none), and the tick it
# was first put off on.
var _deferred_rollback_tick := -1
var _deferral_start_tick := -1
# The peers whose mispredicted inputs asked for the rollback.
var _mispredicted_peers := {}
# Running average of the time a rollback takes per tick re-simulated, its load
# included (0 until one has run).
var _rollback_usecs_per_tick := 0.0
# The last tick that asked for a rollback, done or put off (-1 for none).
var _last_rollback_request_tick := -1
# The adapted budget (0 until adapted), the time rollbacks took in this frame,
# and when the last frame started.
var _adapted_deferral_budget := 0.0
var _frame_rollback_usecs := 0
var _last_frame_start_usec := 0
# Frames are timed from their start, when the engine's main loop comes back
# from waiting for the next frame (vsync, or the frame rate cap): SyncManager's
# _physics_process if the frame has a tick, or its _process. Not from _process:
# a tick's physics runs before it, and delays it without the frame being shown
# any later.
var _frame_open := false
# The time SyncManager's _process and _physics_process took since the last
# frame started, and the most any frame shown in time took lately (decaying).
var _frame_work_usecs := 0
var _max_on_time_work_usecs := 0.0
# The display's refresh interval (0 until asked).
var _vblank_usecs := 0.0
var _vblank_read_usec := 0
var ticks_to_calculate_advantage := 60
var input_delay := 2:
	set = set_input_delay
var max_input_frames_per_message := 5
var max_messages_at_once := 2
var max_ticks_to_regain_sync := 300
## After losing sync, ticks are only run again once this peer is at most this
## many ticks ahead of every other peer (half of local_lag - remote_lag, the
## advantage skip ticks use), so that it doesn't lose it again at once. Not
## compared with local_lag alone: that is the latency in ticks in steady play,
## and a peer waiting for it to come down would resume that far behind the
## others, making one of them lose sync in turn (back and forth, for good, past
## about 230 ms one way with the default settings). 0 resumes as soon as the
## buffers allow.
var min_lag_to_regain_sync := 5
## Instead of skipping ticks, a peer up to max_lead_to_adjust_tick_rate ticks
## off the others changes its physics ticks per second for a while, so that
## they fall back in step without a visible hitch: slower when it is ahead of
## them on average, faster when behind. These are the most it can change, as a
## fraction of the physics ticks per second (rounded down to whole ticks per
## second, at least one). Slowdown at 0, the default, turns it off: ticks are
## skipped as soon as this peer is a tick ahead (the peers behind can't speed
## up then: the skip closes the gap alone). Off by default, as peers then run
## at different rates: anything simulated must use tick_time, never the
## engine's physics delta (move_and_slide(), Godot's own physics bodies...),
## which would differ between them and desync. Faster costs CPU, so it is
## lower, and never done while frames run late: then only the peers ahead
## slow down.
var max_tick_rate_slowdown := 0.0
var max_tick_rate_speedup := 0.02
## How many ticks ahead of the peer furthest behind this peer can be with the
## tick rate adjusted: further, ticks are skipped (a hitch after a stall,
## where adjusting would take seconds).
var max_lead_to_adjust_tick_rate := 4
## How many ticks ran at an adjusted rate since the match started. Read-only.
var tick_rate_adjusted_ticks := 0
var interpolation := false
## With interpolation on, frames show the state between the last two ticks,
## which takes a load back to the tick before after every tick, and a load
## forward to the last one before the next. When frames come slower than both
## the ticks and the display's refresh, the machine can't keep up: this pauses
## it, to save those loads, once frames average 1.09 times the longer of a tick
## and a refresh (below about 55 fps at 60 ticks and 60 Hz), until they average
## 1.03 times it again, after 2 s paused at least (resuming brings the loads
## back, which could pause it again). Not at parity: there some frames get no
## tick and others two, which interpolation smooths, as it does on a display
## slower than the ticks. Paused, the visuals are set once per tick, as
## interpolating at weight 1 would.
var auto_pause_interpolation := true
## Pauses or resumes interpolation every this many ticks, to check the switch.
var debug_toggle_interpolation_ticks := 0
## How many ticks interpolation was paused for since the match started.
var interpolation_paused_ticks := 0
# Whether interpolation is on and not paused: changes only at the start of a
# tick (_physics_process), when the state is the tick's.
var _interpolating := false
var _interpolation_paused := false
var _frame_interval_average := 0.0
# How long interpolation has been paused, for the minimum hold.
var _interpolation_paused_usecs := 0
const INTERPOLATION_PAUSE_HOLD_USECS := 2000000
var max_state_mismatch_count := 10
var disable_event_registration := false

var debug_rollback_ticks := 0
var debug_random_rollback_ticks := 0
## Simulates a late packet: the inputs of the last debug_late_packet_ticks ticks
## stay incomplete, and every debug_late_packet_period ticks they become
## complete but for the last debug_late_packet_incomplete ones, with a rollback
## of debug_late_packet_ticks ticks, as when late inputs turn out mispredicted.
## Unlike debug_rollback_ticks, rollbacks then go back past complete ticks.
var debug_late_packet_ticks := 0
var debug_late_packet_period := 10
var debug_late_packet_incomplete := 1
var _debug_late_packet_arrived := false
var debug_message_bytes := 700
var debug_skip_nth_message := 0
var debug_physics_process_msecs := 0.0
var debug_process_msecs := 0.0
var debug_check_message_serializer_roundtrip := false
var debug_check_local_state_consistency := false
## Before every tick, loads the last state forward (_call_load_state_forward()),
## from the events since the match started, as a replay seeking there would,
## and checks that it saves back the same: that every node a replay rebuilds
## comes back as it was. Slow: spawned nodes are freed and spawned again, so
## that the game's own references to them go stale.
var debug_check_local_state_consistency_forward := false
var debug_use_sync_debugger := false
## Prints a performance summary when a match stops: what each part of a tick
## cost, which scripts' callbacks the time went to, and how many frames were
## late. Timed only while on.
var debug_perf_summary := false
# {timer: [total usecs, calls, max usecs, tick of the max]}
var _perf := {}
var _perf_starts := {}
var _perf_ticks := 0
var _perf_rollbacks := 0
var _perf_rollback_ticks := 0
var _perf_rollback_max := 0
var _perf_ticks_this_frame := 0
var _perf_frame_intervals := PackedInt64Array()
var _perf_frame_work := PackedInt64Array()
var _perf_frame_has_tick := PackedByteArray()


var ping_frequency := 1.0
var input_tick: int = 0
var current_tick: int = 0
var skip_ticks: int = 0
# The physics ticks per second of the project, and how far from it the rate is
# while adjusted (0: not), for how many more ticks.
var _base_tick_rate := 0
var _tick_rate_offset := 0
var _tick_rate_ticks_left := 0
# Closer to the others' average than this (in ticks), the rate isn't adjusted.
const TICK_RATE_DEAD_ZONE := 0.5
var rollback_ticks: int = 0
var requested_input_complete_tick: int = 0
var started := false
var load_type: int = LoadType.ROLLBACK
var tick_time: float

var _host_starting := false
var _ping_timer: Timer
var _spawn_manager
var _property_manager
var _effect_manager
var _logger
var _input_buffer_start_tick: int
var _state_buffer_start_tick: int
var _state_hashes_start_tick: int
var _input_send_queue := []
var _input_send_queue_start_tick: int
var _ticks_spent_regaining_sync := 0
var _time_since_last_tick := 0.0
var _debug_skip_nth_message_counter := 0
var _input_complete_tick := 0
var _state_complete_tick := 0
var _last_state_hashed_tick := 0
var _state_mismatch_count := 0
var _in_rollback := false
var _ran_physics_process := false
var _ticks_since_last_interpolation_frame := 0
var _debug_check_local_state_consistency_buffer := []
## Keeps the events since the match started (_event_history), which loading
## its state forward needs, for a player joining a match in progress.
var allow_late_join := false
# With allow_late_join or debug_check_local_state_consistency_forward: the
# events of the ticks retired from event_buffer, as {node path: {tick:
# events}}, with those before the state a replay started from
# (_start_from_state()) and their scripts, and whether it has them all. Every
# EVENT_HISTORY_COMPACTION_TICKS ticks, their scripts' _compact_events() drop
# what no load can need anymore.
var _event_history := {}
var _event_history_scripts := {}
var _has_event_history := true
var _event_history_compacted_tick := 0
# How many arguments scripts' _compact_events() take, or -1 without.
var _compact_events_methods := {}
const EVENT_HISTORY_COMPACTION_TICKS := 60
# On the host, the late joins (request_join()) under way, by joiner peer id:
# {tick: the first tick the joiner is sent input for, the snapshot's being the
# one before, pinned: {player peer id: true} for the players keeping their input
# from that tick for it, snapshot: the late join message once taken, or null,
# attempts}.
var _late_joins := {}
# On a joiner: asked to join (request_join()), the snapshot not loaded yet,
# and the request's id, which the host's answers carry: those to an earlier
# request, given up, are ignored.
var _late_join_requested := false
var _late_join_id := 0
# On a joiner: the snapshot's parts received so far: it comes in parts of
# LATE_JOIN_SNAPSHOT_PART_BYTES, as some transports take only so much in one
# message (WebRTC's data channels: about 16 KiB between different browsers).
var _late_join_snapshot_parts := []
# On a joiner that loaded a match: its own input_delay, the snapshot's (the
# host's) for the match only. -1: none to put back.
var _input_delay_before_join := -1
# Room left for the message's keys and the transport's framing.
const LATE_JOIN_SNAPSHOT_PART_BYTES := 16000
# On a joiner: when its join last got on (asked, a snapshot part, a tick's
# input complete), and the tick complete then: nothing for
# LATE_JOIN_TIMEOUT_MSECS, it gives up (late_join_failed).
var _late_join_progress_msecs := 0
var _late_join_progress_tick := 0
# On a joiner: the match loaded, no input received for the ticks after it yet.
var _late_join_waiting := false
# On a joiner: the match loaded, not in sync yet (late_join_synced), how many
# of its ticks every player hashed as it did, and whether one differed: nothing
# brings states that differ back together, the join failed.
var _late_join_syncing := false
var _late_join_matched_hashes := 0
var _late_join_mismatch := false
# How many ticks hashed as the players did make a joiner caught up in sync.
const LATE_JOIN_SYNCED_HASHES := 10
# A joiner becoming a player: the host puts {joiner peer id: first tick it
# plays} under this key in its input, which every peer gets in order, before
# the tick it plays from is complete. Hashed (not a "_" or "$" key), never
# predicted: a peer that ran the tick without it rolls back.
const JOIN_INPUT_KEY := "@join"
# On the host, the joiners that asked to play (request_join(true)) until they
# are in sync, then until the host's input says when they play.
var _joiners_to_promote := {}
var _joiners_to_announce := []
# On a joiner that asked to play: the first tick it plays, -1 until known.
var _local_player_from_tick := -1
# The players who joined, by the tick they play from: player_joined is emitted
# in that tick.
var _player_joins := {}
# The last tick a joiner plays from: before it, the players aren't all of
# _player_peers (see _players_at()).
var _last_player_from_tick := 0
# How long a joiner can go without getting less behind: the time to send it the
# snapshot, and for it to load it, included.
const LATE_JOIN_TIMEOUT_MSECS := 30000
# How many times the host picks a later tick when a player no longer has its
# input from the one picked.
const LATE_JOIN_MAX_ATTEMPTS := 3
# How many ticks of input a player sends a joiner each tick, at most.
const LATE_JOIN_MAX_INPUT_TICKS_SENT := 120
# The tick the match started from: 0, or a replay's (_start_from_state()).
var _start_tick := 0
# The last tick a rollback in progress re-simulates.
var _rollback_last_tick := -1
## How many re-simulated states were not saved since the match started, as no
## load could need them (see _can_skip_state()).
var state_saves_skipped := 0
var _current_event_buffer_frame_data := {}
var _event_scripts := {}
var _event_scripts_in_buffer := {}
var _peer_left_for_peer: = {}
# The peers removed during the match, or while our join's snapshot comes: a
# join of theirs read since in the host's input, or the snapshot, doesn't make
# them peers again.
var _peers_removed := {}
# The joins (request ids) their joiners gave up (join_abandoned): a pin for
# one arriving after would keep our input for a peer gone.
var _abandoned_join_ids := {}
var _in_load_state: bool = false

signal sync_started ()
signal sync_stopped ()
signal sync_lost ()
signal sync_regained ()
signal sync_error (msg)

signal skip_ticks_flagged (count)
signal tick_rate_changed (ticks_per_second)
signal rollback_flagged (tick)
signal prediction_missed (tick, peer_id, local_input, remote_input)
signal remote_state_mismatch (tick, peer_id, local_hash, remote_hash)

signal peer_added (peer_id)
signal peer_removed (peer_id)
## On a peer that called request_join(): the join didn't happen.
signal late_join_failed (reason)
## A peer that joined the match in progress (request_join()) caught up, and
## hashed ticks as every player did: on it, and on the players.
signal late_join_synced (peer_id)
## A peer that joined the match in progress to play (request_join(true)) plays
## from this tick on: emitted in it (every time it runs, rollbacks included),
## before the nodes' _network_process(), on every peer. Spawn its nodes here,
## with SyncManager.spawn(), its peer id their multiplayer authority.
signal player_joined (peer_id)
signal peer_pinged_back (peer)

signal state_loaded (rollback_ticks)
signal tick_finished (is_rollback)
signal tick_retired (tick)
signal tick_input_complete (tick)
signal interpolation_frame ()

func _enter_tree() -> void:
	var project_settings_node = load("res://addons/delta_rollback/ProjectSettings.gd").new()
	project_settings_node.add_project_settings()
	project_settings_node.free()

func _exit_tree() -> void:
	stop_logging()

func _ready() -> void:
	#get_tree().connect("network_peer_disconnected", self, "remove_peer")
	#get_tree().connect("server_disconnected", self, "stop")
	
	var project_settings := {
		max_buffer_size = 'network/rollback/max_buffer_size',
		ticks_to_calculate_advantage = 'network/rollback/ticks_to_calculate_advantage',
		input_delay = 'network/rollback/input_delay',
		_ping_frequency = 'network/rollback/ping_frequency',
		interpolation = 'network/rollback/interpolation',
		max_input_frames_per_message = 'network/rollback/limits/max_input_frames_per_message',
		max_messages_at_once = 'network/rollback/limits/max_messages_at_once',
		max_ticks_to_regain_sync = 'network/rollback/limits/max_ticks_to_regain_sync',
		min_lag_to_regain_sync = 'network/rollback/limits/min_lag_to_regain_sync',
		max_state_mismatch_count = 'network/rollback/limits/max_state_mismatch_count',
		debug_rollback_ticks = 'network/rollback/debug/rollback_ticks',
		debug_random_rollback_ticks = 'network/rollback/debug/random_rollback_ticks',
		debug_message_bytes = 'network/rollback/debug/message_bytes',
		debug_skip_nth_message = 'network/rollback/debug/skip_nth_message',
		debug_physics_process_msecs = 'network/rollback/debug/physics_process_msecs',
		debug_process_msecs = 'network/rollback/debug/process_msecs',
		debug_check_message_serializer_roundtrip = 'network/rollback/debug/check_message_serializer_roundtrip',
		debug_check_local_state_consistency = 'network/rollback/debug/check_local_state_consistency',
		debug_check_local_state_consistency_forward = 'network/rollback/debug/check_local_state_consistency_forward',
		allow_late_join = 'network/rollback/allow_late_join',
		debug_use_sync_debugger = 'network/rollback/debug/use_sync_debugger',
		debug_perf_summary = 'network/rollback/debug/perf_summary',
		max_rollback_deferral_ticks = 'network/rollback/max_rollback_deferral_ticks',
		rollback_deferral_budget_usecs = 'network/rollback/rollback_deferral_budget_usecs',
		auto_pause_interpolation = 'network/rollback/auto_pause_interpolation',
		max_tick_rate_slowdown = 'network/rollback/max_tick_rate_slowdown',
		max_tick_rate_speedup = 'network/rollback/max_tick_rate_speedup',
		max_lead_to_adjust_tick_rate = 'network/rollback/max_lead_to_adjust_tick_rate',
	}
	for property_name in project_settings:
		var setting_name = project_settings[property_name]
		# _enter_tree() added any missing: this only guards against that changing.
		if ProjectSettings.has_setting(setting_name):
			set(property_name, ProjectSettings.get_setting(setting_name))
	_interpolating = interpolation
	
	_ping_timer = Timer.new()
	_ping_timer.name = "PingTimer"
	_ping_timer.wait_time = ping_frequency
	_ping_timer.autostart = true
	_ping_timer.one_shot = false
	_ping_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_ping_timer.timeout.connect(_on_ping_timer_timeout)
	add_child(_ping_timer)
	
	# Before the managers: they register themselves with its node registry.
	sync_booster.name = "SyncBooster"
	add_child(sync_booster)
	
	_spawn_manager = SpawnManager.new()
	_spawn_manager.name = "SpawnManager"
	add_child(_spawn_manager)
	
	_property_manager = PropertyManagerScript.new()
	_property_manager.name = "PropertyManager"
	add_child(_property_manager)
	# Native nodes record their changes in it through SyncBooster, with
	# activate_sync()'s rules: during a match, outside loads.
	sync_booster.set_property_manager(_property_manager)
	
	_effect_manager = EffectManager.new()
	_effect_manager.name = "EffectManager"
	add_child(_effect_manager)
	_effect_manager.setup_effect_manager(self)
	
	if debug_use_sync_debugger:
		var sync_debugger = load(SYNC_DEBUGGER_PATH).new()
		sync_debugger.name = "SyncDebugger"
		add_child(sync_debugger)
	
	if network_adaptor == null:
		reset_network_adaptor()
	if message_serializer == null:
		set_message_serializer(_create_class_from_project_settings('network/rollback/classes/message_serializer', DEFAULT_MESSAGE_SERIALIZER_PATH))

func _set_readonly_variable(_value) -> void:
	pass

func _create_class_from_project_settings(setting_name: String, default_path: String):
	var class_path := ''
	if ProjectSettings.has_setting(setting_name):
		class_path = ProjectSettings.get_setting(setting_name)
	if class_path == '':
		class_path = default_path
	return load(class_path).new()

func set_network_adaptor(_network_adaptor: NetworkAdaptor) -> void:
	assert(not started, "Changing the network adaptor after SyncManager has started will probably break everything")
	
	if network_adaptor != null:
		network_adaptor.detach_network_adaptor(self)
		network_adaptor.received_ping.disconnect(_on_received_ping)
		network_adaptor.received_ping_back.disconnect(_on_received_ping_back)
		network_adaptor.received_remote_start.disconnect(_on_received_remote_start)
		network_adaptor.received_remote_stop.disconnect(_on_received_remote_stop)
		network_adaptor.received_input_tick.disconnect(_on_received_input_tick)
		network_adaptor.received_sync_message.disconnect(_on_received_sync_message)
		
		remove_child(network_adaptor)
		network_adaptor.queue_free()
	
	network_adaptor = _network_adaptor
	network_adaptor.name = 'NetworkAdaptor'
	add_child(network_adaptor)
	network_adaptor.received_ping.connect(_on_received_ping)
	network_adaptor.received_ping_back.connect(_on_received_ping_back)
	network_adaptor.received_remote_start.connect(_on_received_remote_start)
	network_adaptor.received_remote_stop.connect(_on_received_remote_stop)
	network_adaptor.received_input_tick.connect(_on_received_input_tick)
	network_adaptor.received_sync_message.connect(_on_received_sync_message)
	network_adaptor.attach_network_adaptor(self)

func reset_network_adaptor() -> void:
	set_network_adaptor(_create_class_from_project_settings('network/rollback/classes/network_adaptor', DEFAULT_NETWORK_ADAPTOR_PATH))

func set_message_serializer(_message_serializer: MessageSerializer) -> void:
	assert(not started, "Changing the message serializer after SyncManager has started will probably break everything")
	message_serializer = _message_serializer

func set_mechanized(_mechanized: bool) -> void:
#	assert(not started, "Changing the mechanized flag after SyncManager has started will probably break everything")
	mechanized = _mechanized
	mechanized_replay = _mechanized
	
	set_process(not mechanized_replay)
	set_physics_process(not mechanized_replay)
	_ping_timer.paused = mechanized
	
	if mechanized_replay:
		stop_logging()

func set_ping_frequency(p_ping_frequency) -> void:
	ping_frequency = p_ping_frequency
	if _ping_timer:
		_ping_timer.wait_time = ping_frequency

func set_input_delay(_input_delay: int) -> void:
	if started:
		push_warning("Cannot change input delay after sync'ing has already started")
	input_delay = _input_delay

## options: spectator (false) for a peer that watches the match without
## playing in it, which is sent our input and state hashes but never waited for.
func add_peer(peer_id: int, options := {}) -> void:
	assert(not peers.has(peer_id), "Peer with given id already exists")
	assert(peer_id != network_adaptor.get_network_unique_id(), "Cannot add ourselves as a peer in SyncManager")
	
	if peers.has(peer_id):
		return
	if peer_id == network_adaptor.get_network_unique_id():
		return
	if started:
		push_error("Can't add peer %s during a match: peers join one in progress with request_join()" % peer_id)
		return
	
	var peer := Peer.new(peer_id, options.get("spectator", false))
	peers[peer_id] = peer
	if not peer.spectator:
		_player_peers[peer_id] = peer
	emit_signal("peer_added", peer_id)

func has_peer(peer_id: int) -> bool:
	return peers.has(peer_id)

func get_peer(peer_id: int) -> Peer:
	return peers.get(peer_id)

func remove_peer(peer_id: int) -> void:
	if peers.has(peer_id):
		# A spectator's input never counts: no need to agree on its last one.
		if started and not peers[peer_id].spectator:
			_sync_remove_peer(peer_id)
		else:
			# Unless a joiner's turn to play is in input that we don't have
			# yet: the peers who have it wait for our say.
			if started:
				for player_id in _player_peers:
					network_adaptor.send_sync_message(player_id, {type = "peer_left", peer = peer_id})
			_remove_peer_internal(peer_id)

func _remove_peer_internal(peer_id: int) -> void:
	var was_player := _player_peers.has(peer_id)
	if started or _late_join_requested:
		_peers_removed[peer_id] = true
	_peer_left_for_peer.erase(peer_id)
	peers.erase(peer_id)
	_player_peers.erase(peer_id)
	_late_joins.erase(peer_id)
	_joiners_to_promote.erase(peer_id)
	_joiners_to_announce.erase(peer_id)
	emit_signal("peer_removed", peer_id)
	# One less player to wait for.
	for joiner in _late_joins.keys():
		_send_late_join_snapshot_if_ready(joiner)
	# Spectators left alone don't keep the match going, nor a player whose
	# last other player left; one playing alone with spectators goes on.
	if (spectating and peers.is_empty()) or (was_player and _player_peers.is_empty()):
		stop()
	elif started:
		# Input and states waiting only for this peer are complete now.
		_update_input_complete_tick()
		_update_state_complete_tick()
		_update_state_hashes()

# don't remove peer immediately since there may be inputs that are only 
# in one peer and can cause desyncs
func _sync_remove_peer(p_peer_id: int) -> void:
	var my_id := network_adaptor.get_network_unique_id()
	# Not to the peer gone.
	for peer_id in peers:
		if peer_id != p_peer_id:
			network_adaptor.send_sync_message(peer_id, {type = "peer_left", peer = p_peer_id})
	_on_peer_left(my_id, p_peer_id)

func clear_peers() -> void:
	for peer_id in peers.keys().duplicate():
		_remove_peer_internal(peer_id)

func _get_system_time_msecs() -> int:
	return int(round(1000.0 * Time.get_unix_time_from_system()))

func _on_ping_timer_timeout() -> void:
	if peers.size() == 0:
		return
	var msg = {
		local_time = _get_system_time_msecs(),
	}
	for peer_id in peers:
		assert(peer_id != network_adaptor.get_network_unique_id(), "Cannot ping ourselves")
		network_adaptor.send_ping(peer_id, msg)

func _on_received_ping(peer_id: int, msg: Dictionary) -> void:
	assert(peer_id != network_adaptor.get_network_unique_id(), "Cannot ping back ourselves")
	msg['remote_time'] = _get_system_time_msecs()
	network_adaptor.send_ping_back(peer_id, msg)

func _on_received_ping_back(peer_id: int, msg: Dictionary) -> void:
	var system_time = _get_system_time_msecs()
	# From a peer removed since we pinged it.
	var peer = peers.get(peer_id)
	if peer == null:
		return
	peer.last_ping_received = system_time
	peer.rtt = system_time - msg['local_time']
	peer.time_delta = msg['remote_time'] - msg['local_time'] - (peer.rtt / 2.0)
	emit_signal("peer_pinged_back", peer)

func start_logging(log_file_path: String, match_info: Dictionary = {}) -> void:
	if mechanized_replay:
		return
	
	if not _logger:
		_logger = DeltaRollbackLogger.new(self)
	else:
		_logger.stop()
	
	if _logger.start(log_file_path, network_adaptor.get_network_unique_id(), match_info) != OK:
		stop_logging()

func stop_logging() -> void:
	if _logger:
		_logger.stop()
		_logger = null

func start() -> void:
	assert(network_adaptor.is_network_host() or mechanized_replay, "start() should only be called on the host")
	if started or _host_starting:
		return
	if mechanized_replay:
		_on_received_remote_start()
		return
	if network_adaptor.is_network_host():
		var highest_rtt: int = 0
		for peer in peers.values():
			highest_rtt = max(highest_rtt, peer.rtt)
		
		# Call _remote_start() on all the other peers.
		for peer_id in peers:
			network_adaptor.send_remote_start(peer_id)
		
		# Attempt to prevent double starting on the host.
		_host_starting = true
		
		# Wait for half the highest RTT to start locally.
		print ("Delaying host start by %sms" % (highest_rtt / 2))
		await get_tree().create_timer(highest_rtt / 2000.0).timeout
		
		_on_received_remote_start()
		_host_starting = false

func _reset() -> void:
	input_tick = 0
	_deferred_rollback_tick = -1
	_deferral_start_tick = -1
	_mispredicted_peers.clear()
	_rollback_usecs_per_tick = 0.0
	_last_rollback_request_tick = -1
	_adapted_deferral_budget = 0.0
	_frame_rollback_usecs = 0
	_last_frame_start_usec = 0
	_frame_open = false
	_frame_work_usecs = 0
	_max_on_time_work_usecs = 0.0
	_frame_interval_average = 0.0
	_interpolation_paused = false
	_interpolation_paused_usecs = 0
	_interpolating = interpolation
	rollbacks_deferred = 0
	_last_deferred_tick = -1
	_vblank_usecs = 0.0
	interpolation_paused_ticks = 0
	_rollback_last_tick = -1
	state_saves_skipped = 0
	current_tick = input_tick - input_delay
	skip_ticks = 0
	# Only if adjusted: a replay sets the rate to play faster or slower.
	_set_tick_rate_offset(0)
	tick_rate_adjusted_ticks = 0
	rollback_ticks = 0
	input_buffer.clear()
	state_buffer.clear()
	state_hashes.clear()
	event_buffer.clear()
	_input_buffer_start_tick = 1
	_state_buffer_start_tick = 0
	_state_hashes_start_tick = 1
	_input_send_queue.clear()
	_input_send_queue_start_tick = 1
	_ticks_spent_regaining_sync = 0
	_time_since_last_tick = 0.0
	_debug_skip_nth_message_counter = 0
	_input_complete_tick = 0
	_state_complete_tick = 0
	_last_state_hashed_tick = 0
	_state_mismatch_count = 0
	_in_rollback = false
	_ran_physics_process = false
	_ticks_since_last_interpolation_frame = 0
	_debug_check_local_state_consistency_buffer.clear()
	_event_history.clear()
	_event_history_scripts.clear()
	_has_event_history = true
	_event_history_compacted_tick = 0
	_start_tick = 0
	_current_event_buffer_frame_data.clear()
	_event_scripts.clear()
	_event_scripts_in_buffer.clear()
	_peer_left_for_peer.clear()
	_peers_removed.clear()
	_abandoned_join_ids.clear()
	_late_joins.clear()
	_late_join_requested = false
	_late_join_snapshot_parts.clear()
	_late_join_waiting = false
	_late_join_syncing = false
	_late_join_matched_hashes = 0
	_late_join_mismatch = false
	_joiners_to_promote.clear()
	_joiners_to_announce.clear()
	_local_player_from_tick = -1
	_player_joins.clear()
	_last_player_from_tick = 0

func _on_received_remote_start(emit_started := true) -> void:
	_reset()
	_perf_reset()
	# The rate the game runs at, which it may have set at runtime: adjusting
	# it changes it from there, and sets it back there.
	_base_tick_rate = Engine.physics_ticks_per_second
	tick_time = (1.0 / ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	sync_booster.set_tick_time(tick_time)
	# The state is the start tick's, for what starts before the first tick.
	sync_booster.set_loaded_tick(current_tick)
	started = true
	_update_booster_recording()
	network_adaptor.start_network_adaptor(self)
	for n in get_tree().get_nodes_in_group("network_sync"):
		set_groups_for_node(n)
	if emit_started:
		emit_signal("sync_started")

## Put a node under SyncManager's control. Which callbacks it takes part in is
## derived from the methods it implements, as the per-phase groups used to be.
func register_node(n: Node) -> void:
	sync_booster.register_node(n)
	n.add_to_group("network_sync_managed")
	n.remove_from_group("network_sync")


## Take a node back out. Freeing a node does this on its own.
func unregister_node(n: Node) -> void:
	sync_booster.unregister_node(n)
	n.remove_from_group("network_sync_managed")


func set_groups_for_node(n: Node) -> void:
	register_node(n)

func stop() -> void:
	_stop("stopped before in sync")

# A join of ours under way ends too: late_join_failed with the reason.
func _stop(join_failed_reason: String) -> void:
	# The host stops everyone; the last player, the spectators, who would
	# wait for its input for good (the host gone).
	var last_player := started and not spectating and _player_peers.is_empty()
	if (network_adaptor.is_network_host() or last_player) and not mechanized_replay:
		for peer_id in peers:
			_send_stop(peer_id, "the match stopped")
	
	# A join of ours under way, given up: the players let us go.
	var joining := _late_join_requested or _late_join_syncing
	if joining:
		for peer_id in _player_peers:
			network_adaptor.send_sync_message(peer_id, {type = "join_abandoned", id = _late_join_id})
		_late_join_requested = false
		_late_join_syncing = false
	_on_received_remote_stop()
	if joining:
		emit_signal("late_join_failed", join_failed_reason)

# A joiner the host knows the request of hears it stopped with a join_failed of
# its id.
func _send_stop(peer_id: int, reason: String) -> void:
	var peer: Peer = peers.get(peer_id)
	if peer and peer.joining and peer.join_id != 0:
		network_adaptor.send_sync_message(peer_id, {type = "join_failed", reason = reason, id = peer.join_id})
	else:
		network_adaptor.send_remote_stop(peer_id)

func _on_received_remote_stop() -> void:
	# Before we loaded a match: none of ours, if we're joining one (from the
	# last player, or an attempt of ours before), the host saying with a
	# join_failed.
	if not (started or _host_starting):
		return
	
	var joining := _late_join_syncing
	# The match's late joiners are spectators again, on every peer, themselves
	# included: whether one plays, or was announced, or caught up, peers can
	# disagree on when the match stops. The next starts with the roles the
	# game gave, a joiner's from request_join().
	var joined_late := _local_player_from_tick >= 0
	for peer in peers.values():
		if peer.player_from_tick > 0:
			peer.spectator = true
			_player_peers.erase(peer.peer_id)
	network_adaptor.stop_network_adaptor(self)
	started = false
	_update_booster_recording()
	_host_starting = false
	if debug_perf_summary:
		_perf_print_summary()
	_reset()
	
	for peer in peers.values():
		peer.clear()
	
	emit_signal("sync_stopped")
	_restore_sync_groups()
	_spawn_manager.reset()
	_property_manager.reset()
	if joined_late:
		spectating = true
	if _input_delay_before_join >= 0:
		input_delay = _input_delay_before_join
		_input_delay_before_join = -1
	if joining:
		emit_signal("late_join_failed", "the match stopped before this peer was in sync")

func _handle_fatal_error(msg: String):
	# Before stop(): a sync_stopped (or sync_error) handler may stop logging.
	if _logger:
		_logger.log_fatal_error(msg)
	emit_signal("sync_error", msg)
	push_error("NETWORK SYNC LOST: " + msg)
	_stop(msg)
	return null

func _call_get_local_input() -> Dictionary:
	return sync_booster.call_get_local_input(network_adaptor.get_network_unique_id())

func _call_network_process(input_frame: InputBufferFrame) -> void:
	_perf_begin("network_process")
	sync_booster.call_network_process(input_frame)
	_spawn_manager._network_process({})
	_perf_end("network_process")

func _call_network_preprocess(input_frame: InputBufferFrame) -> void:
	_perf_begin("network_preprocess")
	sync_booster.call_network_preprocess(input_frame)
	_perf_end("network_preprocess")

func _call_network_postprocess(input_frame: InputBufferFrame) -> void:
	_perf_begin("network_postprocess")
	sync_booster.call_network_postprocess(input_frame)
	_perf_end("network_postprocess")

func _call_save_state() -> Dictionary:
	if _logger:
		_logger.start_timing("call_save_state")
	_perf_begin("save_state")
	var property_manager_state = _property_manager._save_state()
	var res = sync_booster.call_save_state()
	res[str(_property_manager.get_path())] = property_manager_state
	res[str(_spawn_manager.get_path())] = _spawn_manager._save_state()
	_perf_end("save_state")
	if _logger:
		_logger.stop_timing("call_save_state")
	return res

# p_tick: the tick of the state, which native nodes that are functions of the
# tick read (NetworkTimer's ticks_left).
func _call_load_state(state: Dictionary, p_load_type: int, p_tick: int) -> void:
	if _logger:
		_logger.start_timing("call_load_state")
	var perf_timer: String = "load_state_" + ["rollback", "interpolation_backward", "interpolation_forward"][p_load_type]
	_perf_begin(perf_timer)
	sync_booster.set_loaded_tick(p_tick)
	load_type = p_load_type
	_in_load_state = true
	_update_booster_recording()
	_spawn_manager._load_state(state[str(_spawn_manager.get_path())])
	_property_manager._load_state(state[str(_property_manager.get_path())])
	sync_booster.call_load_state(state)
	_in_load_state = false
	_update_booster_recording()
	_perf_end(perf_timer)
	if _logger:
		_logger.stop_timing("call_load_state", true)

# Loads a state from scratch, as that of tick p_tick: unlike _call_load_state(),
# with the events up to it (get_events_up_to_tick()), for what a rollback
# can't go back to: the spawned nodes, the values set_synced() long ago... The
# SpawnManager and PropertyManager must have been reset, but for the check
# (debug_check_local_state_consistency_forward).
func _call_load_state_forward(state: Dictionary, events: Dictionary, p_tick: int) -> void:
	# The state may be one of the state buffer's.
	state = state.duplicate()
	sync_booster.set_loaded_tick(p_tick)
	load_type = LoadType.ROLLBACK
	_in_load_state = true
	_update_booster_recording()
	var spawn_manager_path: = str(_spawn_manager.get_path())
	_spawn_manager._load_state_forward(state[spawn_manager_path], events.get(spawn_manager_path, {}))
	state.erase(spawn_manager_path)
	# Before the nodes: the last values it was given include the states of
	# nodes switched off, then back on since, which theirs must replace.
	var property_manager_path: = str(_property_manager.get_path())
	if state.has(property_manager_path):
		_property_manager._load_state_forward(state[property_manager_path], events.get(property_manager_path, {}))
		state.erase(property_manager_path)
	for node_path in state:
		if node_path == '$':
			continue
		var node = get_node_or_null(node_path)
		assert(node != null, "Unable to restore state to missing node: %s" % node_path)
		if node:
			if not sync_booster.is_sync_active(node):
				sync_booster.register_node(node)
				sync_booster.set_sync_active(node, true)
			if node.has_method('_load_state_forward'):
				node._load_state_forward(state[node_path], events.get(node_path, {}))
			else:
				# Also for nodes saved natively or from _sync_properties(),
				# which have no _load_state().
				sync_booster.load_node_state(node, state[node_path])
	_spawn_manager._remove_despawned_after_forward_load()
	_in_load_state = false
	_update_booster_recording()

## For replays seeking into a log: the match goes on from a logged state, that
## of tick p_tick, with the events up to it (get_events_up_to_tick()). The
## ticks stay the log's, which the state holds (timeouts, animation starts,
## spawn records...): the next tick is p_tick + 1, whose input must be given.
## p_past_events and p_past_event_scripts, the log's events up to p_tick as
## get_events_up_to_tick() takes them (none is null, not {}), start the event
## history (allow_late_join, the forward load check), which is lost without.
func _start_from_state(state: Dictionary, events: Dictionary, p_tick: int,
		p_past_events = null, p_past_event_scripts: Dictionary = {}) -> void:
	_reset()
	_perf_reset()
	_event_history = p_past_events if p_past_events != null else {}
	_event_history_scripts = p_past_event_scripts
	_has_event_history = p_past_events != null
	_event_history_compacted_tick = p_tick
	_spawn_manager.reset()
	_property_manager.reset()
	_effect_manager.end_all()
	current_tick = p_tick
	_start_tick = p_tick
	input_tick = p_tick + input_delay
	_input_buffer_start_tick = p_tick + 1
	_input_send_queue_start_tick = input_tick + 1
	_input_complete_tick = p_tick
	_state_complete_tick = p_tick
	_last_state_hashed_tick = p_tick
	_state_hashes_start_tick = p_tick + 1
	_state_buffer_start_tick = p_tick
	_call_load_state_forward(state, events, p_tick)
	# The state itself is saved by the next _physics_process(), as the start's.

func _update_booster_recording() -> void:
	sync_booster.set_recording(started and not _in_load_state, current_tick)

func _call_interpolate_state(weight: float) -> void:
	if _logger:
		_logger.start_timing("call_load_state")
	if not state_buffer.is_empty():
		_perf_begin("interpolate_state")
		sync_booster.call_interpolate_state(state_buffer[-2].data, state_buffer[-1].data, weight)
		_perf_end("interpolate_state")
	if _logger:
		_logger.stop_timing("call_load_state")

func _save_current_state(can_skip: bool = false) -> void:
	assert(current_tick >= 0, "Attempting to store state for negative tick")
	if current_tick < 0:
		return
	
	if can_skip and _can_skip_state():
		var frame := StateBufferFrame.new(current_tick, {})
		frame.skipped = true
		state_buffer.append(frame)
		state_saves_skipped += 1
	else:
		state_buffer.append(StateBufferFrame.new(current_tick, _call_save_state()))
	event_buffer.append(EventBufferFrame.new(current_tick, _current_event_buffer_frame_data))
	
	_update_state_complete_tick()

func _update_state_complete_tick() -> void:
	# If the input for this state is complete, then update _state_complete_tick.
	if _input_complete_tick > _state_complete_tick:
		# Set to the current_tick so long as its less than or equal to the
		# _input_complete_tick, otherwise, cap it to the _input_complete_tick.
		_state_complete_tick = current_tick if current_tick <= _input_complete_tick else _input_complete_tick
	# The states from a deferred rollback's first tick on were computed with
	# mispredicted inputs: not complete, and not hashed, until it has run.
	if _deferred_rollback_tick >= 0 and _state_complete_tick >= _deferred_rollback_tick:
		_state_complete_tick = _deferred_rollback_tick - 1

# Returns the rollback to do now: p_rollback_ticks, none if it can wait, or
# the longer one a rollback put off has become.
func _apply_rollback_deferral(p_rollback_ticks: int) -> int:
	if max_rollback_deferral_ticks <= 0:
		_mispredicted_peers.clear()
		return p_rollback_ticks
	# A tick skipped to regain sync calls this again on the same tick.
	var recurring := _deferral_start_tick >= 0 or \
		(_last_rollback_request_tick >= 0 and _last_rollback_request_tick >= current_tick - 1)
	if p_rollback_ticks > 0:
		_last_rollback_request_tick = current_tick
	var first_tick := _deferred_rollback_tick
	if p_rollback_ticks > 0:
		var tick := current_tick - p_rollback_ticks + 1
		first_tick = tick if first_tick < 0 else mini(first_tick, tick)
	if first_tick < 0:
		return 0
	var length := current_tick - first_tick + 1
	var deferred_for := 0 if _deferral_start_tick < 0 else current_tick - _deferral_start_tick
	# Room in the state buffer for the state to load, whatever else waits.
	var can_wait := deferred_for < max_rollback_deferral_ticks and length + 2 < max_buffer_size
	if can_wait and not debug_defer_all_rollbacks:
		if rollback_deferral_policy.is_valid():
			can_wait = rollback_deferral_policy.call(_mispredicted_peers.keys(), first_tick)
		else:
			can_wait = recurring and _rollback_usecs_per_tick * length > _rollback_deferral_budget()
	if can_wait:
		if _deferral_start_tick < 0:
			_deferral_start_tick = current_tick
		_deferred_rollback_tick = first_tick
		_update_state_complete_tick()
		# Once per tick: a tick skipped to regain sync comes back here.
		if _last_deferred_tick != current_tick:
			_last_deferred_tick = current_tick
			rollbacks_deferred += 1
		return 0
	_deferred_rollback_tick = -1
	_deferral_start_tick = -1
	_mispredicted_peers.clear()
	return length

func _rollback_deferral_budget() -> float:
	if rollback_deferral_budget_usecs > 0:
		return float(rollback_deferral_budget_usecs)
	if _adapted_deferral_budget > 0.0:
		return _adapted_deferral_budget
	return _get_vblank_usecs() / 2.0

func _get_vblank_usecs() -> float:
	# Read again every second: the window may move to another display.
	var now := Time.get_ticks_usec()
	if _vblank_usecs <= 0.0 or now - _vblank_read_usec > 1000000:
		_vblank_read_usec = now
		var refresh: float = DisplayServer.screen_get_refresh_rate()
		_vblank_usecs = 1000000.0 / (refresh if refresh > 0.0 else 60.0)
	return _vblank_usecs

func _begin_frame(now: int) -> void:
	if _frame_open:
		return
	_frame_open = true
	if _last_frame_start_usec > 0:
		_end_frame(now - _last_frame_start_usec)
	_last_frame_start_usec = now

# The frame that just ended took interval_usecs, until this one started.
func _end_frame(interval_usecs: int) -> void:
	var interval := float(interval_usecs)
	_frame_interval_average = interval if _frame_interval_average <= 0.0 \
		else lerp(_frame_interval_average, interval, 0.05)
	_adapt_deferral_budget(interval_usecs)
	_update_interpolation_pause(interval_usecs)
	if debug_perf_summary:
		_perf_frame_intervals.append(interval_usecs)
		_perf_frame_work.append(_frame_work_usecs)
		_perf_frame_has_tick.append(1 if _perf_ticks_this_frame > 0 else 0)
		_perf_ticks_this_frame = 0
	_frame_rollback_usecs = 0
	_frame_work_usecs = 0

# Takes effect at the start of the next tick.
func _update_interpolation_pause(interval_usecs: int) -> void:
	if not interpolation or mechanized:
		return
	if debug_toggle_interpolation_ticks > 0:
		_interpolation_paused = (current_tick / debug_toggle_interpolation_ticks) % 2 == 1
		return
	if not auto_pause_interpolation:
		# Switched off while paused: resumed, not stuck.
		_interpolation_paused = false
		return
	var reference := _frame_reference_usecs()
	if _interpolation_paused:
		_interpolation_paused_usecs += interval_usecs
		if _interpolation_paused_usecs >= INTERPOLATION_PAUSE_HOLD_USECS \
				and _frame_interval_average <= reference * 1.03:
			_interpolation_paused = false
	elif _frame_interval_average >= reference * 1.09:
		_interpolation_paused = true
		_interpolation_paused_usecs = 0

# How long frames take when the machine keeps up: a tick (at the base rate:
# not moved by its adjustments) or a refresh.
func _frame_reference_usecs() -> float:
	var rate := _base_tick_rate if _base_tick_rate > 0 else Engine.physics_ticks_per_second
	return maxf(1000000.0 / rate, _get_vblank_usecs())

# A frame was shown late if it took over a vblank and a half.
func _adapt_deferral_budget(interval_usecs: int) -> void:
	var on_time := interval_usecs <= _get_vblank_usecs() * 1.5
	if _frame_rollback_usecs > 0 and max_rollback_deferral_ticks > 0 and rollback_deferral_budget_usecs <= 0:
		var vblank := _get_vblank_usecs()
		var budget := _rollback_deferral_budget()
		if on_time:
			budget *= 1.02
		elif _frame_work_usecs > _max_on_time_work_usecs:
			budget = minf(budget, _frame_rollback_usecs) * 0.8
		# Not so low that recovering would take long.
		_adapted_deferral_budget = clampf(budget, vblank / 16.0, vblank)
	# About a minute at 60 frames per second to halve.
	_max_on_time_work_usecs *= 0.9998
	if on_time:
		_max_on_time_work_usecs = maxf(_max_on_time_work_usecs, _frame_work_usecs)

# During a rollback, the state of a re-simulated tick is not saved when no later
# load can need it: before the last complete tick (a rollback never starts
# before it), but for the rollback's last tick (the interpolation backward load
# reads it). Its state hash is SKIPPED_STATE_HASH, which peers do not compare.
# Not while logging, as the log has every state. The state consistency checks
# only compare the states that were saved.
func _can_skip_state() -> bool:
	return current_tick < _input_complete_tick \
		and current_tick < _rollback_last_tick and not _logger \
		and not _is_late_join_snapshot_tick(current_tick)

# A late join's snapshot is the state of this tick.
func _is_late_join_snapshot_tick(tick: int) -> bool:
	for join in _late_joins.values():
		if join.get("tick") == tick + 1:
			return true
	return false

func _update_input_complete_tick() -> void:
	# A player's input for the ticks after input_tick isn't there yet. A
	# spectator has none: the players' input is all it takes, as far as it came.
	var last_tick := input_tick
	if spectating and not input_buffer.is_empty():
		last_tick = maxi(last_tick, input_buffer[-1].tick)
	while last_tick >= _input_complete_tick + 1:
		var input_frame: InputBufferFrame = get_input_frame(_input_complete_tick + 1)
		if not input_frame:
			break
		if not input_frame.is_complete(_players_at(input_frame.tick)):
			break
		# When we add debug rollbacks mark the input as not complete
		# so that the invariant "an complete input cannot be rolled back" is respected
		# NB: a complete input can still be loaded in a rollback for the incomplete next frame
		if debug_random_rollback_ticks > 0 and _input_complete_tick + 1 > current_tick - debug_random_rollback_ticks:
			break
		if debug_rollback_ticks > 0 and _input_complete_tick + 1 > current_tick - debug_rollback_ticks:
			break
		if debug_late_packet_ticks > 0:
			var incomplete: int = debug_late_packet_incomplete if _debug_late_packet_arrived else debug_late_packet_ticks
			if _input_complete_tick + 1 > current_tick - incomplete:
				break
		
		if _logger:
			_logger.write_input(input_frame.tick, input_frame.get_players())
		
		_input_complete_tick += 1
		
		# This tick should be recomputed with complete inputs, let's roll back
		if _input_complete_tick == requested_input_complete_tick:
			requested_input_complete_tick = 0
			var tick_delta = current_tick - _input_complete_tick
			if tick_delta >= 0 and rollback_ticks <= tick_delta:
				rollback_ticks = tick_delta + 1
				emit_signal("rollback_flagged", _input_complete_tick)
		
		emit_signal("tick_input_complete", _input_complete_tick)

func _update_state_hashes() -> void:
	_perf_begin("update_state_hashes")
	_update_state_hashes_now()
	_perf_end("update_state_hashes")

func _update_state_hashes_now() -> void:
	while _state_complete_tick > _last_state_hashed_tick:
		var state_frame: StateBufferFrame = _get_state_frame(_last_state_hashed_tick + 1)
		if not state_frame:
			_handle_fatal_error("Unable to hash state")
			return
		
		_last_state_hashed_tick += 1
		
		var state_hash = SKIPPED_STATE_HASH if state_frame.skipped else _calculate_data_hash(state_frame.data)
		state_hashes.append(StateHashFrame.new(_last_state_hashed_tick, state_hash))
		
		if _logger:
			var event_frame = _get_event_frame(_last_state_hashed_tick)
			if not _event_scripts_in_buffer.is_empty():
				# send all event scripts received as they don't represent state
				for node_path in _event_scripts_in_buffer.keys():
					var script_path = _event_scripts_in_buffer[node_path]
					event_frame._add_script_event(node_path, script_path)
					_event_scripts[node_path] = script_path
				_event_scripts_in_buffer.clear()
			var serialized_events = SyncManager.sync_booster.serialize(event_frame.data)
			_logger.write_event(_last_state_hashed_tick, serialized_events)
			_logger.write_state(_last_state_hashed_tick, state_frame.data)

func _do_tick(is_rollback: bool = false) -> bool:
	var input_frame := get_input_frame(current_tick)
	var previous_frame := get_input_frame(current_tick - 1)
	_current_event_buffer_frame_data = {}
	
	assert(input_frame != null, "Input frame for current_tick is null")
	
	var peers_ticks_since_real_input = {}
	var players := _players_at(current_tick)
	for peer_id in players:
		var peer: Peer = players[peer_id]
		peers_ticks_since_real_input[peer_id] = -1 if peer.last_remote_input_tick_received == 0 \
				or peer.last_remote_input_tick_received < peer.player_from_tick \
		 else current_tick - peer.last_remote_input_tick_received
	input_frame = sync_booster.call_predict_missing_input(peers_ticks_since_real_input, input_frame, previous_frame)
	
	if _player_joins.has(current_tick):
		for peer_id in _player_joins[current_tick]:
			emit_signal("player_joined", peer_id)
	
	# For native nodes that are functions of the tick (NetworkTimer).
	sync_booster.set_current_tick(current_tick)
	_call_network_preprocess(input_frame)
	_call_network_process(input_frame)
	_call_network_postprocess(input_frame)
	
	# If the game was stopped during the last network process, then we return
	# false here, to indicate that a full tick didn't complete and we need to
	# abort.
	if not started:
		return false
	
	_save_current_state(is_rollback)
	
	# Debug check that states computed multiple times with complete inputs are the same
	if debug_check_local_state_consistency and _last_state_hashed_tick >= current_tick:
		_debug_check_consistent_local_state(state_buffer[-1], "Recomputed")
	
	emit_signal("tick_finished", is_rollback)
	return true

func _get_or_create_input_frame(tick: int) -> InputBufferFrame:
	var input_frame: InputBufferFrame
	if input_buffer.size() == 0:
		# From the buffer's first tick: a late joiner may receive later ticks
		# first.
		for t in range(mini(_input_buffer_start_tick, tick), tick + 1):
			input_frame = InputBufferFrame.new()
			input_frame.tick = t
			input_buffer.append(input_frame)
	elif tick > input_buffer[-1].tick:
		var highest = input_buffer[-1].tick
		while highest < tick:
			highest += 1
			input_frame = InputBufferFrame.new()
			input_frame.tick = highest
			input_buffer.append(input_frame)
	else:
		input_frame = get_input_frame(tick)
		if input_frame == null:
			return _handle_fatal_error("Requested input frame (%s) not found in buffer" % tick)
	
	return input_frame

func _cleanup_buffers() -> bool:
	_drop_lagging_spectators()
	# Clean-up the input send queue.
	var min_next_input_tick_requested = _calculate_minimum_next_input_tick_requested()
	# Not past our next tick: a joiner pinned ahead, our only peer, would have
	# the queue's ticks misnumbered.
	while _input_send_queue_start_tick < min_next_input_tick_requested and not _input_send_queue.is_empty():
		_input_send_queue.pop_front()
		_input_send_queue_start_tick += 1
	
	# Clean-up old state buffer frames. We need to keep one extra frame of state
	# because when we rollback, we need to load the state for the frame before
	# the first one we need to run again.
	while state_buffer.size() > max_buffer_size + 1:
		var state_frame_to_retire: StateBufferFrame = state_buffer[0]
		var input_frame = get_input_frame(state_frame_to_retire.tick + 1)
		if input_frame == null:
			var message = "Attempting to retire state frame %s, but input frame %s is missing" % [state_frame_to_retire.tick, state_frame_to_retire.tick + 1]
			push_warning(message)
			if _logger:
				_logger.data['buffer_underrun_message'] = message
			return false
		if not input_frame.is_complete(_players_at(input_frame.tick)):
			var missing: Array = input_frame.get_missing_peers(_players_at(input_frame.tick))
			var message = "Attempting to retire state frame %s, but input frame %s is still missing input (missing peer(s): %s)" % [state_frame_to_retire.tick, input_frame.tick, missing]
			push_warning(message)
			if _logger:
				_logger.data['buffer_underrun_message'] = message
			return false
		
		if state_frame_to_retire.tick > _last_state_hashed_tick:
			var message = "Unable to retire state frame %s, because we haven't hashed it yet" % state_frame_to_retire.tick
			push_warning(message)
			if _logger:
				_logger.data['buffer_underrun_message'] = message
			return false
		
		state_buffer.pop_front()
		var event_frame: EventBufferFrame = event_buffer.pop_front()
		if allow_late_join or debug_check_local_state_consistency_forward:
			_accumulate_events(_event_history, event_frame)
			_compact_event_history(state_frame_to_retire)
			if not _late_joins.is_empty():
				_take_late_join_snapshots(state_frame_to_retire)
		else:
			# Switched on later in the match, the history would miss these.
			_has_event_history = false
		_state_buffer_start_tick += 1
		
		emit_signal("tick_retired", state_frame_to_retire.tick)
	
	# Clean-up old input buffer frames. Unlike state frames, we can have many
	# frames from the future if we are running behind. We don't want having too
	# many future frames to end up discarding input for the current frame, so we
	# only count input frames before the current frame towards the buffer size.
	while (current_tick - _input_buffer_start_tick) > max_buffer_size:
		_input_buffer_start_tick += 1
		input_buffer.pop_front()
	
	while state_hashes.size() > (max_buffer_size * 2):
		var state_hash_to_retire: StateHashFrame = state_hashes[0]
		# A spectator doesn't wait for hashes: those of ticks the players
		# retired before it asked never come, and they are only a check.
		# Nor a joiner, for the ticks before it played.
		var hash_players := _players_at(state_hash_to_retire.tick)
		var waits_for_hashes := not mechanized_replay and not spectating \
				and state_hash_to_retire.tick >= _local_player_from_tick
		if not state_hash_to_retire.is_complete(hash_players) and waits_for_hashes:
			var missing: Array = state_hash_to_retire.get_missing_peers(hash_players)
			var message = "Attempting to retire state hash frame %s, but we're still missing hashes (missing peer(s): %s)" % [state_hash_to_retire.tick, missing]
			push_warning(message)
			if _logger:
				_logger.data['buffer_underrun_message'] = message
			return false
		# Nor before every player has ours: _get_state_hashes_for_peer() can't
		# send it a hash we retired, and it would wait for it for good. Not
		# spectators', who make do without them; a spectator sends none.
		if waits_for_hashes:
			var unacked := []
			for peer in hash_players.values():
				if peer.next_local_hash_tick_requested <= state_hash_to_retire.tick:
					unacked.append(peer.peer_id)
			if not unacked.is_empty():
				var message = "Attempting to retire state hash frame %s, but peer(s) %s haven't received it yet" % [state_hash_to_retire.tick, unacked]
				push_warning(message)
				if _logger:
					_logger.data['buffer_underrun_message'] = message
				return false

		if state_hash_to_retire.mismatch:
			_state_mismatch_count += 1
		else:
			_state_mismatch_count = 0
		if _state_mismatch_count > max_state_mismatch_count:
			_handle_fatal_error("Fatal state mismatch")
			return false
		
		_state_hashes_start_tick += 1
		state_hashes.pop_front()
	
	return true

# A spectator that stopped asking for our input (gone), or asks for ticks so old
# that it can't keep up, would have us keep them for good: we let it go, as
# the time to regain sync allows, and tell it the match is over for it. Each
# player on its own: its input never counted, there is nothing to agree on.
# Whatever Max Ticks To Regain Sync, which only bounds how far behind: a joiner
# making no progress, or a spectator silent, for LATE_JOIN_TIMEOUT_MSECS goes.
func _drop_lagging_spectators() -> void:
	# A spectator sends spectators nothing, nor do they ask it for anything.
	if spectating:
		return
	var lagging := []
	var now := Time.get_ticks_msec()
	for peer in peers.values():
		if not peer.spectator:
			continue
		var behind: int = input_tick - peer.next_local_input_tick_requested
		if peer.joining:
			# Loaded once it asks for more than its first tick.
			if peer.next_local_input_tick_requested > peer.join_tick and behind < peer.join_least_behind:
				peer.join_least_behind = behind
				peer.join_progress_msecs = now
			if now - peer.join_progress_msecs > LATE_JOIN_TIMEOUT_MSECS:
				lagging.append(peer.peer_id)
			continue
		if peer.heard_msecs == 0:
			peer.heard_msecs = now
		if now - peer.heard_msecs > LATE_JOIN_TIMEOUT_MSECS \
				or (max_ticks_to_regain_sync > 0 and behind > max_ticks_to_regain_sync):
			lagging.append(peer.peer_id)
	for peer_id in lagging:
		push_warning("Dropping spectator %s, %s ticks behind" % [peer_id, input_tick - peers[peer_id].next_local_input_tick_requested])
		_send_stop(peer_id, "dropped for making no progress")
		# Stopped, it's gone for everyone: the other players let it go too,
		# one that already has it as a player (its join announced in input we
		# don't have yet) with everyone's say.
		for player_id in _player_peers:
			network_adaptor.send_sync_message(player_id, {type = "peer_dropped", peer = peer_id})
		remove_peer(peer_id)

func get_input_frame(tick: int) -> InputBufferFrame:
	if tick < _input_buffer_start_tick:
		return null
	var index = tick - _input_buffer_start_tick
	if index >= input_buffer.size():
		return null
	var input_frame = input_buffer[index]
	assert(input_frame.tick == tick, "Input frame retreived from input buffer has mismatched tick number")
	return input_frame

func get_latest_input_from_peer(peer_id: int) -> Dictionary:
	if peers.has(peer_id):
		var peer: Peer = peers[peer_id]
		var input_frame = get_input_frame(peer.last_remote_input_tick_received)
		if input_frame:
			return input_frame.get_player_input(peer_id)
	return {}

func get_latest_input_for_node(node: Node) -> Dictionary:
	return get_latest_input_from_peer_for_path(node.get_multiplayer_authority(), str(node.get_path()))

func get_latest_input_from_peer_for_path(peer_id: int, path: String) -> Dictionary:
	return get_latest_input_from_peer(peer_id).get(path, {})

func _get_state_frame(tick: int) -> StateBufferFrame:
	if tick < _state_buffer_start_tick:
		return null
	var index = tick - _state_buffer_start_tick
	if index >= state_buffer.size():
		return null
	var state_frame = state_buffer[index]
	assert(state_frame.tick == tick, "State frame retreived from state buffer has mismatched tick number")
	return state_frame

func _get_event_frame(tick: int) -> EventBufferFrame:
	if tick < _state_buffer_start_tick:
		return null
	var index = tick - _state_buffer_start_tick
	if index >= event_buffer.size():
		return null
	var event_frame = event_buffer[index]
	assert(event_frame.tick == tick, "Event frame retreived from event buffer has mismatched tick number")
	return event_frame

func _get_state_hash_frame(tick: int) -> StateHashFrame:
	if tick < _state_hashes_start_tick:
		return null
	var index = tick - _state_hashes_start_tick
	if index >= state_hashes.size():
		return null
	var state_hash_frame = state_hashes[index]
	assert(state_hash_frame.tick == tick, "State hash frame retreived from state hashes has mismatched tick number")
	return state_hash_frame

func is_current_tick_input_complete() -> bool:
	return current_tick <= _input_complete_tick

func _get_input_messages_from_send_queue_in_range(first_index: int, last_index: int, reverse: bool = false) -> Array:
	var indexes = range(first_index, last_index + 1) if not reverse else range(last_index, first_index - 1, -1)
	
	var all_messages := []
	var msg := {}
	for index in indexes:
		msg[_input_send_queue_start_tick + index] = _input_send_queue[index]
		
		if msg.size() == (mini(max_input_frames_per_message, 255) if max_input_frames_per_message > 0 else 255):
			all_messages.append(msg)
			msg = {}
	
	if msg.size() > 0:
		all_messages.append(msg)
	
	return all_messages

func _get_input_messages_from_send_queue_for_peer(peer: Peer) -> Array:
	# Nothing before what we have (a peer that asked for nothing yet).
	var first_index := maxi(0, peer.next_local_input_tick_requested - _input_send_queue_start_tick)
	var last_index := _input_send_queue.size() - 1
	var max_messages := (max_input_frames_per_message * max_messages_at_once)
	# A peer gets a round trip's worth of ticks before acknowledging any: a few
	# ticks a round trip, it would fall behind over a long one (a player keeps
	# waiting for our input, a spectator lags). Two round trips' worth more,
	# and a joiner far behind more still, to catch up.
	if max_messages > 0:
		max_messages += 2 * ceili(peer.rtt / 1000.0 / tick_time)
		if peer.joining:
			max_messages = maxi(max_messages, LATE_JOIN_MAX_INPUT_TICKS_SENT)
	
	if max_messages <= 0 or (last_index + 1) - first_index <= max_messages:
		return _get_input_messages_from_send_queue_in_range(first_index, last_index, true)
	
	# Only the oldest ticks: the peer can't use any after the first one it's
	# missing (its complete input, what it acknowledges and its lag only count
	# consecutive ticks), and the next ones follow as it acknowledges these.
	return _get_input_messages_from_send_queue_in_range(first_index, first_index + max_messages - 1)

func _get_state_hashes_for_peer(peer: Peer) -> Dictionary:
	var ret := {}
	# We don't keep ours for a spectator (see _cleanup_buffers()), nor those
	# from before a joiner played: it gets those we still have. A player has
	# all it asks for.
	var first_tick := maxi(peer.next_local_hash_tick_requested, _state_hashes_start_tick)
	if first_tick >= _state_hashes_start_tick:
		var index = first_tick - _state_hashes_start_tick
		# Counted in a byte (MessageSerializer).
		while index < state_hashes.size() and ret.size() < 255:
			var state_hash_frame: StateHashFrame = state_hashes[index]
			ret[state_hash_frame.tick] = state_hash_frame.state_hash
			index += 1
	return ret

# Returns whether new averages were calculated (every
# ticks_to_calculate_advantage ticks, for all peers at once).
func _record_advantage(force_calculate_advantage: bool = false) -> bool:
	var calculated := false
	for peer in _players_at(input_tick).values():
		# Number of frames we are predicting for this peer.
		peer.local_lag = (input_tick + 1) - peer.last_remote_input_tick_received
		# Calculate the advantage the peer has over us.
		if peer.record_advantage(ticks_to_calculate_advantage if not force_calculate_advantage else 0):
			calculated = true
		
		if _logger:
			_logger.add_value("peer_%s" % peer.peer_id, {
				local_lag = peer.local_lag,
				remote_lag = peer.remote_lag,
				advantage = peer.local_lag - peer.remote_lag,
				calculated_advantage = peer.calculated_advantage,
			})
	return calculated

func _calculate_skip_ticks() -> bool:
	# Attempt to find the greatest advantage.
	var max_advantage: float
	for peer in _players_at(input_tick).values():
		max_advantage = max(max_advantage, peer.calculated_advantage)
	
	# Within reach of the rate: _adjust_tick_rate() closes the gap.
	if _can_adjust_tick_rate() and max_advantage / 2 <= max_lead_to_adjust_tick_rate:
		return false
	
	if max_advantage >= 2.0 and skip_ticks == 0:
		skip_ticks = int(max_advantage / 2)
		_set_tick_rate_offset(0)
		emit_signal("skip_ticks_flagged", skip_ticks)
		return true
	
	return false

func _can_adjust_tick_rate() -> bool:
	return max_tick_rate_slowdown > 0.0

# Starts running slower or faster for a while, if this peer is ahead of or
# behind the others' average: as they all aim for it, they meet there, without
# needing to agree. Called when new advantages were calculated, and only when
# the rate isn't adjusted already: the advantages measured while it was are
# cleared when it ends, so that the next ones are fresh.
func _adjust_tick_rate() -> void:
	if not _can_adjust_tick_rate() or _tick_rate_offset != 0 or _player_peers.is_empty() or _base_tick_rate <= 0:
		return
	# How many ticks ahead of the others this peer is on average, and so of the
	# average of all peers, this one included (n others, n + 1 in all), and
	# of the one furthest behind.
	var total := 0.0
	var max_lead := 0.0
	var players := _players_at(input_tick)
	for peer in players.values():
		var lead: float = peer.calculated_advantage / 2.0
		# Too far apart: the one ahead skips ticks, which closes the gap alone.
		if absf(lead) > max_lead_to_adjust_tick_rate:
			return
		total += lead
		max_lead = maxf(max_lead, lead)
	# A spectator isn't in the average: the players don't move toward it.
	var ahead := total / (players.size() + (0 if spectating else 1))
	# Close to the average, but a tick or more ahead of a peer: still moving
	# toward it. Among many peers, one behind is close to everyone's average
	# but its own, and if it can't speed up (frames late), nobody else would
	# close the gap (nor skip, as it is within reach).
	if absf(ahead) < TICK_RATE_DEAD_ZONE and not (ahead > 0 and max_lead >= 1.0):
		return
	var max_fraction := max_tick_rate_slowdown if ahead > 0 else max_tick_rate_speedup
	if max_fraction <= 0.0:
		return
	# Faster only with time to spare: frames on time, interpolation running.
	if ahead < 0 and (_interpolation_paused or _frame_interval_average > _frame_reference_usecs() * 1.03):
		return
	var max_offset := maxi(1, int(_base_tick_rate * max_fraction))
	# Running k ticks per second off the base rate b for N ticks loses (slower)
	# or gains (faster) N * k / (b -+ k) ticks: doing it within a window of w
	# ticks takes k >= c * b / (w + c) slower, c * b / (w - c) faster. The
	# smallest such k, or the most allowed, for as long as it takes, a window
	# at most.
	var window := maxi(1, ticks_to_calculate_advantage)
	var c := absf(ahead)
	var needed_offset := c * _base_tick_rate / (window + c) if ahead > 0 \
		else (c * _base_tick_rate / (window - c) if window > c else INF)
	# Not rounded up past a whole number by float error.
	var offset := clampi(ceili(needed_offset - 0.000001), 1, max_offset) if needed_offset != INF else max_offset
	var rate := _base_tick_rate - offset if ahead > 0 else _base_tick_rate + offset
	_tick_rate_ticks_left = mini(ceili(c * rate / offset - 0.000001), window)
	_set_tick_rate_offset(-offset if ahead > 0 else offset)

func _set_tick_rate_offset(offset: int) -> void:
	if offset == _tick_rate_offset:
		return
	_tick_rate_offset = offset
	if offset == 0:
		_tick_rate_ticks_left = 0
	Engine.physics_ticks_per_second = _base_tick_rate + offset
	emit_signal("tick_rate_changed", Engine.physics_ticks_per_second)

# How many ticks this peer is ahead of the peer it is most ahead of (see
# min_lag_to_regain_sync).
func _calculate_max_lead() -> float:
	var max_lead := 0.0
	for peer in _players_at(input_tick).values():
		max_lead = max(max_lead, (peer.local_lag - peer.remote_lag) / 2.0)
	return max_lead

func _calculate_minimum_next_input_tick_requested() -> int:
	if peers.size() == 0:
		return 1
	var peer_list := peers.values().duplicate()
	var result: int = peer_list.pop_front().next_local_input_tick_requested
	for peer in peer_list:
		result = min(result, peer.next_local_input_tick_requested)
	return result

func _send_input_messages_to_peer(peer_id: int) -> void:
	assert(peer_id != network_adaptor.get_network_unique_id(), "Cannot send input to ourselves")
	var peer = peers[peer_id]
	if peer.joining and not peer.join_heard:
		return
	
	var state_hashes = _get_state_hashes_for_peer(peer)
	var input_messages = _get_input_messages_from_send_queue_for_peer(peer)
	# Nothing to send when the peer has all our input, as while we are stalled
	# (sync lost, skipping ticks): a message without input still brings it
	# what we received, without which it can't send us more than the oldest
	# ticks we're missing, nor retire the state hashes we need.
	if input_messages.is_empty():
		input_messages.append({})
	
	if _logger:
		_logger.data['messages_sent_to_peer_%s' % peer_id] = input_messages.size()
	
	for input in input_messages:
		var msg = {
			MessageSerializer.InputMessageKey.NEXT_INPUT_TICK_REQUESTED: peer.last_remote_input_tick_received + 1,
			MessageSerializer.InputMessageKey.INPUT: input,
			MessageSerializer.InputMessageKey.NEXT_HASH_TICK_REQUESTED: peer.last_remote_hash_tick_received + 1,
			MessageSerializer.InputMessageKey.STATE_HASHES: state_hashes,
		}
		
		var bytes = message_serializer.serialize_message(msg)
		
		# See https://gafferongames.com/post/packet_fragmentation_and_reassembly/
		if debug_message_bytes > 0:
			if bytes.size() > debug_message_bytes:
				push_error("Sending message w/ size %s bytes" % bytes.size())
		
		if _logger:
			_logger.add_value("messages_sent_to_peer_%s_size" % peer_id, bytes.size())
			_logger.increment_value("messages_sent_to_peer_%s_total_size" % peer_id, bytes.size())
			_logger.merge_array_value("input_ticks_sent_to_peer_%s" % peer_id, input.keys())
		
		#var ticks = msg[InputMessageKey.INPUT].keys()
		#print ("[%s] Sending ticks %s - %s" % [current_tick, min(ticks[0], ticks[-1]), max(ticks[0], ticks[-1])])
		
		network_adaptor.send_input_tick(peer_id, bytes)

func _send_input_messages_to_all_peers() -> void:
	if debug_skip_nth_message > 1:
		_debug_skip_nth_message_counter += 1
		if _debug_skip_nth_message_counter >= debug_skip_nth_message:
			print("[%s] Skipping message to simulate packet loss" % current_tick)
			_debug_skip_nth_message_counter = 0
			return
	
	if spectating:
		_send_spectating_messages_to_player_peers()
		return
	for peer_id in peers:
		_send_input_messages_to_peer(peer_id)

# Without input nor state hashes: only what we received, for the players to send
# us the next ticks (and hashes), and to tell we're still watching.
func _send_spectating_messages_to_player_peers() -> void:
	for peer in _player_peers.values():
		var msg = {
			MessageSerializer.InputMessageKey.NEXT_INPUT_TICK_REQUESTED: peer.last_remote_input_tick_received + 1,
			MessageSerializer.InputMessageKey.INPUT: {},
			MessageSerializer.InputMessageKey.NEXT_HASH_TICK_REQUESTED: peer.last_remote_hash_tick_received + 1,
			MessageSerializer.InputMessageKey.STATE_HASHES: {},
		}
		network_adaptor.send_input_tick(peer.peer_id, message_serializer.serialize_message(msg))

func _physics_process(_delta: float) -> void:
	if not started:
		return
	var start_time := Time.get_ticks_usec()
	_begin_frame(start_time)
	_run_physics_process(start_time)
	# A spectator behind the input it has (a late joiner, one that was slow)
	# catches up: more ticks, with half a tick's time at most.
	while started and spectating and _input_complete_tick - current_tick > input_delay + 2 \
			and Time.get_ticks_usec() - start_time < tick_time * 500000.0:
		_update_state_hashes()
		_run_physics_process(Time.get_ticks_usec())
	if _late_join_syncing:
		_check_late_join_synced()
	# Here, for every path through it: ticks skipped to regain sync work too,
	# and the perf summary's steps timed in them.
	var work_usecs: int = Time.get_ticks_usec() - start_time
	_frame_work_usecs += work_usecs
	if debug_perf_summary:
		_perf_add("physics_process", work_usecs)

func _run_physics_process(start_time: int) -> void:
	if _logger:
		_logger.begin_tick(current_tick + 1)
		_logger.data['input_complete_tick'] = _input_complete_tick
		_logger.data['state_complete_tick'] = _state_complete_tick
	
	# @todo Is there a way we can move this to _remote_start()?
	# Store an initial state before any ticks: tick 0's, or the one a replay
	# started from (_start_from_state()).
	if state_buffer.is_empty() and current_tick >= 0:
		_save_current_state()
		if _logger:
			_calculate_data_hash(state_buffer[0].data)
			_logger.write_state(current_tick, state_buffer[0].data)
	
	#####
	# STEP 1: PERFORM ANY ROLLBACKS, IF NECESSARY.
	#####
	
	if mechanized:
		rollback_ticks = mechanized_rollback_ticks
	else:
		if debug_random_rollback_ticks > 0:
			randomize()
			debug_rollback_ticks = randi() % debug_random_rollback_ticks
		# Once there are states to go back to, from tick 0 or a replay's start.
		if debug_rollback_ticks > 0 and current_tick - _start_tick >= debug_rollback_ticks:
			rollback_ticks = max(rollback_ticks, debug_rollback_ticks)
		if debug_late_packet_ticks > 0 and current_tick - _start_tick >= debug_late_packet_ticks \
				and current_tick % debug_late_packet_period == 0:
			_debug_late_packet_arrived = true
			_update_input_complete_tick()
			_debug_late_packet_arrived = false
			rollback_ticks = max(rollback_ticks, debug_late_packet_ticks)
		
		rollback_ticks = _apply_rollback_deferral(rollback_ticks)
		
		# We need to reload the current tick since we did a partial rollback
		# to the previous tick in order to interpolate.
		if _interpolating and current_tick > 0 and rollback_ticks == 0:
			_call_load_state(state_buffer[-1].data, LoadType.INTERPOLATION_FORWARD, state_buffer[-1].tick)
			if debug_check_local_state_consistency:
				# Save already computed states for better logging in case of discrepancy
				_debug_check_local_state_consistency_buffer = [state_buffer[-1]]
				var state := StateBufferFrame.new(current_tick, _call_save_state())
				_debug_check_consistent_local_state(state, "Loaded interpolation forward")
		
	
	# Paused or resumed only here, where the state is the last tick's: after the
	# load forward, before the rollback and the tick.
	_interpolating = interpolation and (mechanized or not _interpolation_paused)
	
	# Where a forward load brings the display to the last tick: its effects show.
	_effect_manager.show_pending()
	
	if rollback_ticks > 0:
		if _logger:
			_logger.data['rollback_ticks'] = rollback_ticks
			_logger.start_timing('rollback')
		
		var original_tick = current_tick
		_rollback_last_tick = original_tick
		var rollback_start_usec := Time.get_ticks_usec()
		var rollback_length: int = rollback_ticks
		
		# Rollback our internal state.
		assert(rollback_ticks + 1 <= state_buffer.size(), "Not enough state in buffer to rollback requested number of frames")
		if rollback_ticks + 1 > state_buffer.size():
			_handle_fatal_error("Not enough state in buffer to rollback %s frames" % rollback_ticks)
			return
		
		if state_buffer[-rollback_ticks - 1].skipped:
			_handle_fatal_error("Rollback to tick %s, whose state was not saved" % state_buffer[-rollback_ticks - 1].tick)
			return
		_call_load_state(state_buffer[-rollback_ticks - 1].data, LoadType.ROLLBACK, state_buffer[-rollback_ticks - 1].tick)
		
		current_tick -= rollback_ticks
		_effect_manager.begin_rollback(current_tick)
		
		if debug_check_local_state_consistency:
			# Save already computed states for better logging in case of discrepancy
			_debug_check_local_state_consistency_buffer = state_buffer.slice(state_buffer.size() - rollback_ticks - 1)
			# Debug check that states computed multiple times with complete inputs are the same
			if _last_state_hashed_tick >= current_tick:
				var state := StateBufferFrame.new(current_tick, _call_save_state())
				_debug_check_consistent_local_state(state, "Loaded")
		
		state_buffer.resize(state_buffer.size() - rollback_ticks)
		event_buffer.resize(event_buffer.size() - rollback_ticks)
		
		# Invalidate sync ticks after this, they may be asked for again
		if requested_input_complete_tick > 0 and current_tick < requested_input_complete_tick:
			requested_input_complete_tick = 0
		
		emit_signal("state_loaded", rollback_ticks)
		
		_in_rollback = true
		
		# Iterate forward until we're at the same spot we left off.
		while rollback_ticks > 0:
			current_tick += 1
			if not _do_tick(true):
				return
			rollback_ticks -= 1
		assert(current_tick == original_tick, "Rollback didn't return to the original tick")
		
		_in_rollback = false
		_effect_manager.end_rollback()
		var usecs_per_tick := float(Time.get_ticks_usec() - rollback_start_usec) / rollback_length
		_rollback_usecs_per_tick = usecs_per_tick if _rollback_usecs_per_tick <= 0.0 \
			else lerp(_rollback_usecs_per_tick, usecs_per_tick, 0.2)
		_frame_rollback_usecs += Time.get_ticks_usec() - rollback_start_usec
		if debug_perf_summary:
			_perf_add("rollback", Time.get_ticks_usec() - rollback_start_usec)
			_perf_rollbacks += 1
			_perf_rollback_ticks += rollback_length
			_perf_rollback_max = max(_perf_rollback_max, rollback_length)
		
		if _logger:
			_logger.stop_timing('rollback')
	
	#####
	# STEP 2: SKIP TICKS, IF NECESSARY.
	#####
	
	if not mechanized_replay:
		var advantage_calculated := _record_advantage()
		if _logger and _tick_rate_offset != 0:
			_logger.data['tick_rate'] = Engine.physics_ticks_per_second
		
		# A spectator has no input of its own to send ahead, nothing to keep
		# up with: rather than predict so far that it loses sync (the states
		# to retire not complete yet), it waits for the players' input, as far
		# behind them as its link makes it.
		if spectating and _ticks_spent_regaining_sync == 0 \
				and current_tick - _input_complete_tick >= max_buffer_size - 1:
			_send_input_messages_to_all_peers()
			if _logger:
				_logger.skip_tick(DeltaRollbackLogger.SkipReason.INPUT_BUFFER_UNDERRUN, start_time)
			return
		
		if _ticks_spent_regaining_sync > 0:
			_ticks_spent_regaining_sync += 1
			# A spectator waits: the players drop it when it's too far behind.
			if not spectating and max_ticks_to_regain_sync > 0 and _ticks_spent_regaining_sync > max_ticks_to_regain_sync:
				_handle_fatal_error("Unable to regain synchronization")
				return
			
			# Check again if we're still getting input buffer underruns.
			if not _cleanup_buffers():
				# This can happen if there's a fatal error in _cleanup_buffers().
				if not started:
					return
				# Even when we're skipping ticks, still send input.
				_send_input_messages_to_all_peers()
				if _logger:
					_logger.skip_tick(DeltaRollbackLogger.SkipReason.INPUT_BUFFER_UNDERRUN, start_time)
				return
			
			# Check if we are still too far ahead of a peer to regain sync.
			if min_lag_to_regain_sync > 0 and _calculate_max_lead() > min_lag_to_regain_sync:
				#print ("REGAINING SYNC: wait for the peers to catch up")
				# Even when we're skipping ticks, still send input.
				_send_input_messages_to_all_peers()
				if _logger:
					_logger.skip_tick(DeltaRollbackLogger.SkipReason.WAITING_TO_REGAIN_SYNC, start_time)
				return
			
			# If we've reach this point, that means we've regained sync!
			_ticks_spent_regaining_sync = 0
			emit_signal("sync_regained")
			
			# We don't want to skip ticks through the normal mechanism, because
			# any skips that were previously calculated don't apply anymore.
			# Nor the advantages recorded while waiting: the peer's lag is only
			# updated by its messages, which didn't come, while ours grew.
			skip_ticks = 0
			for peer in peers.values():
				peer.clear_advantage()
		
		# Attempt to clean up buffers, but if we can't, that means we've lost sync.
		elif not _cleanup_buffers():
			# This can happen if there's a fatal error in _cleanup_buffers().
			if not started:
				return
			emit_signal("sync_lost")
			_ticks_spent_regaining_sync = 1
			_set_tick_rate_offset(0)
			# Even when we're skipping ticks, still send input.
			_send_input_messages_to_all_peers()
			if _logger:
				_logger.skip_tick(DeltaRollbackLogger.SkipReason.INPUT_BUFFER_UNDERRUN, start_time)
			return
		
		if skip_ticks > 0:
			skip_ticks -= 1
			if skip_ticks == 0:
				for peer in peers.values():
					peer.clear_advantage()
			else:
				# Even when we're skipping ticks, still send input.
				_send_input_messages_to_all_peers()
				if _logger:
					_logger.skip_tick(DeltaRollbackLogger.SkipReason.ADVANTAGE_ADJUSTMENT, start_time)
				return
		
		if _calculate_skip_ticks():
			# This means we need to skip some ticks, so may as well start now!
			if _logger:
				_logger.skip_tick(DeltaRollbackLogger.SkipReason.ADVANTAGE_ADJUSTMENT, start_time)
			return
		
		if _tick_rate_offset != 0:
			tick_rate_adjusted_ticks += 1
			_tick_rate_ticks_left -= 1
			if _tick_rate_ticks_left <= 0:
				_set_tick_rate_offset(0)
				# Measured while the rate was changing: stale.
				for peer in peers.values():
					peer.clear_advantage()
		elif advantage_calculated:
			_adjust_tick_rate()
	else:
		_cleanup_buffers()
	
	#####
	# STEP 3: GATHER INPUT AND RUN CURRENT TICK
	#####
	
	if _late_join_waiting:
		# Nothing to predict from yet: the match goes on once the players'
		# input after the loaded tick comes.
		if _input_complete_tick <= _start_tick:
			_send_input_messages_to_all_peers()
			if _logger:
				_logger.skip_tick(DeltaRollbackLogger.SkipReason.INPUT_BUFFER_UNDERRUN, start_time)
			return
		_late_join_waiting = false
	
	if debug_check_local_state_consistency_forward and current_tick > 0 and _has_event_history:
		_debug_check_load_state_forward()
	
	input_tick += 1
	current_tick += 1
	
	if spectating and _local_player_from_tick >= 0 and input_tick >= _local_player_from_tick:
		_become_player()
	
	if spectating:
		# No input of ours in it: the players' are predicted until they come.
		if _get_or_create_input_frame(input_tick) == null:
			return
		_send_input_messages_to_all_peers()
	elif not mechanized:
		var input_frame := _get_or_create_input_frame(input_tick)
		# The underlying error would have already been reported in
		# _get_or_create_input_frame() so we can just return here.
		if input_frame == null:
			return
		
		if _logger:
			_logger.data['input_tick'] = input_tick
		
		var local_input = _call_get_local_input()
		if not _joiners_to_announce.is_empty():
			_announce_player_joins(local_input)
		_calculate_data_hash(local_input)
		input_frame.add_input_for_player(network_adaptor.get_network_unique_id(), local_input, false)
		
		# Only serialize and send input when we have real remote peers.
		if peers.size() > 0:
			var serialized_input := message_serializer.serialize_input(local_input)
			
			# check that the serialized then unserialized input matches the original 
			if debug_check_message_serializer_roundtrip:
				var unserialized_input := message_serializer.unserialize_input(serialized_input)
				_calculate_data_hash(unserialized_input)
				if local_input["$"] != unserialized_input["$"]:
					push_error("The input is different after being serialized and unserialized \n Original: %s \n Unserialized: %s" % [ordered_dict2str(local_input), ordered_dict2str(unserialized_input)])
				
			_input_send_queue.append(serialized_input)
			assert(input_tick == _input_send_queue_start_tick + _input_send_queue.size() - 1, "Input send queue ticks numbers are misaligned")
			_send_input_messages_to_all_peers()
		else:
			# Kept in step for when peers come (a joiner).
			_input_send_queue.clear()
			_input_send_queue_start_tick = input_tick + 1
	
	if current_tick > 0:
		if _logger:
			_logger.start_timing("current_tick")
		
		if not _do_tick():
			return
		
		if _logger:
			_logger.stop_timing("current_tick")
		
		if _interpolating:
			# Return to state from the previous frame, so we can interpolate
			# towards the state of the current frame.
			_call_load_state(state_buffer[-2].data, LoadType.INTERPOLATION_BACKWARD, state_buffer[-2].tick)
			if debug_check_local_state_consistency:
				# Save already computed states for better logging in case of discrepancy
				_debug_check_local_state_consistency_buffer = [state_buffer[-2]]
				var state := StateBufferFrame.new(current_tick - 1, _call_save_state())
				_debug_check_consistent_local_state(state, "Loaded interpolation backward")
		elif interpolation:
			# Paused: the visuals set as interpolating at weight 1 would. With
			# the same state on both sides, nothing that is simulated changes
			# (PropertyManager skips identical slots).
			var data: Dictionary = state_buffer[-1].data
			sync_booster.call_interpolate_state(data, data, 1.0)
			interpolation_paused_ticks += 1
	
	_time_since_last_tick = 0.0
	_ran_physics_process = true
	_ticks_since_last_interpolation_frame += 1
	if debug_perf_summary:
		_perf_ticks += 1
		_perf_ticks_this_frame += 1
	
	var total_time_msecs = float(Time.get_ticks_usec() - start_time) / 1000.0
	if debug_physics_process_msecs > 0 and total_time_msecs > debug_physics_process_msecs:
		push_error("[%s] SyncManager._physics_process() took %.02fms" % [current_tick, total_time_msecs])
	
	if _logger:
		_logger.end_tick(start_time)

func _process(delta: float) -> void:
	if not started:
		return
	
	var start_time = Time.get_ticks_usec()
	_begin_frame(start_time)
	
	# These are things that we want to run during "interpolation frames", in
	# order to slim down the normal frames. Or, if interpolation is disabled,
	# we need to run these always. If we haven't managed to run this for more
	# one tick, we make sure to sneak it in just in case.
	if _logger:
		_logger.begin_interpolation_frame(current_tick)
	
	_time_since_last_tick += delta
	
	# Don't interpolate if we are skipping ticks, or just ran physics process.
	if _interpolating and skip_ticks == 0 and _ticks_spent_regaining_sync == 0:
		_call_interpolate_state(Engine.get_physics_interpolation_fraction())
	
	# If there are no other players, then we'll never receive any new input,
	# so we need to update the _input_complete_tick elsewhere. Here's a fine
	# place to do it!
	if _player_peers.is_empty():
		_update_input_complete_tick()
	
	_update_state_hashes()
	
	if interpolation:
		emit_signal("interpolation_frame")
	
	# Do this last to catch any data that came in late.
	network_adaptor.poll()
	
	if _logger:
		_logger.end_interpolation_frame(start_time)
	
	# Clear counter, because we just did an interpolation frame.
	_ticks_since_last_interpolation_frame = 0
	
	# Clear flag so subsequent _process() calls will know that they weren't
	# preceeded by _physics_process().
	_ran_physics_process = false
	_frame_work_usecs += Time.get_ticks_usec() - start_time
	_frame_open = false
	if debug_perf_summary:
		_perf_add("process", Time.get_ticks_usec() - start_time)
	
	var total_time_msecs = float(Time.get_ticks_usec() - start_time) / 1000.0
	if debug_process_msecs > 0 and total_time_msecs > debug_process_msecs:
		push_error("[%s] SyncManager._process() took %.02fms" % [current_tick, total_time_msecs])


# Calculates the hash without any keys that start with '_' (if string)
# or less than 0 (if integer) to allow some properties to not count when
# comparing comparing data.
#
# This can be used for comparing input (to prevent a difference betwen predicted
# input and real input from causing a rollback) and state (for when a property
# is only used for interpolation).
func _calculate_data_hash(input: Dictionary) -> int:
	var serialized_hash: = sync_booster.hash_special_dict(input)
	input['$'] = serialized_hash
	return serialized_hash

func _on_received_input_tick(peer_id: int, serialized_msg: PackedByteArray) -> void:
	if not started:
		return
	
	var msg = message_serializer.unserialize_message(serialized_msg)
	
	var all_remote_input: Dictionary = msg[MessageSerializer.InputMessageKey.INPUT]
	var all_remote_ticks = all_remote_input.keys()
	all_remote_ticks.sort()
	
	# Without input, the message only brings what the peer received from us
	# (see _send_input_messages_to_peer()). It can't have asked for more than
	# our next tick, unless it is from a previous match.
	if all_remote_ticks.is_empty():
		if msg[MessageSerializer.InputMessageKey.NEXT_INPUT_TICK_REQUESTED] > input_tick + 1:
			return
	# A spectator, behind, is sent more ticks at once (see
	# _get_input_messages_from_send_queue_for_peer()).
	elif all_remote_ticks[0] >= input_tick + (maxi(max_buffer_size, max_ticks_to_regain_sync) if spectating else max_buffer_size):
		# This either happens because we are really far behind (but maybe, just
		# maybe could catch up) or we are receiving old ticks from a previous
		# round that hadn't yet arrived. Just discard the message and hope for
		# the best, but if we can't keep up, another one of the fail safes will
		# detect that we are out of sync.
		print ("Discarding message from the future")
		# We return because we don't even want to do the accounting that happens
		# after integrating input, since the data in this message could be
		# totally bunk (ie. if it's from a previous match).
		return
	
	if _logger:
		_logger.begin_interframe()
	
	# From a peer we removed, still on its way.
	var peer: Peer = peers.get(peer_id)
	if peer == null:
		return
	
	# A spectator only tells what it received: the ticks to send it next.
	if peer.spectator:
		peer.join_heard = true
		peer.heard_msecs = Time.get_ticks_msec()
		peer.next_local_input_tick_requested = max(msg[MessageSerializer.InputMessageKey.NEXT_INPUT_TICK_REQUESTED], peer.next_local_input_tick_requested)
		peer.next_local_hash_tick_requested = max(msg[MessageSerializer.InputMessageKey.NEXT_HASH_TICK_REQUESTED], peer.next_local_hash_tick_requested)
		return
	
	# Only process if it contains ticks we haven't received yet.
	if not all_remote_ticks.is_empty() and all_remote_ticks[-1] > peer.last_remote_input_tick_received:
		# Integrate the input we received into the input buffer.
		for remote_tick in all_remote_ticks:
			# Skip ticks we already have.
			if remote_tick <= peer.last_remote_input_tick_received:
				continue
			# This means the input frame has already been retired, which can only
			# happen if we already had all the input.
			if remote_tick < _input_buffer_start_tick:
				continue
			
			var remote_input = message_serializer.unserialize_input(all_remote_input[remote_tick])
			var input_frame := _get_or_create_input_frame(remote_tick)
			if input_frame == null:
				# _get_or_create_input_frame() will have already flagged the error,
				# so we can just return here.
				return
			
			# If we already have non-predicted input for this peer, then skip it.
			if not input_frame.is_player_input_predicted(peer_id):
				continue
			
			# Before the tick the joiner plays from is complete: its input
			# comes after this one's.
			if remote_input.has(JOIN_INPUT_KEY):
				_schedule_player_joins(remote_input[JOIN_INPUT_KEY])
			
			#print ("Received remote tick %s from %s" % [remote_tick, peer_id])
			if _logger:
				_logger.add_value('remote_ticks_received_from_%s' % peer_id, remote_tick)
			
			# If we received a tick in the past and we aren't already setup to
			# rollback earlier than that...
			var tick_delta = current_tick - remote_tick
			if tick_delta >= 0 and rollback_ticks <= tick_delta:
				# Grab our predicted input, and store the remote input.
				var local_input = input_frame.get_player_input(peer_id)
				input_frame.add_input_for_player(peer_id, remote_input, false)
				
				# Check if the remote input matches what we had predicted, if not,
				# flag that we need to rollback.
				if local_input['$'] != remote_input['$']:
					rollback_ticks = tick_delta + 1
					_mispredicted_peers[peer_id] = true
					emit_signal("prediction_missed", remote_tick, peer_id, local_input, remote_input)
					emit_signal("rollback_flagged", remote_tick)
			else:
				# Otherwise, just store it.
				input_frame.add_input_for_player(peer_id, remote_input, false)
		
		# Find what the last remote tick we received was after filling these in.
		var index = (peer.last_remote_input_tick_received - _input_buffer_start_tick) + 1
		while index < input_buffer.size() and not input_buffer[index].is_player_input_predicted(peer_id):
			peer.last_remote_input_tick_received += 1
			index += 1
		
		# Update _input_complete_tick for new input.
		_update_input_complete_tick()
	
	# Record the next frame the other peer needs.
	peer.next_local_input_tick_requested = max(msg[MessageSerializer.InputMessageKey.NEXT_INPUT_TICK_REQUESTED], peer.next_local_input_tick_requested)
	
	# Number of frames the remote is predicting for us. None for a spectator,
	# who sends no input.
	if not spectating:
		peer.remote_lag = (peer.last_remote_input_tick_received + 1) - peer.next_local_input_tick_requested
	
	# Process state hashes.
	var remote_state_hashes = msg[MessageSerializer.InputMessageKey.STATE_HASHES]
	for remote_tick in remote_state_hashes:
		var state_hash_frame := _get_state_hash_frame(remote_tick)
		if state_hash_frame and not state_hash_frame.has_peer_hash(peer_id):
			if not state_hash_frame.record_peer_hash(peer_id, remote_state_hashes[remote_tick]):
				emit_signal("remote_state_mismatch", remote_tick, peer_id, state_hash_frame.state_hash, remote_state_hashes[remote_tick])
			if _late_join_syncing:
				_count_late_join_hash(state_hash_frame)
	
	if spectating:
		# The players send what they still have of what we asked for (see
		# _get_state_hashes_for_peer()), and we don't wait for the rest (see
		# _cleanup_buffers()): what's older won't come, or is no use.
		var oldest: int = _state_hashes_start_tick
		if not remote_state_hashes.is_empty():
			oldest = maxi(oldest, remote_state_hashes.keys().min())
		peer.last_remote_hash_tick_received = maxi(peer.last_remote_hash_tick_received, oldest - 1)
	
	# Find what the last remote state hash we received was after filling these in.
	var index = (peer.last_remote_hash_tick_received - _state_hashes_start_tick) + 1
	while index < state_hashes.size() and state_hashes[index].has_peer_hash(peer_id):
		peer.last_remote_hash_tick_received += 1
		index += 1
	
	# Record the next state hash that the other peer needs.
	peer.next_local_hash_tick_requested = max(msg[MessageSerializer.InputMessageKey.NEXT_HASH_TICK_REQUESTED], peer.next_local_hash_tick_requested)

func reset_mechanized_data() -> void:
	mechanized_input_received.clear()
	mechanized_rollback_ticks = 0

func _process_mechanized_input() -> void:
	for peer_id in mechanized_input_received:
		var peer_input = mechanized_input_received[peer_id]
		for tick in peer_input:
			var input = peer_input[tick]
			var input_frame := _get_or_create_input_frame(int(tick))
			input_frame.add_input_for_player(int(peer_id), input, false)
			if input.has(JOIN_INPUT_KEY):
				_schedule_player_joins(input[JOIN_INPUT_KEY])

func execute_mechanized_tick() -> void:
	_process_mechanized_input()
	_physics_process(tick_time)
	reset_mechanized_data()

func execute_mechanized_interpolation_frame(delta: float) -> void:
	_update_input_complete_tick()
	_ran_physics_process = false
	_process(delta)
	_process_mechanized_input()
	reset_mechanized_data()

func execute_mechanized_interframe() -> void:
	_process_mechanized_input()
	reset_mechanized_data()

func sort_dictionary_keys(input: Dictionary) -> Dictionary:
	var output := {}
	
	var keys = input.keys()
	keys.sort()
	for key in keys:
		output[key] = input[key]
	
	return output

func spawn(name: String, parent: Node, scene: PackedScene, data = {}, rename: bool = true) -> Node:
	if not started:
		var res = scene.instantiate()
		parent.add_child(res)
		_spawn_manager._init_node(res, data)
		return res
	
	return _spawn_manager.spawn(name, parent, scene, data, rename)

func despawn(node: Node) -> void:
	if not started:
		node.queue_free()
	else:
		_spawn_manager.despawn(node)
 
 

func set_synced(node: Node, property: String, value, interpolate:=false, deep_duplicate_value:=false) -> void:
	if not node.is_inside_tree() or not started:
		node.set_indexed(property, value)
		return
	
	if _in_load_state:
		return
		
	_property_manager.set_synced(current_tick, node, property, value, interpolate, deep_duplicate_value)

func connect_signal(node: Node, name: String, target: Node, method: String, binds := [], flags := 0) -> void:
	if not started:
		var callable: = Callable(target, method).bindv(binds)
		node.connect(name, callable, flags)
		return
	
	_spawn_manager.connect_signal(node, name, target, method, binds, flags)

func is_in_rollback() -> bool:
	return _in_rollback

func set_default_sound_bus(bus: String) -> void:
	if _effect_manager == null:
		await self.ready
	_effect_manager.default_bus = bus

## A sound for a network tick, played once whatever the rollbacks re-simulating
## that tick (see EffectManager.gd).
func play_sound(identifier: String, sound: AudioStream, info: Dictionary = {}) -> void:
	_effect_manager.play_sound(identifier, sound, info)

## A visual effect that nothing in the game reads (see EffectManager.gd), for a
## network tick: not a network node, so not saved, loaded or re-spawned by
## rollbacks, and not restarted when they re-simulate the tick that started
## it. key names it among the effects started on that tick.
func spawn_effect(key: String, parent: Node, scene: PackedScene, args: Array = []) -> void:
	_effect_manager.spawn(key, parent, scene, args)

## Called by an effect once it is over.
func end_effect(node: Node) -> void:
	_effect_manager.end_effect(node)

## Asks the last effect started under key to end (see EffectManager.gd): undone
## if a rollback finds it no longer asked.
func end_effect_by_key(key: String) -> void:
	_effect_manager.end_by_key(key)

## Effect instances made in advance, as add_node_in_pool() does for spawns.
func prewarm_effect(scene: PackedScene, count: int) -> void:
	_effect_manager.prewarm(scene, count)

func ensure_current_tick_input_complete() -> bool:
	if is_current_tick_input_complete():
		return true
	if requested_input_complete_tick == 0 or requested_input_complete_tick > current_tick:
		requested_input_complete_tick = current_tick
	return false

func ordered_dict2str(dict: Dictionary) -> String:
	var ret := "{"
	for i in dict.size():
		var key = dict.keys()[i]
		var value = dict[key]
		var value_str := ordered_dict2str(value) if value is Dictionary else str(value)
		ret += "%s:%s" % [key, value_str]
		if i != dict.size() - 1:
			ret += ", "
	ret += "}"
	return ret

func _debug_check_consistent_local_state(state: StateBufferFrame, message := "Loaded") -> void:
	var previously_hashed_frame := _get_state_hash_frame(current_tick)
	var previous_state = _debug_check_local_state_consistency_buffer.pop_front()
	# Nothing to compare when either state was not saved (_can_skip_state()).
	if state.skipped or (previous_state and previous_state.skipped) \
			or (previously_hashed_frame and previously_hashed_frame.state_hash == SKIPPED_STATE_HASH):
		return
	var hashed_state := _calculate_data_hash(state.data)
	if previously_hashed_frame and previously_hashed_frame.state_hash != hashed_state:
		var comparer = DebugStateComparer.new()
		comparer.find_mismatches(previous_state.data, state.data)
		push_error("%s state is not consistent with saved state:\n %s" % [
			message,
			comparer.print_mismatches(),
			])

func register_event(node: Node, data) -> void:
	if disable_event_registration or not started:
		return
	
	var path := str(node.get_path())
	
	if not _event_scripts.has(path) and not _event_scripts_in_buffer.has(path):
		_event_scripts_in_buffer[path] = node.get_script().resource_path
	
	if not _current_event_buffer_frame_data.has(path):
		_current_event_buffer_frame_data[path] = []
	
	_current_event_buffer_frame_data[path].append(data)


func add_node_in_pool(scene: PackedScene) -> void:
	_spawn_manager.add_node_in_pool(scene)


# Loads the last state forward, from scratch but for the scene's own nodes, as
# a replay seeking to it would, and checks that it is saved back the same. Not
# the PropertyManager's reset: the values from before its records, which
# rollbacks to before this tick still need, are not in the state.
func _debug_check_load_state_forward() -> void:
	var frame: StateBufferFrame = state_buffer[-1]
	var events := {}
	for path in _event_history:
		events[path] = _event_history[path].duplicate()
	for event_frame in event_buffer:
		_accumulate_events(events, event_frame)
	var scripts := _get_event_history_scripts()
	var prepared_events := get_events_up_to_tick(frame.tick, frame.data, events, scripts)
	# The reuse pool set aside, as the match's: reset() would free it, and the
	# load would take from it.
	var pool: Dictionary = _spawn_manager.retired_nodes
	_spawn_manager.retired_nodes = {}
	_spawn_manager.reset()
	_call_load_state_forward(frame.data, prepared_events, frame.tick)
	_spawn_manager.retired_nodes = pool
	var loaded := _call_save_state()
	if sync_booster.hash_special_dict(loaded) != sync_booster.hash_special_dict(frame.data):
		var comparer = DebugStateComparer.new()
		comparer.find_mismatches(frame.data, loaded)
		push_error("[%s] State loaded forward is not consistent with saved state:\n %s" % [
			frame.tick, comparer.print_mismatches()])

func _accumulate_events(accumulating: Dictionary, event_frame: EventBufferFrame) -> void:
	for path in event_frame.data:
		# The scripts, which the logger adds: the history has them apart
		# (_get_event_history_scripts()).
		if path == "":
			continue
		var by_tick: Dictionary = accumulating.get(path, {})
		# Added to what a replay's log had for the tick it started from.
		by_tick[event_frame.tick] = by_tick.get(event_frame.tick, []) + event_frame.data[path]
		accumulating[path] = by_tick


# The scripts of the nodes in the event history, by node path: Scripts, or their
# paths.
func _get_event_history_scripts() -> Dictionary:
	var scripts := _event_history_scripts.duplicate()
	scripts.merge(_event_scripts)
	scripts.merge(_event_scripts_in_buffer)
	return scripts

# What a load can't need anymore goes, from the state of a tick retired for
# good (state_frame): every load is from a later tick. A script compacts its
# node's events with an optional
#   static func _compact_events(events: Dictionary, tick: int, state[, states: Dictionary]) -> Dictionary
# which returns, in the same {tick: events} form, ticks in order, events that
# _prepare_events_up_to_tick() turns into the same thing, for any tick from
# this one on, with any events after. state is the node's at that tick (null if
# it wasn't saved), states every node's, by path, for a script that also needs
# another's (PropertyManager, SpawnManager's).
# The nodes gone for good go first, whatever their scripts.
func _compact_event_history(state_frame: StateBufferFrame) -> void:
	if state_frame.skipped or state_frame.tick - _event_history_compacted_tick < EVENT_HISTORY_COMPACTION_TICKS:
		return
	_event_history_compacted_tick = state_frame.tick
	var paths := _event_history.keys()
	paths.erase("")
	for path in _nodes_gone(paths, state_frame.data):
		_event_history.erase(path)
		_event_history_scripts.erase(path)
		_event_scripts.erase(path)
		_event_scripts_in_buffer.erase(path)
	var scripts := _get_event_history_scripts()
	for path in _event_history:
		# Where the logger puts the scripts themselves.
		if path == "" or not scripts.has(path):
			continue
		var script = scripts[path]
		if script is String:
			script = load(script)
		if not _compact_events_methods.has(script):
			var arg_count := -1
			for method in script.get_script_method_list():
				if method.name == "_compact_events":
					arg_count = method.args.size()
					break
			_compact_events_methods[script] = arg_count
		var arg_count: int = _compact_events_methods[script]
		if arg_count >= 4:
			_event_history[path] = script._compact_events(_event_history[path], state_frame.tick, state_frame.data.get(path), state_frame.data)
		elif arg_count >= 0:
			_event_history[path] = script._compact_events(_event_history[path], state_frame.tick, state_frame.data.get(path))

# The nodes (node_paths) gone for good at a tick: not in the tree now, nor
# alive at the tick, spawned or under a spawned node, in SpawnManager's state
# then (states, the tick's, by path). Not the tree at the tick: a node
# despawned since, or about to be in a prediction, a load can still need.
# Spawned nodes' names are never taken again. Without SpawnManager's state,
# none. A synced node out of the tree otherwise counts as gone.
func _nodes_gone(node_paths: Array, states: Dictionary) -> Dictionary:
	var gone := {}
	var spawn_state = states.get(str(_spawn_manager.get_path()))
	if spawn_state == null:
		return gone
	var alive := {}
	for record in spawn_state.records.values():
		# Not despawned (-1).
		if record[1] == -1:
			alive["%s/%s" % [record[2], record[3]]] = true
	for entry in spawn_state.settled.values():
		alive["%s/%s" % [entry[0], entry[1]]] = true
	for node_path in node_paths:
		if gone.has(node_path) or not node_path.is_absolute_path() \
				or get_node_or_null(node_path) != null:
			continue
		var path: String = node_path
		while path != "/" and not alive.has(path):
			path = path.get_base_dir()
		if path == "/":
			gone[node_path] = true
	return gone

func get_events_up_to_tick(tick_number: int, state_data: Dictionary, events: Dictionary, event_scripts: Dictionary) -> Dictionary:
	var res := {}
	for path in events.keys():
		if path == "":
			for tick_events in events[path].values():
				for event in tick_events:
					assert(event.type == "script")
					event_scripts[event.node_path] = load(event.script_path)
		elif event_scripts.has(path):
			var local_state_data = state_data.get(path, {})
			var script = event_scripts[path]
			if script is String:
				script = load(script)
			res[path] = script._prepare_events_up_to_tick(self, tick_number, events[path], local_state_data)
		else:
			push_error("Script of the event sending Node can't be found: %s" % path)
	return res


func _on_received_sync_message(peer_id: int, msg: Dictionary) -> void:
	match msg.get("type"):
		"peer_left":
			_on_peer_left(peer_id, msg.peer)
		"peer_dropped":
			if started and peers.has(msg.peer):
				remove_peer(msg.peer)
		"join_request":
			_on_received_join_request(peer_id, msg.get("as_player", false), msg.get("id", 0))
		"join_pin":
			# Not for a join its joiner gave up, the pin late.
			if not _abandoned_join_ids.has(msg.get("id", 0)) or msg.tick == -1:
				_on_received_join_pin(peer_id, msg.joiner, msg.tick, msg.get("id", 0))
		"join_pinned":
			_on_received_join_pinned(peer_id, msg.joiner, msg.tick, msg.ok)
		"join_snapshot":
			_on_received_join_snapshot(msg)
		"join_failed":
			# The match stopped, or we were dropped, once it was sent: we
			# stop.
			if msg.get("id", 0) == 0 or msg.id != _late_join_id:
				pass
			elif started:
				_stop(msg.reason)
			elif _late_join_requested:
				_late_join_requested = false
				emit_signal("late_join_failed", msg.reason)
		"join_synced":
			if started and peers.has(peer_id) and peers[peer_id].spectator:
				peers[peer_id].joining = false
				emit_signal("late_join_synced", peer_id)
				# The host says in its next input when it plays.
				if _joiners_to_promote.erase(peer_id):
					_joiners_to_announce.append(peer_id)
		"join_peers":
			_on_received_join_peers(msg.peers, msg.tick)
		"join_abandoned":
			if msg.get("id", 0) != 0:
				_abandoned_join_ids[msg.id] = true
			if started and peers.has(peer_id) and peers[peer_id].spectator:
				_remove_peer_internal(peer_id)

#
# Late join: a peer joins a match in progress as a spectator. The host picks a
# tick to come (P), every player keeps its input from there for the joiner
# (pins it), and when the state of the tick before (T) is final, the host
# sends the joiner that state with the events up to it. The joiner loads it
# forward, as a replay seeking into a log does, and catches up with the input
# from P on.
#

## Joins the match in progress as a spectator, which the peers' Allow Late Join
## setting must allow, and with as_player, as a player once in sync. Call it
## once connected to the players, added with add_peer(), before the match
## starts here: sync_started is emitted once the match is loaded,
## late_join_failed if it can't be, player_joined when it plays.
func request_join(as_player := false) -> void:
	if started or _late_join_requested:
		return
	spectating = true
	_late_join_requested = true
	_late_join_snapshot_parts.clear()
	_peers_removed.clear()
	_late_join_progress_msecs = Time.get_ticks_msec()
	_late_join_id = randi_range(1, 0x7fffffff)
	for peer_id in peers:
		network_adaptor.send_sync_message(peer_id, {type = "join_request", as_player = as_player, id = _late_join_id})
	_watch_late_join_request(_late_join_id)

# Nothing runs before the match loads (_physics_process()): a timer checks that
# the join gets on, this request's (id).
func _watch_late_join_request(id: int) -> void:
	while _late_join_requested and _late_join_id == id:
		await get_tree().create_timer(1.0).timeout
		if _late_join_requested and _late_join_id == id \
				and Time.get_ticks_msec() - _late_join_progress_msecs > LATE_JOIN_TIMEOUT_MSECS:
			_give_up_late_join("the players sent no match to load")

# On a joiner: the join won't get anywhere. We stop, which tells the players to
# let us go.
func _give_up_late_join(reason: String) -> void:
	push_warning("Late join failed: " + reason)
	_stop(reason)

# The host handles it, the other players ignore it.
func _on_received_join_request(joiner: int, as_player: bool, id: int) -> void:
	if not network_adaptor.is_network_host() or _late_joins.has(joiner):
		return
	var reason := ""
	if not started:
		reason = "the match hasn't started"
	elif spectating:
		reason = "the host is a spectator"
	elif not allow_late_join:
		reason = "the host doesn't allow late joins (Allow Late Join)"
	elif not _has_event_history:
		reason = "the host doesn't have the events since the match started"
	elif _player_peers.has(joiner):
		reason = "a player can't join as a spectator"
	if reason != "":
		network_adaptor.send_sync_message(joiner, {type = "join_failed", reason = reason, id = id})
		return
	_late_joins[joiner] = {attempts = 0, id = id}
	if as_player:
		_joiners_to_promote[joiner] = true
	_start_late_join_attempt(joiner)

func _start_late_join_attempt(joiner: int) -> void:
	var join: Dictionary = _late_joins[joiner]
	join.attempts += 1
	if join.attempts > LATE_JOIN_MAX_ATTEMPTS:
		_fail_late_join(joiner, "the players couldn't keep their input for it")
		return
	# Far enough ahead for the pins to reach the players before they send it.
	var max_rtt := 0
	for peer in _player_peers.values():
		max_rtt = maxi(max_rtt, peer.rtt)
	# Never the failed attempt's tick: its answers would count.
	join.tick = maxi(input_tick + 10 + ceili(max_rtt / 1000.0 / tick_time) * join.attempts, join.get("tick", 0) + 1)
	join.pinned = {}
	join.snapshot = null
	if not _pin_late_joiner(joiner, join.tick):
		_fail_late_join(joiner, "the host no longer has its input")
		return
	peers[joiner].join_id = join.id
	join.pinned[network_adaptor.get_network_unique_id()] = true
	for peer_id in _player_peers:
		network_adaptor.send_sync_message(peer_id, {type = "join_pin", joiner = joiner, tick = join.tick, id = join.id})

func _fail_late_join(joiner: int, reason: String) -> void:
	var id: int = _late_joins[joiner].id
	_late_joins.erase(joiner)
	_joiners_to_promote.erase(joiner)
	network_adaptor.send_sync_message(joiner, {type = "join_failed", reason = reason, id = id})
	for peer_id in _player_peers:
		network_adaptor.send_sync_message(peer_id, {type = "join_pin", joiner = joiner, tick = -1})
	if peers.has(joiner) and peers[joiner].spectator:
		_remove_peer_internal(joiner)

# Keeps our input from tick for the joiner, a spectator from now on, unless it
# is already gone: whether it is.
func _pin_late_joiner(joiner: int, tick: int) -> bool:
	# A joiner not playing yet has no input to keep: it sends it from its first
	# tick (see _become_player()).
	if tick < _input_send_queue_start_tick and not spectating:
		return false
	var peer: Peer = peers.get(joiner)
	if peer == null:
		peer = Peer.new(joiner, true)
		peers[joiner] = peer
		_peers_removed.erase(joiner)
		emit_signal("peer_added", joiner)
	elif not peer.spectator:
		return false
	peer.next_local_input_tick_requested = tick
	peer.next_local_hash_tick_requested = tick
	peer.joining = true
	peer.join_heard = false
	peer.join_tick = tick
	peer.join_least_behind = 1 << 62
	peer.join_progress_msecs = Time.get_ticks_msec()
	return true

# From the host. A tick of -1 cancels the join.
func _on_received_join_pin(host: int, joiner: int, tick: int, id: int) -> void:
	if not started:
		return
	if tick == -1:
		if peers.has(joiner) and peers[joiner].joining:
			_remove_peer_internal(joiner)
		return
	var ok := _pin_late_joiner(joiner, tick)
	if ok:
		# For a drop of ours to reach it (_send_stop()).
		peers[joiner].join_id = id
	network_adaptor.send_sync_message(host, {type = "join_pinned", joiner = joiner, tick = tick, ok = ok})

func _on_received_join_pinned(player: int, joiner: int, tick: int, ok: bool) -> void:
	var join: Dictionary = _late_joins.get(joiner, {})
	if join.get("tick") != tick:
		return
	if not ok:
		_start_late_join_attempt(joiner)
		return
	join.pinned[player] = true
	_send_late_join_snapshot_if_ready(joiner)

# When the state before the joiner's first tick retires (_cleanup_buffers()),
# final, with the event history up to it.
func _take_late_join_snapshots(state_frame: StateBufferFrame) -> void:
	for joiner in _late_joins:
		var join: Dictionary = _late_joins[joiner]
		if join.get("tick") != state_frame.tick + 1:
			continue
		var scripts := {}
		var history_scripts := _get_event_history_scripts()
		for path in history_scripts:
			var script = history_scripts[path]
			scripts[path] = script if script is String else script.resource_path
		# Each with the first tick it plays: a joiner whose join is announced
		# but to come too.
		var players := {network_adaptor.get_network_unique_id(): 0}
		for peer in _player_peers.values():
			players[peer.peer_id] = peer.player_from_tick
		# Taken now: the history goes on changing.
		var bytes := var_to_bytes({
			tick = state_frame.tick,
			state = state_frame.data,
			events = _event_history,
			scripts = scripts,
			input_delay = input_delay,
			players = players,
		})
		join.snapshot = {
			size = bytes.size(),
			data = bytes.compress(FileAccess.COMPRESSION_ZSTD),
		}
	for joiner in _late_joins.keys():
		_send_late_join_snapshot_if_ready(joiner)

func _send_late_join_snapshot_if_ready(joiner: int) -> void:
	var join: Dictionary = _late_joins[joiner]
	if join.get("snapshot") == null:
		return
	for peer_id in _player_peers:
		if not join.pinned.has(peer_id):
			return
	var data: PackedByteArray = join.snapshot.data
	var parts := ceili(data.size() / float(LATE_JOIN_SNAPSHOT_PART_BYTES))
	for i in parts:
		network_adaptor.send_sync_message(joiner, {
			type = "join_snapshot",
			id = join.id,
			part = i,
			parts = parts,
			size = join.snapshot.size,
			data = data.slice(i * LATE_JOIN_SNAPSHOT_PART_BYTES, (i + 1) * LATE_JOIN_SNAPSHOT_PART_BYTES),
		})
	_late_joins.erase(joiner)

func _on_received_join_snapshot(msg: Dictionary) -> void:
	if started or not _late_join_requested or msg.get("id", 0) != _late_join_id \
			or msg.part != _late_join_snapshot_parts.size():
		return
	_late_join_snapshot_parts.append(msg.data)
	_late_join_progress_msecs = Time.get_ticks_msec()
	if _late_join_snapshot_parts.size() < msg.parts:
		return
	var data := PackedByteArray()
	for part in _late_join_snapshot_parts:
		data.append_array(part)
	var snapshot = bytes_to_var(data.decompress(msg.size, FileAccess.COMPRESSION_ZSTD)) \
			if data.size() > 0 else null
	if not snapshot is Dictionary or not snapshot.has_all(["tick", "state", "events", "scripts", "input_delay", "players"]):
		_give_up_late_join("the snapshot couldn't be read")
		return
	_late_join_requested = false
	if _input_delay_before_join < 0:
		_input_delay_before_join = input_delay
	input_delay = snapshot.input_delay
	# What the players said while it came: the load's reset clears it.
	var removed := _peers_removed.duplicate()
	var left_votes := _peer_left_for_peer.duplicate(true)
	for peer_id in snapshot.players:
		if not peers.has(peer_id) and not removed.has(peer_id):
			add_peer(peer_id)
	# The snapshot says who plays: a peer that registered as a spectator, a
	# joiner that has played since, does; any other watches, or joins too
	# (said in the host's input).
	for peer in peers.values():
		var plays: bool = snapshot.players.has(peer.peer_id)
		if plays == peer.spectator:
			peer.spectator = not plays
			if plays:
				_player_peers[peer.peer_id] = peer
			else:
				_player_peers.erase(peer.peer_id)
	_on_received_remote_start(false)
	var tick: int = snapshot.tick
	var state: Dictionary = snapshot.state
	var events := get_events_up_to_tick(tick, state.duplicate(), snapshot.events, snapshot.scripts.duplicate())
	_start_from_state(state, events, tick, snapshot.events, snapshot.scripts)
	_peers_removed = removed
	# Loaded: what a handler spawns stays.
	emit_signal("sync_started")
	if _logger:
		_log_event_history(snapshot.scripts)
	for peer in _player_peers.values():
		peer.last_remote_input_tick_received = tick
		peer.last_remote_hash_tick_received = tick
	for peer_id in snapshot.players:
		var first_tick: int = snapshot.players[peer_id]
		if first_tick > tick:
			_schedule_player_joins({peer_id: first_tick})
		elif peers.has(peer_id):
			peers[peer_id].player_from_tick = first_tick
	_late_join_waiting = true
	_late_join_syncing = true
	_late_join_matched_hashes = 0
	_late_join_mismatch = false
	_late_join_progress_tick = tick
	_late_join_progress_msecs = Time.get_ticks_msec()
	# Last, the join under way: one stopping the match fails it.
	for left_peer in left_votes:
		for voter in left_votes[left_peer]:
			if started:
				_on_peer_left(voter, left_peer)

# The events before the tick loaded, into the log started with the match
# (sync_started): what a replay seeking into it needs to load forward, as we
# did (the nodes spawned, the values set, the nodes switched off...).
func _log_event_history(scripts: Dictionary) -> void:
	var by_tick := {}
	for path in _event_history:
		for tick in _event_history[path]:
			if not by_tick.has(tick):
				by_tick[tick] = {}
			by_tick[tick][path] = _event_history[path][tick]
	var ticks := by_tick.keys()
	ticks.sort()
	for i in ticks.size():
		var frame := EventBufferFrame.new(ticks[i], by_tick[ticks[i]])
		if i == 0:
			for path in scripts:
				frame._add_script_event(path, scripts[path])
				_event_scripts[path] = scripts[path]
		_logger.write_event(ticks[i], sync_booster.serialize(frame.data))

# A tick's hash from a player, on a joiner: once every player's is there, and
# ours, the tick counts towards being in sync, unless one differs.
func _count_late_join_hash(state_hash_frame: StateHashFrame) -> void:
	if state_hash_frame.mismatch:
		# Given up on in _check_late_join_synced(): not while handling a message.
		_late_join_mismatch = true
		return
	if not state_hash_frame.is_complete(_players_at(state_hash_frame.tick)):
		return
	if state_hash_frame.state_hash == SKIPPED_STATE_HASH:
		return
	for peer_hash in state_hash_frame.peer_hashes.values():
		if peer_hash == SKIPPED_STATE_HASH:
			return
	_late_join_matched_hashes += 1

# In sync once caught up (no more ticks to run than a spectator has behind), with
# enough ticks hashed as the players did: we tell them. With a tick hashed
# otherwise, or no input coming, we give up.
func _check_late_join_synced() -> void:
	if _late_join_mismatch:
		push_error("Late join failed: a tick's state differs from the players'")
		_give_up_late_join("the state loaded differs from the players'")
		return
	if _input_complete_tick > _late_join_progress_tick:
		_late_join_progress_tick = _input_complete_tick
		_late_join_progress_msecs = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _late_join_progress_msecs > LATE_JOIN_TIMEOUT_MSECS:
		_give_up_late_join("no input from the players")
		return
	if _late_join_matched_hashes < LATE_JOIN_SYNCED_HASHES \
			or _input_complete_tick - current_tick > input_delay + 2:
		return
	_late_join_syncing = false
	for peer_id in _player_peers:
		network_adaptor.send_sync_message(peer_id, {type = "join_synced", tick = current_tick})
	emit_signal("late_join_synced", network_adaptor.get_network_unique_id())


#
# A joiner becoming a player (request_join(true)): once it is in sync, the host
# puts the first tick it plays (J) in its input, at a tick (A) far enough ahead
# for every peer to hear of it before it gets there. Every peer, the joiner
# included, gets the host's input for A before the input of J is complete:
# from J on, it takes the joiner's.
#

# On the host: the joiners to play, in this input of ours.
func _announce_player_joins(local_input: Dictionary) -> void:
	var max_rtt := 0
	for peer in peers.values():
		max_rtt = maxi(max_rtt, peer.rtt)
	var first_tick := input_tick + 10 + 2 * ceili(max_rtt / 1000.0 / tick_time)
	var joins := {}
	for joiner in _joiners_to_announce:
		if peers.has(joiner):
			joins[joiner] = first_tick
	_joiners_to_announce.clear()
	if joins.is_empty():
		return
	local_input[JOIN_INPUT_KEY] = joins
	_schedule_player_joins(joins)
	# Players now, which the joins under way wait for too: they keep their
	# input for those joiners, from their first tick, and don't drop them
	# while they load.
	for joiner in _late_joins:
		var join: Dictionary = _late_joins[joiner]
		if join.get("tick") == null:
			continue
		for player in joins:
			if player != joiner:
				network_adaptor.send_sync_message(player, {type = "join_pin", joiner = joiner, tick = join.tick, id = join.id})
	# Its input goes to every peer: those it joined as a spectator doesn't
	# know of, the spectators and joiners who came after it.
	for joiner in joins:
		var others := []
		for peer_id in peers:
			if peer_id != joiner:
				others.append(peer_id)
		network_adaptor.send_sync_message(joiner, {type = "join_peers", peers = others, tick = first_tick})

# From the host's input ({joiner peer id: first tick it plays}), received again
# and again: once is enough. In a replay, only for player_joined: the input is
# all there.
func _schedule_player_joins(joins: Dictionary) -> void:
	var my_id := network_adaptor.get_network_unique_id()
	for joiner in joins:
		var first_tick: int = joins[joiner]
		var joiners: Array = _player_joins.get(first_tick, [])
		if joiner in joiners:
			continue
		joiners.append(joiner)
		_player_joins[first_tick] = joiners
		if mechanized or mechanized_replay:
			continue
		if joiner == my_id:
			_local_player_from_tick = first_tick
			continue
		# Not a peer of ours (a spectator that came before it): one now, the
		# joiner sending us its input (see _on_received_join_peers()).
		var peer: Peer = peers.get(joiner)
		if peer == null:
			if _peers_removed.has(joiner):
				continue
			peer = Peer.new(joiner, false)
			# Sent from its first tick.
			peer.next_local_input_tick_requested = first_tick
			peer.next_local_hash_tick_requested = first_tick
			peers[joiner] = peer
			emit_signal("peer_added", joiner)
		_make_player(peer, first_tick)

# A peer that joined the match plays from first_tick on.
func _make_player(peer: Peer, first_tick: int) -> void:
	peer.spectator = false
	peer.joining = false
	peer.player_from_tick = first_tick
	# Nothing to get from it before.
	peer.last_remote_input_tick_received = maxi(peer.last_remote_input_tick_received, first_tick - 1)
	peer.last_remote_hash_tick_received = maxi(peer.last_remote_hash_tick_received, first_tick - 1)
	peer.clear_advantage()
	_player_peers[peer.peer_id] = peer
	_last_player_from_tick = maxi(_last_player_from_tick, first_tick)

# On a joiner about to play from first_tick: the match's peers, from the host.
# Those we don't have watch, from our first tick on, or play too: a join for
# them in the host's input, maybe read already (and the peer added then).
func _on_received_join_peers(peer_ids: Array, first_tick: int) -> void:
	if not started:
		return
	for peer_id in peer_ids:
		if peers.has(peer_id) or _peers_removed.has(peer_id) or peer_id == network_adaptor.get_network_unique_id():
			continue
		var peer := Peer.new(peer_id, true)
		# Sent from our first tick, unless gone already: the host sends this
		# when it says when we play, a few round trips before.
		peer.next_local_input_tick_requested = maxi(first_tick, _input_send_queue_start_tick)
		peer.next_local_hash_tick_requested = first_tick
		peers[peer_id] = peer
		emit_signal("peer_added", peer_id)
		for tick in _player_joins:
			if peer_id in _player_joins[tick]:
				_make_player(peer, tick)

# The players at a tick: those playing from it or before.
func _players_at(tick: int) -> Dictionary:
	if tick >= _last_player_from_tick:
		return _player_peers
	var players := {}
	for peer_id in _player_peers:
		if _player_peers[peer_id].player_from_tick <= tick:
			players[peer_id] = _player_peers[peer_id]
	return players

# On a joiner, from its first tick: a player, sending its input from there on
# (empty for the ticks it heard of it too late for), and wanting the players'
# hashes from there on.
func _become_player() -> void:
	_becoming_player = true
	spectating = false
	_becoming_player = false
	var first_tick := _local_player_from_tick
	var my_id := network_adaptor.get_network_unique_id()
	_input_send_queue.clear()
	_input_send_queue_start_tick = first_tick
	for tick in range(first_tick, input_tick):
		var input_frame := _get_or_create_input_frame(tick)
		if input_frame == null:
			return
		var empty := {}
		_calculate_data_hash(empty)
		input_frame.add_input_for_player(my_id, empty, false)
		_input_send_queue.append(message_serializer.serialize_input(empty))
	for peer in peers.values():
		peer.next_local_input_tick_requested = maxi(peer.next_local_input_tick_requested, first_tick)
		peer.next_local_hash_tick_requested = maxi(peer.next_local_hash_tick_requested, first_tick)
	for peer in _player_peers.values():
		peer.last_remote_hash_tick_received = maxi(peer.last_remote_hash_tick_received, first_tick - 1)
		peer.clear_advantage()

# caller_id says p_peer_id left, for it: once every player has, it is removed.
func _on_peer_left(caller_id: int, p_peer_id: int) -> void:
	if not (p_peer_id in peers):
		return
	var d: Array = _peer_left_for_peer.get(p_peer_id, [])
	d.append(caller_id)
	_peer_left_for_peer[p_peer_id] = d
	# do it multiple times if several peers are removed at once
	var redo: = true
	while redo:
		redo = false
		var peers_left: Array = _peer_left_for_peer.keys()
		var to_remove: = []
		for peer_left in peers_left:
			var validated_peers: Array = _peer_left_for_peer[peer_left]
			var all_validated: = true
			# The players only: a spectator's say isn't needed, its input
			# never counted.
			var all_peers: = _player_peers.keys().duplicate()
			if not spectating:
				all_peers.append(network_adaptor.get_network_unique_id())
			for peer in all_peers:
				if not (peer in validated_peers or peer == peer_left):
					all_validated = false
					break
			if all_validated:
				redo = true
				to_remove.append(peer_left)
		for peer_left in to_remove:
			_remove_peer_internal(peer_left)
			_peer_left_for_peer.erase(peer_left)


## Switches a node on or off: switched off, it is not saved, loaded, hashed or
## processed (no _network_process(), _interpolate_state()...), which costs
## nothing for a node whose state does not change, and its state is restored by
## rollbacks to before the switch. See set_process_when_inactive() for a node
## that wakes itself up from its _network_process().
func activate_sync(node: Node, enable: bool) -> void:
	if not node.is_inside_tree() or not started:
		# Outside a match there is nothing to roll back, so just set the bit.
		sync_booster.set_sync_active_or_register(node, enable)
		return
	
	if _in_load_state:
		return
	
	# Spawned this tick and waiting to be registered (spawn() does it once the
	# scene is in the tree): registered now, switched on as it would be. Else
	# a node switching itself on from its _ready() would record that it was
	# off before, which a reused node, registered already, doesn't.
	if node.is_in_group("network_sync"):
		register_node(node)
	
	# Already so: PropertyManager would record nothing.
	if sync_booster.is_sync_active(node) == enable:
		return
	
	_property_manager.activate_sync(current_tick, node, enable)


## Whether a node switched off by activate_sync() still gets its process
## callbacks (_network_process(), _network_preprocess(),
## _network_postprocess(), _interpolate_state()). False by default: switched
## off, a node costs nothing at all. True for a node that wakes itself up from
## its own _network_process(), as the demo's Player does when input comes.
func set_process_when_inactive(node: Node, process: bool) -> void:
	sync_booster.set_process_when_inactive(node, process)


func _restore_sync_groups() -> void:
	for node in get_tree().get_nodes_in_group("network_sync_managed"):
		node.add_to_group("network_sync")


# Performance summary (debug_perf_summary).

func _perf_begin(timer: String) -> void:
	if debug_perf_summary:
		_perf_starts[timer] = Time.get_ticks_usec()

func _perf_end(timer: String) -> void:
	if debug_perf_summary and _perf_starts.has(timer):
		_perf_add(timer, Time.get_ticks_usec() - _perf_starts[timer])
		_perf_starts.erase(timer)

func _perf_add(timer: String, usecs: int) -> void:
	var entry = _perf.get(timer)
	if entry == null:
		_perf[timer] = [usecs, 1, usecs, current_tick]
		return
	entry[0] += usecs
	entry[1] += 1
	if usecs > entry[2]:
		entry[2] = usecs
		entry[3] = current_tick

func _perf_reset() -> void:
	_perf.clear()
	_perf_starts.clear()
	_perf_ticks = 0
	_perf_rollbacks = 0
	_perf_rollback_ticks = 0
	_perf_rollback_max = 0
	_perf_ticks_this_frame = 0
	_perf_frame_intervals = PackedInt64Array()
	_perf_frame_work = PackedInt64Array()
	_perf_frame_has_tick = PackedByteArray()
	_effect_manager.reset_stats()
	sync_booster.set_callback_timing(debug_perf_summary)
	sync_booster.reset_callback_times()

static func _perf_percentile(values: Array, fraction: float) -> int:
	if values.is_empty():
		return 0
	return values[mini(int(fraction * values.size()), values.size() - 1)]

func _perf_print_summary() -> void:
	var ticks: float = maxf(_perf_ticks, 1)
	var lines := PackedStringArray()
	lines.append("SyncManager perf summary: %d ticks, %d rollbacks, %d ticks re-simulated (%.2f per rollback, max %d)" % [
		_perf_ticks, _perf_rollbacks, _perf_rollback_ticks, float(_perf_rollback_ticks) / maxf(_perf_rollbacks, 1), _perf_rollback_max])
	lines.append("  state saves skipped: %d; ticks deferred: %d (deferral up to %d ticks, budget %.1f ms%s); interpolation paused for %d ticks" % [
		state_saves_skipped, rollbacks_deferred, max_rollback_deferral_ticks, _rollback_deferral_budget() / 1000.0,
		"" if rollback_deferral_budget_usecs > 0 else " adapted", interpolation_paused_ticks])
	var effects: Dictionary = _effect_manager.stats
	lines.append("  effects: %d shown (%d reused), %d ended by rollbacks, %d ends asked (%d undone); %d sounds" % [
		effects.shown, effects.reused, effects.ended_by_rollback, effects.ends_asked, effects.ends_undone, effects.sounds])
	lines.append("  %-30s %10s %8s %10s %10s %8s  %s" % ["timer", "total ms", "calls", "us/call", "us/tick", "max us", "max at"])
	var names := _perf.keys()
	names.sort()
	for timer in names:
		var entry: Array = _perf[timer]
		lines.append("  %-30s %10.2f %8d %10.1f %10.1f %8d  tick %d" % [timer, entry[0] / 1000.0, entry[1],
			float(entry[0]) / entry[1], entry[0] / ticks, entry[2], entry[3]])
	# Inside the game's callbacks, measured natively.
	lines.append("  game callbacks:")
	var callback_times: Dictionary = sync_booster.get_callback_times()
	for callback in callback_times:
		var entry: Array = callback_times[callback]
		if entry[1] > 0:
			lines.append("    %-28s %10.2f ms %8d calls %8.1f us/call %8.1f us/tick" % [callback, entry[0] / 1000.0, entry[1],
				entry[0] / entry[1], entry[0] / ticks])
	lines.append("  by script, us/tick (calls/tick) per callback:")
	var by_script: Dictionary = sync_booster.get_callback_times_by_script()
	var totals := []
	for script_path in by_script:
		var total := 0.0
		for callback in by_script[script_path]:
			total += by_script[script_path][callback][0]
		totals.append([script_path, total])
	totals.sort_custom(func (a, b): return a[1] > b[1])
	for i in mini(15, totals.size()):
		var script_path: String = totals[i][0]
		var parts := PackedStringArray()
		for callback in by_script[script_path]:
			var entry: Array = by_script[script_path][callback]
			parts.append("%s %.1f (%.1f)" % [callback, entry[0] / ticks, entry[1] / ticks])
		lines.append("    %-40s %8.1f  %s" % [script_path.get_file(), totals[i][1] / ticks, ", ".join(parts)])
	# Frames, timed from their start: late when over a vblank and a half.
	if not _perf_frame_intervals.is_empty():
		var vblank := _get_vblank_usecs()
		var late := 0
		var late_with_tick := 0
		var tick_work := []
		for i in _perf_frame_intervals.size():
			if _perf_frame_intervals[i] > vblank * 1.5:
				late += 1
				if _perf_frame_has_tick[i]:
					late_with_tick += 1
			if _perf_frame_has_tick[i]:
				tick_work.append(_perf_frame_work[i])
		tick_work.sort()
		lines.append("  frames: %d, %d late (%d with ticks); SyncManager's work in frames with ticks: %.2f ms median, %.2f ms p95, %.2f ms max" % [
			_perf_frame_intervals.size(), late, late_with_tick, _perf_percentile(tick_work, 0.5) / 1000.0,
			_perf_percentile(tick_work, 0.95) / 1000.0, (tick_work[-1] if not tick_work.is_empty() else 0) / 1000.0])
	print("\n".join(lines))
