class_name SonicAtkUpT extends PlayerAction

func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"AtkUpT", true, Animation.LOOP_NONE)

func update(delta: float) -> void:
	brain.apply_gravity(delta, data.get_fall_gravity())
	brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
	if brain.frame == 5.0:
		hitboxes["A/0"].activate()
	if brain.frame >= 17.0:
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
					sm.states.ATK_FWC,
					sm.states.ATK_UPC
					): return
		if sm.input_guard(): return
		if sm.input_dodge(): return
	if brain.frame >= 23.0:
		sm.change_state(sm.states.IDL, "IDL")

func end(new_state: int) -> void:
	super(new_state)
