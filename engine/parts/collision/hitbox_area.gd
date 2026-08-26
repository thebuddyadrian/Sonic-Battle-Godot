class_name HitboxArea extends TriggerArea

var hit_group: HitboxGroup
var kb_angle: Vector2

func _init(_data: HitboxData, _owner: EntityBody, _hit_group: HitboxGroup = HitboxGroup.new()) -> void:
	super(_data, _owner)
	hit_group = _hit_group
	debug_color = Color("ff0000ff")

func get_data() -> HitboxData:
	return box_data as HitboxData

func reset() -> void:
	super()

func activate(data: Dictionary = {}) -> void:
	super(data)
	if data.has("clear"):
		if data.clear:
			hit_group.hit_log.clear_log()
	if data.has("aim"):
		kb_angle.x += get_kb_aim(data.aim)

func get_kb_aim(input_raw: Vector2) -> float:
	if input_raw.y*box_owner.global_facing_dir_h >= 0.7:
		return 270.0
	elif input_raw.y*box_owner.global_facing_dir_h <= -0.7:
		return 90.0
	else:
		return 0.0

func update_rotation() -> void:
	rotation_degrees = get_data().anchor_rotation
	var facing: float
	kb_angle = get_data().hit_angle
	match get_data().rotation_mode:
		Globals.RotationModes.STC:
			facing = 0.0
			kb_angle.x = -get_data().hit_angle.x
		Globals.RotationModes.LTR:
			if box_owner.global_facing_dir_h == -1.0:
				facing = PI
				kb_angle.x = 180-get_data().hit_angle.x
			else:
				facing = 0.0
				kb_angle.x = -get_data().hit_angle.x
		Globals.RotationModes.ARD:
			facing = snappedf(box_owner.global_facing_dir, PI/2)
			kb_angle.x += box_owner.global_facing_dir*(180/PI)
	rotation += Vector3.UP*facing


func create_angle(ang: Vector2) -> Vector2:
	var ang_x: float = ang.x*Globals.ANGLE_CONVERSION
	var ang_y: float = ang.y*Globals.ANGLE_CONVERSION
	return Vector2(ang_x, ang_y)

func get_damage(base_dmg: float, player_atk: float, target_def: float) -> float:
	return base_dmg*((player_atk+100.0)/(target_def+100.0))

func get_kb_normal(ang: Vector2) -> Vector3:
	var final_norm: Vector3 = Basis(Vector3.UP, ang.x).x
	final_norm = final_norm.rotated(Basis(Vector3.UP, ang.x).z, ang.y)
	return final_norm.normalized()

func get_kb_force(base_kb: float, weight: float) -> float:
	return base_kb*(200.0/(weight+100.0))

