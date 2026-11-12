extends FighterBrain

#var hb_group_atk_dnk: Hitbox.HitboxGroup
#var hb_group_atk_aair: Hitbox.HitboxGroup
#var hb_group_pwr_fair: Hitbox.HitboxGroup
#var bck_thw_finished: bool = false
#var air_act_refreshed: bool = true
#var pwr_nair_finished: bool = false
#var pwr_hvy_dir: Vector2 = Vector2.RIGHT


#func update_self(delta: float) -> void:
	#if is_on_floor():
		#air_act_refreshed = true

#region ACTIONS
#func dsh_start() -> void:
	#velocity = input_raw_to_world(last_move_input_raw)*20.0
	#velocity.y = 12.0

#func dsh_update(delta: float) -> int:
	#apply_gravity(delta, data.get_fall_gravity(), fast_falling)
	#if is_on_floor():
		#reset_frames()
		#set landing lag
		#return sm.states.LND
	#return -1

#func dsh_end() -> void:
	#pass

#func air_act_start() -> void:
	#velocity = Basis(Vector3.UP, global_facing_dir).x*20.0
	#velocity.y = 5.0
	#air_act_refreshed = false
#
#func air_act_update(delta: float) -> int:
	#if frame >= 22.0:
		#return sm.states.AIR
	#elif frame >= 7.0:
		#apply_gravity(delta, data.get_fall_gravity())
	#return -1
#
#func dodge_start() -> void:
	#super()
#
#func dodge_update(delta: float) -> bool:
	#if frame <= 7.0:
		#velocity = dodge_input*(data.get_dodge_speed(dodge_count)/2.0)
	#else:
		#velocity = dodge_input*data.get_dodge_speed(dodge_count)
	#
	#if frame == 3.0:
		#hurtbox_shape.set_deferred("disabled", true)
	#if frame == 15.0:
		#hurtbox_shape.set_deferred("disabled", false)
	#if frame >= 7.0+data.get_dodge_duration(dodge_count):
		#return true
	#return false
#
#func dodge_rcvr_update(delta: float) -> bool:
	#walk(Vector3.ZERO, data.get_dodge_speed(dodge_count), 0.0, data.get_dodge_traction(dodge_count), delta)
	#if frame >= data.get_dodge_rcvr_frames(dodge_count):
		#return true
	#return false
#
#func dodge_end() -> void:
	#super()
#endregion
#
#region GROUNDS
#func atk_n1_start() -> void:
	#pass
#
#func atk_n1_update(delta: float) -> int:
	#if frame < 4.0:
		#velocity.x *= exp(-0.4)
		#velocity.z *= exp(-0.4)
	#if frame >= 15.0:
		#return sm.states.IDL
	#elif frame >= 8.0:
		#if sm.jab_count >= 1:
			#return sm.states.ATK_N2
	#if frame == 4.0:
		#velocity.x = 0.0
		#velocity.z = 0.0
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.2
		#shape.height = 1.2
		#create_hitbox(shape, 2.0, 3.0, Vector2(0.0, 0.0), 3.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.HBX_TWD_XZ, 15.0, 0.0, Vector3(0.85, 1.0, 0.0), Vector3.FORWARD*90.0)
	#return -1
#
#func atk_n1_end() -> void:
	#pass
#
#func atk_n2_start() -> void:
	#pass
#
#func atk_n2_update(delta: float) -> int:
	#if frame == 5.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.5
		#shape.height = 1.2
		#create_hitbox(shape, 4.0, 3.0, Vector2.ZERO, 0.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 15.0, 0.0, Vector3(0.6, 0.85, 0.0), Vector3.FORWARD*45.0)
	#if frame >= 18.0:
		#return sm.states.IDL
	#elif frame >= 12.0:
		#if sm.jab_count >= 2:
			#return sm.states.ATK_N3
	#return -1
#
#func atk_n2_end() -> void:
	#pass
#
#func atk_n3_start() -> void:
	#pass
#
#func atk_n3_update(delta: float) -> int:
	#if frame == 5.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.7
		#shape.height = 1.6
		#create_hitbox(shape, 6.0, 11.0, Vector2.ZERO, 0.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 20.0, 0.0, Vector3(0.35, 1.0, 0.0), Vector3.FORWARD*45.0)
	#if frame >= 29.0:
		#return sm.states.IDL
	#elif frame >= 19.0:
		#if sm.jab_count >= 3:
			#if absf(move_input.x) > 0.2 && signf(move_input_raw.x) == -signf(local_flip_h):
				#return sm.states.ATK_UPR
			#else:
				#return sm.states.ATK_HVY
	#return -1
