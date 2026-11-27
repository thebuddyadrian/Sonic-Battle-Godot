class_name FighterStateMachine extends StateMachine


@onready var brain: FighterBrain = $".."


var jab_count: int = 0
var data: FighterData
var chase_pos: Vector3

var actions: Dictionary[String, FighterAction] = {}

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
	add_state("ATK_NT1")
	add_state("ATK_NT2")
	add_state("ATK_NT3")
	add_state("ATK_FWC")
	add_state("ATK_FWL")
	add_state("ATK_FWH")
	add_state("ATK_UPC")
	add_state("ATK_UPL")
	add_state("ATK_UPH")
	add_state("ATK_DSH")
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

func wake() -> void:
	for action_name in actions:
		actions[action_name].wake()

func global_state_update(delta: float) -> void:
	brain.update_freeze(delta)
	if brain.pause_dur == 0:
		brain.update(delta)

func state_update(delta: float) -> void:
	if brain.pause_dur > 0:
		return
	
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
			#FighterBrain.AttackType.SPL:
				#if can_gnd_atk():
					#brain.reset_attack_buffer()
					#if attack_input_data.method == FighterBrain.InputMethod.DIR && attack_input_data.input == FighterBrain.AttackInput.BAK:
						#brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
				#elif can_air_atk():
					#brain.reset_attack_buffer()
					#if attack_input_data.method == FighterBrain.InputMethod.DIR && attack_input_data.input == FighterBrain.AttackInput.BAK:
						#brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
					#change_state(get_special(FighterBrain.SpecialVariant.AIR, attack_input_data.input))
					
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
			#if input_dash(): return
			if brain.attack_buffer > 0:
				if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
					if input_attack(
						get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.NTL),
						get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.FWD),
						get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.BAK)
						): return
				else:
					if input_attack(
						states.ATK_NT1,
						states.ATK_FWC,
						states.ATK_UPC
						): return
			if input_guard(): return
			if input_dodge(): return
			var substates: Dictionary[String, int] = get_substates()
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
						FighterData.get_accel_amount(
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
						if brain.sub_frame >= brain.anim_player.get_animation("%s_anim_lib/Stp" % brain.fighter_name).length*Globals.FPS:
							change_substate(substates.IDL)
		states.WLK:
			if input_jump(): return
			#if input_dash(): return
			if brain.attack_buffer > 0:
				if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
					if input_attack(
						get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.NTL),
						get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.FWD),
						get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.BAK)
						): return
				else:
					if input_attack(
						states.ATK_NT1,
						states.ATK_FWC,
						states.ATK_UPC
						): return
			if input_guard(): return
			if input_dodge(): return
			var substates: Dictionary[String, int] = get_substates()
			match substate:
				substates.SRT:
					if substate_start():
						brain.play_section(&"Wlk", &"StartStart", &"StartEnd")
					brain.walk(
						brain.move_input,
						data.walk_start_speed,
						FighterData.get_accel_amount(
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
						FighterData.get_accel_amount(
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
				FighterData.get_accel_amount(
					data.jump_squat_deceleration,
					data.walk_speed
					),
				delta
				)
			if brain.frame >= 3:
				if brain.dash_buffer > 0:
					SyncManager.set_synced(brain, "dash_buffer", 0)
					brain.jump(data.get_short_jump_force())
					change_state(states.AIR_ACT)
					return
				if brain.attack_buffer > 0:
					if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
						if input_attack(
							get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.NTL),
							get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.FWD),
							get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.BAK)
							): return
					else:
						if input_attack(
							states.ATK_ARN,
							states.ATK_ARF,
							states.ATK_ARU
							): return
				if brain.grab_buffer > 0:
					SyncManager.set_synced(brain, "grab_buffer", 0)
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
			var substates: Dictionary[String, int] = get_substates()
			if substate != substates.FAL_FRE:
				if (brain.jump_buffer > 0 || brain.dash_buffer > 0):
					SyncManager.set_synced(brain, "jump_buffer", 0)
					SyncManager.set_synced(brain, "dash_buffer", 0)
					change_state(states.AIR_ACT)
					return
				if brain.attack_buffer > 0:
					if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
						if input_attack(
							get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.NTL),
							get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.FWD),
							get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.BAK)
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
					if brain.grounded && brain.frame >= 3:
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
					if brain.grounded && brain.frame >= 3:
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
					if brain.grounded:
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
					if brain.grounded:
						brain.land(data.land_hard_lag)
						return
		states.AIR_ACT:
			if actions.has('dsh_air'):
				actions.dsh_air.update(delta)
			else:
				change_state(states.IDL)
		states.LND:
			brain.walk(Vector3.ZERO, data.walk_speed, 0.0, brain.land_decel, delta)
			if brain.frame >= brain.land_lag:
				if brain.frame == brain.land_lag:
					brain.play_section(&"Lnd", &"End", &"")
				if input_jump(): return
				if input_dash(): return
				if brain.attack_buffer > 0:
					if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
						if input_attack(
							get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.NTL),
							get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.FWD),
							get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.BAK)
							): return
					else:
						if input_attack(
							states.ATK_NT1,
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
				if brain.frame >= brain.land_lag+3:
					change_state(states.IDL, "IDL")
					return
		states.DSH:
			if actions.has('dsh_gnd'):
				actions.dsh_gnd.update(delta)
			else:
				change_state(states.IDL)
		states.GRD:
			if brain.frame <= 2:
				if brain.dodge_dir_buffer > 0 && brain.move_input_raw.length() > PlayerInput.DEADZONE:
					change_state(states.DGE_GND)
					return
			if actions.has('def_grd'):
				actions.def_grd.update(delta)
			else:
				change_state(states.IDL)
		states.HEL:
			var substates: Dictionary[String, int] = get_substates()
			match substate:
				substates.SRT:
					if brain.sub_frame >= data.heal_startup_frames:
						#brain.play_anim("HelLoop")
						change_substate(substates.ACT)
					return
				substates.ACT:
					brain.health += data.heal_hp_rate*delta
					brain.hgauge += data.heal_hg_rate*delta
					if brain.sub_frame >= 20:
						if brain.local_input.get("guard", PlayerInput.ButtonState.NOT_PRESSED) == PlayerInput.ButtonState.NOT_PRESSED:
							#brain.play_anim("HelEnd")
							change_substate(substates.END)
					return
				substates.END:
					if brain.sub_frame >= data.heal_endlag_frames:
						change_state(states.IDL, "IDL")
					return
		states.DGE_GND:
			if actions.has('dge_gnd'):
				actions.dge_gnd.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_NT1:
			if brain.frame <= 2:
				if input_jump():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.NTL)
					return
				if input_dash():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.NTL)
					return
			if actions.has('atk_nt1'):
				actions.atk_nt1.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_NT2:
			if brain.frame <= 2:
				if input_jump():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.NTL)
					return
				if input_dash():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.NTL)
					return
			if actions.has('atk_nt2'):
				actions.atk_nt2.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_NT3:
			if brain.frame <= 2:
				if input_jump():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.NTL)
					return
				if input_dash():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.NTL)
					return
			if actions.has('atk_nt3'):
				actions.atk_nt3.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_FWC:
			brain.apply_gravity(delta, data.get_fall_gravity())
			brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
			if brain.frame <= 2:
				if input_jump():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.FWD)
					return
				if input_dash():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.FWD)
					return
			var released: bool
			match state_data.input_method:
				FighterBrain.InputMethod.DIR:
					released = brain.local_input.get("attack", PlayerInput.ButtonState.NOT_PRESSED) == PlayerInput.ButtonState.NOT_PRESSED
				FighterBrain.InputMethod.STK:
					released = brain.atk_stk_input_raw.length() <= PlayerInput.DEADZONE
			if released:
				if brain.frame <= 7:
					change_state(states.ATK_FWL, "BASE", {aim = state_data.dir})
				else:
					change_state(states.ATK_FWH, "BASE", {aim = state_data.dir, charge = 1.0})
				return
			if brain.frame >= 60:
				change_state(states.ATK_FWH, "BASE", {aim = state_data.dir, charge = 1.0})
				return
		states.ATK_FWL:
			if actions.has('atk_fwl'):
				actions.atk_fwl.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_FWH:
			if actions.has('atk_fwh'):
				actions.atk_fwh.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_UPC:
			brain.apply_gravity(delta, data.get_fall_gravity())
			brain.walk(Vector3.ZERO, data.walk_speed, 0.0, 80.0, delta)
			if brain.frame <= 2:
				if input_jump():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.BAK)
					return
				if input_dash():
					brain.on_attack_press(FighterBrain.AttackType.NML, FighterBrain.AttackInput.BAK)
					return
			var released: bool
			match state_data.input_method:
				FighterBrain.InputMethod.DIR:
					released = brain.local_input.get("attack", PlayerInput.ButtonState.NOT_PRESSED) == PlayerInput.ButtonState.NOT_PRESSED
				FighterBrain.InputMethod.STK:
					released = brain.atk_stk_input_raw.length() <= PlayerInput.DEADZONE
			if released:
				if brain.frame <= 7:
					change_state(states.ATK_UPL)
				else:
					change_state(states.ATK_UPH, "BASE", {charge = 1.0})
				return
			if brain.frame >= 60:
				change_state(states.ATK_UPH, "BASE", {charge = 1.0})
				return
		states.ATK_UPL:
			if actions.has('atk_upl'):
				actions.atk_upl.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_UPH:
			if actions.has('atk_uph'):
				actions.atk_uph.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_DSH:
			if actions.has('atk_dsh'):
				actions.atk_dsh.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_ARN:
			if actions.has('atk_arn'):
				actions.atk_arn.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_ARF:
			if actions.has('atk_arf'):
				actions.atk_arf.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_ARU:
			if actions.has('atk_aru'):
				actions.atk_aru.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_ARA:
			if actions.has('atk_ara'):
				actions.atk_ara.update(delta)
			else:
				change_state(states.IDL)
		states.ATK_DNK:
			if actions.has('atk_dnk'):
				actions.atk_dnk.update(delta)
			else:
				change_state(states.IDL)
		states.GRB_IDL:
			if actions.has('grb_idl'):
				actions.grb_idl.update(delta)
			else:
				change_state(states.IDL)
		states.GRB_DSH:
			if actions.has('grb_dsh'):
				actions.grb_dsh.update(delta)
			else:
				change_state(states.IDL)
		states.GRB_PVT:
			if actions.has('grb_pvt'):
				actions.grb_pvt.update(delta)
			else:
				change_state(states.IDL)
		states.GRB_HLD:
			if brain.grab_target == null:
				change_state(states.IDL)
			var substates: Dictionary[String, int] = get_substates()
			match substate:
				substates.IDL:
					if brain.attack_buffer > 0:
						brain.reset_attack_buffer()
						change_substate(substates.PML)
						return
					var throw_dir: Vector2 = FighterBrain.get_joy_input(brain.local_input.get("throw_vector", Vector2.ZERO))
					if throw_dir.x == -brain.local_flip_h:
						change_state(states.THW_BAK)
					elif throw_dir.length() > PlayerInput.DEADZONE:
						change_state(states.THW_FWD)
					elif brain.jump_buffer > 0:
						SyncManager.set_synced(brain, "jump_buffer", 0)
						change_state(states.THW_UPR)
					elif brain.guard_buffer > 0:
						SyncManager.set_synced(brain, "guard_buffer", 0)
						change_state(states.THW_DWN)
				substates.PML:
					brain.atk_pml_update(delta)
				substates.RLS:
					change_state(states.IDL)
		states.THW_FWD:
			if actions.has('thw_fwd'):
				actions.thw_fwd.update(delta)
			else:
				change_state(states.IDL)
		states.THW_BAK:
			if actions.has('thw_bak'):
				actions.thw_bak.update(delta)
			else:
				change_state(states.IDL)
		states.THW_UPR:
			if actions.has('thw_upr'):
				actions.thw_upr.update(delta)
			else:
				change_state(states.IDL)
		states.THW_DWN:
			if actions.has('thw_dwn'):
				actions.thw_dwn.update(delta)
			else:
				change_state(states.IDL)
		states.SHT_NTL:
			if actions.has('sht_gnn'):
				actions.sht_gnn.update(delta)
			else:
				change_state(states.IDL)
		states.SHT_FWD:
			if actions.has('sht_gnf'):
				actions.sht_gnf.update(delta)
			else:
				change_state(states.IDL)
		states.SHT_UPR:
			if actions.has('sht_gnu'):
				actions.sht_gnu.update(delta)
			else:
				change_state(states.IDL)
		states.SHT_ARN:
			if actions.has('sht_arn'):
				actions.sht_arn.update(delta)
			else:
				change_state(states.IDL)
		states.SHT_ARF:
			if actions.has('sht_arf'):
				actions.sht_arf.update(delta)
			else:
				change_state(states.IDL)
		states.SHT_ARU:
			if actions.has('sht_aru'):
				actions.sht_aru.update(delta)
			else:
				change_state(states.IDL)
		states.PWR_NTL:
			if actions.has('pwr_gnn'):
				actions.pwr_gnn.update(delta)
			else:
				change_state(states.IDL)
		states.PWR_FWD:
			if actions.has('pwr_gnf'):
				actions.pwr_gnf.update(delta)
			else:
				change_state(states.IDL)
		states.PWR_UPR:
			if actions.has('pwr_gnu'):
				actions.pwr_gnu.update(delta)
			else:
				change_state(states.IDL)
		states.PWR_ARN:
			if actions.has('pwr_arn'):
				actions.pwr_arn.update(delta)
			else:
				change_state(states.IDL)
		states.PWR_ARF:
			if actions.has('pwr_arf'):
				actions.pwr_arf.update(delta)
			else:
				change_state(states.IDL)
		states.PWR_ARU:
			if actions.has('pwr_aru'):
				actions.pwr_aru.update(delta)
			else:
				change_state(states.IDL)
		states.TRP_NTL:
			if actions.has('trp_gnn'):
				actions.trp_gnn.update(delta)
			else:
				change_state(states.IDL)
		states.TRP_FWD:
			if actions.has('trp_gnf'):
				actions.trp_gnf.update(delta)
			else:
				change_state(states.IDL)
		states.TRP_UPR:
			if actions.has('trp_gnu'):
				actions.trp_gnu.update(delta)
			else:
				change_state(states.IDL)
		states.TRP_ARN:
			if actions.has('trp_arn'):
				actions.trp_arn.update(delta)
			else:
				change_state(states.IDL)
		states.TRP_ARF:
			if actions.has('trp_arf'):
				actions.trp_arf.update(delta)
			else:
				change_state(states.IDL)
		states.TRP_ARU:
			if actions.has('trp_aru'):
				actions.trp_aru.update(delta)
			else:
				change_state(states.IDL)
		states.CHS:
			chase_pos.x = brain.chase_target.get_center().x
			chase_pos.z = brain.chase_target.get_center().z
			var target_pos: Vector3 = chase_pos-Basis(Vector3.UP, brain.chase_target.global_facing_dir).x
			if brain.attack_buffer > 0:
				brain.reset_attack_buffer()
				change_state(states.ATK_DNK)
				return
			if brain.chase(target_pos):
				brain.velocity = Vector3.ZERO
				brain.chase_target = null
				SyncManager.set_synced(brain, "chase_window", 0)
				chase_pos = Vector3.ZERO
				change_state(states.AIR, "FAL_FRE")
		states.STN_HIT:
			if !brain.grounded:
				brain.apply_gravity(delta, data.get_fall_gravity(), data.fall_max_speed)
			if Vector2(brain.velocity.x, brain.velocity.z).length() <= 1.0:
				brain.velocity.x = 0.0
				brain.velocity.z = 0.0
			else:
				brain.velocity.x *= FighterBrain.STUN_KB_DECAY
				brain.velocity.z *= FighterBrain.STUN_KB_DECAY
			if brain.frame >= brain.stun+5:
				if brain.grounded:
					change_state(states.IDL, "IDL")
				else:
					change_state(states.AIR, "FAL_NRM")
				return
			elif brain.frame >= brain.stun:
				if brain.frame == brain.stun:
					brain.play_section(&"StnHit", &"End", &"", true)
				if brain.frame >= brain.stun+5:
					change_state(states.IDL, "IDL")
					return
				if input_dodge(): return
				if brain.grounded:
					if input_jump(): return 
					if input_dash(): return
					if brain.attack_buffer > 0:
						if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
							if input_attack(
								get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.NTL),
								get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.FWD),
								get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.BAK)
								): return
						else:
							if input_attack(
								states.ATK_NT1,
								states.ATK_FWC,
								states.ATK_UPC
								): return
					if input_guard(): return
				else:
					if brain.attack_buffer > 0:
						if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
							if input_attack(
								get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.NTL),
								get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.FWD),
								get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.BAK)
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
			var grab_holder: FighterBrain = brain.grab_holder
			brain.move_center_to_point(grab_holder.grab_point.global_position)
			if grab_holder.sm.state == grab_holder.sm.states.GRB_HLD:
				#TODO - Add mashing function
				SyncManager.set_synced(brain, "grabstun", brain.grabstun-1)
				if brain.grabstun <= 0:
					SyncManager.set_synced(brain, "grabstun", 0)
					brain.grab_holder.grab_target = null
					brain.grab_holder = null
					brain.velocity = Vector3.ZERO
					change_state(states.AIR, "FAL_NRM")
		states.LNC_NML:
			if brain.frame >= brain.stun+3:
				change_state(states.AIR, "FAL_NRM")
			brain.apply_gravity(delta, FighterData.get_gravity(brain.knockback.y, brain.stun))
			if brain.grounded:
				brain.velocity.x *= 0.3
				brain.velocity.z *= 0.3
				brain.velocity.y = 5.0
				change_state(states.CRS_FLR)
				return
			if brain.is_on_wall():
				brain.velocity.x = brain.get_wall_normal().x*brain.knockback.x
				brain.velocity.z = brain.get_wall_normal().z*brain.knockback.z
		states.LNC_HVY:
			brain.chase_window = FighterBrain.CHASE_WINDOW_FRAMES
			if brain.frame == 6:
				brain.play_section(&"StnHvy", &"Loop", &"", true, Animation.LoopMode.LOOP_LINEAR)
			if brain.is_on_wall():
				if round(brain.move_input) == round(brain.get_wall_normal()):
					change_state(states.TEC_WAL)
					return
				brain.health -= 15.0
				SyncManager.set_synced(brain, "chase_window", 0)
				brain.chase_target = null
				brain.velocity = Vector3.ZERO
				brain.knockback = brain.get_wall_normal()*3.5
				brain.knockback.y = FighterData.get_jump_force(6.25, 15.0)
				brain.update_facing_dir(-brain.get_wall_normal())
				change_state(states.CRS_WAL)
				return
			if brain.frame >= brain.stun-5:
				brain.velocity = brain.velocity.limit_length(brain.velocity.length()*0.75)
				if brain.frame >= brain.stun:
					if input_dodge(): return
					if brain.grounded:
						if input_jump(): return 
						if input_dash(): return
						if brain.attack_buffer > 0:
							if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
								if input_attack(
									get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.NTL),
									get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.FWD),
									get_special(FighterBrain.SpecialVariant.GND, FighterBrain.AttackInput.BAK)
									): return
							else:
								if input_attack(
									states.ATK_NT1,
									states.ATK_FWC,
									states.ATK_UPC
									): return
						if input_guard(): return
					else:
						if brain.attack_buffer > 0:
							if brain.buffered_attack_input_data.type == FighterBrain.AttackType.SPL:
								if input_attack(
									get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.NTL),
									get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.FWD),
									get_special(FighterBrain.SpecialVariant.AIR, FighterBrain.AttackInput.BAK)
									): return
							else:
								if input_attack(
									states.ATK_ARN,
									states.ATK_ARF,
									states.ATK_ARU
									): return
				if brain.frame >= brain.stun+15:
					change_state(states.AIR, "FAL_NRM")
					return
		states.LNC_UPR:
			if brain.frame >= brain.stun:
				change_state(states.AIR, "FAL_NRM")
			if brain.frame == brain.stun-8:
				brain.play_section(&"StnUpr", &"Apex", &"", true)
			brain.apply_gravity(delta, FighterData.get_gravity(brain.knockback.y, brain.stun))
		states.LNC_DNK:
			var substates: Dictionary[String, int] = get_substates()
			match substate:
				substates.IMP:
					if brain.grounded:
						brain.velocity = brain.get_floor_normal()*absf(brain.knockback.length()*0.5)
						change_substate(substates.CRS)
				substates.CRS:
					brain.apply_gravity(delta, -absf(brain.knockback.y))
					if brain.grounded:
						var floor_normal: Vector3 = brain.get_floor_normal()
						if Vector2(floor_normal.x, floor_normal.z).length() > 0.1:
							brain.velocity.x = floor_normal.x*5.0
							brain.velocity.z = floor_normal.z*5.0
							brain.velocity.y = 5.0
						else:
							brain.velocity = Vector3(-5.0*DetMath._math.cos(brain.global_facing_dir), 5.0, -5.0*DetMath._math.sin(brain.global_facing_dir))
						change_state(states.CRS_FLR)
		states.CRS_WAL:
			if brain.frame == 15:
				brain.velocity = brain.knockback
				brain.play_section(&"CrsWal", &"Apex", &"")
			elif brain.frame > 15:
				if brain.velocity.y > 0.0:
					brain.apply_gravity(delta, -60.0)
				elif absf(brain.velocity.y) <= 5.0:
					brain.apply_gravity(delta, -30.0)
				else:
					brain.apply_gravity(delta, -90.0)
				brain.velocity.x *= exp(-0.95*delta)
				brain.velocity.z *= exp(-0.95*delta)
				
				if brain.grounded:
					brain.velocity = Vector3(-6.0*DetMath._math.cos(brain.global_facing_dir), 5.0, 6.0*DetMath._math.sin(brain.global_facing_dir))
					change_state(states.CRS_FLR)
		states.CRS_FLR:
			brain.apply_gravity(delta, -40.0)
			if brain.grounded:
				change_state(states.FNT)
		states.TEC_NTL:
			pass
		states.TEC_FWD:
			pass
		states.TEC_BAK:
			pass
		states.TEC_WAL:
			if brain.frame >= 10:
				if input_chase():
					change_state(states.CHS)
					chase_pos.y = brain.global_position.y+7.0
					return
				else:
					change_state(states.AIR, "FAL_NRM")
		states.FNT:
			if brain.frame >= 180:
				change_state(states.GTP_NTL)
			elif brain.frame >= 40:
				if brain.jump_buffer > 0:
					SyncManager.set_synced(brain, "jump_buffer", 0)
					change_state(states.GTP_NTL)
				elif brain.move_input.length() >= PlayerInput.DEADZONE:
					if brain.global_facing_dir_h == -brain.move_input.x:
						change_state(states.GTP_BAK)
					else:
						change_state(states.GTP_FWD)
				elif brain.attack_buffer > 0:
					brain.reset_attack_buffer()
					change_state(states.GTP_ATK)
		states.GTP_NTL:
			if brain.frame >= 27:
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
			if actions.has('dsh_gnd'):
				actions.dsh_gnd.start(old_state)
			else:
				change_state(states.IDL)
		states.JMP_SQT:
			brain.play_anim(&"JmpSqt", true)
		states.AIR:
			pass
		states.AIR_ACT:
			if data.mov_mob_air.get("uses") != null:
				data.mov_mob_air.uses += 1
			if actions.has('dsh_air'):
				actions.dsh_air.start(old_state)
			else:
				change_state(states.IDL)
		states.LND:
			brain.play_section(&"Lnd", &"", &"Land")
		states.GRD:
			if actions.has('def_grd'):
				actions.def_grd.start(old_state)
			else:
				change_state(states.IDL)
		states.HEL:
			brain.play_section(&"Hel", &"Startup", &"LoopStart")
			if actions.has('def_hel'):
				actions.def_hel.start(old_state)
			else:
				change_state(states.IDL)
		states.DGE_GND:
			brain.dodge_input = brain.input_raw_to_world(brain.last_move_input_raw)
			brain.update_facing_dir(brain.dodge_input)
			if actions.has('dge_gnd'):
				actions.dge_gnd.start(old_state)
			else:
				change_state(states.IDL)
		states.DGE_AIR:
			if actions.has('dge_air'):
				actions.dge_air.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_NT1:
			if actions.has('atk_nt1'):
				actions.atk_nt1.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_NT2:
			if actions.has('atk_nt2'):
				actions.atk_nt2.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_NT3:
			if actions.has('atk_nt3'):
				actions.atk_nt3.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_FWC:
			brain.play_anim(&"AtkFwC", true, Animation.LOOP_NONE)
		states.ATK_FWL:
			if actions.has('atk_fwl'):
				actions.atk_fwl.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_FWH:
			if actions.has('atk_fwh'):
				actions.atk_fwh.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_UPC:
			brain.play_anim(&"AtkUpC", true, Animation.LOOP_NONE)
		states.ATK_UPL:
			if actions.has('atk_upl'):
				actions.atk_upl.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_UPH:
			if actions.has('atk_uph'):
				actions.atk_uph.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_ARN:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			if actions.atk_arn.get("uses") != null:
				actions.atk_arn.uses += 1
			if actions.has('atk_arn'):
				actions.atk_arn.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_ARF:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			if actions.atk_arf.get("uses") != null:
				actions.atk_arf.uses += 1
			if actions.has('atk_arf'):
				actions.atk_arf.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_ARU:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			if actions.atk_aru.get("uses") != null:
				actions.atk_aru.uses += 1
			if actions.has('atk_aru'):
				actions.atk_aru.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_ARA:
			if old_state == states.JMP_SQT:
				brain.jump(data.get_short_jump_force())
			if actions.atk_ara.get("uses") != null:
				data.atk_ara.uses += 1
			if actions.has('atk_ara'):
				actions.atk_ara.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_DSH:
			if actions.has('atk_dsh'):
				actions.atk_dsh.start(old_state)
			else:
				change_state(states.IDL)
		states.ATK_DNK:
			brain.chase_target = null
			SyncManager.set_synced(brain, "chase_window", 0)
			if actions.has('atk_dnk'):
				actions.atk_dnk.start(old_state)
			else:
				change_state(states.IDL)
		states.GRB_IDL:
			if actions.has('grb_idl'):
				actions.grb_idl.start(old_state)
			else:
				change_state(states.IDL)
		states.GRB_DSH:
			if actions.has('grb_dsh'):
				actions.grb_dsh.start(old_state)
			else:
				change_state(states.IDL)
		states.GRB_HLD:
			brain.play_anim("GrbHld")
		states.THW_FWD:
			actions.thw_fwd.start(old_state)
		states.THW_BAK:
			actions.thw_bak.start(old_state)
		states.THW_UPR:
			actions.thw_upr.start(old_state)
		states.THW_DWN:
			actions.thw_dwn.start(old_state)
		states.SHT_NTL:
			actions.sht_gnn.start(old_state)
		states.SHT_FWD:
			actions.sht_gnf.start(old_state)
		states.SHT_UPR:
			actions.sht_gnu.start(old_state)
		states.SHT_ARN:
			actions.sht_arn.start(old_state)
		states.SHT_ARF:
			actions.sht_arf.start(old_state)
		states.SHT_ARU:
			actions.sht_aru.start(old_state)
		states.PWR_NTL:
			actions.pwr_gnn.start(old_state)
		states.PWR_FWD:
			actions.pwr_gnf.start(old_state)
		states.PWR_UPR:
			actions.pwr_gnu.start(old_state)
		states.PWR_ARN:
			actions.pwr_arn.start(old_state)
		states.PWR_ARF:
			actions.pwr_arf.start(old_state)
		states.PWR_ARU:
			actions.pwr_aru.start(old_state)
		states.TRP_NTL:
			actions.trp_gnn.start(old_state)
		states.TRP_FWD:
			actions.trp_gnf.start(old_state)
		states.TRP_UPR:
			actions.trp_gnu.start(old_state)
		states.TRP_ARN:
			actions.trp_arn.start(old_state)
		states.TRP_ARF:
			actions.trp_arf.start(old_state)
		states.TRP_ARU:
			actions.trp_aru.start(old_state)
		states.CHS:
			brain.play_anim(&"Chs", true, Animation.LOOP_NONE)
		states.STN_HIT:
			brain.play_section(&"StnHit", &"", &"Stun", true)
			if !brain.grounded:
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
			actions.dsh_gnd.end(new_state)
		states.JMP_SQT:
			pass
		states.AIR:
			if new_state == states.LND: brain.fast_falling = false
		states.AIR_ACT:
			if new_state == states.LND: brain.fast_falling = false
			actions.dsh_air.end(new_state)
		states.LND:
			pass
		states.GRD:
			actions.def_grd.end(new_state)
		states.HEL:
			pass
		states.DGE_GND:
			actions.dge_gnd.end(new_state)
		states.DGE_AIR:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.dge_air.end(new_state)
		states.ATK_NT1:
			reset_jab(new_state)
			actions.atk_nt1.end(new_state)
		states.ATK_NT2:
			reset_jab(new_state)
			actions.atk_nt2.end(new_state)
		states.ATK_NT3:
			reset_jab(new_state)
			actions.atk_nt3.end(new_state)
		states.ATK_FWC:
			pass
		states.ATK_FWL:
			actions.atk_fwl.end(new_state)
		states.ATK_FWH:
			actions.atk_fwh.end(new_state)
		states.ATK_UPC:
			pass
		states.ATK_UPL:
			actions.atk_upl.end(new_state)
		states.ATK_UPH:
			actions.atk_uph.end(new_state)
		states.ATK_DSH:
			actions.atk_dsh.end(new_state)
		states.ATK_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.atk_arn.end(new_state)
		states.ATK_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.atk_arf.end(new_state)
		states.ATK_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.atk_aru.end(new_state)
		states.ATK_ARA:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.atk_ara.end(new_state)
		states.ATK_DNK:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.atk_dnk.end(new_state)
		states.GRB_IDL:
			actions.grb_idl.end(new_state)
		states.GRB_DSH:
			actions.grb_dsh.end(new_state)
		states.GRB_PVT:
			actions.grb_pvt.end(new_state)
		states.GRB_HLD:
			if ![states.THW_FWD, states.THW_BAK, states.THW_UPR, states.THW_DWN].has(new_state):
				if brain.grab_target != null:
					brain.grab_target.sm.change_state(brain.grab_target.sm.states.AIR, "FAL_NRM")
					brain.grab_target.velocity = Vector3.ZERO
					brain.grab_target.grab_holder = null
					brain.grab_target = null
		states.THW_FWD:
			actions.thw_fwd.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.THW_BAK:
			actions.thw_bak.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.THW_UPR:
			actions.thw_upr.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.THW_DWN:
			actions.thw_dwn.end(new_state)
			brain.grab_target.grab_holder = null
			brain.grab_target = null
		states.SHT_NTL:
			actions.sht_gnn.end(new_state)
		states.SHT_FWD:
			actions.sht_gnf.end(new_state)
		states.SHT_UPR:
			actions.sht_gnu.end(new_state)
		states.SHT_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.sht_arn.end(new_state)
		states.SHT_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.sht_arf.end(new_state)
		states.SHT_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.sht_aru.end(new_state)
		states.PWR_NTL:
			actions.pwr_gnn.end(new_state)
		states.PWR_FWD:
			actions.pwr_gnf.end(new_state)
		states.PWR_UPR:
			actions.pwr_gnu.end(new_state)
		states.PWR_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.pwr_arn.end(new_state)
		states.PWR_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.pwr_arf.end(new_state)
		states.PWR_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.pwr_aru.end(new_state)
		states.TRP_NTL:
			actions.trp_gnn.end(new_state)
		states.TRP_FWD:
			actions.trp_gnf.end(new_state)
		states.TRP_UPR:
			actions.trp_gnu.end(new_state)
		states.TRP_ARN:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.trp_arn.end(new_state)
		states.TRP_ARF:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.trp_arf.end(new_state)
		states.TRP_ARU:
			if new_state == states.LND:
				brain.fast_falling = false
			actions.trp_aru.end(new_state)
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
	brain.sub_frame = 0
	substate = new_state

