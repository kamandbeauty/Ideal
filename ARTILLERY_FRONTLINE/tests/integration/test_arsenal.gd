extends RefCounted
## The guns the player may stand on the mount: both are complete, the choice is
## kept and shown, and the six-barrel gun behaves as its numbers say.

const TICK: float = 1.0 / 60.0


func run(t: TestContext) -> void:
	Profile.persist = false
	Profile.reset()
	_on_paper(t)
	await _six_barrels(t)
	await _changing_guns(t)
	await _the_choice(t)
	Profile.reset()


func _still(level: CityLevel, at: Vector3) -> Zombie:
	var zombie: Zombie = level.horde.spawn(&"walker", "ring_right", "gate")
	zombie.position = at
	zombie.rotation = Vector3.ZERO
	zombie.speed = 0.0
	zombie.scale = Vector3.ONE
	return zombie


## Ticks a weapon by hand, the way the physics loop would, and returns how many rounds left it.
## With `aim` given, the gunner's aim settles between ticks as it does in play.
func _fire(weapon: Weapon, seconds: float, aim: AimController = null) -> int:
	var before: int = weapon.state.shots
	for tick: int in int(round(seconds / TICK)):
		weapon._physics_process(TICK)
		if aim != null:
			aim.step(TICK)
	return weapon.state.shots - before


func _on_paper(t: TestContext) -> void:
	t.check(Profile.GUNS.size() >= 2, "there is more than one gun to choose from")
	t.equal(Profile.GUNS[0], String(Profile.DEFAULTS.settings.gun), "the first of them is the one a new player has")
	var icons: Array[String] = []
	for id: String in Profile.GUNS:
		t.check(Defender.GUN_SCENES.has(id) and ResourceLoader.exists(Defender.GUN_SCENES[id]), "%s has a scene to stand on the mount" % id)
		var gun: Weapon = (load(Defender.GUN_SCENES[id]) as PackedScene).instantiate()
		t.check(gun != null and gun.data != null and String(gun.data.id) == id, "%s carries the numbers saved under its name" % id)
		t.check(gun.data == Menus.gun_data(id), "and the menu reads the same numbers")
		t.check(gun.data.kind == "bullet" and not gun.data.limited_supply(), "%s is a machine gun with belts that never run out" % id)
		t.check(Loc.TEXT.en.has(gun.data.name_key) and Loc.TEXT.fa.has(gun.data.name_key), "%s has a name in both languages" % id)
		t.check(HudWidgets.ICONS.has(gun.data.icon), "%s has an outline for its card (%s)" % [id, gun.data.icon])
		icons.append(gun.data.icon)
		for language: String in Profile.LANGUAGES:
			Profile.set_setting("language", language)
			var note: String = Menus.gun_note_for(id)
			t.check(note.length() > 20 and not note.contains("%") and note.contains(Loc.number(gun.data.magazine_size)),
				"%s is described in a line that names its belt (%s)" % [id, language])
		gun.free()
	t.check(icons[0] != icons[1], "the two guns are told apart by their outlines")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/hud_widgets.gd")
	var undrawn: Array[String] = []
	for icon: String in HudWidgets.ICONS:
		if not source.contains("\t\t\"%s\":" % icon):
			undrawn.append(icon)
	t.check(undrawn.is_empty(), "every outline the HUD says it knows is one it draws (%s)" % str(undrawn))

	# What makes them two guns and not one.
	var twin: WeaponData = Menus.gun_data("twin_hmg")
	var rotary: WeaponData = Menus.gun_data("rotary_gun")
	t.check(rotary.fire_interval <= twin.fire_interval * 0.5, "the six-barrel gun fires at least twice as fast (%.0f against %.0f a second)" % [
		1.0 / rotary.fire_interval, 1.0 / twin.fire_interval])
	t.check(rotary.damage < twin.damage and rotary.headshot_multiplier < twin.headshot_multiplier, "with a lighter round, less deadly to the head")
	t.check(rotary.penetration == 0 and twin.penetration >= 1, "that stops in the first body, where the twin gun's goes through")
	t.check(rotary.magazine_size >= twin.magazine_size * 3, "from a belt at least three times as long (%d against %d)" % [rotary.magazine_size, twin.magazine_size])
	t.check(rotary.spin_up_time > 0.0 and is_zero_approx(twin.spin_up_time), "and it alone has to run up before it fires")
	t.check(rotary.spread_degrees > twin.spread_degrees and rotary.reload_time > twin.reload_time, "it scatters wider and takes longer to reload")
	var walker: ZombieData = load("res://resources/zombies/walker.tres")
	var runner: ZombieData = load("res://resources/zombies/runner.tres")
	for prey: ZombieData in [walker, runner]:
		var twin_time: float = ceilf(prey.max_health / twin.damage) * twin.fire_interval
		var rotary_time: float = ceilf(prey.max_health / rotary.damage) * rotary.fire_interval
		t.check(rotary_time < twin_time, "held on the body of a %s it is the quicker of the two (%.2f s against %.2f s)" % [prey.id, rotary_time, twin_time])
	t.check(ceilf(walker.max_health / (twin.damage * twin.headshot_multiplier)) < ceilf(walker.max_health / (rotary.damage * rotary.headshot_multiplier)),
		"but a careful shot to the head is the twin gun's business")
	# Over a whole belt and its reload the two do the same work, to within a tenth.
	var twin_rate: float = twin.damage * float(twin.magazine_size) / (twin.fire_interval * float(twin.magazine_size) + twin.reload_time)
	var rotary_rate: float = rotary.damage * float(rotary.magazine_size) / (rotary.fire_interval * float(rotary.magazine_size) + rotary.reload_time
		+ rotary.spin_up_time)
	t.check(rotary_rate > twin_rate * 0.9 and rotary_rate < twin_rate * 1.1, "over belt after belt neither outguns the other (%.0f against %.0f a second)" % [
		rotary_rate, twin_rate])
	Profile.set_setting("language", "fa")