#
#func atk_n3_end() -> void:
	#pass
#
#func atk_hvy_start() -> void:
	#kbi_dir = get_kbi(move_input_raw)
#
#func atk_hvy_update(delta: float) -> int:
	#apply_gravity(delta, data.get_fall_gravity()*1.2, false)
	#if frame <= 10.0:
		#velocity.x *= exp(-0.6)
		#velocity.z *= exp(-0.6)
	#if frame == 10.0:
		#velocity.x = 0.0
		#velocity.z = 0.0
	#if frame == 11.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.85
		#shape.height = 2.1
		#create_hitbox(shape, 12.0, 30.0, Vector2(kbi_dir, 0.0), 30.0, Hitbox.LaunchTypes.HVY, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 40.0, 7.0, Vector3(0.6, 1.0, 0.0), Vector3.FORWARD*90.0)
	#if frame >= 51.0:
		#return sm.states.IDL
	#elif frame >= 39.0:
		#if frame == 39.0:
			#velocity.x = -global_facing_dir_h*5.0
			#velocity.y = 17.0
		#if sm.input_chase():
			#return sm.states.CHS
	#return -1
#
#func atk_hvy_end() -> void:
	#pass
#
#func atk_upr_start() -> void:
	#pass
#
#func atk_upr_update(delta: float) -> int:
	#if frame <= 8.0:
		#velocity.x *= exp(-0.2)
		#velocity.z *= exp(-0.2)
	#if frame == 8.0:
		#velocity.x = 0.0
		#velocity.z = 0.0
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.7
		#shape.height = 2.15
		#create_hitbox(shape, 8.0, 15.0, Vector2(0.0, 90.0), 25.0, Hitbox.LaunchTypes.UPR, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 20.0, 5.0, Vector3(0.5, 1.3, 0.0), Vector3.ZERO)
	#if frame >= 31.0:
		#return sm.states.IDL
	#elif frame >= 19.0 && jump_buffer > 0.0:
		#jump_buffer = 0.0
		#return sm.states.JMP_SQT
	#return -1
#
#func atk_upr_end() -> void:
	#pass
#
#func atk_dsh_start() -> void:
	#pass
#
#func atk_dsh_update(delta: float) -> int:
	#apply_gravity(delta, data.get_fall_gravity())
	#if frame >= 22.0:
		#return sm.states.FAL
	#elif frame >= 14.0:
		#if attack_buffer > 0.0:
			#var attack_input_data: Dictionary = buffered_attack_input_data
			#match attack_input_data.type:
				#AttackType.NML:
					#if [AttackInput.FWD, AttackInput.BCK].has(attack_input_data.input):
						#reset_attack_buffer()
						#return sm.states.ATK_FAIR
					#elif attack_input_data.input == AttackInput.NTL:
						#reset_attack_buffer()
						#return sm.states.ATK_NAIR
		#elif jump_buffer > 0.0:
				#jump_buffer = 0.0
				#return sm.states.AIR_ACT
	#elif frame == 4.0:
		#velocity.y = 7.0
	#elif frame == 6.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.height = 3.0
		#shape.radius = 0.5
		#create_hitbox(shape, 6.0, 10.0, Vector2(0.0, 40.0), 20.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 20.0, 5.0, Vector3(0.2, 0.7, 0.0), Vector3.FORWARD*90.0, FlipModes.ARD)
	#return -1
#
#func atk_dsh_end() -> void:
	#pass
#
#func atk_pml_start() -> void:
	#pass
#
#func atk_pml_update(delta: float) -> bool:
	#if frame == 5.0:
		#var shape: SphereShape3D = SphereShape3D.new()
		#shape.radius = 0.25
		#create_hitbox(shape, 2.0, 5.0, Vector2.ZERO, 0.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 0.0, 0.0, Vector3(0.9, 0.75, 0.0), Vector3.ZERO)
	#if frame >= 15.0:
		#return true
	#return false
#
#func atk_pml_end() -> void:
	#pass
#
#func atk_gtp_start() -> void:
	#pass
#
#func atk_gtp_update(delta: float) -> bool:
	#if frame == 3.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.6
		#shape.height = 2.3
		#create_hitbox(shape, 11.0, 5.0, Vector2(0.0, 10.0), 10.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.PLR_AWY_XZ, 10.0, 0.0, Vector3(0.0, 0.6, 0.0), Vector3.RIGHT*90.0)
	#if frame == 14.0:
		#hurtbox_shape.set_deferred("disabled", true)
	#if frame >= 30.0:
		#return true
	#return false
#
#func atk_gtp_end() -> void:
	#pass
#endregion
#
#region AERIALS
#func atk_nair_start() -> void:
	#pass
#
#func atk_nair_update(delta: float) -> int:
	#if frame < 4.0:
		#apply_gravity(delta, data.get_jump_gravity())
	#else:
		#apply_gravity(delta, data.get_fall_gravity())
	#if frame == 4.0:
		#if velocity.y <= 0.0:
			#velocity.y = 0.0
		#velocity.y += 6.0
		#var shape: SphereShape3D = SphereShape3D.new()
		#shape.radius = 0.45
		#create_hitbox(shape, 6.0, 7.0, Vector2(0.0, 90.0), 15.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 25.0, 2.0, Vector3(0.6, 0.0, 0.0), Vector3.ZERO)
	#if frame >= 18.0:
		#return sm.states.AIR
	#elif frame >= 12.0:
		#walk(move_input, data.base_speed, data.get_accel_amount()*data.air_accel_mult, 0.0, delta)
		#if jump_buffer > 0.0 && sm.can_air_act():
				#jump_buffer = 0.0
				#return sm.states.AIR_ACT
	#return -1
#
#func atk_nair_end() -> void:
	#pass
#
#func atk_dair_start() -> void:
	#pass
#
#func atk_dair_update(delta: float) -> int:
	#apply_gravity(delta, data.get_jump_gravity())
	#if frame == 4.0:
		#if velocity.y <= 0.0:
			#velocity.y = 0.0
		#velocity.y += 5.0
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.4
		#shape.height = 1.4
		#create_hitbox(shape, 6.0, 5.0, Vector2(0.0, 15.0), 9.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 20.0, 5.0, Vector3(0.7, 1.15, 0.0), Vector3.FORWARD*50.0, FlipModes.ARD)
	#if frame >= 16.0:
		#return sm.states.AIR
	#return -1
#
#func atk_dair_end() -> void:
	#pass
#
#func atk_aair_start() -> void:
	#velocity = Basis(Vector3.UP, global_facing_dir).x*15.0
	#if velocity.y <= 0.0:
		#velocity.y = 0.0
	#hb_group_atk_aair = Hitbox.HitboxGroup.create_group("SonicAtkAAir%s" % player_id, self)
	#hitbox_groups.append(hb_group_atk_aair)
#
#func atk_aair_update(delta: float) -> int:
	#apply_gravity(delta, data.get_jump_gravity())
	#if frame == 5.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.45
		#shape.height = 1.5
		#var hitbox: Hitbox = create_hitbox(shape, 3.0, 20.0, Vector2(0.0, 55.0), 18.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 20.0, 7.0, Vector3(0.7, 0.4, 0.0), Vector3.FORWARD*90.0, PlayerBrain.FlipModes.ARD)
		#hb_group_atk_aair.add_hitbox(hitbox)
	#if frame == 8.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.4
		#shape.height = 1.2
		#var hitbox: Hitbox = create_hitbox(shape, 6.0, 13.0, Vector2(0.0, 33.0), 10.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 15.0, 0.0, Vector3(0.7, 0.4, 0.0), Vector3.FORWARD*90.0, PlayerBrain.FlipModes.ARD)
		#hb_group_atk_aair.add_hitbox(hitbox)
	#if frame == 14.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.35
		#shape.height = 1.0
		#var hitbox: Hitbox = create_hitbox(shape, INF, 7.0, Vector2(0.0, 33.0), 8.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 10.0, 0.0, Vector3(0.7, 0.4, 0.0), Vector3.FORWARD*90.0, PlayerBrain.FlipModes.ARD)
		#hb_group_atk_aair.add_hitbox(hitbox)
	#return -1
#
#func atk_aair_end() -> void:
	#pass
#
#func atk_dnk_start() -> void:
	#velocity = Vector3.ZERO
	#hb_group_atk_dnk = Hitbox.HitboxGroup.create_group("SonicAtkDnk%s" % player_id, self)
	#hitbox_groups.append(hb_group_atk_dnk)
#
#func atk_dnk_update(delta: float) -> int:
	#if frame == 10.0:
		#var shape: SphereShape3D = SphereShape3D.new()
		#shape.radius = 0.25
		#var hitbox: Hitbox = create_hitbox(shape, 5.0, 43.0, Vector2(0.0, 270.0), 40.0, Hitbox.LaunchTypes.DNK, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 25.0, 10.0, Vector3(0.5, 0.5, 0.0), Vector3.ZERO)
		#hb_group_atk_dnk.add_hitbox(hitbox)
	#if frame == 15.0:
		#var shape: SphereShape3D = SphereShape3D.new()
		#shape.radius = 0.9
		#var hitbox: Hitbox = create_hitbox(shape, 8.0, 13.0, Vector2(0.0, 90.0), 5.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 10.0, 0.0, Vector3(0.5, 0.7, 0.0), Vector3.ZERO)
		#hb_group_atk_dnk.add_hitbox(hitbox)
	#if frame >= 25.0:
		#return sm.states.AIR
	#return -1
#
#func atk_dnk_end() -> void:
	#pass
#endregion
#
#region GRABS
#func grb_idl_start() -> void:
	#velocity = Vector3.ZERO
#
#func grb_idl_update(delta: float) -> bool:
	#if frame == 5.0:
		#grabbox_shape.set_deferred("disabled", false)
	#if frame == 9.0:
		#grabbox_shape.set_deferred("disabled", true)
	#if frame >= 21.0:
		#return true
	#return false
#
#func grb_idl_end() -> void:
	#pass
#
#func grb_dsh_start() -> void:
	#velocity = get_forward()*10.0
#
#func grb_dsh_update(delta: float) -> bool:
	#if frame >= 15.0:
		#velocity = velocity.move_toward(Vector3.ZERO, 30.0*delta)
	#if frame == 12.0:
		#grabbox_shape.set_deferred("disabled", false)
	#if frame == 22.0:
		#grabbox_shape.set_deferred("disabled", true)
	#if frame >= 35.0:
		#return true
	#return false
#
#func grb_dsh_end() -> void:
	#pass
#endregion
#
#region THROWS
#func thw_fwd_start() -> void:
	#grab_target.collbox.set_deferred("disabled", false)
	#kbi_dir = get_kbi(move_input_raw)
#
#func thw_fwd_update(delta: float) -> int:
	#chase_window = CHASE_WINDOW_FRAMES
	#if frame == 22.0:
		#var shape: SphereShape3D = SphereShape3D.new()
		#shape.radius = 0.5
		#var hitbox: Hitbox = create_hitbox(shape, 5.0, 28.0, Vector2(kbi_dir, 0.0), 25.0, Hitbox.LaunchTypes.HVY, Hitbox.HitboxTypes.THW, Hitbox.AngleModes.NML, 40.0, 0.0, Vector3(0.25, 1.0, 0.0), Vector3.FORWARD*90.0)
	#if frame >= 43.0:
		#return sm.states.IDL
	#elif frame >= 34.0 && sm.input_chase():
		#return sm.states.CHS
	#return -1
#
#func thw_fwd_end() -> void:
	#pass
#
#func thw_bck_start() -> void:
	#bck_thw_finished = false
#
#func thw_bck_update(delta: float) -> int:
	#if !bck_thw_finished:
		#if frame == 12.0:
			#velocity.y = PlayerData.get_jump_force(2.5, 20.0)
			#velocity.x = -global_facing_dir_h*5.0
		#if anim.current_animation_position*60.0 >= 21:
			#anim.seek(13.0/60.0)
		#if frame > 12.0:
			#if velocity.y > 0.0:
				#velocity.y += PlayerData.get_gravity(2.5, 20.0)*delta
			#else:
				#velocity.y += PlayerData.get_gravity(2.5, 10.0)*delta
			#if is_on_floor():
				#velocity.x = -global_facing_dir_h*2.5
				#reset_frames()
				#var shape: SphereShape3D = SphereShape3D.new()
				#shape.radius = 1.0
				#var hitbox: Hitbox = create_hitbox(shape, 3.0, 41.0, Vector2(0.0, 112.0), 27.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.THW, Hitbox.AngleModes.NML, 30.0, 7.0, Vector3(0.0, 1.0, 0.0), Vector3.ZERO)
				#bck_thw_finished = true
	#else:
		#if frame == 1.0:
			#velocity.y = PlayerData.get_jump_force(1.0, 20.0)
		#else:
			#velocity.y += PlayerData.get_gravity(1.0, 20.0)*delta
			#if anim.current_animation_position*60.0 >= 38.0:
				#anim.seek(32.0/60.0)
			#if is_on_floor():
				#velocity = Vector3.ZERO
				#return sm.states.LND
	#return -1
