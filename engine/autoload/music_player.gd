extends AudioStreamPlayer


func _ready() -> void:
	bus = "BGM"


func play_track(audio_stream: AudioStream):
	stop()
	stream = audio_stream
	play()
