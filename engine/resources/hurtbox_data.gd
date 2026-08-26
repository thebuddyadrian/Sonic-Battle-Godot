@tool
class_name HurtboxData extends TriggerData


enum HurtboxModes{
	NRM,
	INT,
	INV,
	ARM,
}


var defense: float = 100.0
var weight: float = 100.0
var hurtbox_mode: HurtboxModes:
	set(value):
		hurtbox_mode = value
		notify_property_list_changed()
var armor: float = 0.0

func _init() -> void:
	monitorable = true
	monitoring = false

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary]
	
	properties.append({
		"name": "Hurtbox Data",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	properties.append({
		"name": "defense",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "weight",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "hurtbox_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Normal, Intangible, Invincible, Armor",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	if hurtbox_mode == HurtboxModes.ARM:
		properties.append({
			"name": "armor",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	
	return properties
