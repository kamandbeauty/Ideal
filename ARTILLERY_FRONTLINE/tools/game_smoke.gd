extends Node
## Self-driving run of the real game for CI: plays through menu, combat with
## every weapon, the gate falling and the defeat screen, then lays the game
## out on a 20:9 phone with a camera cut-out and on a 4:3 tablet, saving a
## screenshot at each step and a JSON report. Started with `-- --smoke`; never
## part of an exported build.
##
## Every picture is filed under how it came about, so nobody has to guess what it proves:
##   screen  - a menu of the real game, opened by this driver;
##   play    - the real game: the siege runs by its own rules and the weapons are worked through the
##             touch path (between pictures the siege is advanced without drawing);
##   slowed  - the same, with the clock slowed so a software renderer can catch a moment that lasts a few frames;
##   staged  - zombies or damage placed by this driver; what happens next is the game's own doing;
##   preview - a screen shown with figures this driver made up.

const OUT: String = "res://documentation/qa/"
const KINDS: Array[String] = ["screen", "play", "slowed", "staged", "preview"]
## A camera cut-out on the left edge of a phone held in landscape, in canvas units (about 90 px of a 2400 x 1080 screen).
const CUTOUT: float = 68.0

var game: Node
var level: CityLevel
var failures: Array[String] = []
var shots: Array[String] = []
var kinds: Dictionary = {}
var notes: Dictionary = {}
var checks: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Profile.persist = false
	Profile.load_profile()
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("SMOKE FAIL: " + message)


func frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func shot(shot_name: String, kind: String = "play") -> void:
	assert(KINDS.has(kind))
	if DisplayServer.get_name() == "headless":
		# Nothing is drawn without a display; keep the sequence so the logic can still be exercised.
		await frames(1)
		print("SMOKE shot ", shot_name, " skipped (headless)")
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUT + shot_name + ".png"
	var error: int = image.save_png(path)
	check(error == OK, "screenshot %s saved" % shot_name)
	shots.append(shot_name + ".png")
	kinds[shot_name + ".png"] = kind
	print("SMOKE shot ", shot_name, " ", image.get_size(), " ", kind)


## Advances the siege without rendering, to reach a moment worth looking at.
func simulate(seconds: float, step: float = 1.0 / 30.0) -> void:
	var left: float = seconds
	while left > 0.0 and not level.over:
		var delta: float = minf(step, left)
		level.director._physics_process(delta)
		level.horde._physics_process(delta)
		level.defense._physics_process(delta)
		# The match clock normally runs with the drawn frames; skipped time counts too.
		if level.running:
			level.stats.time += delta
		left -= delta


## The attacker nearest the gunner, optionally only those on one target ("gate" or "wall").
func _nearest_attacker(target: String = "") -> Zombie:
	var best: Zombie = null
	for zombie: Zombie in level.horde.active:
		if zombie.alive and zombie.state == Zombie.State.ATTACK and (target == "" or (zombie.slot != null and zombie.slot.target == target)):
			if best == null or zombie.position.length() < best.position.length():
				best = zombie
	return best


func _physics_frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


## Waits for the physics step in which the next round leaves the gun. The picture taken straight
## after it shows that round's muzzle flash: a flash is never put out before it has been drawn once.
func _next_round(gun: TwinHmg) -> void:
	var fired: int = gun.state.shots
	var waited: int = 0
	while gun.state.shots == fired and waited < 240:
		await get_tree().physics_frame
		waited += 1


