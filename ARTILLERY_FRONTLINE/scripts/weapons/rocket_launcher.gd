class_name RocketLauncher
extends Weapon
## The shoulder-fired RPG: one round in the tube, a slow reload, and a blast
## where it lands. The model rides on the gunner's eye, low on the right.

## Where the launcher rests in the view: position right, up and back of the eye, and its toe-in.
const REST_POSITION := Vector3(0.29, -0.24, -0.2)
const REST_ANGLES := Vector3(5.0, 12.0, 0.0)

var holder: Node3D
var warhead: Node3D
var muzzle: Node3D
var kick: float = 0.0
var rest := Transform3D.IDENTITY
var warhead_rest := Vector3.ZERO


func _build() -> void:
	holder = get_node("Holder")
	warhead = holder.find_child("Warhead", true, false)
	muzzle = holder.find_child("Muzzle", true, false)
	if warhead:
		warhead_rest = warhead.position
	rest = Transform3D(Basis.from_euler(Vector3(deg_to_rad(REST_ANGLES.x), deg_to_rad(REST_ANGLES.y), deg_to_rad(REST_ANGLES.z))),
		REST_POSITION)


func set_aim(_yaw_degrees: float, _pitch_degrees: float) -> void:
	_pose()


func muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position


func _fire_round() -> void:
	_pose()
	var origin: Vector3 = muzzle_position()
	var direction: Vector3 = scatter((sight_point() - origin).normalized())
	if rockets:
		rockets.launch(origin, direction, data)
	kick = 1.0
	if effects:
		effects.burst("dust", origin + direction * 0.4, direction, 0.7)
	Sound.play("rocket", -1.0, rng.randf_range(0.96, 1.04))
	shot_fired.emit(0)


func _animate(delta: float) -> void:
	kick = move_toward(kick, 0.0, delta * 3.2)


func _pose() -> void:
	if holder == null:
		return
	holder.visible = readiness > 0.001
	if not holder.visible:
		return
	var away: float = 1.0 - smoothstep(0.0, 1.0, readiness)
	var loading: float = sin(state.reload_progress() * PI) if state.reloading else 0.0
	var jolt: float = kick * kick
	var offset := Vector3(0.05 * away, -0.42 * away - 0.15 * loading, 0.1 * away + 0.08 * jolt)
	var tilt := Vector3(deg_to_rad(-38.0 * away - 26.0 * loading + 7.0 * jolt), 0.0, deg_to_rad(-14.0 * loading))
	var local := Transform3D(Basis.from_euler(tilt), offset)
	var frame: Transform3D = camera.global_transform if camera else global_transform
	holder.global_transform = frame * rest * local
	if warhead:
		# The tube is empty after the shot; the new round slides in over the second half of the reload.
		var loaded: bool = state.ammo > 0
		var seating: float = clampf((state.reload_progress() - 0.5) / 0.35, 0.0, 1.0) if state.reloading else 0.0
		warhead.visible = loaded or seating > 0.0
		warhead.position = warhead_rest + Vector3(0.0, 0.0, -0.3 * (1.0 - seating)) if not loaded else warhead_rest
