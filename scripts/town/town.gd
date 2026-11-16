extends Node3D
## Runs one Roadside Empire station hub: the 3D canyon view, camera rig,
## portrait HUD, world badges, vault collection and idle simulation.

signal exit_requested
signal travel_requested(town_id: String)

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
var _music_night := false
var _coin_timer := 0.0
var _coin_index := 0
var _event_timer := 85.0
var _auto_timer := 6.0
var _last_event_id := ""
var _events_rng := RandomNumberGenerator.new()
var _zoom_from := 23.5
var _zoom_to := 23.5
var _target_from := Vector3.ZERO
var _target_to := Vector3.ZERO


func _ready() -> void:
	_events_rng.randomize()
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

	if Game.offline_seconds > 0.0 and state.offline_earnings(Game.offline_seconds) > 0.0:
		hud.show_offline(Game.offline_seconds, state.offline_earnings(Game.offline_seconds))

	state.event_started.connect(_on_event_started)
	App.settings_changed.connect(_on_settings_changed)
	_start_music()
	_claim_daily()


func _intro_camera() -> void:
	camera_rig.zoom = 29.5
	camera_rig.target = Vector3(-0.3, 0.0, 2.8)
	camera_rig.apply()
	var tween := create_tween()
	tween.tween_method(_apply_intro, 0.0, 1.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_intro(t: float) -> void:
	camera_rig.zoom = lerpf(29.5, IsometricCamera.DEFAULT_ZOOM, t)
	camera_rig.target = Vector3(-0.3, 0.0, lerpf(2.8, IsometricCamera.DEFAULT_TARGET.z, t))
	camera_rig.apply()


func _process(delta: float) -> void:
	if state == null:
		return
	state.advance(delta)
	_coin_timer += delta
	if _coin_timer >= 3.8:
		_coin_timer = 0.0
		_pop_income()
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = _events_rng.randf_range(115.0, 165.0)
		if state.active_event.is_empty():
			var event_id := TownEvents.pick(_events_rng, _last_event_id)
			if state.start_event(event_id):
				_last_event_id = event_id
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_auto_timer = 5.5
		_auto_upgrade()

	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		_autosave = 0.0
		Game.save_game()
	_tick_music()
	if hud != null:
		hud.tick(delta)


func _exit_tree() -> void:
	if state != null:
		App.record_reputation(int(state.reputation))
		Game.save_game()


func _start_music() -> void:
	_music_night = day_cycle.is_night()
	Sound.play_music("night" if _music_night else "day")
	Sound.start_ambience()


func _tick_music() -> void:
	var night := day_cycle.is_night()
	if night == _music_night:
		return
	_music_night = night
	Sound.play_music("night" if night else "day")
	if hud != null:
		hud.show_message(App.t("msg.night" if night else "msg.morning"))


func _on_event_started(id: String) -> void:
	Sound.play("event", -6.0)
	App.tap(20)
	if hud != null:
		hud.show_message(App.t(TownEvents.name_key(id)))


func _claim_daily() -> void:
	if Game.profile == null or not Game.profile.bonus_ready():
		return
	var chest := Game.profile.claim_daily()
	if chest.is_empty():
		return
	var message := App.t("msg.daily", [
		App.format_short(float(chest["cash"])),
		App.format_number(float(chest["streak"])),
		"%.1f" % float(chest["multiplier"]),
	])
	if int(chest["gems"]) > 0:
		message += " · " + App.t("msg.daily_gems", [App.format_number(float(chest["gems"]))])
		Sound.play("gem", -4.0)
	if hud != null:
		hud.show_message(message)
	Sound.play("cash", -4.0)
	App.tap(35)
	hud.refresh()
	Game.save_game()


func _on_settings_changed() -> void:
	if view == null:
		return
	var cust := view.get_node_or_null("Customers")
	if cust != null:
		cust.set("max_agents", Quality.agent_cap(App.quality))
	var walkers := view.get_node_or_null("Pedestrians")
	if walkers != null:
		walkers.call("set_count", Quality.pedestrian_count(App.quality))


func select_business(id: String) -> void:
	if not state.businesses.has(id):
		return
	var b := state.business(id)
	if b != null and b.unlocked and b.vault_cash >= 1.0:
		var swept := state.collect_vault(id)
		if swept > 0.0:
			view.pop_income(id, swept)
			Sound.play("coin", -7.0)
	selected_id = id
	view.set_selected(id)
	hud.show_business(id)


func deselect() -> void:
	selected_id = ""
	view.set_selected("")
	hud.hide_business()


func _on_business_changed(id: String) -> void:
	var b := state.business(id)
	var previous := int(_levels.get(id, b.level if b != null else 1))
	view.refresh_business(id)
	if b == null:
		return
	_levels[id] = b.level
	if b.level > previous:
		view.sparkle(id)


func _auto_upgrade() -> void:
	var step := AutoUpgrade.apply(state)
	if step.is_empty() or hud == null:
		return
	var id := String(step["id"])
	view.refresh_business(id)
	view.sparkle(id)
	var message := App.t("msg.auto_level", [
		App.t("business.%s.name" % id),
		App.format_number(float(step.get("level", 1))),
	])
	if String(step["kind"]) == AutoUpgrade.KIND_BRANCH:
		message = App.t("msg.auto_branch", [
			App.t("business.%s.name" % id),
			App.t("branch.%s" % String(step["branch"])),
			App.format_number(float(step["branch_level"])),
		])
	elif String(step["kind"]) == AutoUpgrade.KIND_MANAGER:
		message = App.t("msg.auto_rank", [
			App.t("business.%s.name" % id),
			App.t("manager.rank.%d" % int(step["manager_rank"])),
		])
	hud.show_message(message)


func _pop_income() -> void:
	var ids := state.unlocked_ids()
	if ids.is_empty():
		return
	_coin_index = (_coin_index + 1) % ids.size()
	var id := ids[_coin_index]
	var b := state.business(id)
	if b != null and b.is_automated():
		view.pop_income(id, b.net_per_second(state.traffic()) * state.income_multiplier() * 3.5)


func _on_town_completed() -> void:
	_zoom_from = camera_rig.zoom
	_zoom_to = 31.0
	_target_from = camera_rig.target
	_target_to = IsometricCamera.DEFAULT_TARGET
	var tw := create_tween()
	tw.tween_method(_apply_camera_focus, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_CUBIC)
	if hud != null:
		hud.show_completion_banner()


func end_cinematic() -> void:
	_zoom_from = camera_rig.zoom
	_zoom_to = IsometricCamera.DEFAULT_ZOOM
	_target_from = camera_rig.target
	_target_to = IsometricCamera.DEFAULT_TARGET
	var tw := create_tween()
	tw.tween_method(_apply_camera_focus, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_CUBIC)


func _apply_camera_focus(t: float) -> void:
	camera_rig.zoom = lerpf(_zoom_from, _zoom_to, t)
	camera_rig.target = _target_from.lerp(_target_to, t)
	camera_rig.apply()


func save_now() -> void:
	Game.save_game()
	App.record_reputation(int(state.reputation))


func claim_offline() -> Dictionary:
	var report := Game.claim_offline()
	view.refresh_all()
	hud.refresh()
	return report


func travel_to(town_id: String) -> bool:
	if not Game.travel_to(town_id):
		if hud != null:
			hud.show_message(App.t("msg.travel_locked", [
				App.format_number(TownData.star_required(town_id))
			]))
		Sound.play("deny", -10.0)
		return false
	App.record_reputation(int(state.reputation))
	if hud != null:
		hud.show_message(App.t("msg.travel", [App.t("town.%s" % town_id)]))
	travel_requested.emit(town_id)
	return true


func leave_to_menu() -> void:
	Game.save_game()
	App.record_reputation(int(state.reputation))
	exit_requested.emit()


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
		return
	if id == selected_id:
		collect_tip(id)
		return
	select_business(id)


func collect_tip(id: String) -> float:
	var amount := state.collect_tip(id)
	if amount <= 0.0:
		Sound.play("deny", -18.0)
		return 0.0
	view.pop_income(id, amount)
	Sound.play("coin", -7.0)
	App.tap(18)
	if hud != null:
		hud.refresh()
	return amount


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state != null:
			Game.save_game()
			App.record_reputation(int(state.reputation))
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if selected_id.is_empty():
			leave_to_menu()
		else:
			deselect()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_game()
