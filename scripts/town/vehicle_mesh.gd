class_name VehicleMesh
extends RefCounted
## The shared vehicle builder. Six silhouettes cover the traffic and the
## customers who stop at the town, so a bus is recognisably a bus and a camper
## never turns into a delivery truck.
##
## Built from boxes on purpose: the whole thing is ~40 triangles and every
## vehicle carries its wheel pivots as metadata so callers can spin them.

const KINDS: Array[String] = ["car", "suv", "pickup", "truck", "bus", "camper"]

const PAINTS: Array[Color] = [
	Color(0.78, 0.2, 0.2),    # cherry
	Color(0.95, 0.91, 0.8),   # cream
	Color(0.24, 0.66, 0.66),  # turquoise
	Color(0.93, 0.71, 0.24),  # mustard
	Color(0.35, 0.55, 0.62),  # dusty blue
	Color(0.72, 0.45, 0.52),  # salmon
	Color(0.2, 0.36, 0.4),    # deep teal
	Color(0.16, 0.2, 0.24),   # black
	Color(0.86, 0.64, 0.42),  # copper
	Color(0.6, 0.66, 0.5),    # avocado
] = [
	Color(0.82, 0.24, 0.22),
	Color(0.22, 0.4, 0.78),
	Color(0.9, 0.74, 0.24),
	Color(0.88, 0.88, 0.9),
	Color(0.26, 0.6, 0.42),
	Color(0.55, 0.38, 0.72),
	Color(0.95, 0.55, 0.2),
	Color(0.2, 0.22, 0.26),
	Color(0.36, 0.72, 0.74),
	Color(0.72, 0.3, 0.45),
]

const WHEEL_RADIUS := 0.16
## The kit city is built at roughly one unit = one metre; vehicles shrink a
## little so a bus never outsizes a shop.
const SIZE_SCALE := 0.78


static func spec(kind: String) -> Dictionary:
	match kind:
		"suv":
			return {
				"length": 2.0, "width": 0.78, "body": 0.46,
				"cabin": 0.4, "cabin_offset": -0.02, "cabin_length": 0.62,
			}
		"pickup":
			return {
				"length": 2.2, "width": 0.8, "body": 0.4,
				"cabin": 0.42, "cabin_offset": 0.34, "cabin_length": 0.42,
				"bed": true,
			}
		"truck":
			return {
				"length": 3.0, "width": 0.84, "body": 0.5,
				"cabin": 0.62, "cabin_offset": 0.62, "cabin_length": 0.3,
				"trailer": true,
			}
		"bus":
			return {
				"length": 3.4, "width": 0.86, "body": 0.66,
				"cabin": 0.34, "cabin_offset": -0.06, "cabin_length": 0.94,
				"windows": true,
			}
		"camper":
			return {
				"length": 2.6, "width": 0.84, "body": 0.62,
				"cabin": 0.24, "cabin_offset": -0.16, "cabin_length": 0.8,
				"stripe": true,
			}
	return {
		"length": 1.7, "width": 0.72, "body": 0.34,
		"cabin": 0.34, "cabin_offset": -0.04, "cabin_length": 0.5,
	}