#
#func thw_bck_end() -> void:
	#pass
#
#func thw_upr_start() -> void:
	#pass
#
#func thw_upr_update(delta: float) -> int:
	#if frame >= 46.0 && frame <= 94.0:
		#if frame/3.0 == roundf(frame/3.0):
			#var shape: SphereShape3D = SphereShape3D.new()
			#shape.radius = 2.0
			#var hitbox: Hitbox = create_hitbox(shape, 2.0, 14.0, Vector2.ZERO, 10.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.HBX_TWD, 15.0, 0.0, Vector3(0.0, 3.5, 0.0), Vector3.ZERO)
	#if frame == 97.0:
		#var shape: SphereShape3D = SphereShape3D.new()
		#shape.radius = 2.5
		#var hitbox: Hitbox = create_hitbox(shape, 5.0, 47.0, Vector2(0.0, 80.0), 25.0, Hitbox.LaunchTypes.UPR, Hitbox.HitboxTypes.THW, Hitbox.AngleModes.PLR_AWY_X, 15.0, 0.0, Vector3(0.0, 3.5, 0.0), Vector3.ZERO)
	#if frame >= 135.0:
		#return sm.states.IDL
	#return -1
#
#func thw_upr_end() -> void:
	#pass
#
#func thw_dwn_start() -> void:
	#pass
#
#func thw_dwn_update(delta: float) -> int:
	#if frame >= 28.0 && frame <= 60.0:
		#if frame/3.0 == roundf(frame/3.0):
			#var shape: SphereShape3D = SphereShape3D.new()
			#shape.radius = 0.6
			#var hitbox: Hitbox = create_hitbox(shape, 1.0, 16.0, Vector2.ZERO, 0.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.NML, Hitbox.AngleModes.NML, 15.0, 0.0, Vector3.ZERO, Vector3.ZERO)
	#if frame == 62.0:
		#grab_target.collbox.set_deferred("disabled", false)
		#var shape: SphereShape3D = SphereShape3D.new()
		#shape.radius = 1.0
		#var hitbox: Hitbox = create_hitbox(shape, 3.0, 34.0, Vector2(0.0, 33.0), 20.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.THW, Hitbox.AngleModes.NML, 15.0, 5.0, Vector3.ZERO, Vector3.ZERO)
	#if frame == 64.0:
		#velocity.y = 20.0
		#velocity.x = -global_facing_dir_h*5.0
	#elif frame > 64.0:
		#apply_gravity(delta, data.get_jump_gravity())
		#if is_on_floor():
			#return sm.states.LND
	#if frame >= 83.0:
		#return sm.states.AIR
	#return -1
#
#func thw_dwn_end() -> void:
	#pass
#endregion
#
#region POWERS
#func pwr_ntl_start() -> void:
	#velocity = Vector3.ZERO
#
#func pwr_ntl_update(delta: float) -> int:
	#apply_gravity(delta, data.get_jump_gravity(), false)
	#if frame == 5.0:
		#velocity = Vector3(global_facing_dir_h*15.0, 5.0, 0.0)
	#if frame == 12.0:
			#var shape: SphereShape3D = SphereShape3D.new()
			#shape.radius = 0.57
			#create_hitbox(shape, 12.0, 15.0, Vector2(0.0, 25.0), 20.0, Hitbox.LaunchTypes.STN, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.NML, 10.0, 5.0, Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
	#if frame >= 24.0:
		#if is_on_floor():
			#velocity.x = velocity.move_toward(Vector3.ZERO, 150.0*delta).x
			#velocity.z = velocity.move_toward(Vector3.ZERO, 150.0*delta).z
		#if jump_buffer > 0.0:
			#jump_buffer = 0.0
			#return sm.states.JMP_SQT
	#if frame >= 36.0:
		#return sm.states.IDL
	#return -1
#
#func pwr_ntl_end() -> void:
	#if sm.state != sm.states.AIR:
		#velocity = Vector3.ZERO
#
#func pwr_hvy_start() -> void:
	#velocity = Vector3.ZERO
	#pwr_hvy_dir = move_input_raw
