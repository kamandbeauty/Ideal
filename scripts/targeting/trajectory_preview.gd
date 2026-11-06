class_name TrajectoryPreview
extends Node3D
## Fixed-size MultiMesh; no per-frame node creation.

const MAX_DOTS: int = 140
var impact_position: Vector3 = Vector3.ZERO
var impact_collider: Object
var has_impact: bool = false
var flight_time: float = 0.0
var _dots: MultiMesh
var _marker: MeshInstance3D


func _ready() -> void:
	var dot_mat := ShapeFactory.material(Color("f7d88c"))
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.emission_enabled = true
	dot_mat.emission = Color("b98632")
	dot_mat.emission_energy_multiplier = 0.55
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.13
	dot_mesh.height = 0.26
	dot_mesh.radial_segments = 6
	dot_mesh.rings = 4
	dot_mesh.material = dot_mat
	_dots = MultiMesh.new()
	_dots.transform_format = MultiMesh.TRANSFORM_3D
	_dots.mesh = dot_mesh
	_dots.instance_count = MAX_DOTS
	_dots.visible_instance_count = 0
	var dots_node := MultiMeshInstance3D.new()
	dots_node.multimesh = _dots
	dots_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dots_node)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.1
	ring.outer_radius = 1.25
	ring.rings = 16
	ring.ring_segments = 6
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.material_override = dot_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


func update_prediction(
	space: PhysicsDirectSpaceState3D,
	origin: Vector3,
	velocity: Vector3,
	gravity: float,
	drag: float
) -> void:
	var result := Ballistics.trace(space, origin, velocity, gravity, drag)
	var points: PackedVector3Array = result.points
	impact_position = result.position
	impact_collider = result.collider
	has_impact = result.hit
	flight_time = result.time
	var count := mini(points.size(), MAX_DOTS)
	for i in range(count):
		_dots.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
	_dots.visible_instance_count = count
	_marker.visible = has_impact
	_marker.position = Vector3(impact_position.x, 0.13, impact_position.z)
