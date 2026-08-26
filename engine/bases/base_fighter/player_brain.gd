class_name PlayerBrain extends EntityBody


const JUMP_BUFFER_FRAMES: float = 6.0
const DASH_INPUT_BUFFER_FRAMES: float = 15.0
const DASH_BUFFER_FRAMES: float = 9.0
const DODGE_DIR_BUFFER_FRAMES: float = 7.0
const DODGE_BUFFER_FRAMES: float = 9.0
const GUARD_BUFFER_FRAMES: float = 25.0
const ATTACK_BUFFER_FRAMES: float = 9.0
const ATTACK_DIR_BUFFER_FRAMES: float = 7.0
const GUARD_COOLDOWN_FRAMES: float = 20.0
const DODGE_COOLDOWN_FRAMES: float = 30.0
const STOP_THRESHOLD: float = 1.0
const CHASE_WINDOW_FRAMES: float = 60.0
const CHASE_SPEED: float = 0.07
const STUN_KB_DECAY: float = 0.85


enum AttackType{
	NML = 0,
	SPL = 1,
}

enum AttackInput{
	NTL = 0,
	BAK = 1,
	FWD = 2,
}

enum SpecialType{
	PWR = 0,
	SHT = 1,
	TRP = 2,
}

enum SpecialVariant{
	GND = 0,
	AIR = 1,
	DEF = 2,
}

enum InputMethod{
	DIR = 0,
	STK = 1,
}

enum FlipModes{
	STC = 0,
	LTR = 1,
	ARD = 2,
}

enum ControlModes{
	INP_PLR = 0,
	INP_CPU = 1,
	IDL = 2,
	JMP = 3,
	ATK_NTL = 4,
	ATK_UPR = 5,
	ATK_FWD = 6,
	GRD = 7,
}

enum SpriteModes{
	DIR2 = 0,
	DIR4 = 1,
}


@export var player_data: PlayerData
@export_group("")
@export var player_id: int
@export var player_name: String
@export var control_mode: ControlModes = ControlModes.INP_PLR
@export var ground_special: SpecialType
@export var aerial_special: SpecialType
@export var defense_special: SpecialType

@onready var sm: PlayerStateMachine = $PlayerStateMachine
#@onready var grabbox: Area3D = $GrabBox
#@onready var grabbox_shape: CollisionShape3D = $GrabBox/GrabBoxShape
#@onready var grab_point: Marker3D = $GrabBox/GrabPoint

var is_turning: bool = false
var can_guard_cancel: bool = false
var fast_falling: bool = false
var air_act_refreshed: bool = true

var points: int = 3
var attack_input: AttackInput
var sprite_mode: SpriteModes = SpriteModes.DIR2

var buffered_attack_input_data: Dictionary = {
	type = 0,
	input = 0,
	method = 0,
}

var sub_frame: float = 0.0
var local_flip_h: float = 1.0
var jump_buffer: float = 0.0
var attack_dir_buffer: float = 0.0
var attack_buffer: float = 0.0
var grab_buffer: float = 0.0
var dash_input_buffer: float = 0.0
var dash_buffer: float = 0.0
var dodge_buffer: float = 0.0
var dodge_dir_buffer: float = 0.0
var guard_buffer: float = 0.0
var dodge_cooldown: float = 0.0
var grab_cooldown: float = 0.0
var land_lag: float
var land_decel: float
var health: float:
	set(value):
		health = clampf(value, 0.0, data.combat_max_hp)
var hgauge: float = 0.0:
	set(value):
		hgauge = clampf(value, 0.0, data.combat_max_hg)
var stun: float = 0.0
var grabstun: float = 0.0
var flinch_armor: float = 0.0
var dmg_armor: float = 0.0
var chase_window: float = 0.0
var guard_startup: float
var guard_activation: float
var guard_recovery: float
var guard_cooldown: float = 0.0

var move_input_raw: Vector2 = Vector2.ZERO
var last_move_input_raw: Vector2 = Vector2.RIGHT
var atk_stk_input_raw: Vector2 = Vector2.ZERO
var last_atk_stk_input_raw: Vector2 = Vector2.RIGHT

var move_input: Vector3 = Vector3.ZERO
var dodge_input: Vector3
var knockback: Vector3 = Vector3.ZERO

var char_name: String

var data: PlayerData

var chase_target: PlayerBrain
var grab_target: PlayerBrain
var grab_holder: PlayerBrain

var hurtbox: HurtboxArea


