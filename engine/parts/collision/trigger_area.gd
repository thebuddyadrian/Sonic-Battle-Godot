class_name TriggerArea extends Area3D


var box_data: TriggerData
var box_owner: EntityBody

var frame: float

var coll: CollisionShape3D = CollisionShape3D.new()

var debug_color: Color:
	set(value):
		debug_color = value
		coll.debug_color = debug_color

signal trigger_entered(self_box: TriggerArea, other_box: TriggerArea)

func _init(_data: TriggerData, _owner: EntityBody) -> void:
	box_data = _data
	box_owner = _owner
	debug_color = Color("0000ffff")

func _ready() -> void:
	area_entered.connect(_on_box_entered)
	monitorable = get_data().monitorable
	monitoring = get_data().monitoring
	coll.shape = get_data().shape
	coll.debug_color = debug_color
	coll.debug_fill = true
	add_child(coll)
	reset()

func reset() -> void:
	frame = 0.0
	coll.position = box_data.position
	coll.rotation_degrees = box_data.box_rotation
	scale = get_data().scale
	priority = get_data().priority
	update_rotation()

func get_data() -> TriggerData:
	return box_data as TriggerData

func update_rotation() -> void:
	rotation_degrees = get_data().anchor_rotation
	var facing: float
	match get_data().rotation_mode:
		Globals.RotationModes.STC:
			facing = 0.0
		Globals.RotationModes.LTR:
			if box_owner.global_facing_dir_h == -1.0:
				facing = PI
			else:
				facing = 0.0
		Globals.RotationModes.ARD:
			facing = snappedf(box_owner.global_facing_dir, PI/2)
	rotation += Vector3.UP*facing

func activate(data: Dictionary = {}) -> void:
	reset()
	if !is_inside_tree():
		box_owner.add_child(self)

func deactivate() -> void:
	if is_inside_tree():
		box_owner.remove_child(self)

func _physics_process(delta: float) -> void:
	if box_owner.pause_dur == 0.0:
		frame += floorf(delta*Globals.FPS)
	if frame >= get_data().duration && get_data().duration > 0.0:
		deactivate()
		
func _on_box_entered(area: Area3D) -> void:
	if !(area is TriggerArea):
		return
	trigger_entered.emit(self, area)
