class_name SonicDgA extends PlayerAction

func wake() -> void:
	super()

func start(old_state: int) -> void:
	super(old_state)

func update(delta: float) -> void:
	pass

func end(new_state: int) -> void:
	super(new_state)
