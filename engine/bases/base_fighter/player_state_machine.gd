class_name PlayerStateMachine extends StateMachine


@onready var brain: PlayerBrain = $".."


var jab_count: int = 0
var data: PlayerData
var chase_pos: Vector3


func _ready() -> void:
	add_state("IDL", ["IDL", "TRN", "STP"])
	add_state("WLK", ["SRT", "WLK", "TRN"])
	add_state("JMP_SQT")
	add_state("AIR", ["FAL_NRM", "FAL_FRE", "JMP_SHT", "JMP_FUL"])
	add_state("AIR_ACT")
	add_state("LND")
	add_state("DSH")
	add_state("GRD")
	add_state("HEL")
	add_state("DGE_GND")
	add_state("DGE_AIR")
	add_state("CHS")
	add_state("ATK_LT1")
	add_state("ATK_LT2")
	add_state("ATK_LT3")
	add_state("ATK_FWC")
	add_state("ATK_FWT")
	add_state("ATK_FWH")
	add_state("ATK_UPC")
	add_state("ATK_UPT")
	add_state("ATK_UPH")
	add_state("ATK_DSN")
	add_state("ATK_DSF")
	add_state("ATK_DSU")
	add_state("ATK_ARN")
	add_state("ATK_ARF")
	add_state("ATK_ARU")
	add_state("ATK_ARA")
	add_state("ATK_DNK")
	add_state("GRB_IDL")
	add_state("GRB_DSH")
	add_state("GRB_PVT")
	add_state("GRB_HLD", ["IDL", "PML", "RLS"])
	add_state("THW_FWD")
	add_state("THW_BAK")
	add_state("THW_UPR")
	add_state("THW_DWN")
	add_state("PWR_NTL")
	add_state("PWR_FWD")
	add_state("PWR_UPR")
	add_state("PWR_ARN")
	add_state("PWR_ARF")
	add_state("PWR_ARU")
	add_state("SHT_NTL")
	add_state("SHT_FWD")
	add_state("SHT_UPR")
	add_state("SHT_ARN")
	add_state("SHT_ARF")
	add_state("SHT_ARU")
	add_state("TRP_NTL")
	add_state("TRP_FWD")
	add_state("TRP_UPR")
	add_state("TRP_ARN")
	add_state("TRP_ARF")
	add_state("TRP_ARU")
	add_state("STN_HIT")
	add_state("STN_BLK")
	add_state("STN_BRK")
	add_state("STN_GRB", ["STN", "RLS"])
	add_state("LNC_NML")
	add_state("LNC_HVY")
	add_state("LNC_UPR")
	add_state("LNC_DNK", ["IMP", "CRS"])
	add_state("CRS_WAL", ["IMP", "LNC"])
	add_state("CRS_FLR", ["IMP", "IDL"])
	add_state("TEC_NTL")
	add_state("TEC_FWD")
	add_state("TEC_BAK")
	add_state("TEC_WAL", ["IMP", "JMP"])
	add_state("GTP_NTL")
	add_state("GTP_FWD")
	add_state("GTP_BAK")
	add_state("GTP_ATK")
	add_state("FNT")
	brain.wake.call_deferred()
	change_state.call_deferred(states.IDL, "IDL")

func global_state_update(delta: float) -> void:
	brain.update_freeze(delta)
	if brain.pause_dur == 0.0:
		brain.update(delta)

