class_name VehicleMesh
extends RefCounted
## Mobile-friendly, chamfered miniatures: painted bodywork, framed glazing,
## chrome bumpers, grilles, mirrors, recessed wheels and working brake lamps.

const KINDS: Array[String] = ["car", "suv", "pickup", "truck", "bus", "camper"]
const PAINTS: Array[Color] = [
	Color(0.88, 0.47, 0.18),
	Color(0.20, 0.61, 0.72),
	Color(0.83, 0.39, 0.53),
	Color(0.73, 0.20, 0.18),
	Color(0.91, 0.67, 0.20),
	Color(0.27, 0.44, 0.65),
	Color(0.25, 0.59, 0.43),
	Color(0.22, 0.27, 0.33),
	Color(0.83, 0.79, 0.67),
	Color(0.52, 0.35, 0.65),
]
const WHEEL_RADIUS := 0.16
const SIZE_SCALE := 0.82

static var _paints: Dictionary = {}


static func spec(kind: String) -> Dictionary:
	match kind:
		"monster":
			return {
				"length": 2.35,
				"width": 1.08,
				"body": 0.48,
				"cabin": 0.44,
				"cabin_offset": 0.05,
				"cabin_length": 0.48,
				"monster": true
			}
		"suv":
			return {
				"length": 2.0, "width": 0.80, "body": 0.46, "cabin": 0.40, "cabin_offset": -0.02, "cabin_length": 0.62
			}
		"pickup":
			return {
				"length": 2.2,
				"width": 0.82,
				"body": 0.40,
				"cabin": 0.42,
				"cabin_offset": 0.22,
				"cabin_length": 0.42,
				"bed": true
			}
		"truck":
			return {
				"length": 3.1,
				"width": 0.88,
				"body": 0.50,
				"cabin": 0.64,
				"cabin_offset": 0.34,
				"cabin_length": 0.28,
				"trailer": true
			}
		"bus":
			return {
				"length": 3.3,
				"width": 0.88,
				"body": 0.66,
				"cabin": 0.36,
				"cabin_offset": -0.04,
				"cabin_length": 0.92,
				"windows": true
			}
		"camper":
			return {
				"length": 2.45,
				"width": 0.86,
				"body": 0.54,
				"cabin": 0.42,
				"cabin_offset": 0.0,
				"cabin_length": 0.92,
				"twotone": true
			}
	return {"length": 1.82, "width": 0.76, "body": 0.36, "cabin": 0.34, "cabin_offset": -0.04, "cabin_length": 0.52}


## Full visual envelope, including oversized monster tyres and both bumpers.
static func footprint(kind: String) -> Vector2:
	var profile := spec(kind)
	var extra_width := 0.48 if kind == "monster" else 0.24
	return Vector2(float(profile["width"]) + extra_width, float(profile["length"]) + 0.14) * SIZE_SCALE


static func build(kind: String, color: Color) -> Node3D:
	var profile := spec(kind)
	var monster := bool(profile.get("monster", false))
	var wheel_r := 0.34 if monster else WHEEL_RADIUS
	var base_y := wheel_r + (0.24 if monster else 0.0)
	var length := float(profile["length"])
	var width := float(profile["width"])
	var body_h := float(profile["body"])
	var cabin_h := float(profile["cabin"])
	var cabin_len := length * float(profile["cabin_length"])
	var car := Node3D.new()
	car.name = "Vehicle_" + kind
	car.set_meta("kind", kind)
	car.set_meta("length", length * SIZE_SCALE)
	car.set_meta("wheel_radius", wheel_r * SIZE_SCALE)

	var shadow := SurfaceMaterials.contact_shadow(Vector2(width + 0.6, length + 0.65))
	car.add_child(shadow)
	_box(
		car,
		paint(Color(0.10, 0.13, 0.16), 0.8),
		Vector3(0, base_y + 0.03, 0),
		Vector3(width * 0.93, 0.16, length * 0.9),
		0.025
	)
	_box(car, paint(color, 0.38), Vector3(0, base_y + body_h * 0.5, 0), Vector3(width, body_h, length), 0.055)
	var cabin_pos := Vector3(0, base_y + body_h + cabin_h * 0.5 - 0.01, float(profile["cabin_offset"]) * length)
	var cream := Color(0.85, 0.83, 0.74)
	var cab_col := cream if profile.has("twotone") else color.lightened(0.06)
	_box(car, paint(cab_col, 0.40), cabin_pos, Vector3(width * 0.94, cabin_h, cabin_len), 0.055)
	_add_glazing(car, width, cabin_h, cabin_len, cabin_pos, kind)
	_add_details(car, profile, color, Vector3(width, body_h, length), cabin_pos, base_y)
	_add_lights_and_wheels(car, kind, Vector2(width, length), wheel_r, base_y)
	car.scale = Vector3.ONE * SIZE_SCALE
	return car


