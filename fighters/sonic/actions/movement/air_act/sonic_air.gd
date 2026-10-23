class_name SonicAir extends PlayerAction


func wake() -> void:
	super()
	brain.landed.connect(on_land)

func start(old_state: int) -> void:
	super(old_state)
	brain.play_section(&"AirAct", &"", &"Loop", true, Animation.LOOP_NONE)
	if brain.move_input_raw.length() > PlayerInput.DEADZONE:
		brain.update_facing_dir(brain.move_input)
	brain.velocity = Basis(Vector3.UP, brain.global_facing_dir).x*20.0
	brain.velocity.y = 5.0
	brain.air_act_refreshed = false
	brain.hurtbox.deactivate()
	hurtboxes["A"].activate({
		def = data.combat_def,
		weight = data.combat_weight
	})

func update(delta: float) -> void:
	sm.input_fast_fall()
	if brain.frame == 6.0:
		hurtboxes["A"].hurtbox_mode = HurtboxData.HurtboxModes.NRM
	if brain.frame == 12.0:
		hurtboxes["A"].deactivate()
		hurtboxes["B"].activate({
			weight = data.combat_weight,
			def = data.combat_def
		})
	if brain.frame == 15.0:
		brain.play_section(&"AirAct", &"Loop", &"", true, Animation.LOOP_LINEAR)
	
	if brain.attack_buffer > 0.0:
		if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
			if brain.frame >= 8.0:
				if sm.input_attack(
					sm.get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.NTL),
					sm.get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.FWD),
					sm.get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.BAK)
					): return
		else:
			if brain.frame >= 20.0:
				if sm.input_attack(
					sm.states.ATK_ARN,
					sm.states.ATK_ARF,
					sm.states.ATK_ARU
					): return
			elif brain.frame >= 2.0:
				if sm.input_attack(
					sm.states.ATK_ARA,
					sm.states.ATK_ARA,
					sm.states.ATK_ARA
					): return
	if brain.frame >= 30.0:
		sm.change_state(sm.states.AIR)
		return
	if brain.frame >= 7.0 || brain.fast_falling:
		if brain.fast_falling:
			brain.apply_gravity(delta, -300.0, INF)
			brain.walk(Vector3.ZERO, data.air_speed, 0.0, data.get_walk_decel_amount(), delta)
		else:
			brain.apply_gravity(delta, data.get_fall_gravity(), data.fall_max_speed)
			brain.walk(Vector3.ZERO, data.air_speed, 0.0, data.get_air_decel_amount(), delta)
	if brain.is_on_floor() && brain.frame >= 12.0:
		brain.land(15.0, 2.5)

func end(new_state: int) -> void:
	super(new_state)
	if new_state == sm.states.LND && brain.fast_falling:
		brain.fast_falling = false
	brain.hurtbox.activate()

func on_land() -> void:
	brain.air_act_refreshed = true