func state_update(delta: float) -> void:
	if brain.pause_dur > 0.0:
		return
	brain.move_and_slide()
	
	if falling():
		change_state(states.AIR, "FAL_NRM")
		return
	
	if can_chase():
		change_state(states.CHS)
		chase_pos.y = brain.global_position.y+7.0
		return
	
	#if brain.attack_buffer > 0.0:
		#var attack_input_data: Dictionary = brain.buffered_attack_input_data
		#match attack_input_data.type:
			#PlayerBrain.AttackType.SPL:
				#if can_gnd_atk():
					#brain.reset_attack_buffer()
					#if attack_input_data.method == PlayerBrain.InputMethod.DIR && attack_input_data.input == PlayerBrain.AttackInput.BAK:
						#brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
				#elif can_air_atk():
					#brain.reset_attack_buffer()
					#if attack_input_data.method == PlayerBrain.InputMethod.DIR && attack_input_data.input == PlayerBrain.AttackInput.BAK:
						#brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
					#change_state(get_special(PlayerBrain.SpecialVariant.AIR, attack_input_data.input))
					
	#if brain.grab_buffer > 0.0 && can_grab():
			#brain.grab_buffer = 0.0
			#if (state == states.WLK && substate != get_substates().SRT) || (state == states.IDL && substate == get_substates().STP):
				#change_state(states.GRB_DSH)
				#return 
			#else:
				#change_state(states.GRB_IDL)
				#return
	
	match state:
		states.IDL:
			if input_jump(): return 
			if input_dash(): return
			if brain.attack_buffer > 0.0:
				if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
					if input_attack(
						get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.NTL),
						get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.FWD),
						get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.BAK)
						): return
				else:
					if input_attack(
						states.ATK_LT1,
						states.ATK_FWC,
						states.ATK_UPC
						): return
			if input_guard(): return
			if input_dodge(): return
			match substate:
				substates.IDL:
					if substate_start():
						brain.play_anim(&"Idl", true, Animation.LOOP_LINEAR)
					brain.walk(
						Vector3.ZERO,
						data.walk_speed,
						0.0,
						data.get_walk_decel_amount(),
						delta
						)
					if brain.move_input.length() > PlayerInput.DEADZONE:
						brain.update_facing_dir(brain.move_input)
						if brain.is_turning:
							change_substate(substates.TRN)
						else:
							change_state(states.WLK, "SRT")
				substates.TRN:
					if substate_start():
						brain.play_anim(&"Trn", true)
					brain.walk(
						brain.move_input,
						data.walk_start_speed,
						PlayerData.get_accel_amount(
							data.walk_start_acceleration,
							data.walk_start_speed
							),
						data.get_walk_decel_amount(),
						delta
						)
					if brain.sub_frame >= data.turn_idle_frames:
						if brain.move_input.length() > PlayerInput.DEADZONE:
							brain.update_facing_dir(brain.move_input)
							if brain.is_turning:
								change_substate(substates.TRN)
							else:
								change_state(states.WLK, "SRT")
						else:
							brain.velocity.x = 0.0
							brain.velocity.z = 0.0
							change_substate(substates.IDL)
				substates.STP:
					if substate_start():
						brain.play_anim(&"Stp", true, Animation.LOOP_NONE)
					brain.walk(
						Vector3.ZERO,
						data.walk_speed,
						0.0,
						data.get_walk_decel_amount(),
						delta
						)
					if brain.move_input.length() > PlayerInput.DEADZONE:
						brain.update_facing_dir(brain.move_input)
						if brain.is_turning:
							change_state(states.WLK, "TRN")
						else:
							change_state(states.WLK, "SRT")
						return
					if brain.sub_frame >= data.walk_stop_frames:
						brain.velocity.x = 0.0
						brain.velocity.z = 0.0
						if brain.sub_frame >= brain.anim_player.current_animation_length*Globals.FPS:
							change_substate(substates.IDL)
		states.WLK:
			if input_jump(): return
			if input_dash(): return
			if brain.attack_buffer > 0.0:
				if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
					if input_attack(
						get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.NTL),
						get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.FWD),
						get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.BAK)
						): return
				else:
					if input_attack(
						states.ATK_LT1,
						states.ATK_FWC,
						states.ATK_UPC
						): return
			if input_guard(): return
			if input_dodge(): return
			match substate:
				substates.SRT:
					if substate_start():
						brain.play_section(&"Wlk", &"StartStart", &"StartEnd")
					brain.walk(
						brain.move_input,
						data.walk_start_speed,
						PlayerData.get_accel_amount(
							data.walk_start_acceleration,
							data.walk_start_speed
							),
						data.get_walk_decel_amount(),
						delta
						)
					if brain.move_input.length() <= PlayerInput.DEADZONE:
						brain.velocity.x = 0.0
						brain.velocity.z = 0.0
						change_state(states.IDL, "IDL")
						return
					brain.update_facing_dir(brain.move_input)
					if brain.is_turning:
						change_state(states.IDL, "TRN")
						return
					if brain.sub_frame >= data.walk_startup_frames:
						change_substate(substates.WLK)
						return
				substates.WLK:
					if substate_start():
						brain.play_section(&"Wlk", &"Loop", &"", false, Animation.LOOP_LINEAR)
					brain.walk(
						brain.move_input,
						data.walk_speed,
						data.get_walk_accel_amount(),
						data.get_walk_decel_amount(),
						delta
						)
					if brain.move_input.length() > PlayerInput.DEADZONE:
						brain.update_facing_dir(brain.move_input)
						if brain.is_turning:
							change_substate(substates.TRN)
							return
					else:
						change_state(states.IDL, "STP")
						return
				substates.TRN:
					if substate_start():
						brain.play_anim(&"Pvt")
					brain.walk(
						brain.move_input,
						data.walk_start_speed,
						PlayerData.get_accel_amount(
							data.walk_start_acceleration,
							data.walk_start_speed
							),
						data.get_walk_decel_amount(),
						delta
						)
					if brain.sub_frame >= data.turn_walk_frames:
						if brain.move_input.length() <= PlayerInput.DEADZONE:
							change_state(states.IDL, "IDL")
						else:
							change_state(states.WLK, "SRT")
		states.JMP_SQT:
			brain.walk(
				Vector3.ZERO,
				data.walk_speed,
				0.0,
				PlayerData.get_accel_amount(
					data.jump_squat_deceleration,
					data.walk_speed
					),
				delta
				)
			if brain.frame >= 3.0:
				if brain.dash_buffer > 0.0 && brain.air_act_refreshed:
					brain.dash_buffer = 0.0
					brain.jump(data.get_short_jump_force())
					change_state(states.AIR_ACT)
					return
				if brain.attack_buffer > 0.0:
					if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
						if input_attack(
							get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.NTL),
							get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.FWD),
							get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.BAK)
							): return
					else:
						if input_attack(
							states.ATK_ARN,
							states.ATK_ARF,
							states.ATK_ARU
							): return
				if brain.grab_buffer > 0.0:
					brain.grab_buffer = 0.0
					brain.jump(data.get_short_jump_force())
					change_state(states.AIR, "JMP_SHT")
					return
				brain.jump(data.get_full_jump_force())
				change_state(states.AIR, "JMP_FUL")
				return
		states.AIR:
			if brain.move_input.length() > PlayerInput.DEADZONE:
				brain.update_facing_dir(brain.move_input)
			brain.walk(
				brain.move_input,
				data.air_speed,
				data.get_air_accel_amount(),
				data.get_air_decel_amount(),
				delta
				)
			if substate != substates.FAL_FRE:
				if (brain.jump_buffer > 0.0 || brain.dash_buffer > 0.0) && brain.air_act_refreshed:
					brain.jump_buffer = 0.0
					brain.dash_buffer = 0.0
					change_state(states.AIR_ACT)
					return
				if brain.attack_buffer > 0.0:
					if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
						if input_attack(
							get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.NTL),
							get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.FWD),
							get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.BAK)
							): return
					else:
						if input_attack(
							states.ATK_ARN,
							states.ATK_ARF,
							states.ATK_ARU
							): return
			input_fast_fall()
			match substate:
				substates.JMP_SHT:
					brain.apply_gravity(
						delta,
						data.get_short_jump_gravity()
						)
					if brain.is_on_floor() && brain.frame >= 3.0:
						brain.land()
						return
					if substate_start():
						brain.play_section(&"Jmp", &"", &"Loop", true, Animation.LOOP_LINEAR)
					elif brain.sub_frame == data.jump_short_frames_to_peak:
						brain.play_section(&"Jmp", &"Apex", &"", true, Animation.LOOP_NONE)
					if brain.velocity.y <= 0.0:
						change_substate(substates.FAL_NRM)
				substates.JMP_FUL:
					brain.apply_gravity(
						delta,
						data.get_full_jump_gravity()
						)
					if brain.is_on_floor() && brain.frame >= 3.0:
						brain.land()
						return
					if substate_start():
						brain.play_section(&"Jmp", &"", &"Loop", true, Animation.LOOP_LINEAR)
					elif brain.sub_frame == data.jump_short_frames_to_peak:
						brain.play_section(&"Jmp", &"Apex", &"", true, Animation.LOOP_NONE)
					if brain.velocity.y <= 0.0:
						change_substate(substates.FAL_NRM)
				substates.FAL_NRM:
					if substate_start():
						brain.play_anim(&"FalNrm", true, Animation.LOOP_LINEAR)
					brain.apply_gravity(
						delta,
						data.get_fast_fall_gravity() if brain.fast_falling else data.get_fall_gravity(),
						data.fall_fast_max_speed if brain.fast_falling else data.fall_fast_max_speed
						)
					if brain.is_on_floor():
						brain.land()
						return
				substates.FAL_FRE:
					if substate_start():
						brain.play_anim(&"FalFre", true, Animation.LOOP_LINEAR)
					brain.apply_gravity(
						delta,
						data.get_fast_fall_gravity() if brain.fast_falling else data.get_fall_gravity(),
						data.fall_fast_max_speed if brain.fast_falling else data.fall_fast_max_speed
						)
					if brain.is_on_floor():
						brain.land(data.land_hard_lag)
						return
		states.AIR_ACT:
			data.mov_mob_air.update(delta)
		states.LND:
			brain.walk(Vector3.ZERO, data.walk_speed, 0.0, brain.land_decel, delta)
			if brain.frame >= brain.land_lag:
				if brain.frame == brain.land_lag:
					brain.play_section(&"Lnd", &"End", &"")
				if input_jump(): return
				if input_dash(): return
				if brain.attack_buffer > 0.0:
					if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
						if input_attack(
							get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.NTL),
							get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.FWD),
							get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.BAK)
							): return
					else:
						if input_attack(
							states.ATK_LT1,
							states.ATK_FWC,
							states.ATK_UPC
							): return
				if input_guard(): return
				if input_dodge(): return
				if brain.move_input.length() > PlayerInput.DEADZONE:
					brain.update_facing_dir(brain.move_input)
					if brain.is_turning:
						change_state(states.WLK, "TRN")
					else:
						change_state(states.WLK, "SRT")
					return
				if brain.frame >= brain.land_lag+3.0:
					change_state(states.IDL, "IDL")
					return
		states.DSH:
			data.mov_mob_dsh.update(delta)
		states.GRD:
			if brain.frame <= 2.0:
				if brain.dodge_dir_buffer > 0.0 && brain.move_input_raw.length() > PlayerInput.DEADZONE:
					change_state(states.DGE_GND)
					return
			data.mov_def_grd.update(delta)
		states.HEL:
			match substate:
				substates.SRT:
					if brain.sub_frame >= data.heal_startup_frames:
						#brain.play_anim("HelLoop")
						change_substate(substates.ACT)
					return
				substates.ACT:
					brain.health += data.heal_hp_rate*delta
					brain.hgauge += data.heal_hg_rate*delta
					if brain.sub_frame >= 20.0:
						if !Input.is_action_pressed(&"Guard"):
							#brain.play_anim("HelEnd")
							change_substate(substates.END)
					return
				substates.END:
					if brain.sub_frame >= data.heal_endlag_frames:
						change_state(states.IDL, "IDL")
					return
		states.DGE_GND:
			data.mov_dge_gnd.update(delta)
		states.ATK_LT1:
			if brain.frame <= 2.0:
				if input_jump():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.NTL)
					return
				if input_dash():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.NTL)
					return
			data.atk_lt1.update(delta)
		states.ATK_LT2:
			if brain.frame <= 2.0:
				if input_jump():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.NTL)
					return
				if input_dash():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.NTL)
					return
			data.atk_lt2.update(delta)
		states.ATK_LT3:
			if brain.frame <= 2.0:
				if input_jump():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.NTL)
					return
				if input_dash():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.NTL)
					return
			data.atk_lt3.update(delta)
		states.ATK_FWC:
			brain.apply_gravity(delta, data.get_fall_gravity())
			brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
			if brain.frame <= 2.0:
				if input_jump():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.FWD)
					return
				if input_dash():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.FWD)
					return
			var released: bool
			match state_data.input_method:
				PlayerBrain.InputMethod.DIR:
					released = !Input.is_action_pressed(&"Attack")
				PlayerBrain.InputMethod.STK:
					released = brain.atk_stk_input_raw.length() <= PlayerInput.DEADZONE
			if released:
				if brain.frame <= 7.0:
					change_state(states.ATK_FWT, "BASE", {aim = state_data.dir})
				else:
					change_state(states.ATK_FWH, "BASE", {aim = state_data.dir, charge = 1.0})
				return
			if brain.frame >= 60.0:
				change_state(states.ATK_FWH, "BASE", {aim = state_data.dir, charge = 1.0})
				return
		states.ATK_FWT:
			data.atk_fwd_tap.update(delta)
		states.ATK_FWH:
			data.atk_fwd_hld.update(delta)
		states.ATK_UPC:
			brain.apply_gravity(delta, data.get_fall_gravity())
			brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
			if brain.frame <= 2.0:
				if input_jump():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.BAK)
					return
				if input_dash():
					brain.on_attack_press(PlayerBrain.AttackType.NML, PlayerBrain.AttackInput.BAK)
					return
			var released: bool
			match state_data.input_method:
				PlayerBrain.InputMethod.DIR:
					released = !Input.is_action_pressed(&"Attack")
				PlayerBrain.InputMethod.STK:
					released = brain.atk_stk_input_raw.length() <= PlayerInput.DEADZONE
			if released:
				if brain.frame <= 7.0:
					change_state(states.ATK_UPT)
				else:
					change_state(states.ATK_UPH, "BASE", {charge = 1.0})
				return
			if brain.frame >= 60.0:
				change_state(states.ATK_UPH, "BASE", {charge = 1.0})
				return
		states.ATK_UPT:
			data.atk_upr_tap.update(delta)
		states.ATK_UPH:
			data.atk_upr_hld.update(delta)
		states.ATK_DSN:
			data.atk_dsh_ntl.update(delta)
		states.ATK_DSF:
			data.atk_dsh_fwd.update(delta)
		states.ATK_DSU:
			data.atk_dsh_upr.update(delta)
		states.ATK_ARN:
			data.atk_air_ntl.update(delta)
		states.ATK_ARF:
			data.atk_air_fwd.update(delta)
		states.ATK_ARU:
			data.atk_air_upr.update(delta)
		states.ATK_ARA:
			data.atk_air_act.update(delta)
		states.ATK_DNK:
			data.atk_air_dnk.update(delta)
		states.GRB_IDL:
			data.grb_idl.update(delta)
		states.GRB_DSH:
			data.grb_dsh.update(delta)
		states.GRB_PVT:
			data.grb_pvt.update(delta)
		states.GRB_HLD:
			if brain.grab_target == null:
				change_state(states.IDL)
			match substate:
				substates.IDL:
					if brain.attack_buffer > 0.0:
						brain.reset_attack_buffer()
						change_substate(substates.PML)
						return
					var left: float = float(Input.is_action_just_pressed(&"MoveLeft"))
					var right: float = float(Input.is_action_just_pressed(&"MoveRight"))
					var up: float = float(Input.is_action_just_pressed(&"MoveUp"))
					var down: float = float(Input.is_action_just_pressed(&"MoveDown"))
					var throw_dir: Vector2 = PlayerBrain.get_joy_input(Vector2(right-left, down-up).normalized())
					if throw_dir.x == -brain.local_flip_h:
						change_state(states.THW_BAK)
					elif throw_dir.length() > PlayerInput.DEADZONE:
						change_state(states.THW_FWD)
					elif brain.jump_buffer > 0.0:
						brain.jump_buffer = 0.0
						change_state(states.THW_UPR)
					elif brain.guard_buffer > 0.0:
						brain.guard_buffer = 0.0
						change_state(states.THW_DWN)
				substates.PML:
					brain.atk_pml_update(delta)
				substates.RLS:
					change_state(states.IDL)
		states.THW_FWD:
			data.thw_fwd.update(delta)
		states.THW_BAK:
			data.thw_bak.update(delta)
		states.THW_UPR:
			data.thw_upr.update(delta)
		states.THW_DWN:
			data.thw_dwn.update(delta)
		states.SHT_NTL:
			data.sht_gnd_ntl.update(delta)
		states.SHT_FWD:
			data.sht_gnd_fwd.update(delta)
		states.SHT_UPR:
			data.sht_gnd_upr.update(delta)
		states.SHT_ARN:
			data.sht_air_ntl.update(delta)
		states.SHT_ARF:
			data.sht_air_fwd.update(delta)
		states.SHT_ARU:
			data.sht_air_upr.update(delta)
		states.PWR_NTL:
			data.pwr_gnd_ntl.update(delta)
		states.PWR_FWD:
			data.pwr_gnd_fwd.update(delta)
		states.PWR_UPR:
			data.pwr_gnd_upr.update(delta)
		states.PWR_ARN:
			data.pwr_air_ntl.update(delta)
		states.PWR_ARF:
			data.pwr_air_fwd.update(delta)
		states.PWR_ARU:
			data.pwr_air_upr.update(delta)
		states.TRP_NTL:
			data.trp_ntl.update(delta)
		states.TRP_FWD:
			data.trp_fwd.update(delta)
		states.TRP_UPR:
			data.trp_upr.update(delta)
		states.TRP_ARN:
			data.trp_air_ntl.update(delta)
		states.TRP_ARF:
			data.trp_air_fwd.update(delta)
		states.TRP_ARU:
			data.trp_air_upr.update(delta)
		states.CHS:
			chase_pos.x = brain.chase_target.get_center().x
			chase_pos.z = brain.chase_target.get_center().z
			var target_pos: Vector3 = chase_pos-Basis(Vector3.UP, brain.chase_target.global_facing_dir).x
			if brain.attack_buffer > 0.0:
				brain.reset_attack_buffer()
				change_state(states.ATK_DNK)
				return
			if brain.chase(target_pos):
				brain.velocity = Vector3.ZERO
				brain.chase_target = null
				brain.chase_window = 0.0
				chase_pos = Vector3.ZERO
				change_state(states.AIR, "FAL_FRE")
		states.STN_HIT:
			if !brain.is_on_floor():
				brain.apply_gravity(delta, data.get_fall_gravity(), data.fall_max_speed)
			if Vector2(brain.velocity.x, brain.velocity.z).length() <= 1.0:
				brain.velocity.x = 0.0
				brain.velocity.z = 0.0
			else:
				brain.velocity.x *= PlayerBrain.STUN_KB_DECAY
				brain.velocity.z *= PlayerBrain.STUN_KB_DECAY
			if brain.frame >= brain.stun+5.0:
				if brain.is_on_floor():
					change_state(states.IDL, "IDL")
				else:
					change_state(states.AIR, "FAL_NRM")
				return
			elif brain.frame >= brain.stun:
				if brain.frame == brain.stun:
					brain.play_section(&"StnHit", &"End", &"", true)
				if brain.frame >= brain.stun+5.0:
					change_state(states.IDL, "IDL")
					return
				if input_dodge(): return
				if brain.is_on_floor():
					if input_jump(): return 
					if input_dash(): return
					if brain.attack_buffer > 0.0:
						if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
							if input_attack(
								get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.NTL),
								get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.FWD),
								get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.BAK)
								): return
						else:
							if input_attack(
								states.ATK_LT1,
								states.ATK_FWC,
								states.ATK_UPC
								): return
					if input_guard(): return
				else:
					if brain.attack_buffer > 0.0:
						if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
							if input_attack(
								get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.NTL),
								get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.FWD),
								get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.BAK)
								): return
						else:
							if input_attack(
								states.ATK_ARN,
								states.ATK_ARF,
								states.ATK_ARU
								): return
		states.STN_BLK:
			pass
			#brain.velocity = brain.velocity.move_toward(Vector3.ZERO, 25.0*delta)
			#if brain.frame >= brain.stun:
				#change_state(states.IDL)
			#elif brain.frame >= brain.stun-5.0:
				#brain.play_anim("StnBlkEnd")
		states.STN_BRK:
			pass
		states.STN_GRB:
			var grab_holder: PlayerBrain = brain.grab_holder
			brain.move_center_to_point(grab_holder.grab_point.global_position)
			if grab_holder.sm.state == grab_holder.sm.states.GRB_HLD:
				var grab_decay: float = 0.1*floorf(delta*Globals.FPS)
				#TODO - Add mashing function
				brain.grabstun -= grab_decay
				if brain.grabstun <= 0.0:
					brain.grabstun = 0.0
					brain.grab_holder.grab_target = null
					brain.grab_holder = null
					brain.velocity = Vector3.ZERO
					change_state(states.AIR, "FAL_NRM")
		states.LNC_NML:
			if brain.frame >= brain.stun+3.0:
				change_state(states.AIR, "FAL_NRM")
			brain.apply_gravity(delta, PlayerData.get_gravity(brain.knockback.y, brain.stun))
			if brain.is_on_floor():
				brain.velocity.x *= 0.3
				brain.velocity.z *= 0.3
				brain.velocity.y = 5.0
				change_state(states.CRS_FLR)
				return
			if brain.is_on_wall():
				brain.velocity.x = brain.get_wall_normal().x*brain.knockback.x
				brain.velocity.z = brain.get_wall_normal().z*brain.knockback.z
		states.LNC_HVY:
			brain.chase_window = PlayerBrain.CHASE_WINDOW_FRAMES
			if brain.frame == 6.0:
				brain.play_section(&"StnHvy", &"Loop", &"", true, Animation.LoopMode.LOOP_LINEAR)
			if brain.is_on_wall():
				if round(brain.move_input) == round(brain.get_wall_normal()):
					change_state(states.TEC_WAL)
					return
				brain.health -= 15.0
				brain.chase_window = 0.0
				brain.chase_target = null
				brain.velocity = Vector3.ZERO
				brain.knockback = brain.get_wall_normal()*3.5
				brain.knockback.y = PlayerData.get_jump_force(6.25, 15.0)
				brain.update_facing_dir(-brain.get_wall_normal())
				change_state(states.CRS_WAL)
				return
			if brain.frame >= brain.stun-5.0:
				brain.velocity = brain.velocity.limit_length(brain.velocity.length()*0.75)
				if brain.frame >= brain.stun:
					if input_dodge(): return
					if brain.is_on_floor():
						if input_jump(): return 
						if input_dash(): return
						if brain.attack_buffer > 0.0:
							if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
								if input_attack(
									get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.NTL),
									get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.FWD),
									get_special(PlayerBrain.SpecialVariant.GND, PlayerBrain.AttackInput.BAK)
									): return
							else:
								if input_attack(
									states.ATK_LT1,
									states.ATK_FWC,
									states.ATK_UPC
									): return
						if input_guard(): return
					else:
						if brain.attack_buffer > 0.0:
							if brain.buffered_attack_input_data.type == PlayerBrain.AttackType.SPL:
								if input_attack(
									get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.NTL),
									get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.FWD),
									get_special(PlayerBrain.SpecialVariant.AIR, PlayerBrain.AttackInput.BAK)
									): return
							else:
								if input_attack(
									states.ATK_ARN,
									states.ATK_ARF,
									states.ATK_ARU
									): return
				if brain.frame >= brain.stun+15.0:
					change_state(states.AIR, "FAL_NRM")
					return
		states.LNC_UPR:
			if brain.frame >= brain.stun:
				change_state(states.AIR, "FAL_NRM")
			if brain.frame == brain.stun-8.0:
				brain.play_section(&"StnUpr", &"Apex", &"", true)
			brain.apply_gravity(delta, PlayerData.get_gravity(brain.knockback.y, brain.stun))
		states.LNC_DNK:
			match substate:
				substates.IMP:
					if brain.is_on_floor():
						brain.velocity = brain.get_floor_normal()*absf(brain.knockback.length()*0.5)
						change_substate(substates.CRS)
				substates.CRS:
					brain.apply_gravity(delta, -absf(brain.knockback.y))
					if brain.is_on_floor():
						var floor_normal: Vector3 = brain.get_floor_normal()
						if Vector2(floor_normal.x, floor_normal.z).length() > 0.1:
							brain.velocity.x = floor_normal.x*5.0
							brain.velocity.z = floor_normal.z*5.0
							brain.velocity.y = 5.0
						else:
							brain.velocity = Vector3(-5.0*cos(brain.global_facing_dir), 5.0, -5.0*sin(brain.global_facing_dir))
						change_state(states.CRS_FLR)
		states.CRS_WAL:
			if brain.frame == 15.0:
				brain.velocity = brain.knockback
				brain.play_section(&"CrsWal", &"Apex", &"")
			elif brain.frame > 15.0:
				if brain.velocity.y > 0.0:
					brain.apply_gravity(delta, -60.0)
				elif absf(brain.velocity.y) <= 5.0:
					brain.apply_gravity(delta, -30.0)
				else:
					brain.apply_gravity(delta, -90.0)
				brain.velocity.x *= exp(-0.95*delta)
				brain.velocity.z *= exp(-0.95*delta)
				
				if brain.is_on_floor():
					brain.velocity = Vector3(-6.0*cos(brain.global_facing_dir), 5.0, 6.0*sin(brain.global_facing_dir))
					change_state(states.CRS_FLR)
		states.CRS_FLR:
			brain.apply_gravity(delta, -40.0)
			if brain.is_on_floor():
				change_state(states.FNT)
		states.TEC_NTL:
			pass
		states.TEC_FWD:
			pass
		states.TEC_BAK:
			pass
		states.TEC_WAL:
			if brain.frame >= 10.0:
				if input_chase():
					change_state(states.CHS)
					chase_pos.y = brain.global_position.y+7.0
					return
				else:
					change_state(states.AIR, "FAL_NRM")
		states.FNT:
			if brain.frame >= 180.0:
				change_state(states.GTP_NTL)
			elif brain.frame >= 40.0:
				if brain.jump_buffer > 0.0:
					brain.jump_buffer = 0.0
					change_state(states.GTP_NTL)
				elif brain.move_input.length() >= PlayerInput.DEADZONE:
					if brain.global_facing_dir_h == -brain.move_input.x:
						change_state(states.GTP_BAK)
					else:
						change_state(states.GTP_FWD)
				elif brain.attack_buffer > 0.0:
					brain.reset_attack_buffer()
					change_state(states.GTP_ATK)
		states.GTP_NTL:
			if brain.frame >= 27.0:
				change_state(states.IDL, "IDL")
		states.GTP_ATK:
			pass
		states.GTP_FWD:
			pass
		states.GTP_BAK:
			pass