## The six-barrel gun on the mount: run-up, rate, run-down, the belt, and what a round does.
func _six_barrels(t: TestContext) -> void:
	Profile.set_setting("gun", "rotary_gun")
	var level: CityLevel = t.make_level()
	await t.frames(2)
	await t.physics_frames(2)
	var defender: Defender = level.defender
	var gun := defender.weapon as RotaryGun
	t.check(gun != null and defender.gun_id() == "rotary_gun", "the gun the player chose stands on the mount when the level is built")
	t.check(defender.weapons.size() == 2 and defender.weapons[0] == gun and defender.weapons[1].data.kind == "rocket",
		"first among the weapons, with the launcher beside it")
	t.check(gun.bullets == level.bullets and gun.effects == level.effects and gun.camera == defender.camera, "wired to the pools and to the gunner's eye")
	t.check(gun.rotor != null and gun.muzzle != null and gun.port != null and gun.pivot != null, "its model has a rotor, a muzzle and an ejection port")
	t.equal(gun.state.ammo, 500, "a full belt of 500 is loaded")
	var data: WeaponData = gun.data

	# Run-up: nothing leaves the gun until the barrels are at speed.
	# (The engine ticks the gun too while a test waits; here it is ticked by hand only.)
	defender.set_input_enabled(true)
	defender.aim.set_aim(0.0, 20.0)
	defender._apply_aim()
	gun.set_trigger(true)
	var early: int = _fire(gun, data.spin_up_time - 2.0 * TICK)
	t.equal(early, 0, "no round leaves while the barrels run up")
	t.check(gun.spin_fraction() > 0.5 and gun.spin_fraction() < 1.0 and gun.driving, "they are most of the way there (%.2f)" % gun.spin_fraction())
	var first: int = _fire(gun, 4.0 * TICK)
	t.check(first >= 1 and first <= 3, "%.1f s after the trigger the first rounds are away" % data.spin_up_time)
	t.near(gun.spin_fraction(), 1.0, 0.0001, "with the barrels at full speed")
	# Rate: exactly what the data says, whatever the tick.
	var burst: int = _fire(gun, 2.0, defender.aim)
	t.check(absi(burst - int(round(2.0 / data.fire_interval))) <= 1, "two seconds of fire is %d rounds (got %d)" % [int(round(2.0 / data.fire_interval)), burst])
	t.equal(gun.state.ammo, data.magazine_size - gun.state.shots, "each one comes off the belt")
	t.equal(level.bullets.launched, gun.state.shots, "and goes through the bullet pool")
	t.equal(level.stats.shots, gun.state.shots, "the match counts them as machine-gun rounds")
	t.check(defender.aim.recoil_pitch > 0.0, "the gun kicks")
	var twin_climb: float = defender.aim_settings.recoil_pitch_degrees / (Menus.gun_data("twin_hmg").fire_interval * defender.aim_settings.recoil_recovery_speed)
	t.check(defender.aim.recoil_pitch < twin_climb * 1.25, "but in a long burst it climbs no further than the twin gun does (%.2f degrees against %.2f)" % [
		defender.aim.recoil_pitch, twin_climb])
	# Run-down: the barrels coast, and a quick second pull finds them still turning.
	gun.set_trigger(false)
	var after: int = _fire(gun, 0.3)
	t.equal(after, 0, "letting go stops the fire at once")
	t.check(gun.spin_fraction() > 0.4 and gun.spin_fraction() < 0.9 and not gun.driving, "while the barrels coast on (%.2f)" % gun.spin_fraction())
	gun.set_trigger(true)
	var ticks: int = 0
	var shots_before: int = gun.state.shots
	while gun.state.shots == shots_before and ticks < 60:
		gun._physics_process(TICK)
		ticks += 1
	t.check(float(ticks) * TICK < data.spin_up_time * 0.75, "a second pull while they still turn fires sooner than from rest (%.2f s)" % (float(ticks) * TICK))
	gun.set_trigger(false)
	_fire(gun, RotaryGun.RUN_DOWN + 0.1)
	t.near(gun.spin_fraction(), 0.0, 0.0001, "left alone they stop within %.1f s" % RotaryGun.RUN_DOWN)
	# The belt: the last round starts the reload, the barrels run down through it, and the gun must run up again.
	gun.state.ammo = 3
	gun.set_trigger(true)
	var last: int = _fire(gun, data.spin_up_time + 0.3)
	t.equal(last, 3, "the last three rounds of a belt are fired")
	t.check(gun.state.reloading and gun.state.ammo == 0, "and the new belt goes in by itself")
	_fire(gun, data.reload_time - 0.4)
	t.check(gun.state.reloading and gun.spin_fraction() < 0.01, "the reload takes its %.1f s, with the barrels at rest" % data.reload_time)
	var resumed: int = _fire(gun, 0.2)
	t.check(not gun.state.reloading and gun.state.ammo == data.magazine_size - resumed and resumed == 0,
		"the belt is in, but with the trigger held all along nothing leaves until the barrels are back at speed")
	var again: int = _fire(gun, data.spin_up_time + 0.2)
	t.check(again > 0, "then the fire goes on")
	gun.set_trigger(false)
	_fire(gun, 1.2)
	# Put away for the launcher, the motor stops.
	gun.set_trigger(true)
	_fire(gun, data.spin_up_time + 0.1)
	defender.select_weapon(1)
	t.check(not gun.trigger, "shouldering the launcher takes the finger off the gun's trigger")
	var away: int = _fire(gun, 0.5)
	t.check(away == 0 and not gun.driving, "and the gun falls silent as it is put away")
	defender.select_weapon(0)
	_fire(gun, 1.2)
	t.check(gun.is_ready(), "(the gun is back in hand)")
	level.bullets.clear()

	# What a round does: its own damage to the first body, and nothing to the one behind.
	gun.data = data.duplicate()
	gun.data.spread_degrees = 0.0
	gun.state = WeaponState.new(gun.data)
	# (An open stretch of the square: nothing stands between the gun and these two.)
	var front: Zombie = _still(level, Vector3(6.0, 0.0, -45.0))
	var rear: Zombie = _still(level, Vector3(6.0, 0.0, -47.0))
	await t.physics_frames(3)
	var chest: Vector3 = front.global_position + Vector3(0.0, 1.05, 0.0)
	var wanted: Vector2 = defender.aim_for(chest)
	defender.aim.reset()
	defender.aim.set_aim(wanted.x, wanted.y)
	defender._apply_aim()
	var front_health: float = front.health
	var rear_health: float = rear.health
	gun.spin = 1.0
	gun.set_trigger(true)
	gun._physics_process(TICK)
	gun.set_trigger(false)
	var sent: int = gun.state.shots
	await t.physics_frames(8)
	t.check(sent >= 1 and sent <= 2, "(one tick of fire is a round or two: %d)" % sent)
	t.near(front.health, front_health - data.damage * float(sent), 0.001, "a body hit takes %.0f from a walker" % data.damage)
	t.near(rear.health, rear_health, 0.001, "and the walker standing behind it is untouched: the light round does not go through")
	# The head of the one behind, from the side, so that nothing stands in the way.
	var head: Vector3 = rear.head_area.global_position
	level.bullets.fire(head + Vector3(12.0, 0.0, 0.0), Vector3.LEFT * data.muzzle_velocity, data.damage, data.max_range,
		false, data.penetration, data.penetration_damage_scale, data.headshot_multiplier)
	await t.physics_frames(6)
	t.near(rear.health, rear_health - data.damage * data.headshot_multiplier, 0.001, "to the head it does %.0f" % (data.damage * data.headshot_multiplier))
	await t.discard(level)
	Profile.set_setting("gun", "twin_hmg")


