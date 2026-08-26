@abstract class_name StateMachine extends Node


var state: int = -1
var substate: int = 0: set = change_substate
var prev_state: int = -1
var states: Dictionary[String, int] = {}
var all_substates: Dictionary[int, PackedStringArray] = {}
var substates: Dictionary[String, int] = {}
var state_data: Dictionary = {}

func _physics_process(delta: float) -> void:
	if state != -1:
		global_state_update(delta)
		state_update(delta)

func global_state_update(delta: float) -> void:
	pass

func state_update(delta: float) -> void:
	pass

func enter_state(new_state: int, old_state: int) -> void:
	pass

func exit_state(old_state: int, new_state: int) -> void:
	pass

func change_state(new_state: int, new_substate: String = get_substates(new_state).find_key(0), data: Dictionary = {}) -> void:
	substates = get_substates(new_state)
	state_data = data
	if substates.has(new_substate):
		substate = substates[new_substate]
	else:
		print("substate %s not found in state %s. Transitioning to default substate %s" % [new_substate, states.find_key(new_state), substates.find_key(0)])
		substate = 0
	
	if new_state != state:
		prev_state = state
		state = new_state
		
		if prev_state != -1:
			exit_state(prev_state, new_state)
		if new_state != -1:
			enter_state(new_state, prev_state)

func change_substate(new_state: int) -> void:
	substate = new_state

func get_substates(state_id: int = state) -> Dictionary[String, int]:
	var local_substates: Dictionary[String, int] = {}
	for substate_name in all_substates[state_id]:
		local_substates[substate_name] = local_substates.size()
	return local_substates

func add_state(state_name: String, substate_names: PackedStringArray = ["BASE"]) -> void:
	states.set(state_name, states.size())
	all_substates[states[state_name]] = substate_names

func add_substates(state_id: int, substate_names: PackedStringArray) -> void:
	all_substates[state_id] = substate_names