func enter_state(new_state: int, old_state: int) -> void:
	brain.reset_frames()
	match new_state:
		states.IDL:
			pass
		states.WLK:
			pass
		states.DSH:
			data.mov_mob_dsh.start(old_state)
		states.JMP_SQT:
			brain.play_anim(&"JmpSqt", true)
		states.AIR:
			pass
		states.AIR_ACT:
			data.mov_mob_air.start(old_state)
		states.LND:
			brain.play_section(&"Lnd", &"", &"Land")
		states.GRD:
			data.mov_def_grd.start(old_state)
		states.HEL:
			brain.play_section(&"Hel", &"Startup", &"LoopStart")
		states.DGE_GND:
			brain.dodge_input = brain.input_raw_to_world(brain.last_move_input_raw)
			brain.update_facing_dir(brain.dodge_input)
			data.mov_dge_gnd.start(old_state)
		states.DGE_AIR:
			data.mov_dge_air.start(old_state)
		states.ATK_LT1:
			data.atk_lt1.start(old_state)
		states.ATK_LT2:
			data.atk_lt2.start(old_state)
		states.ATK_LT3:
			data.atk_lt3.start(old_state)
		states.ATK_FWC:
			brain.play_anim(&"AtkFwC", true, Animation.LOOP_NONE)
		states.ATK_FWT:
			data.atk_fwd_tap.start(old_state)
		states.ATK_FWH:
			data.atk_fwd_hld.start(old_state)
		states.ATK_UPC:
			brain.play_anim(&"AtkUpC", true, Animation.LOOP_NONE)
		states.ATK_UPT:
			data.atk_upr_tap.start(old_state)
		states.ATK_UPH:
			data.atk_upr_hld.start(old_state)
		states.ATK_ARN:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			data.atk_air_ntl.start(old_state)
		states.ATK_ARF:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			data.atk_air_fwd.start(old_state)
		states.ATK_ARU:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			data.atk_air_upr.start(old_state)
		states.ATK_ARA:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			data.atk_air_act.start(old_state)
		states.ATK_DSN:
			data.atk_dsh_ntl.start(old_state)
		states.ATK_DSF:
			data.atk_dsh_fwd.start(old_state)
		states.ATK_DSU:
			data.atk_dsh_upr.start(old_state)
		states.ATK_DNK:
			brain.chase_target = null
			brain.chase_window = 0.0
			data.atk_air_dnk.start(old_state)
		states.GRB_IDL:
			data.grb_idl.start(old_state)
		states.GRB_DSH:
			data.grb_dsh.start(old_state)
		states.GRB_HLD:
			brain.play_anim("GrbHld")
		states.THW_FWD:
			data.thw_fwd.start(old_state)
		states.THW_BAK:
			data.thw_bak.start(old_state)
		states.THW_UPR:
			data.thw_upr.start(old_state)
		states.THW_DWN:
			data.thw_dwn.start(old_state)
		states.SHT_NTL:
			data.sht_gnd_ntl.start(old_state)
		states.SHT_FWD:
			data.sht_gnd_fwd.start(old_state)
		states.SHT_UPR:
			data.sht_gnd_upr.start(old_state)
		states.SHT_ARN:
			data.sht_air_ntl.start(old_state)
		states.SHT_ARF:
			data.sht_air_fwd.start(old_state)
		states.SHT_ARU:
			data.sht_air_upr.start(old_state)
		states.PWR_NTL:
			data.pwr_gnd_ntl.start(old_state)
		states.PWR_FWD:
			data.pwr_gnd_fwd.start(old_state)
		states.PWR_UPR:
			data.pwr_gnd_upr.start(old_state)
		states.PWR_ARN:
			data.pwr_air_ntl.start(old_state)
		states.PWR_ARF:
			data.pwr_air_fwd.start(old_state)
		states.PWR_ARU:
			data.pwr_air_upr.start(old_state)
		states.TRP_NTL:
			data.trp_gnd_ntl.start(old_state)
		states.TRP_FWD:
			data.trp_gnd_fwd.start(old_state)
		states.TRP_UPR:
			data.trp_gnd_upr.start(old_state)
		states.TRP_ARN:
			data.trp_air_ntl.start(old_state)
		states.TRP_ARF:
			data.trp_air_fwd.start(old_state)
		states.TRP_ARU:
			data.trp_air_upr.start(old_state)
		states.CHS:
			brain.play_anim(&"Chs", true, Animation.LOOP_NONE)
		states.STN_HIT:
			brain.play_section(&"StnHit", &"", &"Stun", true)
			if !brain.is_on_floor():
				if brain.knockback.y == 0.0:
					brain.velocity.y = 12.0
		states.STN_BLK:
			brain.play_anim(&"StnBlk", true)
		states.STN_BRK:
			#brain.play_anim("StnBrk", true)
			brain.play_anim(&"StnBlk", true)
		states.STN_GRB:
			#brain.play_anim("StnGrb", true)
			brain.play_section(&"StnHit", &"", &"Stun", true)
			brain.velocity = Vector3.ZERO
		states.LNC_NML:
			brain.play_section(&"StnHit", &"", &"Stun", true)
		states.LNC_HVY:
			brain.play_section(&"StnHvy", &"", &"Loop", true, Animation.LoopMode.LOOP_NONE)
		states.LNC_UPR:
			brain.play_section(&"StnUpr", &"", &"Loop", true, Animation.LOOP_LINEAR)
		states.LNC_DNK:
			brain.play_section(&"StnHit", &"", &"Stun", true)
		states.CRS_WAL:
			brain.play_section(&"CrsWal", &"", &"Loop", true, Animation.LOOP_LINEAR)
		states.CRS_FLR:
			brain.play_anim(&"CrsFlr", true)
		states.TEC_NTL:
			brain.play_anim(&"TecNtl")
		states.TEC_FWD:
			brain.play_anim(&"TecFlr")
		states.TEC_BAK:
			brain.play_anim(&"TecBak")
		states.TEC_WAL:
			brain.play_anim(&"TecWal")
		states.FNT:
			brain.velocity.x = 0.0
			brain.velocity.z = 0.0
			brain.play_anim(&"Fnt")
		states.GTP_NTL:
			brain.play_anim(&"GtpNtl")
		states.GTP_FWD:
			brain.play_anim(&"GtpFwd")
		states.GTP_BAK:
			brain.play_anim(&"GtpBak")

