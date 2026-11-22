class_name Main extends Node

var current_scene: Node

func _ready() -> void:
	Globals.main = self
	current_scene = $MatchScene
