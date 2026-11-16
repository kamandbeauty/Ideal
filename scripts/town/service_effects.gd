class_name ServiceEffects
extends Node3D
## A fixed-size visual pool for one customer. No physics, timers, tweens,
## random-number draws or income writes. CustomerFlow owns the service gate.

const ICONS := {
	"gas_station": preload("res://assets/ui/service-fuel.svg"),
	"car_wash": preload("res://assets/ui/service-wash.svg"),
	"auto_service": preload("res://assets/ui/nav-build.svg"),
	"toilets": preload("res://assets/ui/service-refresh.svg"),
	"diner": preload("res://assets/ui/service-food.svg"),
	"electric_charger": preload("res://assets/ui/nav-boost.svg"),
	"motel": preload("res://assets/ui/service-rest.svg"),
	"drive_in": preload("res://assets/ui/service-cinema.svg"),
}

static var _bubble_mesh: SphereMesh
static var _bubble_material: StandardMaterial3D

var business_id := ""
var servicing := false
var activation_count := 0
var _clock := 0.0
var _preset := ""
var _top := 1.0
var _width := 0.8
var _indicator_y := 1.8
var _bubbles: MultiMeshInstance3D
var _badge: Sprite3D
var _rollers: Array[Node3D] = []


func setup(id: String, kind: String, preset: String) -> void:
	name = "ServiceFeedback_" + id
	business_id = id
	_top = vehicle_top(kind)
	_width = VehicleMesh.footprint(kind).x
	_indicator_y = indicator_height(id, kind)
	visible = false
	_build_pool()
	_badge = Sprite3D.new()
	_badge.name = "ServiceIcon"
	_badge.texture = ICONS.get(id, ICONS["gas_station"])
	_badge.pixel_size = 0.008
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.shaded = false
	_badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_badge)
	if id == "gas_station" or id == "electric_charger":
		_build_hose(id == "electric_charger")
	elif id == "car_wash":
		_build_rollers()
	set_quality(preset)


static func vehicle_top(kind: String) -> float:
	var profile := VehicleMesh.spec(kind)
	var base := 0.58 if kind == "monster" else VehicleMesh.WHEEL_RADIUS
	return (base + float(profile["body"]) + float(profile["cabin"])) * VehicleMesh.SIZE_SCALE


static func indicator_height(id: String, kind: String) -> float:
	# Progress and the service icon must not be hidden underneath a canopy.
	var clearance := 0.0
	if id == "gas_station":
		clearance = 2.50
	elif id == "car_wash" or id == "auto_service":
		clearance = 2.40
	return maxf(clearance, vehicle_top(kind) + 0.38)


func set_quality(preset: String) -> void:
	var next := Quality.normalise(preset)
	if next == _preset:
		return
	_preset = next
	_bubbles.multimesh.instance_count = Quality.service_particle_count(next)