func exit_state(old_state: int, new_state: int) -> void:
	#TODO - Rearrange states
	match old_state:
		states.IDL:
			pass
		states.WLK:
			pass
		states.DSH:
			data.mov_mob_dsh.end(new_state)
		states.JMP_SQT:
			pass
		states.AIR:
			if new_state == states.LND: brain.fast_falling = false
		states.AIR_ACT:
			if new_state == states.LND: brain.fast_falling = false
			data.mov_mob_air.end(new_state)
		states.LND:
			pass
		states.GRD:
			data.mov_def_grd.end(new_state)
		states.HEL:
			pass
		states.DGE_GND:
			data.mov_dge_gnd.end(new_state)
		states.DGE_AIR:
			if new_state == states.LND:
				brain.fast_falling = false
			data.mov_dge_air.end(new_state)
		states.ATK_LT1:
			reset_jab(new_state)
			data.atk_lt1.end(new_state)
		states.ATK_LT2:
			reset_jab(new_state)
			data.atk_lt2.end(new_state)
		states.ATK_LT3:
			reset_jab(new_state)
			data.atk_lt3.end(new_state)
		states.ATK_FWC:
			pass
		states.ATK_FWT:
			data.atk_fwd_tap.end(new_state)
		states.ATK_FWH:
			data.atk_fwd_hld.end(new_state)
		states.ATK_UPC:
			pass
		states.ATK_UPT:
			data.atk_upr_tap.end(new_state)
		states.ATK_UPH:
			data.atk_upr_hld.end(new_state)
		states.ATK_DSN:
			data.atk_dsh_ntl.end(new_state)
		states.ATK_DSF:
			data.atk_dsh_fwd.end(new_state)
		states.ATK_DSU:
			data.atk_dsh_upr.end(new_state)
		states.ATK_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			data.atk_air_ntl.end(new_state)
		states.ATK_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			data.atk_air_fwd.end(new_state)
		states.ATK_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			data.atk_air_upr.end(new_state)
		states.ATK_ARA:
			if new_state == states.LND:
				brain.fast_falling = false
			data.atk_air_act.end(new_state)
		states.ATK_DNK:
			if new_state == states.LND:
				brain.fast_falling = false
			data.atk_air_dnk.end(new_state)
		states.GRB_IDL:
			data.grb_idl.end(new_state)
		states.GRB_DSH:
			data.grb_dsh.end(new_state)
		states.GRB_PVT:
			data.grb_pvt.end(new_state)
		states.GRB_HLD:
			if ![states.THW_FWD, states.THW_BAK, states.THW_UPR, states.THW_DWN].has(new_state):
				if brain.grab_target != null:
					brain.grab_target.sm.change_state(brain.grab_target.sm.states.AIR, "FAL_NRM")
					brain.grab_target.velocity = Vector3.ZERO
					brain.grab_target.grab_holder = null
					brain.grab_target = null
		states.THW_FWD:
			data.thw_fwd.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.THW_BAK:
			data.thw_bak.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.THW_UPR:
			data.thw_upr.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.THW_DWN:
			data.thw_dwn.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.SHT_NTL:
			data.sht_ntl.end(new_state)
		states.SHT_FWD:
			data.sht_fwd.end(new_state)
		states.SHT_UPR:
			data.sht_upr.end(new_state)
		states.SHT_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			data.sht_air_ntl.end(new_state)
		states.SHT_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			data.sht_air_fwd.end(new_state)
		states.SHT_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			data.sht_air_upr.end(new_state)
		states.PWR_NTL:
			data.pwr_gnd_ntl.end(new_state)
		states.PWR_FWD:
			data.pwr_gnd_fwd.end(new_state)
		states.PWR_UPR:
			data.pwr_gnd_upr.end(new_state)
		states.PWR_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			data.pwr_air_ntl.end(new_state)
		states.PWR_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			data.pwr_air_fwd.end(new_state)
		states.PWR_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			data.pwr_air_upr.end(new_state)
		states.TRP_NTL:
			data.trp_ntl.end(new_state)
		states.TRP_FWD:
			data.trp_fwd.end(new_state)
		states.TRP_UPR:
			data.trp_upr.end(new_state)
		states.TRP_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			data.trp_air_ntl.end(new_state)
		states.TRP_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			data.trp_air_fwd.end(new_state)
		states.TRP_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			data.trp_air_upr.end(new_state)
		states.CHS:
			pass
		states.STN_HIT:
			pass
		states.STN_BLK:
			pass
		states.STN_BRK:
			pass
		states.STN_GRB:
			brain.collbox.set_deferred("disabled", false)
		states.LNC_NML:
			pass
		states.LNC_HVY:
			pass
		states.LNC_UPR:
			pass
		states.LNC_DNK:
			pass
		states.CRS_WAL:
			pass
		states.CRS_FLR:
			pass
		states.TEC_NTL:
			pass
		states.TEC_FWD:
			pass
		states.TEC_BAK:
			pass
		states.TEC_WAL:
			pass
		states.FNT:
			pass
		states.GTP_NTL:
			pass
		states.GTP_FWD:
			pass
		states.GTP_BAK:
			pass
		states.GTP_ATK:
			pass

