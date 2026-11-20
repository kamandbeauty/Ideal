extends RefCounted
## Zombie movement, attacking, the places at the wall, pooling and the breach.


func _until(t: TestContext, level: CityLevel, limit: float, done: Callable) -> float:
	var elapsed: float = 0.0
	while elapsed < limit and not done.call():
		t.simulate(level, 0.25)
		elapsed += 0.25
	return elapsed


func run(t: TestContext) -> void:
	await _corpse_clearance(t)
	var level: CityLevel = t.make_level()
	await t.frames(2)
	var horde: Horde = level.horde
	var layout: LevelLayout = level.layout
	var walker: ZombieData = level.zombie_types[0]
	horde.rng.seed = 42

	t.check(horde.spawn(&"no_such_type", "ring_right", "gate") == null, "an unknown zombie type spawns nothing")
	t.check(horde.spawn(&"walker", "no_such_route", "gate") == null, "an unknown route spawns nothing")
	t.equal(horde.alive_count(), 0, "failed spawns leave the field empty")

	# One walker: route, slot, arrival, attack.
	var zombie: Zombie = horde.spawn(&"walker", "ring_right", "gate")
	t.check(zombie != null and is_instance_of(zombie, Zombie), "Horde instantiates a Zombie node, not a bare Node3D")
	t.check(zombie != null and zombie.alive and zombie.visible and zombie.state == Zombie.State.ADVANCE, "a spawned zombie is alive and advancing")
	var spawn: Vector3 = (layout.routes.ring_right.points as PackedVector3Array)[0]
	t.check(zombie.position.distance_to(spawn) <= float(layout.routes.ring_right.widths[0]) + 0.01, "it starts at the route's spawn, inside its lane")
	t.check(zombie.slot != null and zombie.slot.line == "gate" and zombie.slot.row == 0, "it has claimed a front place at the gate")
	t.equal(zombie.body_area.collision_layer, Layers.ZOMBIE_BODY, "its body can be hit")
	t.equal(zombie.head_area.collision_layer, Layers.ZOMBIE_HEAD, "its head can be hit")
	var pace_factor: float = 1.35 if zombie.running else 1.0
	t.check(zombie.speed > walker.speed * pace_factor * 0.85 and zombie.speed < walker.speed * pace_factor * 1.15, "its speed matches its selected walk or run")
	var distance: float = layout.route_length("ring_right", "right") + (layout.mouths.right.position as Vector3).distance_to(zombie.slot.position)
	var took: float = _until(t, level, 150.0, func() -> bool: return zombie.state == Zombie.State.ATTACK)
	t.equal(zombie.state, Zombie.State.ATTACK, "it reaches the gate and attacks")
	t.check(zombie.position.distance_to(zombie.slot.position) < 0.05, "it stands exactly on its place")
	var expected: float = distance / zombie.speed
	t.check(took > expected * 0.8 and took < expected * 1.3, "the walk takes about distance / speed (%.0f s, expected %.0f s)" % [took, expected])
	t.simulate(level, 1.0)
	var forward := Vector3(sin(zombie.rotation.y), 0.0, cos(zombie.rotation.y))
	t.check(forward.dot(zombie.slot.facing) > 0.95, "it faces the gate")
	t.equal(zombie.current_clip, "attack", "it plays the attack clip")
	var gate_before: float = level.defense.gate_health
	var blows_before: int = zombie.blows
	t.simulate(level, walker.attack_interval * 5.0)
	t.equal(zombie.blows - blows_before, 5, "it lands one blow per attack interval")
	t.near(gate_before - level.defense.gate_health, walker.attack_damage * 5.0, 0.001, "each blow takes attack_damage from the gate")
	t.near(level.defense.wall_health, level.defense.data.wall_max_health, 0.001, "blows on the gate leave the wall alone")

	# Death releases the place; the body lingers, sinks and returns to the pool.
	var slot: AttackLines.Slot = zombie.slot
	var pooled_before: int = horde.pooled[&"walker"].size()
	t.check(not zombie.take_hit(10.0, false, zombie.position, Vector3.RIGHT), "a light hit does not kill")
	t.check(zombie.take_hit(1000.0, false, zombie.position, Vector3.RIGHT), "a heavy hit kills")
	t.check(slot.occupant == null and zombie.slot == null, "its place is free again")
	t.equal(horde.alive_count(), 0, "it no longer counts as alive")
	t.equal(horde.killed_total, 1, "the kill is counted")
	t.check(zombie.current_clip.begins_with("death"), "it plays a death clip")
	t.check(horde.active.has(zombie), "the body stays on the ground for a while")
	t.simulate(level, walker.corpse_time + 3.0)
	t.check(not horde.active.has(zombie) and not zombie.visible, "the body is cleared away")
	t.equal(horde.pooled[&"walker"].size(), pooled_before + 1, "and the node returns to the pool")

	# A full gate: front row attacks, second row waits, the rest overflow; rows step forward.
	var columns: int = horde.lines.lines.gate.columns
	var squad: Array[Zombie] = []
	for index: int in columns * 2 + 2:
		squad.append(horde.spawn(&"walker", "ring_right", "gate"))
	var at_gate: int = 0
	var overflow: int = 0
	for member: Zombie in squad:
		if member.slot != null and member.slot.line == "gate":
			at_gate += 1
		elif member.slot != null:
			overflow += 1
	t.equal(at_gate, columns * 2, "the gate takes two full rows")
	t.equal(overflow, 2, "the rest take places on the wall beside it")
	var gaits: Dictionary = {}
	var leans: Dictionary = {}
	for member: Zombie in squad:
		gaits[member.walk_clip] = true
		leans["%.2f" % member.gait_lean.x] = true
	t.check(gaits.size() >= 2, "walkers in a crowd choose both walking and running (%s)" % str(gaits.keys()))
	t.check(leans.size() >= 2, "and they do not all lean the same")
	_until(t, level, 200.0, func() -> bool:
		for member: Zombie in squad:
			if member.state == Zombie.State.ADVANCE:
				return false
		return true)
	t.equal(horde.attackers("gate"), columns, "the whole front row attacks the gate")
	var waiting: Array[Zombie] = []
	var victim: Zombie = null
	for member: Zombie in squad:
		if member.slot != null and member.slot.line == "gate":
			if member.slot.row == 1:
				waiting.append(member)
			elif victim == null:
				victim = member
	t.equal(waiting.size(), columns, "the second row waits behind")
	t.check(waiting[0].state == Zombie.State.WAIT and waiting[0].current_clip == "idle", "waiting zombies idle")
	var freed: AttackLines.Slot = victim.slot
	victim.kill()
	t.check(freed.occupant != null and freed.occupant != victim, "someone from the second row takes the freed place at once")
	var promoted: Zombie = freed.occupant
	_until(t, level, 20.0, func() -> bool: return promoted.state == Zombie.State.ATTACK)
	t.equal(promoted.state, Zombie.State.ATTACK, "the one who stepped forward now attacks")
	t.equal(horde.attackers("gate"), columns, "the front row is full again")

	# Pool reuse.
	var created: int = horde.created
	for member: Zombie in squad:
		member.kill()
	t.simulate(level, walker.corpse_time + 4.0)
	t.equal(horde.active.size(), 0, "the field is empty after the bodies are cleared")
	for index: int in 20:
		horde.spawn(&"walker", "alley_left", "wall")
	t.equal(horde.created, created, "respawning reuses pooled zombies instead of creating nodes")
	t.equal(horde.alive_count(), 20, "twenty are alive again")
	var patch_first: Zombie = horde.active[0]
	t.equal(patch_first.slot.line, "patch", "wall attackers head for the patched breach")
	t.equal(patch_first.side, "left", "and use the left side of the court")

	# The gate falls: its attackers pour through and every one of them hurts the wall.
	for index: int in 6:
		horde.spawn(&"walker", "ring_right", "gate")
	_until(t, level, 200.0, func() -> bool: return horde.attackers("gate") >= 6)
	t.check(horde.attackers("gate") >= 6, "six attack the gate")
	var gate_events: Array = []
	var on_gate := func() -> void: gate_events.append(1)
	Events.gate_destroyed.connect(on_gate)
	level.defense.apply_damage("gate", 100000.0)
	t.equal(gate_events.size(), 1, "gate_destroyed is emitted")
	var breaching: int = 0
	for member: Zombie in horde.active:
		if member.state == Zombie.State.BREACH:
			breaching += 1
	t.check(breaching >= 6, "the gate's attackers turn to run through it")
	t.check(not horde.lines.lines.gate.open, "the gate's places are closed")
	var wall_before: float = level.defense.wall_health
	var entered_before: int = horde.entered_total
	_until(t, level, 30.0, func() -> bool: return horde.entered_total - entered_before >= 6)
	t.check(horde.entered_total - entered_before >= 6, "they get inside the city")
	t.check(wall_before - level.defense.wall_health >= walker.breach_damage * 6.0 - 0.01, "each one through the gate costs the wall breach_damage")
	var late: Zombie = horde.spawn(&"walker", "ring_right", "gate")
	t.check(late.state == Zombie.State.BREACH and late.slot == null, "later gate attackers go straight for the gap")
	var last: Vector3 = late.path[late.path.size() - 1]
	t.check(last.x > layout.gate_center.x + 2.0, "their path ends inside the city")
	Events.gate_destroyed.disconnect(on_gate)

	horde.clear()
	t.equal(horde.active.size(), 0, "clear removes every zombie")
	t.equal(horde.alive_count(), 0, "clear resets the count")
	t.check(horde.lines.lines.gate.open and horde.lines.occupied() == 0, "clear reopens and empties the places")

	# Every type uses two even-legged gaits with independent stride phases.
	for kind: Array in [[&"walker", 24], [&"runner", 24], [&"brute", 24], [&"boss", 24]]:
		var taken: Dictionary = {}
		var phases: Dictionary = {}
		var wrong: int = 0
		for index: int in int(kind[1]):
			var member: Zombie = horde.spawn(kind[0], "avenue_left" if index % 2 == 0 else "ring_right", "any")
			var wanted: String = "run_clean" if member.running else "walk_clean"
			if member.walk_clip != wanted or member.current_clip != wanted or member.anim.current_animation != wanted:
				wrong += 1
			if index == 0:
				t.equal(member.walk_clips.size(), 2, "a %s has an even walk and run" % kind[0])
				t.check(member.anim.get_animation(wanted).loop_mode == Animation.LOOP_LINEAR, "the chosen gait loops")
			taken[member.walk_clip] = true
			phases[snappedf(member.anim.current_animation_position, 0.01)] = true
		t.equal(wrong, 0, "every %s uses the selected clean gait" % kind[0])
		t.equal(taken.size(), 2, "%s randomly walk or run" % kind[0])
		t.check(phases.size() >= int(kind[1]) / 2, "the crowd starts out of step (%d phases)" % phases.size())
		horde.clear()

	# A real camera and a wall high above the level isolate sight and occlusion.
	t.check(horde.camera == level.defender.camera, "the horde uses the player's camera")
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.position = Vector3(0.0, 200.0, 0.0)
	camera.make_current()
	horde.camera = camera
	horde.seen_voice_left = 100.0
	horde.groan_left = 100.0
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	level.add_child(wall)
	wall.position = Vector3(0.0, 200.0, -5.0)
	await t.physics_frames(2)
	var visible_zombie: Zombie = horde.spawn(&"walker", "ring_right", "gate")
	var eye: Vector3 = camera.global_position
	var forward_view: Vector3 = -camera.global_basis.z.normalized()
	var height: Vector3 = Vector3.UP * visible_zombie.data.height() * 0.7
	visible_zombie.global_position = eye - forward_view * 10.0 - height
	Sound.last_start.clear()
	var before: int = Sound.started
	t.check(not horde._announce_visible() and Sound.started == before, "a zombie behind the camera is not announced")
	visible_zombie.global_position = eye + forward_view * 10.0 - height
	t.check(not horde._announce_visible() and Sound.started == before, "a zombie hidden by a wall is not announced")
	wall.queue_free()
	await t.physics_frames(2)
	t.check(horde._announce_visible() and visible_zombie.seen_announced and Sound.started == before + 1, "first visible zombie requests a voice")
	t.check(not horde._announce_visible() and Sound.started == before + 1, "remaining in view does not repeat the announcement")
	horde.clear()
	var reused: Zombie = horde.spawn(&"walker", "ring_right", "gate")
	t.check(reused == visible_zombie and not reused.seen_announced, "pool reuse resets first-sighting state")
	horde.clear()
	await t.discard(level)