#
#func pwr_hvy_update(delta: float) -> int:
	#apply_gravity(delta, data.get_fall_gravity())
	#if frame == 20.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.8
		#shape.height = 2.2
		#create_hitbox(shape, 25.0, 90.0, Vector2(0.0, 0.0), 30.0, Hitbox.LaunchTypes.HVY, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.NML, 60.0, 10.0, Vector3(0.0, 1.0, 0.0), (Vector3.FORWARD*90.0)+((Vector3.UP*90.0) if absf(pwr_hvy_dir.y) > 1.0 else Vector3.ZERO), FlipModes.ARD)
		#match pwr_hvy_dir:
			#Vector2.UP:
				#play_anim("PwrHvyN")
			#Vector2.DOWN:
				#play_anim("PwrHvyS")
			#_:
				#play_anim("PwrHvyE")
	#if frame >= 20.0 && frame <= 45.0:
		#velocity.x = input_raw_to_world(pwr_hvy_dir).x*25.0
		#velocity.z = input_raw_to_world(pwr_hvy_dir).z*25.0
	#if frame == 45.0:
		#play_anim("PwrHvyEnd")
	#if frame >= 45.0:
		#if is_on_floor():
			#velocity.x = velocity.move_toward(Vector3.ZERO, 60.0*delta).x
			#velocity.z = velocity.move_toward(Vector3.ZERO, 60.0*delta).z
	#if frame >= 78.0:
		#return sm.states.IDL
	#return -1
#
#func pwr_hvy_end() -> void:
	#pass
#
#func pwr_upr_start() -> void:
	#velocity = Vector3.ZERO
#
#func pwr_upr_update(delta: float) -> int:
	#if frame == 8.0:
		#velocity = Vector3.UP*30.0
	#if frame >= 8.0 && frame <= 24.0:
		#if frame/4.0 == roundf(frame/4.0):
			#var shape = CapsuleShape3D.new()
			#shape.radius = 0.55
			#shape.height = 2.0
			#create_hitbox(shape, 3.0, 4.0, Vector2(0.0, 90.0), 30.0, Hitbox.LaunchTypes.UPR, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.HBX_TWD_XZ, 20.0, 5.0, Vector3(0.0, 0.95, 0.0), Vector3.ZERO)
	#if frame == 28.0:
		#var shape = CapsuleShape3D.new()
		#shape.radius = 0.65
		#shape.height = 2.0
		#create_hitbox(shape, 5.0, 15.0, Vector2(0.0, 90.0), 30.0, Hitbox.LaunchTypes.UPR, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.HBX_AWY_X, 20.0, 5.0, Vector3(0.0, 0.95, 0.0), Vector3.ZERO)
	#if frame >= 20.0:
		#apply_gravity(delta, data.get_fall_gravity()*2.0, false)
	#if frame >= 40.0:
		#return sm.states.AIR
	#return -1
#
#func pwr_upr_end() -> void:
	#pass
#
#func pwr_nair_start() -> void:
	#velocity = Vector3.ZERO
	#pwr_nair_finished = false
#
#func pwr_nair_update(delta: float) -> int:
	#if pwr_nair_finished:
		#apply_gravity(delta, data.get_jump_gravity(), false)
		#if frame/3.0 == roundf(frame/3.0):
			#var shape: SphereShape3D = SphereShape3D.new()
			#shape.radius = 0.57
			#create_hitbox(shape, 2.0, 5.0, Vector2(0.0, 90.0), 15.0, Hitbox.LaunchTypes.UPR, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.NML, 45.0, 2.0, Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
		#if frame >= 35.0:
			#return sm.states.AIR
	#else:
		#if frame == 10.0:
			#velocity.y = -30.0
			#velocity.x = input_raw_to_world(last_move_input_raw).x*2.5
			#velocity.z = input_raw_to_world(last_move_input_raw).z*2.5
			#match last_move_input_raw:
				#Vector2.UP:
					#play_anim("PwrNAirN")
				#Vector2.DOWN:
					#play_anim("PwrNAirS")
				#_:
					#play_anim("PwrNAirE")
		#if frame >= 10.0:
			#if frame/3.0 == roundf(frame/3.0):
				#var shape: SphereShape3D = SphereShape3D.new()
				#shape.radius = 0.6
				#create_hitbox(shape, 2.0, 5.0, Vector2(0.0, 0.0), 5.0, Hitbox.LaunchTypes.UPR, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.HBX_TWD, 10.0, 3.0, Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
			#if is_on_floor():
				#frame = 0.0
				#pwr_nair_finished = true
				#velocity.y = 25.0
	#return -1
