class_name GuildHallZones
extends RefCounted
## The guild hall's layout: nine named zones, the furniture in them, and the
## numbers the hall, the navigation mesh and the tests all have to agree on.
##
## Everything is a constant, so the hall, the navmesh and the suites read the same
## table: a zone cannot be drawn somewhere the walkable grid does not know about.

const WIDTH := 26.0
const DEPTH := 20.0
const WALL_HEIGHT := 6.5
const WALL_THICKNESS := 0.5
const DOOR_WIDTH := 3.2

## Rect2 in world XZ: rect.position is (x, z), rect.size is (width, depth).
const ZONES := {
	"entrance": {
		"name_key": "zone.entrance",
		"rect": Rect2(2.0, 4.0, 4.0, 6.0),
		"floor": Color(0.24, 0.24, 0.34),
		"purpose": "The door the customers walk through.",
	},
	"lounge": {
		"name_key": "zone.lounge",
		"rect": Rect2(-6.0, 4.0, 8.0, 6.0),
		"floor": Color(0.2, 0.16, 0.32),
		"purpose": "Waiting benches for customers with an order.",
	},
	"counter": {
		"name_key": "zone.counter",
		"rect": Rect2(-13.0, 4.0, 7.0, 6.0),
		"floor": Color(0.24, 0.19, 0.28),
		"purpose": "Reception: the player hands goods over and takes the coins.",
	},
	"warehouse": {
		"name_key": "zone.warehouse",
		"rect": Rect2(6.0, 4.0, 7.0, 6.0),
		"floor": Color(0.19, 0.22, 0.3),
		"purpose": "Shelves the player picks goods from.",
	},
	"hall": {
		"name_key": "zone.hall",
		"rect": Rect2(-6.0, -10.0, 12.0, 14.0),
		"floor": Color(0.16, 0.17, 0.26),
		"purpose": "The open hall: training dummies, and room to walk.",
	},
	"mission_board": {
		"name_key": "zone.mission_board",
		"rect": Rect2(-13.0, -2.0, 7.0, 6.0),
		"floor": Color(0.2, 0.18, 0.3),
		"purpose": "Where adventurers are dispatched.",
	},
	"workshop": {
		"name_key": "zone.workshop",
		"rect": Rect2(-13.0, -10.0, 7.0, 8.0),
		"floor": Color(0.21, 0.18, 0.24),
		"purpose": "Repair bench for the guild's gear.",
	},
	"treasury": {
		"name_key": "zone.treasury",
		"rect": Rect2(6.0, -2.0, 7.0, 6.0),
		"floor": Color(0.26, 0.21, 0.16),
		"purpose": "The vault: carried coins are deposited here.",
	},
	"stair": {
		"name_key": "zone.stair",
		"rect": Rect2(6.0, -10.0, 7.0, 8.0),
		"floor": Color(0.18, 0.19, 0.27),
		"purpose": "Steps to the upper floor.",
	},
}

