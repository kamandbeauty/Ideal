extends Node3D
## One run of the game: the island, the camera, the waves and the economy.
##
## The scene is assembled in code from LevelData so the map, the pads and the
## path always match.

signal exit_requested
signal retry_requested

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const PICK_MASK := 2
const TAP_MAX_MOVE := 16.0
const TAP_MAX_TIME := 0.45
const ORBIT_SPEED := 0.008

var state: GameState
var _hud
var _rig: CameraRig
var _pads: Array[BuildPad] = []
var _enemies: Array[Enemy] = []
var _selected_pad: BuildPad
var _selected_tower: Tower

var _wave_schedule: Array = []
var _wave_timer := 0.0
var _spawn_cursor := 0
var _wave_active := false
var _prepare_running := false
var _prepare_timer := 0.0
var _game_over := false
var _paused := false
var _speed := 1

var _touches: Dictionary = {}
var _tap_start := Vector2.ZERO
var _tap_time := 0.0
var _dragging := false
var _pinch_distance := 0.0
var _mouse_down := false


func _ready() -> void:
	Engine.time_scale = 1.0
	state = GameState.new()
	var built := Battlefield.build(self)
	_pads = built["pads"]

	_rig = CameraRig.new()
	_rig.name = "CameraRig"
	add_child(_rig)
	_rig.setup(LevelData.CAMERA_FOCUS)

	_setup_hud()
	_connect_state()
	_hud.refresh(state)
	_hud.hide_panels()
	_start_prepare()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	var tree := get_tree()
	if tree != null:
		tree.paused = false


# --- Frame loop -------------------------------------------------------------

func _process(delta: float) -> void:
	if _game_over:
		return
	if not _touches.is_empty() or _mouse_down:
		_tap_time += delta

	if _wave_active:
		_wave_timer += delta
		_spawn_due()
		if _spawn_cursor >= _wave_schedule.size() and _enemies.is_empty():
			_complete_wave()
	elif _prepare_running:
		_prepare_timer = maxf(0.0, _prepare_timer - delta)
		if _prepare_timer <= 0.0:
			_begin_wave(false)
		else:
			_hud.set_wave_status(App.t("hud.next_wave_in", [ceili(_prepare_timer)]))


# --- Setup ------------------------------------------------------------------

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	_hud = HUD_SCENE.instantiate()
	layer.add_child(_hud)
	_hud.build_requested.connect(_on_build_requested)
	_hud.upgrade_requested.connect(_on_upgrade_requested)
	_hud.sell_requested.connect(_on_sell_requested)
	_hud.start_wave_requested.connect(func() -> void: _begin_wave(true))
	_hud.speed_requested.connect(_on_speed_requested)
	_hud.pause_requested.connect(func() -> void: _set_paused(true))
	_hud.resume_requested.connect(func() -> void: _set_paused(false))
	_hud.quit_requested.connect(_quit_to_menu)
	_hud.retry_requested.connect(func() -> void: retry_requested.emit())
	_hud.menu_requested.connect(_quit_to_menu)
	_hud.set_speed(_speed)


func _connect_state() -> void:
	state.gold_changed.connect(func(_gold: int) -> void: _hud.refresh(state))
	state.core_changed.connect(func(_core: int, _max: int) -> void: _hud.refresh(state))
	state.wave_changed.connect(func(_wave: int, _total: int) -> void: _hud.refresh(state))
	state.finished.connect(_on_finished)


func _start_prepare() -> void:
	_prepare_running = true
	_prepare_timer = WaveData.prepare_time(state.wave + 1)
	_hud.show_start_button(true)
	_hud.set_wave_status(App.t("hud.next_wave_in", [ceili(_prepare_timer)]))


func _begin_wave(manual: bool) -> void:
	if _game_over or state.is_finished() or state.phase == GameState.Phase.WAVE:
		return
	if manual and _prepare_running:
		var bonus := int(ceil(_prepare_timer)) * WaveData.EARLY_BONUS_PER_SECOND
		if bonus > 0:
			state.earn(bonus)
			_hud.toast(App.t("wave.bonus", [bonus]))
	_prepare_running = false
	_hud.show_start_button(false)
	var index := state.begin_wave()
	_wave_schedule = WaveData.schedule(index)
	_wave_timer = 0.0
	_spawn_cursor = 0
	_wave_active = true
	_hud.set_wave_status(App.t("hud.wave_running", [index]))
	_hud.toast(App.t("wave.started", [index]))


