class_name BattleController
extends Node3D
## Composition root for one mission. Rules, weapons, projectiles and UI stay separate.
signal telemetry_changed(data: Dictionary)
signal notice(message: String)
var mission: MissionData
var active_on_ready: bool = false
var active: bool = false
var battlefield: DesertBattlefield
var effects: EffectPool
var projectiles: ProjectilePool
var combat: CombatCoordinator
var artillery: ArtilleryController
var targeting: TargetingSystem
var cameras: ArtilleryCameraRig
var missions: MissionManager
var loadout: WeaponLoadout
var selected_target: EnemyTarget
var prediction_ammo: AmmunitionData
var telemetry_clock: float = 0.0
var return_fire: ReturnFire
var auto_reload_delay: float = -1.0

func _ready() -> void:
	if mission == null:
		mission = load("res://resources/missions/sr01.tres")
	effects = EffectPool.new()
	add_child(effects)
	battlefield = load("res://scenes/battlefield/battlefield.tscn").instantiate()
	add_child(battlefield)
	battlefield.configure_mission(mission)
	projectiles = ProjectilePool.new()
	add_child(projectiles)
	projectiles.impact.connect(_on_impact)
	combat = CombatCoordinator.new()
	combat.effects = effects
	add_child(combat)
	combat.damage_dealt.connect(_on_damage)
	artillery = ArtilleryController.new()
	artillery.position = Vector3(0, 2.0, 105)
	add_child(artillery)
	var weapon: WeaponData = load("res://resources/weapons/kestrel.tres")
	artillery.configure(weapon)
	var ammunition: Array[AmmunitionData] = [load("res://resources/ammunition/he.tres"), load("res://resources/ammunition/ap.tres")]
	loadout = WeaponLoadout.new(weapon, ammunition, mission.ammunition, Profile.data.upgrades)
	_update_prediction_ammo()
	targeting = TargetingSystem.new()
	artillery.add_child(targeting)
	artillery.fired.connect(_on_fired)
	artillery.state_changed.connect(func(state): Events.weapon_state_changed.emit(state))
	cameras = ArtilleryCameraRig.new()
	add_child(cameras)
	cameras.controller = artillery
	cameras.projectiles = projectiles
	cameras.targeting = targeting
	missions = MissionManager.new()
	add_child(missions)
	missions.finished.connect(_on_mission_finished)
	missions.objective_changed.connect(func(done, total): Events.objective_changed.emit(done, total))
	return_fire = ReturnFire.new()
	return_fire.effects = effects
	return_fire.battery_position = artillery.global_position
	add_child(return_fire)
	return_fire.set_shooters(battlefield.targets)
	return_fire.battery_hit.connect(_on_battery_hit)
	return_fire.battery_destroyed.connect(_on_battery_destroyed)
	for target in battlefield.targets:
		target.destroyed.connect(_on_target_destroyed)
	for object in battlefield.destructibles:
		object.broken.connect(_on_object_broken)
	select_target(_first_required_target())
	if active_on_ready:
		activate()
	else:
		for target in battlefield.targets:
			target.set_physics_process(false)

func activate() -> void:
	active = true
	return_fire.enabled = true
	missions.begin(mission)
	for target in battlefield.targets:
		target.set_physics_process(true)
	notice.emit(Loc.t("notice_intro"))

func _first_required_target() -> String:
	for id in mission.target_ids:
		for target in battlefield.targets:
			if target.target_id == id and not target.health.is_destroyed:
				return id
	return "t01"

func _update_prediction_ammo() -> void:
	prediction_ammo = loadout.current_ammo().duplicate()
	prediction_ammo.air_resistance = effective_drag()
	artillery.set_meta("selected_ammo", prediction_ammo)
	artillery.set_meta("muzzle_velocity", loadout.velocity() / prediction_ammo.velocity_multiplier)
	if targeting:
		targeting.invalidate()

