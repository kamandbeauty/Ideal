extends RefCounted
## The level, the gun and the zombie as built scenes.


func run(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	await t.physics_frames(3)
	var layout: LevelLayout = level.layout

	# Level mesh and collision.
	for node_name: String in ["Ground", "Fortress", "GateLeafA", "GateLeafB", "WallPatch", "CourtProps", "StreetProps", "Skyline"]:
		t.check(level.geometry.find_child(node_name, true, false) is MeshInstance3D, "the level mesh has the %s chunk" % node_name)
	var world: StaticBody3D = level.geometry.find_child("World", true, false)
	t.check(world != null and (world.collision_layer & Layers.WORLD) != 0, "the level has a static collision body on the world layer")
	t.equal(level.gate_leaves.size(), 2, "both gate leaves were found")
	t.equal(level.gate_body.collision_layer, Layers.DEFENSES, "the gate stops bullets")
	t.equal(level.patch_body.collision_layer, Layers.DEFENSES, "the wall patch stops bullets")

	# Shared materials.
	var ground: MeshInstance3D = level.geometry.find_child("Ground", true, false)
	var bound: int = 0
	var textured: bool = false
	for index: int in ground.mesh.get_surface_count():
		var material: Material = ground.get_surface_override_material(index)
		if material != null:
			bound += 1
			if material == MaterialLibrary.surface("paving") and (material as StandardMaterial3D).albedo_texture != null:
				textured = true
	t.equal(bound, ground.mesh.get_surface_count(), "every ground surface uses a library material")
	t.check(textured, "the court floor uses the shared textured paving material")
	var fortress: MeshInstance3D = level.geometry.find_child("Fortress", true, false)
	t.check(fortress.get_surface_override_material(0) == MaterialLibrary.surface("concrete"), "walls share the one concrete material")
	t.check((MaterialLibrary.surface("concrete") as StandardMaterial3D).normal_texture != null, "world materials carry normal maps")

	# Lighting and atmosphere.
	t.check(level.environment.fog_enabled and level.environment.background_mode == Environment.BG_SKY, "the scene has a sky and fog")
	t.check(is_zero_approx(level.environment.fog_sun_scatter), "fog does not scatter a ball of light into the picture")
	t.check(level.sun != null and level.sun.light_energy > 0.5, "the scene has a sun")
	t.check(level.sun.global_basis.z.dot(-CityLevel.SUN_TRAVEL.normalized()) > 0.99, "the sun shines along the configured direction")
	t.check(level.fire_nodes.size() == layout.fires.size() and level.fire_nodes.size() >= 3, "fires are built from the layout")

	# The gunner.
	var defender: Defender = level.defender
	t.check(defender.global_position.is_equal_approx(layout.mount_position), "the gun stands on the layout's mount")
	t.check(defender.camera.current, "the gunner's eye is the active camera")
	t.near(defender.camera.fov, defender.aim_settings.fov_degrees, 0.001, "the field of view comes from AimSettings")
	t.check(not defender.input_enabled, "input is off until the match begins")
	defender.aim.set_aim(0.0, 0.0)
	defender._apply_aim()
	t.check(defender.camera.global_position.distance_to(layout.eye_position) < 0.06, "the eye is where the layout says (%s)" % str(defender.camera.global_position))
	var worst: float = 1.0
	var eye_follows: float = 1.0
	for aim: Vector2 in [Vector2(0, 0), Vector2(70, 45), Vector2(-70, -15), Vector2(35, -10), Vector2(-52, 20)]:
		defender.aim.set_aim(aim.x, aim.y)
		defender.shake = Vector3.ZERO
		defender._apply_aim()
		var expected: Vector3 = AimController.direction_of(aim.x, aim.y)
		worst = minf(worst, defender.weapon.bore_direction().dot(expected))
		eye_follows = minf(eye_follows, defender.view_direction().dot(expected))
	t.check(worst > 0.99999, "the barrels point exactly where the aim controller says")
	t.check(eye_follows > 0.99999, "the camera looks along the barrels at every aim")
	defender.aim.set_aim(0.0, -15.0)
	defender._apply_aim()
	var muzzle: Vector3 = defender.weapon.muzzles[0].global_position
	t.check(muzzle.y > layout.mount_position.y + 0.45, "at full depression the muzzles stay above the kerb")
	t.equal(defender.weapon.muzzles.size(), 2, "the gun has two muzzles")
	# With the real rig: the crosshair can be laid on the chest of every attacker, and it lands there.
	var unreachable: int = 0
	var worst_miss: float = 0.0
	var checked: int = 0
	for line_name: String in level.horde.lines.lines:
		var slots: Array = level.horde.lines.lines[line_name].slots
		for index: int in slots.size():
			var chest: Vector3 = slots[index].position + Vector3(0.0, 1.2, 0.0)
			if not defender.can_aim_at(chest):
				unreachable += 1
				continue
			if index % 3 != 0:
				continue
			var wanted: Vector2 = defender.aim_for(chest)
			defender.aim.set_aim(wanted.x, wanted.y)
			defender.shake = Vector3.ZERO
			defender._apply_aim()
			var origin: Vector3 = defender.camera.global_position
			var along: float = (chest - origin).dot(defender.view_direction())
			worst_miss = maxf(worst_miss, (origin + defender.view_direction() * along).distance_to(chest))
			checked += 1
	t.equal(unreachable, 0, "the crosshair can reach the chest of every attack place within the aim limits")
	t.check(checked >= 15 and worst_miss < 0.02, "the solved aim puts the crosshair on the target (worst miss %.3f m over %d places)" % [worst_miss, checked])
	t.check(not defender.can_aim_at(Vector3(0.0, 0.0, -6.0)), "the dead ground under the bastion is out of reach, as designed")
	t.check(defender.weapon.data != null and defender.weapon.bullets == level.bullets, "the gun is wired to its data and the bullet pool")

	# Zombies.
	t.equal(level.horde.pooled[&"walker"].size(), (level.horde.types[&"walker"] as ZombieData).prewarm, "zombies are prewarmed into the pool")
	var zombie: Zombie = level.horde.pooled[&"walker"][0]
	t.check(not zombie.visible and zombie.state == Zombie.State.POOLED, "pooled zombies are hidden and idle")
	t.check(zombie.skeleton != null and zombie.skeleton.get_bone_count() == 18, "the zombie has its 18-bone skeleton")
	t.check(zombie.body_mesh != null and zombie.body_mesh.skin != null, "the zombie mesh is skinned")
	for clip: String in ["walk", "walk_m", "walk_b", "walk_b_m", "idle", "attack", "hit", "death_back", "death_front"]:
		t.check(zombie.anim.has_animation(clip), "the zombie has the %s clip" % clip)
	t.equal(zombie.walk_clips.size(), 4, "a walker has four ways of limping to choose from")
	for clip: String in zombie.walk_clips:
		t.equal(zombie.anim.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)
	t.equal(zombie.anim.get_animation("death_back").loop_mode, Animation.LOOP_NONE, "death does not loop")
	t.check(zombie.head_area.get_parent() is BoneAttachment3D, "the head volume rides the head bone")
	t.equal(zombie.body_area.collision_layer, 0, "a pooled zombie cannot be hit")
	t.check(zombie.body_area.get_meta("zombie") == zombie and zombie.head_area.get_meta("head") == true, "hit volumes know their zombie")
	t.check(MaterialLibrary.zombie_skin("walker", 0) != MaterialLibrary.zombie_skin("walker", 1), "zombie skins differ")
	t.check((MaterialLibrary.zombie_skin("walker", 2) as StandardMaterial3D).albedo_texture != null, "zombie skins are textured")
	var walk_rng := RandomNumberGenerator.new()
	walk_rng.seed = 7
	t.equal(zombie._pick_look(walk_rng), 0, "a life never wears the extra white figures")
	var limping: int = 0
	for _i: int in 200:
		if zombie._walk_name(zombie._pick_walk(walk_rng)).begins_with("walk_b"):
			limping += 1
	t.check(limping > 5 and limping < 50, "most walkers shuffle; a few still limp (%d of 200)" % limping)

	# Spawn points are out of the gunner's sight.
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var visible_spawns: Array[String] = []
	for route: String in layout.route_names():
		var spawn: Vector3 = (layout.routes[route].points as PackedVector3Array)[0] + Vector3(0.0, 1.4, 0.0)
		var query := PhysicsRayQueryParameters3D.create(layout.eye_position, spawn, Layers.WORLD)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or (hit.position as Vector3).distance_to(spawn) < 1.0:
			visible_spawns.append(route)
	t.check(visible_spawns.is_empty(), "every spawn point is hidden from the gun (%s)" % str(visible_spawns))

	# Wave director and effects.
	t.equal(level.director.wave_count(), level.wave_set.waves.size(), "the director holds the shipped waves")
	t.equal(level.director.phase, WaveDirector.Phase.IDLE, "no wave runs before the match begins")
	t.check(level.effects.pool_size() >= 30, "effect emitters are pooled up front")
	t.equal(level.bullets.multimesh.instance_count, BulletPool.CAPACITY, "one MultiMesh instance per pooled round")
	await t.discard(level)

	# The game's root scene.
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(3)
	t.check(game.level is CityLevel and game.hud is Hud and game.menus is Menus, "the main scene builds the level, HUD and menus")
	t.equal(game.menus.screen, "main", "the game opens on the title screen")
	t.check(not game.hud.active, "the combat HUD is hidden on the title screen")
	t.check(game.level.idle_view and not game.level.running, "the title screen shows the level without a match")
	t.tree.paused = false
	await t.discard(game)
