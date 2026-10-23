class_name SonicShtNtl extends PlayerAction

const PROJECTILE_COUNT: int = 3

var projectiles: Array[ProjectileBrain]


func wake() -> void:
	super()
	for i in PROJECTILE_COUNT-1:
		var projectile = preload("uid://dfw17qxhtryg7").instantiate()
		projectile.proj_owner = brain
		projectiles.append(projectile)

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"ShtNtl", true)

func update(delta: float) -> void:
	brain.walk(Vector3.ZERO, data.walk_speed, 0.0, data.get_walk_decel_amount(), delta)
	
	if brain.frame == 9.0:
		for projectile in projectiles:
			if !projectile.is_inside_tree():
				projectile.spawn({"dir": brain.global_facing_dir_h})
				break
	
	if brain.frame >= 29.0:
		sm.change_state(sm.states.IDL, "IDL")
