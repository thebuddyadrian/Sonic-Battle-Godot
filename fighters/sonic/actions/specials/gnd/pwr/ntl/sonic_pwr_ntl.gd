class_name SonicPwrNtl extends PlayerAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.update_facing_dir(Vector3(brain.global_facing_dir_h, 0.0, 0.0))
	brain.play_anim(&"PwrNtl", true)

func update(delta: float) -> void:
	sm.input_fast_fall()
	if brain.fast_falling:
		brain.apply_gravity(delta, data.get_fast_fall_gravity())
	else:
		brain.apply_gravity(delta, data.get_fall_gravity())
	if brain.frame <= 4.0:
		if brain.move_input.length() > PlayerInput.DEADZONE:
			brain.update_facing_dir(brain.move_input)
	
	if brain.frame == 5.0:
		brain.velocity = brain.get_forward()*13.0
		brain.velocity.y = 0.0
	
	if brain.frame == 11.0:
		brain.hurtbox.deactivate()
		hurtboxes["A"].activate()
	
	if brain.frame == 15.0:
		hitboxes["A/0"].activate()
	
	if brain.frame == 27.0:
		brain.velocity.x *= 0.5
		brain.velocity.z *= 0.5
		brain.hurtbox.activate()
		hurtboxes["A"].deactivate()
	
	if brain.frame >= 41:
		sm.change_state(sm.states.IDL, "IDL")
	
	if brain.frame >= 27.0:
		brain.walk(Vector3.ZERO, 20.0, 0.0, PlayerData.get_accel_amount(5.0, 20.0), delta)
	

func end(new_state: int) -> void:
	super(new_state)
