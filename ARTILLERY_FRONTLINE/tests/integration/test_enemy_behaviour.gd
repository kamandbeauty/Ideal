extends RefCounted
## Phase 3 enemy behaviour. Each check covers one gameplay rule, so a regression names the broken behaviour.
## Units are stepped by calling _physics_process directly with a fixed step; other wave units are frozen.

const STEP: float = 1.0 / 60.0

func run(t: TestContext) -> void:
	_check_role_rules(t)
	_check_wave_roles(t)
	_check_line_of_fire_rules(t)
	await _check_line_of_fire_physics(t)
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	# Freeze the scripted first wave so only the units spawned by each check act.
	scene.set_process(false)
	scene.disembark_all_now()
	for unit in scene.soldiers:
		unit.set_physics_process(false)
	for vehicle in scene.vehicles:
		vehicle.set_physics_process(false)
	for plane in scene.aircraft:
		plane.set_physics_process(false)
	await _check_rifle_advances_and_holds_fire(t, scene)
	await _check_heavy_holds_at_range(t, scene)
	await _check_heavy_fires_three_round_burst(t, scene)
	await _check_rpg_fires_once_then_falls_back(t, scene)
	await _check_firing_line_repositions(t, scene)
	scene.queue_free()
	await t.tree.process_frame

## Roles must differ in what they do, not only in health.
func _check_role_rules(t: TestContext) -> void:
	var rifle: int = InfantryRole.Kind.RIFLE
	var heavy: int = InfantryRole.Kind.HEAVY
	var rpg: int = InfantryRole.Kind.RPG
	t.equal(InfantryRole.from_name("heavy"), heavy, "Wave name heavy maps to the heavy infantry role")
	t.equal(InfantryRole.from_name("rpg"), rpg, "Wave name rpg maps to the RPG role")
	t.equal(InfantryRole.from_name("soldier"), rifle, "Unknown and rifle names map to riflemen")
	t.check(InfantryRole.max_health(heavy) > InfantryRole.max_health(rifle), "Heavy infantry carries more health")
	t.check(InfantryRole.armor(heavy) > 0.0 and InfantryRole.armor(rifle) == 0.0, "Only heavy infantry wear armour")
	t.check(InfantryRole.holds(heavy) and InfantryRole.holds(rpg) and not InfantryRole.holds(rifle), "Heavy and RPG hold a firing line; riflemen keep advancing")
	t.check(InfantryRole.hold_distance(rpg) > InfantryRole.hold_distance(heavy), "RPG keeps further back than heavy infantry")
	t.check(InfantryRole.burst_size(heavy) == 3 and InfantryRole.burst_size(rpg) == 1 and InfantryRole.burst_size(rifle) == 1, "Heavy fires three-round bursts; rifle and RPG fire single shots")
	t.check(InfantryRole.setup_time(heavy) > 0.0 and InfantryRole.setup_time(rpg) > 0.0 and InfantryRole.setup_time(rifle) == 0.0, "Heavy and RPG set up before they fire")
	t.check(InfantryRole.reload_time(rpg) > 0.0 and InfantryRole.reload_time(heavy) == 0.0, "Only the RPG reloads between shots")
	t.check(InfantryRole.blast_radius(rpg) > 0.0 and InfantryRole.blast_radius(heavy) == 0.0 and InfantryRole.blast_radius(rifle) == 0.0, "Only the rocket is an explosive round")
	t.check(InfantryRole.stagger_time(heavy) < InfantryRole.stagger_time(rifle), "Heavy infantry flinch less when hit")
	t.check(InfantryRole.spread(heavy) < InfantryRole.spread(rifle), "Bipod-fired heavy rounds group tighter than rifle fire")
	t.check(InfantryRole.fire_range(rpg) > InfantryRole.fire_range(heavy), "RPG reaches further than heavy infantry")
	t.near(InfantryRole.speed_factor(heavy), 0.7, 0.0001, "Heavy infantry walk slower")
	# Heavy armour resists small arms: a 15-point hit does less than 15 damage.
	t.check(DamageModel.taken(15.0, InfantryRole.armor(heavy)) < 15.0, "Heavy plate removes part of a rifle round")
	t.near(DamageModel.taken(15.0, InfantryRole.armor(rifle)), 15.0, 0.0001, "Riflemen take a rifle round in full")

