extends RefCounted

## Names the values of logged states that are saved as Arrays, for people to
## read: PropertyManager's ring of records, SpawnManager's records and settled
## nodes, and NetworkTrajectory's tracks are positional to keep saving cheap,
## which leaves a log showing "0", "1", "2"... where it used to show names.
##
## Everything returned is a copy: the logged states themselves are what a
## replay loads, and must stay in the format the nodes save.

const SPAWN_RECORD_FIELDS := ["spawn_tick", "despawn_tick", "parent", "name", "scene"]
const SPAWN_SETTLED_FIELDS := ["parent", "name", "scene"]
const TRACK_FIELDS := ["target", "property", "callback", "from", "to", "start_tick", "delay", "duration", "trans", "ease"]
# Tween.TransitionType and Tween.EaseType, by value.
const TRANSITION_NAMES := ["LINEAR", "SINE", "QUINT", "QUART", "QUAD", "EXPO", "ELASTIC", "CUBIC", "CIRC", "BOUNCE", "BACK", "SPRING"]
const EASE_NAMES := ["IN", "OUT", "IN_OUT", "OUT_IN"]

## A whole state, {node path: node state} (and the hash under '$').
static func annotate_state(state: Dictionary) -> Dictionary:
	var ret := {}
	for path in state:
		ret[path] = annotate_node_state(str(path), state[path])
	return ret

static func annotate_node_state(path: String, node_state):
	if node_state is Array and path.ends_with("/PropertyManager"):
		return _annotate_property_manager(node_state)
	if node_state is Dictionary:
		if node_state.has("records") and path.ends_with("/SpawnManager"):
			return _annotate_spawn_manager(node_state)
		if node_state.get("tracks") is Array:
			return _annotate_trajectory(node_state)
	return node_state

## A tick's events, {node path: [event...]}.
static func annotate_events(events: Dictionary) -> Dictionary:
	var ret := {}
	for path in events:
		var node_events = events[path]
		if node_events is Array and str(path).ends_with("/PropertyManager"):
			# [property path, value]: the value it keeps once its record expires.
			var named := []
			for e in node_events:
				if e is Array and e.size() > 1:
					var key := str(e[0])
					var event := {property = key}
					event.merge(_name_value(key, e[1]))
					named.append(event)
				else:
					named.append(e)
			node_events = named
		ret[path] = node_events
	return ret

# [ring], the ring being slots, each null or [expiry, {key: record}, has an
# interpolated record], and a record [expiry, value(, true if interpolated)].
# Older logs have the flat {key: record} instead of the ring. Shown as the
# flat records, sorted: which slot a record is in follows from its expiry.
static func _annotate_property_manager(state: Array) -> Dictionary:
	var flat := {}
	var saved = state[0] if state.size() > 0 else null
	if saved is Dictionary:
		flat = saved
	elif saved is Array:
		for slot in saved:
			if slot is Array and slot.size() > 1 and slot[1] is Dictionary:
				flat.merge(slot[1])
	var keys := flat.keys()
	keys.sort()
	var records := {}
	for key in keys:
		var record = flat[key]
		records[key] = _annotate_property_record(str(key), record) if record is Array else record
	return {records = records}

static func _annotate_property_record(key: String, record: Array) -> Dictionary:
	var ret := {
		expiry_tick = record[0] if record.size() > 0 else null,
	}
	ret.merge(_name_value(key, record[1] if record.size() > 1 else null))
	ret.interpolated = record.size() > 2 and bool(record[2])
	return ret

# A node's activation key ("path:$") holds false for its sync switched on, or
# the state it keeps while switched off.
static func _name_value(key: String, value) -> Dictionary:
	if not key.ends_with(":$"):
		return {value = value}
	if value is bool:
		return {sync_active = true}
	return {sync_active = false, state = annotate_node_state(key.trim_suffix(":$"), value)}

static func _annotate_spawn_manager(state: Dictionary) -> Dictionary:
	var ret := state.duplicate()
	ret.records = _name_fields_of_each(state.records, SPAWN_RECORD_FIELDS)
	if state.get("settled") is Dictionary:
		ret.settled = _name_fields_of_each(state.settled, SPAWN_SETTLED_FIELDS)
	return ret

static func _annotate_trajectory(state: Dictionary) -> Dictionary:
	var ret := state.duplicate()
	var tracks := []
	for track in state.tracks:
		if not track is Array:
			tracks.append(track)
			continue
		var named := _name_fields(track, TRACK_FIELDS)
		if named.has("trans"):
			named.trans = _enum_name(TRANSITION_NAMES, named.trans)
		if named.has("ease"):
			named.ease = _enum_name(EASE_NAMES, named.ease)
		tracks.append(named)
	ret.tracks = tracks
	return ret

static func _name_fields_of_each(entries, fields: Array):
	if not entries is Dictionary:
		return entries
	var ret := {}
	for key in entries:
		var entry = entries[key]
		ret[key] = _name_fields(entry, fields) if entry is Array else entry
	return ret

# Fields past the known ones keep their index, so nothing is hidden.
static func _name_fields(values: Array, fields: Array) -> Dictionary:
	var ret := {}
	for i in range(values.size()):
		ret[fields[i] if i < fields.size() else str(i)] = values[i]
	return ret

static func _enum_name(names: Array, value):
	if value is int and value >= 0 and value < names.size():
		return names[value]
	return value
