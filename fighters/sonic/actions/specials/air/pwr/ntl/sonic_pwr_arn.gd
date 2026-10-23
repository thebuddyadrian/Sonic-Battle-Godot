class_name SonicPwrArN extends PlayerAction


func wake() -> void:
	super()
	sm.add_substates(sm.states.PWR_ARN, ["DRP", "LND", "RBD"])

func start(old_state: int) -> void:
	super(old_state)
	brain.velocity = Vector3.ZERO
	brain.play_section(&"PwrArN", &"", &"Startup", true, Animation.LOOP_NONE)

func update(delta: float) -> void:
	match sm.substate:
		sm.substates.DRP:
			if brain.sub_frame == 13.0:
				brain.play_section(&"PwrArN", &"EastStart", &"EastEnd", true, Animation.LOOP_LINEAR)
			if brain.sub_frame <= 13.0:
				brain.velocity = Vector3.ZERO
			else:
				brain.velocity.y = -30.0
				brain.velocity.x = brain.get_forward().x*3.0
				brain.velocity.z = brain.get_forward().z*3.0
				if brain.sub_frame/3.0 == roundf(brain.sub_frame/3.0):
					hitboxes["A/0"].activate({clear = true})
				if brain.is_on_floor():
					if Input.is_action_pressed(&"Special"):
						brain.velocity.y = 20.0
						sm.change_substate(sm.substates.RBD)
					else:
						brain.velocity = Vector3.ZERO
						brain.landed.emit()
						sm.change_substate(sm.substates.LND)
			return
		sm.substates.LND:
			brain.apply_gravity(delta, data.get_fall_gravity(), data.fall_max_speed)
			brain.velocity.x = 0.0
			brain.velocity.z = 0.0
			if brain.sub_frame == 1.0:
				brain.play_section(&"Lnd", &"", &"Land", true)
			if brain.sub_frame == 3.0:
				hitboxes["B/0"].activate()
			if brain.sub_frame == 17.0:
				brain.play_section(&"Lnd", &"End", &"", true)
			if brain.sub_frame >= 20.0:
				sm.change_state(sm.states.IDL, "IDL")
			return
		sm.substates.RBD:
			brain.apply_gravity(delta, data.get_full_jump_gravity())
			if brain.sub_frame/3.0 == roundf(brain.sub_frame/3.0):
					hitboxes["A/0"].activate({clear = true})
			if brain.sub_frame >= 25.0:
				sm.change_state(sm.states.AIR, "FAL_NRM")
			return

func end(new_state: int) -> void:
	super(new_state)
