class_name CityData
extends RefCounted
## The catalogue: every structure, its price, what it gives the city, and the
## auto-tiling rules for the road network.
##
## Pure, static data so the tests can read it without a scene tree.

const GRID_SIZE := 24
const HALF_GRID := GRID_SIZE / 2
const INVALID_CELL := Vector2i(9999, 9999)
const HALL_ID := "town_hall"

# Neighbour bits. North is -Z, east is +X, south is +Z, west is -X.
const DIR_N := 1
const DIR_E := 2
const DIR_S := 4
const DIR_W := 8
const DIRS: Array[int] = [DIR_N, DIR_E, DIR_S, DIR_W]

const CATEGORIES: Array[String] = ["road", "residential", "commercial", "nature", "civic"]

## model ids -> the .glb that draws them
const MODEL_PATHS := {
	"road-straight": "res://assets/models/road-straight.glb",
	"road-corner": "res://assets/models/road-corner.glb",
	"road-split": "res://assets/models/road-split.glb",
	"road-intersection": "res://assets/models/road-intersection.glb",
	"building-small-a": "res://assets/models/building-small-a.glb",
	"building-small-b": "res://assets/models/building-small-b.glb",
	"building-small-c": "res://assets/models/building-small-c.glb",
	"building-small-d": "res://assets/models/building-small-d.glb",
	"building-garage": "res://assets/models/building-garage.glb",
	"grass": "res://assets/models/grass.glb",
	"grass-trees": "res://assets/models/grass-trees.glb",
	"grass-trees-tall": "res://assets/models/grass-trees-tall.glb",
	"pavement": "res://assets/models/pavement.glb",
	"pavement-fountain": "res://assets/models/pavement-fountain.glb",
}

## Which edges each road model joins when it is not rotated.
const ROAD_PIECES := {
	"road-straight": DIR_N | DIR_S,
	"road-corner": DIR_S | DIR_W,
	"road-split": DIR_E | DIR_S | DIR_W,
	"road-intersection": DIR_N | DIR_E | DIR_S | DIR_W,
}
const ROAD_PIECE_ORDER: Array[String] = [
	"road-intersection", "road-split", "road-corner", "road-straight"
]

const STRUCTURES := {
	"road": {
		"category": "road",
		"cost": 30,
		"model": "road-straight",
		"rotatable": false,
		"needs_road": false,
		"population": 0.0,
		"income": 0.0,
		"happiness": 0.0,
		"pollution": 0.0,
	},
	"house_a": {
		"category": "residential",
		"cost": 120,
		"model": "building-small-a",
		"rotatable": true,
		"needs_road": true,
		"population": 4.0,
		"income": 0.3,
		"happiness": 0.0,
		"pollution": 0.0,
	},
	"house_b": {
		"category": "residential",
		"cost": 170,
		"model": "building-small-b",
		"rotatable": true,
		"needs_road": true,
		"population": 7.0,
		"income": 0.6,
		"happiness": 0.0,
		"pollution": 0.0,
	},
	"house_d": {
		"category": "residential",
		"cost": 300,
		"model": "building-small-d",
		"rotatable": true,
		"needs_road": true,
		"population": 15.0,
		"income": 1.4,
		"happiness": 0.0,
		"pollution": 0.0,
	},
	"shop": {
		"category": "commercial",
		"cost": 220,
		"model": "building-garage",
		"rotatable": true,
		"needs_road": true,
		"population": 0.0,
		"income": 2.2,
		"happiness": 0.0,
		"pollution": 2.0,
	},
	"grass": {
		"category": "nature",
		"cost": 10,
		"model": "grass",
		"rotatable": false,
		"needs_road": false,
		"population": 0.0,
		"income": 0.0,
		"happiness": 1.0,
		"pollution": 0.0,
	},
	"trees": {
		"category": "nature",
		"cost": 30,
		"model": "grass-trees",
		"rotatable": false,
		"needs_road": false,
		"population": 0.0,
		"income": 0.0,
		"happiness": 3.0,
		"pollution": 0.0,
	},
	"tall_trees": {
		"category": "nature",
		"cost": 50,
		"model": "grass-trees-tall",
		"rotatable": false,
		"needs_road": false,
		"population": 0.0,
		"income": 0.0,
		"happiness": 4.5,
		"pollution": 0.0,
	},
	"pavement": {
		"category": "civic",
		"cost": 20,
		"model": "pavement",
		"rotatable": false,
		"needs_road": false,
		"population": 0.0,
		"income": 0.0,
		"happiness": 1.5,
		"pollution": 0.0,
	},
	"fountain": {
		"category": "civic",
		"cost": 90,
		"model": "pavement-fountain",
		"rotatable": false,
		"needs_road": false,
		"population": 0.0,
		"income": 0.0,
		"happiness": 8.0,
		"pollution": 0.0,
	},
	"town_hall": {
		"category": "civic",
		"cost": 0,
		"model": "building-small-c",
		"rotatable": false,
		"needs_road": false,
		"population": 0.0,
		"income": 0.0,
		"happiness": 2.0,
		"pollution": 0.0,
	},
}


