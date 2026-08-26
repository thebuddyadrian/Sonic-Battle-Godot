class_name PlayerAction extends Resource


var brain: PlayerBrain:
	set(value):
		brain = value
		if brain.data:
			data = brain.data
			sm = brain.sm
var data: PlayerData
var sm: PlayerStateMachine

@export var hitbox_groups: Dictionary[StringName, HitboxGroup]
@export var hurtbox_datas: Dictionary[StringName, HurtboxData]
@export var grabbox_datas: Dictionary[StringName, GrabboxData]
@export var guardbox_datas: Dictionary[StringName, GuardboxData]

var hitboxes: Dictionary[StringName, HitboxArea]
var hurtboxes: Dictionary[StringName, HurtboxArea]
var grabboxes: Dictionary[StringName, GrabboxArea]
var guardboxes: Dictionary[StringName, GuardboxArea]


func wake() -> void:
	for hitbox_group in hitbox_groups:
		for hitbox_data in hitbox_groups[hitbox_group].hitboxes:
			var hitbox: HitboxArea = HitboxArea.new(hitbox_data, brain, hitbox_groups[hitbox_group])
			hitboxes["%s/%s" % [hitbox_group, hitbox_groups[hitbox_group].hitboxes.find(hitbox_data)]] = hitbox
	for hurtbox_data in hurtbox_datas:
		var hurtbox: HurtboxArea = HurtboxArea.new(hurtbox_datas[hurtbox_data], brain)
		hurtboxes[hurtbox_data] = hurtbox
	for grabbox_data in grabbox_datas:
		var grabbox: GrabboxArea = GrabboxArea.new(grabbox_datas[grabbox_data], brain)
		grabboxes[grabbox_data] = grabbox
	for guardbox_data in guardbox_datas:
		var guardbox: GuardboxArea = GuardboxArea.new(guardbox_datas[guardbox_data], brain)
		guardboxes[guardbox_data] = guardbox

func start(old_state: int) -> void:
	for hitbox_group in hitbox_groups:
		hitbox_groups[hitbox_group].hit_log.clear_log()

func update(delta: float) -> void:
	sm.change_state(0)

func end(new_state: int) -> void:
	for hitbox in hitboxes:
		if hitboxes[hitbox].is_inside_tree():
			hitboxes[hitbox].deactivate()
	for hurtbox in hurtboxes:
		if hurtboxes[hurtbox].is_inside_tree():
			hurtboxes[hurtbox].deactivate()
	for grabbox in grabboxes:
		if grabboxes[grabbox].is_inside_tree():
			grabboxes[grabbox].deactivate()
	for guardbox in guardboxes:
		if guardboxes[guardbox].is_inside_tree():
			guardboxes[guardbox].deactivate()
	if !brain.hurtbox.is_inside_tree():
		brain.hurtbox.activate()
