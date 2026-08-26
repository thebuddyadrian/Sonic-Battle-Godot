@tool
class_name GrabboxData extends TriggerData


var endurance: float = 100.0
var strength: float = 100.0

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	properties.append({
		"name": "Grabbox Data",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	properties.append({
		"name": "endurance",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "strength",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties
