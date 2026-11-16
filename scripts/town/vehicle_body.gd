class_name VehicleBody
extends CharacterBody3D
## Kinematic, non-pushing traffic: a swept box prevents tunnelling, a forward
## cast brakes before contact, and rotation is checked before it is applied.
## Layer 1 is ONLY for touch targets. Cars use 2; solid scenery uses 4.

const VEHICLE_LAYER := 2
const SOLID_LAYER := 4
const GROUP := "road_vehicles"
const TURN_SPEED := 3.8

var kind := "car"
var dimensions := Vector2.ONE
var speed := 0.0
var distance_driven := 0.0
var waiting_seconds := 0.0
var visual: Node3D
var _shape: CollisionShape3D
var _route: Array[Vector3] = []
var _waypoint := 0


func setup(vehicle_kind: String, color: Color) -> void:
	kind = vehicle_kind
	dimensions = VehicleMesh.footprint(kind)
	collision_layer = VEHICLE_LAYER
	collision_mask = VEHICLE_LAYER | SOLID_LAYER
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.015
	add_to_group(GROUP)
	visual = VehicleMesh.build(kind, color)
	add_child(visual)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(dimensions.x, 1.55, dimensions.y)
	_shape.shape = box
	_shape.position.y = 0.78
	add_child(_shape)


func set_route(points: Array[Vector3]) -> void:
	_route = points.duplicate()
	_waypoint = 0


func arrived() -> bool:
	return _waypoint >= _route.size()


func hold(delta: float) -> void:
	speed = 0.0
	waiting_seconds += delta
	VehicleMesh.set_braking(visual, true)


func drive(delta: float, cruise: float, reversing: bool = false) -> void:
	# Small angular steps also protect the swept volume when the phone hitches.
	var remaining := clampf(delta, 0.0, 0.35)
	while remaining > 0.0001:
		var step := minf(remaining, 1.0 / 60.0)
		_drive_step(step, cruise, reversing)
		remaining -= step


func _drive_step(delta: float, cruise: float, reversing: bool) -> void:
	while not arrived() and position.distance_to(_route[_waypoint]) < 0.035:
		_waypoint += 1
	if arrived():
		hold(delta)
		return
	var offset := _route[_waypoint] - position
	offset.y = 0.0
	var direction := offset.normalized()
	var desired_yaw := atan2(direction.x, direction.z) + (PI if reversing else 0.0)
	var next_yaw := rotate_toward(rotation.y, desired_yaw, TURN_SPEED * delta)
	var candidate := global_transform
	candidate.basis = Basis(Vector3.UP, next_yaw)
	if not _rotation_clear(candidate):
		hold(delta)
		return
	rotation.y = next_yaw

	var angle := absf(angle_difference(rotation.y, desired_yaw))
	var desired_speed := cruise * clampf(1.0 - angle / 1.2, 0.0, 1.0)
	var look_ahead := maxf(0.7, speed * 0.8 + 0.35)
	var hit := KinematicCollision3D.new()
	if test_move(global_transform, direction * look_ahead, hit, 0.06):
		desired_speed = minf(desired_speed, DrivingRules.stopping_speed(hit.get_travel().length(), cruise))
	speed = DrivingRules.approach_speed(speed, desired_speed, delta)
	var motion := direction * minf(speed * delta, offset.length())
	var collision := move_and_collide(motion, false, 0.02)
	var moved := motion.length() if collision == null else collision.get_travel().length()
	distance_driven += moved
	VehicleMesh.roll(visual, moved * (-1.0 if reversing else 1.0))
	VehicleMesh.set_braking(visual, desired_speed < cruise * 0.55 or collision != null)
	if collision != null:
		speed = 0.0
	if moved < 0.0005:
		waiting_seconds += delta
	else:
		waiting_seconds = 0.0


func _rotation_clear(candidate: Transform3D) -> bool:
	if _shape == null or get_world_3d() == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.transform = candidate * _shape.transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.012
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Check both broadphase and the just-spawned bodies (same physics tick).
static func spawn_clear(parent: Node3D, vehicle_kind: String, at: Vector3, yaw: float) -> bool:
	var size := VehicleMesh.footprint(vehicle_kind)
	for other in parent.get_tree().get_nodes_in_group(GROUP):
		var body := other as VehicleBody
		if body == null or not body.visible or body.collision_layer == 0:
			continue
		if DrivingRules.overlaps(
			DrivingRules.xz(at),
			size,
			yaw,
			DrivingRules.xz(body.global_position),
			body.dimensions,
			body.global_rotation.y,
			1.0
		):
			return false
	return true