## Furniture: a box on the floor that blocks walking. `zone` must contain `rect`.
const PROPS := [
	{"zone": "counter", "kind": "counter", "rect": Rect2(-12.4, 8.2, 3.6, 1.2), "height": 1.1},
	{"zone": "counter", "kind": "shelf", "rect": Rect2(-12.4, 5.0, 1.0, 2.6), "height": 2.2},
	{"zone": "warehouse", "kind": "rack", "rect": Rect2(7.2, 5.0, 1.1, 4.0), "height": 2.4},
	{"zone": "warehouse", "kind": "rack", "rect": Rect2(9.6, 5.0, 1.1, 4.0), "height": 2.4},
	{"zone": "warehouse", "kind": "rack", "rect": Rect2(11.8, 5.0, 1.1, 4.0), "height": 2.4},
	{"zone": "warehouse", "kind": "crate", "rect": Rect2(8.5, 5.0, 1.0, 0.9), "height": 1.0},
	{"zone": "lounge", "kind": "bench", "rect": Rect2(-5.6, 5.2, 3.0, 0.8), "height": 0.55},
	{"zone": "lounge", "kind": "bench", "rect": Rect2(-1.6, 5.2, 3.0, 0.8), "height": 0.55},
	{"zone": "lounge", "kind": "plant", "rect": Rect2(-5.9, 8.6, 0.9, 0.9), "height": 1.6},
	{"zone": "mission_board", "kind": "board", "rect": Rect2(-12.6, 2.4, 5.2, 0.4), "height": 2.8},
	{"zone": "mission_board", "kind": "bench", "rect": Rect2(-10.4, -1.2, 3.0, 0.8), "height": 0.55},
	{"zone": "treasury", "kind": "chest", "rect": Rect2(10.6, 1.0, 2.0, 1.4), "height": 1.2},
	{"zone": "treasury", "kind": "shelf", "rect": Rect2(6.8, -1.4, 1.0, 2.4), "height": 2.0},
	{"zone": "workshop", "kind": "counter", "rect": Rect2(-11.6, -8.2, 3.4, 1.1), "height": 1.0},
	{"zone": "workshop", "kind": "crate", "rect": Rect2(-12.2, -4.4, 1.2, 1.2), "height": 0.9},
	{"zone": "stair", "kind": "stair", "rect": Rect2(7.4, -7.6, 2.6, 4.2), "height": 1.6},
	{"zone": "hall", "kind": "dummy", "rect": Rect2(-3.4, -6.0, 0.9, 0.9), "height": 2.0},
	{"zone": "hall", "kind": "dummy", "rect": Rect2(2.5, -6.0, 0.9, 0.9), "height": 2.0},
	{"zone": "hall", "kind": "brazier", "rect": Rect2(-5.2, 3.0, 0.8, 0.8), "height": 1.2},
	{"zone": "hall", "kind": "brazier", "rect": Rect2(4.4, 3.0, 0.8, 0.8), "height": 1.2},
]

## Where the player and the customers appear.
const SPAWNS := {
	"player": Vector3(0.0, 0.0, 8.0),
	"door": Vector3(4.0, 0.0, 9.4),
	"customer_queue": Vector3(-2.4, 0.0, 6.4),
	"warehouse_pickup": Vector3(9.0, 0.0, 9.6),
	"counter_delivery": Vector3(-8.0, 0.0, 8.9),
	"treasury_deposit": Vector3(9.6, 0.0, 1.4),
	"mission_board": Vector3(-10.0, 0.0, 4.6),
}


## The queue in front of the counter, first place first. The counter desk faces
## north, so the line runs east along the desk instead of into it.
const QUEUE_LINE := [
	Vector3(-10.6, 0.0, 7.3),
	Vector3(-9.2, 0.0, 7.3),
	Vector3(-7.8, 0.0, 7.3),
	Vector3(-6.4, 0.0, 7.3),
]


static func queue_slot(index: int) -> Vector3:
	if index < 0 or index >= QUEUE_LINE.size():
		return SPAWNS["customer_queue"] as Vector3
	return QUEUE_LINE[index] as Vector3


static func queue_length() -> int:
	return QUEUE_LINE.size()


static func zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in ZONES:
		ids.append(str(id))
	ids.sort()
	return ids


static func zone(id: String) -> Dictionary:
	return ZONES.get(id, {})


static func rect(id: String) -> Rect2:
	var data := zone(id)
	return data.get("rect", Rect2()) as Rect2


static func center(id: String) -> Vector3:
	var box := rect(id)
	return Vector3(box.position.x + box.size.x * 0.5, 0.0, box.position.y + box.size.y * 0.5)


static func spawn(id: String) -> Vector3:
	return SPAWNS.get(id, Vector3.ZERO) as Vector3


## Which zone a world position stands in, or "" for outside the hall.
static func zone_at(point: Vector3) -> String:
	for id in ZONES:
		var box := rect(str(id))
		if box.has_point(Vector2(point.x, point.z)):
			return str(id)
	return ""


static func props_in(zone_id: String) -> Array:
	var found: Array = []
	for prop in PROPS:
		if str(prop["zone"]) == zone_id:
			found.append(prop)
	return found


## Footprints the navigation mesh has to walk around.
static func obstacle_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for prop in PROPS:
		rects.append(prop["rect"] as Rect2)
	return rects
