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
	scene.set_physics_process(false)
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
	await _check_vehicle_rules(t)
	await _check_tank_pivots_before_driving(t)
	await _check_turret_waits_for_alignment(t)
	await _check_jeep_strafes(t)
	await _check_vehicle_damage_states(t)
	await _check_cook_off(t)
	await _check_vehicle_line_of_fire(t)
	await _check_infantry_cover_and_death(t, scene)
	_check_infantry_hit_reactions(t, scene)
	await _check_destroyed_enemies_cannot_attack(t, scene)
	_check_destruction_profiles(t)
	await _check_vehicle_destruction(t)
	await _check_aircraft_damage_and_destruction(t)
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
	# Fixed aim point on the emplacement, so line-of-fire geometry is the same on every run.
	unit.objective = Vector3(0.0, 0.0, scene.emplacement.z)
	unit.player_position = unit.objective
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
	_step(heavy, 3600)
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
	t.check(rpg.state == EnemySoldier.State.COVER, "The RPG stays in cover while it reloads")
	t.check(_flat_distance(rpg.global_position, scene.emplacement) > fired_from - 0.5, "The RPG falls back from the emplacement after its shot")
	# The reload takes five seconds; the RPG goes back to the firing line the moment it is loaded.
	_step(rpg, 70)
	t.check(rpg.state == EnemySoldier.State.ADVANCE, "The RPG returns to the firing line once reloaded")
	t.equal(shots[0], 1, "Reloading does not itself fire the next rocket")
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
	# Setting up at the flank takes the heavy's set-up time, so give it time to fire before judging.
	_step(heavy, 300)
	t.check(shots[0] >= 1, "Heavy infantry fire from the flank once the line is clear")
	heavy.queue_free()
	scene.soldiers.erase(heavy)
	blocker.queue_free()
	await scene.get_tree().process_frame

## Vehicle handling rules: each role turns, traverses and aims differently, and only carriers cook off.
func _check_vehicle_rules(t: TestContext) -> void:
	t.check(EnemyVehicle.turn_rate("tank") < EnemyVehicle.turn_rate("jeep"), "Heavy hulls turn more slowly than a jeep")
	t.check(EnemyVehicle.traverse_rate("boss") < EnemyVehicle.traverse_rate("tank"), "The boss turret traverses more slowly than a tank turret")
	t.check(EnemyVehicle.aim_tolerance("tank") < EnemyVehicle.aim_tolerance("jeep"), "A tank gun needs a tighter aim than a jeep's machine gun")
	t.check(EnemyVehicle.cook_off_radius("tank") > 0.0 and EnemyVehicle.cook_off_radius("boss") > 0.0 and EnemyVehicle.cook_off_radius("apc") > 0.0, "Tanks, APCs and the boss carry ammunition that cooks off")
	t.check(EnemyVehicle.cook_off_radius("jeep") == 0.0 and EnemyVehicle.cook_off_radius("transport") == 0.0, "Jeeps and transports carry no cook-off")
	t.check(EnemyVehicle.strafes("jeep") and not EnemyVehicle.strafes("tank") and not EnemyVehicle.strafes("transport"), "Only the jeep strafes its target")

func _vehicle(t: TestContext, kind: String, spawn: Vector3, target: Vector3) -> EnemyVehicle:
	var unit := EnemyVehicle.new()
	t.tree.root.add_child(unit)
	unit.configure(spawn, target, kind)
	unit.set_physics_process(false)
	unit.shoot_cooldown = 10000.0
	return unit

## A tank that faces away pivots on the spot before it drives, then reaches its half-way hold line.
func _check_tank_pivots_before_driving(t: TestContext) -> void:
	var tank: EnemyVehicle = _vehicle(t, "tank", Vector3(0, 0, 0), Vector3(0, 0, 40))
	for index in range(60):
		tank._physics_process(STEP)
	var moved: float = Vector2(tank.global_position.x, tank.global_position.z).length()
	t.check(moved < 0.01, "A tank facing away does not drive while it swings round")
	t.near(absf(angle_difference(0.0, tank.rotation.y)), EnemyVehicle.turn_rate("tank"), 0.05, "The tank swings round at its turn rate")
	for index in range(1200):
		tank._physics_process(STEP)
	t.check(tank.holding, "After turning, the tank drives to its hold line")
	t.near(Vector2(tank.global_position.x, tank.global_position.z).distance_to(Vector2(0, 40)), tank.stop_distance, 0.02, "The tank parks at its half-way line")
	tank.queue_free()