signal landed
signal kod


func _ready() -> void:
	data = player_data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	sm.data = data
	for property in data.get_property_list():
		if property.class_name == &"PlayerAction":
			if data.get(property.name):
				var action: PlayerAction = data.get(property.name)
				action.brain = self
				action.wake()
	data.combat_hurtbox.weight = data.combat_weight
	data.combat_hurtbox.defense = data.combat_def
	hurtbox = HurtboxArea.new(data.combat_hurtbox, self)
	#hurtbox.reflector_entered.connect(_on_reflect)

func _unhandled_input(event: InputEvent) -> void:
	if control_mode == ControlModes.INP_PLR:
		if event.is_action_pressed(&"Jump"):
			on_jump_press()
		
		if event.is_action_pressed(&"Guard"):
			on_guard_press()
		
		if event.is_action_pressed(&"Grab"):
			on_grab_press()
		
		if event.is_action_pressed(&"Dash"):
			on_dash_press()
		
		get_atk_input(event)
		
		if event.is_action_pressed(&"Special"):
			on_attack_press(AttackType.SPL, attack_input, InputMethod.DIR)
		
		#if event.is_action_pressed(&"Swap"):
			#if ground_special == SpecialType.PWR:
				#ground_special = SpecialType.SHT
			#else:
				#ground_special = SpecialType.PWR

func wake() -> void:
	#super()
	#scale modifier fomula
	#var cos_angle: float = maxf(absf(cos(cam.global_rotation.x)), 0.01)
	#scale.y = base_scale/cos_angle
	#hurtbox.scale /= Hitbox.SCALE_MODIFIER
	#grabbox.scale /= Hitbox.SCALE_MODIFIER
	health = data.combat_max_hp
	update_facing_dir(global_position.direction_to(Vector3.ZERO))
	if player_id > 1:
		control_mode = ControlModes.IDL
	start()

func start() -> void:
	hurtbox.activate()

func update(delta: float) -> void:
	var delta_frame: float = floorf(delta*Globals.FPS)
	if pause_dur == 0.0:
		frame += delta_frame
		sub_frame += delta_frame
	dash_input_buffer -= delta_frame
	dash_input_buffer = maxf(0.0, dash_input_buffer)
	dash_buffer -= delta_frame
	dash_buffer = maxf(0.0, dash_buffer)
	jump_buffer -= delta_frame
	jump_buffer = maxf(0.0, jump_buffer)
	dodge_dir_buffer -= delta_frame
	dodge_dir_buffer = maxf(0.0, dodge_dir_buffer)
	dodge_buffer -= delta_frame
	dodge_buffer = maxf(0.0, dodge_buffer)
	guard_buffer -= delta_frame
	guard_buffer = maxf(0.0, guard_buffer)
	guard_cooldown -= delta_frame
	guard_cooldown = maxf(0.0, guard_cooldown)
	dodge_cooldown -= delta_frame
	dodge_cooldown = maxf(0.0, dodge_cooldown)
	grab_cooldown -= delta_frame
	grab_cooldown = maxf(0.0, grab_cooldown)
	attack_buffer -= delta_frame
	attack_buffer = maxf(0.0, attack_buffer)
	attack_dir_buffer -= delta_frame
	attack_dir_buffer = maxf(0.0, attack_dir_buffer)
	grab_buffer -= delta_frame
	grab_buffer = maxf(0.0, grab_buffer)
	chase_window -= delta_frame
	chase_window = maxf(0.0, chase_window)
	
	if chase_window <= 0.0 && chase_target != null && sm.state != sm.states.CHS:
		chase_window = 0.0
		chase_target = null
	
	match control_mode:
		ControlModes.INP_PLR:
			var new_move_input_raw: Vector2 = get_joy_input(Input.get_vector(&"MoveLeft", &"MoveRight", &"MoveUp", &"MoveDown"))
			if move_input_raw == Vector2.ZERO && new_move_input_raw.length() > PlayerInput.DEADZONE:
				on_move_press(new_move_input_raw)
			move_input_raw = new_move_input_raw
			if move_input_raw != Vector2.ZERO:
				last_move_input_raw = move_input_raw
			move_input = input_raw_to_world(move_input_raw)
			
			#if Input.is_action_just_pressed(&"Jump"):
				#on_jump_press()
			#
			#if Input.is_action_just_pressed(&"Guard"):
				#on_guard_press()
			#
			#if Input.is_action_just_pressed(&"Grab"):
				#on_grab_press()
			#
			#if Input.is_action_just_pressed(&"Dash"):
				#on_dash_press()
			
			
			
			#if Input.is_action_just_pressed(&"Special"):
				#on_attack_press(AttackType.SPL, attack_input, InputMethod.DIR)
		ControlModes.INP_CPU:
			#TODO - CPU Input
			pass
		ControlModes.JMP:
			if sm.state == sm.states.IDL:
				on_jump_press()
		ControlModes.ATK_NTL:
			if sm.jab_count < 2:
				on_attack_press(AttackType.NML, AttackInput.NTL, InputMethod.STK)
		ControlModes.ATK_UPR:
			on_attack_press(AttackType.NML, AttackInput.BAK, InputMethod.STK)
		ControlModes.ATK_FWD:
			on_attack_press(AttackType.NML, AttackInput.FWD, InputMethod.STK)
		ControlModes.GRD:
			on_guard_press()
	
	if move_input.length() <= PlayerInput.DEADZONE:
		attack_dir_buffer = 0.0
	if attack_dir_buffer <= 0.0:
		attack_input = AttackInput.NTL
	
	#if global_facing_dir_h == 1.0:
		#sprite_anchor.rotation.y = 0.0
	#else:
		#sprite_anchor.rotation.y = PI
	
	sprite.flipped = global_facing_dir_h <= 0.0
	update_self(delta)

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

