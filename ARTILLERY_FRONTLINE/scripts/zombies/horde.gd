class_name Horde
extends Node3D
## Owns every zombie: pooling, the single per-tick update loop, routes and the
## places at the wall. Nothing else creates or frees zombie nodes.

var layout: LevelLayout
var defense: Defense
var effects: EffectPool
var lines := AttackLines.new()
var types: Dictionary = {}
var pooled: Dictionary = {}
var active: Array[Zombie] = []
var retired: Array[Zombie] = []
var corpses: Array[Zombie] = []
var rng := RandomNumberGenerator.new()
var living: int = 0
var spawned_total: int = 0
var killed_total: int = 0
var entered_total: int = 0
var created: int = 0
var reused: int = 0
var health_scale: float = 1.0
var speed_scale: float = 1.0
var corpse_limit: int = 18
var groan_left: float = 2.0
## Targets that have fallen; zombies heading for them run through instead.
var fallen: Dictionary = {}


func _ready() -> void:
	add_to_group("quality_listener")
	rng.randomize()
	corpse_limit = Graphics.profile().corpses


func apply_quality(_tier: String, settings: Dictionary) -> void:
	corpse_limit = settings.corpses


func setup(level_layout: LevelLayout, wall: Defense, effect_pool: EffectPool, zombie_types: Array) -> void:
	layout = level_layout
	defense = wall
	effects = effect_pool
	lines.setup(layout)
	for data: ZombieData in zombie_types:
		if data != null:
			types[data.id] = data
			if not pooled.has(data.id):
				pooled[data.id] = []


## Builds zombies ahead of time so the first wave does not hitch.
func prewarm(type_id: StringName, count: int) -> void:
	if not types.has(type_id):
		return
	for index: int in count:
		pooled[type_id].append(_create(types[type_id]))


func _create(data: ZombieData) -> Zombie:
	var zombie: Zombie = data.scene.instantiate()
	zombie.data = data
	zombie.horde = self
	zombie.name = "%s%03d" % [String(data.id).capitalize(), created]
	created += 1
	add_child(zombie)
	return zombie


func has_type(type_id: StringName) -> bool:
	return types.has(type_id)


## Spawns one zombie at the start of `route`, wanting to attack `target`
## ("gate", "wall" or "any"). Returns null for an unknown type or route.
func spawn(type_id: StringName, route: String, target: String = "gate") -> Zombie:
	if not types.has(type_id) or layout == null or not layout.has_route(route):
		return null
	var data: ZombieData = types[type_id]
	var zombie: Zombie
	var stock: Array = pooled[type_id]
	if stock.is_empty():
		zombie = _create(data)
	else:
		zombie = stock.pop_back()
		reused += 1
	var hint: String = "left" if route.ends_with("left") else ("right" if route.ends_with("right") else "")
	var lane: float = rng.randf_range(-1.0, 1.0)
	var gone: bool = target != "any" and fallen.has(target)
	var slot: AttackLines.Slot = null
	var side: String = hint if hint != "" else ("left" if rng.randf() < 0.5 else "right")
	if not gone:
		slot = lines.claim(zombie, target, hint if target == "any" else "", rng.randf_range(-0.6, 0.6))
		if slot != null:
			side = slot.side
		else:
			side = _side_of(target, side)
	else:
		side = _side_of(target, side)
	var path: PackedVector3Array = layout.path_for(route, lane, side)
	zombie.activate(path, slot, target, side, lane, health_scale, speed_scale, rng)
	if gone:
		# Walk the route first, then pour through the gap.
		zombie.path.append_array(layout.breach_path(target, lane * 0.7))
		zombie.state = Zombie.State.BREACH
	elif slot != null:
		zombie.path.append(slot.position)
	else:
		zombie.path.append(_waiting_point(target, side))
	active.append(zombie)
	living += 1
	spawned_total += 1
	Events.zombie_spawned.emit(zombie)
	return zombie


func _side_of(target: String, fallback: String) -> String:
	for line_name: String in lines.lines_for_target(target):
		return lines.lines[line_name].side
	return fallback


func _waiting_point(target: String, side: String) -> Vector3:
	var order: Array[String] = lines.preference(target, side)
	if order.is_empty():
		return layout.mouths[side].position if layout.mouths.has(side) else Vector3.ZERO
	return lines.waiting_point(order[0], rng)