static func build(kind: String, color: Color) -> Node3D:
	var profile := spec(kind)
	var length := float(profile["length"])
	var width := float(profile["width"])
	var body_height := float(profile["body"])
	var cabin_height := float(profile["cabin"])
	var cabin_length := float(profile.get("cabin_length", 0.5))

	var car := Node3D.new()
	car.name = "Vehicle_%s" % kind
	car.set_meta("kind", kind)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(width, body_height, length)
	body.mesh = body_mesh
	body.position.y = WHEEL_RADIUS + body_height * 0.5
	body.material_override = paint(color, 0.35)
	car.add_child(body)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(width * 0.9, cabin_height, length * cabin_length)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(
		0.0,
		WHEEL_RADIUS + body_height + cabin_height * 0.5 - 0.01,
		float(profile["cabin_offset"]) * length
	)
	cabin.material_override = paint(Color(0.14, 0.18, 0.24), 0.2)
	car.add_child(cabin)

	# Windscreen sheen on the nose of the cabin.
	var glass := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(width * 0.74, cabin_height * 0.5, 0.03)
	glass.mesh = glass_mesh
	glass.position = cabin.position + Vector3(0, 0.0, length * cabin_length * 0.5)
	glass.material_override = paint(Color(0.62, 0.8, 0.92), 0.05, 0.5)
	car.add_child(glass)

	if profile.has("bed"):
		var bed := MeshInstance3D.new()
		var bed_mesh := BoxMesh.new()
		bed_mesh.size = Vector3(width * 0.92, body_height * 0.7, length * 0.34)
		bed.mesh = bed_mesh
		bed.position = Vector3(0, WHEEL_RADIUS + body_height * 0.55, -length * 0.3)
		bed.material_override = paint(color.darkened(0.25), 0.6)
		car.add_child(bed)

	if profile.has("trailer"):
		var trailer := MeshInstance3D.new()
		var trailer_mesh := BoxMesh.new()
		trailer_mesh.size = Vector3(width * 1.02, body_height * 2.0, length * 0.6)
		trailer.mesh = trailer_mesh
		trailer.position = Vector3(0, WHEEL_RADIUS + body_height * 1.1, -length * 0.2)
		trailer.material_override = paint(Color(0.9, 0.9, 0.88), 0.55)
		car.add_child(trailer)

	if profile.has("windows"):
		for side in [-1.0, 1.0]:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(0.02, cabin_height * 0.8, length * 0.7)
			strip.mesh = strip_mesh
			strip.position = Vector3(width * 0.46 * side, cabin.position.y, cabin.position.z)
			strip.material_override = paint(Color(0.55, 0.72, 0.86), 0.1, 0.4)
			car.add_child(strip)

	if profile.has("stripe"):
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(width * 1.004, 0.1, length * 0.86)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(0, WHEEL_RADIUS + body_height * 0.5, 0)
		stripe.material_override = paint(Color(0.95, 0.95, 0.92), 0.5)
		car.add_child(stripe)

	var front := length * 0.5
	for side in [-1.0, 1.0]:
		_add_light(
			car, Vector3(width * 0.28 * side, WHEEL_RADIUS + 0.1, front - 0.01),
			Color(1.0, 0.94, 0.72)
		)
		_add_light(
			car, Vector3(width * 0.3 * side, WHEEL_RADIUS + 0.1, -front + 0.01),
			Color(1.0, 0.2, 0.14)
		)

	var wheels: Array[Node3D] = []
	var axles := [-1.0, 1.0]
	if kind == "bus" or kind == "truck":
		axles = [-1.0, 0.55]
	for side in [-1.0, 1.0]:
		for axle in axles:
			var pivot := Node3D.new()
			pivot.position = Vector3(
				(width * 0.5 + 0.02) * side, WHEEL_RADIUS, length * 0.32 * float(axle)
			)
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = WHEEL_RADIUS
			cylinder.bottom_radius = WHEEL_RADIUS
			cylinder.height = 0.1
			cylinder.radial_segments = 10
			wheel.mesh = cylinder
			wheel.rotation_degrees.z = 90.0
			wheel.material_override = paint(Color(0.09, 0.1, 0.12), 0.7, 0.05)
			pivot.add_child(wheel)
			car.add_child(pivot)
			wheels.append(pivot)

	car.set_meta("wheels", wheels)
	car.set_meta("length", length * SIZE_SCALE)
	car.scale = Vector3.ONE * SIZE_SCALE
	return car


## Kicks the whole wheel set forward; call it with the distance the car moved.
static func roll(car: Node3D, distance: float) -> void:
	var spin := distance / WHEEL_RADIUS
	var wheels: Array = car.get_meta("wheels", [])
	for pivot in wheels:
		(pivot as Node3D).rotation.x -= spin


static func paint(color: Color, roughness: float, metallic: float = 0.15) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func _add_light(parent: Node3D, position: Vector3, color: Color) -> void:
	var light := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.09, 0.03)
	light.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4
	light.material_override = material
	light.position = position
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(light)
