extends Control

signal request_cursor_anim(anim_name)

# If there's a player selecting a fighter using this node
var active: bool = false: set = set_active
var is_cpu: bool = false
var fighter_index: int = 0 : set = set_fighter_index
var fighter: String : set = set_fighter

var css_ready : bool = false


@export var player_number: int = 1

@onready var fighter_selected: Label = $FighterSelected
@onready var reference_rect: ReferenceRect = $ReferenceRect
@onready var fighter_portrait: TextureRect = $Portrait_Manager/Fighters
@onready var pixelate: AnimationPlayer = $Portrait_Manager/pixelate
@onready var confirm_sprite : TextureRect = $ConfirmSprite
@onready var cursor_arrows: Control = $CursorArrows
@onready var cursor_arrows_animplayer: AnimationPlayer = $CursorArrows/AnimationPlayer

signal selection_finished(plrnum)


func _ready() -> void:
	#player_name.text = "Player " + str(player_number)
	set_active(active)
	set_fighter_index(fighter_index)
	# Make sure the shader material isn't shared between fighters
	fighter_portrait.material = fighter_portrait.material.duplicate()

	if MatchSetup.is_playing_solo() or is_cpu:
		cursor_arrows.visible = false


func _process(delta: float) -> void:
	if !active:
		return
	if get_input("ui_left"):
		fighter_index -= 1
		play_cursor_anim("ArrowBumpLeft")
	if get_input("ui_right"):
		fighter_index += 1
		play_cursor_anim("ArrowRightBump")
	if get_input("ui_accept"):
		selection_finished.emit(player_number)
		confirm_sprite.visible = true
		cursor_arrows.visible = false


func get_input(action: String) -> bool:
	# If this is a CPU player, use player 1 controls
	var input_player_number: int = player_number if !is_cpu else 1
	return PlayerInput.player_action_just_pressed(action, input_player_number)


func play_cursor_anim(anim):
	if MatchSetup.is_playing_solo():
		request_cursor_anim.emit(anim)
	else:
		var animplayer = cursor_arrows.get_node("AnimationPlayer")
		animplayer.stop()
		animplayer.play(anim)


func set_active(p_active: bool):
	active = p_active
	reference_rect.visible = active


func set_fighter_index(p_index: int):
	fighter_index = p_index
	if fighter_index < 0:
		fighter_index = GameData.fighters.size() - 1
	if fighter_index >= GameData.fighters.size():
		fighter_index = 0
	set_fighter(GameData.fighters[fighter_index])


func set_fighter(p_fighter: String):
	# Load texture for already selected fighter, in case the last transition was interrupted
	if fighter != "":
		var old_fighter_data: FighterData = GameData.get_fighter_data(fighter)
		if fighter_portrait.texture.resource_path != old_fighter_data.portrait_path:
			fighter_portrait.texture = load(old_fighter_data.portrait_path)

	fighter = p_fighter
	fighter_selected.text = "Fighter:\n" + GameData.get_fighter_data(fighter).display_name
	var fighter_data: FighterData = GameData.get_fighter_data(fighter)
	pixelate.stop()
	pixelate.play("pixelate")
	await get_tree().create_timer(0.4).timeout
	fighter_portrait.texture = load(fighter_data.portrait_path)


func load_fighter_portrait(p_fighter: String):
	var fighter_data: FighterData = GameData.get_fighter_data(p_fighter)
	fighter_portrait.texture = load(fighter_data.portrait_path)
