class_name GuardboxArea extends TriggerArea


signal hitbox_entered(hitbox: HitboxArea, hitbox_data: HitboxData)

func _init(_data: GuardboxData, _owner: EntityBody) -> void:
	super(_data, _owner)
	monitorable = true
	monitoring = false
