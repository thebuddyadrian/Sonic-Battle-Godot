extends FighterAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_section(&"Dsh", &"", &"Loop", true, Animation.LOOP_NONE)
	if brain.move_input_raw.length() > PlayerInput.DEADZONE:
		brain.update_facing_dir(brain.move_input)
	brain.velocity = brain.input_raw_to_world(brain.last_move_input_raw)*20.0
	brain.velocity.y = 10.0

func update(delta: float) -> void:
	if brain.fast_falling:
		brain.apply_gravity(delta, data.get_fast_fall_gravity(), data.fall_fast_max_speed)
	else:
		brain.apply_gravity(delta, -80.0)
	brain.walk(Vector3.ZERO, 20.0, 0.0, data.get_air_decel_amount(), delta)
	
	if brain.frame == 10:
		brain.play_section(&"Dsh", &"Loop", &"", true, Animation.LOOP_LINEAR)
		
	if brain.frame >= 5:
		if sm.input_attack(
			sm.states.ATK_DSH,
			sm.states.ATK_DSH,
			sm.states.ATK_DSH
			):
			return
	if brain.frame >= 18:
		if brain.jump_buffer > 0:
			brain.jump_buffer = 0
			sm.change_state(sm.states.AIR_ACT)
			return
	if brain.frame >= 2:
		sm.input_fast_fall()
	if brain.is_on_floor() && brain.frame >= 6:
		if brain.fast_falling:
			brain.land(10, 1.0)
		else:
			brain.velocity.x *= 0.3
			brain.velocity.z *= 0.3
			brain.land(10, 2.5)

func end(new_state: int) -> void:
	super(new_state)
	if new_state == sm.states.LND && brain.fast_falling:
		brain.fast_falling = false
