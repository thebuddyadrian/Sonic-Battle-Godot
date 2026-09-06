@tool
class_name GuardboxData extends TriggerData


var parry_frames: float = 7.0
var health: float = 100.0
var defense: float = 100.0
var sturdiness: float = 100.0

func _init() -> void:
	monitorable = true
	monitoring = false

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary]
	
	properties.append({
		"name": "Guardbox Data",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	properties.append({
		"name": "parry_frames",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "health",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "defense",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "sturdiness",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties
