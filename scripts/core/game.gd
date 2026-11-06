extends Node3D
## Composition root: gameplay state and communication, not physics or rendering logic.

const WEAPON: WeaponConfig = preload("res://resources/weapons/bastion.tres")
const HIGH_EXPLOSIVE: AmmoConfig = preload("res://resources/ammunition/high_explosive.tres")
const ARMOR_PIERCING: AmmoConfig = preload("res://resources/ammunition/armor_piercing.tres")

var battlefield: Battlefield
var gun: Artillery
var projectiles: ProjectilePool
var effects: EffectPool
var preview: TrajectoryPreview
var camera_rig: BattlefieldCamera
var hud: TacticalHUD
var audio: BattlefieldAudio
var graphics: GraphicsController
var mission := MissionState.new()
var save_store := SaveStore.new()
var save_data: Dictionary = {}
var mode: String = "menu"
var _prediction_timer: float = 0.0
var _prediction_dirty: bool = true
var _touch_index: int = -1
var _mouse_aiming: bool = false


func _ready() -> void:
	get_tree().paused = false
	save_data = save_store.load_data()
	battlefield = Battlefield.new()
	add_child(battlefield)
	projectiles = ProjectilePool.new()
	add_child(projectiles)
	projectiles.impacted.connect(_on_impact)
	effects = EffectPool.new()
	add_child(effects)
	audio = BattlefieldAudio.new()
	add_child(audio)
	gun = Artillery.new()
	gun.position = Vector3(0, 0, 44)
	gun.config = WEAPON
	gun.ammo_types = [HIGH_EXPLOSIVE, ARMOR_PIERCING]
	add_child(gun)
	gun.aim_changed.connect(_on_aim_changed)
	gun.fired.connect(_on_fired)
	gun.reload_started.connect(func() -> void: audio.play_sound("reload"))
	_spawn_targets()
	preview = TrajectoryPreview.new()
	add_child(preview)
	camera_rig = BattlefieldCamera.new()
	camera_rig.gun = gun
	camera_rig.preview = preview
	add_child(camera_rig)
	graphics = GraphicsController.new()
	graphics.sun = battlefield.sun
	graphics.detail_group = battlefield.detail_group
	graphics.effect_pool = effects
	add_child(graphics)
	hud = TacticalHUD.new()
	add_child(hud)
	_connect_ui()
	_apply_settings(save_data.settings, false)
	mission.setup(3)
	mission.completed.connect(_on_mission_completed)
	if get_tree().has_meta("frontline_replay"):
		get_tree().remove_meta("frontline_replay")
		_start_mission()


func _spawn_targets() -> void:
	_add_target("RADAR", "T-01  /  RADAR", Vector3(0, 0, -69), 120.0, 0.0)
	_add_target("TANK", "T-02  /  ARMOR", Vector3(-22, 0, -63), 185.0, 5.5)
	_add_target("TRANSPORT", "T-03  /  CONVOY", Vector3(23, 0, -93), 145.0, 7.0)


func _add_target(kind: String, callsign: String, spawn: Vector3, hp: float, patrol: float) -> void:
	var target := BattlefieldTarget.new()
	target.name = kind.capitalize()
	target.target_type = kind
	target.callsign = callsign
	target.position = spawn
	target.max_health = hp
	target.patrol_extent = patrol
	add_child(target)
	target.destroyed.connect(_on_target_destroyed)


func _connect_ui() -> void:
	hud.start_requested.connect(_start_mission)
	hud.pause_requested.connect(_pause_mission)
	hud.resume_requested.connect(_resume_mission)
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_return_to_menu)
	hud.fire_requested.connect(_fire)
	hud.reload_requested.connect(_reload)
	hud.ammo_requested.connect(_select_ammo)
	hud.zoom_requested.connect(_toggle_zoom)
	hud.camera_requested.connect(_toggle_camera)
	hud.settings_changed.connect(_on_settings_changed)
	gun.feedback.connect(hud.show_feedback)


func _process(delta: float) -> void:
	if mode == "active":
		mission.elapsed += delta
		hud.update_status(gun, mission, preview, camera_rig.camera)
		if not gun.state.has_any_rounds() and not _any_projectile_active():
			_finish(false)


func _physics_process(delta: float) -> void:
	_prediction_timer -= delta
	# Refresh while targets patrol even without new input, with a bounded rate.
	if _prediction_timer <= 0.0:
		_prediction_dirty = true
	if _prediction_dirty and _prediction_timer <= 0.0:
		preview.update_prediction(
			get_world_3d().direct_space_state,
			gun.muzzle_position(),
			gun.launch_velocity(),
			gun.config.gravity,
			gun.config.drag
		)
		_prediction_timer = 0.2
		_prediction_dirty = false