## Another gun is stood on the mount of a level that is already built.
func _changing_guns(t: TestContext) -> void:
	var level: CityLevel = t.make_level()
	await t.frames(2)
	var defender: Defender = level.defender
	t.check(defender.weapon is TwinHmg and defender.gun_id() == "twin_hmg", "a new player's mount carries the twin gun")
	var old: Weapon = defender.weapon
	var launcher: Weapon = defender.weapons[1]
	var changes: Array = []
	var on_change := func() -> void: changes.append(1)
	defender.loadout_changed.connect(on_change)
	var told: Array = []
	var on_weapon := func(index: int, weapon: Node) -> void: told.append([index, weapon])
	Events.weapon_changed.connect(on_weapon)
	t.check(not defender.mount_gun("twin_hmg"), "standing the gun that is already there changes nothing")
	t.check(not defender.mount_gun("pea_shooter"), "nor does asking for a gun that does not exist")
	t.check(changes.is_empty() and defender.weapon == old, "and nobody is told otherwise")
	t.check(defender.mount_gun("rotary_gun"), "the six-barrel gun can be stood in its place")
	var gun: Weapon = defender.weapon
	t.check(gun is RotaryGun and defender.weapons[0] == gun and defender.gun_id() == "rotary_gun", "it is the gun in hand, first among the weapons")
	t.check(defender.weapons.size() == 2 and defender.weapons[1] == launcher, "the launcher is still the second")
	t.check(gun.is_ready() and gun.state.ammo == gun.data.magazine_size, "it is up, with a full belt")
	t.check(gun.bullets == level.bullets and gun.rockets == level.rockets and gun.effects == level.effects and gun.camera == defender.camera and gun.sight == defender.cradle,
		"wired to the pools and to the gunner's eye like the one it replaced")
	t.equal(changes.size(), 1, "the HUD is told once that the weapons changed")
	t.check(told.size() == 1 and told[0][0] == 0 and told[0][1] == gun, "and which one is in hand now")
	await t.frames(2)
	t.check(not is_instance_valid(old), "the gun taken off the mount is gone")
	var guns: int = 0
	for child: Node in defender.get_children():
		if child is Weapon and (child as Weapon).data.kind == "bullet":
			guns += 1
	t.equal(guns, 1, "one machine gun stands on the mount, not two")
	# It follows the aim like the old one, and firing it kicks the gunner's aim.
	defender.set_input_enabled(true)
	defender.aim.set_aim(25.0, 10.0)
	defender._apply_aim()
	t.check(gun.bore_direction().dot(defender.aim_direction()) > 0.999, "it points where the gunner looks")
	gun.set_trigger(true)
	_fire(gun, gun.data.spin_up_time + 0.2)
	gun.set_trigger(false)
	t.check(gun.state.shots > 0 and defender.aim.recoil_pitch > 0.0, "and its shots are felt in the aim")
	level.bullets.clear()
	# With the launcher on the shoulder the change happens behind it.
	t.check(defender.select_weapon(1) and defender.weapon == launcher, "(the launcher is shouldered)")
	var rockets: int = launcher.state.ammo + launcher.state.reserve
	t.check(defender.mount_gun("twin_hmg"), "the gun can be changed while the launcher is in hand")
	t.check(defender.weapon == launcher and defender.weapon_index == 1, "the launcher stays in hand")
	t.check(defender.weapons[0] is TwinHmg and not defender.weapons[0].selected and is_zero_approx(defender.weapons[0].readiness), "the new gun waits below the parapet")
	t.equal(launcher.state.ammo + launcher.state.reserve, rockets, "and no rocket is lost or gained by it")
	_fire(defender.weapons[0], 0.6)
	t.check(defender.select_weapon(0) and defender.weapon is TwinHmg, "it comes up when the gunner goes back to it")
	defender.loadout_changed.disconnect(on_change)
	Events.weapon_changed.disconnect(on_weapon)
	await t.discard(level)