func effective_drag() -> float:
	return 0.018 if Profile.data.settings.advanced_drag else loadout.current_ammo().air_resistance

func _process(delta: float) -> void:
	if loadout == null:
		return
	prediction_ammo.air_resistance = effective_drag()
	artillery.set_meta("muzzle_velocity", loadout.velocity() / prediction_ammo.velocity_multiplier)
	if active:
		missions.tick(delta)
		var keyboard := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			keyboard.x -= 24.0 * delta
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			keyboard.x += 24.0 * delta
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			keyboard.y += 18.0 * delta
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			keyboard.y -= 18.0 * delta
		if keyboard.length_squared() > 0.0:
			artillery.adjust(keyboard.x, keyboard.y)
		if auto_reload_delay >= 0.0:
			auto_reload_delay -= delta
			if auto_reload_delay <= 0.0 and Profile.data.settings.auto_reload:
				reload()
		missions.check_ammunition(loadout.total_remaining() == 0, projectiles.active_count() > 0, artillery.reload_remaining > 0.0)
	telemetry_clock += delta
	if telemetry_clock >= 0.10:
		telemetry_clock = 0.0
		telemetry_changed.emit(telemetry())

func telemetry() -> Dictionary:
	var target_health: float = 0.0
	var target_name: String = Loc.t("no_target")
	var distance: float = 0.0
	if is_instance_valid(selected_target):
		target_health = selected_target.health.current / selected_target.health.maximum
		target_name = selected_target.data.display_name
		distance = artillery.global_position.distance_to(selected_target.global_position)
	return {"yaw": artillery.yaw_degrees, "elevation": artillery.elevation_degrees,
		"state": "READY" if artillery.can_fire() else ("RELOADING" if artillery.reload_remaining > 0.0 else "EMPTY"),
		"reload": 1.0 - artillery.reload_remaining / maxf(0.01, artillery.reload_duration),
		"ammo": loadout.counts.duplicate(), "selected_ammo": loadout.selected,
		"remaining": loadout.total_remaining(), "objectives": missions.destroyed_ids.size(),
		"required": mission.target_ids.size(), "time": missions.elapsed, "accuracy": missions.accuracy(),
		"target_name": target_name, "target_health": target_health, "target_distance": distance,
		"predicted_range": artillery.global_position.distance_to(targeting.predicted_impact) if targeting.prediction_valid else 0.0,
		"flight_time": targeting.predicted_time, "camera": cameras.mode_name(), "shots": missions.shots,
		"battery": return_fire.health_ratio()}

func aim_drag(pixels: Vector2) -> void:
	if active:
		artillery.aim(pixels, float(Profile.data.settings.sensitivity))
		targeting.invalidate()

func select_target(id: String) -> void:
	for target in battlefield.targets:
		if target.target_id == id and not target.health.is_destroyed:
			selected_target = target
			return

func cycle_target() -> void:
	var candidates: Array[EnemyTarget] = []
	for target in battlefield.targets:
		if target.required and not target.health.is_destroyed:
			candidates.append(target)
	if candidates.is_empty():
		for target in battlefield.targets:
			if not target.health.is_destroyed:
				candidates.append(target)
	if not candidates.is_empty():
		var index: int = candidates.find(selected_target)
		selected_target = candidates[(index + 1) % candidates.size()]
		notice.emit(Loc.t("notice_acquired") % selected_target.data.display_name)

func compute_solution() -> bool:
	if not active:
		return false
	if not is_instance_valid(selected_target) or selected_target.health.is_destroyed:
		cycle_target()
	if not is_instance_valid(selected_target) or selected_target.health.is_destroyed:
		return false
	var result: Dictionary = {}
	var flight_estimate: float = 0.0
	for iteration in range(5):
		var aim_point: Vector3 = selected_target.predict_position(flight_estimate)
		result = targeting.solve(artillery.muzzle_position(), aim_point, loadout.velocity(), effective_drag())
		if not result.valid or not artillery.set_solution(result.yaw, result.elevation):
			notice.emit(Loc.t("notice_limits"))
			return false
		flight_estimate = float(result.flight_time)
	targeting.invalidate()
	notice.emit(Loc.t("notice_solution") % [Loc.decimal(result.elevation), Loc.decimal(result.flight_time)])
	return true

