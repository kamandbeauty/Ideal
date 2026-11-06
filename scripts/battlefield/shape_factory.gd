class_name ShapeFactory
extends RefCounted
## Original geometry: primitives are composed into a consistent low-poly art style.


static func material(
	color: Color, metallic: float = 0.0, roughness: float = 1.0
) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result


static func box(
	parent: Node3D, dimensions: Vector3, pos: Vector3, surface: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = surface
	parent.add_child(instance)
	return instance


static func cylinder(
	parent: Node3D, radius: float, height: float, pos: Vector3, surface: Material, sides: int = 12
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = surface
	parent.add_child(instance)
	return instance


static func sphere(
	parent: Node3D, dimensions: Vector3, pos: Vector3, surface: Material, segments: int = 12
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 4)
	instance.mesh = mesh
	instance.scale = dimensions
	instance.position = pos
	instance.material_override = surface
	parent.add_child(instance)
	return instance
