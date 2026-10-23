class_name SonicDgG extends PlayerAction

func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"DgeGnd", true)

func update(delta: float) -> void:
	if brain.frame == 5.0:
		brain.hurtbox.hurtbox_mode = HurtboxData.HurtboxModes.INT
	if brain.frame == 15.0:
		brain.hurtbox.hurtbox_mode = HurtboxData.HurtboxModes.NRM
		if brain.move_input.length() > PlayerInput.DEADZONE: brain.update_facing_dir(brain.move_input)
		else: brain.update_facing_dir(-brain.dodge_input)
	if brain.frame <= 4.0:
		brain.walk(
			Vector3.ZERO,
			data.walk_speed,
			0.0,
			data.get_walk_decel_amount(),
			delta
			)
	elif brain.frame <= 15.0:
		brain.walk(
			brain.dodge_input,
			data.dodge_speed,
			PlayerData.get_accel_amount(
				data.dodge_acceleration,
				data.dodge_speed
				),
			0.0,
			delta
			)
	elif brain.frame <= 28.0:
		brain.walk(
			Vector3.ZERO,
			data.dodge_speed,
			0.0,
			PlayerData.get_accel_amount(
				data.dodge_deceleration,
				data.dodge_speed
				),
			delta
			)
	elif brain.frame <= 33.0:
		brain.walk(
			Vector3.ZERO,
			data.walk_speed,
			0.0,
			data.get_walk_decel_amount(),
			delta
			)
		if sm.input_jump(): return 
		if sm.input_dash(): return
		if brain.attack_buffer > 0.0:
			if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
				if sm.input_attack(
					sm.get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.NTL),
					sm.get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.FWD),
					sm.get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.BAK)
					): return
			else:
				if sm.input_attack(
					sm.states.ATK_LT1,
					sm.states.ATK_FWH,
					sm.states.ATK_UPH
					): return
		if sm.input_guard(): return
	else:
		sm.change_state(sm.states.IDL, "IDL")
	

func end(new_state: int) -> void:
	super(new_state)