static func _add_glazing(car: Node3D, width: float, height: float, length: float, at: Vector3, kind: String) -> void:
	var glass := paint(Color(0.19, 0.36, 0.43), 0.18, 0.24)
	var glint := paint(Color(0.49, 0.66, 0.68), 0.26, 0.10)
	for end in [-1.0, 1.0]:
		_box(
			car,
			glass,
			at + Vector3(0, 0, float(end) * (length * 0.5 + 0.006)),
			Vector3(width * 0.78, height * 0.64, 0.015),
			0.008
		)
		_box(
			car,
			glint,
			at + Vector3(-width * 0.14, height * 0.18, float(end) * (length * 0.5 + 0.016)),
			Vector3(width * 0.26, 0.025, 0.008)
		)
	var count := 4 if kind == "bus" else (3 if kind == "camper" else 2)
	var span := length * 0.85 / float(count)
	for side in [-1.0, 1.0]:
		for window in count:
			var z := -length * 0.425 + (float(window) + 0.5) * span
			_box(
				car,
				glass,
				at + Vector3(width * 0.475 * float(side), 0, z),
				Vector3(0.014, height * 0.61, span - 0.045),
				0.005
			)
		# Slim side mirrors; these are included in the collider width.
		_box(
			car,
			paint(Color(0.20, 0.24, 0.27), 0.45),
			at + Vector3((width * 0.5 + 0.055) * float(side), -height * 0.25, length * 0.4),
			Vector3(0.10, 0.065, 0.11),
			0.015
		)


static func _add_details(
	car: Node3D, profile: Dictionary, color: Color, size: Vector3, cabin: Vector3, base_y: float
) -> void:
	var chrome := paint(Color(0.55, 0.60, 0.60), 0.35, 0.6)
	var dark := paint(Color(0.12, 0.16, 0.19), 0.7, 0.0)
	for end in [-1.0, 1.0]:
		_box(
			car,
			chrome,
			Vector3(0, base_y + 0.08, float(end) * (size.z * 0.5 + 0.028)),
			Vector3(size.x * 0.95, 0.09, 0.06),
			0.015
		)
		_box(
			car,
			paint(Color(0.78, 0.76, 0.63), 0.8),
			Vector3(0, base_y + 0.14, float(end) * (size.z * 0.5 + 0.063)),
			Vector3(0.18, 0.075, 0.008)
		)
	_box(car, dark, Vector3(0, base_y + 0.25, size.z * 0.5 + 0.009), Vector3(size.x * 0.38, 0.10, 0.016))
	if profile.has("twotone"):
		_box(
			car,
			paint(Color(0.86, 0.84, 0.75), 0.45),
			Vector3(0, base_y + size.y, 0),
			Vector3(size.x * 1.01, 0.06, size.z * 0.98),
			0.01
		)
		_box(
			car,
			chrome,
			cabin + Vector3(0, float(profile["cabin"]) * 0.53, -0.18),
			Vector3(size.x * 0.76, 0.04, size.z * 0.53),
			0.02
		)
	if profile.has("bed"):
		_box(
			car,
			paint(color.darkened(0.30), 0.8),
			Vector3(0, base_y + size.y + 0.01, -size.z * 0.31),
			Vector3(size.x * 0.75, 0.025, size.z * 0.27),
			0.02
		)
	if profile.has("trailer"):
		_box(
			car,
			paint(Color(0.75, 0.75, 0.67), 0.75),
			Vector3(0, base_y + size.y * 1.15, -size.z * 0.18),
			Vector3(size.x * 1.04, size.y * 2.15, size.z * 0.62),
			0.045
		)
		for rib in 5:
			_box(
				car,
				chrome,
				Vector3(0, base_y + size.y * 1.15, -size.z * 0.44 + float(rib) * 0.36),
				Vector3(size.x * 1.055, size.y * 2.08, 0.022)
			)
	if profile.has("monster"):
		_box(
			car,
			paint(Color(0.91, 0.66, 0.17), 0.3),
			cabin + Vector3(0, float(profile["cabin"]) * 0.55, 0.12),
			Vector3(size.x * 0.78, 0.10, 0.14),
			0.025
		)


