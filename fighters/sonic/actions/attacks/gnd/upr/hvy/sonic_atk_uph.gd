class_name SonicAtkUpH extends PlayerAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkUpH", true)

func update(delta: float) -> void:
	brain.apply_gravity(delta, data.get_fall_gravity())
	brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
	if brain.frame == 6.0:
		hitboxes["A/0"].activate()
	if brain.frame >= 29.0:
		sm.change_state(sm.states.IDL)
	if brain.frame >= 20.0:
		if brain.jump_buffer > 0.0 && brain.is_on_floor():
			brain.jump_buffer = 0.0
			sm.change_state(sm.states.JMP_SQT)
	
func end(new_state: int) -> void:
	super(new_state)