func get_launch_vel(target: TriggerArea, angle: Vector2, angle_type: HitboxData.AngleTypes, knockback: float, weight: float) -> Vector3:
	var final_vel: Vector3
	var xangle: Vector2
	var xdist: float
	var target_player: EntityBody = target.box_owner
	var player_pos: Vector3 = target_player.get_center()
	var owner_pos: Vector3 = box_owner.get_center()
	var self_pos: Vector3 = coll.global_position
	
	var kb: float = get_kb_force(knockback, weight)
	match angle_type:
		HitboxData.AngleTypes.NML:
			final_vel = get_kb_normal(Vector2(angle.x, angle.y))*kb
		HitboxData.AngleTypes.REV_XZ:
			final_vel = get_kb_normal(Vector2(angle.x+PI, angle.y))*kb
		HitboxData.AngleTypes.REV_X:
			final_vel = get_kb_normal(Vector2(-angle.x, angle.y))*kb
		HitboxData.AngleTypes.PLR_AWY:
			xangle.x = -Vector2(owner_pos.x, owner_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))
			xdist = Vector2(owner_pos.x, owner_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, player_pos.y-owner_pos.y).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.PLR_AWY_XZ:
			xangle.x = -Vector2(owner_pos.x, owner_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))
			xdist = Vector2(owner_pos.x, owner_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.PLR_AWY_X:
			xangle.x = -atan2(sin(angle.x), cos(Vector2(owner_pos.x, owner_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))))
			xdist = Vector2(owner_pos.x, owner_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.PLR_TWD:
			xangle.x = -Vector2(owner_pos.x, owner_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))+PI
			xdist = Vector2(owner_pos.x, owner_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, player_pos.y-owner_pos.y).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.PLR_TWD_XZ:
			xangle.x = -Vector2(owner_pos.x, owner_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))+PI
			xdist = Vector2(owner_pos.x, owner_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.PLR_TWD_X:
			xangle.x = -atan2(-sin(angle.x), cos(Vector2(owner_pos.x, owner_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))))+PI
			xdist = Vector2(owner_pos.x, owner_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.HBX_AWY:
			xangle.x = -Vector2(self_pos.x, self_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))
			xdist = Vector2(self_pos.x, self_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, player_pos.y-self_pos.y).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.HBX_AWY_XZ:
			xangle.x = -Vector2(self_pos.x, self_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))
			xdist = Vector2(self_pos.x, self_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.HBX_AWY_X:
			xangle.x = -atan2(sin(angle.x), cos(Vector2(self_pos.x, self_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))))
			xdist = Vector2(self_pos.x, self_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.HBX_TWD:
			xangle.x = -Vector2(self_pos.x, self_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))+PI
			xdist = Vector2(self_pos.x, self_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, player_pos.y-self_pos.y).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.HBX_TWD_XZ:
			xangle.x = -Vector2(self_pos.x, self_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))+PI
			xdist = Vector2(self_pos.x, self_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
		HitboxData.AngleTypes.HBX_TWD_X:
			xangle.x = -atan2(-sin(angle.x), cos(Vector2(self_pos.x, self_pos.z).angle_to_point(Vector2(player_pos.x, player_pos.z))))+PI
			xdist = Vector2(self_pos.x, self_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
			xangle.y = -Vector2(xdist, -sin(angle.y)).angle()
			final_vel = get_kb_normal(xangle)*kb
	return final_vel

func _on_box_entered(area: Area3D) -> void:
	if !(area is TriggerArea):
		return
	var area_owner: EntityBody = area.box_owner
	if area_owner == box_owner:
		return
	if hit_group.hit_log.has_hit(area_owner):
		return
	for box in get_overlapping_areas():
		if box is GuardboxArea:
			print(true)
	if area is GuardboxArea:
		var guardbox: GuardboxArea = area
		var launch_vel: Vector3 = get_launch_vel(guardbox, create_angle(Vector2.ZERO), HitboxData.AngleTypes.PLR_AWY_X, get_data().shield_knockback, guardbox.get_data().sturdiness)
		area_owner.pause_dur = get_data().shield_lag
		area_owner.pause_pos = area_owner.global_position
		area_owner.velocity = launch_vel
		area_owner.pause_vel = launch_vel
		box_owner.pause_dur = get_data().shield_lag
		box_owner.pause_pos = box_owner.global_position
		box_owner.pause_vel = box_owner.velocity
		guardbox.hitbox_entered.emit(self, get_data())
		return
	if area is HurtboxArea:
		var hurtbox: HurtboxArea = area
		if hurtbox.hurtbox_mode == HurtboxData.HurtboxModes.INT:
			return
		hit_group.hit_log.log_hit(area_owner)
		box_owner.pause_dur = get_data().hit_lag
		box_owner.pause_pos = box_owner.global_position
		box_owner.pause_vel = box_owner.velocity
		if hurtbox.hurtbox_mode == HurtboxData.HurtboxModes.INV:
			area_owner.pause_dur = get_data().hit_lag
			area_owner.pause_pos = area_owner.global_position
			area_owner.pause_vel = area_owner.velocity
			return
		var dmg: float
		dmg = get_damage(get_data().hit_damage, box_owner.data.combat_atk if box_owner is PlayerBrain else 100.0, hurtbox.defense)
		if area_owner is PlayerBrain:
			area_owner.hgauge += dmg/8.0
		if hurtbox.hurtbox_mode == HurtboxData.HurtboxModes.ARM && dmg <= hurtbox.armor:
			area_owner.pause_dur = get_data().hit_lag
			area_owner.pause_pos = area_owner.global_position
			area_owner.pause_vel = area_owner.velocity
			return
		var launch_vel: Vector3 = get_launch_vel(hurtbox, create_angle(kb_angle), get_data().type_angle, get_data().hit_knockback, hurtbox.weight)
		area_owner.pause_dur = get_data().hit_lag
		area_owner.pause_pos = area_owner.global_position
		area_owner.velocity = launch_vel
		area_owner.pause_vel = launch_vel
		if area_owner is PlayerBrain:
			area_owner.stun = get_data().hit_stun
			area_owner.knockback = launch_vel
			area_owner.health -= dmg
			match get_data().type_launch:
				HitboxData.LaunchTypes.STN:
					area_owner.sm.change_state(area_owner.sm.states.STN_HIT)
				HitboxData.LaunchTypes.NML:
					area_owner.sm.change_state(area_owner.sm.states.LNC_NML)
				HitboxData.LaunchTypes.HVY:
					area_owner.sm.change_state(area_owner.sm.states.LNC_HVY)
				HitboxData.LaunchTypes.UPR:
					area_owner.sm.change_state(area_owner.sm.states.LNC_UPR)
				HitboxData.LaunchTypes.DNK:
					area_owner.sm.change_state(area_owner.sm.states.LNC_DNK)
		if get_data().type_launch == HitboxData.LaunchTypes.HVY:
			box_owner.chase_window = PlayerBrain.CHASE_WINDOW_FRAMES
			box_owner.chase_target = area_owner
			area_owner.chase_window = PlayerBrain.CHASE_WINDOW_FRAMES
			area_owner.chase_target = box_owner
	'''var player: PlayerBrain = area.owner
	if hb_owner == player:
		return
	var dmg: float = get_damage(player.data.combat_def)
	if !player_list.has(player):
		player_list.append(player)
		if area.collision_layer == GUARDBOX_LAYER:
			if dmg >= player.data.guard_strength+40.0:
				player.sm.set_state(player.sm.states.STN_BRK)
				player.health -= get_damage(1.0)
				hb_owner.sgauge += (get_damage(1.0)/4.0)*hb_owner.data.combat_sgauge_mult
				player.stun = floorf(hitstun*2.5*player.data.combat_atk_mult)
				player.velocity = Basis(Vector3.UP, hb_owner.global_facing_dir).x * -10.0
			else:
				player.sgauge += (get_damage(1.0)/2.0)*player.data.combat_sgauge_mult
				hb_owner.sm.set_state(hb_owner.sm.states.STN_BLK)
				hb_owner.stun = floorf(player.data.guard_blockstun/hb_owner.data.combat_blockstun_res)
				hb_owner.velocity = Basis(Vector3.UP, hb_owner.global_facing_dir).x * -5.0
		else:
			if dmg > player.dmg_armor:
				player.health -= dmg
			player.sgauge += (dmg/8.0)*player.data.combat_sgauge_mult
			if player.sm.state == player.sm.states.STN_GRB && hb_type != HitboxTypes.THW:
				return
			if dmg > player.flinch_armor:
				var launch_vel: Vector3
				player.stun = hitstun/player.data.combat_kb_res
				launch_vel = get_launch_vel(area, player.data.combat_kb_res)
				player.sm.hit_freeze(hitlag, launch_vel, launch_type)
				player.sm.set_state(player.sm.states.HIT_FRZ)
				if launch_type == LaunchTypes.HVY:
					hb_owner.chase_window = PlayerBrain.CHASE_WINDOW_FRAMES
					hb_owner.chase_target = player
					player.chase_window = PlayerBrain.CHASE_WINDOW_FRAMES
					player.chase_target = hb_owner
				hb_owner.pause_dur = hitlag
				hb_owner.pause_pos = hb_owner.global_position
				hb_owner.pause_vel = hb_owner.velocity
			hb_owner.sgauge += (get_damage(1.0)/4.0)*hb_owner.data.combat_sgauge_mult'''