## The choice on the title screen: shown at once, kept, and used by the next match.
func _the_choice(t: TestContext) -> void:
	var root: Window = t.tree.root
	var old_size: Vector2i = root.size
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await t.frames(3)
	root.size = Vector2i(1440, 810)
	await t.frames(2)
	var menus: Menus = game.menus
	var hud: Hud = game.hud
	t.check(menus.screen == "main" and menus.gun_choices != null, "the title screen offers the guns")
	t.equal(menus.gun_choices.buttons.size(), Profile.GUNS.size(), "one choice for each")
	t.equal(menus.gun_choices.selected, 0, "the twin gun is lit for a new player")
	var outlined: int = 0
	for glyph: MenuWidgets.Glyph in menus.gun_choices.glyphs:
		if glyph != null:
			outlined += 1
	t.equal(outlined, Profile.GUNS.size(), "each is shown by its outline over its name")
	t.equal(menus.gun_note.text, Menus.gun_note_for("twin_hmg"), "with a line on what the lit one is good for")
	t.check(game.level.defender.weapon is TwinHmg, "and the gun behind the menu is that one")
	var card_height: float = (menus.gun_note.get_parent().get_parent() as Control).size.y
	var rotary_at: int = Profile.GUNS.find("rotary_gun")
	t.check(rotary_at > 0, "the six-barrel is among the title guns")
	menus.gun_choices.buttons[rotary_at].pressed.emit()
	await t.frames(3)
	t.equal(String(Profile.setting("gun")), "rotary_gun", "a tap on the other gun makes it the player's")
	t.equal(menus.gun_choices.selected, rotary_at, "it is the one lit now")
	t.equal(menus.gun_note.text, Menus.gun_note_for("rotary_gun"), "the line under the choice describes it")
	t.near((menus.gun_note.get_parent().get_parent() as Control).size.y, card_height, 0.5, "and the card does not change its size for it")
	t.check(game.level.defender.weapon is RotaryGun, "the street behind the menu shows it on the mount at once")
	t.check(hud.weapon_slots.size() == 2 and hud.weapon_slots[0].icon == "rotary" and hud.weapon_slots[1].icon == "launcher", "and the HUD's cards are drawn for it")
	game.choose_gun("pea_shooter")
	t.equal(String(Profile.setting("gun")), "rotary_gun", "a gun that does not exist cannot be chosen")
	game.start_match()
	await t.frames(4)
	var level: CityLevel = game.level
	level.director.stop()
	t.check(level.defender.weapon is RotaryGun and level.defender.gun_id() == "rotary_gun", "the match is fought with the chosen gun")
	t.check(hud.weapon_slots.size() == 2 and hud.weapon_slots[0].icon == "rotary", "under its own card")
	t.equal(hud.magazine, 500, "the round count shows its belt")
	# The choice belongs to the title screen: mid-match the mount is left alone.
	game.choose_gun("twin_hmg")
	t.check(level.defender.weapon is RotaryGun, "the gun is not swapped under the gunner in the middle of a match")
	t.equal(String(Profile.setting("gun")), "twin_hmg", "though the choice is noted")
	game.to_menu()
	await t.frames(3)
	t.check(game.level.defender.weapon is TwinHmg and menus.gun_choices.selected == 0, "back on the title screen the noted gun stands on the mount and is lit")
	game.queue_free()
	await t.frames(2)
	root.size = old_size

	# Kept across a restart of the game, on a scratch save.
	var path: String = "user://test_arsenal_profile.json"
	SaveManager.remove(path)
	var real_path: String = Profile.save_path
	Profile.save_path = path
	Profile.persist = true
	Profile.reset()
	Profile.set_setting("gun", "rotary_gun")
	Profile.data = {}
	Profile.load_profile()
	t.equal(String(Profile.setting("gun")), "rotary_gun", "the chosen gun is still the player's after the game is closed and opened")
	Profile.persist = false
	Profile.save_path = real_path
	SaveManager.remove(path)
	Profile.reset()