## Wave cargo: heavy and RPG units replace riflemen, so each wave keeps its total.
func _check_wave_roles(t: TestContext) -> void:
	var first: Array[String] = CoastalController.infantry_kinds(WaveManager.ROUNDS[0])
	t.equal(first.size(), 8, "First landing keeps eight infantry")
	t.equal(first.count("rpg"), 1, "First landing carries one RPG soldier")
	t.equal(first.count("heavy"), 0, "First landing has no heavy infantry")
	var second: Array[String] = CoastalController.infantry_kinds(WaveManager.ROUNDS[1])
	t.equal(second.size(), 12, "Armored push keeps twelve infantry")
	t.equal(second.count("heavy"), 2, "Armored push brings two heavy infantry")
	t.equal(second.count("rpg"), 2, "Armored push brings two RPG soldiers")
	t.equal(second.count("soldier"), 8, "Remaining infantry are riflemen")
	var final: Array[String] = CoastalController.infantry_kinds(WaveManager.ROUNDS[2])
	t.equal(final.size(), 20, "Final assault keeps twenty infantry")
	t.equal(final.count("heavy"), 4, "Final assault brings four heavy infantry")
	t.equal(final.count("rpg"), 3, "Final assault brings three RPG soldiers")
	t.equal(WaveManager.target_count(WaveManager.ROUNDS[2]), 29, "Final assault still totals 29 targets")
	# The role split is ordered: heavy first, then RPG, then riflemen.
	t.equal(final[0], "heavy", "Heavy infantry land first in the cargo order")

func _check_line_of_fire_rules(t: TestContext) -> void:
	t.check(FireControl.line_clear(null, Vector3(0, 10, -50), Vector3(0, 6, 40)), "A line well above the ground is clear")
	t.check(not FireControl.line_clear(null, Vector3(0, -3, -50), Vector3(0, 6, 40)), "A line that starts below the ground is blocked")
	t.check(FireControl.line_clear(null, Vector3(0, 8, -40), Vector3(0, 8, 40)), "Without a physics space only the terrain decides, and an elevated line is clear")

## A real physics blocker on the cover layer must block the sight line; removing it clears the line.
func _check_line_of_fire_physics(t: TestContext) -> void:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 30.0, 2.0)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(0, 12, 0)
	t.tree.root.add_child(blocker)
	await t.tree.physics_frame
	await t.tree.physics_frame
	var space: PhysicsDirectSpaceState3D = t.tree.root.get_world_3d().direct_space_state
	var from := Vector3(0, 8, -40)
	var to := Vector3(0, 8, 40)
	t.check(not FireControl.line_clear(space, from, to), "Cover on layer 1 blocks the line of fire")
	t.tree.root.remove_child(blocker)
	blocker.free()
	await t.tree.physics_frame
	await t.tree.physics_frame
	t.check(FireControl.line_clear(space, from, to), "Removing the cover clears the line of fire")

## Spawns one infantry unit at a fixed point, frozen, aimed at the emplacement, with a counter for its shots.
func _spawn(scene: CoastalController, z: float, role: String, sight: int) -> EnemySoldier:
	scene._spawn_soldier(Vector3(0, 0, z), role)
	var unit: EnemySoldier = scene.soldiers[scene.soldiers.size() - 1]
	unit.set_physics_process(false)
	unit.global_position = Vector3(0.0, CoastalTerrain.height_at(0.0, z), z)
	unit.sight_override = sight
	unit.shoot_cooldown = 0.0
	return unit

func _step(unit: EnemySoldier, frames: int) -> void:
	for index in range(frames):
		unit._physics_process(STEP)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _check_rifle_advances_and_holds_fire(t: TestContext, scene: CoastalController) -> void:
	var rifle: EnemySoldier = _spawn(scene, 0.0, "soldier", 0)
	var shots: Array = [0]
	rifle.shoot_requested.connect(func(_unit, _target): shots[0] += 1)
	var start: float = _flat_distance(rifle.global_position, rifle.objective)
	_step(rifle, 300)
	t.check(not rifle.holding_position, "Riflemen keep advancing instead of holding a line")
	t.check(_flat_distance(rifle.global_position, rifle.objective) < start - 5.0, "Riflemen close on the objective")
	t.equal(shots[0], 0, "Riflemen hold fire while they have no clear line")
	rifle.sight_override = 1
	_step(rifle, 120)
	t.check(shots[0] >= 1, "Riflemen open fire once the line is clear")
	rifle.queue_free()
	scene.soldiers.erase(rifle)

