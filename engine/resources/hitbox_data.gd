@tool
class_name HitboxData extends TriggerData


enum LaunchTypes{
	STN = 0,
	NML = 1,
	UPR = 2,
	HVY = 3,
	DNK = 4,
}

enum HitboxTypes{
	NML = 0,
	THW = 1,
	PWR = 2,
	SHT = 3,
	TRP = 4,
	HYP = 5,
}

enum AngleTypes{
	NML = 0,
	REV_XZ = 1,
	REV_X = 2,
	PLR_AWY = 3,
	PLR_AWY_XZ = 4,
	PLR_AWY_X = 5,
	PLR_TWD = 6,
	PLR_TWD_XZ = 7,
	PLR_TWD_X = 8,
	HBX_AWY = 9,
	HBX_AWY_XZ = 10,
	HBX_AWY_X = 11,
	HBX_TWD = 12,
	HBX_TWD_XZ = 13,
	HBX_TWD_X = 14,
}



var hit_damage: float
var hit_angle: Vector2
var hit_knockback: float
var hit_stun: float
var hit_lag: float
var shield_damage: float
var shield_knockback: float
var shield_stun: float
var shield_lag: float
var type_launch: LaunchTypes
var type_hitbox: HitboxTypes
var type_angle: AngleTypes


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	properties.append({
		"name": "Hitbox Data",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	properties.append({
		"name": "Hit Data",
		"type": TYPE_STRING,
		"hint_string": "hit",
		"usage": PROPERTY_USAGE_SUBGROUP
	})
	
	properties.append({
		"name": "hit_damage",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "hit_angle",
		"type": TYPE_VECTOR2,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "hit_knockback",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "hit_stun",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "hit_lag",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "Shield Data",
		"type": TYPE_STRING,
		"hint_string": "shield",
		"usage": PROPERTY_USAGE_SUBGROUP
	})
	
	properties.append({
		"name": "shield_damage",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "shield_knockback",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "shield_stun",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "shield_lag",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "Types",
		"type": TYPE_STRING,
		"hint_string": "type",
		"usage": PROPERTY_USAGE_SUBGROUP
	})
	
	properties.append({
		"name": "type_launch",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Stun, Normal, Upper, Heavy, Dunk",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "type_hitbox",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Normal, Throw, Power, Shot, Trap, Hyper",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "type_angle",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(AngleTypes.keys()),
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties
