class_name SonicPwrArU extends PlayerAction

func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.velocity = Vector3.ZERO
	brain.play_anim(&"PwrArU", true, Animation.LOOP_NONE)

func update(delta: float) -> void:
	if brain.frame >= 9.0:
		brain.velocity = brain.get_forward()*12.0
		brain.velocity.y = 3.5
		if brain.frame <= 25.0:
			if brain.frame/4.0 == roundf(brain.frame/4.0):
				hitboxes["A/0"].activate({clear = true})
		if brain.frame == 26.0:
			hitboxes["B/0"].activate()
		
		if brain.frame >= 31.0:
			sm.change_state(sm.states.AIR, "FAL_FRE")

func end(new_state: int) -> void:
	super(new_state)