func change_substate(new_state: int) -> void:
	brain.sub_frame = 0.0
	substate = new_state

func substate_start() -> bool:
	return brain.sub_frame == 1.0

func reset_jab(new_state: int) -> void:
	if ![states.ATK_LT2, states.ATK_LT3].has(new_state):
		jab_count = 0

func falling() -> bool:
	return ![
		states.DSH,
		states.CHS,
		states.AIR,
		states.AIR_ACT,
		states.ATK_LT1,
		states.ATK_LT2,
		states.ATK_LT3,
		states.ATK_FWC,
		states.ATK_FWT,
		states.ATK_FWH,
		states.ATK_UPC,
		states.ATK_UPT,
		states.ATK_UPH,
		states.ATK_DSN,
		states.ATK_DSF,
		states.ATK_DSU,
		states.ATK_ARN,
		states.ATK_ARF,
		states.ATK_ARU,
		states.ATK_ARA,
		states.ATK_DNK,
		states.THW_FWD,
		states.THW_BAK,
		states.THW_UPR,
		states.THW_DWN,
		states.PWR_NTL,
		states.PWR_FWD,
		states.PWR_UPR,
		states.PWR_ARN,
		states.PWR_ARF,
		states.PWR_ARU,
		states.SHT_NTL,
		states.SHT_FWD,
		states.SHT_UPR,
		states.SHT_ARN,
		states.SHT_ARF,
		states.SHT_ARU,
		states.TRP_NTL,
		states.TRP_FWD,
		states.TRP_UPR,
		states.TRP_ARN,
		states.TRP_ARF,
		states.TRP_ARU,
		states.STN_HIT,
		states.STN_GRB,
		states.CRS_WAL,
		states.CRS_FLR,
		states.LNC_NML,
		states.LNC_HVY,
		states.LNC_UPR,
		states.LNC_DNK,
		states.FNT].has(state) && !brain.is_on_floor()

