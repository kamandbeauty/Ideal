class_name ArtilleryProjectile
extends Node3D
## Swept ray collision; no per-shell RigidBody and no tunneling.
signal impacted(position: Vector3, normal: Vector3, collider: Object, ammunition: AmmunitionData)
signal expired
var active: bool = false
var velocity: Vector3 = Vector3.ZERO
var ammunition: AmmunitionData
var age: float = 0.0
var damage_scale: float = 1.0
var shot_id: int = 0
var visual: MeshInstance3D
var trail: ImmediateMesh
var trail_instance: MeshInstance3D
var trail_points := PackedVector3Array()

func _ready() -> void:
	visual = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.radial_segments = 8
	mesh.rings = 4
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.7, 0.28)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.08)
	material.emission_energy_multiplier = 3.0
	visual.material_override = material
	add_child(visual)
	trail = ImmediateMesh.new()
	trail_instance = MeshInstance3D.new()
	trail_instance.mesh = trail
	trail_instance.top_level = true
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.albedo_color = Color(0.95, 0.82, 0.59, 0.5)
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_instance.material_override = trail_material
	add_child(trail_instance)
	deactivate()

func launch(origin: Vector3, initial_velocity: Vector3, ammo: AmmunitionData, multiplier: float, id: int = 0) -> void:
	shot_id = id
	global_position = origin
	velocity = initial_velocity
	ammunition = ammo
	damage_scale = multiplier
	age = 0.0
	active = true
	visible = true
	trail_instance.visible = true
	set_physics_process(true)
	trail_points.clear()
	trail_points.append(origin)

func deactivate() -> void:
	active = false
	visible = false
	if trail_instance:
		trail_instance.visible = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not active or ammunition == null:
		return
	var state: Dictionary = Ballistics.integrate(global_position, velocity, delta, ammunition.air_resistance)
	var next: Vector3 = state.position
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 7)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	age += delta
	if not hit.is_empty():
		global_position = hit.position
		deactivate()
		impacted.emit(hit.position, hit.normal, hit.collider, ammunition)
		return
	global_position = next
	velocity = state.velocity
	trail_points.append(global_position)
	if trail_points.size() > 28:
		trail_points.remove_at(0)
	trail.clear_surfaces()
	if trail_points.size() >= 2:
		trail.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in trail_points:
			trail.surface_add_vertex(point)
		trail.surface_end()
	if age >= Ballistics.MAX_FLIGHT_TIME or next.y < -100.0 or next.length() > 4000.0:
		deactivate()
		expired.emit()
