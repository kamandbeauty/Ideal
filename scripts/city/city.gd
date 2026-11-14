extends Node3D
## A city session: state, view, camera, HUD and the touch controls.

signal exit_requested

const HUD_SCENE := preload("res://scenes/ui/city_hud.tscn")
const AUTOSAVE_SECONDS := 20.0
const HUD_REFRESH_SECONDS := 0.12
const TAP_MAX_MOVE := 14.0
const TAP_MAX_TIME := 0.4
const PLACE_SOUND := "res://assets/audio/placement-*.ogg"
const REMOVE_SOUND := "res://assets/audio/removal-*.ogg"

## Set by the menu before the scene enters the tree.
var load_from_file := false

var state: CityState
var view: CityView
var camera_rig: CityCamera
var hud

var selected_id := "road"
var selected_rotation := 0
var demolish_mode := false

var _undo: Array[Dictionary] = []
var _autosave := 0.0
var _hud_timer := 0.0

var _touches: Dictionary = {}
var _tap_start := Vector2.ZERO
var _tap_time := 0.0
var _dragging := false
var _pinch_distance := 0.0
var _mouse_down := false


func _ready() -> void:
	state = CityState.load_from_disk() if load_from_file else CityState.new()
	if state == null:
		state = CityState.new()
	state.milestone_reached.connect(_on_milestone)

	view = CityView.new()
	view.name = "CityView"
	add_child(view)
	view.setup(state)

	camera_rig = CityCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup()

	_setup_hud()
	_select_structure("road")
	state.save_to_disk()


func _exit_tree() -> void:
	if state != null:
		state.save_to_disk()
		App.record_population(int(state.population))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null:
			state.save_to_disk()


func _process(delta: float) -> void:
	if not _touches.is_empty() or _mouse_down:
		_tap_time += delta
	state.advance(delta)

	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		_autosave = 0.0
		state.save_to_disk()

	_hud_timer += delta
	if _hud_timer >= HUD_REFRESH_SECONDS:
		_hud_timer = 0.0
		hud.refresh(state)


# --- Setup ------------------------------------------------------------------

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	hud = HUD_SCENE.instantiate()
	layer.add_child(hud)
	hud.structure_chosen.connect(_select_structure)
	hud.rotate_requested.connect(_rotate_selection)
	hud.undo_requested.connect(_undo_last)
	hud.demolish_requested.connect(_toggle_demolish)
	hud.save_requested.connect(_save_now)
	hud.menu_requested.connect(_quit_to_menu)
	hud.refresh(state)
	hud.set_demolish(false)


# --- Player actions ---------------------------------------------------------

func _select_structure(id: String) -> void:
	if id.is_empty():
		return
	selected_id = id
	selected_rotation = 0
	demolish_mode = false
	hud.set_demolish(false)
	hud.set_selection(id)
	view.set_selection(id, 0)
	Sound.play("res://assets/audio/toggle.ogg", -18.0)


func _rotate_selection() -> void:
	if not bool(CityData.structure(selected_id).get("rotatable", false)):
		return
	selected_rotation = (selected_rotation + 1) % 4
	view.set_selection(selected_id, selected_rotation)
	Sound.play("res://assets/audio/rotate.ogg", -16.0)


func _toggle_demolish() -> void:
	demolish_mode = not demolish_mode
	hud.set_demolish(demolish_mode)
	Sound.play("res://assets/audio/toggle.ogg", -18.0)


func _save_now() -> void:
	if state.save_to_disk():
		hud.toast(App.t("hud.saved"))


func _quit_to_menu() -> void:
	state.save_to_disk()
	App.record_population(int(state.population))
	exit_requested.emit()


