extends RefCounted
## The awkward moments: the trigger held through an empty belt, a weapon put
## away half-loaded, the last grenade thrown as far as it goes, a rocket that
## bursts in the gunner's face, more blasts than the pool has slots, a wave that
## ends while its dead still lie there, defeat with the boss on the field, a
## pause with a thumb on FIRE, a drumming on every button, a touch on the very
## edge of the glass, and the phone taking the game away and giving it back.

const STEP: float = 1.0 / 60.0


func run(t: TestContext) -> void:
	await _weapons(t)
	await _blasts(t)
	await _waves_and_defeat(t)
	await _controls(t)


func _level(t: TestContext) -> CityLevel:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	level.begin_match()
	# These tests place their own zombies; the waves stay out of it.
	level.director.stop()
	return level


## A zombie that stays where it is put.
func _stand(level: CityLevel, type_id: StringName, at: Vector3) -> Zombie:
	var zombie: Zombie = level.horde.spawn(type_id, "avenue_left", "gate")
	zombie.position = at
	zombie.speed = 0.0
	return zombie


func _aim(defender: Defender, point: Vector3) -> void:
	var wanted: Vector2 = defender.aim_for(point)
	defender.aim.set_aim(wanted.x, wanted.y)
	defender.shake = Vector3.ZERO
	defender._apply_aim()


## A thumb on FIRE. The gunner passes it to the weapon in the next frame; the tests do not wait for one.
func _hold_fire(defender: Defender) -> void:
	defender.set_fire(true)
	defender.weapon.set_trigger(true)


## Runs the weapons' own clocks without waiting for real frames.
func _tick(defender: Defender, ticks: int) -> void:
	for tick: int in ticks:
		for item: Weapon in defender.weapons:
			item._physics_process(STEP)