func attacking() -> Array:
	return [
	states.ATK_LT1,
	states.ATK_LT2,
	states.ATK_LT3,
	states.ATK_FWC,
	states.ATK_FWT,
	states.ATK_FWH,
	states.ATK_UPC,
	states.ATK_UPT,
	states.ATK_UPH,
	states.ATK_ARN,
	states.ATK_ARF,
	states.ATK_ARU,
	states.ATK_DSN,
	states.ATK_DSF,
	states.ATK_DSU,
	states.ATK_ARA,
	states.ATK_DNK,
	states.PWR_NTL,
	states.PWR_FWD,
	states.PWR_UPR,
	states.PWR_ARN,
	states.PWR_ARF,
	states.PWR_ARU,
	states.SHT_NTL,
	states.SHT_FWD,
	states.SHT_UPR,
	states.SHT_ARN,
	states.SHT_ARF,
	states.SHT_ARU,
	states.TRP_NTL,
	states.TRP_FWD,
	states.TRP_UPR,
	states.TRP_ARN,
	states.TRP_ARF,
	states.TRP_ARU,
	]

func can_chase() -> bool:
	if !(attacking()+[states.CHS, states.STN_HIT, states.STN_GRB, states.CRS_WAL, states.CRS_FLR, states.LNC_NML, states.LNC_HVY, states.LNC_UPR, states.LNC_DNK]).has(state):
		return input_chase()
	return false