static func _add_lights_and_wheels(car: Node3D, kind: String, size: Vector2, radius: float, base_y: float) -> void:
	var brake := StandardMaterial3D.new()
	brake.albedo_color = Color(0.65, 0.055, 0.025)
	brake.emission_enabled = true
	brake.emission = Color(1.0, 0.08, 0.025)
	brake.emission_energy_multiplier = 0.25
	car.set_meta("brake_material", brake)
	for side in [-1.0, 1.0]:
		var head := paint(Color(0.94, 0.85, 0.61), 0.25, 0.0)
		head.emission_enabled = true
		head.emission = Color(0.85, 0.69, 0.36)
		head.emission_energy_multiplier = 0.65
		_box(
			car,
			head,
			Vector3(size.x * 0.30 * float(side), base_y + 0.18, size.y * 0.5 + 0.02),
			Vector3(0.16, 0.08, 0.028),
			0.01
		)
		_box(
			car,
			brake,
			Vector3(size.x * 0.32 * float(side), base_y + 0.16, -size.y * 0.5 - 0.02),
			Vector3(0.14, 0.08, 0.028),
			0.01
		)
	var wheels: Array[Node3D] = []
	var monster := kind == "monster"
	var tire_width := 0.24 if monster else 0.11
	var out_x := size.x * 0.5 + (0.10 if monster else 0.02)
	for side in [-1.0, 1.0]:
		for axle in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(out_x * float(side), radius, size.y * 0.32 * float(axle))
			_wheel(pivot, radius, tire_width, paint(Color(0.075, 0.09, 0.10), 0.92, 0.0))
			var hub := _wheel(pivot, radius * 0.48, tire_width + 0.018, paint(Color(0.48, 0.54, 0.56), 0.4, 0.55))
			hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			car.add_child(pivot)
			wheels.append(pivot)
	car.set_meta("wheels", wheels)


static func _wheel(parent: Node3D, radius: float, width: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.rotation_degrees.z = 90.0
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func roll(car: Node3D, distance: float) -> void:
	if car == null:
		return
	var spin := distance / float(car.get_meta("wheel_radius", WHEEL_RADIUS))
	for pivot in car.get_meta("wheels", []):
		(pivot as Node3D).rotation.x += spin


static func set_braking(car: Node3D, braking: bool) -> void:
	if car == null:
		return
	var material: StandardMaterial3D = car.get_meta("brake_material", null)
	if material != null:
		material.emission_energy_multiplier = 1.8 if braking else 0.25


static func paint(color: Color, roughness: float, metallic: float = 0.10) -> StandardMaterial3D:
	var key := "%s:%.2f:%.2f" % [color.to_html(), roughness, metallic]
	if _paints.has(key):
		return _paints[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_paints[key] = material
	return material


static func _box(parent: Node3D, material: Material, at: Vector3, size: Vector3, bevel: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if bevel > 0.0:
		instance.mesh = StylizedMesh.box(size, bevel)
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance
