@tool
class_name TriggerData extends Resource


var shape: Shape3D
var position: Vector3 = Vector3.ZERO
var anchor_rotation: Vector3 = Vector3.ZERO
var box_rotation: Vector3 = Vector3.ZERO
var scale: Vector3 = Vector3.ONE
var duration: float = 0.0
var rotation_mode: Globals.RotationModes = Globals.RotationModes.LTR
var priority: int = 0
var monitoring: bool = true
var monitorable: bool = true


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	properties.append({
		"name": "TriggerBox Data",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	properties.append({
		"name": "shape",
		"class_name": &"Shape3D",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Shape3D",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "position",
		"type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "anchor_rotation",
		"type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "box_rotation",
		"type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "scale",
		"type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "duration",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "rotation_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Static, Left-to-Right, All-Around",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "priority",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	if get_script().get_global_name() == &"TriggerData":
		properties.append({
			"name": "monitoring",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		
		properties.append({
			"name": "monitorable",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	
	return properties
