class_name SonicAtkArN extends PlayerAction


var can_boost: bool = true


func wake() -> void:
	super()
	brain.landed.connect(on_land)

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkArN", true)

func update(delta: float) -> void:
	brain.apply_gravity(delta, data.get_fall_gravity())
	brain.walk(brain.move_input, data.air_speed, data.get_air_accel_amount(), data.get_air_decel_amount(), delta)
	
	if brain.frame == 6.0:
		hitboxes["A/0"].activate()
	
	if brain.frame >= 8.0 && brain.frame <= 12.0:
		if brain.velocity.y <= 8.0 && can_boost && !brain.is_on_floor():
			brain.velocity.y = 8.0
			can_boost = false
	
	if brain.frame >= 19.0:
		sm.change_state(sm.states.AIR, "FAL_NRM")
	elif brain.frame >= 16.0:
		if brain.attack_buffer > 0.0:
			var attack_input_data: Dictionary = brain.buffered_attack_input_data
			match attack_input_data.type:
				PlayerBrain.AttackType.NML:
					match attack_input_data.input:
						PlayerBrain.AttackInput.NTL:
							brain.reset_attack_buffer()
							sm.change_state(sm.states.ATK_ARN)
						PlayerBrain.AttackInput.FWD:
							brain.reset_attack_buffer()
							sm.change_state(sm.states.ATK_ARF)
						PlayerBrain.AttackInput.BAK:
							brain.reset_attack_buffer()
							sm.change_state(sm.states.ATK_ARU)
		elif brain.jump_buffer > 0.0 && brain.air_act_refreshed:
				brain.jump_buffer = 0.0
				sm.change_state(sm.states.AIR_ACT)
	if brain.is_on_floor():
		if brain.frame >= 4.0 && brain.frame <= 13.0:
			brain.land(7.0, 3.0)
		else:
			brain.land()

func end(new_state: int) -> void:
	super(new_state)

func on_land() -> void:
	can_boost = true
