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
@export var walk_startup_frames: float = 5.0
@export var walk_start_acceleration: float = 0.2
@export var walk_start_speed: float = 4.0
@export var walk_stop_frames: float = 14.0
@export_subgroup("Turn", "turn")
@export var turn_idle_frames: float = 9.0
@export var turn_walk_frames: float = 20.0
@export_subgroup("Land", "land")
@export var land_soft_lag: float = 4.0
@export var land_hard_lag: float = 20.0
@export var land_deceleration: float = 0.5
@export_subgroup("Dodge", "dodge")
@export var dodge_startup_frames: float = 4.0
@export var dodge_active_frames: float = 11.0
@export var dodge_endlag_frames: float = 14.0
@export var dodge_cooldown_frames: float = 20.0
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
@export var jump_squat_frames: float = 3.0
@export var jump_squat_deceleration: float = 0.05
@export_subgroup("Jump/Short", "jump_short")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var jump_short_height: float = 3.0
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var jump_short_frames_to_peak: float = 20.0
@export_subgroup("Jump/Full", "jump_full")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var jump_full_height: float = 5.0
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var jump_full_frames_to_peak: float = 30.0
@export_subgroup("Fall", "fall")
@export_custom(PROPERTY_HINT_RANGE, "0,1,1,or_greater,hide_slider,suffix:f") var fall_frames_to_descent: float = 25.0
@export var fall_fast_frames_to_descent: float = 15.0
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
@export_group("Actions")
#region MOVEMENT
@export_subgroup("Movement", "mov")
@export_subgroup("Movement/Mobility", "mov_mob")
@export var mov_mob_dsh: FighterAction
@export var mov_mob_air: FighterAction
@export_subgroup("Movement/Defense", "mov_def")
@export var mov_def_grd: FighterAction
@export var mov_def_hel: FighterAction
@export_subgroup("Movement/Dodge", "mov_dge")
@export var mov_dge_gnd: FighterAction
@export var mov_dge_air: FighterAction
#endregion
#region GROUND ATTACKS
@export_subgroup("Attacks")
@export_subgroup("Attacks/Ground")
@export_subgroup("Attacks/Ground/Neutral", "atk_nt")
@export var atk_nt1: FighterAction
@export var atk_nt2: FighterAction
@export var atk_nt3: FighterAction
@export_subgroup("Attacks/Ground/Forward", "atk_fw")
@export var atk_fwl: FighterAction:
	get():
		return atk_fwh if !atk_fwl else atk_fwl
@export var atk_fwh: FighterAction
@export_subgroup("Attacks/Ground/Upper", "atk_up")
@export var atk_upl: FighterAction:
	get():
		return atk_uph if !atk_upl else atk_upl
@export var atk_uph: FighterAction
@export_subgroup("Attacks/Ground/Dash", "atk_dsh")
@export var atk_dsh: FighterAction
#endregion
#region AIR ATTACKS
@export_subgroup("Attacks/Air", "atk_air")
@export var atk_air_ntl: FighterAction
@export var atk_air_fwd: FighterAction:
	get():
		return atk_air_ntl if !atk_air_fwd else atk_air_fwd
@export var atk_air_upr: FighterAction:
	get():
		return atk_air_ntl if !atk_air_upr else atk_air_upr
@export var atk_air_act: FighterAction:
	get():
		return atk_air_ntl if !atk_air_act else atk_air_act
@export var atk_air_dnk: FighterAction
#endregion
#region GROUND SPECIALS
@export_subgroup("Specials")
@export_subgroup("Specials/Ground")
@export_subgroup("Specials/Ground/Shot", "sht_gnd")
@export var sht_gnd_ntl: FighterAction
@export var sht_gnd_fwd: FighterAction:
	get():
		return sht_gnd_ntl if !sht_gnd_fwd else sht_gnd_fwd
@export var sht_gnd_upr: FighterAction:
	get():
		return sht_gnd_ntl if !sht_gnd_upr else sht_gnd_upr
@export_subgroup("Specials/Ground/Power", "pwr_gnd")
@export var pwr_gnd_ntl: FighterAction
@export var pwr_gnd_fwd: FighterAction:
	get():
		return pwr_gnd_ntl if !pwr_gnd_fwd else pwr_gnd_fwd
@export var pwr_gnd_upr: FighterAction:
	get():
		return pwr_gnd_ntl if !pwr_gnd_upr else pwr_gnd_upr
@export_subgroup("Specials/Ground/Trap", "trp_gnd")
@export var trp_gnd_ntl: FighterAction
@export var trp_gnd_fwd: FighterAction:
	get():
		return trp_gnd_ntl if !trp_gnd_fwd else trp_gnd_fwd
@export var trp_gnd_upr: FighterAction:
	get():
		return trp_gnd_ntl if !trp_gnd_upr else trp_gnd_upr
#endregion
#region AIR SPECIALS
@export_subgroup("Specials/Air")
@export_subgroup("Specials/Air/Shot", "sht_air")
@export var sht_air_ntl: FighterAction
@export var sht_air_fwd: FighterAction:
	get():
		return sht_air_ntl if !sht_air_fwd else sht_air_fwd
@export var sht_air_upr: FighterAction:
	get():
		return sht_air_ntl if !sht_air_upr else sht_air_upr
@export_subgroup("Specials/Air/Power", "pwr_air")
@export var pwr_air_ntl: FighterAction
@export var pwr_air_fwd: FighterAction:
	get():
		return pwr_air_ntl if !pwr_air_fwd else pwr_air_fwd
@export var pwr_air_upr: FighterAction:
	get():
		return pwr_air_ntl if !pwr_air_upr else pwr_air_upr
@export_subgroup("Specials/Air/Trap", "trp_air")
@export var trp_air_ntl: FighterAction
@export var trp_air_fwd: FighterAction:
	get():
		return trp_air_ntl if !trp_air_fwd else trp_air_fwd
@export var trp_air_upr: FighterAction:
	get():
		return trp_air_ntl if !trp_air_upr else trp_air_upr
#endregion
#region DEFENSE SPECIALS
@export_subgroup("Specials/Defense")
@export var sht_def: FighterAction:
	get():
		return sht_gnd_ntl if !sht_def else sht_def
@export var pwr_def: FighterAction:
	get():
		return pwr_gnd_ntl if !pwr_def else pwr_def
@export var trp_def: FighterAction:
	get():
		return trp_gnd_ntl if !trp_def else trp_def
#endregion
#region GRABS
@export_subgroup("Grabs", "grb")
@export var grb_idl: FighterAction
@export var grb_dsh: FighterAction:
	get():
		return grb_idl if !grb_dsh else grb_dsh
@export var grb_pvt: FighterAction:
	get():
		return grb_idl if !grb_pvt else grb_pvt
#endregion
#region THROWS
@export_subgroup("Throws", "thw")
@export var thw_fwd: FighterAction
@export var thw_bak: FighterAction
@export var thw_upr: FighterAction
@export var thw_dwn: FighterAction
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
