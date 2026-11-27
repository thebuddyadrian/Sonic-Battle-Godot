@tool
class_name FighterData extends Resource

@export var display_name: String
@export_group("File Paths")
@export_file var portrait_path: String
@export_file var life_icon_path: String
@export_group("Ground")
@export_subgroup("Walk", "walk")
@export var walk_speed: float = 10.0
@export var walk_acceleration: float = 2.0
@export var walk_deceleration: float = 3.0
@export var walk_startup_frames: int = 5
@export var walk_start_acceleration: float = 0.2
@export var walk_start_speed: float = 4.0
@export var walk_stop_frames: int = 14
@export_subgroup("Turn", "turn")
@export var turn_idle_frames: int = 9
@export var turn_walk_frames: int = 20
@export_subgroup("Land", "land")
@export var land_soft_lag: int = 4
@export var land_hard_lag: int = 20
@export var land_deceleration: float = 0.5
@export_subgroup("Dodge", "dodge")
@export var dodge_startup_frames: int = 4
@export var dodge_active_frames: int = 11
@export var dodge_endlag_frames: int = 14
@export var dodge_cooldown_frames: int = 20
@export var dodge_speed: float = 20.0
@export var dodge_acceleration: float = 10.0
@export var dodge_deceleration: float = 5.0
#TODO - Add dodge decay

#Air
@export_group("Air")
@export_subgroup("Movement", "air")
@export var air_speed: float = 8.0
@export var air_acceleration: float = 1.0
@export var air_deceleration: float = 0.2
@export_subgroup("Jump", "jump")
@export_subgroup("Jump/Squat", "jump_squat")
@export var jump_squat_frames: int = 3
@export var jump_squat_deceleration: float = 0.05
@export_subgroup("Jump/Short", "jump_short")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var jump_short_height: float = 3.0
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var jump_short_frames_to_peak: int = 20
@export_subgroup("Jump/Full", "jump_full")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var jump_full_height: float = 5.0
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var jump_full_frames_to_peak: int = 30
@export_subgroup("Fall", "fall")
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var fall_frames_to_descent: int = 25
@export var fall_fast_frames_to_descent: int = 15
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var fall_max_speed: float = 25.0
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var fall_fast_max_speed: float = 40.0

#Guard
#@export_group("Guard", "guard")
#@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var guard_startup_frames: float = 5.0
#@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var guard_active_frames: float = 15.0
#@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var guard_endlag_frames: float = 10.0
#@export var guard_blockstun: float = 30.0

#Grab
#@export_group("Grab", "grab")
#@export_subgroup("Idle", "grab_idle")
#@export var grab_idle_startup_frames: float = 6.0
#@export var grab_idle_active_frames: float = 2.0
#@export var grab_idle_endlag_frames: float = 27.0
#@export_subgroup("Dash", "grab_dash")
#@export var grab_dash_startup_frames: float = 9.0
#@export var grab_dash_active_frames: float = 2.0
#@export var grab_dash_endlag_frames: float = 32.0
#@export_subgroup("Pivot", "grab_pivot")
#@export var grab_pivot_startup_frames: float = 10.0
#@export var grab_pivot_active_frames: float = 2.0
#@export var grab_pivot_endlag_frames: float = 25.0

#Tech
@export_group("Tech", "tech")
@export_subgroup("Neutral", "tech_neutral")
@export var tech_neutral_invincibility_frames: float = 20.0
@export var tech_neutral_duration: float = 25.0
@export_subgroup("Roll", "tech_roll")
@export var tech_roll_invincibility_frames: float = 20.0
@export var tech_roll_duration: float = 35.0
@export var tech_roll_speed: float = 20.0
@export var tech_roll_deceleration: float = 10.0

#Heal
@export_group("Heal", "heal")
@export var heal_hp_rate: float = 5.0
@export var heal_hg_rate: float = 2.0
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var heal_startup_frames: float = 10.0
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var heal_endlag_frames: float = 15.0