func update_self(delta: float) -> void:
	pass

func reset_frames() -> void:
	frame = 0.0
	sub_frame = 0.0

func reset_attack_buffer()-> void:
	attack_buffer = 0.0
	attack_dir_buffer = 0.0

func apply_gravity(delta: float, gravity_strength: float, max_speed: float = data.fall_max_speed) -> void:
	velocity.y += gravity_strength*delta
	velocity.y = maxf(-max_speed, velocity.y)

func input_raw_to_world(input_raw: Vector2) -> Vector3:
	var input: Vector3 = (get_cam_forward()*input_raw.y)+(get_cam_right()*input_raw.x)
	input.y = 0.0
	input = input.normalized()
	return input

static func get_joy_input(input: Vector2, deadzone: float = PlayerInput.DEADZONE) -> Vector2:
	var input_vector: Vector2
	if input.length() > deadzone:
		var angle = snappedf(input.angle(), PI/4) / (PI/4)
		angle = wrapi(int(angle), 0, 8)
		match angle:
			0:
				input_vector = Vector2.RIGHT
			1:
				input_vector = Vector2.DOWN + Vector2.RIGHT
			2:
				input_vector = Vector2.DOWN
			3:
				input_vector = Vector2.DOWN + Vector2.LEFT
			4:
				input_vector = Vector2.LEFT
			5:
				input_vector = Vector2.UP + Vector2.LEFT
			6:
				input_vector = Vector2.UP
			7:
				input_vector = Vector2.UP + Vector2.RIGHT
	else:
		input_vector = Vector2.ZERO
	return input_vector.normalized()

func on_move_press(input: Vector2) -> void:
	on_attack_dir_input(input)
	dodge_dir_buffer = DODGE_DIR_BUFFER_FRAMES
	if dash_input_buffer > 0.0:
		dash_input_buffer = 0.0
		if input == last_move_input_raw:
			on_dash_press()
	else:
		dash_input_buffer = DASH_INPUT_BUFFER_FRAMES

func on_jump_press() -> void:
	jump_buffer = JUMP_BUFFER_FRAMES

func on_dash_press() -> void:
	dash_buffer = DASH_BUFFER_FRAMES

func on_guard_press() -> void:
	if dodge_dir_buffer > 0.0 && move_input_raw.length() > PlayerInput.DEADZONE:
		dodge_buffer = DODGE_BUFFER_FRAMES
		guard_buffer = 0.0
	else:
		guard_buffer = GUARD_BUFFER_FRAMES
		dodge_buffer = 0.0

func on_attack_press(type: AttackType, input: AttackInput, method: InputMethod = InputMethod.DIR) -> void:
	buffered_attack_input_data.type = type
	buffered_attack_input_data.input = input
	buffered_attack_input_data.method = method
	attack_buffer = ATTACK_BUFFER_FRAMES

func on_grab_press() -> void:
	grab_buffer = ATTACK_BUFFER_FRAMES

func on_attack_dir_input(input: Vector2) -> void:
	attack_dir_buffer = ATTACK_DIR_BUFFER_FRAMES
	if signf(input.x) == -local_flip_h:
		attack_input = AttackInput.BAK
	else:
		attack_input = AttackInput.FWD

