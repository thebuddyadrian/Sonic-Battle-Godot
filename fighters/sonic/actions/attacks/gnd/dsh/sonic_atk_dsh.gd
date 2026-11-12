class_name SonicAtkDsh extends FighterAction


func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkDsh", true)

func update(delta: float) -> void:
	brain.apply_gravity(delta, -90.0)
	brain.walk(Vector3.ZERO, data.air_speed, data.get_air_accel_amount(), data.get_air_decel_amount(), delta)
	
	if brain.frame == 5.0:
		brain.velocity.y = 10.0
	if brain.frame == 7.0:
		hitboxes["A/0"].activate()
	
	if brain.frame >= 21.0:
		sm.change_state(sm.states.AIR, "FAL_NRM")
	elif brain.frame >= 14.0:
		if brain.attack_buffer > 0.0:
			var attack_input_data: Dictionary = brain.buffered_attack_input_data
			match attack_input_data.type:
				FighterBrain.AttackType.NML:
					match attack_input_data.input:
						FighterBrain.AttackInput.NTL:
							brain.reset_attack_buffer()
							sm.change_state(sm.states.ATK_ARN)
						FighterBrain.AttackInput.FWD:
							brain.reset_attack_buffer()
							sm.change_state(sm.states.ATK_ARF)
						FighterBrain.AttackInput.BAK:
							brain.reset_attack_buffer()
							sm.change_state(sm.states.ATK_ARU)
		elif brain.jump_buffer > 0.0:
				brain.jump_buffer = 0.0
				sm.change_state(sm.states.AIR_ACT)

func end(new_state: int) -> void:
	super(new_state)
