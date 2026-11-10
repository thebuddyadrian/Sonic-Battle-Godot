@tool
extends Resource
class_name StageInfo

## The name that will be shown in the stage select screen.
@export var display_name: String = ""
## The file path for the music track.
@export_file var music_file_path: String
## File path for the stage scene.
@export_file var stage_scene_path: String

