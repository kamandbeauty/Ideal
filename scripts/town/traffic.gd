class_name Traffic
extends Node3D
## Cosmetic highway traffic: cars, vans and trucks with wheels, headlights and
## brake lights. The economy is statistical, so these never affect income.

const LANES: Array[float] = [-0.85, 0.85]
const ROAD_HALF_LENGTH := 19.0
const CAR_COUNT := 10
const SEED := 4242

## Ten vehicles, six silhouettes: the highway is never all the same hatchback.
const VEHICLES: Array[Dictionary] = [
	{"kind": "car", "paint": 0}, {"kind": "suv", "paint": 1},
	{"kind": "pickup", "paint": 4}, {"kind": "truck", "paint": 3},
	{"kind": "bus", "paint": 2}, {"kind": "camper", "paint": 5},
	{"kind": "car", "paint": 6}, {"kind": "suv", "paint": 8},
	{"kind": "truck", "paint": 7}, {"kind": "car", "paint": 9},
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
	var spec: Dictionary = VEHICLES[index % VEHICLES.size()]

	var car := VehicleMesh.build(
		String(spec["kind"]), VehicleMesh.PAINTS[int(spec["paint"])]
	)
	car.name = "Vehicle%d" % index
	car.position = Vector3(
		LANES[lane_index],
		0.0,
		lerpf(-ROAD_HALF_LENGTH, ROAD_HALF_LENGTH, float(index) / float(CAR_COUNT)) +
			_rng.randf_range(-1.2, 1.2)
	)
	if direction < 0.0:
		car.rotation_degrees.y = 180.0
	add_child(car)
	cars.append({
		"node": car,
		"direction": direction,
		"speed": _rng.randf_range(3.0, 4.6),
	})


func _process(delta: float) -> void:
	for entry in cars:
		var car: Node3D = entry["node"]
		var direction := float(entry["direction"])
		var speed := float(entry["speed"])
		var step := direction * speed * delta
		car.position.z += step
		if car.position.z > ROAD_HALF_LENGTH:
			car.position.z = -ROAD_HALF_LENGTH
		elif car.position.z < -ROAD_HALF_LENGTH:
			car.position.z = ROAD_HALF_LENGTH
		VehicleMesh.roll(car, absf(step))
