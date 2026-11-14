class_name CityState
extends RefCounted
## The city itself: the grid, the money, the people and the rules that tie
## them together. No nodes and no rendering, so a whole city can be simulated
## and saved in a headless test.

signal changed
signal cash_changed(cash: float)
signal placed(cell: Vector2i, id: String)
signal removed(cell: Vector2i, id: String, refund: int)
signal milestone_reached(index: int, bonus: int)

const STARTING_CASH := 5000.0
const HALL_CELL := Vector2i(0, 0)
const MILESTONES: Array[int] = [20, 50, 100, 200]
const MILESTONE_BONUS: Array[int] = [400, 800, 1500, 2500]
const SAVE_PATH := "user://city.json"
const SAVE_VERSION := 1

var cash: float = STARTING_CASH
var population: float = 0.0
var elapsed: float = 0.0
var cells: Dictionary = {}
var rotations: Dictionary = {}
var reached_milestones: int = 0

# Recomputed whenever the grid changes.
var capacity: float = 0.0
var income: float = 0.0
var happiness: float = 45.0
var green_bonus: float = 0.0
var pollution: float = 0.0
var connected_buildings: int = 0
var unconnected_buildings: int = 0
var road_cells: int = 0


func _init(with_hall: bool = true) -> void:
	if with_hall:
		place_free(CityData.HALL_ID, HALL_CELL, 0)


# --- Queries ---------------------------------------------------------------

func cell_in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= -CityData.HALF_GRID
		and cell.x < CityData.HALF_GRID
		and cell.y >= -CityData.HALF_GRID
		and cell.y < CityData.HALF_GRID
	)


func structure_at(cell: Vector2i) -> String:
	return str(cells.get(cell, ""))


func rotation_at(cell: Vector2i) -> int:
	return int(rotations.get(cell, 0))


func is_road(cell: Vector2i) -> bool:
	return structure_at(cell) == "road"


func is_empty(cell: Vector2i) -> bool:
	return not cells.has(cell)


func has_hall() -> bool:
	return structure_at(HALL_CELL) == CityData.HALL_ID


func occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell)
	return result


func can_place(id: String, cell: Vector2i) -> bool:
	return (
		CityData.has_structure(id)
		and id != CityData.HALL_ID
		and cell_in_bounds(cell)
		and is_empty(cell)
		and cash >= float(CityData.cost(id))
	)


func income_per_second() -> float:
	return (income + population * 0.06) * (0.4 + 0.6 * happiness / 100.0)


func next_milestone_index() -> int:
	return reached_milestones


func next_milestone() -> int:
	if reached_milestones >= MILESTONES.size():
		return -1
	return MILESTONES[reached_milestones]


# --- Changes ---------------------------------------------------------------

func place(id: String, cell: Vector2i, rotation: int = 0) -> bool:
	if not can_place(id, cell):
		return false
	cash -= float(CityData.cost(id))
	cells[cell] = id
	rotations[cell] = posmod(rotation, 4)
	recompute()
	placed.emit(cell, id)
	cash_changed.emit(cash)
	return true


## Places without charging: the town hall, loading a save and undoing a sale.
func place_free(id: String, cell: Vector2i, rotation: int = 0) -> bool:
	if not CityData.has_structure(id) or not cell_in_bounds(cell) or not is_empty(cell):
		return false
	cells[cell] = id
	rotations[cell] = posmod(rotation, 4)
	recompute()
	placed.emit(cell, id)
	return true


## Removes a structure. The town hall cannot be removed.
func remove(cell: Vector2i, refund_ratio: float = 0.5) -> Dictionary:
	var id := structure_at(cell)
	if id.is_empty() or id == CityData.HALL_ID:
		return {}
	var rotation := rotation_at(cell)
	var refunded := int(floor(float(CityData.cost(id)) * clampf(refund_ratio, 0.0, 1.0)))
	cells.erase(cell)
	rotations.erase(cell)
	cash += float(refunded)
	recompute()
	removed.emit(cell, id, refunded)
	cash_changed.emit(cash)
	return {"id": id, "refund": refunded, "rotation": rotation}


func add_cash(amount: float) -> void:
	if amount == 0.0:
		return
	cash += amount
	cash_changed.emit(cash)


