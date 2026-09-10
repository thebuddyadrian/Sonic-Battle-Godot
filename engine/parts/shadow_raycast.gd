extends RayCast3D

@onready var shadow: MeshInstance3D = $Shadow
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if is_colliding():
		shadow.global_position.y = get_collision_point().y
		shadow.visible = true
	else:
		shadow.visible = false
		#print_debug(get_collision_point())
