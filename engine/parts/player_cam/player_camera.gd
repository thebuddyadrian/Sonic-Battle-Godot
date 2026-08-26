## The main camera found in levels.
extends Camera3D
class_name BattleCamera


@export var movespeed := 3.5
@export var rotspeed := 3.5


@onready var root: Node3D = $"../.."
@onready var targetpos: Node3D = $"../../PositionTarget"
@onready var rotation_target: Node3D = $"../../RotationTarget"
@onready var pivot: Node3D = %Pivot

var player_id_to_track: int = 1: set = set_id_to_track
var player_to_track: PlayerBrain

# Set from the level script if the camera follows the player
var _dont_rotate = false

func _process(delta):
	var targetposex := Vector3.ZERO
	targetposex += player_to_track.global_position
	
	var targetpos2 := Vector3(targetposex.x/1.3, targetposex.y/1.2, targetposex.z)

	targetpos.global_position = targetpos.global_position.lerp(
		targetpos2, min(delta * movespeed, 1.0))
	
	rotation_target.global_position = rotation_target.global_position.lerp(
		targetposex, min(delta * rotspeed, 1.0))
	
	if !_dont_rotate:
		root.global_position = targetpos.global_position
		look_at_from_position(global_position, rotation_target.global_position)

func find_player_to_track(player_id: int) -> void:
	for player: PlayerBrain in get_tree().get_nodes_in_group("characters"):
		if player.player_id == player_id:
			player_to_track = player
			break

func set_id_to_track(id: int) -> void:
	player_id_to_track = id
	find_player_to_track(id)
	pivot.player_to_follow = player_to_track
