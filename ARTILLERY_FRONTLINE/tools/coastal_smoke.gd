extends Node
## Software-rendered coastal milestone smoke driver. Not Android device certification.
var game: Node
var checks: Array[Dictionary] = []
var failures: int = 0
var output: String = "res://documentation/qa"

func _ready() -> void:
	call_deferred("run")

func check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})
	if not passed:
		failures += 1
		push_error("COASTAL SMOKE FAIL: " + name)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(output + "/" + name + ".png")
	check("capture " + name, error == OK and image.get_width() > 500)

func run() -> void:
	Engine.max_physics_steps_per_frame = 32
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Profile.data.settings.quality = "high"
	Graphics.apply_preference()
	game.start_coastal_milestone()
	await get_tree().create_timer(1.6).timeout
	var coastal: CoastalController = game.coastal
	check("coastal scene initialized", coastal != null and coastal.battlefield != null)
	check("at least 8 animated soldiers", coastal.soldiers.size() >= 8)
	check("landing craft present", coastal.craft != null)
	check("mobile HUD present", coastal.hud != null and coastal.hud.root.visible)
	await capture("coastal-beach")
	Profile.data.settings.quality = "low"
	Graphics.apply_preference()
	await get_tree().create_timer(0.6).timeout
	var soldier: EnemySoldier = coastal.soldiers[0]
	var before: Vector3 = soldier.global_position
	await get_tree().create_timer(0.8).timeout
	check("soldiers advance toward objectives", soldier.global_position.distance_to(before) > 0.05 or soldier.is_dead())
	var craft_before: float = coastal.craft.progress
	await get_tree().create_timer(0.8).timeout
	check("amphibious craft moves", coastal.craft.progress > craft_before)
	var yaw_before: float = coastal.yaw_target
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(140, -36)
	coastal._unhandled_input(drag)
	await get_tree().create_timer(0.3).timeout
	check("touch drag aims weapon", not is_equal_approx(yaw_before, coastal.yaw_target))
	var ammo_before: int = coastal.weapon.ammo
	check("manual fire works", coastal.fire_once() and coastal.weapon.ammo == ammo_before - 1)
	await capture("coastal-fire")
	coastal.set_auto_fire(true)
	var auto_before: int = coastal.weapon.ammo
	await get_tree().create_timer(0.9).timeout
	coastal.set_auto_fire(false)
	check("automatic fire consumes ammunition", coastal.weapon.ammo < auto_before)
	coastal.weapon.ammo = maxi(0, coastal.weapon.ammo)
	check("reload starts", coastal.weapon.start_reload())
	await get_tree().create_timer(3.0).timeout
	check("reload completes", coastal.weapon.ammo == int(coastal.weapon.config().magazine))
	coastal.weapon.select("rocket")
	check("rocket weapon selectable", coastal.weapon.weapon_id == "rocket")
	var explosion_point: Vector3 = coastal.soldiers[1].global_position if coastal.soldiers.size() > 1 else Vector3(0, 0, 0)
	coastal._explode(explosion_point, Vector3.UP, 8.0)
	await get_tree().create_timer(0.4).timeout
	check("explosion effects active", coastal.effects.active_count() > 0)
	await capture("coastal-explosion")
	coastal.use_support("repair")
	check("repair support functions", coastal.player_health >= 100.0 or float(coastal.support_timers.repair) > 0.0)
	var report: Dictionary = {"scope": "Desktop Godot 4.7.2 Compatibility renderer under Xvfb/llvmpipe; not Android hardware", "checks": checks, "failures": failures, "passed": failures == 0, "performance": Graphics.snapshot(), "soldiers": coastal.soldiers.size(), "kills": coastal.kills}
	var file: FileAccess = FileAccess.open(output + "/coastal-smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COASTAL_SMOKE_REPORT ", JSON.stringify(report))
	Sound.stop_all()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if failures == 0 else 1)
