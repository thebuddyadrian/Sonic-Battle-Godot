class_name SonicPwrFwd extends PlayerAction


var dir_raw: Vector2
var dir: Vector3
var anim: Animation

func wake() -> void:
	super()
	sm.add_substates(sm.states.PWR_FWD, ["ATK", "RCL", "LND"])

func start(old_state: int) -> void:
	super(old_state)
	brain.velocity.x = 0.0
	brain.velocity.z = 0.0
	dir_raw = brain.last_move_input_raw
	brain.play_section(&"PwrFwd", &"", &"Startup", true)

func update(delta: float) -> void:
	match sm.substate:
		sm.substates.ATK:
			sm.input_fast_fall()
			if brain.fast_falling:
				brain.apply_gravity(delta, data.get_fast_fall_gravity())
			else:
				brain.apply_gravity(delta, data.get_fall_gravity())
			
			if brain.frame < 30.0:
				if brain.move_input_raw.length() > PlayerInput.DEADZONE:
					if [brain.global_facing_dir_h, 0.0].has(signf(brain.move_input.x)):
						dir_raw = brain.move_input_raw
			if brain.frame == 30.0:
				hitboxes["A/0"].activate()
				dir = brain.input_raw_to_world(dir_raw)
				brain.play_section(&"PwrFwd", &"EastStart", &"EastEnd", true, Animation.LOOP_LINEAR)
				#match pwr_hvy_dir:
					#Vector2.UP:
						#play_anim("PwrHvyN")
					#Vector2.DOWN:
						#play_anim("PwrHvyS")
					#_:
						#play_anim("PwrHvyE")
			if brain.frame == 55.0:
				brain.play_section(&"PwrFwd", &"EndlagStart", &"EndlagEnd", true)
			if brain.frame >= 30.0 && brain.frame <= 55.0:
				brain.velocity.x = dir.x*25.0
				brain.velocity.z = dir.z*25.0
				if brain.is_on_wall():
					brain.velocity = brain.get_wall_normal()*10.0
					brain.velocity.y = 15.0
					brain.frame = 0.0
					brain.play_section(&"PwrFwd", &"CrashAirborneStart", &"CrashAirborneEnd", true)
					sm.change_substate(sm.substates.RCL)
					return
			if brain.frame >= 40.0:
				if brain.move_input.length() > PlayerInput.DEADZONE:
					if brain.move_input == -dir:
						if brain.frame < 52.0:
							hitboxes["A/0"].deactivate()
							brain.frame = 52.0
							return
				if sm.input_chase():
					sm.chase_pos.y = brain.get_center().y+7.0
					sm.change_state(sm.states.CHS)
					return
			if brain.frame >= 55.0:
				if brain.is_on_floor():
					brain.walk(Vector3.ZERO, 25.0, 0.0, PlayerData.get_accel_amount(3.0, 25.0), delta)
			if brain.frame >= 88.0:
				sm.change_state(sm.states.IDL, "IDL")
		sm.substates.RCL:
			brain.apply_gravity(delta, data.get_fall_gravity(), data.fall_max_speed)
			if brain.is_on_floor():
				brain.velocity = Vector3.ZERO
				brain.play_section(&"PwrFwd", &"CrashLand", &"", true)
				brain.frame = 0.0
				sm.change_substate(sm.substates.LND)
		sm.substates.LND:
			if brain.frame >= 55.0:
				sm.change_state(sm.states.IDL, "IDL")

func end(new_state: int) -> void:
	super(new_state)