func _spawn_due() -> void:
	while _spawn_cursor < _wave_schedule.size():
		var entry: Dictionary = _wave_schedule[_spawn_cursor]
		if float(entry["time"]) > _wave_timer:
			break
		_spawn_enemy(str(entry["type"]))
		_spawn_cursor += 1


func _spawn_enemy(kind: String) -> void:
	var enemy := Enemy.new()
	enemy.name = "Enemy_" + kind
	add_child(enemy)
	enemy.setup(kind, LevelData.route(), _rig.camera)
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	_enemies.append(enemy)


func _complete_wave() -> void:
	_wave_active = false
	var index := state.wave
	var reward := WaveData.reward(index)
	state.earn(reward)
	_hud.toast(App.t("wave.cleared", [index, reward]))
	state.complete_wave()
	if not state.is_finished():
		_start_prepare()


func _on_enemy_died(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	spawn_burst(enemy.global_position, EnemyData.color_of(enemy.kind), 0.9)
	state.earn(enemy.gold_reward)


func _on_enemy_leaked(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	state.damage_core(enemy.core_damage)
	if not state.is_finished():
		_hud.toast(App.t("info.leak", [enemy.core_damage]))


func _on_finished(victory: bool) -> void:
	_game_over = true
	_wave_active = false
	_prepare_running = false
	_clear_selection()
	_hud.show_start_button(false)
	_hud.set_wave_status("")
	App.record_waves(state.completed_waves)
	_hud.show_result(victory, state.completed_waves, GameState.TOTAL_WAVES)
	_speed = 1
	Engine.time_scale = 1.0
	_hud.set_speed(_speed)


# --- Player actions ---------------------------------------------------------

func _on_build_requested(kind: String) -> void:
	if _selected_pad == null or not is_instance_valid(_selected_pad):
		return
	if _selected_pad.tower != null or not TowerData.has_type(kind):
		return
	var cost := TowerData.build_cost(kind)
	if not state.spend(cost):
		_hud.toast(App.t("build.no_gold"))
		return
	var tower := Tower.new()
	tower.name = "Tower_" + kind
	_selected_pad.add_child(tower)
	tower.position = Vector3(0.0, 0.06, 0.0)
	tower.setup(kind, self)
	_selected_pad.set_tower(tower)
	_hud.toast(App.t("build.built", [App.t("tower.%s.name" % kind)]))
	_select_tower(tower)


func _on_upgrade_requested() -> void:
	var tower := _selected_tower
	if tower == null or not is_instance_valid(tower):
		return
	var cost := TowerData.upgrade_cost(tower.kind, tower.level)
	if cost <= 0:
		return
	if not state.spend(cost):
		_hud.toast(App.t("build.no_gold"))
		return
	tower.set_level(tower.level + 1)
	_hud.show_tower_panel(tower, state.gold)
	_hud.toast(App.t("build.upgraded", [App.t("tower.%s.name" % tower.kind), tower.level]))


func _on_sell_requested() -> void:
	var tower := _selected_tower
	if tower == null or not is_instance_valid(tower):
		return
	var refund := TowerData.sell_value(tower.kind, tower.level)
	state.earn(refund)
	var pad := tower.get_parent() as BuildPad
	if pad != null:
		pad.set_tower(null)
	_clear_selection()
	tower.queue_free()
	_hud.toast(App.t("build.sold", [refund]))


func _on_speed_requested() -> void:
	if _game_over:
		return
	_speed = 2 if _speed == 1 else 1
	Engine.time_scale = float(_speed)
	_hud.set_speed(_speed)


func _set_paused(paused: bool) -> void:
	if _game_over:
		return
	_paused = paused
	get_tree().paused = paused
	_hud.show_pause(paused)


func _quit_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	exit_requested.emit()


# --- Selection --------------------------------------------------------------

func _handle_tap(screen_position: Vector2) -> void:
	var picked := _pick(screen_position)
	if picked is BuildPad:
		_select_pad(picked as BuildPad)
	elif picked is Tower:
		_select_tower(picked as Tower)
	else:
		_clear_selection()


func _pick(screen_position: Vector2) -> Node:
	if _rig == null or _rig.camera == null:
		return null
	var camera := _rig.camera
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 240.0
	var query := PhysicsRayQueryParameters3D.create(from, to, PICK_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["collider"] as Node


func _select_pad(pad: BuildPad) -> void:
	_clear_selection()
	_selected_pad = pad
	pad.set_selected(true)
	_hud.show_pad_panel(state.gold)


func _select_tower(tower: Tower) -> void:
	_clear_selection()
	_selected_tower = tower
	tower.show_range(true)
	_hud.show_tower_panel(tower, state.gold)


func _clear_selection() -> void:
	if _selected_pad != null and is_instance_valid(_selected_pad):
		_selected_pad.set_selected(false)
	if _selected_tower != null and is_instance_valid(_selected_tower):
		_selected_tower.show_range(false)
	_selected_pad = null
	_selected_tower = null
	if _hud != null:
		_hud.hide_panels()


# --- Combat services used by towers and shots -------------------------------

func find_target(origin: Vector3, radius: float) -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for enemy in _enemies:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		if origin.distance_to(enemy.global_position) > radius:
			continue
		var to_core := enemy.global_position.distance_squared_to(LevelData.CORE_POSITION)
		if best == null or to_core < best_distance:
			best = enemy
			best_distance = to_core
	return best


func launch_shot(origin: Vector3, target: Enemy, kind: String, level: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	var shot := Shot.new()
	shot.name = "Shot_" + kind
	add_child(shot)
	shot.global_position = origin
	shot.setup(self, target, kind, level)


func apply_area_damage(
	center: Vector3,
	radius: float,
	damage: float,
	slow: float,
	slow_time: float,
	color: Color
) -> void:
	var flat_center := Vector2(center.x, center.z)
	for enemy in _enemies.duplicate():
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var flat := Vector2(enemy.global_position.x, enemy.global_position.z)
		if flat.distance_to(flat_center) > radius:
			continue
		enemy.take_damage(damage)
		if slow > 0.0:
			enemy.apply_slow(slow, slow_time)
	spawn_burst(center, color, maxf(radius * 0.7, 0.8))


func spawn_burst(at: Vector3, color: Color, radius: float) -> void:
	var burst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 5
	burst.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_color.a = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	burst.material_override = material
	burst.position = at
	add_child(burst)
	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * maxf(radius, 0.6), 0.32)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.32)
	tween.chain().tween_callback(burst.queue_free)


func spawn_ring(at: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.93
	mesh.outer_radius = 1.0
	mesh.rings = 36
	mesh.ring_segments = 5
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_color.a = 0.9
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	ring.material_override = material
	ring.position = at + Vector3(0.0, 0.22, 0.0)
	ring.scale = Vector3(radius * 0.3, 1.0, radius * 0.3)
	add_child(ring)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.42)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.42)
	tween.chain().tween_callback(ring.queue_free)


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _game_over or _paused or _rig == null:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_handle_drag(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventMagnifyGesture:
		_rig.zoom_by(1.0 / maxf(0.2, event.factor))


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_tap_start = event.position
			_tap_time = 0.0
			_dragging = false
		elif _touches.size() == 2:
			_pinch_distance = _touch_distance()
			_dragging = true
	else:
		var was_single := _touches.size() == 1
		_touches.erase(event.index)
		if was_single and not _dragging and _tap_time <= TAP_MAX_TIME:
			_handle_tap(event.position)
		if _touches.size() < 2:
			_pinch_distance = 0.0


func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		_dragging = true
		var current := _touch_distance()
		if _pinch_distance > 0.0 and current > 0.0:
			_rig.zoom_by(_pinch_distance / current)
		_pinch_distance = current
		return
	if event.position.distance_to(_tap_start) > TAP_MAX_MOVE:
		_dragging = true
	if _dragging:
		_rig.orbit(-event.relative.x * ORBIT_SPEED)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_rig.zoom_by(0.92)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_rig.zoom_by(1.08)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down = true
			_tap_start = event.position
			_tap_time = 0.0
			_dragging = false
		else:
			_mouse_down = false
			if not _dragging and _tap_time <= TAP_MAX_TIME:
				_handle_tap(event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_down:
		return
	if event.position.distance_to(_tap_start) > TAP_MAX_MOVE:
		_dragging = true
	if _dragging:
		_rig.orbit(-event.relative.x * ORBIT_SPEED)


func _touch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var points := _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)
