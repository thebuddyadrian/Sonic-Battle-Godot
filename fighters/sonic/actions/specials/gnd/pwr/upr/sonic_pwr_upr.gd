class_name SonicPwrUpr extends PlayerAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"PwrUpr", true)

func update(delta: float) -> void:
	if brain.frame <= 10.0:
		sm.input_fast_fall()
		if brain.fast_falling:
			brain.apply_gravity(delta, data.get_fast_fall_gravity())
		else:
			brain.apply_gravity(delta, data.get_fall_gravity())
		brain.walk(Vector3.ZERO, data.walk_speed, 0.0, data.get_walk_decel_amount(), delta)
		if brain.frame == 10.0:
			brain.velocity.x = 0.0
			brain.velocity.z = 0.0
	
	if brain.frame == 11.0:
		brain.velocity.y = 15.0
	
	if brain.frame >= 12.0 && brain.frame <= 24.0:
		if brain.frame/3.0 == roundf(brain.frame/3.0):
			hitbox_groups["A"].hit_log.clear_log()
			hitboxes["A/0"].activate()
	
	if brain.frame == 27.0:
		hitboxes["B/0"].activate()
	
	if brain.frame >= 16.0:
		brain.walk(brain.move_input, 2.0, data.get_air_accel_amount(), data.get_air_decel_amount(), delta)
	
	if brain.frame >= 30.0:
		brain.velocity.y = move_toward(brain.velocity.y, 0.0, 100.0*delta)
	
	if brain.frame >= 46.0:
		sm.change_state(sm.states.AIR, "FAL_FRE")

func end(new_state: int) -> void:
	super(new_state)
