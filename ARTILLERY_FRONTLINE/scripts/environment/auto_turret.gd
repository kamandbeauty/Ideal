class_name AutoTurret
extends Node3D
## A purchased flank gun. It acquires the nearest visible attacker and fires
## through the shared bullet pool without changing the player's accuracy stats.

const DAMAGE: float = 21.0
const FIRE_INTERVAL: float = 0.28
const PROJECTILE_SPEED: float = 360.0
const MAX_RANGE: float = 100.0
const TARGET_REFRESH: float = 0.18

var horde: Horde
var bullets: BulletPool
var effects: EffectPool
var traverse: Node3D
var muzzle: Marker3D
var target: Zombie
var fire_left: float = 0.0
var target_refresh_left: float = 0.0


func _ready() -> void:
	_build_model()


func _physics_process(delta: float) -> void:
	if horde == null or bullets == null:
		return
	fire_left = maxf(0.0, fire_left - delta)
	target_refresh_left -= delta
	if target_refresh_left <= 0.0 or not is_instance_valid(target) or not target.alive:
		target_refresh_left = TARGET_REFRESH
		target = _nearest_target()
	if not is_instance_valid(target) or not target.alive:
		return
	var aim_at: Vector3 = target.global_position + Vector3.UP * target.data.height() * 0.58
	traverse.look_at(aim_at, Vector3.UP)
	if fire_left > 0.0 or not _has_visible_target(aim_at):
		return
	var direction: Vector3 = (aim_at - muzzle.global_position).normalized()
	var shot: int = bullets.fire(muzzle.global_position, direction * PROJECTILE_SPEED, DAMAGE, MAX_RANGE,
		true, 0, 0.5, 1.0, false)
	if shot >= 0:
		fire_left = FIRE_INTERVAL


func _nearest_target() -> Zombie:
	var nearest: Zombie
	var best_distance: float = MAX_RANGE * MAX_RANGE
	for candidate: Zombie in horde.active:
		if not is_instance_valid(candidate) or not candidate.alive:
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest


func _has_visible_target(aim_at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position, aim_at, Layers.BULLET_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	if collider == null or not collider.has_meta("zombie"):
		return false
	var visible_zombie: Zombie = collider.get_meta("zombie") as Zombie
	return visible_zombie != null and visible_zombie.alive


func _build_model() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.13, 0.17, 0.18)
	steel.metallic = 0.82
	steel.roughness = 0.34
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.68, 0.46, 0.19)
	trim.metallic = 0.75
	trim.roughness = 0.3
	_mesh(CylinderMesh.new(), Vector3(0.0, 0.12, 0.0), Vector3(0.78, 0.24, 0.78), steel)
	var body := BoxMesh.new()
	body.size = Vector3(0.78, 0.42, 0.82)
	_mesh(body, Vector3(0.0, 0.74, 0.0), Vector3.ONE, steel)
	traverse = Node3D.new()
	traverse.name = "Traverse"
	traverse.position.y = 0.92
	add_child(traverse)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.12
	barrel.bottom_radius = 0.16
	barrel.height = 1.35
	barrel.radial_segments = 10
	var barrel_mesh := MeshInstance3D.new()
	barrel_mesh.mesh = barrel
	barrel_mesh.material_override = trim
	barrel_mesh.rotation.x = PI / 2.0
	barrel_mesh.position = Vector3(0.0, 0.0, -0.64)
	traverse.add_child(barrel_mesh)
	var receiver := BoxMesh.new()
	receiver.size = Vector3(0.48, 0.28, 0.62)
	var receiver_mesh := MeshInstance3D.new()
	receiver_mesh.mesh = receiver
	receiver_mesh.material_override = steel
	receiver_mesh.position.z = -0.12
	traverse.add_child(receiver_mesh)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, -1.32)
	traverse.add_child(muzzle)


func _mesh(mesh: Mesh, at: Vector3, size: Vector3, material: Material) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		var cylinder: CylinderMesh = mesh as CylinderMesh
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.z * 0.5
		cylinder.height = size.y
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
