class_name ProjectileBrain extends EntityBody


@export var hitbox_groups: Dictionary[StringName, HitboxGroup]
@export var hurtbox_datas: Dictionary[StringName, HurtboxData]
@export var grabbox_datas: Dictionary[StringName, GrabboxData]



var hitboxes: Dictionary[StringName, HitboxArea]
var hurtboxes: Dictionary[StringName, HurtboxArea]
var grabboxes: Dictionary[StringName, GrabboxArea]

var proj_owner: EntityBody


signal on_hit_entity(entity: EntityBody)
signal on_hit_wall(normal: Vector3)
signal on_hit_floor(normal: Vector3)


func _ready() -> void:
	wake()

func wake() -> void:
	#super()
	on_hit_entity.connect(_on_hit_entity)
	on_hit_wall.connect(_on_hit_wall)
	on_hit_floor.connect(_on_hit_floor)
	for hitbox_group in hitbox_groups:
		for hitbox_data in hitbox_groups[hitbox_group].hitboxes:
			var hitbox: HitboxArea = HitboxArea.new(hitbox_data, self, hitbox_groups[hitbox_group])
			hitboxes["%s/%s" % [hitbox_group, hitbox_groups[hitbox_group].hitboxes.find(hitbox_data)]] = hitbox
	for hurtbox_data in hurtbox_datas:
		var hurtbox: HurtboxArea = HurtboxArea.new(hurtbox_datas[hurtbox_data], self)
		hurtboxes[hurtbox_data] = hurtbox
	for grabbox_data in grabbox_datas:
		var grabbox: GrabboxArea = GrabboxArea.new(grabbox_datas[grabbox_data], self)
		grabboxes[grabbox_data] = grabbox
	start()

func start() -> void:
	pass

func _physics_process(delta: float) -> void:
	update_freeze(delta)
	update(delta)

func update(delta: float) -> void:
	var delta_frame: float = floorf(delta*60.0)
	if pause_dur == 0.0:
		frame += delta_frame
		if move_and_slide():
			if is_on_floor():
				on_hit_floor.emit(get_floor_normal())
			if is_on_wall():
				on_hit_wall.emit(get_wall_normal())
		update_projectile(delta)

func update_projectile(delta: float) -> void:
	pass

func spawn(data: Dictionary = {}) -> void:
	frame = 0.0
	if !is_inside_tree():
		proj_owner.add_child(self)

func despawn() -> void:
	if pause_dur > 0.0:
		await pause_finished
	if is_inside_tree():
		proj_owner.remove_child.call_deferred(self)

func _on_hit_entity(entity: EntityBody) -> void:
	pass

func _on_hit_wall(normal: Vector3) -> void:
	pass

func _on_hit_floor(normal: Vector3) -> void:
	pass
