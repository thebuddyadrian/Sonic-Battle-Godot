extends Node

var _fighter_data_dict: Dictionary[String, FighterData]
var _stage_data_dict: Dictionary[String, StageData]

# TO-DO store fighters in a list resource instead of storing it here in an array
var fighters: Array[String] = [
	"sonic", 
	#"tails", 
	#"knuckles", 
	#"shadow",
	# "kid_goku",
	#"rouge",
	#"amy",
	#"cream",
	#"emerl"
]

# TO-DO do the same with the stages
var battle_stages: Array[String] = [
	"test_stage",
	# "emeraldbeach", 
	# "amysroom", 
	# "battlehwy", 
	# "chaoruins",
	# "hologram",
	# "holysummit",
	# "greenhill"
]

var modded_battle_stages: Array[String]


func _init() -> void:
	# Preload all FighterData resources
	for fighter in fighters:
		_fighter_data_dict[fighter] = load("res://fighters/%s/resources/%s_data.tres" % [fighter, fighter])
	for stage in battle_stages:
		_stage_data_dict[stage] = load("res://stages/%s/%s.tres" % [stage, stage])


func _ready() -> void:
	# Load modded stages
	var game_folder = OS.get_executable_path()
	game_folder = game_folder.trim_suffix(game_folder.split("/")[-1])
	print("Game folder is at: " + game_folder)
	var stage_mods_folder = game_folder + "mods/stages"
	var dir = DirAccess.open(stage_mods_folder)
	if dir:
		print("Opened folder " + stage_mods_folder)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				if file_name.ends_with(".pck"):
					print("Found stage mod PCK: " + stage_mods_folder + file_name)
					var success = ProjectSettings.load_resource_pack("res://mods/stages/" + file_name)
					if success:
						print("Successfully loaded stage mod " + file_name)
						var stage_name = file_name.trim_suffix(".pck")
						# Add stage to "modded_battle_stages" array
						modded_battle_stages.append(stage_name)
					else:
						print("Could not load stage mod " + file_name)
			file_name = dir.get_next()
	else:
		print("Failed to open " + stage_mods_folder)


func get_fighter_data(fighter_name: String):
	assert(_fighter_data_dict.has(fighter_name), "Cannot find FighterData for %s" % fighter_name)
	return _fighter_data_dict[fighter_name]


func get_stage_data(stage_name: String):
	assert(_stage_data_dict.has(stage_name), "Cannot find StageData for %s" % stage_name)
	return _stage_data_dict[stage_name]