## A reservation is not service. Arrival, reverse, yielding and departure all
## pass false here, immediately hiding every bubble, hose and indicator.
func tick(delta: float, active: bool, progress: float) -> void:
	if not active:
		stop()
		return
	if not servicing:
		activation_count += 1
	servicing = true
	visible = true
	_clock = fposmod(_clock + clampf(delta, 0.0, 0.35), 100.0)
	_badge.position = Vector3(0, _indicator_y + sin(_clock * 4.0) * 0.035, 0.25)
	for i in _rollers.size():
		_rollers[i].rotation.y = _clock * (3.6 if i == 0 else -3.6)
	var count := _bubbles.multimesh.instance_count
	for i in count:
		var life := fposmod(_clock * 0.85 + float(i) / float(count), 1.0)
		var phase := float(i) * 2.39996
		var at := Vector3.ZERO
		var radius := 0.035 + sin(life * PI) * 0.025
		var color := Color("#c6ecfa")
		match business_id:
			"car_wash":
				var side := -1.0 if i % 2 == 0 else 1.0
				at = Vector3(
					side * lerpf(_width * 0.5 + 0.08, 0.06, life),
					lerpf(_top * 0.65, _top + 0.34, life),
					sin(phase) * 0.67
				)
				radius *= 1.35
				color = Color.WHITE if i % 3 == 0 else Color("#8dddf8")
			"gas_station", "electric_charger":
				at = Vector3(cos(phase) * _width * 0.48, _top + 0.12 + life * 0.34, sin(phase) * 0.48)
				color = Color("#a5e84f") if business_id == "electric_charger" else Color("#ffe48b")
				radius *= 0.70
			"auto_service":
				at = Vector3(
					cos(phase + _clock * 1.4) * _width * 0.56, 0.28 + life * 0.50, sin(phase + _clock * 1.4) * 0.65
				)
				color = Color("#ffe590")
				radius *= 0.75
			"diner", "motel":
				at = Vector3(sin(phase + life * 2.0) * 0.17, _top + 0.08 + life * 0.43, -0.3 + cos(phase) * 0.28)
				color = Color("#fff1cd") if business_id == "diner" else Color("#bddcf7")
				radius *= 0.75
			_:
				at = Vector3(cos(phase) * _width * 0.55, _top * 0.7 + life * 0.5, sin(phase) * 0.55)
				color = Color("#ccf6dc") if business_id == "toilets" else Color("#e5d1fa")
		var size := radius * (0.55 + sin(clampf(progress, 0.0, 1.0) * PI) * 0.45)
		_bubbles.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at))
		_bubbles.multimesh.set_instance_color(i, color)


func stop() -> void:
	servicing = false
	visible = false


func particle_count() -> int:
	return _bubbles.multimesh.instance_count if _bubbles != null else 0


func _build_pool() -> void:
	if _bubble_mesh == null:
		_bubble_mesh = SphereMesh.new()
		_bubble_mesh.radius = 1.0
		_bubble_mesh.height = 2.0
		_bubble_mesh.radial_segments = 8
		_bubble_mesh.rings = 4
		_bubble_material = StandardMaterial3D.new()
		_bubble_material.vertex_color_use_as_albedo = true
		_bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.use_colors = true
	pool.mesh = _bubble_mesh
	_bubbles = MultiMeshInstance3D.new()
	_bubbles.name = "PooledServiceParticles"
	_bubbles.multimesh = pool
	_bubbles.material_override = _bubble_material
	_bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubbles)


func _build_hose(electric: bool) -> void:
	var hose := Node3D.new()
	hose.name = "ChargingCable" if electric else "FuelHose"
	add_child(hose)
	var material := VehicleMesh.paint(CartoonPalette.INK, 0.95, 0.0)
	var points: Array[Vector3] = [
		Vector3(-0.82, 0.59, -0.12),
		Vector3(-0.72, 0.26, 0.34),
		Vector3(-_width * 0.5 - 0.06, 0.28, 0.48),
		Vector3(-_width * 0.5, 0.49, 0.40),
	]
	for i in range(points.size() - 1):
		var segment := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.018
		mesh.height = 1.0
		mesh.radial_segments = 6
		segment.mesh = mesh
		segment.material_override = material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.position = (points[i] + points[i + 1]) * 0.5
		var direction := points[i + 1] - points[i]
		segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
		segment.scale.y = direction.length()
		hose.add_child(segment)


func _build_rollers() -> void:
	var blue := VehicleMesh.paint(Color("#249fc9"), 0.95, 0.0)
	var cream := VehicleMesh.paint(Color("#d7f0f8"), 0.95, 0.0)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WashRollerLeft" if side < 0.0 else "WashRollerRight"
		pivot.position = Vector3(float(side) * 0.72, 0.64, -0.10)
		add_child(pivot)
		_rollers.append(pivot)
		var brush := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.065
		mesh.bottom_radius = 0.065
		mesh.height = 0.92
		mesh.radial_segments = 8
		brush.mesh = mesh
		brush.material_override = blue
		brush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(brush)
		for angle in [0.0, PI * 0.5]:
			var stripe := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(0.024, 0.93, 0.14)
			stripe.mesh = strip_mesh
			stripe.material_override = cream
			stripe.rotation.y = float(angle)
			stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(stripe)