## Figures for the victory screen that agree with each other and with the game's own data: every
## zombie of every wave is dead, and no more explosives were used than the gunner is ever handed.
func _victory_figures() -> Dictionary:
	var waves: WaveSet = level.director.wave_set
	var launcher: WeaponData = level.defender.weapons[1].data
	var stats := MatchStats.new()
	var rockets_handed: int = launcher.magazine_size + launcher.reserve
	var grenades_handed: int = level.defender.grenade_data.carried
	for wave: WaveData in waves.waves:
		stats.special_kills += wave.total() - wave.count_of(&"walker")
		stats.bosses += wave.count_of(&"boss")
		rockets_handed += wave.resupply_rockets
		grenades_handed += wave.resupply_grenades
	stats.kills = waves.total_zombies()
	stats.wave = waves.waves.size()
	stats.waves_total = waves.waves.size()
	stats.waves_cleared = waves.waves.size()
	stats.victory = true
	stats.rockets = mini(9, rockets_handed)
	stats.grenades = mini(7, grenades_handed)
	# About four kills to an explosive, as in the play-through above; a quarter of the rest by headshot.
	stats.blast_kills = (stats.rockets + stats.grenades) * 4
	stats.headshots = (stats.kills - stats.blast_kills) / 4
	stats.shots = 2600
	stats.hits = 1222
	# Inside the band the simulated sieges of the test suite finish in.
	stats.time = 486.0
	stats.wall_left = 0.82
	stats.gate_left = 0.37
	check(stats.blast_kills + stats.headshots <= stats.kills and stats.special_kills <= stats.kills and stats.bosses <= stats.special_kills,
		"the figures of the victory preview agree with each other")
	return stats.to_dict()


## Resizes the window and waits for the canvas to take the shape the stretch settings give it there.
func _resize(window_size: Vector2i, canvas: Vector2) -> bool:
	get_window().size = window_size
	for index: int in 20:
		await frames(1)
		if (get_viewport().get_visible_rect().size - canvas).length() < 3.0:
			await frames(3)
			return true
	return false


## Everything the HUD draws that is not a full-screen overlay: [name, rectangle].
func _hud_parts() -> Array:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var parts: Array = []
	for child: Node in game.hud.root.get_children():
		var control := child as Control
		if control == null or not control.is_visible_in_tree() or control.modulate.a <= 0.01:
			continue
		var box: Rect2 = control.get_global_rect()
		if box.size.x <= 1.0 or box.size.y <= 1.0 or box.size.x >= view.x - 1.0:
			continue
		# The sight and the kill marks belong to the middle of the picture, not to its edges.
		if control == game.hud.crosshair:
			continue
		parts.append([String(control.name), box])
	return parts


## Checks that the HUD keeps clear of the cut-outs and of the screen's edges, and that the thumb controls are whole.
func _check_hud(label: String, cutouts: Vector2) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var outside: Array[String] = []
	var under: Array[String] = []
	var leftmost: float = view.x
	var rightmost: float = 0.0
	for part: Array in _hud_parts():
		var box: Rect2 = part[1]
		leftmost = minf(leftmost, box.position.x)
		rightmost = maxf(rightmost, box.end.x)
		if box.position.x < -0.5 or box.position.y < -0.5 or box.end.x > view.x + 0.5 or box.end.y > view.y + 0.5:
			outside.append("%s %s" % [part[0], str(box)])
		if box.position.x < cutouts.x + 19.5 or box.end.x > view.x - cutouts.y - 19.5:
			under.append("%s %s" % [part[0], str(box)])
	check(outside.is_empty(), "%s: every part of the HUD is on the screen (%s)" % [label, str(outside)])
	check(under.is_empty(), "%s: no part of the HUD is under a cut-out or within 20 units of one (%s)" % [label, str(under)])
	var buttons: Array = [game.hud.fire_button, game.hud.reload_button, game.hud.grenade_button, game.hud.pause_button]
	var whole: bool = true
	for button: HudWidgets.RoundButton in buttons:
		var at: Vector2 = button.center()
		if at.x - button.radius < cutouts.x or at.x + button.radius > view.x - cutouts.y or at.y - button.radius < 0.0 or at.y + button.radius > view.y:
			whole = false
	check(whole, "%s: FIRE, RELOAD, GRENADE and PAUSE are whole and clear of the cut-outs" % label)
	var apart: bool = true
	for first: int in buttons.size():
		for second: int in range(first + 1, buttons.size()):
			var one: HudWidgets.RoundButton = buttons[first]
			var other: HudWidgets.RoundButton = buttons[second]
			if one.center().distance_to(other.center()) < one.radius + other.radius + 4.0:
				apart = false
	check(apart, "%s: the thumb buttons do not touch each other" % label)
	check(game.hud.fire_button.radius >= 80.0, "%s: FIRE keeps its size" % label)
	notes[label] = {
		"canvas": [snappedf(view.x, 0.1), snappedf(view.y, 0.1)], "cutouts": [cutouts.x, cutouts.y],
		"hud_from": snappedf(leftmost, 0.1), "hud_to": snappedf(rightmost, 0.1),
		"fire": [snappedf(game.hud.fire_button.center().x, 0.1), snappedf(game.hud.fire_button.center().y, 0.1)],
	}