func select_ammunition(id: String) -> void:
	if loadout.select(id):
		_update_prediction_ammo()
		Sound.play_ui()
	else:
		notice.emit(Loc.t("notice_incompatible"))

func fire() -> bool:
	if not active or not missions.active:
		return false
	if projectiles.active_count() >= ProjectilePool.CAPACITY:
		notice.emit(Loc.t("notice_fire_limit"))
		return false
	if not artillery.can_fire():
		notice.emit(Loc.t("notice_breech"))
		return false
	if int(loadout.counts.get(loadout.selected, 0)) <= 0:
		notice.emit(Loc.t("notice_select_ammo"))
		return false
	var ammo: AmmunitionData = loadout.consume()
	if ammo == null:
		return false
	ammo = ammo.duplicate()
	ammo.air_resistance = effective_drag()
	artillery.data.accuracy_degrees = loadout.dispersion()
	auto_reload_delay = 0.65
	return artillery.fire(ammo)

func reload() -> bool:
	if not active or artillery.loaded or artillery.reload_remaining > 0.0:
		return false
	if int(loadout.counts.get(loadout.selected, 0)) <= 0:
		notice.emit(Loc.t("notice_no_rounds"))
		return false
	auto_reload_delay = -1.0
	var started: bool = artillery.begin_reload(loadout.reload_seconds())
	if started:
		Sound.play_at("reload", artillery.global_position, -5.0)
	return started

func _on_fired(origin: Vector3, direction: Vector3, ammo: AmmunitionData) -> void:
	var id: int = missions.register_shot() if missions.active else 0
	projectiles.launch(origin, direction * loadout.velocity(), ammo, loadout.damage_multiplier(), id)
	effects.explode(origin, direction, 3.0, TerrainSampler.height_at(origin.x, origin.z), true)
	Sound.play_at("cannon", origin, -1.0)
	targeting.invalidate()

func _on_impact(point: Vector3, normal: Vector3, collider: Object, ammo: AmmunitionData, multiplier: float, shot_id: int) -> void:
	combat.resolve_impact(point, normal, collider, ammo, multiplier, shot_id)
	targeting.invalidate()

func _on_damage(target_id: String, amount: float, direct: bool, shot_id: int) -> void:
	missions.register_damage(target_id, shot_id, amount)
	if amount > 0.0 and direct:
		notice.emit(Loc.t("notice_direct") % Loc.number(roundi(amount)))

func _on_target_destroyed(target: EnemyTarget) -> void:
	missions.register_destroyed(target.target_id)
	notice.emit(Loc.t("notice_neutralized") % target.data.display_name)
	if selected_target == target:
		cycle_target()

func _on_object_broken(id: String, _point: Vector3) -> void:
	missions.register_destroyed(id)
	if id == mission.optional_crate_id:
		notice.emit(Loc.t("notice_optional"))

func _on_battery_hit(ratio: float, _point: Vector3) -> void:
	notice.emit(Loc.t("notice_battery_hit") % Loc.number(roundi(ratio * 100.0)))

func _on_battery_destroyed() -> void:
	notice.emit(Loc.t("notice_battery_lost"))
	if missions.active:
		missions.finish(false, "reason_battery")

func _on_mission_finished(result: Dictionary) -> void:
	active = false
	return_fire.enabled = false
	Events.mission_finished.emit(result)

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: fire()
		KEY_R: reload()
		KEY_Z: cameras.toggle_zoom()
		KEY_C: cameras.cycle()
		KEY_TAB: cycle_target()
		KEY_F: compute_solution()
		KEY_1: select_ammunition("he")
		KEY_2: select_ammunition("ap")
