class_name TargetingSystem
extends Node3D
## Nominal trajectory uses the live-shell integrator and swept world collision.
signal prediction_changed(impact: Vector3, flight_time: float, valid: bool)
var line: MeshInstance3D
var mesh: ImmediateMesh
var impact_marker: MeshInstance3D
var accumulator: float = 0.0
var last_origin: Vector3 = Vector3.INF
var last_velocity: Vector3 = Vector3.INF
var predicted_impact: Vector3 = Vector3.ZERO
var predicted_time: float = 0.0
var prediction_valid: bool = false
var enabled_preview: bool = true

func _ready() -> void:
	mesh = ImmediateMesh.new()
	line = MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.91, 0.77, 0.43, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	line.material_override = material
	add_child(line)
	impact_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 2.4
	ring.outer_radius = 2.8
	ring.rings = 24
	ring.ring_segments = 6
	impact_marker.mesh = ring
	impact_marker.material_override = material
	impact_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(impact_marker)

func invalidate() -> void:
	accumulator = 1.0

func _process(delta: float) -> void:
	accumulator += delta
	if accumulator >= 0.12:
		accumulator = 0.0
		var controller: ArtilleryController = get_parent() as ArtilleryController
		if controller and controller.data:
			var ammo: AmmunitionData = controller.get_meta("selected_ammo", null)
			if ammo:
				var speed: float = float(controller.get_meta("muzzle_velocity", controller.data.muzzle_velocity)) * ammo.velocity_multiplier
				update_prediction(controller.muzzle_position(), controller.aim_direction() * speed, ammo.air_resistance)

func update_prediction(origin: Vector3, velocity: Vector3, drag: float = 0.0) -> void:
	line.visible = enabled_preview
	impact_marker.visible = false
	if not enabled_preview:
		return
	if origin.distance_squared_to(last_origin) < 0.0001 and velocity.distance_squared_to(last_velocity) < 0.0001:
		return
	last_origin = origin
	last_velocity = velocity
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var previous: Vector3 = origin
	var time: float = 0.0
	var interval: float = 0.08
	prediction_valid = false
	while time < Ballistics.MAX_FLIGHT_TIME:
		time += interval
		var state: Dictionary = Ballistics.integrate(origin, velocity, time, drag)
		var next: Vector3 = state.position
		var query := PhysicsRayQueryParameters3D.create(previous, next, 7)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			mesh.surface_add_vertex(hit.position)
			predicted_impact = hit.position
			predicted_time = time
			prediction_valid = true
			impact_marker.global_position = predicted_impact + Vector3.UP * 0.15
			impact_marker.visible = true
			break
		mesh.surface_add_vertex(next)
		previous = next
		if next.y < -60.0:
			break
	mesh.surface_end()
	prediction_changed.emit(predicted_impact, predicted_time, prediction_valid)

func solve(origin: Vector3, target: Vector3, speed: float, drag: float = 0.0, target_velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	var result: Dictionary = Ballistics.solution(origin, target, speed, false, drag)
	if not result.valid:
		return result
	if target_velocity.length_squared() > 0.01:
		for iteration in range(4):
			result = Ballistics.solution(origin, target + target_velocity * float(result.flight_time), speed, false, drag)
			if not result.valid:
				break
	return result