## Checks that everything a menu shows that can be read or pressed is on the screen and clear of the cut-outs.
func _check_menu(label: String, cutouts: Vector2) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var wrong: Array[String] = []
	var seen: int = 0
	var pending: Array[Node] = [game.menus.holder]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not (control is BaseButton or control is Label or control.has_method("flip") or control.has_method("set_from")):
			continue
		var box: Rect2 = control.get_global_rect()
		if box.size.x <= 0.0 or box.size.y <= 0.0:
			continue
		seen += 1
		if box.position.x < cutouts.x - 0.5 or box.end.x > view.x - cutouts.y + 0.5 or box.position.y < -0.5 or box.end.y > view.y + 0.5:
			wrong.append("%s %s" % [control.name, str(box)])
	check(seen > 0 and wrong.is_empty(), "%s: all %d texts and controls of the %s screen are on the screen and clear of the cut-outs (%s)"
		% [label, seen, game.menus.screen, str(wrong)])


## The same game on other screens. The window is resized, so the canvas takes the shape the stretch
## settings give it there: 1800 x 810 on a 20:9 phone, 1440 x 1080 on a 4:3 tablet.
func _other_screens() -> void:
	var base: Vector2i = get_window().size
	notes["window"] = [base.x, base.y]

	# A 20:9 phone held in landscape with its camera cut-out on the left.
	var phone: bool = await _resize(Vector2i(base.x, int(round(float(base.x) * 9.0 / 20.0))), Vector2(1800.0, 810.0))
	notes["phone_20x9_laid_out"] = phone
	if phone:
		var cutouts := Vector2(CUTOUT, 0.0)
		game.hud.inset_override = cutouts
		game.menus.inset_override = cutouts
		game.menus.show_settings("main")
		await frames(4)
		_check_menu("phone_20x9_settings", cutouts)
		await shot("24-phone-20x9-settings", "screen")
		game.menus.show_main()
		await frames(3)
		_check_menu("phone_20x9_menu", cutouts)
		# The English title stands on the left, next to the cut-out.
		Profile.set_setting("language", "en")
		await frames(3)
		_check_menu("phone_20x9_menu_en", cutouts)
		Profile.set_setting("language", "fa")
		await frames(2)

		game.start_match()
		await frames(6)
		level = game.level
		check(level != null and level.running, "a second match starts on the 20:9 screen")
		level.defender.aim.set_aim(40.0, -8.5)
		simulate(36.0)
		var extra: int = 0
		while level.horde.attackers("gate") < 2 and extra < 40:
			simulate(1.0)
			extra += 1
		var victim: Zombie = _nearest_attacker("gate")
		if victim != null:
			_aim_at(victim.position + Vector3(0.0, 1.15, 0.0))
		await frames(4)
		_check_hud("phone_20x9", cutouts)
		# FIRE is pressed where it is drawn on this screen.
		var gun: TwinHmg = level.defender.weapon as TwinHmg
		var fired: int = level.stats.shots
		game.hud.touch_down(0, game.hud.fire_button.center())
		await _physics_frames(14)
		await _next_round(gun)
		await shot("25-phone-20x9-play")
		await _physics_frames(10)
		game.hud.touch_up(0)
		check(level.stats.shots > fired, "FIRE works where it is drawn on the 20:9 screen")
		check(game.hud.role_at(game.hud.fire_button.center()) == "fire" and game.hud.role_at(Vector2(900.0, 300.0)) == "aim",
			"the right thumb finds FIRE and the middle of the screen aims")

		# Left-handed: the thumb controls change sides, and FIRE now sits by the cut-out.
		Profile.set_setting("left_handed", true)
		await frames(4)
		_check_hud("phone_20x9_left_handed", cutouts)
		check(game.hud.fire_button.center().x < 900.0, "left-handed, FIRE is under the left thumb")
		await shot("26-phone-20x9-left-handed")
		Profile.set_setting("left_handed", false)
		await frames(3)
	game.hud.inset_override = Vector2(-1.0, -1.0)
	game.menus.inset_override = Vector2(-1.0, -1.0)

	# A 4:3 tablet: the canvas grows upward instead of sideways.
	var tablet: bool = await _resize(Vector2i(int(round(float(base.y) * 4.0 / 3.0)), base.y), Vector2(1440.0, 1080.0))
	notes["tablet_4x3_laid_out"] = tablet
	if tablet:
		if game.mode != 1:
			game.start_match()
			await frames(6)
			level = game.level
			simulate(30.0)
		await frames(4)
		_check_hud("tablet_4x3", Vector2.ZERO)
		await shot("27-tablet-4x3-play")
		game.pause()
		await frames(3)
		_check_menu("tablet_4x3_pause", Vector2.ZERO)
		game.resume()
		await frames(2)
	if game.mode != 0:
		game.to_menu()
		await frames(6)
	if tablet:
		_check_menu("tablet_4x3_menu", Vector2.ZERO)
		await shot("28-tablet-4x3-menu", "screen")

	var restored: bool = await _resize(base, Vector2(1440.0, 810.0))
	check(restored and game.menus.screen == "main", "back on the 16:9 screen the title is laid out again")
	_check_menu("back_on_16x9_menu", Vector2.ZERO)