func substate_start() -> bool:
	return brain.sub_frame == 1

func reset_jab(new_state: int) -> void:
	if ![states.ATK_NT2, states.ATK_NT3].has(new_state):
		jab_count = 0

func falling() -> bool:
	return ![
		states.DSH,
		states.CHS,
		states.AIR,
		states.AIR_ACT,
		states.ATK_NT1,
		states.ATK_NT2,
		states.ATK_NT3,
		states.ATK_FWC,
		states.ATK_FWL,
		states.ATK_FWH,
		states.ATK_UPC,
		states.ATK_UPL,
		states.ATK_UPH,
		states.ATK_DSH,
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
		states.FNT].has(state) && !brain.grounded

func attacking() -> Array:
	return [
	states.ATK_NT1,
	states.ATK_NT2,
	states.ATK_NT3,
	states.ATK_FWC,
	states.ATK_FWL,
	states.ATK_FWH,
	states.ATK_UPC,
	states.ATK_UPL,
	states.ATK_UPH,
	states.ATK_ARN,
	states.ATK_ARF,
	states.ATK_ARU,
	states.ATK_DSH,
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
	if brain.jump_buffer > 0:
		SyncManager.set_synced(brain, "jump_buffer", 0)
		change_state(states.JMP_SQT)
		return true
	return false

func input_dash() -> bool:
	if brain.dash_buffer > 0:
		SyncManager.set_synced(brain, "dash_buffer", 0)
		change_state(states.DSH)
		return true
	return false

func input_attack(atk_ntl: int, atk_fwd: int, atk_upr: int, flip: bool = true) -> bool:
	var atk_data: Dictionary = {}
	if brain.attack_buffer > 0:
		var attack_input_data: Dictionary = brain.buffered_attack_input_data
		atk_data = {
			input_method = attack_input_data.method,
			dir = brain.get_kb_aim()
			}
		match attack_input_data.input:
			FighterBrain.AttackInput.NTL:
				brain.reset_attack_buffer()
				change_state(atk_ntl, "BASE", atk_data if [states.ATK_FWC, states.ATK_UPC].has(atk_ntl) else {})
				return true
			FighterBrain.AttackInput.FWD:
				brain.reset_attack_buffer()
				change_state(atk_fwd, "BASE", atk_data if [states.ATK_FWC, states.ATK_UPC].has(atk_fwd) else {})
				return true
			FighterBrain.AttackInput.BAK:
				brain.reset_attack_buffer()
				if attack_input_data.method == FighterBrain.InputMethod.DIR && flip:
					brain.update_facing_dir(brain.move_input*Vector3(-1.0, 1.0, 1.0))
				change_state(atk_upr, "BASE", atk_data if [states.ATK_FWC, states.ATK_UPC].has(atk_upr) else {})
				return true
	return false

func input_guard() -> bool:
	if brain.guard_buffer > 0:
		SyncManager.set_synced(brain, "guard_buffer", 0)
		change_state(states.GRD)
		return true
	return false

func input_dodge(aerial: bool = false) -> bool:
	if brain.dodge_buffer > 0:
		SyncManager.set_synced(brain, "dodge_buffer", 0)
		if aerial:
			change_state(states.DGE_AIR)
		else:
			change_state(states.DGE_GND)
		return true
	return false

func input_fast_fall() -> bool:
	if !brain.fast_falling:
		if brain.grab_buffer > 0 && brain.velocity.y <= 0.0:
			SyncManager.set_synced(brain, "grab_buffer", 0)
			brain.fast_falling = true
			return true
	return false

func get_special(atk_var: FighterBrain.SpecialVariant, atk_input: FighterBrain.AttackInput) -> int:
	var specials: Dictionary[int, String] = {
		FighterBrain.SpecialType.PWR: "PWR",
		FighterBrain.SpecialType.SHT: "SHT",
		FighterBrain.SpecialType.TRP: "TRP"
	}
	
	var inputs: Dictionary[int, String]
	var special: int
	
	match atk_var:
		FighterBrain.SpecialVariant.GND:
			special = brain.ground_special
			inputs = {
				FighterBrain.AttackInput.NTL: "_NTL",
				FighterBrain.AttackInput.FWD: "_FWD",
				FighterBrain.AttackInput.BAK: "_UPR"
			}
		
		FighterBrain.SpecialVariant.AIR:
			special = brain.aerial_special
			inputs = {
				FighterBrain.AttackInput.NTL: "_ARN",
				FighterBrain.AttackInput.FWD: "_ARF",
				FighterBrain.AttackInput.BAK: "_ARU"
			}
		
		FighterBrain.SpecialVariant.DEF:
			special = brain.defense_special
			inputs = {
				FighterBrain.AttackInput.NTL: "_DEF",
				FighterBrain.AttackInput.FWD: "_DEF",
				FighterBrain.AttackInput.BAK: "_DEF"
			}
	
	return states[specials[special]+inputs[atk_input]]
