class_name SonicAtkArA extends PlayerAction

func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_section(&"AtkArA", &"", &"Loop", true)
	if brain.velocity.y <= 0.0:
		brain.velocity.y = 0.0

func update(delta: float) -> void:
	if brain.frame <= 4.0:
		if brain.atk_stk_input_raw.length() > PlayerInput.DEADZONE:
			brain.update_facing_dir(brain.input_raw_to_world(brain.atk_stk_input_raw))
		elif brain.move_input_raw.length() > PlayerInput.DEADZONE:
			brain.update_facing_dir(brain.move_input)
		if brain.frame == 4.0:
			brain.velocity = Basis(Vector3.UP, brain.global_facing_dir).x*15.0
	else:
		brain.apply_gravity(delta, -50.0, 20.0)
	
	if brain.frame == 6.0:
		hitboxes["A/0"].activate()
	if brain.frame == 9.0:
		hitboxes["A/1"].activate()
		brain.play_section(&"AtkArA", &"Loop", &"", true, Animation.LOOP_LINEAR)
		
	if brain.is_on_floor():
		if brain.frame <= 15.0:
			brain.land(18.0, 3.0)
		else:
			brain.land()

func end(new_state: int) -> void:
	super(new_state)
