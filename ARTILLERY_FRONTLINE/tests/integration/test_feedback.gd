extends RefCounted
## What a fight shows and leaves behind, in the real level: scars and chips
## where rounds strike, brass from the gun, the figure rocking under a hit,
## blood where a body comes to rest, the layers of a blast, the kick of the
## view - and all of it pooled, and thinned out on the lowest quality tier.


func _still(level: CityLevel, type_id: StringName, at: Vector3) -> Zombie:
	var zombie: Zombie = level.horde.spawn(type_id, "ring_right", "gate")
	zombie.position = at
	zombie.rotation = Vector3.ZERO
	zombie.speed = 0.0
	zombie.scale = Vector3.ONE
	zombie.health = zombie.data.max_health
	zombie.full_health = zombie.health
	return zombie


func _tick(zombie: Zombie, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		zombie.tick(minf(left, 1.0 / 30.0))
		left -= 1.0 / 30.0


func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.reset()
	Graphics.apply_tier("high")
	var level: CityLevel = t.make_level()
	await t.frames(2)
	await t.physics_frames(3)
	level.director.stop()
	var effects: EffectPool = level.effects
	var marks: MarkPool = level.marks
	var bullets: BulletPool = level.bullets
	var defender: Defender = level.defender
	var gun: TwinHmg = defender.weapon as TwinHmg

	# What the level is given.
	t.check(marks != null and bullets.marks == marks and level.horde.marks == marks, "rounds and the horde share the level's pool of marks")
	t.check(level.ash != null and level.ash.emitting and level.ash.visible, "ash drifts over the court on the top tier")
	t.check(level.ash.amount <= 60, "and it is a handful of flecks, not a storm (%d)" % level.ash.amount)
	for kind: String in ["chips", "ember", "launch", "wisp"]:
		t.check(effects.emitters.has(kind), "the effect pool has %s" % kind)
	t.check(effects.emitters["ember"].size() >= Explosions.BLASTS, "every blast that can burn at once has its embers")
	t.check(gun != null and gun.casings != null and gun.ports.size() == 2, "the twin gun has a casing pool and a port for each barrel")
	t.check(gun.port_sides[0] * gun.port_sides[1] < 0.0, "the two barrels throw their brass to opposite sides")
	var pool_size: int = effects.pool_size()
	var mark_nodes: int = marks.get_child_count()
	var level_nodes: int = level.get_child_count()

	# A round into stone.
	var scars: int = int(marks.placed["scar"])
	var bursts: int = effects.bursts
	bullets.fire(Vector3(8.0, 3.0, -28.0), Vector3(0.0, -300.0, 0.0), 34.0, 100.0)
	await t.physics_frames(4)
	t.equal(int(marks.placed["scar"]), scars + 1, "a round into the paving leaves a scar")
	t.equal(effects.bursts, bursts + 2, "and knocks loose dust and chips")
	var scar: Transform3D = marks.shown("scar", scars % int(MarkPool.KINDS["scar"].count))
	t.check(absf(scar.origin.x - 8.0) < 0.01 and absf(scar.origin.z + 28.0) < 0.01, "the scar is where the round struck")
	t.check(scar.origin.y > 0.0 and scar.origin.y < 0.08, "lying on the paving (%.3f m)" % scar.origin.y)
	# The gate is plate: sparks, and no scar on something that swings away when it falls.
	scars = int(marks.placed["scar"])
	bursts = effects.bursts
	bullets.fire(Vector3(8.0, 1.1, -19.0), Vector3(300.0, 0.0, 0.0), 34.0, 100.0)
	await t.physics_frames(4)
	t.equal(int(marks.placed["scar"]), scars, "a round on the gate leaves no scar")
	t.equal(effects.bursts, bursts + 1, "only sparks")

	# The lowest tier keeps what costs nothing and drops the dressing.
	Graphics.apply_tier("low")
	t.check(not effects.detail, "the lowest tier switches the particle dressing off")
	t.check(not level.ash.visible and not level.ash.emitting, "the ash stops")
	t.check(not level.explosions.glow_lights, "blasts throw no light")
	t.check(not gun.light.visible, "and neither does the muzzle")
	t.check(level.rockets.glows.size() == RocketPool.CAPACITY and not level.rockets.glows.any(func(glow: OmniLight3D) -> bool: return glow.visible),
		"nor a rocket in flight")
	scars = int(marks.placed["scar"])
	bursts = effects.bursts
	bullets.fire(Vector3(-8.0, 3.0, -28.0), Vector3(0.0, -300.0, 0.0), 34.0, 100.0)
	await t.physics_frames(4)
	t.equal(effects.bursts, bursts + 1, "a strike on stone is dust alone")
	t.equal(int(marks.placed["scar"]), scars + 1, "the scar stays: every scar there is costs one draw call")
	Graphics.apply_tier("high")
	t.check(effects.detail and level.ash.visible and level.ash.emitting and level.explosions.glow_lights, "a higher tier brings it all back")
	t.check(gun.light.visible and level.rockets.glows.all(func(glow: OmniLight3D) -> bool: return glow.visible), "the lights of the guns with it")

	# The gun: brass, flash, and the report rolling on after the burst.
	level.begin_match()
	level.director.stop()
	defender.aim.set_aim(0.0, -4.0)
	await t.frames(2)
	var ejected: int = gun.casings.ejected
	var shots: int = gun.state.shots
	var wisps: int = 0
	defender.set_fire(true)
	var guard: int = 0
	while gun.state.shots < shots + 12 and guard < 400:
		await t.physics_frames(1)
		guard += 1
	t.check(gun.state.shots >= shots + 12, "the gun fires a burst")
	t.equal(gun.casings.ejected - ejected, gun.state.shots - shots, "every round throws a case")
	t.check(gun.casings.flying > 0 and gun.casings.flying <= CasingPool.COUNT, "some of them are in the air (%d)" % gun.casings.flying)
	t.check(gun.burst >= 12, "the gun knows it is in a burst")
	for emitter: CPUParticles3D in effects.emitters["wisp"]:
		if emitter.emitting:
			wisps += 1
	t.check(wisps > 0, "smoke curls off the muzzles")
	var flash: MeshInstance3D = gun.flashes[0]
	var flash_material: StandardMaterial3D = (flash.mesh as QuadMesh).material
	t.check(flash_material.albedo_color.r > 1.5, "the muzzle flash is brighter than white")
	t.check(flash_material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and flash_material.cull_mode == BaseMaterial3D.CULL_DISABLED,
		"it adds light and is seen from behind the gun")
	var away: Vector3 = (defender.camera.global_position - flash.global_position).normalized()
	t.check(absf(flash.global_basis.z.normalized().dot(away)) > 0.95, "and it faces the gunner squarely")
	# Cases leave the picture sideways: none of them crosses the middle of the view.
	var crossed: int = 0
	for slot: int in CasingPool.COUNT:
		if gun.casings.alive[slot] == 0:
			continue
		var local: Vector3 = defender.camera.global_transform.affine_inverse() * gun.casings.positions[slot]
		var half: float = tan(deg_to_rad(defender.camera.fov * 0.5))
		if local.z < 0.0 and absf(local.x / -local.z / (half * 16.0 / 9.0)) < 0.25 and absf(local.y / -local.z / half) < 0.5:
			crossed += 1
	t.equal(crossed, 0, "no case flies across the middle of the picture")
	# A flash is drawn at least once, however slow the frame: rounds leave in the physics step, the picture
	# comes later, and a flash timed from the shot would be over before a slow frame showed it.
	gun.flashes[0].visible = false
	gun.flashes[1].visible = false
	gun.barrel = 0
	gun._fire_round()
	t.check(gun.flashes[0].visible and not gun.flashes[1].visible, "a round lights the flash of its own barrel")
	gun._animate(0.25)
	t.check(gun.flashes[0].visible, "after a frame of a quarter of a second the flash is still there to be drawn")
	t.near(gun.light.light_energy, TwinHmg.FLASH_LIGHT, 0.0001, "and so is its light")
	t.check(gun.light.position.z > gun.muzzles[0].position.z + 1.0, "which stands well ahead of the muzzles")
	t.check(gun.light.light_specular <= 0.2, "and throws next to no highlight, so it does not gild the barrels")
	gun._animate(0.25)
	t.check(not gun.flashes[0].visible, "the frame after that puts it out")
	gun._fire_round()
	gun._animate(1.0 / 60.0)
	gun._animate(1.0 / 60.0)
	t.check(gun.flashes[1].visible, "at sixty frames a second a flash lasts two frames")
	gun._animate(1.0 / 60.0)
	gun._animate(1.0 / 60.0)
	t.check(not gun.flashes[1].visible, "and no more than three")
	Sound.last_start.erase("hmg_tail")
	defender.set_fire(false)
	await t.frames(2)
	await t.physics_frames(16)
	await t.frames(2)
	t.equal(gun.burst, 0, "releasing the trigger ends the burst")
	t.check(Sound.last_start.has("hmg_tail"), "and its report rolls on down the street")

	# A hit rocks the figure; it rights itself; the head stays an honest target.
	var walker: Zombie = _still(level, &"walker", Vector3(6.0, 0.0, -30.0))
	await t.physics_frames(3)
	# (Standing still it has turned to face its route; put it square to the gun again.)
	walker.rotation = Vector3.ZERO
	walker.force_update_transform()
	var head: Vector3 = walker.head_area.global_position
	t.check(walker.take_hit(20.0, false, head, Vector3(0.0, 0.0, -1.0)) == false, "a light hit does not kill")
	walker.model.force_update_transform()
	var moved: Vector3 = walker.head_area.global_position - head
	t.check(walker.rock.length() > 0.5 and walker.rock.length() <= Zombie.ROCK_LIMIT, "a hit rocks the figure (%.1f°)" % walker.rock.length())
	t.check(moved.z < -0.01, "backwards, along the round (%.3f m)" % moved.z)
	t.check(moved.length() < walker.data.head_radius * 0.6, "by less than the head is wide, so the next round still finds it")
	for round_index: int in 30:
		walker._rock(Vector3(0.6, 0.0, -0.8), 1.0)
	t.check(walker.rock.length() <= Zombie.ROCK_LIMIT + 0.001, "however many rounds land, it never tips past %.0f°" % Zombie.ROCK_LIMIT)
	_tick(walker, 1.0)
	t.check(walker.rock == Vector2.ZERO and walker.model.rotation.is_equal_approx(walker.gait_lean), "within a second it stands straight again")
	walker.rotation = Vector3.ZERO
	walker._rock(Vector3(1.0, 0.0, 0.0), 1.0)
	t.check(absf(walker.rock.y) > 0.5 and absf(walker.rock.x) < 0.01, "a round from the side tips it sideways")
	_tick(walker, 1.0)
	var by_type: Dictionary = {}
	for data: ZombieData in level.zombie_types:
		by_type[data.id] = data.hit_rock_degrees
	t.check(by_type[&"boss"] < by_type[&"brute"] and by_type[&"brute"] < by_type[&"walker"], "the bigger it is, the less a round moves it")

	# Where a body comes to rest, blood spreads; a heavy one raises the dust.
	var blood: int = int(marks.placed["blood"])
	var feet: Vector3 = walker.global_position
	walker.kill(false, Vector3(0.0, 0.0, -1.0))
	t.equal(int(marks.placed["blood"]), blood, "no blood while the body is still falling")
	# The fall is an animation; play it through, then let the horde's clock catch up.
	walker.anim.advance(4.0)
	await t.frames(2)
	_tick(walker, 3.0)
	t.equal(walker.state, Zombie.State.CORPSE, "the walker has fallen")
	t.equal(int(marks.placed["blood"]), blood + 1, "blood spreads where the body came to rest")
	var rest: Vector3 = walker.resting_point()
	t.check(rest.distance_to(feet) > 0.2 and rest.distance_to(feet) < 2.0, "under the body, not under where it stood (%.2f m away)" % rest.distance_to(feet))
	t.near(rest.y, feet.y, 0.001, "on the ground")
	var brute: Zombie = _still(level, &"brute", Vector3(-6.0, 0.0, -30.0))
	await t.physics_frames(2)
	bursts = effects.bursts
	blood = int(marks.placed["blood"])
	brute.kill(false, Vector3(0.0, 0.0, -1.0))
	brute.anim.advance(5.0)
	await t.frames(2)
	_tick(brute, 4.0)
	t.equal(int(marks.placed["blood"]), blood + 1, "a brute bleeds too")
	t.check(effects.bursts > bursts, "and the dust jumps when it lands")
	# Recycled, a figure is upright again.
	walker._rock(Vector3(0.0, 0.0, -1.0), 1.0)
	walker.recycle()
	t.check(walker.rock == Vector2.ZERO and walker.model.rotation.is_equal_approx(walker.gait_lean), "a recycled zombie goes back to the pool upright")

	# A blast is built in layers.
	var blast: ExplosionData = load("res://resources/explosions/rocket_blast.tres")
	bursts = effects.bursts
	var embers_before: int = effects.cursors["ember"]
	level.explosions.detonate(Vector3(0.0, 0.3, -34.0), blast)
	t.check(effects.bursts - bursts >= 5, "a blast is fire, smoke, debris, embers and dust (%d bursts)" % (effects.bursts - bursts))
	t.check(effects.cursors["ember"] != embers_before, "the embers fly")
	var glare: StandardMaterial3D = level.explosions.flashes[0].material_override
	t.check(level.explosions.flashes[0].visible and glare.albedo_color.r > 1.5, "its first instant is brighter than white")
	t.check(level.explosions.lights[0].visible and level.explosions.lights[0].light_energy > 1.0, "and it lights the street")
	# The same rule as for the muzzle: the frame that first shows a blast does not age it.
	level.explosions._process(0.3)
	t.check(level.explosions.flashes[0].visible and glare.albedo_color.a > 0.99, "a slow frame straight after the blast still shows its glare at full strength")
	level.explosions._process(0.05)
	t.check(glare.albedo_color.a < 0.95, "from the next frame on it fades")
	level.explosions._process(1.0)
	t.check(not level.explosions.flashes[0].visible and not level.explosions.lights[0].visible, "and within a second glare and light are gone")
	t.check(float(EffectPool.KINDS["fireball"].color.g) > 0.85 and float(EffectPool.KINDS["fireball"].end.r) < 0.4,
		"the fireball starts white-hot and burns down to a dull red")

	# The view kicks, and settles; with the shake switched off it does not move at all.
	var lens: float = defender.aim_settings.fov_degrees
	defender.punch = 0.0
	defender.shake = Vector3.ZERO
	defender.jolt(2.0)
	defender._process(0.001)
	t.check(defender.camera.fov > lens + 0.5 and defender.camera.fov <= lens + 3.0, "a heavy jolt throws the view open a little (%.2f°)" % (defender.camera.fov - lens))
	for step: int in 60:
		defender._process(1.0 / 60.0)
	t.near(defender.camera.fov, lens, 0.001, "and it settles within a second")
	var launcher: Weapon = defender.weapons[1]
	t.check(launcher != null and launcher.data.kind == "rocket", "the gunner carries a launcher")
	defender.punch = 0.0
	defender._on_shot(0, launcher)
	t.check(defender.punch > 1.0, "a rocket kicks the view")
	var tube := launcher as RocketLauncher
	if tube != null and tube.flash != null:
		tube._fire_round()
		tube._animate(0.25)
		t.check(tube.flash.visible, "the launcher's flash is drawn once however slow the frame")
		tube._animate(0.25)
		t.check(not tube.flash.visible, "and is out on the next")
	defender.punch = 0.0
	defender._on_shot(0, gun)
	t.near(defender.punch, 0.0, 0.0001, "the machine gun does not: at twelve rounds a second it would only blur")
	Profile.set_setting("screen_shake", false)
	defender.jolt(2.0)
	defender._process(0.001)
	t.near(defender.camera.fov, lens, 0.001, "with screen shake off the lens stays where it is")
	t.check(defender.camera.rotation.is_equal_approx(Vector3.ZERO), "and the view does not shake")
	Profile.set_setting("screen_shake", true)

	# The gate and the wall come down with something to see.
	bursts = effects.bursts
	level.defense.apply_damage("gate", 100000.0, level.layout.gate_center)
	t.check(level.defense.gate_destroyed and effects.bursts - bursts >= 5, "the gate goes in smoke, sparks, splinters and dust (%d bursts)" % (effects.bursts - bursts))

	# Nothing was created for any of it.
	t.equal(effects.pool_size(), pool_size, "the effect pool did not grow")
	t.equal(marks.get_child_count(), mark_nodes, "nor the marks")
	t.equal(level.get_child_count(), level_nodes, "nor the level")
	await t.discard(level)
	Profile.reset()
	Graphics.apply_preference()
