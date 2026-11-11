extends Node
## Self-driving run of the real game for CI: plays through menu, combat with
## every weapon, the gate falling and the defeat screen, saving a screenshot
## at each step and a JSON report. Started with `-- --smoke`; never part of an exported build.

const OUT: String = "res://documentation/qa/"

var game: Node
var level: CityLevel
var failures: Array[String] = []
var shots: Array[String] = []
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


func shot(shot_name: String) -> void:
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
	print("SMOKE shot ", shot_name, " ", image.get_size())


## Advances the siege without rendering, to reach a moment worth looking at.
func simulate(seconds: float, step: float = 1.0 / 30.0) -> void:
	var left: float = seconds
	while left > 0.0 and not level.over:
		var delta: float = minf(step, left)
		level.director._physics_process(delta)
		level.horde._physics_process(delta)
		level.defense._physics_process(delta)
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


func _aim_at(point: Vector3) -> void:
	var wanted: Vector2 = level.defender.aim_for(point)
	level.defender.aim.set_aim(wanted.x, wanted.y)


func _run() -> void:
	await frames(8)
	check(game.menus.screen == "main", "the game opens on the main menu")
	await shot("01-menu-fa")
	Profile.set_setting("language", "en")
	await frames(3)
	await shot("02-menu-en")
	game.menus.show_settings("main")
	await frames(3)
	await shot("03-settings-en")
	Profile.set_setting("language", "fa")
	await frames(3)
	await shot("04-settings-fa")
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
	game.hud.touch_down(0, game.hud.fire_button.center())
	for index: int in 14:
		await get_tree().physics_frame
	await shot("08-gate-firing")
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
	await _physics_frames(4)
	await shot("10-rocket-away")
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
	await shot("16-pause")
	game.resume()
	await frames(2)

	# Let the horde through: the gate falls, then the wall.
	level.defender.aim.set_aim(40.0, -8.5)
	var waited: float = 0.0
	while not level.defense.gate_destroyed and waited < 400.0:
		simulate(1.0)
		waited += 1.0
	check(level.defense.gate_destroyed, "the gate falls when left alone")
	notes["gate_fell_after_s"] = waited
	await frames(40)
	await shot("17-gate-down")
	waited = 0.0
	while not level.over and waited < 400.0:
		simulate(1.0)
		waited += 1.0
	check(level.defense.breached, "the wall is breached when left alone")
	level.defender.aim.set_aim(-33.0, -7.0)
	await frames(30)
	await shot("18-wall-breached")
	var guard: int = 0
	while game.mode != 3 and guard < 1500:
		await frames(1)
		guard += 1
	check(game.mode == 3, "the result screen follows the breach")
	await frames(4)
	await shot("19-defeat")
	game.menus.show_result(true, {"waves_cleared": 5, "waves_total": 5, "kills": 202, "headshots": 61, "accuracy": 0.47, "time": 412.0,
		"wall_left": 0.82})
	await frames(3)
	await shot("20-victory-preview")
	game.to_menu()
	await frames(6)
	check(game.menus.screen == "main", "MAIN MENU returns to the title")

	var report: Dictionary = {
		"passed": failures.is_empty(), "checks": checks, "failures": failures, "screenshots": shots, "notes": notes,
		"renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info().string,
		"scope": "Software-rendered desktop run of the real game; not an Android device run",
	}
	var file := FileAccess.open(OUT + "smoke-report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("LASTWALL_SMOKE_REPORT " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