func _aim_at(point: Vector3) -> void:
	var wanted: Vector2 = level.defender.aim_for(point)
	level.defender.aim.set_aim(wanted.x, wanted.y)


## One of each kind side by side on the court, seen through a long lens, with
## the gun and the HUD out of the picture. Not a view the player gets: it is
## here so the four models can be compared in the real renderer.
func _line_up() -> void:
	var eye: Vector3 = level.defender.eye_position()
	var places: Dictionary = {&"runner": 3.9, &"walker": 5.3, &"brute": 7.0, &"boss": 9.5}
	var row: Array[Zombie] = []
	level.horde.set_physics_process(false)
	for type_id: StringName in places:
		var zombie: Zombie = level.horde.spawn(type_id, "ring_right", "gate")
		zombie.position = Vector3(places[type_id], 0.0, -26.0)
		zombie.rotation.y = atan2(eye.x - zombie.position.x, eye.z - zombie.position.z)
		row.append(zombie)
	check(row.size() == 4 and level.horde.alive_count() == 4, "one of each kind stands on the court")
	var camera: Camera3D = level.defender.camera
	var lens: float = camera.fov
	_aim_at(Vector3(6.9, 1.75, -26.0))
	camera.fov = 12.5
	level.defender.weapon.visible = false
	game.hud.visible = false
	await frames(10)
	await shot("17-the-four-kinds", "staged")
	camera.fov = lens
	level.defender.weapon.visible = true
	game.hud.visible = true
	for zombie: Zombie in row:
		zombie.kill()
	level.horde.set_physics_process(true)
	# Long enough for the bodies to be cleared away.
	simulate(16.0)
	check(level.horde.alive_count() == 0 and level.horde.boss == null, "the court is empty again")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		# Without a display the window is a 64-pixel square; give the canvas the 16:9 shape it has in the rendered run.
		get_window().size = Vector2i(1440, 810)
	await frames(8)
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	check(canvas.is_equal_approx(Vector2(1440.0, 810.0)), "the canvas is 1440 x 810 on a 16:9 screen (%s)" % str(canvas))
	check(game.menus.screen == "main", "the game opens on the main menu")
	await shot("01-menu-fa", "screen")
	Profile.set_setting("language", "en")
	await frames(3)
	await shot("02-menu-en", "screen")
	game.menus.show_settings("main")
	await frames(3)
	await shot("03-settings-en", "screen")
	Profile.set_setting("language", "fa")
	await frames(3)
	await shot("04-settings-fa", "screen")
	game.menus.show_main()
	await frames(2)

	game.start_match()
	await frames(6)
	level = game.level
	check(level != null and level.running, "a match is running after DEFEND")
	check(game.hud.active, "the HUD is active in play")
	await shot("05-match-start")

	# First wave arriving through the court mouth.
	simulate(24.0)
	await frames(8)
	notes["alive_at_24s"] = level.horde.alive_count()
	check(level.horde.alive_count() > 0, "zombies are on the field after 24 s")
	await shot("06-wave-arrives")

	# Swing to the gate and fire through the real touch path.
	level.defender.aim.set_aim(40.0, -8.5)
	simulate(14.0)
	# The first of them reach the gate between half a minute and three quarters, depending on the routes drawn.
	var extra: int = 0
	while level.horde.attackers("gate") < 2 and extra < 40:
		simulate(1.0)
		extra += 1
	await frames(6)
	notes["gate_attackers"] = level.horde.attackers("gate")
	await shot("07-gate-under-attack")
	# Lay the sight on one of the attackers and hold FIRE: the whole chain from
	# thumb to kill (touch router, gun, convergence, pooled round, hit volume).
	var victim: Zombie = _nearest_attacker("gate")
	if victim != null:
		_aim_at(victim.position + Vector3(0.0, 1.15, 0.0))
	await frames(3)
	var fired_before: int = level.stats.shots
	var gun: TwinHmg = level.defender.weapon as TwinHmg
	game.hud.touch_down(0, game.hud.fire_button.center())
	for index: int in 14:
		await get_tree().physics_frame
	await _next_round(gun)
	await shot("08-gate-firing")
	check(gun.flashes[0].visible or gun.flashes[1].visible, "a muzzle flash is on screen while the gun fires")
	check(gun.casings.ejected > 0, "the gun throws its brass")
	for index: int in 40:
		await get_tree().physics_frame
	game.hud.touch_up(0)
	notes["shots"] = level.stats.shots - fired_before
	notes["hits"] = level.stats.hits
	notes["kills"] = level.stats.kills
	check(level.stats.shots > fired_before, "holding FIRE shoots")
	check(victim != null, "a zombie reached the gate to be shot at")
	check(level.stats.hits > 0, "rounds aimed at a zombie hit it")
	check(level.stats.kills > 0, "sustained fire on a zombie kills it")
	await frames(4)

	# The launcher: taken up from its card, then one rocket into the crowd at the gate.
	simulate(5.0)
	game.hud.touch_down(1, game.hud.weapon_slots[1].center())
	game.hud.touch_up(1)
	var waited_frames: int = 0
	while not level.defender.weapon.is_ready() and waited_frames < 300:
		await get_tree().physics_frame
		waited_frames += 1
	check(level.defender.weapon_index == 1 and level.defender.weapon.is_ready(), "the launcher comes up from its card")
	victim = _nearest_attacker("gate")
	_aim_at(victim.position + Vector3(0.0, 0.9, 0.0) if victim != null else level.layout.gate_center + Vector3(-1.2, -1.2, 0.0))
	await frames(4)
	await shot("09-rpg-shouldered")
	var kills_before: int = level.stats.kills
	game.hud.touch_down(0, game.hud.fire_button.center())
	waited_frames = 0
	while level.rockets.launched < 1 and waited_frames < 120:
		await get_tree().physics_frame
		waited_frames += 1
	game.hud.touch_up(0)
	check(level.rockets.launched == 1, "FIRE launches one rocket")
	# The flight lasts a third of a second; slow the clock so the software renderer can catch the round in the air.
	Engine.time_scale = 0.1
	await _physics_frames(9)
	check(level.rockets.active_count == 1, "the rocket is in flight")
	await shot("10-rocket-away", "slowed")
	Engine.time_scale = 1.0
	waited_frames = 0
	while level.explosions.detonations < 1 and waited_frames < 600:
		await get_tree().physics_frame
		waited_frames += 1
	await shot("11-rocket-blast")
	check(level.explosions.detonations >= 1, "the rocket bursts")
	check(level.stats.kills > kills_before, "the rocket kills in the crowd at the gate")
	notes["rocket_kills"] = level.stats.kills - kills_before
	await frames(3)

	# Back behind the machine gun, and a grenade for the patched breach on the left arm.
	game.hud.touch_down(1, game.hud.weapon_slots[0].center())
	game.hud.touch_up(1)
	simulate(6.0)
	victim = _nearest_attacker("wall")
	_aim_at(victim.position if victim != null else level.layout.patch_center + Vector3(1.5, -1.8, 0.0))
	await frames(6)
	var thrown_before: int = level.grenades.thrown
	kills_before = level.stats.kills
	game.hud.touch_down(2, game.hud.grenade_button.center())
	game.hud.touch_up(2)
	check(level.grenades.thrown == thrown_before + 1, "the grenade button throws a grenade")
	waited_frames = 0
	while level.grenades.detonated < 1 and waited_frames < 900:
		await get_tree().physics_frame
		waited_frames += 1
	await shot("12-grenade-blast")
	check(level.grenades.detonated >= 1, "the grenade goes off")
	notes["grenade_kills"] = level.stats.kills - kills_before
	notes["blast_kills"] = level.stats.blast_kills
	check(level.defender.weapon_index == 0, "the machine gun is back in hand")
	# Half a second on: the fire is out, the smoke is rising and the ground is marked.
	waited_frames = 0
	while level.explosions.burning() > 0 and waited_frames < 300:
		await get_tree().physics_frame
		waited_frames += 1
	await shot("13-grenade-aftermath")
	await frames(2)


	# The patched breach on the left arm.
	level.defender.aim.set_aim(-33.0, -7.0)
	simulate(8.0)
	await frames(8)
	await shot("14-wall-patch")
	notes["render"] = Graphics.snapshot()

	# Looking down the avenue.
	level.defender.aim.set_aim(0.0, -2.5)
	await frames(6)
	await shot("15-avenue")

	game.pause()
	await frames(3)
	check(get_tree().paused, "pause stops the tree")
	await shot("16-pause", "screen")
	game.resume()
	await frames(2)

	# The tougher kinds. Staged, so the pictures do not depend on playing eight
	# waves under a software renderer: the waves stop and whoever is left is put down.
	level.director.stop()
	for zombie: Zombie in level.horde.active.duplicate():
		if zombie.alive:
			zombie.kill()
	simulate(8.0)
	await _line_up()

	# Then the boss is sent at the gate with two brutes and a pack of runners.
	# The gate is put back to full strength, so the scene does not depend on how the first wave went.
	check(not level.defense.gate_destroyed, "the gate has stood through the first wave")
	level.defense.gate_health = level.defense.data.gate_max_health
	Events.gate_damaged.emit(0.0, level.defense.gate_health, level.defense.data.gate_max_health)
	var boss: Zombie = level.horde.spawn(&"boss", "ring_right", "gate")
	check(boss != null and level.horde.boss == boss, "the boss takes the field")
	# Brutes walk faster than the boss: they set out late enough to reach the gate just behind it.
	var brute_speed: float = (level.horde.types[&"brute"] as ZombieData).speed
	var way: float = 0.0
	for index: int in range(1, boss.path.size()):
		way += boss.path[index - 1].distance_to(boss.path[index])
	var head_start: float = way * (1.0 - boss.speed / brute_speed) + 4.0
	var brutes: Array[Zombie] = []
	var waited: float = 0.0
	while waited < 200.0 and boss.position.z < -41.0 and not level.defense.gate_destroyed:
		simulate(0.5)
		waited += 0.5
		if brutes.is_empty() and waited * boss.speed >= head_start:
			brutes.append(level.horde.spawn(&"brute", "ring_right", "gate"))
			brutes.append(level.horde.spawn(&"brute", "ring_right", "gate"))
	_aim_at(boss.position + Vector3(0.0, 1.8, 0.0))
	await frames(8)
	check(game.hud.boss_meter.visible, "the HUD shows the boss's health")
	await shot("18-boss-in-the-court", "staged")
	var pack: bool = false
	var gathered: bool = false
	while waited < 320.0 and not gathered and not level.defense.gate_destroyed:
		simulate(0.5)
		waited += 0.5
		# Runners cover the same ground in a quarter of the time: they are let loose when the boss is nearly there.
		if not pack and boss.position.distance_to(level.layout.gate_center) < 15.0:
			pack = true
			for index: int in 5:
				level.horde.spawn(&"runner", "ring_right", "gate")
		gathered = boss.state == Zombie.State.ATTACK and brutes.size() == 2 \
			and brutes[0].state == Zombie.State.ATTACK and brutes[1].state == Zombie.State.ATTACK
	check(boss.state == Zombie.State.ATTACK and boss.slot != null and boss.slot.line == "gate", "the boss reaches the gate and strikes it")
	check(boss.slot != null and boss.slot.members.size() == 3 and absf(boss.position.z - level.layout.gate_center.z) < 1.1,
		"it holds the three middle places of the gate")
	var flanking: int = 0
	for brute: Zombie in brutes:
		if brute.state == Zombie.State.ATTACK and brute.slot != null and brute.slot.line == "gate" and brute.slot.members.size() == 2:
			flanking += 1
	check(flanking == 2, "a brute strikes the gate on either side of it")
	check(not level.defense.gate_destroyed, "the gate is still standing when they have gathered")
	notes["boss_reached_gate_after_s"] = waited
	notes["attackers_with_boss"] = level.horde.attackers("gate")
	notes["gate_left_with_boss"] = snappedf(level.defense.gate_fraction(), 0.01)
	simulate(1.0)
	_aim_at(boss.position + Vector3(0.0, 1.6, 0.0))
	await frames(8)
	await shot("19-boss-at-the-gate", "staged")

	# Let them through: the gate falls, then the wall.
	level.defender.aim.set_aim(40.0, -8.5)
	waited = 0.0
	while not level.defense.gate_destroyed and waited < 400.0:
		simulate(1.0)
		waited += 1.0
	check(level.defense.gate_destroyed, "the gate falls when left alone")
	notes["gate_fell_after_s"] = waited
	await frames(40)
	await shot("20-gate-down", "staged")
	waited = 0.0
	while not level.over and waited < 400.0:
		simulate(1.0)
		waited += 1.0
		# Everyone who was at the gate is through and the wall still stands: the next lot comes down the street.
		if level.horde.alive_count() == 0 and not level.over:
			for index: int in 6:
				level.horde.spawn(&"brute" if index < 2 else &"walker", "ring_right", "gate")
	check(level.defense.breached, "the wall is breached when left alone")
	notes["wall_fell_after_s"] = waited
	level.defender.aim.set_aim(-33.0, -7.0)
	# The patch takes a moment to come down, and a few seconds later the result screen covers the view.
	var guard: int = 0
	while game.mode != 3 and guard < 12:
		await frames(1)
		guard += 1
	check(game.mode != 3, "the breach is in view before the result screen covers it")
	await shot("21-wall-breached", "staged")
	guard = 0
	while game.mode != 3 and guard < 1500:
		await frames(1)
		guard += 1
	check(game.mode == 3, "the result screen follows the breach")
	await frames(4)
	check(game.menus.screen == "result" and not game.menus.result_victory, "it reports a defeat")
	notes["defeat_time_s"] = snappedf(float(game.menus.result_stats.get("time", 0.0)), 0.1)
	await shot("22-defeat", "staged")
	var preview: Dictionary = _victory_figures()
	notes["victory_preview"] = preview
	game.menus.show_result(true, preview, true)
	await frames(3)
	await shot("23-victory-preview", "preview")
	game.to_menu()
	await frames(6)
	check(game.menus.screen == "main", "MAIN MENU returns to the title")

	await _other_screens()

	var by_kind: Dictionary = {}
	for kind: String in KINDS:
		by_kind[kind] = []
	for file_name: String in shots:
		(by_kind[kinds[file_name]] as Array).append(file_name)
	var report: Dictionary = {
		"passed": failures.is_empty(), "checks": checks, "failures": failures, "screenshots": shots, "kinds": by_kind, "notes": notes,
		"kinds_explained": {
			"screen": "a menu of the real game, opened by the driver",
			"play": "the real game; between pictures the siege is advanced without drawing",
			"slowed": "the real game with the clock slowed for the capture",
			"staged": "zombies or damage placed by the driver; what follows is the game's own doing",
			"preview": "a screen shown with figures the driver made up",
		},
		"renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info().string,
		"scope": "Software-rendered desktop run of the real game; not an Android device run",
	}
	var file := FileAccess.open(OUT + "smoke-report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("LASTWALL_SMOKE_REPORT " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
