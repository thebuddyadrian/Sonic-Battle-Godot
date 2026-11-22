class_name DetMath
## Deterministic versions of the engine's vector and transform methods that use
## trigonometry, for game scripts: the same results on every platform.
##
## Floats themselves are deterministic: +, -, *, / and sqrt() are exactly
## rounded (IEEE 754), and Godot doesn't fuse them, so they give the same bits
## everywhere, and so do the engine methods built only from them (length(),
## normalized(), dot(), cross(), lerp(), move_toward(), distance_to(), clamp(),
## snappedf(), fmod(), floor()...). What isn't is everything that calls sin(),
## cos(), tan(), atan2(), pow(), exp() or log(): those come from the
## platform's libm, which differs in the last bits between Windows, macOS,
## Linux, Android...
##
## For the functions themselves, call Godot Rapier's deterministic math
## directly: RapierMath2D.sin(), cos(), tan(), asin(), acos(), atan(), atan2(),
## pow(), exp(), log(), hypot()... (or RapierMath3D, the same), the software
## libm Rapier's own physics runs on. This class has what Rapier doesn't: the
## engine methods built on them, such as Vector2.rotated(), angle(),
## from_angle(), Transform2D(rotation, position), Quaternion(axis, angle),
## Basis.from_euler() or ease().
##
##   var dir := DetMath.from_angle(aim)              # not Vector2.from_angle()
##   velocity = DetMath.rotated(velocity, spin)      # not velocity.rotated()
##   var heading := DetMath.angle(target - position) # not .angle()
##   var falloff := RapierMath2D.pow(distance, -2.0) # not pow()
##
## They compute in 32 bit floats (the precision of Vector2 and the physics), so
## expect about 7 significant digits.
##
## Requires Godot Rapier (2D or 3D): there is no fallback, as the platform's
## functions would only be deterministic between identical machines.

# RapierMath2D or RapierMath3D, whichever is installed, called by name: the
# addon doesn't need Rapier to load.
static var _math: Object = _find_math()

static func _find_math() -> Object:
	for math_class in ["RapierMath2D", "RapierMath3D"]:
		if ClassDB.class_exists(math_class):
			return ClassDB.instantiate(math_class)
	push_error("DetMath needs Godot Rapier (2D or 3D) for its deterministic math.")
	return null

## Whether the deterministic functions are available (Godot Rapier is loaded).
static func is_deterministic() -> bool:
	return _math != null

## Godot's ease(), which uses pow().
@warning_ignore("shadowed_global_identifier")
static func ease(x: float, curve: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if curve > 0.0:
		if curve < 1.0:
			return 1.0 - _math.pow(1.0 - x, 1.0 / curve)
		return _math.pow(x, curve)
	if curve < 0.0:
		if x < 0.5:
			return _math.pow(x * 2.0, -curve) * 0.5
		return (1.0 - _math.pow(1.0 - (x - 0.5) * 2.0, -curve)) * 0.5 + 0.5
	return 0.0

# 2D ---------------------------------------------------------------------------

## Vector2.from_angle(angle).
static func from_angle(angle: float) -> Vector2:
	return Vector2(_math.cos(angle), _math.sin(angle))

## v.angle(): the angle from the X axis, in (-PI, PI].
static func angle(v: Vector2) -> float:
	return _math.atan2(v.y, v.x)

## from.angle_to(to): the signed angle between them.
static func angle_to(from: Vector2, to: Vector2) -> float:
	return _math.atan2(from.cross(to), from.dot(to))

## from.angle_to_point(to): the angle of the line from one to the other.
static func angle_to_point(from: Vector2, to: Vector2) -> float:
	return angle(to - from)

## v.rotated(angle).
static func rotated(v: Vector2, angle: float) -> Vector2:
	var c: float = _math.cos(angle)
	var s: float = _math.sin(angle)
	return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)

## Transform2D(rotation, origin).
static func transform_2d(rotation: float, origin := Vector2.ZERO) -> Transform2D:
	var c: float = _math.cos(rotation)
	var s: float = _math.sin(rotation)
	return Transform2D(Vector2(c, s), Vector2(-s, c), origin)

## t.get_rotation().
static func get_rotation(t: Transform2D) -> float:
	return _math.atan2(t.x.y, t.x.x)

# 3D ---------------------------------------------------------------------------

## Quaternion(axis, angle). The axis must be normalized.
static func quaternion(axis: Vector3, angle: float) -> Quaternion:
	var s: float = _math.sin(angle * 0.5)
	return Quaternion(axis.x * s, axis.y * s, axis.z * s, _math.cos(angle * 0.5))

## v.rotated(axis, angle). The axis must be normalized.
static func rotated_3d(v: Vector3, axis: Vector3, angle: float) -> Vector3:
	# Basis(Quaternion) and Basis * Vector3 are plain arithmetic: deterministic.
	return Basis(quaternion(axis, angle)) * v

## Basis.from_euler(euler), in Godot's default YXZ order (as Node3D.rotation).
static func basis_from_euler(euler: Vector3) -> Basis:
	return Basis(quaternion(Vector3.UP, euler.y)
			* quaternion(Vector3.RIGHT, euler.x)
			* quaternion(Vector3.BACK, euler.z))

## from.angle_to(to): the unsigned angle between two vectors.
static func angle_to_3d(from: Vector3, to: Vector3) -> float:
	return _math.atan2(from.cross(to).length(), from.dot(to))

static func signed_angle_to_3d(from: Vector3, to: Vector3, axis: Vector3) -> float:
	var u_ang: float = _math.atan2(from.cross(to).length(), from.dot(to))
	var s: float = -1.0 if from.cross(to).dot(axis) < 0.0 else 1.0
	return u_ang * s