func input_chase() -> bool:
	if brain.chase_target != null:
		if brain.move_input.length() > PlayerInput.DEADZONE:
			var self_pos: Vector2 = Vector2(brain.global_position.x, brain.global_position.z)
			var target_pos: Vector2 = Vector2(brain.chase_target.global_position.x, brain.chase_target.global_position.z)
			var target_angle: float = self_pos.angle_to_point(target_pos)
			var input_angle: float = Vector2(brain.move_input.x, brain.move_input.z).angle()
			return angle_difference(target_angle, input_angle) <= 45.0*Globals.ANGLE_CONVERSION
	return false

func input_jump() -> bool:
	if brain.jump_buffer > 0.0:
		brain.jump_buffer = 0.0
		change_state(states.JMP_SQT)
		return true
	return false

func input_dash() -> bool:
	if brain.dash_buffer > 0.0:
		brain.dash_buffer = 0.0
		change_state(states.DSH)
		return true
	return false

func input_attack(atk_ntl: int, atk_fwd: int, atk_upr: int, flip: bool = true) -> bool:
	var atk_data: Dictionary = {}
	if brain.attack_buffer > 0.0:
		var attack_input_data: Dictionary = brain.buffered_attack_input_data
		atk_data = {
			input_method = attack_input_data.method,
			dir = brain.get_kb_aim()
			}
		match attack_input_data.input:
			PlayerBrain.AttackInput.NTL:
				brain.reset_attack_buffer()
				change_state(atk_ntl, "BASE", atk_data if [states.ATK_FWC, states.ATK_UPC].has(atk_ntl) else {})
				return true
			PlayerBrain.AttackInput.FWD:
				brain.reset_attack_buffer()
				change_state(atk_fwd, "BASE", atk_data if [states.ATK_FWC, states.ATK_UPC].has(atk_fwd) else {})
				return true
			PlayerBrain.AttackInput.BAK:
				brain.reset_attack_buffer()
				if attack_input_data.method == PlayerBrain.InputMethod.DIR && flip:
					brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
				change_state(atk_upr, "BASE", atk_data if [states.ATK_FWC, states.ATK_UPC].has(atk_upr) else {})
				return true
	return false