#Combat
@export_group("Combat", "combat")
@export_range(100.0, 700.0, 1.0, "or_greater", "hide_control") var combat_max_hp: float = 300.0
@export_range(100.0, 200.0, 1.0, "or_greater", "hide_control") var combat_max_hg: float = 100.0
@export_range(1.0, 100.0, 1.0, "or_greater", "hide_control") var combat_atk: float = 100.0
@export_range(1.0, 100.0, 1.0, "or_greater", "hide_control") var combat_def: float = 100.0
@export var combat_weight: float = 100.0
@export var combat_hurtbox: HurtboxData
#Actions
@export_group("Actions", "act")
#region MOVEMENT
@export_subgroup("Dash", "act_dsh")
@export_file("*.tres") var act_dsh_gnd: String
@export_file("*.tres") var act_dsh_air: String
@export_subgroup("Defense", "act_def")
@export_file("*.tres") var act_def_grd: String
@export_file("*.tres") var act_def_hel: String
@export_subgroup("Dodge", "act_dge")
@export_file("*.tres") var act_dge_gnd: String
@export_file("*.tres") var act_dge_air: String
#endregion
#region GROUND ATTACKS
@export_subgroup("Attacks")
@export_subgroup("Attacks/Ground")
@export_subgroup("Attacks/Ground/Neutral", "act_atk_nt")
@export_file("*.tres") var act_atk_nt1: String
@export_file("*.tres") var act_atk_nt2: String
@export_file("*.tres") var act_atk_nt3: String
@export_subgroup("Attacks/Ground/Forward", "act_atk_fw")
@export_file("*.tres") var act_atk_fwl: String:
	get():
		return act_atk_fwh if !act_atk_fwl else act_atk_fwl
@export_file("*.tres") var act_atk_fwh: String
@export_subgroup("Attacks/Ground/Upper", "act_atk_up")
@export_file("*.tres") var act_atk_upl: String:
	get():
		return act_atk_uph if !act_atk_upl else act_atk_upl
@export_file("*.tres") var act_atk_uph: String
@export_subgroup("Attacks/Ground/Dash", "act_atk_dsh")
@export_file("*.tres") var act_atk_dsh: String
#endregion
#region AIR ATTACKS
@export_subgroup("Attacks/Air", "act_atk_ar")
@export_file("*.tres") var act_atk_arn: String
@export_file("*.tres") var act_atk_arf: String:
	get():
		return act_atk_arn if !act_atk_arf else act_atk_arf
@export_file("*.tres") var act_atk_aru: String:
	get():
		return act_atk_arn if !act_atk_aru else act_atk_aru
@export_file("*.tres") var act_atk_ara: String:
	get():
		return act_atk_arn if !act_atk_ara else act_atk_ara
@export_subgroup("Attacks/Air/Dunk", "act_atk_dnk")
@export_file("*.tres") var act_atk_dnk: String
#endregion
#region GROUND SPECIALS
@export_subgroup("Specials")
@export_subgroup("Specials/Ground")
@export_subgroup("Specials/Ground/Shot", "act_sht_gn")
@export_file("*.tres") var act_sht_gnn: String
@export_file("*.tres") var act_sht_gnf: String:
	get():
		return act_sht_gnn if !act_sht_gnf else act_sht_gnf
@export_file("*.tres") var act_sht_gnu: String:
	get():
		return act_sht_gnn if !act_sht_gnu else act_sht_gnu
@export_subgroup("Specials/Ground/Power", "act_pwr_gn")
@export_file("*.tres") var act_pwr_gnn: String
@export_file("*.tres") var act_pwr_gnf: String:
	get():
		return act_pwr_gnn if !act_pwr_gnf else act_pwr_gnf
@export_file("*.tres") var act_pwr_gnu: String:
	get():
		return act_pwr_gnn if !act_pwr_gnu else act_pwr_gnu
@export_subgroup("Specials/Ground/Trap", "act_trp_gn")
@export_file("*.tres") var act_trp_gnn: String
@export_file("*.tres") var act_trp_gnf: String:
	get():
		return act_trp_gnn if !act_trp_gnf else act_trp_gnf
@export_file("*.tres") var act_trp_gnu: String:
	get():
		return act_trp_gnn if !act_trp_gnu else act_trp_gnu
#endregion
#region AIR SPECIALS
@export_subgroup("Specials/Air")
@export_subgroup("Specials/Air/Shot", "act_sht_ar")
@export_file("*.tres") var act_sht_arn: String
@export_file("*.tres") var act_sht_arf: String:
	get():
		return act_sht_arn if !act_sht_arf else act_sht_arf
