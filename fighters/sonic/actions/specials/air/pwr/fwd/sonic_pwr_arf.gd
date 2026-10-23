class_name SonicPwrArF extends PlayerAction

func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.velocity = Vector3.ZERO
	brain.play_anim(&"PwrArF", true, Animation.LOOP_NONE)

func update(delta: float) -> void:
	if brain.frame == 19.0:
		brain.velocity = brain.get_forward()*45.0
		hitboxes["A/0"].activate()
	
	if brain.frame == 23.0:
		brain.velocity = Vector3.ZERO
		hitboxes["A/1"].activate()
	
	if brain.frame >= 30.0:
		brain.apply_gravity(delta, data.get_fall_gravity(), data.fall_max_speed)
	
	if brain.frame >= 40.0:
		sm.change_state(sm.states.AIR, "FAL_NRM")

func end(new_state: int) -> void:
	super(new_state)
