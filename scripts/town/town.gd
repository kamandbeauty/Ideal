extends Node3D
## Runs one town: the 3D view, the camera, the HUD and the idle simulation.

signal exit_requested

const HUD_SCENE := preload("res://scenes/ui/town_hud.tscn")
const AUTOSAVE_SECONDS := 20.0
const TAP_SLOP := 14.0

var state: TownState
var view: TownView
var camera_rig: IsometricCamera
var hud: Control
var day_cycle: DayCycle
var selected_id := ""

var _autosave := 0.0
var _pressing := false
var _press_position := Vector2.ZERO
var _drag_distance := 0.0
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _levels: Dictionary = {}
var _coin_timer := 0.0
var _coin_index := 0
var _zoom_from := 30.0
var _zoom_to := 30.0
var _target_from := Vector3.ZERO
var _target_to := Vector3.ZERO


func _ready() -> void:
	Game.ensure_town()
	state = Game.town
	state.business_changed.connect(_on_business_changed)
	state.town_completed.connect(_on_town_completed)
	for id in state.business_ids():
		_levels[id] = state.business(id).level

	view = TownView.new()
	view.name = "TownView"
	add_child(view)
	view.setup(state)

	day_cycle = DayCycle.new()
	day_cycle.name = "DayCycle"
	add_child(day_cycle)
	day_cycle.setup(view)

	camera_rig = IsometricCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	_intro_camera()

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(self)

	if Game.offline_seconds > 0.0:
		hud.show_offline(Game.offline_seconds, state.offline_earnings(Game.offline_seconds))


func _intro_camera() -> void:
	camera_rig.zoom = 38.0
	camera_rig.target = Vector3(0, 0, 5.0)
	camera_rig.apply()
	var tween := create_tween()
	tween.tween_method(_apply_intro, 0.0, 1.0, 1.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_intro(t: float) -> void:
	camera_rig.zoom = lerpf(38.0, 30.0, t)
	camera_rig.target = Vector3(0, 0, lerpf(5.0, 0.0, t))
	camera_rig.apply()


func _process(delta: float) -> void:
	if state == null:
		return
	state.advance(delta)
	_coin_timer += delta
	if _coin_timer >= 3.5:
		_coin_timer = 0.0
		_pop_income()
	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		_autosave = 0.0
		Game.save_game()
	if hud != null:
		hud.tick(delta)


func _exit_tree() -> void:
	if state != null:
		App.record_reputation(int(state.reputation))
		Game.save_game()


# --- Selection -------------------------------------------------------------

func select_business(id: String) -> void:
	if not state.businesses.has(id):
		return
	selected_id = id
	view.set_selected(id)
	hud.show_business(id)


func deselect() -> void:
	selected_id = ""
	view.set_selected("")
	hud.hide_business()


func _on_business_changed(id: String) -> void:
	var business := state.business(id)
	var previous := int(_levels.get(id, business.level if business != null else 1))
	view.refresh_business(id)
	if business == null:
		return
	_levels[id] = business.level
	if business.level > previous:
		view.sparkle(id)
		_focus_camera(id)


func _pop_income() -> void:
	var ids := state.unlocked_ids()
	if ids.is_empty():
		return
	_coin_index = (_coin_index + 1) % ids.size()
	var id := ids[_coin_index]
	var business := state.business(id)
	if business == null:
		return
	view.pop_income(id, business.net_per_second(state.traffic()) * 3.5)


func _focus_camera(id: String) -> void:
	var plot := BusinessData.plot(id)
	_zoom_from = camera_rig.zoom
	_zoom_to = camera_rig.zoom * 0.86
	_target_from = camera_rig.target
	_target_to = Vector3(plot.x * 0.35, 0, plot.y * 0.35)
	var tween := create_tween()
	tween.tween_method(_apply_camera_focus, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_apply_camera_focus, 1.0, 0.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_delay(0.35)


func _apply_camera_focus(t: float) -> void:
	camera_rig.zoom = lerpf(_zoom_from, _zoom_to, t)
	camera_rig.target = _target_from.lerp(_target_to, t)
	camera_rig.apply()


func _on_town_completed() -> void:
	_zoom_from = camera_rig.zoom
	_zoom_to = 40.0
	_target_from = camera_rig.target
	_target_to = Vector3.ZERO
	var tween := create_tween()
	tween.tween_method(_apply_camera_focus, 0.0, 1.0, 1.6).set_trans(Tween.TRANS_CUBIC)
	if hud != null:
		hud.show_completion_banner()


## Called by the HUD once the completion banner is dismissed.
func end_cinematic() -> void:
	_zoom_from = camera_rig.zoom
	_zoom_to = 30.0
	_target_from = camera_rig.target
	_target_to = Vector3.ZERO
	var tween := create_tween()
	tween.tween_method(_apply_camera_focus, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_CUBIC)


# --- HUD actions -----------------------------------------------------------

func save_now() -> void:
	Game.save_game()
	App.record_reputation(int(state.reputation))


func claim_offline() -> Dictionary:
	var report := Game.claim_offline()
	view.refresh_all()
	hud.refresh()
	return report


func leave_to_menu() -> void:
	Game.save_game()
	App.record_reputation(int(state.reputation))
	exit_requested.emit()


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _pressing:
			_drag_distance += event.relative.length()
			camera_rig.pan_by_pixels(event.relative)
	elif event is InputEventMagnifyGesture:
		camera_rig.zoom_by(1.0 / maxf(0.35, event.factor))
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_pressing = true
			_press_position = event.position
			_drag_distance = 0.0
		else:
			_pressing = false
			_pinch_distance = _touch_distance()
	else:
		var was_pressing := _pressing
		_touches.erase(event.index)
		_pinch_distance = 0.0
		if _touches.is_empty():
			_pressing = false
			if was_pressing and _drag_distance < TAP_SLOP:
				_tap(event.position)
		else:
			_pressing = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		var distance := _touch_distance()
		if _pinch_distance > 1.0 and distance > 1.0:
			camera_rig.zoom_by(_pinch_distance / distance)
		_pinch_distance = distance
		return
	_drag_distance += event.relative.length()
	camera_rig.pan_by_pixels(event.relative)


func _touch_distance() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1])


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
				_press_position = event.position
				_drag_distance = 0.0
			else:
				var was_pressing := _pressing
				_pressing = false
				if was_pressing and _drag_distance < TAP_SLOP:
					_tap(event.position)
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				camera_rig.zoom_by(0.9)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				camera_rig.zoom_by(1.1)


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_Q:
			camera_rig.turn_quarter(1)
		KEY_E:
			camera_rig.turn_quarter(-1)
		KEY_R:
			camera_rig.reset_view()
		KEY_ESCAPE:
			if selected_id.is_empty():
				leave_to_menu()
			else:
				deselect()


func _tap(screen_point: Vector2) -> void:
	var id := view.select_at(camera_rig.camera, screen_point)
	if id.is_empty():
		deselect()
	else:
		select_business(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if selected_id.is_empty():
			leave_to_menu()
		else:
			deselect()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_game()
