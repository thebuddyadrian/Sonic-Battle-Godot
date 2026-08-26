class_name HurtboxArea extends TriggerArea



var hurtbox_mode: HurtboxData.HurtboxModes:
	set(value):
		hurtbox_mode = value
		match value:
			HurtboxData.HurtboxModes.NRM:
				debug_color = Color("00ff00ff")
			HurtboxData.HurtboxModes.INT:
				debug_color = Color("00ffffff")
			HurtboxData.HurtboxModes.INV:
				debug_color = Color("7200ffff")
			HurtboxData.HurtboxModes.INT:
				debug_color = Color("545454ff")
var weight: float
var defense: float
var armor: float = 0.0:
	set(value):
		if hurtbox_mode == HurtboxData.HurtboxModes.ARM:
			armor = value
			return
		armor = 0.0


func _init(_data: HurtboxData, _owner: EntityBody) -> void:
	super(_data, _owner)
	monitoring = false
	monitorable = true

func get_data() -> HurtboxData:
	return box_data as HurtboxData

func reset() -> void:
	super()
	weight = get_data().weight
	defense = get_data().defense
	hurtbox_mode = get_data().hurtbox_mode

func activate(data: Dictionary = {}) -> void:
	if data.has("weight"):
		weight = data.weight
	if data.has("defense"):
		defense = data.defense
	super(data)
