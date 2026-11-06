class_name CoastalBullet
extends Node3D
## Swept tracer/rocket projectile for the mounted-weapon milestone.
signal impacted(position: Vector3, normal: Vector3, collider: Object, damage: float, blast: float)
signal expired

var active: bool = false
var velocity: Vector3 = Vector3.ZERO
var damage: float = 20.0
var blast: float = 0.0
var age: float = 0.0
var life: float = 3.0
var visual: MeshInstance3D
var trail: ImmediateMesh
var trail_instance: MeshInstance3D
var trail_points := PackedVector3Array()

func _ready() -> void:
	visual = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.16
	mesh.radial_segments = 8
	mesh.rings = 4
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.42)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.62, 0.18)
	material.emission_energy_multiplier = 3.5
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	trail = ImmediateMesh.new()
	trail_instance = MeshInstance3D.new()
	trail_instance.mesh = trail
	trail_instance.top_level = true
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.albedo_color = Color(1.0, 0.78, 0.4, 0.55)
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_instance.material_override = trail_material
	trail_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail_instance)
	deactivate()

func launch(origin: Vector3, initial_velocity: Vector3, hit_damage: float, blast_radius: float) -> void:
	global_position = origin
	velocity = initial_velocity
	damage = hit_damage
	blast = blast_radius
	age = 0.0
	life = 4.0 if blast_radius > 0.0 else 2.4
	active = true
	visible = true
	trail_instance.visible = true
	trail_points.clear()
	trail_points.append(origin)
	visual.scale = Vector3.ONE * (2.2 if blast_radius > 0.0 else 1.0)
	set_physics_process(true)

func deactivate() -> void:
	active = false
	visible = false
	if trail_instance:
		trail_instance.visible = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if blast > 0.0:
		velocity.y -= 2.2 * delta
	var next: Vector3 = global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 7)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	age += delta
	if not hit.is_empty():
		global_position = hit.position
		deactivate()
		impacted.emit(hit.position, hit.normal, hit.collider, damage, blast)
		return
	global_position = next
	trail_points.append(global_position)
	if trail_points.size() > 14:
		trail_points.remove_at(0)
	trail.clear_surfaces()
	if trail_points.size() >= 2:
		trail.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in trail_points:
			trail.surface_add_vertex(point)
		trail.surface_end()
	if age >= life or next.y < -40.0:
		deactivate()
		expired.emit()