## Sample both impact types at the real gate and wall, at every type's scale.
func _corpse_clearance(t: TestContext) -> void:
	for stage: int in [0, 3, 6]:
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		var horde: Horde = level.horde
		for extra: bool in [false, true]:
			Zombie.mix_extras = extra
			for kind: StringName in [&"walker", &"runner", &"brute", &"boss"]:
				for side: String in ["gate", "wall"]:
					var zombie: Zombie = horde.spawn(kind, "ring_right" if side == "gate" else "alley_left", side)
					if zombie != null and zombie.slot == null:
						horde.find_place(zombie) # Wide zombies claim a place on arrival.
					t.check(zombie != null and zombie.slot != null, "corpse test has a wall slot")
					if zombie == null or zombie.slot == null:
						horde.clear()
						continue
					var facing: Vector3 = zombie.slot.facing
					zombie.position = zombie.slot.position
					zombie.rotation.y = atan2(facing.x, facing.z)
					zombie.state = Zombie.State.ATTACK
					if side == "gate":
						var blast: ExplosionData = load("res://resources/explosions/grenade_blast.tres")
						zombie.take_blast(100000.0, zombie.position - facing * 5.0, 1.0, blast)
					else:
						zombie.kill(false, facing)
					var margin: float = zombie.data.height() * maxf(zombie.scale.x, maxf(zombie.scale.y, zombie.scale.z)) + 0.35
					var limit: float = level.layout.court_half_width - margin
					t.check(absf(zombie.position.x) <= limit + 0.001, "%s %s corpse has room to fall" % [kind, side])
					t.check(absf(zombie.position.x + zombie.knock.x) <= limit + 0.001, "%s %s blast cannot throw corpse into wall" % [kind, side])
					if zombie.anim and zombie.skeleton:
						zombie.anim.seek(zombie.anim.current_animation_length * 0.9, true)
						await t.frames(2)
						var extreme: float = 0.0
						for bone: int in zombie.skeleton.get_bone_count():
							var world: Vector3 = zombie.skeleton.global_transform * zombie.skeleton.get_bone_global_pose(bone).origin
							extreme = maxf(extreme, absf(world.x))
						t.check(extreme < level.layout.court_half_width, "%s %s bones stay inside wall (%.2f)" % [kind, side, extreme])
					horde.clear()
		Zombie.mix_extras = false
		await t.discard(level)
