class_name VehicleMesh
extends RefCounted
## Roadside Empire vehicle builder: two-tone VW campervans, sedans, SUVs,
## pickups, semi-trucks, coaches and giant lifted Monster Trucks!

const KINDS: Array[String] = ["car", "suv", "pickup", "truck", "bus", "camper"]

const PAINTS: Array[Color] = [
	Color(0.95, 0.56, 0.20),  # orange camper
	Color(0.24, 0.72, 0.88),  # sky-blue camper
	Color(0.94, 0.44, 0.64),  # pink retro van
	Color(0.88, 0.24, 0.22),  # cherry red
	Color(0.95, 0.76, 0.22),  # sunny yellow
	Color(0.32, 0.54, 0.84),  # cobalt sedan
	Color(0.26, 0.72, 0.48),  # mint green
	Color(0.22, 0.26, 0.34),  # slate semi
	Color(0.92, 0.88, 0.80),  # cream cruiser
	Color(0.64, 0.40, 0.86),  # violet custom
]

const WHEEL_RADIUS := 0.16
const SIZE_SCALE := 0.82


static func spec(kind: String) -> Dictionary:
	match kind:
		"monster":
			return {
				"length": 2.35, "width": 1.08, "body": 0.48,
				"cabin": 0.44, "cabin_offset": 0.05, "cabin_length": 0.48,
				"monster": true,
			}
		"suv":
			return {
				"length": 2.0, "width": 0.80, "body": 0.46,
				"cabin": 0.40, "cabin_offset": -0.02, "cabin_length": 0.62,
			}
		"pickup":
			return {
				"length": 2.2, "width": 0.82, "body": 0.40,
				"cabin": 0.42, "cabin_offset": 0.22, "cabin_length": 0.42,
				"bed": true,
			}
		"truck":
			return {
				"length": 3.1, "width": 0.88, "body": 0.50,
				"cabin": 0.64, "cabin_offset": 0.34, "cabin_length": 0.28,
				"trailer": true,
			}
		"bus":
			return {
				"length": 3.3, "width": 0.88, "body": 0.66,
				"cabin": 0.36, "cabin_offset": -0.04, "cabin_length": 0.92,
				"windows": true,
			}
		"camper":
			return {
				"length": 2.45, "width": 0.86, "body": 0.54,
				"cabin": 0.42, "cabin_offset": 0.0, "cabin_length": 0.92,
				"twotone": true,
			}
	return {
		"length": 1.82, "width": 0.76, "body": 0.36,
		"cabin": 0.34, "cabin_offset": -0.04, "cabin_length": 0.52,
	}


static func build(kind: String, color: Color) -> Node3D:
	var profile := spec(kind)
	var is_monster := bool(profile.get("monster", false))
	var wheel_r := 0.34 if is_monster else WHEEL_RADIUS
	var lift := 0.24 if is_monster else 0.0
	var length := float(profile["length"])
	var width := float(profile["width"])
	var body_h := float(profile["body"])
	var cabin_h := float(profile["cabin"])
	var cabin_len := float(profile.get("cabin_length", 0.5))

	var car := Node3D.new()
	car.name = "Vehicle_%s" % kind
	car.set_meta("kind", kind)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(width, body_h, length)
	body.mesh = body_mesh
	body.position.y = wheel_r + lift + body_h * 0.5
	body.material_override = paint(color, 0.32)
	car.add_child(body)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(width * 0.94, cabin_h, length * cabin_len)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(
		0.0,
		wheel_r + lift + body_h + cabin_h * 0.5 - 0.01,
		float(profile["cabin_offset"]) * length
	)
	var cab_col := Color(0.97, 0.96, 0.93) if profile.has("twotone") else Color(0.20, 0.26, 0.34)
	cabin.material_override = paint(cab_col, 0.28)
	car.add_child(cabin)

	var glass := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(width * 0.80, cabin_h * 0.56, 0.04)
	glass.mesh = glass_mesh
	glass.position = cabin.position + Vector3(0.0, 0.0, length * cabin_len * 0.5)
	glass.material_override = paint(Color(0.58, 0.82, 0.96), 0.08, 0.45)
	car.add_child(glass)

	_add_silhouette_extras(car, profile, color, width, body_h, cabin_h, length, wheel_r + lift, cabin.position)
	_add_headlights_and_wheels(car, kind, is_monster, width, length, wheel_r)
	car.set_meta("length", length * SIZE_SCALE)
	car.scale = Vector3.ONE * SIZE_SCALE
	return car