func _input(event: InputEvent) -> void:
	# Release even when a drag ends over a button and GUI consumes that release.
	if event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
		_touch_index = -1
	elif (
		event is InputEventMouseButton
		and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		_mouse_aiming = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if mode == "active":
					_pause_mission()
				elif mode == "paused":
					_resume_mission()
			KEY_SPACE:
				_fire()
			KEY_R:
				_reload()
			KEY_Z:
				_toggle_zoom()
			KEY_C:
				_toggle_camera()
			KEY_1:
				_select_ammo(0)
			KEY_2:
				_select_ammo(1)
		return
	if mode != "active":
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		gun.aim_by_pixels(event.relative)
	elif (
		event is InputEventMouseButton
		and event.device != InputEvent.DEVICE_ID_EMULATION
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		_mouse_aiming = event.pressed
	elif (
		event is InputEventMouseMotion
		and event.device != InputEvent.DEVICE_ID_EMULATION
		and _mouse_aiming
	):
		gun.aim_by_pixels(event.relative)


func _start_mission() -> void:
	mode = "active"
	get_tree().paused = false
	hud.show_gameplay()
	hud.show_feedback("DRAG TO AIM  /  DESTROY THREE TARGETS")


func _pause_mission() -> void:
	if mode != "active":
		return
	mode = "paused"
	_touch_index = -1
	_mouse_aiming = false
	hud.show_pause()
	get_tree().paused = true


func _resume_mission() -> void:
	if mode != "paused":
		return
	get_tree().paused = false
	mode = "active"
	hud.show_gameplay()


func _restart() -> void:
	get_tree().paused = false
	get_tree().set_meta("frontline_replay", true)
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _fire() -> void:
	if mode == "active":
		gun.try_fire()


func _reload() -> void:
	if mode == "active":
		gun.reload_weapon()


func _select_ammo(index: int) -> void:
	if mode == "active":
		gun.select_ammo(index)


func _toggle_zoom() -> void:
	if mode == "active":
		camera_rig.toggle_zoom()
		hud.set_camera_labels(camera_rig.zoomed, camera_rig.track_shell)


func _toggle_camera() -> void:
	if mode == "active":
		camera_rig.toggle_camera()
		hud.set_camera_labels(camera_rig.zoomed, camera_rig.track_shell)


func _on_aim_changed() -> void:
	_prediction_dirty = true


func _on_fired(origin: Vector3, velocity: Vector3, ammo: AmmoConfig) -> void:
	mission.record_shot()
	var shell := projectiles.spawn(origin, velocity, ammo, gun.config.gravity, gun.config.drag)
	if shell == null:
		hud.show_feedback("SHELL CAPACITY REACHED")
		return
	camera_rig.set_projectile(shell)
	camera_rig.shake(1.0)
	audio.play_sound("fire")
	hud.show_feedback("ROUND AWAY  /  RELOAD")


func _on_impact(point: Vector3, collider: Object, ammo: AmmoConfig) -> void:
	effects.explode(point)
	audio.play_sound("impact")
	camera_rig.shake(0.65)
	var pending: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("damageable"):
		var target := node as BattlefieldTarget
		if target == null or target.is_destroyed:
			continue
		var damage := DamageModel.blast_damage(
			ammo.damage,
			ammo.blast_radius,
			point.distance_to(target.damage_center()),
			collider == target
		)
		if damage > 0.0:
			pending.append({"target": target, "damage": damage})
	if not pending.is_empty():
		# Record once per shell, before the last kill triggers mission completion.
		mission.record_hit()
		for item in pending:
			var target: BattlefieldTarget = item.target
			target.receive_damage(item.damage)
		if mode == "active":
			hud.show_feedback("TARGET HIT")
	elif mode == "active":
		hud.show_feedback("IMPACT  /  ADJUST FIRE")
	_prediction_dirty = true


func _on_target_destroyed(target: BattlefieldTarget) -> void:
	mission.target_destroyed(target.get_instance_id())


func _on_mission_completed() -> void:
	_finish(true)


func _finish(success: bool) -> void:
	if mode != "active":
		return
	mode = "finishing"
	var stars := mission.rating() if success else 0
	if success:
		var saved_record: Variant = save_data.records.get("dustline", {})
		var previous: Dictionary = saved_record if saved_record is Dictionary else {}
		var previous_time := float(previous.get("best_time", 0.0))
		save_data.records.dustline = {
			"completed": true,
			"best_stars": maxi(int(previous.get("best_stars", 0)), stars),
			"best_time":
			mission.elapsed if previous_time <= 0.0 else minf(previous_time, mission.elapsed),
		}
		if not save_store.save_data(save_data):
			push_warning("Could not save mission record")
	# Let the final explosion read before presenting the results.
	await get_tree().create_timer(1.3).timeout
	if not is_inside_tree():
		return
	mode = "results"
	hud.show_results(
		success,
		stars,
		mission.destroyed_ids.size(),
		mission.total_targets,
		mission.shots_fired,
		mission.hits,
		mission.elapsed
	)
	get_tree().paused = true


func _any_projectile_active() -> bool:
	for projectile in projectiles.projectiles:
		if projectile.active:
			return true
	return false


func _on_settings_changed(settings: Dictionary) -> void:
	_apply_settings(settings, true)


func _apply_settings(settings: Dictionary, persist: bool) -> void:
	save_data.settings = settings.duplicate(true)
	gun.sensitivity = float(settings.get("sensitivity", 1.0))
	audio.enabled = bool(settings.get("sound", true))
	graphics.configure(str(settings.get("graphics", "AUTO")), int(settings.get("target_fps", 60)))
	hud.set_settings(settings)
	if persist and not save_store.save_data(save_data):
		hud.show_feedback("SETTINGS COULD NOT BE SAVED")