func input_guard() -> bool:
	if brain.guard_buffer > 0.0:
		brain.guard_buffer = 0.0
		change_state(states.GRD)
		return true
	return false

func input_dodge(aerial: bool = false) -> bool:
	if brain.dodge_buffer > 0.0:
		brain.dodge_buffer = 0.0
		if aerial:
			change_state(states.DGE_AIR)
		else:
			change_state(states.DGE_GND)
		return true
	return false

func input_fast_fall() -> bool:
	if !brain.fast_falling:
		if brain.grab_buffer > 0.0 && brain.velocity.y <= 0.0:
			brain.grab_buffer = 0.0
			brain.fast_falling = true
			return true
	return false

func get_special(atk_var: PlayerBrain.SpecialVariant, atk_input: PlayerBrain.AttackInput) -> int:
	var specials: Dictionary[int, String] = {
		PlayerBrain.SpecialType.PWR: "PWR",
		PlayerBrain.SpecialType.SHT: "SHT",
		PlayerBrain.SpecialType.TRP: "TRP"
	}
	
	var inputs: Dictionary[int, String]
	var special: int
	
	match atk_var:
		PlayerBrain.SpecialVariant.GND:
			special = brain.ground_special
			inputs = {
				PlayerBrain.AttackInput.NTL: "_NTL",
				PlayerBrain.AttackInput.FWD: "_FWD",
				PlayerBrain.AttackInput.BAK: "_UPR"
			}
		
		PlayerBrain.SpecialVariant.AIR:
			special = brain.aerial_special
			inputs = {
				PlayerBrain.AttackInput.NTL: "_ARN",
				PlayerBrain.AttackInput.FWD: "_ARF",
				PlayerBrain.AttackInput.BAK: "_ARU"
			}
		
		PlayerBrain.SpecialVariant.DEF:
			special = brain.defense_special
			inputs = {
				PlayerBrain.AttackInput.NTL: "_DEF",
				PlayerBrain.AttackInput.FWD: "_DEF",
				PlayerBrain.AttackInput.BAK: "_DEF"
			}
	
	return states[specials[special]+inputs[atk_input]]
