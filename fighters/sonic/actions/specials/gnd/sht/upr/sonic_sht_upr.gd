class_name SonicShtUpr extends PlayerAction


var projectile: ProjectileBrain


func wake() -> void:
	super()
	if !is_instance_valid(projectile):
		#projectile = preload("uid://b34gnlyqyduvx").instantiate()
		projectile.proj_owner = brain

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"ShtUpr", true)

func update(delta: float) -> void:
	brain.walk(Vector3.ZERO, data.walk_speed, 0.0, data.get_walk_decel_amount(), delta)
	
	if brain.frame == 13.0:
		projectile.spawn({"dir": brain.global_facing_dir_h})
	
	if brain.frame >= 37.0:
		sm.change_state(sm.states.IDL, "IDL")

func end(new_state: int) -> void:
	super(new_state)
