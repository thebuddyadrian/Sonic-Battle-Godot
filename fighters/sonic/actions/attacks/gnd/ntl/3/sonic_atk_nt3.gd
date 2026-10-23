class_name SonicAtkNt3 extends PlayerAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkLt3", true)

func update(delta: float) -> void:
	brain.apply_gravity(delta, data.get_fall_gravity())
	brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
	if brain.attack_buffer > 0.0:
		var attack_input_data: Dictionary = brain.buffered_attack_input_data
		match attack_input_data.input:
			PlayerBrain.AttackInput.NTL:
				sm.jab_count += 1
				brain.reset_attack_buffer()
				if brain.frame >= 15.0:
					if absf(brain.move_input.x) > 0.3 && signf(brain.move_input_raw.x) == -signf(brain.local_flip_h):
						sm.change_state(sm.states.ATK_UPC, "BASE", {input_method = attack_input_data.method})
					else:
						sm.change_state(sm.states.ATK_FWC, "BASE", {input_method = attack_input_data.method, dir = brain.get_kb_aim()})
			PlayerBrain.AttackInput.FWD:
				if brain.frame >= 15.0:
					brain.reset_attack_buffer()
					sm.change_state(sm.states.ATK_FWC, "BASE", {input_method = attack_input_data.method, dir = brain.get_kb_aim()})
			PlayerBrain.AttackInput.BAK:
				if brain.frame >= 15.0:
					brain.reset_attack_buffer()
					if attack_input_data.method == PlayerBrain.InputMethod.DIR:
						brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
					sm.change_state(sm.states.ATK_UPC, "BASE", {input_method = attack_input_data.method})
	if brain.frame == 5.0:
		hitboxes["A/0"].activate()
	if brain.frame == 8.0:
		brain.velocity.x = 0.0
		brain.velocity.z = 0.0
	if brain.frame >= 25.0:
		sm.change_state(sm.states.IDL)
	if brain.frame >= 15.0:
		if sm.jab_count >= 3 || Input.is_action_pressed(&"Attack"):
			if absf(brain.move_input.x) > 0.3 && signf(brain.move_input_raw.x) == -signf(brain.local_flip_h):
				sm.change_state(sm.states.ATK_UPC, "BASE", {input_method = PlayerBrain.InputMethod.DIR, dir = brain.get_kb_aim()})
			else:
				sm.change_state(sm.states.ATK_FWC, "BASE", {input_method = PlayerBrain.InputMethod.DIR, dir = brain.get_kb_aim()})
func end(new_state: int) -> void:
	super(new_state)
