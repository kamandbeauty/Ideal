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
	# Pose checks measure the idle weapon; default auto-fire would recoil it during the wait.
	game.coastal.set_auto_fire(false)
	await get_tree().create_timer(1.6).timeout
	var coastal: CoastalController = game.coastal
	check("coastal scene initialized", coastal != null and coastal.battlefield != null)
	check("landing craft carries the first wave", coastal.crafts.size() >= 1 and coastal.crafts[0].cargo.size() >= 8)
	var craft_start: float = coastal.crafts[0].progress
	await get_tree().create_timer(0.8).timeout
	check("amphibious craft sails toward the beach", coastal.crafts[0].progress > craft_start or coastal.crafts[0].is_dead())
	# Land the wave now so the infantry, tank and transport checks below have units to drive.
	coastal.disembark_all_now()
	check("at least 8 animated soldiers", coastal.soldiers.size() >= 8)
	check("destructible tank present", coastal.vehicles.size() >= 1)
	check("hostile aircraft present", coastal.aircraft.size() >= 1)
	check("landing craft present", coastal.crafts.size() >= 1)
	check("mobile HUD present", coastal.hud != null and coastal.hud.root.visible)
	var bounds: Rect2 = coastal.weapon.screen_bounds(coastal.camera)
	var height: float = get_viewport().get_visible_rect().size.y
	check("weapon stays in lower foreground", bounds.position.y > height * 0.35)
	var muzzles_forward: bool = true
	var muzzle_band: bool = true
	var width: float = get_viewport().get_visible_rect().size.x
	var muzzle_x: Array[float] = []
	for muzzle in coastal.weapon.muzzles:
		muzzles_forward = muzzles_forward and coastal.weapon.to_local(muzzle.global_position).z < -1.0
		var screen: Vector2 = coastal.camera.unproject_position(muzzle.global_position)
		muzzle_x.append(screen.x)
		muzzle_band = muzzle_band and screen.y > height * 0.42 and screen.y < height * 0.82
	check("muzzles point away from camera", muzzles_forward)
	check("muzzles stay in lower aiming band", muzzle_band)
	check("twin muzzles visually separated", muzzle_x.size() != 2 or absf(muzzle_x[0] - muzzle_x[1]) > width * 0.04)
	check("independent recoil pivots present", coastal.weapon.recoil_nodes.size() >= 1)
	await capture("coastal-beach")
	var focus_soldier: EnemySoldier = coastal.soldiers[0]
	coastal.aim_at(focus_soldier.global_position + Vector3.UP * 1.2)
	coastal.toggle_zoom()
	await get_tree().create_timer(0.7).timeout
	await capture("coastal-infantry")
	coastal.toggle_zoom()
	coastal.aim_yaw.rotation.y = 0.0
	coastal.yaw_target = 0.0
	coastal.yaw_current = 0.0
	coastal.pitch_target = -4.0
	coastal.pitch_current = -4.0
	Profile.data.settings.quality = "low"
	Graphics.apply_preference()
	await get_tree().create_timer(0.6).timeout
	var soldier: EnemySoldier = coastal.soldiers[0]
	var before: Vector3 = soldier.global_position
	# Infantry bound forward and halt to look around, so sample a longer window.
	var advanced: bool = false
	for step in range(28):
		await get_tree().create_timer(0.1).timeout
		advanced = advanced or soldier.global_position.distance_to(before) > 0.5 or soldier.is_dead()
	check("soldiers advance toward objectives", advanced)
	check("landing craft has grounded and released its cargo", coastal.crafts[0].has_arrived and coastal.disembark_queue.is_empty())
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
	coastal.set_auto_fire(false)
	var auto_before: int = coastal.weapon.ammo
	coastal.firing = true
	await get_tree().create_timer(0.9).timeout
	coastal.firing = false
	check("automatic fire consumes ammunition", coastal.weapon.ammo < auto_before)
	check("reload starts", coastal.weapon.start_reload())
	await get_tree().create_timer(1.0).timeout
	await capture("coastal-weapon-reload")
	await get_tree().create_timer(2.2).timeout
	check("reload completes", coastal.weapon.ammo == int(coastal.weapon.config().magazine))
	var tank: EnemyVehicle = coastal.vehicles[0]
	# Isolate the armor target: advancing infantry can otherwise intercept the
	# rocket mid-flight, which tests crowd blocking rather than armor damage.
	var soldier_layers: Array[int] = []
	for unit in coastal.soldiers:
		soldier_layers.append(unit.collision_layer)
		unit.collision_layer = 0
	coastal.aim_at(tank.global_position + Vector3.UP * 1.4)
	await get_tree().create_timer(0.5).timeout
	coastal.weapon.select("rocket")
	coastal.weapon.cooldown = 0.0
	check("rocket weapon selectable and fires", coastal.weapon.weapon_id == "rocket" and coastal.fire_once())
	await get_tree().create_timer(2.0).timeout
	check("rocket reaches and damages armor", tank.is_dead() or tank.health < tank.max_health)
	for index in range(coastal.soldiers.size()):
		coastal.soldiers[index].collision_layer = soldier_layers[index]
	coastal.weapon.select("bazooka")
	check("bazooka weapon selectable", coastal.weapon.weapon_id == "bazooka")
	coastal.use_support("airstrike")
	check("airstrike available in first round", coastal.airstrike_queue.size() > 0 and int(coastal.support_charges.airstrike) == 1)
	await get_tree().create_timer(2.2).timeout
	check("airstrike explosions active", coastal.effects.active_count() > 0)
	await capture("coastal-explosion")
	check("emplacement survives the smoke engagement", coastal.active and coastal.player_health > 0.0)
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	check("coastal fire button is on the physical right", coastal.hud.fire_button.get_global_rect().get_center().x > viewport_rect.size.x * 0.5)
	var health_before: float = coastal.player_health
	coastal._damage_player(600.0)
	check("emplacement armour reduces incoming damage", absf(coastal.player_health - (health_before - 600.0 * CoastalController.DAMAGE_SCALE)) < 0.01)
	coastal.use_support("repair")
	var repaired: float = minf(CoastalController.MAX_HEALTH, health_before - 600.0 * CoastalController.DAMAGE_SCALE + CoastalController.REPAIR_AMOUNT)
	check("repair works independently of airstrike cooldown", absf(coastal.player_health - repaired) < 0.01 and float(coastal.support_timers.repair) > 0.0)
	coastal.hud.set_paused(true)
	await get_tree().create_timer(0.25).timeout
	check("coastal pause panel appears", coastal.hud.pause_panel.visible)
	check("coastal pause covers the full viewport", coastal.hud.pause_panel.get_global_rect().is_equal_approx(viewport_rect))
	check("coastal pause has an opaque backdrop", coastal.hud.pause_panel.get_child(0) is ColorRect and is_equal_approx((coastal.hud.pause_panel.get_child(0) as ColorRect).color.a, 1.0))
	await capture("coastal-pause")
	coastal.hud.set_paused(false)
	await get_tree().create_timer(0.2).timeout
	coastal._finish(true)
	await get_tree().create_timer(0.3).timeout
	check("mission results panel appears", coastal.hud.result_panel.visible)
	check("coastal results cover the full viewport", coastal.hud.result_panel.get_global_rect().is_equal_approx(viewport_rect))
	await capture("coastal-results")
	# Vehicle design preview: the three approved models on the beach, HUD hidden, front facing the camera.
	coastal.hud.root.visible = false
	coastal.hud.result_panel.visible = false
	coastal.hud.pause_panel.visible = false
	var preview := Node3D.new()
	preview.name = "VehiclePreview"
	coastal.add_child(preview)
	var lineup: Array = [[VehicleModels.build_jeep(), -6.0], [VehicleModels.build_apc(), 0.0], [VehicleModels.build_boss_tank(), 6.0]]
	for entry in lineup:
		var model: Node3D = entry[0]
		model.position = Vector3(float(entry[1]), CoastalTerrain.height_at(float(entry[1]), 36.0), 36.0)
		model.rotation.y = PI
		preview.add_child(model)
	coastal.aim_at(Vector3(0.0, 1.5, 36.0))
	await get_tree().create_timer(1.0).timeout
	await capture("vehicle-models")
	var report: Dictionary = {"scope": "Desktop Godot 4.7.2 Compatibility renderer under Xvfb/llvmpipe; art pass 03 skinned infantry/detailed war machines/weapons; not Android hardware", "checks": checks, "failures": failures, "passed": failures == 0, "performance": Graphics.snapshot(), "soldiers": coastal.soldiers.size(), "kills": coastal.kills, "weapon_screen_bounds": {"x": bounds.position.x, "y": bounds.position.y, "w": bounds.size.x, "h": bounds.size.y}}
	var file: FileAccess = FileAccess.open(output + "/coastal-smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COASTAL_SMOKE_REPORT ", JSON.stringify(report))
	Sound.stop_all()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if failures == 0 else 1)
