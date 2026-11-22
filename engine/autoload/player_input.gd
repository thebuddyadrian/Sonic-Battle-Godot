# Helper class to get player-specific input for menus
# In game, a function on base_player.gd will be used instead.
extends Node

const DEADZONE: float = 0.2

enum ButtonState {
	NOT_PRESSED = 0,
	PRESSED = 1,
	RELEASED = 2,
	HELD = 3,
}

func player_action_pressed(action: StringName, player_no: int) -> bool:
	return Input.is_action_pressed(action + str(player_no))


func player_action_just_pressed(action: StringName, player_no: int) -> bool:
	return Input.is_action_just_pressed(action + str(player_no))


func player_action_just_released(action: StringName, player_no: int) -> bool:
	return Input.is_action_just_released(action + str(player_no))

func player_action_get_vector(negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName, player_no: int, deadzone: float = -1.0) -> Vector2:
	var neg_x: StringName = negative_x + str(player_no)
	var pos_x: StringName = positive_x + str(player_no)
	var neg_y: StringName = negative_y + str(player_no)
	var pos_y: StringName = positive_y + str(player_no)
	
	return Input.get_vector(neg_x, pos_x, neg_y, pos_y, deadzone)