static func _add_silhouette_extras(
	car: Node3D,
	profile: Dictionary,
	color: Color,
	width: float,
	body_h: float,
	cabin_h: float,
	length: float,
	base_y: float,
	cabin_pos: Vector3
) -> void:
	if profile.has("twotone"):
		var belt := MeshInstance3D.new()
		var belt_mesh := BoxMesh.new()
		belt_mesh.size = Vector3(width * 1.02, 0.08, length * 0.98)
		belt.mesh = belt_mesh
		belt.position = Vector3(0, base_y + body_h, 0)
		belt.material_override = paint(Color(0.98, 0.98, 0.96), 0.3)
		car.add_child(belt)
	if profile.has("bed"):
		var bed := MeshInstance3D.new()
		var bed_mesh := BoxMesh.new()
		bed_mesh.size = Vector3(width * 0.92, body_h * 0.65, length * 0.36)
		bed.mesh = bed_mesh
		bed.position = Vector3(0, base_y + body_h * 0.55, -length * 0.28)
		bed.material_override = paint(color.darkened(0.22), 0.55)
		car.add_child(bed)
	if profile.has("trailer"):
		var trailer := MeshInstance3D.new()
		var trailer_mesh := BoxMesh.new()
		trailer_mesh.size = Vector3(width * 1.04, body_h * 2.15, length * 0.62)
		trailer.mesh = trailer_mesh
		trailer.position = Vector3(0, base_y + body_h * 1.15, -length * 0.18)
		trailer.material_override = paint(Color(0.95, 0.95, 0.93), 0.45)
		car.add_child(trailer)
	if profile.has("windows"):
		for side in [-1.0, 1.0]:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(0.03, cabin_h * 0.72, length * 0.74)
			strip.mesh = strip_mesh
			strip.position = Vector3(width * 0.47 * side, cabin_pos.y, cabin_pos.z)
			strip.material_override = paint(Color(0.54, 0.78, 0.94), 0.1, 0.4)
			car.add_child(strip)
	if profile.has("monster"):
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(width * 0.78, 0.10, 0.14)
		bar.mesh = bar_mesh
		bar.position = cabin_pos + Vector3(0, cabin_h * 0.55, 0.12)
		bar.material_override = paint(Color(1.0, 0.84, 0.18), 0.2)
		car.add_child(bar)


static func _add_headlights_and_wheels(
	car: Node3D, kind: String, is_monster: bool, width: float, length: float, wheel_r: float
) -> void:
	var front := length * 0.5
	for side in [-1.0, 1.0]:
		_add_light(car, Vector3(width * 0.30 * side, wheel_r + 0.14, front - 0.01), Color(1.0, 0.95, 0.72))
		_add_light(car, Vector3(width * 0.32 * side, wheel_r + 0.14, -front + 0.01), Color(1.0, 0.22, 0.16))

	var wheels: Array[Node3D] = []
	var axles := [-1.0, 1.0]
	if kind == "bus" or kind == "truck":
		axles = [-1.0, 0.58]
	var tire_w := 0.24 if is_monster else 0.11
	var out_x := (width * 0.5 + (0.10 if is_monster else 0.02))
	for side in [-1.0, 1.0]:
		for axle in axles:
			var pivot := Node3D.new()
			pivot.position = Vector3(out_x * side, wheel_r, length * 0.32 * float(axle))
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = wheel_r
			cylinder.bottom_radius = wheel_r
			cylinder.height = tire_w
			cylinder.radial_segments = 12
			wheel.mesh = cylinder
			wheel.rotation_degrees.z = 90.0
			wheel.material_override = paint(Color(0.11, 0.12, 0.15), 0.75, 0.05)
			pivot.add_child(wheel)
			car.add_child(pivot)
			wheels.append(pivot)
	car.set_meta("wheels", wheels)


static func roll(car: Node3D, distance: float) -> void:
	var spin := distance / WHEEL_RADIUS
	var wheels: Array = car.get_meta("wheels", [])
	for pivot in wheels:
		(pivot as Node3D).rotation.x -= spin


static func paint(color: Color, roughness: float, metallic: float = 0.12) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func _add_light(parent: Node3D, pos: Vector3, color: Color) -> void:
	var light := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.20, 0.09, 0.03)
	light.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4
	light.material_override = material
	light.position = pos
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(light)
