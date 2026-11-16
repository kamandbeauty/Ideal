class_name Traffic
extends Node3D
## Both highway lanes share the same swept-body rules as visiting customers.
## Faster vehicles brake behind slower ones; recycling waits for a safe gap.

const LANES: Array[float] = [ForecourtLayout.FAR_LANE_Z, ForecourtLayout.NEAR_LANE_Z]
const ROAD_HALF_LENGTH := ForecourtLayout.ROAD_END
const CAR_COUNT := 10
const SEED := 4242
const VEHICLES: Array[String] = ["camper", "truck", "camper", "car", "pickup", "camper", "suv", "truck", "bus", "car"]

var cars: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _yield_active := false


func _ready() -> void:
	_rng.seed = SEED
	for i in CAR_COUNT:
		_spawn(i)


func _spawn(index: int) -> void:
	var lane := index % LANES.size()
	var direction := 1.0 if lane == 1 else -1.0
	var car := VehicleBody.new()
	car.name = "HighwayVehicle%d" % index
	car.setup(VEHICLES[index], VehicleMesh.PAINTS[index % VehicleMesh.PAINTS.size()])
	car.position = ForecourtLayout.point(-26.0 + floorf(float(index) / 2.0) * 11.0, LANES[lane])
	car.rotation.y = direction * PI * 0.5
	add_child(car)
	car.set_route([ForecourtLayout.point(ROAD_HALF_LENGTH * direction, LANES[lane])])
	cars.append({"node": car, "direction": direction, "speed": _rng.randf_range(3.6, 5.0), "lane": lane})


func _physics_process(delta: float) -> void:
	var yielding := false
	for body in get_tree().get_nodes_in_group(VehicleBody.GROUP):
		if (body as VehicleBody).merge_requested:
			yielding = true
			break
	_yield_active = yielding
	for entry in cars:
		var car: VehicleBody = entry["node"]
		if car.arrived():
			car.visible = false
			car.collision_layer = 0
			var direction := float(entry["direction"])
			var lane := int(entry["lane"])
			var start := ForecourtLayout.point(-ROAD_HALF_LENGTH * direction, LANES[lane])
			if not VehicleBody.spawn_clear(self, car.kind, start, direction * PI * 0.5):
				continue
			car.position = start
			car.speed = 0.0
			car.visible = true
			car.collision_layer = VehicleBody.VEHICLE_LAYER
			car.set_route([ForecourtLayout.point(ROAD_HALF_LENGTH * direction, LANES[lane])])
			entry["gate_seen"] = false
		if not yielding:
			entry["gate_seen"] = false
			entry["merge_pass"] = false
		elif not bool(entry.get("gate_seen", false)):
			entry["gate_seen"] = true
			# A car already too close to brake safely must clear the junction.
			var braking_distance := car.speed * car.speed / (2.0 * DrivingRules.BRAKING)
			var nose := car.position.x + car.dimensions.y * 0.5
			entry["merge_pass"] = nose + braking_distance + 0.55 >= ForecourtLayout.MERGE_STOP_X
		var cruise := float(entry["speed"])
		if yielding and float(entry["direction"]) > 0.0 and not bool(entry.get("merge_pass", false)):
			var available := ForecourtLayout.MERGE_STOP_X - car.position.x - car.dimensions.y * 0.5
			cruise = minf(cruise, DrivingRules.stopping_speed(available, cruise))
		car.drive(delta, cruise)


func can_merge() -> bool:
	if not _yield_active:
		return false
	for entry in cars:
		var car: VehicleBody = entry["node"]
		if float(entry["direction"]) < 0.0 or not car.visible or car.collision_layer == 0:
			continue
		if not bool(entry.get("gate_seen", false)):
			return false
		# Include cars still approaching but too close to stop: looking only at
		# their CURRENT junction rectangle would grant a conflicting merge.
		if bool(entry.get("merge_pass", true)) and car.position.x < ForecourtLayout.DRIVE_X + 4.0:
			return false
	return true
