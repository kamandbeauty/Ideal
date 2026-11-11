class_name Horde
extends Node3D
## Owns every zombie: pooling, the single per-tick update loop, routes and the
## places at the wall. Nothing else creates or frees zombie nodes.

var layout: LevelLayout
var defense: Defense
var effects: EffectPool
## Where the blood of the fallen is laid down; the level hands it over.
var marks: MarkPool
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
## The boss on the field, if one is alive.
var boss: Zombie = null
var kills_by_type: Dictionary = {}
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


## Builds zombies ahead of time so the first wave does not hitch. A negative
## count builds as many as the type asks for.
func prewarm(type_id: StringName, count: int = -1) -> void:
	if not types.has(type_id):
		return
	var data: ZombieData = types[type_id]
	for index: int in (data.prewarm if count < 0 else count):
		pooled[type_id].append(_create(data))


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
	if not gone and data.footprint <= 1:
		slot = lines.claim(zombie, target, hint if target == "any" else "", rng.randf_range(-0.6, 0.6))
		if slot != null:
			side = slot.side
		else:
			side = _side_of(target, side)
	else:
		# The big ones pick their place when they get there, and take it.
		side = _side_of(target, side)
	var path: PackedVector3Array = layout.path_for(route, lane, side)
	zombie.activate(path, slot, target, side, lane, health_scale, speed_scale, rng)
	if gone:
		# Walk the route first, then pour through the gap.
		zombie.path.append_array(layout.breach_path(target, lane * 0.7))
		zombie.state = Zombie.State.BREACH
	else:
		var destination: Vector3 = slot.position if slot != null else _waiting_point(target, side)
		if path.size() > 0:
			zombie.path.append(_court_point(path[path.size() - 1], destination))
		zombie.path.append(destination)
	active.append(zombie)
	living += 1
	spawned_total += 1
	if data.spawn_sound != "":
		Sound.play(data.spawn_sound, data.voice_volume_db)
	if data.is_boss:
		boss = zombie
		Events.boss_appeared.emit(zombie)
	Events.zombie_spawned.emit(zombie)
	return zombie


## A loose waypoint between the court mouth and the standing place, so a wave
## crosses the court as a ragged crowd instead of a single file.
func _court_point(from: Vector3, to: Vector3) -> Vector3:
	var along: Vector3 = to - from
	var across := Vector3(along.z, 0.0, -along.x).normalized()
	var point: Vector3 = from.lerp(to, rng.randf_range(0.35, 0.65)) + across * rng.randf_range(-2.4, 2.4)
	# Keep to the zombie's own half: clear of the wrecks down the middle and of the wall itself.
	var half: float = signf(to.x) if absf(to.x) > 0.1 else signf(from.x)
	point.x = half * clampf(absf(point.x), 3.6, 14.2)
	point.y = 0.0
	return point


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
		Sound.play_variant_at(clip, 2 if clip == "zombie_attack" else 3, zombie.position + Vector3(0.0, zombie.data.height() * 0.85, 0.0),
			-5.0 + zombie.data.voice_volume_db, rng.randf_range(0.85, 1.12) * zombie.data.voice_pitch)


## A waiting zombie asks again for a place at the wall.
func find_place(zombie: Zombie) -> void:
	if fallen.has(zombie.target):
		zombie.enter_breach(layout.breach_path(zombie.target, zombie.lateral * 0.7))
		return
	_settle(zombie, null)


## Claims a place for `zombie`; whoever that pushes aside looks for another
## place in turn. The chain is short: each one only moves something narrower
## than itself (the boss moves brutes, brutes move the rest).
func _settle(zombie: Zombie, lost: AttackLines.Slot) -> void:
	var wide: bool = zombie.data.footprint > 1
	# The wider it is, the straighter it goes for the middle.
	var drift: float = rng.randf_range(-0.6, 0.6) / float(zombie.data.footprint)
	var slot: AttackLines.Slot = lines.claim(zombie, zombie.target, zombie.side, drift, zombie.data.footprint, wide)
	var pushed: Array = lines.displaced.duplicate()
	if slot != null:
		zombie.assign_slot(slot)
	elif lost != null:
		# Nowhere to stand: step back from the place it lost and ask again shortly.
		zombie.fall_back(lines.waiting_point(lost.line, rng))
	for other: Zombie in pushed:
		other.slot = null
		if other.alive:
			_settle(other, slot)


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
	var at: Vector3 = slot.position + slot.facing * 0.75 + Vector3(0.0, zombie.data.height() * 0.68, 0.0)
	defense.apply_damage(slot.target, zombie.data.attack_damage, at)


func died(zombie: Zombie, headshot: bool) -> void:
	living -= 1
	killed_total += 1
	kills_by_type[zombie.data.id] = int(kills_by_type.get(zombie.data.id, 0)) + 1
	corpses.append(zombie)
	if zombie.data.death_sound != "":
		Sound.play(zombie.data.death_sound, zombie.data.voice_volume_db)
	else:
		Sound.play_variant_at("zombie_death", 2, zombie.position + Vector3(0.0, zombie.data.height() * 0.7, 0.0),
			-4.0 + zombie.data.voice_volume_db, randf_range(0.88, 1.1) * zombie.data.voice_pitch)
	if zombie == boss:
		boss = null
		Events.boss_fell.emit(zombie)
	# Too many bodies: the oldest one starts sinking now.
	if corpses.size() > corpse_limit:
		var oldest: Zombie = corpses.pop_front()
		if oldest.state == Zombie.State.CORPSE or oldest.state == Zombie.State.DYING:
			oldest.state = Zombie.State.CORPSE
			oldest.timer = minf(oldest.timer, 1.5)
	Events.zombie_killed.emit(zombie, headshot)


## A body has come to rest: blood spreads under it, and a heavy one raises the dust.
func fell(zombie: Zombie) -> void:
	var rest: Vector3 = zombie.resting_point()
	var bulk: float = zombie.scale.x * (1.0 + 0.45 * float(zombie.data.footprint - 1))
	if marks:
		marks.mark("blood", rest, Vector3.UP, bulk)
	if effects and zombie.data.footprint > 1:
		effects.burst("dust", rest + Vector3(0.0, 0.2, 0.0), Vector3.UP, 1.1 * float(zombie.data.footprint))
		Sound.play_at("body_fall", rest, -4.0 + 2.0 * float(zombie.data.footprint), randf_range(0.8, 0.95) / sqrt(float(zombie.data.footprint)))


## A zombie ran through a fallen gate (or the breached wall) into the city.
func entered_city(zombie: Zombie) -> void:
	if not zombie.alive:
		return
	zombie.alive = false
	living -= 1
	entered_total += 1
	if zombie == boss:
		boss = null
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


## Shortens a blast's throw so a body is never pushed into the wall it stood
## against or over the kerb of the court.
func clamp_throw(from: Vector3, push: Vector3) -> Vector3:
	if layout == null:
		return push
	var reach: float = layout.court_half_width - 0.9
	var landing: Vector3 = from + push
	if from.z > layout.court_mouth_z and absf(from.x) <= reach and absf(landing.x) > reach:
		landing.x = signf(landing.x) * reach
	return landing - from


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
	boss = null
	fallen.clear()
	for line_name: String in lines.lines:
		lines.lines[line_name].open = true
