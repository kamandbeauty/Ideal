class_name Traffic
extends Node3D
## Purely cosmetic cars looping along the highway. The economy uses statistics,
## not these cars; they exist so the road feels alive.

const LANES: Array[float] = [-0.85, 0.85]
const ROAD_HALF_LENGTH := 19.0
const CAR_SPEED := 3.6
const CAR_COUNT := 7
const COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.25),
	Color(0.24, 0.42, 0.8),
	Color(0.92, 0.82, 0.3),
	Color(0.9, 0.9, 0.92),
	Color(0.3, 0.65, 0.45),
	Color(0.55, 0.4, 0.75),
]

var cars: Array[Node3D] = []


func _ready() -> void:
	for i in CAR_COUNT:
		_spawn_car(i)


func _spawn_car(index: int) -> void:
	var lane := index % LANES.size()
	var direction := 1.0 if lane == 0 else -1.0
	var car := Node3D.new()
	car.name = "Car%d" % index
	car.set_meta("direction", direction)
	car.position = Vector3(
		LANES[lane],
		0.05,
		lerpf(-ROAD_HALF_LENGTH, ROAD_HALF_LENGTH, float(index) / float(CAR_COUNT))
	)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.32, 1.05)
	body.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[index % COLORS.size()]
	material.metallic = 0.15
	material.roughness = 0.45
	body.material_override = material
	body.position.y = 0.16
	car.add_child(body)

	var roof := MeshInstance3D.new()
	var cabin := BoxMesh.new()
	cabin.size = Vector3(0.5, 0.26, 0.52)
	roof.mesh = cabin
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.16, 0.2, 0.26)
	glass.roughness = 0.2
	glass.metallic = 0.4
	roof.material_override = glass
	roof.position = Vector3(0, 0.42, -0.05)
	car.add_child(roof)

	# Headlights so the direction of travel reads at a glance.
	for side in [-1.0, 1.0]:
		var light := MeshInstance3D.new()
		var bulb := BoxMesh.new()
		bulb.size = Vector3(0.12, 0.08, 0.03)
		light.mesh = bulb
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.95, 0.75)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.92, 0.6)
		glow.emission_energy_multiplier = 1.4
		light.material_override = glow
		light.position = Vector3(0.18 * side, 0.16, 0.53 * direction)
		car.add_child(light)

	add_child(car)
	cars.append(car)


func _process(delta: float) -> void:
	for car in cars:
		var direction := float(car.get_meta("direction", 1.0))
		car.position.z += direction * CAR_SPEED * delta
		if car.position.z > ROAD_HALF_LENGTH:
			car.position.z = -ROAD_HALF_LENGTH
		elif car.position.z < -ROAD_HALF_LENGTH:
			car.position.z = ROAD_HALF_LENGTH
