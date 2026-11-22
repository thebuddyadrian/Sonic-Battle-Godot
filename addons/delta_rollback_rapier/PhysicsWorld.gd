extends Node
## Puts a Rapier physics space under rollback: one network node for the whole
## space, whose state is Rapier's own snapshot of it. The same script serves
## the 2D demo and the 3D one (physics_3d).
##
## - Godot no longer steps the space: it is stepped here, once per tick, in
##   _network_postprocess(), after every _network_process() has applied its
##   forces.
## - _save_state() snapshots the space and _load_state() restores it. Rapier is
##   deterministic, so re-simulating from a restored snapshot gives the same
##   results bit for bit.
## - By default (cache_snapshots), each tick's snapshot stays in Rapier's
##   memory (StateManager cache_state()), 2 to 4 times cheaper than exporting
##   it as bytes, and the state only holds the tick it is cached under. While
##   SyncManager logs a match, snapshots are exported, as the log needs them.
## - Peers compare a hash of the bodies' transforms (the "bodies" key), the
##   same whether the snapshot is cached or exported: a desync shows there as
##   soon as a body is somewhere else, and a wrong velocity the tick after.
## - The body nodes are not network nodes: their state is in the snapshot, and
##   restoring it moves them. But they must be the same on every peer and in
##   every state: a snapshot restores bodies, it doesn't create or free them,
##   so don't spawn or despawn physics bodies with this setup.
##
## Requires Godot Rapier (physics/2d/physics_engine = "Rapier2D", or
## physics/3d/physics_engine = "Rapier3D").

## Which space: the viewport's 3D world, or its 2D one.
@export var physics_3d := false
## The node under which the physics bodies are, for the state manager to match
## its snapshot's bodies with them.
@export var root_node: Node
## Keeps each tick's snapshot in Rapier's memory instead of exporting it:
## saving costs 2 to 4 times less (2D and 3D demos). Off, every snapshot is
## exported in full into the state (a PackedByteArray), as for a log.
@export var cache_snapshots := true

var space: RID
# RapierPhysicsServer2D or 3D: the PhysicsServer2D / 3D singleton, once Rapier
# is the physics engine. Untyped, for the Rapier methods (space_step()...).
var _server: Object
var _state_manager: Node
# Every body under root_node, in tree order: the same on every peer. Typed, as
# space_get_bodies_transform() takes no other.
var _bodies: Array[RID] = []
# The state saved or loaded last, while the space hasn't changed since: saving
# again returns it (a save just after a load, as SyncManager's checks do, may
# not be for the current tick). Empty once the space steps.
var _unchanged_state := {}

func _ready() -> void:
	var state_manager_class := "StateManager3D" if physics_3d else "StateManager2D"
	if not ClassDB.class_exists(state_manager_class):
		push_error("PhysicsWorld needs Godot Rapier as the %s physics engine." % ("3D" if physics_3d else "2D"))
		# Out of the rollback: one error, not one per callback per tick.
		remove_from_group("network_sync")
		return
	_server = PhysicsServer3D if physics_3d else PhysicsServer2D
	space = get_viewport().world_3d.space if physics_3d else get_viewport().world_2d.space
	# Only ticks advance the simulation, not frames.
	_server.space_set_active(space, false)
	_state_manager = ClassDB.instantiate(state_manager_class)
	_state_manager.root_node = root_node if root_node else owner
	add_child(_state_manager)
	# One snapshot per tick, replaced when the tick is re-simulated: the
	# rollback buffer's ticks, and a few to spare. The oldest go first.
	_state_manager.max_cache_length = SyncManager.max_buffer_size + 4
	_state_manager.rolling_cache = true
	SyncManager.sync_started.connect(_clear_cache)
	SyncManager.sync_stopped.connect(_clear_cache)
	var body_class := "PhysicsBody3D" if physics_3d else "PhysicsBody2D"
	for body in _state_manager.root_node.find_children("*", body_class, true, false):
		_bodies.append(body.get_rid())

func _exit_tree() -> void:
	if space.is_valid():
		_server.space_set_active(space, true)

func _clear_cache() -> void:
	_state_manager.clear_cache()
	_unchanged_state = {}

func _network_postprocess(_input: Dictionary) -> void:
	_unchanged_state = {}
	# The tick's length, not the engine's: that changes while SyncManager
	# adjusts the tick rate, and while a replay plays faster or slower.
	_server.space_step(space, SyncManager.tick_time)
	# Moves the body nodes to where the step left them, and fires their
	# signals (body_entered...), which re-simulated ticks fire again.
	_server.space_flush_queries(space)

func _save_state() -> Dictionary:
	if not _unchanged_state.is_empty():
		return _unchanged_state
	var state := {
		# What peers compare. The snapshot itself is left out of the hash ("_"):
		# whether it is cached or exported must not make peers disagree.
		bodies = hash(_server.space_get_bodies_transform(space, _bodies)),
	}
	# A log needs the snapshot itself, to replay the match from.
	if not cache_snapshots or SyncManager._logger:
		state["_snapshot"] = _state_manager.export_state(space, "RustBincode")
	else:
		var tick: int = SyncManager.current_tick
		var index: int = _state_manager.ordered_cache_tags().find(tick)
		if index >= 0:
			_state_manager.remove_cached_by_index(index)
		_state_manager.cache_state(space, tick)
		state["_cached_tick"] = tick
	_unchanged_state = state
	return state

func _load_state(state: Dictionary) -> void:
	# Either moves the body nodes as well.
	if state.has("_snapshot"):
		_state_manager.import_state(space, state["_snapshot"])
	else:
		var index: int = _state_manager.ordered_cache_tags().find(state["_cached_tick"])
		if index < 0:
			push_error("PhysicsWorld: the snapshot of tick %d is no longer cached." % state["_cached_tick"])
			return
		_state_manager.load_cached_state(space, index)
	_unchanged_state = state
