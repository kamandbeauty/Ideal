extends Node
## Software-rendered coastal milestone smoke driver. Not Android device certification.
var game: Node
var checks: Array[Dictionary] = []
var failures: int = 0
var output: String = "user://qa" if OS.has_feature("android") else "res://documentation/qa"

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
	check("destructible tank present", coastal.vehicles.size() >= 1)
	check("hostile aircraft present", coastal.aircraft.size() >= 1)
	check("landing craft present", coastal.crafts.size() >= 1)
	check("mobile HUD present", coastal.hud != null and coastal.hud.root.visible)
	var bounds: Rect2 = coastal.weapon.screen_bounds(coastal.camera)
	var height: float = get_viewport().get_visible_rect().size.y
	check("weapon stays in lower foreground", bounds.position.y > height * 0.35)
	var muzzles_forward: bool = true
	for muzzle in coastal.weapon.muzzles:
		muzzles_forward = muzzles_forward and coastal.weapon.to_local(muzzle.global_position).z < -1.0
	check("muzzles point away from camera", muzzles_forward)
	await capture("coastal-beach")
	Profile.data.settings.quality = "low"
	Graphics.apply_preference()
	await get_tree().create_timer(0.6).timeout
	var soldier: EnemySoldier = coastal.soldiers[0]
	var before: Vector3 = soldier.global_position
	await get_tree().create_timer(0.8).timeout
	check("soldiers advance toward objectives", soldier.global_position.distance_to(before) > 0.05 or soldier.is_dead())
	var craft_before: float = coastal.crafts[0].progress
	await get_tree().create_timer(0.8).timeout
	check("amphibious craft moves", coastal.crafts[0].progress > craft_before or coastal.crafts[0].is_dead())
	var anchor: Vector3 = coastal.aim_yaw.global_position
	var yaw_before: float = coastal.yaw_target
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(140, -36)
	coastal._unhandled_input(drag)
	await get_tree().create_timer(0.3).timeout
	check("touch drag aims weapon", not is_equal_approx(yaw_before, coastal.yaw_target))
	check("player position is fixed", coastal.aim_yaw.global_position.is_equal_approx(anchor))
	var ammo_before: int = coastal.weapon.ammo
	coastal.hud.fire_button.button_down.emit()
	await get_tree().create_timer(0.25).timeout
	coastal.hud.fire_button.button_up.emit()
	check("HUD fire button fires weapon", coastal.weapon.ammo < ammo_before)
	await capture("coastal-fire")
	coastal.set_auto_fire(true)
	var auto_before: int = coastal.weapon.ammo
	await get_tree().create_timer(0.9).timeout
	coastal.set_auto_fire(false)
	check("automatic fire consumes ammunition", coastal.weapon.ammo < auto_before)
	check("reload starts", coastal.weapon.start_reload())
	await get_tree().create_timer(3.0).timeout
	check("reload completes", coastal.weapon.ammo == int(coastal.weapon.config().magazine))
	var tank: EnemyVehicle = coastal.vehicles[0]
	coastal.aim_at(tank.global_position + Vector3.UP * 1.4)
	await get_tree().create_timer(0.5).timeout
	coastal.weapon.select("rocket")
	coastal.weapon.cooldown = 0.0
	check("rocket weapon selectable and fires", coastal.weapon.weapon_id == "rocket" and coastal.fire_once())
	await get_tree().create_timer(2.0).timeout
	check("rocket reaches and damages armor", tank.is_dead() or tank.health < tank.max_health)
	coastal.weapon.select("bazooka")
	check("bazooka weapon selectable", coastal.weapon.weapon_id == "bazooka")
	coastal.use_support("airstrike")
	check("airstrike available in first round", coastal.airstrike_queue.size() > 0 and int(coastal.support_charges.airstrike) == 1)
	await get_tree().create_timer(2.2).timeout
	check("airstrike explosions active", coastal.effects.active_count() > 0)
	await capture("coastal-explosion")
	check("emplacement survives the smoke engagement", coastal.active and coastal.player_health > 0.0)
	var health_before: float = coastal.player_health
	coastal._damage_player(600.0)
	coastal.use_support("repair")
	check("repair works independently of airstrike cooldown", coastal.player_health >= minf(CoastalController.MAX_HEALTH, health_before - 600.0 + 900.0) - 1.0 and float(coastal.support_timers.repair) > 0.0)
	coastal._finish(true)
	await get_tree().create_timer(0.3).timeout
	check("mission results panel appears", coastal.hud.result_panel.visible)
	await capture("coastal-results")
	var report: Dictionary = {"scope": "Desktop Godot 4.7.2 Compatibility renderer under Xvfb/llvmpipe; not Android hardware", "checks": checks, "failures": failures, "passed": failures == 0, "performance": Graphics.snapshot(), "soldiers": coastal.soldiers.size(), "kills": coastal.kills, "weapon_screen_bounds": {"x": bounds.position.x, "y": bounds.position.y, "w": bounds.size.x, "h": bounds.size.y}}
	var file: FileAccess = FileAccess.open(output + "/coastal-smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COASTAL_SMOKE_REPORT ", JSON.stringify(report))
	Sound.stop_all()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if failures == 0 else 1)
