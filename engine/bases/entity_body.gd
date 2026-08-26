class_name EntityBody extends CharacterBody3D


@onready var center_point: Marker3D = $CenterPoint
@onready var collbox: CollisionShape3D = $Collbox
@onready var sprite: BattleAnimatedSprite3D = $SpriteAnchor/BillboardAnim
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var global_facing_dir: float = 0.0
var global_facing_dir_h: float = 1.0
var frame: float = 0.0
var pause_frame: float = 0.0
var pause_dur: float = 0.0
var pause_pos: Vector3 = Vector3.ZERO
var pause_vel: Vector3 = Vector3.ZERO

var cam: Camera3D
var cam_pivot: Node3D

signal pause_finished

func update(delta: float) -> void:
	var delta_frame: float = floorf(delta*60.0)
	if pause_dur == 0.0:
		frame += delta_frame
	sprite.flipped = global_facing_dir_h <= 0.0

func update_freeze(delta: float) -> void:
	if pause_frame < pause_dur:
		global_position = pause_pos
		velocity = Vector3.ZERO
		pause_frame += floorf(delta*Globals.FPS)
		anim_player.speed_scale = 0.0
	else:
		if pause_dur > 0.0:
			if pause_vel != Vector3.ZERO:
				velocity = pause_vel
				pause_vel = Vector3.ZERO
			pause_frame = 0.0
			pause_dur = 0.0
			anim_player.speed_scale = 1.0
			anim_player.advance(0.0)
			pause_finished.emit()

func get_forward() -> Vector3:
	return Basis(Vector3.UP, global_facing_dir).x

func get_cam_forward() -> Vector3:
	var forward: Vector3 = cam.global_basis.z
	forward.x = 0.0
	forward.y = 0.0
	return forward.normalized()

func get_cam_right() -> Vector3:
	var right: Vector3 = cam.global_basis.x
	right.y = 0.0
	right.z = 0.0
	return right.normalized()

func get_center() -> Vector3:
	return center_point.global_position

func update_facing_dir(direction: Vector3) -> void:
	var target_dir: float = Vector3.RIGHT.signed_angle_to(direction, Vector3.UP)
	var facing_dir_x: float = cos(global_facing_dir)
	var target_dir_x: float = cos(target_dir)
	global_facing_dir = target_dir
	var dir_x: float = cos(fposmod((cam.global_rotation.y - global_facing_dir), 2*PI))
	if absf(dir_x) > 0.01:
		global_facing_dir_h = signf(cos(global_facing_dir))

func move_center_to_point(point: Vector3, collide: bool = false) -> void:
	var target_pos: Vector3 = point-center_point.position
	velocity = 60.0*(target_pos-global_position)
	if collide:
		move_and_collide(velocity)

#func _on_reflect(reflector: ReflectorArea, reflector_data: ReflectorData) -> void:
	#pass
