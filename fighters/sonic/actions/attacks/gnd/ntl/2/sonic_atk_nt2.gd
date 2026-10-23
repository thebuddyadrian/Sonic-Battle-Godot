class_name SonicAtkNt2 extends PlayerAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkLt2", true)

func update(delta: float) -> void:
	brain.apply_gravity(delta, data.get_fall_gravity())
	brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
	if brain.attack_buffer > 0.0:
		var attack_input_data: Dictionary = brain.buffered_attack_input_data
		match attack_input_data.input:
			PlayerBrain.AttackInput.NTL:
				brain.reset_attack_buffer()
				sm.jab_count += 1
				if brain.frame >= 10.0:
					sm.change_state(sm.states.ATK_LT3)
			PlayerBrain.AttackInput.FWD:
				if brain.frame >= 10.0:
					brain.reset_attack_buffer()
					sm.change_state(sm.states.ATK_FWC, "BASE", {input_method = attack_input_data.method, dir = brain.get_kb_aim()})
			PlayerBrain.AttackInput.BAK:
				if brain.frame >= 10.0:
					brain.reset_attack_buffer()
					if attack_input_data.method == PlayerBrain.InputMethod.DIR:
						brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
					sm.change_state(sm.states.ATK_UPC, "BASE", {input_method = attack_input_data.method})
	if brain.frame == 5.0:
		hitboxes["A/0"].activate()
	if brain.frame >= 13.0:
		sm.change_state(sm.states.IDL)
	if brain.frame >= 10.0:
		if sm.jab_count >= 2 || Input.is_action_pressed(&"Attack"):
			sm.change_state(sm.states.ATK_LT3)
	if brain.frame >= 6.0:
		brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)

func end(new_state: int) -> void:
	super(new_state)
