extends Node3D
class_name MatchScene

const CAMERA_ROOT = preload("uid://dgswtfbyqn45x") # player_camera.tscn
const PLAYER_WINDOW = preload("uid://dhw76smlt6230") # player_window.tscn
const PLAYER_HUD = preload("uid://bsemd68skb2c1") # player_hud.tscn
const PAUSE_MENU = preload("uid://cifkfj62fb1ho") # pause.tscn

const LOG_FILE_DIRECTORY = 'user://detailed_logs'

var logging_enabled: bool = true


@onready var main_menu: HBoxContainer = $CanvasLayer/MainMenu
@onready var connection_window: Window = $CanvasLayer/ConnectionWindow
@onready var host_field: LineEdit = $CanvasLayer/ConnectionWindow/GridContainer/HostField
@onready var port_field: LineEdit = $CanvasLayer/ConnectionWindow/GridContainer/PortField
@onready var server_button: Button = $CanvasLayer/ConnectionWindow/GridContainer/ServerButton
@onready var client_button: Button = $CanvasLayer/ConnectionWindow/GridContainer/ClientButton
@onready var local_button: Button = $CanvasLayer/MainMenu/LocalButton
@onready var online_button: Button = $CanvasLayer/MainMenu/OnlineButton
@onready var message_label: Label = $CanvasLayer/MessageLabel
@onready var reset_button: Button = $CanvasLayer/ResetButton
@onready var sync_lost_label: Label = $CanvasLayer/SyncLostLabel


@export var test_fighters: Array[String] = ["sonic", "sonic"]
@export var test_stage: String

var stage: BaseStage
var camera_pivots: Dictionary[int, Node3D]
var cameras: Dictionary[int, BattleCamera]
var players: Dictionary[int, FighterBrain]
var original_content_scale_size: Vector2i