func _place(cell: Vector2i) -> void:
	if selected_id.is_empty() or not state.cell_in_bounds(cell):
		return
	if not state.is_empty(cell):
		hud.toast(App.t("msg.occupied"))
		return
	if not state.place(selected_id, cell, selected_rotation):
		hud.toast(App.t("msg.no_cash"))
		return
	_undo.append({"action": "place", "cell": cell, "id": selected_id})
	Sound.play(PLACE_SOUND, -12.0)
	view.refresh_area(cell)
	view.update_cursor(cell, true)
	hud.refresh(state)
	hud.toast(App.t("msg.built", [App.t("structure.%s.name" % selected_id)]))
	if CityData.needs_road(selected_id) and state.unconnected_buildings > 0:
		hud.toast(App.t("hud.road_needed"))


func _demolish(cell: Vector2i) -> void:
	var id := state.structure_at(cell)
	if id.is_empty():
		return
	if id == CityData.HALL_ID:
		hud.toast(App.t("msg.cannot_remove"))
		return
	var result := state.remove(cell)
	if result.is_empty():
		return
	_undo.append({
		"action": "remove",
		"cell": cell,
		"id": str(result["id"]),
		"rotation": int(result["rotation"]),
	})
	Sound.play(REMOVE_SOUND, -12.0)
	view.refresh_area(cell)
	hud.refresh(state)
	hud.toast(App.t("msg.removed", [App.t("structure.%s.name" % result["id"]), result["refund"]]))


func _undo_last() -> void:
	if _undo.is_empty():
		hud.toast(App.t("msg.undo_empty"))
		return
	var action: Dictionary = _undo.pop_back()
	var cell: Vector2i = action["cell"]
	if str(action["action"]) == "place":
		state.remove(cell, 1.0)
		Sound.play(REMOVE_SOUND, -14.0)
	else:
		state.place_free(str(action["id"]), cell, int(action.get("rotation", 0)))
		Sound.play(PLACE_SOUND, -14.0)
	view.refresh_area(cell)
	hud.refresh(state)


func _on_milestone(index: int, bonus: int) -> void:
	var threshold := 0
	if index >= 0 and index < CityState.MILESTONES.size():
		threshold = CityState.MILESTONES[index]
	hud.toast(App.t("hud.milestone", [threshold, bonus]))
	App.record_population(int(state.population))


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
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
		camera_rig.zoom_by(1.0 / maxf(0.2, event.factor))


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
			_tap(event.position)
		if _touches.size() < 2:
			_pinch_distance = 0.0


func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		_dragging = true
		var current := _touch_distance()
		if _pinch_distance > 0.0 and current > 0.0:
			camera_rig.zoom_by(_pinch_distance / current)
		_pinch_distance = current
		return
	if event.position.distance_to(_tap_start) > TAP_MAX_MOVE:
		_dragging = true
	if _dragging:
		camera_rig.pan_by_pixels(event.relative)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		camera_rig.zoom_by(0.9)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		camera_rig.zoom_by(1.1)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down = true
			_tap_start = event.position
			_tap_time = 0.0
			_dragging = false
		else:
			_mouse_down = false
			if not _dragging and _tap_time <= TAP_MAX_TIME:
				_tap(event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_down:
		_hover(event.position)
		return
	if event.position.distance_to(_tap_start) > TAP_MAX_MOVE:
		_dragging = true
	if _dragging:
		camera_rig.pan_by_pixels(event.relative)


func _tap(screen_position: Vector2) -> void:
	var cell := view.cell_from_screen(screen_position, camera_rig.camera)
	if cell == CityData.INVALID_CELL:
		view.hide_cursor()
		return
	var valid := state.is_empty(cell) if not demolish_mode else not state.is_empty(cell)
	view.update_cursor(cell, valid)
	if demolish_mode:
		_demolish(cell)
	else:
		_place(cell)


func _hover(screen_position: Vector2) -> void:
	var cell := view.cell_from_screen(screen_position, camera_rig.camera)
	if cell == CityData.INVALID_CELL:
		view.hide_cursor()
		return
	var valid := state.is_empty(cell) if not demolish_mode else not state.is_empty(cell)
	view.update_cursor(cell, valid)


func _touch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var points := _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)
