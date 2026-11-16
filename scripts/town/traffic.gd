class_name Traffic
extends Node3D
## Two-lane desert highway traffic cruising along z = -6.8 (both directions):
## colorful two-tone campervans, pickups, semi-trucks, sedans and Monster Trucks!

const HIGHWAY_Z := -6.8
const LANES: Array[float] = [HIGHWAY_Z - 0.82, HIGHWAY_Z + 0.82]
const ROAD_HALF_LENGTH := 26.0
const CAR_COUNT := 10
const SEED := 4242

const VEHICLES: Array[Dictionary] = [
	{"kind": "camper", "paint": 0},
	{"kind": "truck", "paint": 7},
	{"kind": "camper", "paint": 1},
	{"kind": "car", "paint": 3},
	{"kind": "pickup", "paint": 4},
	{"kind": "camper", "paint": 2},
	{"kind": "suv", "paint": 5},
	{"kind": "truck", "paint": 0},
	{"kind": "bus", "paint": 6},
	{"kind": "car", "paint": 8},
]

var cars: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	for i in CAR_COUNT:
		_spawn(i)


func _spawn(index: int) -> void:
	var lane_index := index % LANES.size()
	var direction := 1.0 if lane_index == 1 else -1.0
	var spec: Dictionary = VEHICLES[index % VEHICLES.size()]

	var car := VehicleMesh.build(
		String(spec["kind"]), VehicleMesh.PAINTS[int(spec["paint"])]
	)
	car.name = "HighwayVehicle%d" % index
	car.position = Vector3(
		lerpf(-ROAD_HALF_LENGTH, ROAD_HALF_LENGTH, float(index) / float(CAR_COUNT))
		+ _rng.randf_range(-1.4, 1.4),
		0.03,
		LANES[lane_index]
	)
	# Vehicle nose points along +Z by default, so +90 faces +X and -90 faces -X!
	car.rotation_degrees.y = 90.0 if direction > 0.0 else -90.0
	add_child(car)
	cars.append({
		"node": car,
		"direction": direction,
		"speed": _rng.randf_range(3.4, 5.2),
	})


func _process(delta: float) -> void:
	for entry in cars:
		var car: Node3D = entry["node"]
		var direction := float(entry["direction"])
		var speed := float(entry["speed"])
		var step := direction * speed * delta
		car.position.x += step
		if car.position.x > ROAD_HALF_LENGTH:
			car.position.x = -ROAD_HALF_LENGTH
		elif car.position.x < -ROAD_HALF_LENGTH:
			car.position.x = ROAD_HALF_LENGTH
		VehicleMesh.roll(car, absf(step))