func _ready() -> void:
	#if MatchSetup.single_window:
		#original_content_scale_size = get_window().content_scale_size
		# Double the content size to allow split screen
		#get_window().content_scale_size *= 2
	#else:
		# Make sure subwindows aren't embedded, or else multiple windows wont spawn
		#get_viewport().gui_embed_subwindows = false
	ControlsSettings.load_all_button_layouts()
	ControlsSettings.load_controls_settings()
	ControlsSettings.apply_button_layouts()
	MatchResults.results.clear()
	
	server_button.pressed.connect(_on_server_button_pressed)
	client_button.pressed.connect(_on_client_button_pressed)
	local_button.pressed.connect(_on_local_button_pressed)
	online_button.pressed.connect(_on_online_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	SyncManager.sync_started.connect(_on_sync_manager_sync_started)
	SyncManager.sync_stopped.connect(_on_sync_manager_sync_stopped)
	SyncManager.sync_lost.connect(_on_sync_manager_sync_lost)
	SyncManager.sync_regained.connect(_on_sync_manager_sync_regained)
	SyncManager.sync_error.connect(_on_sync_manager_sync_error)
	initialize_match()

func initialize_match():
	# If no fighters have been selected, use test fighters
	if MatchSetup.fighter_choices.is_empty():
		MatchSetup.human_players = test_fighters.size()
		for i in range(test_fighters.size()):
			MatchSetup.fighter_choices[i + 1] = test_fighters[i]
			MatchSetup.current_stage_index = 0
			MatchSetup.stage_list = [test_stage]

	# Load Stage
	var current_stage: String = MatchSetup.stage_list[MatchSetup.current_stage_index]
	var stage_data: StageData = GameData.get_stage_data(current_stage)
	print("Loading stage \"%s\"" % current_stage)
	var stage_scene: PackedScene = load(stage_data.stage_scene_path)
	stage = stage_scene.instantiate()
	add_child(stage)

	# Get music track
	if stage and stage.stage_data:
		if stage.stage_data.music_file_path:
			print("Loading music track %s" % stage.stage_data.music_file_path)
			MusicPlayer.play_track(load(stage.stage_data.music_file_path))

	# Spawn cameras
	for i in range(MatchSetup.get_total_players()):
		var camera_root = CAMERA_ROOT.instantiate()
		if MatchSetup.single_window:
			var viewport = SubViewport.new()
			viewport.size = Vector2(240,160)
			viewport.audio_listener_enable_3d = true
			var subviewport_container = get_node("%SubViewportContainer" + str(i + 1))
			subviewport_container.add_child(viewport)
			viewport.add_child(camera_root)
		else:
			# For players 2-4, spawn a separate window
			#if i > 0 or MatchSetup.single_window:
				#var window = PLAYER_WINDOW.instantiate()
				#stage.camera_root_parent.add_child(window)
				#window.add_child(camera_root)
			#else:
			stage.camera_root_parent.add_child(camera_root)
		camera_root.name = "CameraRoot" + str(i + 1)
		var camera_pivot: Node3D = camera_root.get_node("Pivot")
		var camera: BattleCamera = camera_root.get_node("Pivot/Camera")
		camera_pivots[i] = camera_pivot
		cameras[i] = camera
		camera.match_scene = self

	# Spawn fighters
	assert(stage.player_spawn_1, "No spawn position has been placed for player 1")
	assert(stage.player_spawn_2, "No spawn position has been placed for player 2")
	assert(stage.player_spawn_3, "No spawn position has been placed for player 3")
	assert(stage.player_spawn_4, "No spawn position has been placed for player 4")
	for i in range(MatchSetup.get_total_players()):
		var fighter = MatchSetup.fighter_choices[i + 1]
		var spawn_position: Node3D = stage.get("player_spawn_%s" % str(i + 1))
		var player: FighterBrain = preload("res://fighters/sonic/fighter_sonic.tscn").instantiate()
		players[i] = player
		stage.add_child(player)
		player.cam_pivot = camera_pivots[i]
		player.cam = cameras[i]
		player.player_id = i + 1
		cameras[i].player_id_to_track = i + 1
		player.name = str(i+1)
		player.fighter_name = fighter
		player.kod.connect(_on_player_kod)
		player.global_position = spawn_position.global_position
		player.wake()
		player.sm.change_state(player.sm.states.IDL)
		
		

		# Spawn HUD
		#var player_hud = PLAYER_HUD.instantiate()
		#cameras[i].add_child(player_hud)
		#player_hud.track_player(player)

func _get_alive_player_count():
	var count: int = 0
	for i in players:
		if players[i].points > 0:
			count += 1
	return count


func _on_player_kod(player: FighterBrain):
	# Your placement depends on how many players were alive when you got KO'd
	MatchResults.results[player.player_id] = _get_alive_player_count() + 1
	if _get_alive_player_count() <= 1:
		# Add the winner player
		for i in players:
			if players[i].points > 0:
				MatchResults.results[players[i].player_id] = 1
		_go_to_results_screen()


func _go_to_results_screen():
	SceneChanger.change_scene_to_file("res://menus/results_screen/results_screen.tscn")

#func _exit_tree() -> void:
	# Restore original content scale size
	#get_window().content_scale_size = original_content_scale_size

func setup_match_for_replay(my_peer_id: int, peer_ids: Array, match_info: Dictionary) -> void:
	main_menu.visible = false
	connection_window.visible = false
	reset_button.visible = false
	initialize_match()

func _on_server_button_pressed() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_server(int(port_field.text))
	multiplayer.multiplayer_peer = peer
	main_menu.visible = false
	connection_window.visible = false
	message_label.text = "Listening..."

func _on_client_button_pressed() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_client(host_field.text, int(port_field.text))
	multiplayer.multiplayer_peer = peer
	main_menu.visible = false
	connection_window.visible = false
	message_label.text = "Connecting..."

func _on_peer_connected(peer_id: int):
	message_label.text = "Connected!"
	SyncManager.add_peer(peer_id)
	
	players[0].set_multiplayer_authority(1)
	if multiplayer.is_server():
		players[1].set_multiplayer_authority(peer_id)
	else:
		players[1].set_multiplayer_authority(multiplayer.get_unique_id())
	
	for i in players:
		if players[i].is_multiplayer_authority():
			cameras[i].make_current()
	
	if multiplayer.is_server():
		message_label.text = "Starting..."
		await get_tree().create_timer(2.0).timeout
		SyncManager.start()

func _on_peer_disconnected(peer_id: int):
	message_label.text = "Disconnected"
	SyncManager.remove_peer(peer_id)

func _on_server_disconnected() -> void:
	_on_peer_disconnected(1)

func _on_reset_button_pressed() -> void:
	SyncManager.stop()
	SyncManager.clear_peers()
	var peer = multiplayer.multiplayer_peer
	if peer:
		peer.close()
	get_tree().reload_current_scene()

func _on_sync_manager_sync_started() -> void:
	message_label.text = "Started!"
	
	if logging_enabled && !SyncReplay.active:
		if !DirAccess.dir_exists_absolute(LOG_FILE_DIRECTORY):
			DirAccess.make_dir_absolute(LOG_FILE_DIRECTORY)
		
		var datetime = Time.get_datetime_dict_from_system()
		var log_file_name = "%04d%02d%02d-%02d%02d%02d-peer-%d.log" % [
			datetime.year,
			datetime.month,
			datetime.day,
			datetime.hour,
			datetime.minute,
			datetime.second,
			multiplayer.get_unique_id()
		]
		
		SyncManager.start_logging(LOG_FILE_DIRECTORY + '/' + log_file_name, {})

func _on_sync_manager_sync_stopped() -> void:
	if logging_enabled:
		SyncManager.stop_logging()

func _on_sync_manager_sync_lost() -> void:
	sync_lost_label.visible = true

func _on_sync_manager_sync_regained() -> void:
	sync_lost_label.visible = false

func _on_sync_manager_sync_error(msg: String) -> void:
	message_label.text = "Fatal sync error:" + msg
	sync_lost_label.visible = false
	
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer
	if peer:
		peer.close()
	SyncManager.clear_peers()

func _on_local_button_pressed() -> void:
	pass

func _on_online_button_pressed() -> void:
	connection_window.popup_centered()
