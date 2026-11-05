class_name MeshFactory
extends RefCounted
## Shared primitive meshes and materials keep mobile draw state changes low.
static var materials: Dictionary = {}
static var box_mesh: BoxMesh
static var sphere_mesh: SphereMesh
static var cylinder_mesh: CylinderMesh

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var key: String = color.to_html() + str(metallic) + str(roughness)
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	materials[key] = result
	return result

static func box(parent: Node3D, name: String, position: Vector3, size: Vector3, color: Color, cast_shadow: bool = true) -> MeshInstance3D:
	if box_mesh == null:
		box_mesh = BoxMesh.new()
		box_mesh.size = Vector3.ONE
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = box_mesh
	instance.material_override = material(color)
	instance.position = position
	instance.scale = size
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

static func cylinder(parent: Node3D, name: String, position: Vector3, radius: float, height: float, color: Color, segments: int = 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = position
	parent.add_child(instance)
	return instance

static func sphere(parent: Node3D, name: String, position: Vector3, scale: Vector3, color: Color) -> MeshInstance3D:
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 1.0
		sphere_mesh.height = 2.0
		sphere_mesh.radial_segments = 12
		sphere_mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = sphere_mesh
	instance.material_override = material(color)
	instance.position = position
	instance.scale = scale
	parent.add_child(instance)
	return instance

static func static_box(parent: Node3D, name: String, position: Vector3, size: Vector3, color: Color, collision: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	box(body, "Visual", Vector3.ZERO, size, color)
	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	return body