func play_anim(anim_name: StringName, reset: bool = false, loop: Animation.LoopMode = Animation.LOOP_NONE, char_lib: String = char_name) -> void:
	var anim_path: String = "%s_anim_lib/%s" % [char_lib, anim_name]
	var anim: Animation = anim_player.get_animation(anim_path)
	if anim_name == anim_player.assigned_animation:
		if !reset: return
	anim.loop_mode = loop
	anim_player.stop()
	anim_player.play(anim_path)
	anim_player.advance(0.0)

func play_section(anim_name: StringName, start_point: StringName = &"", end_point: StringName = &"", reset: bool = false, loop: Animation.LoopMode = Animation.LOOP_NONE, char_lib: String = char_name) -> void:
	var anim_path: String = "%s_anim_lib/%s" % [char_lib, anim_name]
	var anim: Animation = anim_player.get_animation(anim_path)
	if anim_path == anim_player.assigned_animation:
		if anim.has_marker(start_point) &&\
		(anim.get_marker_time(start_point) == anim_player.get_section_start_time()) &&\
		anim.has_marker(end_point) &&\
		(anim.get_marker_time(end_point) == anim_player.get_section_end_time()):
			if !reset: return
	anim.loop_mode = loop
	anim_player.stop()
	anim_player.play(anim_path)
	anim_player.advance(0.0)
	anim_player.play_section_with_markers(anim_path, start_point, end_point)
	anim_player.advance(0.0)
	if anim.has_marker(start_point):
		anim_player.seek(anim.get_marker_time(start_point), true, true)

func update_facing_dir(direction: Vector3) -> void:
	var target_dir: float = Vector3.RIGHT.signed_angle_to(direction, Vector3.UP)
	var facing_dir_x: float = cos(global_facing_dir)
	var target_dir_x: float = cos(target_dir)
	if absf(facing_dir_x) > 0.1 && absf(target_dir_x) > 0.1:
		is_turning = signf(target_dir_x) == -signf(facing_dir_x)
	else:
		is_turning = false
	global_facing_dir = target_dir
	var dir_x: float = cos(fposmod((cam.global_rotation.y - global_facing_dir), 2*PI))
	if absf(dir_x) > 0.1:
		global_facing_dir_h = signf(cos(global_facing_dir))
		local_flip_h = signf(dir_x)

#func _on_reflect(reflector: ReflectorArea, reflector_data: ReflectorData) -> void:
	#var facing_norm: Vector3 = Basis(Vector3.UP, global_facing_dir).x
	#if reflector_data.flags_axis & ReflectorData.AxisFlags.X:
		#facing_norm.x *= -1.0
	#if reflector_data.flags_axis & ReflectorData.AxisFlags.Z:
		#facing_norm *= -1.0
	#update_facing_dir(facing_norm.normalized())

func grab_release() -> void:
	if grab_holder != null:
		grab_holder.grab_target = null
		grab_holder = null

#func create_hitbox(s: Shape3D, dur: float, dmg: float, ang: Vector2, kb: float, lt: Hitbox.LaunchTypes, hb_t: Hitbox.HitboxTypes, am: Hitbox.AngleModes, hs: float, hl: float, pos: Vector3, rot: Vector3, flip_mode: FlipModes = FlipModes.LTR) -> Hitbox:
	#var p_rot: Vector3
	#var r_rot: Vector3 = rot*ANGLE_CONVERSION
	#var facing: float
	#var f_ang: Vector2 = ang
	#match flip_mode:
		#FlipModes.STC:
			#facing = 0.0
			#f_ang.x = -ang.x
		#FlipModes.LTR:
			#if global_facing_dir_h == -1.0:
				#facing = PI
				#f_ang.x = 180-ang.x
			#else:
				#facing = 0.0
				#f_ang.x = -ang.x
		#FlipModes.ARD:
			#facing = snappedf(global_facing_dir, PI/2)
			#f_ang.x += global_facing_dir*(180/PI)
	#p_rot = Vector3.UP*facing
	#var scl: Vector3 = Vector3.ONE
	#var hitbox: Hitbox = Hitbox.create_hitbox(s, dur, dmg, f_ang, kb, lt, hb_t, am, hs, hl, pos, p_rot, r_rot, scl, self)
	#return hitbox
