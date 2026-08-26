extends CanvasLayer

@onready var lifebar: TextureProgressBar = $Lifebar
@onready var icon: Sprite2D = $Lifebar/Icon
@onready var stock_label: Label = $StockLabel
@onready var pause_menu: Control = $Pause
@onready var player_id_label: Label = $PlayerIDLabel

var player_tracking: PlayerBrain


func track_player(player: PlayerBrain):
	icon.texture = load(GameData.get_character_info(player.char_name).life_icon_path)
	lifebar.max_value = player.data.combat_max_hp
	player_tracking = player
	pause_menu.player_id = player.player_id
	player_id_label.text = "P" + str(player.player_id)


func _process(delta):
	if player_tracking:
		lifebar.value = player_tracking.health
	#stock_label.text = str(player_tracking.current_stocks)
