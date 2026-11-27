extends FighterAction

func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkDnk")
	brain.velocity = Vector3.ZERO

func update(delta: float) -> void:
	if brain.frame == 10:
		hitboxes["A/0"].activate()
	if brain.frame == 12:
		hitboxes["A/1"].activate()
	
	if brain.frame >= 29:
		sm.change_state(sm.states.AIR, "FAL_NRM")

func end(new_state: int) -> void:
	super(new_state)