func _check_heavy_holds_at_range(t: TestContext, scene: CoastalController) -> void:
	var heavy: EnemySoldier = _spawn(scene, 0.0, "heavy", 0)
	_step(heavy, 1800)
	var range_now: float = _flat_distance(heavy.global_position, heavy.objective)
	t.check(heavy.holding_position, "Heavy infantry stop and hold a firing line")
	t.near(range_now, InfantryRole.hold_distance(InfantryRole.Kind.HEAVY), 0.6, "Heavy infantry hold at their set-up distance, not at the emplacement")
	var held: Vector3 = heavy.global_position
	_step(heavy, 120)
	t.check(held.distance_to(heavy.global_position) < 0.01, "A holding heavy stays put while it covers")
	heavy.queue_free()
	scene.soldiers.erase(heavy)

func _check_heavy_fires_three_round_burst(t: TestContext, scene: CoastalController) -> void:
	# Spawned close enough to the emplacement that the unit is already on its hold line.
	var heavy: EnemySoldier = _spawn(scene, 42.0, "heavy", 1)
	_step(heavy, 60)
	var shots: Array = [0]
	heavy.shoot_requested.connect(func(_unit, _target): shots[0] += 1)
	_step(heavy, 180)
	t.equal(shots[0], 3, "Heavy infantry fire one three-round burst after setting up, then wait for the next cycle")
	heavy.queue_free()
	scene.soldiers.erase(heavy)

func _check_rpg_fires_once_then_falls_back(t: TestContext, scene: CoastalController) -> void:
	var rpg: EnemySoldier = _spawn(scene, 10.0, "rpg", 1)
	var shots: Array = [0]
	rpg.shoot_requested.connect(func(_unit, _target): shots[0] += 1)
	var frames: int = 0
	while shots[0] == 0 and frames < 1500:
		_step(rpg, 1)
		frames += 1
	t.equal(shots[0], 1, "RPG soldier fires one rocket once it is set up on a clear line")
	var fired_from: float = _flat_distance(rpg.global_position, scene.emplacement)
	t.check(rpg.state == EnemySoldier.State.COVER, "After firing, the RPG soldier falls back to cover")
	t.check(rpg.reload_timer > 0.0, "The RPG reloads after firing")
	_step(rpg, 240)
	t.equal(shots[0], 1, "The RPG does not fire again while it is reloading")
	t.check(_flat_distance(rpg.global_position, scene.emplacement) > fired_from - 0.5, "The RPG falls back from the emplacement after its shot")
	_step(rpg, 420)
	t.check(rpg.state != EnemySoldier.State.COVER, "The RPG returns to the firing line once reloaded")
	rpg.queue_free()
	scene.soldiers.erase(rpg)

## Blocked by cover, a heavy unit looks for a flank position with a clear line, moves there and fires.
func _check_firing_line_repositions(t: TestContext, scene: CoastalController) -> void:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.5)
	shape.shape = box
	blocker.add_child(shape)
	# The sight line from a heavy on the slope (eye about 4.8 m) to the emplacement passes z=45 near y=5.0.
	blocker.position = Vector3(0, 5.0, 45)
	scene.add_child(blocker)
	await scene.get_tree().physics_frame
	await scene.get_tree().physics_frame
	var heavy: EnemySoldier = _spawn(scene, 36.0, "heavy", -1)
	var shots: Array = [0]
	heavy.shoot_requested.connect(func(_unit, _target): shots[0] += 1)
	var seen_reposition: bool = false
	var shots_before_reposition: int = -1
	var reached_flank: bool = false
	for index in range(1200):
		_step(heavy, 1)
		if not seen_reposition and heavy.reposition_point != Vector3.INF:
			seen_reposition = true
			shots_before_reposition = shots[0]
		if seen_reposition and heavy.reposition_point == Vector3.INF:
			reached_flank = true
			break
	t.check(seen_reposition, "Blocked heavy infantry pick a flank firing position")
	t.equal(shots_before_reposition, 0, "Heavy infantry hold fire while cover blocks their line")
	t.check(reached_flank, "Heavy infantry reach the flank position")
	t.check(shots[0] >= 1, "Heavy infantry fire from the flank once the line is clear")
	heavy.queue_free()
	scene.soldiers.erase(heavy)
	blocker.queue_free()
	await scene.get_tree().process_frame