static func has_structure(id: String) -> bool:
	return STRUCTURES.has(id)


static func structure(id: String) -> Dictionary:
	if not has_structure(id):
		return {}
	return STRUCTURES[id]


static func cost(id: String) -> int:
	return int(structure(id).get("cost", 0))


static func refund(id: String) -> int:
	return int(floor(cost(id) * 0.5))


static func category_of(id: String) -> String:
	return str(structure(id).get("category", ""))


static func needs_road(id: String) -> bool:
	return bool(structure(id).get("needs_road", false))


static func model_of(id: String) -> String:
	return str(structure(id).get("model", ""))


static func model_path(model_id: String) -> String:
	return str(MODEL_PATHS.get(model_id, ""))


## Buildable structures in a category, cheapest first. The town hall is never
## offered to the player.
static func ids_in_category(category: String) -> Array[String]:
	var ids: Array[String] = []
	for id in STRUCTURES:
		if id == HALL_ID:
			continue
		if category_of(id) == category:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		if cost(a) == cost(b):
			return a < b
		return cost(a) < cost(b)
	)
	return ids


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in STRUCTURES:
		ids.append(id)
	ids.sort()
	return ids


static func dir_offset(dir: int) -> Vector2i:
	match dir:
		DIR_N:
			return Vector2i(0, -1)
		DIR_E:
			return Vector2i(1, 0)
		DIR_S:
			return Vector2i(0, 1)
		DIR_W:
			return Vector2i(-1, 0)
	return Vector2i.ZERO


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRS:
		result.append(cell + dir_offset(dir))
	return result


## Roads leave through exactly the edges where a road neighbour exists.
static func road_mask(cells: Dictionary, cell: Vector2i) -> int:
	var mask := 0
	for dir in DIRS:
		if str(cells.get(cell + dir_offset(dir), "")) == "road":
			mask |= dir
	return mask


## Rotate a set of edge bits counter-clockwise, matching a positive rotation
## about the Y axis in Godot.
static func rotate_mask(mask: int, steps: int) -> int:
	var rotated := 0
	for i in DIRS.size():
		if mask & DIRS[i]:
			rotated |= DIRS[(i - steps + 4) % 4]
	return rotated


## Pick the road model and rotation that draws the given edge mask.
static func road_piece(mask: int) -> Dictionary:
	var clean := mask & 15
	if clean == 0:
		return {"model": "road-straight", "rotation": 0}
	if clean == DIR_E or clean == DIR_W:
		return {"model": "road-straight", "rotation": 1}
	if clean == DIR_N or clean == DIR_S:
		return {"model": "road-straight", "rotation": 0}
	for model in ROAD_PIECE_ORDER:
		var base: int = ROAD_PIECES[model]
		for steps in 4:
			if rotate_mask(base, steps) == clean:
				return {"model": model, "rotation": steps}
	# Two opposite directions: a straight piece turned across the flow.
	return {"model": "road-straight", "rotation": 0 if (clean & DIR_N) else 1}
