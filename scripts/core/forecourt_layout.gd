class_name ForecourtLayout
extends RefCounted
## One source of truth for paving, physical obstacles, parking and routes.
## West spine: inbound/southbound. East spine: outbound/northbound.
## Row aisles are eastbound only. Parking manoeuvres hold a FIFO row lock.

const DRIVE_X := 9.6
const BAY_SPACING := 1.70
const BAY_Z := 2.85
const AISLE_Z := 5.0
const VEHICLE_Y := 0.075
const HIGHWAY_Z := -6.8
const NEAR_LANE_Z := HIGHWAY_Z + 0.82
const FAR_LANE_Z := HIGHWAY_Z - 0.82
const ROAD_END := 31.0
const LOT_BOUNDS := Rect2(-10.85, -4.5, 21.7, 33.0)
const BUILDING_SIZE := Vector2(3.4, 3.2)


static func row_for(id: String) -> int:
	return roundi((BusinessData.plot(id).y + 1.2) / 7.6)


static func aisle_z(id: String) -> float:
	return BusinessData.plot(id).y + AISLE_Z


## Slots never recenter when a capacity upgrade unlocks another pump.
static func bay_position(id: String, slot: int) -> Vector3:
	var plot := BusinessData.plot(id)
	var x := plot.x + (float(slot) - float(BusinessData.max_bays(id) - 1) * 0.5) * BAY_SPACING
	return point(x, plot.y + BAY_Z)


static func staging_position(id: String, slot: int) -> Vector3:
	return point(bay_position(id, slot).x, aisle_z(id))


static func building_rect(id: String) -> Rect2:
	return Rect2(BusinessData.plot(id) - BUILDING_SIZE * 0.5, BUILDING_SIZE)


static func prop_rects(id: String, bays: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not ["gas_station", "car_wash", "auto_service", "electric_charger"].has(id):
		return result
	for slot in bays:
		var at := DrivingRules.xz(bay_position(id, slot))
		if id == "gas_station" or id == "electric_charger":
			var offset := Vector2(-0.82, -0.12 if id == "gas_station" else 0.0)
			result.append(Rect2(at + offset - Vector2(0.08, 0.18), Vector2(0.16, 0.36)))
		else:
			for side in [-0.80, 0.80]:
				result.append(Rect2(at + Vector2(float(side) - 0.05, 0.01), Vector2(0.10, 0.22)))
	return result


static func inbound(id: String, slot: int) -> Array[Vector3]:
	var bay := bay_position(id, slot)
	var corners: Array[Vector3] = [
		point(-ROAD_END, NEAR_LANE_Z),
		point(-DRIVE_X, NEAR_LANE_Z),
		point(-DRIVE_X, aisle_z(id)),
		staging_position(id, slot),
		bay,
	]
	return rounded(corners, 0.85)


static func reverse_out(id: String, slot: int) -> Array[Vector3]:
	return [bay_position(id, slot), staging_position(id, slot)]


static func outbound(id: String, slot: int) -> Array[Vector3]:
	var corners: Array[Vector3] = [
		staging_position(id, slot),
		point(DRIVE_X, aisle_z(id)),
		point(DRIVE_X, NEAR_LANE_Z),
		point(ROAD_END, NEAR_LANE_Z),
	]
	return rounded(corners, 0.85)


static func point(x: float, z: float) -> Vector3:
	return Vector3(x, VEHICLE_Y, z)


## Quadratic corner arcs, not diagonal shortcuts across the neighbouring lot.
static func rounded(corners: Array[Vector3], radius: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if corners.is_empty():
		return result
	result.append(corners[0])
	for i in range(1, corners.size() - 1):
		var before := corners[i - 1] - corners[i]
		var after := corners[i + 1] - corners[i]
		var trim := minf(radius, minf(before.length(), after.length()) * 0.42)
		var a := corners[i] + before.normalized() * trim
		var b := corners[i] + after.normalized() * trim
		result.append(a)
		for step in range(1, 9):
			var t := float(step) / 8.0
			result.append(a.lerp(corners[i], t).lerp(corners[i].lerp(b, t), t))
	result.append(corners[-1])
	return result
