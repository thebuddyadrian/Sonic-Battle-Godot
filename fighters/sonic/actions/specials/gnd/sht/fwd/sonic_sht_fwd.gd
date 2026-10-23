class_name SonicShtFwd extends PlayerAction


var projectile: ProjectileBrain


func wake() -> void:
	super()
	if !is_instance_valid(projectile):
		projectile = preload("uid://7hti6ws4mkfo").instantiate()
		projectile.proj_owner = brain

func start(old_state: int) -> void:
	super(old_state)
	brain.play_anim(&"ShtFwd", true)
	var dir_y: float = sin(fposmod((brain.cam.global_rotation.y - brain.global_facing_dir), 2*PI))
	if dir_y < -0.8:
		pass
	elif dir_y > 0.8:
		pass
	else:
		pass

func update(delta: float) -> void:
	if brain.frame < 24.0:
		brain.walk(Vector3.ZERO, data.walk_speed, 0.0, data.get_walk_decel_amount(), delta)
	
	if brain.frame == 24.0:
		brain.velocity = Basis(Vector3.UP, brain.global_facing_dir).x*-5.0
		brain.velocity.y = 17.0
		projectile.spawn({"dir": brain.global_facing_dir})
	
	if brain.frame >= 48.0:
		sm.change_state(sm.states.AIR, "FAL_NRM")
	elif brain.frame >= 24.0:
		brain.apply_gravity(delta, data.get_fall_gravity(), data.fall_max_speed)

func end(new_state: int) -> void:
	super(new_state)
