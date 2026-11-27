extends FighterAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkFwH", true)

func update(delta: float) -> void:
	if brain.frame < 31:
		brain.apply_gravity(delta, data.get_fall_gravity())
		brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
	
	if brain.frame == 3:
		hitboxes["A/0"].activate({aim = sm.state_data.aim})
	
	if brain.frame >= 43:
		sm.change_state(sm.states.AIR, "FAL_NRM")
	if brain.frame >= 25:
		if sm.input_chase():
			sm.chase_pos.y = brain.get_center().y+7.0
			sm.change_state(sm.states.CHS)
			return
	if brain.frame >= 31:
		if brain.frame == 31:
			brain.velocity.x = -brain.global_facing_dir_h*5.0
			brain.velocity.y = 12.0
		brain.apply_gravity(delta, data.get_fall_gravity())

func end(new_state: int) -> void:
	super(new_state)