func _physics_process(delta: float) -> void:
	var index: int = active.size() - 1
	while index >= 0:
		active[index].tick(delta)
		index -= 1
	if not retired.is_empty():
		for zombie: Zombie in retired:
			active.erase(zombie)
			corpses.erase(zombie)
			zombie.recycle()
			pooled[zombie.data.id].append(zombie)
		retired.clear()
	groan_left -= delta
	if groan_left <= 0.0:
		groan_left = rng.randf_range(1.2, 3.6)
		_groan()


func _groan() -> void:
	if living <= 0 or active.is_empty():
		return
	var zombie: Zombie = active[rng.randi() % active.size()]
	if zombie.alive:
		var clip: String = "zombie_attack" if zombie.state == Zombie.State.ATTACK else "zombie_groan"
		Sound.play_variant_at(clip, 2 if clip == "zombie_attack" else 3, zombie.position + Vector3(0.0, 1.4, 0.0), -5.0, rng.randf_range(0.85, 1.12))


## A waiting zombie asks again for a place at the wall.
func find_place(zombie: Zombie) -> void:
	if fallen.has(zombie.target):
		zombie.enter_breach(layout.breach_path(zombie.target, zombie.lateral * 0.7))
		return
	var slot: AttackLines.Slot = lines.claim(zombie, zombie.target, zombie.side, rng.randf_range(-0.6, 0.6))
	if slot != null:
		zombie.assign_slot(slot)


func release_place(zombie: Zombie) -> void:
	var slot: AttackLines.Slot = zombie.slot
	if slot == null:
		return
	zombie.slot = null
	lines.release(slot)
	for move: Array in lines.advance_rows(slot.line):
		(move[0] as Zombie).assign_slot(move[1])


## A blow lands on the wall or gate.
func strike(zombie: Zombie, slot: AttackLines.Slot) -> void:
	if defense == null:
		return
	var at: Vector3 = slot.position + slot.facing * 0.75 + Vector3(0.0, 1.25, 0.0)
	defense.apply_damage(slot.target, zombie.data.attack_damage, at)


func died(zombie: Zombie, headshot: bool) -> void:
	living -= 1
	killed_total += 1
	corpses.append(zombie)
	Sound.play_variant_at("zombie_death", 2, zombie.position + Vector3(0.0, 1.2, 0.0), -4.0, randf_range(0.88, 1.1))
	# Too many bodies: the oldest one starts sinking now.
	if corpses.size() > corpse_limit:
		var oldest: Zombie = corpses.pop_front()
		if oldest.state == Zombie.State.CORPSE or oldest.state == Zombie.State.DYING:
			oldest.state = Zombie.State.CORPSE
			oldest.timer = minf(oldest.timer, 1.5)
	Events.zombie_killed.emit(zombie, headshot)


## A zombie ran through a fallen gate (or the breached wall) into the city.
func entered_city(zombie: Zombie) -> void:
	if not zombie.alive:
		return
	zombie.alive = false
	living -= 1
	entered_total += 1
	if defense:
		defense.apply_breach(zombie.data.breach_damage)
	recycle(zombie)


func recycle(zombie: Zombie) -> void:
	if not retired.has(zombie):
		retired.append(zombie)


## The gate (or the wall patch) has fallen: everyone attacking or heading for
## it runs through the gap from now on.
func open_breach(target: String) -> void:
	if fallen.has(target):
		return
	fallen[target] = true
	for line_name: String in lines.lines_for_target(target):
		if target == "wall" and line_name != "patch":
			continue
		lines.close(line_name)
	for zombie: Zombie in active:
		if zombie.alive and zombie.target == target and zombie.state != Zombie.State.BREACH:
			if zombie.slot != null and zombie.slot.line != "" and lines.lines[zombie.slot.line].open:
				continue
			zombie.enter_breach(layout.breach_path(target, zombie.lateral * 0.7))


func alive_count() -> int:
	return living


func attackers(target: String = "") -> int:
	var total: int = 0
	for zombie: Zombie in active:
		if zombie.state == Zombie.State.ATTACK and (target == "" or (zombie.slot != null and zombie.slot.target == target)):
			total += 1
	return total


func clear() -> void:
	for zombie: Zombie in active:
		if zombie.slot != null:
			lines.release(zombie.slot)
		zombie.recycle()
		pooled[zombie.data.id].append(zombie)
	active.clear()
	retired.clear()
	corpses.clear()
	living = 0
	fallen.clear()
	for line_name: String in lines.lines:
		lines.lines[line_name].open = true
