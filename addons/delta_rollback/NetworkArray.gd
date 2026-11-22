extends Node
class_name NetworkArray
## An array whose appends and clears are events, for rollbacks.
##
## Not reset for reuse ("Reuse Despawned Nodes"): in a reused node, it keeps
## its contents. clear() it in the node's _network_spawn(), which records the
## clear as an event (out of the tree, in _network_prepare_for_reuse(), it
## would have no node to go to).

# Read only: get_contents(). Inside the class too, the getter: the slots are
# in _contents.
var contents: Array:
	set = _readonly,
	get = get_contents
var _contents := []
var _size := []
var _contents_ind := 0
var _buffer_size: int

func _ready() -> void:
	add_to_group("network_sync")
	_buffer_size = ProjectSettings.get_setting("network/rollback/max_buffer_size")
	for _i in _buffer_size:
		_contents.append([])
		_size.append(0)

func _readonly(_value):
	pass

func get_contents() -> Array:
	return _contents[_contents_ind].slice(0, _size[_contents_ind])

func append(value) -> void:
	var local_contents: Array = _contents[_contents_ind]
	var index: int = _size[_contents_ind]
	if local_contents.size() <= index:
		local_contents.append(value)
	else:
		local_contents[index] = value
	_size[_contents_ind] = index + 1
	SyncManager.register_event(self, {
		type = "append",
		value = value,
	})

func clear() -> void:
	_contents_ind = (_contents_ind + 1) % _buffer_size
	_contents[_contents_ind].clear()
	_size[_contents_ind] = 0
	SyncManager.register_event(self, {
		type = "clear",
	})

func _save_state() -> Dictionary:
	return {
		contents_ind = _contents_ind,
		size = _size.duplicate()
	}

func _load_state(state: Dictionary) -> void:
	_contents_ind = state.contents_ind
	_size = state.size.duplicate()

# The contents (events, from the last clear) go in the state's slot. The other
# slots stay: empty on a peer that loads the match, what rollbacks need on one
# that checks the load (debug_check_local_state_consistency_forward).
func _load_state_forward(state: Dictionary, events: Array) -> void:
	_load_state(state)
	_contents[_contents_ind] = events.duplicate()
	_size[_contents_ind] = events.size()

# From the last clear on: nothing before it is in the array anymore.
static func _compact_events(events: Dictionary, _tick: int, _state) -> Dictionary:
	var ticks := events.keys()
	for i in range(ticks.size() - 1, -1, -1):
		var tick_events: Array = events[ticks[i]]
		for j in range(tick_events.size() - 1, -1, -1):
			if tick_events[j].type == "clear":
				var compacted := {ticks[i]: tick_events.slice(j)}
				for t in ticks.slice(i + 1):
					compacted[t] = events[t]
				return compacted
	return events

static func _prepare_events_up_to_tick(_sync_manager: Node, tick_number: int, events: Dictionary, _state: Dictionary) -> Array:
	# only keep the last tick for each node
	var final_contents := []
	for t in events.keys():
		# Only load up to the asked tick
		if t > tick_number:
			break
		var new_event = events[t]
		for e in new_event:
			if e.type == "append":
				final_contents.append(e.value)
			elif e.type == "clear":
				final_contents.clear()
	return final_contents