#
#func pwr_nair_end() -> void:
	#pass
#
#func pwr_fair_start() -> void:
	#hb_group_pwr_fair = Hitbox.HitboxGroup.create_group("SonicPwrFAir%s" % player_id, self)
	#hitbox_groups.append(hb_group_pwr_fair)
	#velocity = Vector3.ZERO
#
#func pwr_fair_update(delta: float) -> int:
	#if frame == 3.0:
		#velocity = Basis(Vector3.UP, global_facing_dir).x*25.0
		#velocity.y = 10.0
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.7
		#shape.height = 2.5
		#var hitbox: Hitbox = create_hitbox(shape, 6.0, 40.0, Vector2(0.0, 25.0), 20.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.NML, 40.0, 10.0, Vector3(0.0, 0.7, 0.0), Vector3.FORWARD*90.0, FlipModes.ARD)
	#if frame == 9.0:
		#var shape: CapsuleShape3D = CapsuleShape3D.new()
		#shape.radius = 0.7
		#shape.height = 2.5
		#var hitbox: Hitbox = create_hitbox(shape, 11.0, 15.0, Vector2(0.0, 25.0), 10.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.NML, 40.0, 10.0, Vector3(0.0, 0.7, 0.0), Vector3.FORWARD*90.0, FlipModes.ARD)
	#if frame >= 20.0:
		#return sm.states.AIR
	#elif frame >= 3.0:
		#apply_gravity(delta, data.get_fall_gravity()*0.75, false)
	#return -1
#
#func pwr_fair_end() -> void:
	#pass
#
#func pwr_uair_start() -> void:
	#velocity = Vector3.ZERO
#
#func pwr_uair_update(delta: float) -> int:
	#if frame == 4.0:
		#velocity = Basis(Vector3.UP, global_facing_dir).x*12.0
		#velocity.y = 3.5
	#if frame >= 4.0:
		#if frame <= 25.0:
			#if frame/4.0 == roundf(frame/4.0):
				#var shape: CapsuleShape3D = CapsuleShape3D.new()
				#shape.radius = 0.5
				#shape.height = 2.35
				#create_hitbox(shape, 2.0, 3.0, Vector2(0.0, 0.0), 15.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.HBX_TWD, 30.0, 5.0, Vector3(0.0, 0.5, 0.0), Vector3.FORWARD*90.0)
		#if frame == 26.0:
			#var shape: CapsuleShape3D = CapsuleShape3D.new()
			#shape.radius = 0.75
			#shape.height = 2.5
			#create_hitbox(shape, 2.0, 14.0, Vector2(0.0, 15.0), 20.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.PWR, Hitbox.AngleModes.NML, 30.0, 15.0, Vector3(0.0, 0.5, 0.0), Vector3.FORWARD*90.0, FlipModes.ARD)
	#if frame >= 31.0:
		#return sm.states.AIR
	#return -1
#
#func pwr_uair_end() -> void:
	#pass
#
#endregion
#
#region SHOTS
#
#func sht_ntl_start() -> void:
	#pass
#
#func sht_ntl_update(delta: float) -> int:
	#if frame == 2.0:
		#var cshape: SphereShape3D = SphereShape3D.new()
		#cshape.radius = 0.85
		#var hshape: SphereShape3D = SphereShape3D.new()
		#hshape.radius = 1.0
		#var proj_script: ProjBullet = ProjBullet.new(Vector2(global_facing_dir*(180/PI), 0.0), 10.0)
		#create_projectile(cshape, hshape, INF, 0.0, Vector2(0.0, 30.0), 20.0, Hitbox.LaunchTypes.NML, Hitbox.HitboxTypes.SHT, ProjectileBrain.AngleModes.NML, 20.0, 5.0, Vector3.ZERO, Vector3.ZERO, ProjectileBrain.KillFlags.WALL | ProjectileBrain.KillFlags.HITBOX, proj_script, SHT_HVY_F_FRAMES, Vector2(-64.0, 0.0), FlipModes.ARD)
	#if frame >= 10.0:
		#return sm.states.IDL
	#return -1
#
#func sht_ntl_end() -> void:
	#pass
#
#endregion
#
#region TRAPS
#
#endregion