## The gun only fires once the turret is on the bearing: a misaligned turret holds fire, then traverses and fires.
func _check_turret_waits_for_alignment(t: TestContext) -> void:
	var tank: EnemyVehicle = _vehicle(t, "tank", Vector3(0, 0, 0), Vector3(0, 0, -5))
	tank.turret.rotation.y = PI
	tank.shoot_cooldown = 0.0
	var shots: Array = [0]
	tank.shoot_requested.connect(func(_muzzle, _aim, _damage, _blast): shots[0] += 1)
	for index in range(30):
		tank._physics_process(STEP)
	t.check(tank.aim_error > 1.0, "A turret facing away from the target is not on the bearing")
	t.equal(shots[0], 0, "The gun holds fire while the turret is misaligned")
	var fired_misaligned: bool = false
	for index in range(600):
		var before: int = shots[0]
		tank._physics_process(STEP)
		if shots[0] > before and tank.aim_error > EnemyVehicle.aim_tolerance("tank") + 0.001:
			fired_misaligned = true
	t.check(shots[0] >= 1, "The gun fires once the turret has traversed onto the target")
	t.check(not fired_misaligned, "No shot leaves while the turret is outside the aim tolerance")
	tank.queue_free()

## A jeep does not park: it circles its target at its stand-off distance and keeps covering the ground.
func _check_jeep_strafes(t: TestContext) -> void:
	var jeep: EnemyVehicle = _vehicle(t, "jeep", Vector3(0, 0, 60), Vector3(0, 0, 0))
	for index in range(900):
		jeep._physics_process(STEP)
	t.check(not jeep.holding, "The jeep keeps moving instead of parking")
	var path: float = 0.0
	var low: float = INF
	var high: float = 0.0
	var previous: Vector3 = jeep.global_position
	for index in range(300):
		jeep._physics_process(STEP)
		path += Vector2(jeep.global_position.x - previous.x, jeep.global_position.z - previous.z).length()
		previous = jeep.global_position
		var radius: float = Vector2(jeep.global_position.x, jeep.global_position.z).length()
		low = minf(low, radius)
		high = maxf(high, radius)
	t.check(path > 15.0, "The jeep strafes across the target's front, covering over 15 m in five seconds")
	t.check(low > 36.0 and high < 44.0, "The jeep holds its stand-off distance while it circles")
	jeep.queue_free()

## Damage shows on the hull: a hit rocks it, and smoke then fire build on the wreck as health falls.
func _check_vehicle_damage_states(t: TestContext) -> void:
	var tank: EnemyVehicle = _vehicle(t, "tank", Vector3(0, 0, 0), Vector3(0, 0, -5))
	tank.receive_damage(40.0)
	t.check(tank.hit_jolt > 0.0, "A hit sets a hull jolt")
	for index in range(3):
		tank._physics_process(STEP)
	t.check(absf(tank.model_root.rotation.x) > 0.0001, "The hull rocks after a hit")
	t.check(tank.smoke_plume == null and tank.fire_plume == null, "A healthy vehicle shows no damage smoke")
	tank.health = tank.max_health * 0.55
	tank.receive_damage(1.0)
	t.check(tank.smoke_plume != null and tank.fire_plume == null, "Below 60% health the vehicle smokes")
	tank.health = tank.max_health * 0.25
	tank.receive_damage(1.0)
	t.check(tank.fire_plume != null, "Below 30% health the vehicle burns")
	tank.queue_free()

## Ammunition carriers cook off after their fuse, once each; an unarmoured jeep does not.
func _check_cook_off(t: TestContext) -> void:
	var tank: EnemyVehicle = _vehicle(t, "tank", Vector3(0, 0, 0), Vector3(0, 0, -5))
	var cooked: Array = []
	tank.cook_off.connect(func(_source, radius): cooked.append(radius))
	tank._die()
	t.equal(cooked.size(), 0, "A destroyed tank does not cook off instantly")
	await tank.get_tree().create_timer(EnemyVehicle.COOK_OFF_DELAY + 0.4).timeout
	t.equal(cooked.size(), 1, "A destroyed tank cooks off once after its fuse")
	t.near(float(cooked[0]) if cooked.size() > 0 else -1.0, EnemyVehicle.cook_off_radius("tank"), 0.0001, "The cook-off uses the tank's blast radius")
	var jeep: EnemyVehicle = _vehicle(t, "jeep", Vector3(0, 0, 0), Vector3(0, 0, -5))
	var jeep_cooked: Array = []
	jeep.cook_off.connect(func(_source, radius): jeep_cooked.append(radius))
	jeep._die()
	await jeep.get_tree().create_timer(EnemyVehicle.COOK_OFF_DELAY + 0.4).timeout
	t.equal(jeep_cooked.size(), 0, "A destroyed jeep does not cook off")
	tank.queue_free()
	jeep.queue_free()