@export_file("*.tres") var act_sht_aru: String:
	get():
		return act_sht_arn if !act_sht_aru else act_sht_aru
@export_subgroup("Specials/Air/Power", "act_pwr_ar")
@export_file("*.tres") var act_pwr_arn: String
@export_file("*.tres") var act_pwr_arf: String:
	get():
		return act_pwr_arn if !act_pwr_arf else act_pwr_arf
@export_file("*.tres") var act_pwr_aru: String:
	get():
		return act_pwr_arn if !act_pwr_aru else act_pwr_aru
@export_subgroup("Specials/Air/Trap", "act_trp_ar")
@export_file("*.tres") var act_trp_arn: String
@export_file("*.tres") var act_trp_arf: String:
	get():
		return act_trp_arn if !act_trp_arf else act_trp_arf
@export_file("*.tres") var act_trp_aru: String:
	get():
		return act_trp_arn if !act_trp_aru else act_trp_aru
#endregion
#region DEFENSE SPECIALS
@export_subgroup("Specials/Defense", "act")
@export_file("*.tres") var act_sht_def: String:
	get():
		return act_sht_gnn if !act_sht_def else act_sht_def
@export_file("*.tres") var act_pwr_def: String:
	get():
		return act_pwr_gnn if !act_pwr_def else act_pwr_def
@export_file("*.tres") var act_trp_def: String:
	get():
		return act_trp_gnn if !act_trp_def else act_trp_def
#endregion
#region GRABS
@export_subgroup("Grabs", "act_grb")
@export_file("*.tres") var act_grb_idl: String
@export_file("*.tres") var act_grb_dsh: String:
	get():
		return act_grb_idl if !act_grb_dsh else act_grb_dsh
@export_file("*.tres") var act_grb_pvt: String:
	get():
		return act_grb_idl if !act_grb_pvt else act_grb_pvt
#endregion
#region THROWS
@export_subgroup("Throws", "act_thw")
@export_file("*.tres") var act_thw_fwd: String
@export_file("*.tres") var act_thw_bak: String
@export_file("*.tres") var act_thw_upr: String
@export_file("*.tres") var act_thw_dwn: String
#endregion


func get_walk_accel_amount() -> float:
	return (Globals.FPS*walk_acceleration)/walk_speed

func get_walk_decel_amount() -> float:
	return (Globals.FPS*walk_deceleration)/walk_speed

func get_air_accel_amount() -> float:
	return (Globals.FPS*air_acceleration)/air_speed

func get_air_decel_amount() -> float:
	return (Globals.FPS*air_deceleration)/air_speed

static func get_accel_amount(acceleration: float, speed: float) -> float:
	return (Globals.FPS*acceleration)/speed

func get_full_jump_force() -> float:
	return (2.0*jump_full_height)/(jump_full_frames_to_peak/Globals.FPS)

func get_full_jump_gravity() -> float:
	var time_to_peak: float = jump_full_frames_to_peak/Globals.FPS
	return (-2.0*jump_full_height)/(time_to_peak**2.0)

func get_short_jump_force() -> float:
	return (2.0*jump_short_height)/(jump_short_frames_to_peak/Globals.FPS)

func get_short_jump_gravity() -> float:
	var time_to_peak: float = jump_short_frames_to_peak/Globals.FPS
	return (-2.0*jump_short_height)/(time_to_peak**2.0)

func get_fall_gravity() -> float:
	var time_to_descent: float = fall_frames_to_descent/Globals.FPS
	return (-2.0*jump_full_height)/(time_to_descent**2.0)

func get_fast_fall_gravity() -> float:
	var time_to_descent: float = fall_fast_frames_to_descent/Globals.FPS
	return (-2.0*jump_full_height)/(time_to_descent**2.0)

static func get_gravity(height: float, frames_to_descent: float) -> float:
	var time_to_descent: float = (2.0*frames_to_descent)/Globals.FPS
	return (-2.0*height)/(time_to_descent**2.0)

static func get_jump_force(height: float, frames_to_apex: float) -> float:
	var time_to_apex: float = (2.0*frames_to_apex)/Globals.FPS
	return (2.0*height)/(time_to_apex)