#
#func create_projectile(cs: Shape3D, hb_s: Shape3D, dur: float, dmg: float, kb_ang: Vector2, kb: float, lt: Hitbox.LaunchTypes, hb_t: Hitbox.HitboxTypes, am: ProjectileBrain.AngleModes, hs: float, hl: float, pos: Vector3, rot: Vector3, kf: int, pj_s: ProjectileScript, sf: Array[SpriteFrames], so: Vector2, flip_mode: FlipModes = FlipModes.LTR) -> ProjectileBrain:
	#var p_rot: Vector3
	#var r_rot: Vector3 = rot*ANGLE_CONVERSION
	#var facing: float
	#var kf_ang: Vector2 = kb_ang
	#match flip_mode:
		#FlipModes.STC:
			#facing = 0.0
			#pf_ang.x = -p_ang.x
			#kf_ang.x = -kb_ang.x
		#FlipModes.LTR:
			#if global_facing_dir_h == -1.0:
				#facing = PI
				#pf_ang.x = 180.0-p_ang.x
				#kf_ang.x = 180.0-kb_ang.x
			#else:
				#facing = 0.0
				#pf_ang.x = -p_ang.x
				#kf_ang.x = -kb_ang.x
		#FlipModes.ARD:
			#facing = snappedf(global_facing_dir, PI/2)
			#pf_ang.x += global_facing_dir*(180/PI)
			#kf_ang.x += global_facing_dir*(180/PI)
	#p_rot = Vector3.UP*facing
	#var scl: Vector3 = Vector3.ONE
	#var projectile: ProjectileBrain = ProjectileBrain.create_projectile(cs, hb_s, dur, dmg, kf_ang, kb, lt, hb_t, am, hs, hl, pos, p_rot, r_rot, scl, kf, pj_s, sf, so, self)
	#return projectile

func get_atk_input(event: InputEvent) -> void:
	var new_atk_stk_input_raw: Vector2 = get_joy_input(Input.get_vector(&"AttackLeft", &"AttackRight", &"AttackUp", &"AttackDown"))
	if atk_stk_input_raw == Vector2.ZERO && new_atk_stk_input_raw.length() > PlayerInput.DEADZONE:
		on_attack_dir_input(new_atk_stk_input_raw)
		on_attack_press(AttackType.NML, attack_input, InputMethod.STK)
	elif event.is_action_pressed(&"Attack"):
		on_attack_press(AttackType.NML, attack_input, InputMethod.DIR)
	atk_stk_input_raw = new_atk_stk_input_raw
	if atk_stk_input_raw != Vector2.ZERO:
		last_atk_stk_input_raw = atk_stk_input_raw

func get_kb_aim() -> Vector2:
	if atk_stk_input_raw.length() > PlayerInput.DEADZONE:
		return atk_stk_input_raw
	elif move_input_raw.length() > PlayerInput.DEADZONE:
		return move_input_raw
	else:
		return Vector2(global_facing_dir_h, 0.0)

#region ACTIONS
func walk(dir: Vector3, speed: float, acceleration: float, deceleration: float, delta: float) -> void:
	var target_speed: Vector3 = dir*speed
	
	var accel_rate: float = acceleration if target_speed.length() > PlayerInput.DEADZONE else deceleration
	
	var speed_dif: Vector3 = target_speed-velocity
	var movement: Vector3 = speed_dif*accel_rate
	velocity.x += movement.x*delta
	velocity.z += movement.z*delta
	if target_speed.length() <= PlayerInput.DEADZONE && Vector2(velocity.x, velocity.z).length() <= STOP_THRESHOLD:
		velocity.x = 0.0
		velocity.z = 0.0

func jump(force: float) -> void:
	velocity.y = force

func chase(target_pos: Vector3) -> bool:
	var self_pos: Vector3 = get_center()
	var distance: Vector3 = target_pos-self_pos
	var new_vel: Vector3 = Globals.FPS*(distance*CHASE_SPEED)
	velocity = new_vel
	if frame >= 45.0:
		velocity = Vector3.ZERO
		chase_target = null
		chase_window = 0.0
		return true
	return false

func land(landing_lag: float = data.land_soft_lag, landing_decel: float = data.land_deceleration) -> void:
	land_lag = landing_lag
	land_decel = PlayerData.get_accel_amount(landing_decel, data.walk_speed)
	landed.emit()
	sm.change_state(sm.states.LND)
#endregion

func atk_gtp_update(delta: float) -> void:
	pass

func atk_pml_update(delta: float) -> void:
	pass
