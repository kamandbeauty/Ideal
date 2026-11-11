class_name AttackLines
extends RefCounted
## Standing places along the gate and the wall. Zombies claim a slot before
## they enter the court, so they spread along the target instead of stacking,
## and the rows behind step forward when someone in front drops.

const ROW_GAP: float = 1.05


class Slot:
	extends RefCounted
	var line: String = ""
	var column: int = 0
	var row: int = 0
	var position: Vector3 = Vector3.ZERO
	## Unit vector from the slot toward the thing being attacked.
	var facing: Vector3 = Vector3.FORWARD
	var target: String = "wall"
	var side: String = ""
	var occupant: Object = null


var lines: Dictionary = {}


func setup(layout: LevelLayout) -> void:
	lines.clear()
	for line_name: String in layout.attack_lines:
		var spec: Dictionary = layout.attack_lines[line_name]
		var a: Vector3 = spec.a
		var b: Vector3 = spec.b
		var normal: Vector3 = (spec.normal as Vector3).normalized()
		var spacing: float = spec.spacing
		var length: float = a.distance_to(b)
		var columns: int = int(floor(length / spacing)) + 1
		var along: Vector3 = (b - a).normalized()
		var lead: float = (length - float(columns - 1) * spacing) * 0.5
		var slots: Array[Slot] = []
		for row: int in int(spec.rows):
			for column: int in columns:
				var slot := Slot.new()
				slot.line = line_name
				slot.column = column
				slot.row = row
				slot.position = a + along * (lead + float(column) * spacing) + normal * (float(row) * ROW_GAP)
				slot.facing = -normal
				slot.target = spec.target
				slot.side = spec.side
				slots.append(slot)
		lines[line_name] = {
			"slots": slots, "columns": columns, "rows": int(spec.rows), "target": String(spec.target), "side": String(spec.side),
			"priority": int(spec.priority), "open": true, "center": (a + b) * 0.5, "normal": normal, "along": along, "length": length,
		}


func capacity() -> int:
	var total: int = 0
	for line_name: String in lines:
		if lines[line_name].open:
			total += lines[line_name].slots.size()
	return total


func occupied(line_name: String = "") -> int:
	var total: int = 0
	for key: String in lines:
		if line_name != "" and key != line_name:
			continue
		for slot: Slot in lines[key].slots:
			if slot.occupant != null:
				total += 1
	return total


## Lines in the order a zombie wanting `target` should try them.
func preference(target: String, side: String = "") -> Array[String]:
	var wanted: Array[String] = []
	var same_side: Array[String] = []
	var rest: Array[String] = []
	var first_side: String = side
	var names: Array = lines.keys()
	names.sort_custom(func(left: String, right: String) -> bool: return lines[left].priority < lines[right].priority)
	for line_name: String in names:
		var line: Dictionary = lines[line_name]
		if not line.open:
			continue
		if target == "any" or line.target == target:
			wanted.append(line_name)
			if first_side == "":
				first_side = line.side
	for line_name: String in names:
		var line: Dictionary = lines[line_name]
		if not line.open or wanted.has(line_name):
			continue
		if line.side == first_side:
			same_side.append(line_name)
		else:
			rest.append(line_name)
	return wanted + same_side + rest


## Reserves a place for `who`. Front row of the preferred line first, then the
## rows behind it, then the next line. Null when every place is taken.
func claim(who: Object, target: String, side: String = "", jitter: float = 0.0) -> Slot:
	for line_name: String in preference(target, side):
		var line: Dictionary = lines[line_name]
		for row: int in line.rows:
			var best: Slot = null
			var best_score: float = INF
			var middle: float = float(line.columns - 1) * 0.5
			for slot: Slot in line.slots:
				if slot.row != row or slot.occupant != null:
					continue
				# Fill from the middle outward so the attack bunches on the weak point.
				var score: float = absf(float(slot.column) - middle - jitter)
				if score < best_score:
					best_score = score
					best = slot
			if best != null:
				best.occupant = who
				return best
	return null


func release(slot: Slot) -> void:
	if slot != null:
		slot.occupant = null


## After a front place opens, returns [occupant, new_slot] pairs that step forward.
func advance_rows(line_name: String) -> Array:
	var moves: Array = []
	if not lines.has(line_name):
		return moves
	var line: Dictionary = lines[line_name]
	if not line.open or line.rows < 2:
		return moves
	for row: int in range(0, line.rows - 1):
		for slot: Slot in line.slots:
			if slot.row != row or slot.occupant != null:
				continue
			var donor: Slot = null
			var best: int = 99
			for candidate: Slot in line.slots:
				if candidate.row != row + 1 or candidate.occupant == null:
					continue
				var distance: int = absi(candidate.column - slot.column)
				if distance < best and distance <= 2:
					best = distance
					donor = candidate
			if donor != null:
				slot.occupant = donor.occupant
				donor.occupant = null
				moves.append([slot.occupant, slot])
	return moves


## Closes a line (its target has fallen) and returns everyone who stood there.
func close(line_name: String) -> Array:
	var displaced: Array = []
	if not lines.has(line_name):
		return displaced
	var line: Dictionary = lines[line_name]
	line.open = false
	for slot: Slot in line.slots:
		if slot.occupant != null:
			displaced.append(slot.occupant)
			slot.occupant = null
	return displaced


func lines_for_target(target: String) -> Array[String]:
	var found: Array[String] = []
	for line_name: String in lines:
		if lines[line_name].target == target:
			found.append(line_name)
	return found


## A loose spot behind a line for those who found every place taken.
func waiting_point(line_name: String, rng: RandomNumberGenerator) -> Vector3:
	var line: Dictionary = lines[line_name]
	var back: float = float(line.rows) * ROW_GAP + rng.randf_range(0.6, 3.0)
	return line.center + line.along * rng.randf_range(-0.5, 0.5) * line.length + line.normal * back
