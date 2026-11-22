extends PropertyManager


func _ready() -> void:
	initialize(ProjectSettings.get_setting("network/rollback/max_buffer_size") + 2)


func _network_process(_data: Dictionary) -> void:
	if SyncManager._logger:
		SyncManager._logger.start_timing("property_manager_np")
	var events = network_process(SyncManager.current_tick)
	for e in events:
		SyncManager.register_event(self, e)
	if SyncManager._logger:
		SyncManager._logger.stop_timing("property_manager_np")


func _save_state() -> Array:
	return save_state()


func _load_state(state: Array) -> void:
	if SyncManager._logger:
		SyncManager._logger.start_timing("property_manager")
	load_state(state, SyncManager.load_type)
	if SyncManager._logger:
		SyncManager._logger.stop_timing("property_manager", true)


func _interpolate_state(state_before: Array, state_after: Array, weight: float) -> void:
	interpolate_state(state_before, state_after, weight)


func _load_state_forward(state: Array, events: Dictionary) -> void:
	load_state_forward(state, events)


# The last time each key was set: _prepare_events_up_to_tick() keeps that
# value, in the order they were last set, whatever comes after. Not for the
# nodes gone for good (SyncManager._nodes_gone()): every load is from a later
# tick.
static func _compact_events(events: Dictionary, _tick: int, _state, states := {}) -> Dictionary:
	var last := {}
	for t in events:
		var tick_events: Array = events[t]
		for i in tick_events.size():
			last[tick_events[i][0]] = [t, i]
	var node_paths := []
	for key in last:
		node_paths.append(key.get_slice(":", 0))
	var gone: Dictionary = SyncManager._nodes_gone(node_paths, states)
	var compacted := {}
	for t in events:
		var tick_events: Array = events[t]
		var kept := []
		for i in tick_events.size():
			var key: String = tick_events[i][0]
			if last[key] == [t, i] and not gone.has(key.get_slice(":", 0)):
				kept.append(tick_events[i])
		if not kept.is_empty():
			compacted[t] = kept
	return compacted


# The last value of each key, in the order they were last set, up to the tick.
# Also for nodes not in the tree yet, which the load spawns; those of keys with
# a record in the state are replaced by it (load_state_forward()).
static func _prepare_events_up_to_tick(_sync_manager: Node, tick_number: int, events: Dictionary, _state: Array) -> Dictionary:
	var prepared_events := {}
	for t in events.keys():
		if t > tick_number:
			break
		for e in events[t]:
			prepared_events.erase(e[0])
			prepared_events[e[0]] = e[1]
	return prepared_events
