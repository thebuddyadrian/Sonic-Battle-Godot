class_name SonicGrd extends PlayerAction

var guard_speed: float
var guard_decel: float

func wake() -> void:
	super()
	guardboxes["A"].hitbox_entered.connect(_on_hitbox_entered)

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"Grd", true)
	guard_speed = data.walk_speed
	guard_decel = data.get_walk_decel_amount()
	brain.hurtbox.deactivate()
	hurtboxes["A"].activate()

func update(delta: float) -> void:
	brain.walk(Vector3.ZERO, guard_speed, 0.0, guard_decel, delta)
	if brain.frame == 8.0:
		hurtboxes["A"].hurtbox_mode = HurtboxData.HurtboxModes.INT
		guardboxes["A"].activate()
	
	if brain.frame == 23.0:
		hurtboxes["A"].hurtbox_mode = HurtboxData.HurtboxModes.NRM
	
	if brain.frame >= 38.0:
		sm.change_state(sm.states.IDL, "IDL")
		return
	if brain.frame >= 33.0:
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
		if sm.input_jump(): return 
		if sm.input_dash(): return
		if sm.input_guard(): return
		if sm.input_dodge(): return

func end(new_state: int) -> void:
	super(new_state)
	brain.hurtbox.activate()

func _on_hitbox_entered(hitbox: HitboxArea, hitbox_data: HitboxData) -> void:
	guard_speed = hitbox_data.shield_knockback
	if absf(guard_speed) <= 0.1:
		guard_speed = data.walk_speed
	guard_decel = PlayerData.get_accel_amount(0.5, guard_speed)
