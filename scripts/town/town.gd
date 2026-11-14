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
var selected_id := ""

var _autosave := 0.0
var _pressing := false
var _press_position := Vector2.ZERO
var _drag_distance := 0.0
var _touches: Dictionary = {}
var _pinch_distance := 0.0


func _ready() -> void:
	Game.ensure_town()
	state = Game.town
	state.business_changed.connect(_on_business_changed)

	view = TownView.new()
	view.name = "TownView"
	add_child(view)
	view.setup(state)

	camera_rig = IsometricCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(self)

	if Game.offline_seconds > 0.0:
		hud.show_offline(Game.offline_seconds, state.offline_earnings(Game.offline_seconds))


func _process(delta: float) -> void:
	if state == null:
		return
	state.advance(delta)
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
	view.refresh_business(id)


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