func set_cell(id: String, cell: Vector2i, rotation: int = 0) -> void:
	cells[cell] = id
	rotations[cell] = posmod(rotation, 4)


# --- Simulation ------------------------------------------------------------

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed += delta

	var growth := -0.25 if happiness < 45.0 else 0.9 * (happiness / 100.0)
	if population < capacity:
		population = minf(capacity, population + growth * delta)
	elif population > capacity:
		population = maxf(capacity, population - 0.6 * delta)

	cash += income_per_second() * delta
	_check_milestones()


func recompute() -> void:
	var network := _connected_roads()
	capacity = 0.0
	income = 0.0
	green_bonus = 0.0
	pollution = 0.0
	connected_buildings = 0
	unconnected_buildings = 0
	road_cells = 0

	for cell in cells:
		var id := str(cells[cell])
		var data := CityData.structure(id)
		if data.is_empty():
			continue
		if CityData.category_of(id) == "road":
			road_cells += 1
			continue
		green_bonus += float(data.get("happiness", 0.0))
		pollution += float(data.get("pollution", 0.0))
		if not CityData.needs_road(id):
			continue
		if _has_connected_road(cell, network):
			connected_buildings += 1
			capacity += float(data.get("population", 0.0))
			income += float(data.get("income", 0.0))
		else:
			unconnected_buildings += 1

	happiness = clampf(45.0 + green_bonus - 4.0 * unconnected_buildings - pollution, 0.0, 100.0)
	changed.emit()


func _connected_roads() -> Dictionary:
	var network := {}
	if not has_hall():
		return network
	var queue: Array[Vector2i] = []
	for cell in CityData.neighbors(HALL_CELL):
		if is_road(cell):
			network[cell] = true
			queue.append(cell)
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for neighbor in CityData.neighbors(current):
			if is_road(neighbor) and not network.has(neighbor):
				network[neighbor] = true
				queue.append(neighbor)
	return network


func _has_connected_road(cell: Vector2i, network: Dictionary) -> bool:
	for neighbor in CityData.neighbors(cell):
		if network.has(neighbor):
			return true
	return false


func _check_milestones() -> void:
	while (
		reached_milestones < MILESTONES.size()
		and population >= float(MILESTONES[reached_milestones])
	):
		var bonus := MILESTONE_BONUS[reached_milestones]
		cash += float(bonus)
		reached_milestones += 1
		milestone_reached.emit(reached_milestones - 1, bonus)


# --- Saving ----------------------------------------------------------------

func serialize() -> Dictionary:
	var entries: Array = []
	var sorted: Array[Vector2i] = occupied_cells()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	for cell in sorted:
		entries.append({
			"x": cell.x,
			"z": cell.y,
			"id": str(cells[cell]),
			"rot": rotation_at(cell),
		})
	return {
		"version": SAVE_VERSION,
		"cash": cash,
		"population": population,
		"elapsed": elapsed,
		"reached_milestones": reached_milestones,
		"cells": entries,
	}


func apply_save(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false
	var raw: Variant = data.get("cells", [])
	if typeof(raw) != TYPE_ARRAY:
		return false

	var loaded: Dictionary = {}
	var loaded_rotations: Dictionary = {}
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str(entry.get("id", ""))
		if not CityData.has_structure(id):
			continue
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("z", 0)))
		if not cell_in_bounds(cell):
			continue
		loaded[cell] = id
		loaded_rotations[cell] = posmod(int(entry.get("rot", 0)), 4)
	if not loaded.has(HALL_CELL):
		loaded[HALL_CELL] = CityData.HALL_ID
		loaded_rotations[HALL_CELL] = 0

	cells = loaded
	rotations = loaded_rotations
	cash = float(data.get("cash", STARTING_CASH))
	population = maxf(0.0, float(data.get("population", 0.0)))
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	reached_milestones = clampi(int(data.get("reached_milestones", 0)), 0, MILESTONES.size())
	recompute()
	population = minf(population, capacity)
	return true


func save_to_disk() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(serialize()))
	file.close()
	return true


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func load_from_disk() -> CityState:
	if not save_exists():
		return null
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var state := CityState.new()
	if not state.apply_save(parsed):
		return null
	return state


static func delete_save() -> void:
	if save_exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