## Adds a solid cover body on physics layer 1, the layer the line of fire is tested against.
func _add_cover(t: TestContext, centre: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = centre
	t.tree.root.add_child(blocker)
	return blocker

func _remove_cover(t: TestContext, blocker: StaticBody3D) -> void:
	t.tree.root.remove_child(blocker)
	blocker.free()

## A tank holding 20 m from the emplacement, turret not yet on the bearing.
func _siege_tank(t: TestContext, spawn: Vector3) -> EnemyVehicle:
	var tank: EnemyVehicle = _vehicle(t, "tank", spawn, Vector3(0, 0, 0))
	tank.stop_distance = 20.0
	tank.shoot_cooldown = 0.0
	return tank

## Vehicle line of fire. A wall between a gun and the emplacement stops every shot; the gun turns to a
## clear spot instead of firing uselessly; fire resumes when the line is clear.
func _check_vehicle_line_of_fire(t: TestContext) -> void:
	await t.tree.physics_frame
	var wall: StaticBody3D = _add_cover(t, Vector3(0, 3, 10), Vector3(6, 6, 2))
	await t.tree.physics_frame
	await t.tree.physics_frame
	var tank: EnemyVehicle = _siege_tank(t, Vector3(0, 0, 20))
	tank.can_reposition = false
	var shots: Array = [0]
	tank.shoot_requested.connect(func(_muzzle, _aim, _damage, _blast): shots[0] += 1)
	t.check(not tank.line_of_fire_clear(), "Cover between a tank and its target blocks the line of fire")
	for index in range(600):
		tank._physics_process(STEP)
	t.check(tank.aim_error <= EnemyVehicle.aim_tolerance("tank"), "The turret traverses onto the target behind the cover")
	t.equal(shots[0], 0, "A tank never fires through cover")
	tank.queue_free()
	_remove_cover(t, wall)
	await t.tree.physics_frame
	await t.tree.physics_frame

	wall = _add_cover(t, Vector3(0, 3, 10), Vector3(6, 6, 2))
	await t.tree.physics_frame
	await t.tree.physics_frame
	tank = _siege_tank(t, Vector3(0, 0, 20))
	var start: Vector3 = tank.global_position
	var clear_shots: Array = [0]
	var blocked_shots: Array = [0]
	tank.shoot_requested.connect(func(_muzzle, _aim, _damage, _blast):
		if tank.line_of_fire_clear():
			clear_shots[0] += 1
		else:
			blocked_shots[0] += 1)
	for index in range(1500):
		tank._physics_process(STEP)
	t.check(start.distance_to(tank.global_position) > 2.0, "A blocked tank drives to a spot with a clear line of fire")
	t.equal(blocked_shots[0], 0, "No shell leaves a tank whose line is blocked")
	t.check(clear_shots[0] >= 1, "The tank fires once it has a clear line from its new spot")
	t.equal(tank.reposition_point, Vector3.INF, "The tank has arrived at its firing spot")
	tank.queue_free()
	_remove_cover(t, wall)
	await t.tree.physics_frame
	await t.tree.physics_frame

	wall = _add_cover(t, Vector3(0, 3, 10), Vector3(6, 6, 2))
	await t.tree.physics_frame
	await t.tree.physics_frame
	tank = _siege_tank(t, Vector3(0, 0, 20))
	tank.can_reposition = false
	var held: Array = [0]
	tank.shoot_requested.connect(func(_muzzle, _aim, _damage, _blast): held[0] += 1)
	for index in range(600):
		tank._physics_process(STEP)
	t.equal(held[0], 0, "A tank held by cover stays silent while the line is blocked")
	_remove_cover(t, wall)
	await t.tree.physics_frame
	await t.tree.physics_frame
	for index in range(300):
		tank._physics_process(STEP)
	t.check(held[0] >= 1, "The tank fires again once the cover is gone")
	tank.queue_free()
	await t.tree.physics_frame

## Infantry: a blast does not pull a unit out of cover; a killed unit takes no more damage and stops shooting.
func _check_infantry_cover_and_death(t: TestContext, scene: CoastalController) -> void:
	var sheltered: EnemySoldier = _spawn(scene, 30.0, "soldier", 0)
	sheltered.state = EnemySoldier.State.COVER
	sheltered.react_to_explosion(sheltered.global_position + Vector3(0, 0, -5), 6.0)
	t.equal(sheltered.state, EnemySoldier.State.COVER, "A nearby blast does not pull a soldier out of cover")
	t.check(sheltered.stagger_time > 0.0, "A soldier in cover still reacts to a blast")
	var exposed: EnemySoldier = _spawn(scene, 31.0, "soldier", 0)
	exposed.state = EnemySoldier.State.ADVANCE
	exposed.react_to_explosion(exposed.global_position + Vector3(0, 0, -5), 6.0)
	t.equal(exposed.state, EnemySoldier.State.STAGGER, "A soldier in the open staggers from a nearby blast")
	var doomed: EnemySoldier = _spawn(scene, 32.0, "rpg", 0)
	var deaths: Array = [0]
	doomed.died.connect(func(_unit): deaths[0] += 1)
	doomed.receive_damage(999.0)
	t.check(doomed.is_dead(), "A lethal hit kills an RPG soldier")
	t.equal(deaths[0], 1, "An infantry death is announced once")
	t.equal(doomed.receive_damage(10.0), 0.0, "A corpse takes no further damage")
	t.equal(deaths[0], 1, "A corpse does not announce its death again")
	t.equal(doomed.collision_layer, 0, "A corpse has no collision on the unit layer, so it cannot block movement")
	t.equal(doomed.state, EnemySoldier.State.DEAD, "The dead RPG soldier is in the dead state")

## Hit reactions and death differ by role: heavy plate barely flinches and collapses straight down,
## the RPG soldier stumbles back and breaks its set-up, a heavy on its bipod keeps the set-up.
func _check_infantry_hit_reactions(t: TestContext, scene: CoastalController) -> void:
	t.check(InfantryRole.flinch(InfantryRole.Kind.HEAVY) < InfantryRole.flinch(InfantryRole.Kind.RIFLE), "A heavy soldier flinches less than a rifleman")
	t.check(InfantryRole.flinch(InfantryRole.Kind.RPG) > InfantryRole.flinch(InfantryRole.Kind.RIFLE), "An RPG soldier flinches more than a rifleman")
	t.check(InfantryRole.death_impulse_scale(InfantryRole.Kind.HEAVY) < 1.0, "A heavy soldier collapses under less impulse")
	t.check(InfantryRole.death_impulse_scale(InfantryRole.Kind.RPG) > 1.0, "An RPG soldier is thrown further on death")
	var rpg: EnemySoldier = _spawn(scene, 34.0, "rpg", 0)
	rpg.setup_timer = 1.0
	rpg.receive_damage(5.0, rpg.global_position + Vector3.UP * 0.9, Vector3.FORWARD)
	t.equal(rpg.setup_timer, 0.0, "A hit breaks an RPG soldier's set-up")
	t.check(rpg.hit_flinch > 0.0, "An RPG soldier flinches when hit")
	var heavy: EnemySoldier = _spawn(scene, 36.0, "heavy", 0)
	heavy.setup_timer = 1.0
	heavy.receive_damage(5.0, heavy.global_position + Vector3.UP * 0.9, Vector3.FORWARD)
	t.check(heavy.setup_timer > 0.5, "A heavy soldier keeps its bipod set-up through a graze")
	t.check(heavy.hit_flinch > 0.0 and heavy.hit_flinch < rpg.hit_flinch, "A heavy soldier's flinch is smaller than an RPG soldier's")

## A destroyed enemy cannot attack: the controller refuses shots from dead sources, and a dead vehicle is silent.
func _check_destroyed_enemies_cannot_attack(t: TestContext, scene: CoastalController) -> void:
	var tank: EnemyVehicle = _siege_tank(t, Vector3(0, 0, 20))
	t.check(scene._source_can_fire(tank), "A living tank may fire")
	var shots: Array = [0]
	tank.shoot_requested.connect(func(_muzzle, _aim, _damage, _blast): shots[0] += 1)
	tank._die()
	t.check(not scene._source_can_fire(tank), "The controller refuses shots from a destroyed tank")
	for index in range(120):
		tank._physics_process(STEP)
	t.equal(shots[0], 0, "A destroyed tank does not fire")
	t.equal(tank.receive_damage(500.0), 0.0, "A destroyed tank takes no further damage")
	tank.queue_free()
	var soldier: EnemySoldier = _spawn(scene, 38.0, "soldier", 0)
	soldier.receive_damage(999.0)
	t.check(not scene._source_can_fire(soldier), "A dead soldier is not a valid shooter")
	t.check(scene._source_can_fire(null), "A shot with no recorded source keeps its old behaviour")

## Wreck profiles: each vehicle type has its own tilt, cook-off bursts and plume size.
func _check_destruction_profiles(t: TestContext) -> void:
	t.check(EnemyVehicle.wreck_profile("jeep").tilt > EnemyVehicle.wreck_profile("tank").tilt, "A jeep rolls over further than a tank")
	t.check(EnemyVehicle.wreck_profile("apc").tilt > EnemyVehicle.wreck_profile("tank").tilt, "An APC lists further than a tank")
	t.equal(int(EnemyVehicle.wreck_profile("boss").bursts), 2, "The boss cooks off in two bursts")
	t.equal(int(EnemyVehicle.wreck_profile("tank").bursts), 1, "A tank cooks off once")
	t.equal(int(EnemyVehicle.wreck_profile("jeep").bursts), 0, "A jeep does not cook off")
	t.check(EnemyVehicle.wreck_profile("boss").smoke > EnemyVehicle.wreck_profile("tank").smoke, "The boss wreck throws bigger smoke than a tank")

## A destroyed vehicle announces its destruction once, builds its wreck plumes, stops firing and cooks off once per burst.
func _check_vehicle_destruction(t: TestContext) -> void:
	var boss: EnemyVehicle = _vehicle(t, "boss", Vector3(0, 0, 0), Vector3(0, 0, -5))
	var deaths: Array = [0]
	boss.died.connect(func(_unit): deaths[0] += 1)
	var bursts: Array = [0]
	boss.cook_off.connect(func(_source, _radius): bursts[0] += 1)
	boss.receive_damage(99999.0)
	t.check(boss.is_dead(), "A lethal hit destroys the boss")
	boss._die()
	boss.receive_damage(500.0)
	t.equal(deaths[0], 1, "A destroyed vehicle announces its destruction once")
	t.check(boss.smoke_plume != null and boss.fire_plume != null, "A wreck keeps its smoke and fire")
	await boss.get_tree().create_timer(EnemyVehicle.COOK_OFF_DELAY + EnemyVehicle.BURST_SPACING * 2.0 + 0.4).timeout
	t.equal(bursts[0], 2, "A destroyed boss cooks off once per burst, not repeatedly")
	boss.queue_free()

## Aircraft: a hit lurches the airframe, smoke then fire build on the wreck, and destruction is announced once.
func _check_aircraft_damage_and_destruction(t: TestContext) -> void:
	var plane := EnemyAircraft.new()
	t.tree.root.add_child(plane)
	plane.configure(Vector3(0, 0, 0), "helicopter", 0.0)
	plane.set_physics_process(false)
	plane.receive_damage(20.0)
	t.check(plane.hit_lurch > 0.0, "A hit lurches the airframe")
	plane.health = plane.max_health * 0.55
	plane.receive_damage(1.0)
	t.check(plane.smoke_plume != null and plane.fire_plume == null, "Below 60% health the aircraft smokes")
	plane.health = plane.max_health * 0.25
	plane.receive_damage(1.0)
	t.check(plane.fire_plume != null, "Below 30% health the aircraft burns")
	var deaths: Array = [0]
	plane.died.connect(func(_unit): deaths[0] += 1)
	plane.receive_damage(9999.0)
	plane.receive_damage(10.0)
	t.equal(deaths[0], 1, "An aircraft announces its destruction once")
	var fired: Array = [0]
	plane.shoot_requested.connect(func(_origin, _target, _damage, _blast): fired[0] += 1)
	plane.shoot_cooldown = 0.0
	plane._physics_process(STEP)
	t.equal(fired[0], 0, "A destroyed aircraft does not fire")
	plane.queue_free()
	await t.tree.process_frame
