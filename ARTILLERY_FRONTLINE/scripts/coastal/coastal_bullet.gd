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
var rocket_root: Node3D
var trail_material: StandardMaterial3D

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
	rocket_root = Node3D.new()
	rocket_root.visible = false
	var body := MeshFactory.cylinder(rocket_root, "RocketBody", Vector3.ZERO, 0.07, 0.6, Color(0.32, 0.35, 0.3), 14, "paint_olive")
	body.rotation.x = PI * 0.5
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.22
	cone.radial_segments = 14
	nose.mesh = cone
	nose.material_override = MeshFactory.material(Color(0.5, 0.42, 0.25), 0.4, 0.5)
	nose.position.z = -0.4
	nose.rotation.x = -PI * 0.5
	rocket_root.add_child(nose)
	for side in [-1.0, 1.0]:
		MeshFactory.box(rocket_root, "Fin", Vector3(side * 0.1, 0, 0.26), Vector3(0.16, 0.02, 0.18), Color(0.25, 0.27, 0.24), false, "steel")
	var glow := MeshFactory.sphere(rocket_root, "MotorGlow", Vector3(0, 0, 0.34), Vector3(0.09, 0.09, 0.16), Color(1.0, 0.6, 0.2))
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.65, 0.25)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.5, 0.15)
	glow_mat.emission_energy_multiplier = 3.0
	glow.material_override = glow_mat
	add_child(rocket_root)
	trail = ImmediateMesh.new()
	trail_instance = MeshInstance3D.new()
	trail_instance.mesh = trail
	trail_instance.top_level = true
	trail_material = StandardMaterial3D.new()
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
	var heavy: bool = blast_radius >= 6.0
	visual.visible = not heavy
	rocket_root.visible = heavy
	if heavy:
		trail_material.albedo_color = Color(0.7, 0.68, 0.62, 0.4)
	else:
		trail_material.albedo_color = Color(1.0, 0.78, 0.4, 0.55)
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
	if rocket_root.visible and velocity.length_squared() > 0.01:
		rocket_root.look_at(global_position + velocity, Vector3.UP)
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
