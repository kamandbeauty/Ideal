class_name Traffic
extends Node3D
## Cosmetic highway traffic: cars, vans and trucks with wheels, headlights and
## brake lights. The economy is statistical, so these never affect income.

const LANES: Array[float] = [-0.9, 0.9]
const ROAD_HALF_LENGTH := 19.0
const CAR_COUNT := 8
const WHEEL_RADIUS := 0.13
const SEED := 4242

const BODY_COLORS: Array[Color] = [
	Color(0.82, 0.24, 0.22),
	Color(0.22, 0.4, 0.78),
	Color(0.9, 0.78, 0.28),
	Color(0.88, 0.88, 0.9),
	Color(0.26, 0.6, 0.42),
	Color(0.55, 0.38, 0.72),
	Color(0.95, 0.55, 0.2),
	Color(0.16, 0.18, 0.22),
]

var cars: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	for i in CAR_COUNT:
		_spawn(i)


func _spawn(index: int) -> void:
	var lane_index := index % LANES.size()
	var direction := 1.0 if lane_index == 0 else -1.0
	var kind := index % 3
	var spec := _spec(kind)

	var car := Node3D.new()
	car.name = "Vehicle%d" % index
	car.position = Vector3(
		LANES[lane_index],
		0.0,
		lerpf(-ROAD_HALF_LENGTH, ROAD_HALF_LENGTH, float(index) / float(CAR_COUNT)) +
			_rng.randf_range(-1.2, 1.2)
	)
	if direction < 0.0:
		car.rotation_degrees.y = 180.0

	var length := float(spec["length"])
	var width := float(spec["width"])
	var body_height := float(spec["body"])
	var color: Color = BODY_COLORS[index % BODY_COLORS.size()]
	if kind == 2:
		color = color.lerp(Color(0.85, 0.85, 0.82), 0.35)

	# Body.
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, body_height, length)
	body.mesh = box
	body.position.y = WHEEL_RADIUS + body_height * 0.5
	body.material_override = _paint(color, 0.35)
	car.add_child(body)

	# Cabin / trailer.
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(
		width * (0.92 if kind == 0 else 0.98),
		float(spec["cabin"]),
		length * (0.48 if kind == 0 else 0.72)
	)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(
		0.0,
		WHEEL_RADIUS + body_height + float(spec["cabin"]) * 0.5,
		float(spec["cabin_offset"]) * length
	)
	cabin.material_override = _paint(Color(0.14, 0.18, 0.24), 0.15)
	car.add_child(cabin)

	# Windscreen sheen.
	var glass := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(width * 0.78, float(spec["cabin"]) * 0.55, 0.04)
	glass.mesh = glass_mesh
	glass.position = cabin.position + Vector3(0, 0.0, length * 0.24)
	glass.material_override = _paint(Color(0.6, 0.78, 0.9), 0.05, 0.5)
	car.add_child(glass)

	# Lights.
	var front := length * 0.5
	for side in [-1.0, 1.0]:
		_add_light(car, Vector3(width * 0.28 * side, WHEEL_RADIUS + 0.12, front - 0.01),
			Color(1.0, 0.94, 0.72), 1.8, 0.12)
		_add_light(car, Vector3(width * 0.30 * side, WHEEL_RADIUS + 0.13, -front + 0.01),
			Color(1.0, 0.18, 0.12), 1.0, 0.1)

	# Wheels on pivots so they can spin.
	var wheels: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		for axle in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(
				(width * 0.5 + 0.02) * side,
				WHEEL_RADIUS,
				length * 0.3 * axle
			)
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = WHEEL_RADIUS
			cylinder.bottom_radius = WHEEL_RADIUS
			cylinder.height = 0.09
			cylinder.radial_segments = 10
			wheel.mesh = cylinder
			wheel.rotation_degrees.z = 90.0
			wheel.material_override = _paint(Color(0.09, 0.1, 0.12), 0.6)
			pivot.add_child(wheel)
			car.add_child(pivot)
			wheels.append(pivot)

	add_child(car)
	cars.append({
		"node": car,
		"wheels": wheels,
		"direction": direction,
		"speed": _rng.randf_range(3.0, 4.6),
	})


func _spec(kind: int) -> Dictionary:
	match kind:
		1:
			return {
				"length": 1.5, "width": 0.6, "body": 0.44,
				"cabin": 0.4, "cabin_offset": -0.12,
			}
		2:
			return {
				"length": 2.0, "width": 0.68, "body": 0.56,
				"cabin": 0.5, "cabin_offset": -0.34,
			}
	return {
		"length": 1.05, "width": 0.55, "body": 0.3,
		"cabin": 0.26, "cabin_offset": -0.05,
	}


func _paint(color: Color, roughness: float, metallic: float = 0.15) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _add_light(
	parent: Node3D, position: Vector3, color: Color, energy: float, size: float
) -> void:
	var light := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size * 2.2, size, 0.03)
	light.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	light.material_override = material
	light.position = position
	parent.add_child(light)


func _process(delta: float) -> void:
	for entry in cars:
		var car: Node3D = entry["node"]
		var direction := float(entry["direction"])
		var speed := float(entry["speed"])
		car.position.z += direction * speed * delta
		if car.position.z > ROAD_HALF_LENGTH:
			car.position.z = -ROAD_HALF_LENGTH
		elif car.position.z < -ROAD_HALF_LENGTH:
			car.position.z = ROAD_HALF_LENGTH
		for wheel in entry["wheels"]:
			(wheel as Node3D).rotation.x -= speed * delta / WHEEL_RADIUS