func _weapons(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var defender: Defender = level.defender
	var gun: TwinHmg = defender.weapons[0] as TwinHmg
	var launcher: RocketLauncher = defender.weapons[1] as RocketLauncher

	# The trigger held through the end of the belt and through the whole reload.
	_aim(defender, defender.eye_position() + Vector3(0.0, 40.0, -200.0))
	gun.state.ammo = 3
	var before: int = gun.state.shots
	_hold_fire(defender)
	_tick(defender, 40)
	t.equal(gun.state.shots - before, 3, "with the trigger held, the last three rounds go and no more")
	t.check(gun.state.reloading and gun.state.ammo == 0, "the empty gun starts loading by itself")
	_tick(defender, int(gun.data.reload_time / STEP) - 45)
	t.equal(gun.state.shots - before, 3, "nothing is fired while it loads, however long the trigger is held")
	_tick(defender, 60)
	t.check(not gun.state.reloading and gun.state.shots - before > 3, "and it fires again on its own once the belt is in")
	defender.set_fire(false)
	t.check(not gun.trigger, "letting go of FIRE releases the trigger at once, not a frame later")
	var after_release: int = gun.state.shots
	_tick(defender, 30)
	t.equal(gun.state.shots, after_release, "and no round follows")
	await t.frames(1)

	# Put away half-loaded, the gun goes on loading.
	gun.state.ammo = 0
	t.check(gun.state.start_reload(), "the empty gun is set loading")
	_tick(defender, 20)
	t.check(defender.select_weapon(1), "the launcher can be taken up while the gun is loading")
	_tick(defender, int(gun.data.reload_time / STEP) + 10)
	t.check(not gun.state.reloading and gun.state.ammo == gun.data.magazine_size, "the gun finished loading while it was put away")
	t.check(defender.weapon == launcher and launcher.is_ready() and not gun.selected, "and the launcher is in hand, ready")

	# A drumming on the weapon cards.
	for press: int in 25:
		defender.select_weapon(press % 2)
		_tick(defender, 1)
	var in_hand: int = 0
	for item: Weapon in defender.weapons:
		if item.selected:
			in_hand += 1
	t.equal(in_hand, 1, "after two dozen presses on the cards exactly one weapon is selected")
	t.check(defender.weapon == defender.weapons[defender.weapon_index] and defender.weapon.selected, "and it is the one the gunner holds")
	t.check(not defender.weapon.trigger, "nothing was left firing")
	_tick(defender, 240)
	t.check(defender.weapon.is_ready(), "left alone, it comes up ready")

	# The last grenade, thrown as far as a grenade goes.
	_aim(defender, Vector3(0.0, 0.0, -140.0))
	var foot := Vector3(defender.camera.global_position.x, defender.ground_height, defender.camera.global_position.z)
	var target: Vector3 = defender.throw_target()
	var reach: float = defender.grenade_data.max_range
	t.near(Vector2(target.x - foot.x, target.z - foot.z).length(), reach, 0.05, "aimed far down the avenue, a grenade is sent to the end of its reach")
	var bursts: Array = []
	var on_blast := func(at: Vector3, _radius: float, _kills: int) -> void: bursts.append(at)
	Events.explosion.connect(on_blast)
	defender.grenade_count = 3
	defender.grenade_cooldown = 0.0
	var thrown: int = defender.grenades.thrown
	for press: int in 10:
		defender.throw_grenade()
	t.equal(defender.grenades.thrown, thrown + 1, "ten presses in one instant throw one grenade")
	t.equal(defender.grenade_count, 2, "and cost one")
	defender.grenade_count = 1
	defender.grenade_cooldown = 0.0
	t.check(defender.throw_grenade(), "the last grenade can be thrown")
	t.equal(defender.grenade_count, 0, "the belt is empty")
	defender.grenade_cooldown = 0.0
	thrown = defender.grenades.thrown
	for press: int in 10:
		defender.throw_grenade()
	t.check(defender.grenades.thrown == thrown and defender.grenade_count == 0, "ten more presses throw nothing and the count stays at nought")
	for tick: int in 600:
		defender.grenades._physics_process(STEP)
	Events.explosion.disconnect(on_blast)
	t.equal(bursts.size(), 2, "both grenades burst")
	var far_enough: bool = true
	var landed: Array[float] = []
	for at: Vector3 in bursts:
		var distance: float = Vector2(at.x - foot.x, at.z - foot.z).length()
		landed.append(snappedf(distance, 0.1))
		if distance < reach - 4.0 or distance > reach + 14.0:
			far_enough = false
	t.check(far_enough, "about where they were sent: at the end of the reach, give or take the bounce (%s m)" % str(landed))
	t.check(level.defense.wall_health == level.defense.data.wall_max_health, "and the wall took no harm from any of this")
	await t.discard(level)


func _blasts(t: TestContext) -> void:
	var level: CityLevel = await _level(t)
	var defender: Defender = level.defender
	var launcher: RocketLauncher = defender.weapons[1] as RocketLauncher

	# A rocket that meets something five metres from the muzzle.
	defender.select_weapon(1)
	_tick(defender, 240)
	t.check(launcher.is_ready(), "the launcher is on the shoulder")
	defender.aim.set_aim(0.0, -4.0)
	defender.shake = Vector3.ZERO
	defender._apply_aim()
	var close: Zombie = _stand(level, &"walker", defender.eye_position() + defender.aim_direction() * 5.0 - Vector3(0.0, 0.9, 0.0))
	close.force_update_transform()
	await t.physics_frames(2)
	close.position = defender.eye_position() + defender.aim_direction() * 5.0 - Vector3(0.0, 0.9, 0.0)
	close.force_update_transform()
	await t.physics_frames(2)
	var wall: float = level.defense.wall_health
	var gate: float = level.defense.gate_health
	var blasts: int = level.explosions.detonations
	defender.punch = 0.0
	_hold_fire(defender)
	_tick(defender, 3)
	defender.set_fire(false)
	t.equal(level.rockets.launched, 1, "one rocket leaves the tube")
	for tick: int in 120:
		level.rockets._physics_process(STEP)
	t.equal(level.explosions.detonations, blasts + 1, "it bursts once, a few metres from the gunner")
	t.check(not close.alive, "what it struck is dead")
	t.check(level.defense.wall_health == wall and level.defense.gate_health == gate, "close as it was, it cost the wall and the gate nothing")
	t.check(defender.punch <= 3.0001, "and the view is jolted, not thrown (%.2f)" % defender.punch)
	t.equal(level.rockets.active_count, 0, "no rocket is left in flight")

	# More blasts in one instant than the pool has slots.
	var data: ExplosionData = load("res://resources/explosions/grenade_blast.tres")
	var crowd: Array[Zombie] = []
	for index: int in 8:
		crowd.append(_stand(level, &"walker", Vector3(-17.5 + 5.0 * float(index), 0.0, -30.0)))
	blasts = level.explosions.detonations
	var emitters: int = level.effects.pool_size()
	var killed: int = 0
	for zombie: Zombie in crowd:
		killed += int(level.explosions.detonate(zombie.position + Vector3(0.0, 0.2, 0.0), data).killed)
	t.equal(level.explosions.detonations, blasts + 8, "eight blasts in one instant are all counted")
	t.equal(killed, 8, "and each kills the walker it lands on")
	t.check(level.explosions.burning() <= Explosions.BLASTS, "no more of them are drawn than the pool has slots (%d of %d)" % [level.explosions.burning(), Explosions.BLASTS])
	t.equal(level.effects.pool_size(), emitters, "and not one emitter was added")
	t.check(defender.punch <= 3.0001, "eight at once still do not throw the view")
	await t.frames(3)
	t.check(level.explosions.burning() <= Explosions.BLASTS, "it still holds a frame later")
	await t.discard(level)


func _waves_and_defeat(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	level.begin_match()

	# A wave is over the moment its last zombie dies, while the dead still lie there.
	var guard: int = 0
	while (level.director.index < 0 or level.director.phase == WaveDirector.Phase.SPAWNING) and guard < 600:
		t.simulate(level, 0.25)
		guard += 1
		if level.director.phase == WaveDirector.Phase.CLEARING:
			break
		for zombie: Zombie in level.horde.active:
			if zombie.alive and level.director.queue.size() > 0:
				zombie.kill()
	t.equal(level.director.phase, WaveDirector.Phase.CLEARING, "the whole first wave has been sent")
	for zombie: Zombie in level.horde.active:
		if zombie.alive:
			zombie.kill()
	t.simulate(level, 0.1)
	t.equal(level.director.phase, WaveDirector.Phase.INTERMISSION, "the wave is over as soon as the last one is dead")
	t.check(level.horde.alive_count() == 0 and level.horde.active.size() > 0, "although %d of them are still falling or lying there" % level.horde.active.size())
	t.equal(level.stats.waves_cleared, 1, "and it is counted as held")
	t.simulate(level, level.wave_set.waves[0].intermission + 2.5)
	t.equal(level.director.index, 1, "the next wave starts on time")
	t.check(level.horde.alive_count() > 0, "and its first zombies are on the street")
	var doubles: int = 0
	var seen: Dictionary = {}
	for zombie: Zombie in level.horde.active:
		doubles += 1 if seen.has(zombie) else 0
		seen[zombie] = true
		for stock: Array in level.horde.pooled.values():
			if stock.has(zombie):
				doubles += 1
	t.equal(doubles, 0, "no zombie is on the street twice, or on the street and in the pool")
	t.equal(level.horde.built_on_demand, 0, "and none had to be built in the middle of the fight")

	# Defeat with the boss on the field.
	level.director.stop()
	for zombie: Zombie in level.horde.active:
		if zombie.alive:
			zombie.kill()
	var boss: Zombie = level.horde.spawn(&"boss", "avenue_left", "gate")
	t.check(boss != null and level.horde.boss == boss, "the boss is on the field")
	var falls: Array = []
	var results: Array = []
	var on_fall := func(_zombie: Node3D) -> void: falls.append(true)
	var on_finish := func(victory: bool, stats: Dictionary) -> void: results.append([victory, stats])
	Events.boss_fell.connect(on_fall)
	Events.match_finished.connect(on_finish)
	level.defense.apply_damage("wall", level.defense.wall_health + 1.0)
	t.check(level.over and level.defense.breached, "the wall falls with the boss still on its feet")
	t.check(not level.defender.input_enabled, "the guns go dead")
	t.simulate(level, 30.0)
	t.equal(results.size(), 1, "the match ends once")
	t.check(results.size() == 1 and not results[0][0], "as a defeat")
	t.check(results.size() == 1 and int(results[0][1].bosses) == 0, "with no boss to the gunner's name")
	t.equal(falls.size(), 0, "the boss is not reported as fallen")
	t.check(level.horde.boss == boss and boss.alive and boss.state == Zombie.State.BREACH, "it is still on its feet, making for the breach")
	t.near(level.defense.wall_health, 0.0, 0.0001, "a wall that has fallen takes no further count")
	t.near(Engine.time_scale, 1.0, 0.0001, "time runs at its own speed again")
	Events.boss_fell.disconnect(on_fall)
	Events.match_finished.disconnect(on_finish)
	await t.discard(level)


func _controls(t: TestContext) -> void:
	var root: Window = t.tree.root
	var size_before: Vector2i = root.size
	Profile.persist = false
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(3)
	root.size = Vector2i(1440, 810)
	await t.frames(2)
	game.start_match()
	await t.frames(4)
	var hud: Hud = game.hud
	var level: CityLevel = game.level
	level.director.stop()
	var defender: Defender = level.defender
	var view: Vector2 = root.get_visible_rect().size
	var fire_at: Vector2 = hud.fire_button.center()
	t.equal(hud.role_at(fire_at), "fire", "FIRE is where it is drawn")

	# A pause with a thumb on FIRE.
	hud.touch_down(0, fire_at)
	await t.frames(1)
	t.check(defender.touch_fire and defender.weapon.trigger, "a thumb on FIRE holds the trigger")
	game.pause()
	var at_pause: int = defender.weapon.state.shots
	t.check(game.mode == 2 and t.tree.paused, "PAUSE stops the match")
	t.check(not defender.touch_fire and not defender.weapon.trigger and hud.fingers.is_empty(), "and lets go of the trigger and of every finger")
	await t.frames(3)
	hud.touch_up(0)
	game.resume()
	await t.frames(2)
	await t.physics_frames(8)
	t.check(game.mode == 1 and not t.tree.paused, "RESUME takes it up again")
	t.equal(defender.weapon.state.shots, at_pause, "with the gun silent until FIRE is pressed again")

	# The phone takes the game away and gives it back.
	hud.touch_down(0, fire_at)
	await t.frames(1)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(game.mode == 2 and t.tree.paused and game.menus.screen == "pause", "losing the screen to another app pauses the match")
	t.check(not defender.touch_fire and not defender.weapon.trigger, "and releases the trigger")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(game.mode == 2 and game.menus.screen == "pause", "being told twice changes nothing")
	Graphics.warmup = 0.0
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	Graphics.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await t.frames(2)
	t.check(game.mode == 2 and t.tree.paused, "coming back, the match is still paused: the player decides when it goes on")
	t.check(Graphics.warmup > 0.5, "and the quality governor does not judge the frame that spans the time away")
	t.check(game.go_back() and game.mode == 1, "the back button takes the match up again")
	game.to_menu()
	await t.frames(2)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(game.mode == 0 and not t.tree.paused, "on the title screen there is nothing to pause")
	game.start_match()
	await t.frames(4)
	level = game.level
	level.director.stop()
	defender = level.defender

	# A drumming on every button.
	for press: int in 12:
		game.pause()
		game.resume()
	t.check(game.mode == 1 and not t.tree.paused and hud.active, "a dozen pauses and resumes in one instant leave the match running")
	for press: int in 12:
		game.go_back()
	t.check(game.mode == 1 and not t.tree.paused, "and so do a dozen presses of the back button")
	hud.touch_down(1, hud.pause_button.center())
	hud.touch_down(2, hud.pause_button.center())
	t.check(game.mode == 2 and hud.fingers.is_empty(), "two taps on PAUSE in one instant pause once")
	game.resume()
	await t.frames(1)
	defender.weapon.state.ammo = 10
	for press: int in 10:
		hud.touch_down(3, hud.reload_button.center())
		hud.touch_up(3)
	t.check(defender.weapon.state.reloading, "ten taps on RELOAD start one reload")
	t.near(defender.weapon.state.reload_left, defender.weapon.data.reload_time, 0.05, "which is not started over by the other nine")
	defender.grenade_count = 3
	defender.grenade_cooldown = 0.0
	var thrown: int = defender.grenades.thrown
	for press: int in 10:
		hud.touch_down(4, hud.grenade_button.center())
		hud.touch_up(4)
	t.check(defender.grenades.thrown == thrown + 1 and defender.grenade_count == 2, "ten taps on the grenade throw one")

	# Touches on the very edge of the glass, and just off it.
	var edge_points: Array[Vector2] = [Vector2.ZERO, Vector2(view.x - 1.0, 0.0), Vector2(0.0, view.y - 1.0), view - Vector2.ONE,
		Vector2(view.x * 0.5, 0.0), Vector2(view.x * 0.5, view.y - 1.0), Vector2(0.0, view.y * 0.5), Vector2(view.x - 1.0, view.y * 0.5),
		Vector2(-30.0, -30.0), view + Vector2(60.0, 60.0)]
	var roles: Array[String] = []
	for point: Vector2 in edge_points:
		roles.append(hud.role_at(point))
	t.check(roles.all(func(role: String) -> bool: return role == "aim"), "a touch on any edge or corner, or just off the glass, is an aiming touch (%s)" % str(roles))
	var yaw: float = defender.aim.target_yaw
	hud.touch_down(5, Vector2(0.0, view.y * 0.5))
	hud.touch_drag(5, Vector2(140.0, 0.0))
	t.check(absf(defender.aim.target_yaw - yaw) > 1.0, "a drag that starts on the edge turns the gun")
	hud.touch_up(5)
	hud.touch_down(6, fire_at)
	hud.touch_down(7, fire_at + Vector2(12.0, 0.0))
	hud.touch_up(6)
	t.check(defender.touch_fire, "with two thumbs on FIRE, lifting one keeps the trigger held")
	hud.touch_up(7)
	t.check(not defender.touch_fire and not defender.weapon.trigger, "lifting the other releases it")
	hud.touch_up(99)
	hud.touch_drag(99, Vector2(50.0, 50.0))
	t.check(hud.fingers.is_empty(), "a finger that never landed changes nothing")

	# Defeat with the boss on the field, and the match after it.
	level.horde.spawn(&"boss", "avenue_left", "gate")
	await t.frames(2)
	t.check(hud.boss_shown, "the boss has its bar")
	level.defense.apply_damage("wall", level.defense.wall_health + 1.0)
	level.end_left = 0.05
	var waited: int = 0
	while game.mode != 3 and waited < 240:
		await t.frames(1)
		waited += 1
	t.check(game.mode == 3 and not game.menus.result_victory, "the wall falling with the boss alive ends in the defeat screen")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(game.mode == 3 and not t.tree.paused, "which an interruption leaves as it is")
	game.start_match()
	await t.frames(4)
	t.check(game.level != level and game.level.horde.boss == null, "the next match has no boss")
	t.check(not game.hud.boss_shown, "and no boss bar")
	t.check(game.level.defense.wall_health == game.level.defense.data.wall_max_health and not game.level.over, "behind a whole wall")
	t.near(Engine.time_scale, 1.0, 0.0001, "at full speed")
	t.check(game.level.defender.input_enabled and game.level.defender.weapon_index == 0, "with the guns live and the machine gun in hand")

	game.to_menu()
	await t.frames(1)
	t.tree.paused = false
	root.size = size_before
	Profile.reset()
	await t.discard(game)
