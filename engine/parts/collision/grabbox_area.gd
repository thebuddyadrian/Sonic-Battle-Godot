class_name GrabboxArea extends TriggerArea


signal grabbox_connected(self_box: GrabboxArea, other_box: HurtboxArea)

func _init(_data: GrabboxData, _owner: EntityBody) -> void:
	super(_data, _owner)
	debug_color = Color("ff8900ff")

func _on_box_entered(area: Area3D) -> void:
	super(area)
	if !(area is TriggerArea):
		return
	if area is HurtboxArea:
		var hurtbox: HurtboxArea = area
		var hurtbox_owner: PlayerBrain = hurtbox.hurtbox_owner
		if hurtbox_owner == box_owner:
			return
		if box_owner.grab_target != null:
			return
		if hurtbox_owner.grab_holder != null:
			return
		if [HurtboxData.HurtboxModes.INT, HurtboxData.HurtboxModes.INV].has(hurtbox.data.hurtbox_mode):
			return
		var hurtbox_sm: PlayerStateMachine = hurtbox_owner.sm
		var grabbox_sm: PlayerStateMachine = box_owner.sm
		
		grabbox_sm.change_state(grabbox_sm.states.GRB_HLD)
		hurtbox_sm.change_state(hurtbox_sm.states.STN_GRB)
		#hurtbox_owner.move_center_to_point(grab_point.global_position)
		#grabbox_owner.grab_target = hurtbox_owner
		#hurtbox_owner.grab_holder = grabbox_owner
		hurtbox_owner.collbox.set_deferred(&"disabled", true)
		grabbox_connected.emit(self, hurtbox)
		deactivate()
