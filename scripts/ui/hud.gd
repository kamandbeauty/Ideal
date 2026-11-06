class_name TacticalHUD
extends CanvasLayer

signal start_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal fire_requested
signal reload_requested
signal ammo_requested(index: int)
signal zoom_requested
signal camera_requested
signal settings_changed(settings: Dictionary)

const SAND := Color("e9ddc3")
const MUTED := Color("9b9f8e")
const GOLD := Color("e8b34f")
const DARK := Color("151d19")
const PANEL := Color(0.055, 0.085, 0.07, 0.86)
const LINE := Color(0.48, 0.51, 0.40, 0.55)

var _bold: Font = load("res://assets/fonts/Rajdhani-Bold.ttf")
var _regular: Font = load("res://assets/fonts/Rajdhani-Medium.ttf")
var _mono: Font = load("res://assets/fonts/IBMPlexMono-Regular.ttf")
var _root: Control
var _gameplay: Control
var _menu: Control
var _pause: Control
var _results: Control
var _settings_screen: Control
var _licenses_screen: Control
var _licenses_text: RichTextLabel
var _settings_return: String = "menu"
var _settings: Dictionary = {}
var _reticle: AimReticle
var _objective: Label
var _bearing: Label
var _elevation: Label
var _range: Label
var _timer: Label
var _ammo_name: Label
var _ammo_count: Label
var _status: Label
var _feedback: Label
var _reload_button: Button
var _fire_button: Button
var _he_button: Button
var _ap_button: Button
var _zoom_button: Button
var _camera_button: Button
var _target_panel: Control
var _target_name: Label
var _target_health: Label
var _result_summary: Label
var _result_stars: Label
var _result_title: Label
var _result_subtitle: Label
var _graphics_button: Button
var _fps_button: Button
var _sound_button: Button
var _sensitivity_button: Button
var _feedback_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Interface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_gameplay()
	_build_menu()
	_build_pause()
	_build_results()
	_build_settings()
	_build_licenses()
	show_menu()


func set_settings(settings: Dictionary) -> void:
	_settings = settings.duplicate(true)
	_refresh_settings()


func show_menu() -> void:
	_show_screen("menu")
	_gameplay.visible = false


func show_gameplay() -> void:
	_show_screen("")
	_gameplay.visible = true


func show_pause() -> void:
	_show_screen("pause")


func show_results(
	success: bool, stars: int, destroyed: int, total: int, shots: int, hits: int, seconds: float
) -> void:
	_result_title.text = "SECTOR SECURED" if success else "MISSION FAILED"
	_result_subtitle.text = (
		"The outpost is no longer operational."
		if success
		else "No ammunition remaining. Regroup and try again."
	)
	_result_stars.text = "STAR RATING  %d / 3" % stars
	_result_summary.text = (
		"TARGETS  %d / %d       HITS  %d / %d       TIME  %02d:%02d"
		% [destroyed, total, hits, shots, int(seconds) / 60, int(seconds) % 60]
	)
	_show_screen("results")


func show_feedback(message: String) -> void:
	_feedback.text = message
	_feedback.visible = true
	_feedback_time = 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _pause.visible:
			resume_requested.emit()
			get_viewport().set_input_as_handled()
		elif _settings_screen.visible:
			_show_screen(_settings_return)
			get_viewport().set_input_as_handled()
		elif _licenses_screen.visible:
			_show_screen("menu")
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _feedback_time > 0.0:
		_feedback_time -= delta
		if _feedback_time <= 0.0:
			_feedback.visible = false


func update_status(
	gun: Artillery, mission: MissionState, preview: TrajectoryPreview, camera: Camera3D
) -> void:
	if not _gameplay.visible:
		return
	_objective.text = "%d / %d  TARGETS" % [mission.destroyed_ids.size(), mission.total_targets]
	_bearing.text = "%03d°" % int(fposmod(gun.yaw_degrees, 360.0))
	_elevation.text = "%02d°" % int(round(gun.elevation_degrees))
	var distance: float = (
		Vector2(
			preview.impact_position.x - gun.global_position.x,
			preview.impact_position.z - gun.global_position.z
		)
		. length()
	)
	_range.text = "%03d M" % int(distance) if preview.has_impact else "--- M"
	_timer.text = "%02d:%02d" % [int(mission.elapsed) / 60, int(mission.elapsed) % 60]
	var ammo: AmmoConfig = gun.state.current_ammo()
	_ammo_name.text = ammo.display_name
	_ammo_count.text = "%02d" % gun.state.current_rounds()
	if gun.state.reload_remaining > 0.0:
		_status.text = "CHAMBERING  %.1f S" % gun.state.reload_remaining
		_reload_button.text = "LOADING"
	elif gun.state.chambered:
		_status.text = "ROUND CHAMBERED"
		_reload_button.text = "RELOAD"
	else:
		_status.text = "CHAMBER EMPTY  /  RELOAD"
		_reload_button.text = "RELOAD !"
	_set_selected(_he_button, gun.state.selected_index == 0)
	_set_selected(_ap_button, gun.state.selected_index == 1)
	var markers: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("damageable"):
		var marked_target := node as BattlefieldTarget
		if marked_target == null or marked_target.is_destroyed:
			continue
		var anchor := (
			marked_target.global_position
			+ Vector3.UP * (10.0 if marked_target.target_type == "RADAR" else 5.5)
		)
		if not camera.is_position_behind(anchor):
			markers.append(
				{
					"position": camera.unproject_position(anchor),
					"name": marked_target.callsign + "  " + marked_target.target_type
				}
			)
	_reticle.update_markers(markers)
	var target := preview.impact_collider as BattlefieldTarget
	_target_panel.visible = is_instance_valid(target) and not target.is_destroyed
	if _target_panel.visible:
		_target_name.text = target.callsign + "  /  " + target.target_type
		_target_health.text = (
			"INTEGRITY   %d%%" % int(ceil(target.health / target.max_health * 100.0))
		)
	if preview.has_impact and not camera.is_position_behind(preview.impact_position):
		_reticle.update_position(
			camera.unproject_position(preview.impact_position), _target_panel.visible
		)
	else:
		_reticle.update_position(Vector2(-1000, -1000), false)


func set_camera_labels(zoomed: bool, shell_cam: bool) -> void:
	_zoom_button.text = "ZOOM  %s" % ("ON" if zoomed else "OFF")
	_camera_button.text = "CAM  %s" % ("SHELL" if shell_cam else "GUN")


func _build_gameplay() -> void:
	_gameplay = _control(_root, Vector2.ZERO, Vector2.ZERO)
	_gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vignette := ColorRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vignette_material
	_gameplay.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle = AimReticle.new()
	_gameplay.add_child(_reticle)

	var top := _anchored(_gameplay, Control.PRESET_TOP_WIDE, 0, 0, 0, 72)
	(
		_panel(top, Vector2.ZERO, Vector2.ZERO, Color(0.035, 0.055, 0.045, 0.88))
		. set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	)
	_label(top, "A / F", Vector2(28, 11), Vector2(95, 35), 30, GOLD, true)
	_label(top, "ARTILLERY\nFRONTLINE", Vector2(108, 14), Vector2(155, 40), 15, SAND, true)
	_label(top, "OPERATION 01", Vector2(283, 13), Vector2(140, 18), 10, MUTED, false, true)
	_label(top, "DUSTLINE", Vector2(283, 27), Vector2(160, 32), 24, SAND, true)
	var telemetry := _anchored(top, Control.PRESET_CENTER_TOP, -175, 9, 175, 64)
	_label(telemetry, "BEARING", Vector2(0, 0), Vector2(90, 15), 12, MUTED, false, true)
	_bearing = _label(telemetry, "000°", Vector2(0, 14), Vector2(100, 30), 24, SAND, true)
	_label(telemetry, "ELEVATION", Vector2(115, 0), Vector2(90, 15), 12, MUTED, false, true)
	_elevation = _label(telemetry, "26°", Vector2(115, 14), Vector2(100, 30), 24, SAND, true)
	_label(telemetry, "IMPACT", Vector2(235, 0), Vector2(90, 15), 12, MUTED, false, true)
	_range = _label(telemetry, "--- M", Vector2(235, 14), Vector2(110, 30), 24, GOLD, true)
	var top_right := _anchored(top, Control.PRESET_TOP_RIGHT, -240, 10, -26, 60)
	_timer = _label(top_right, "00:00", Vector2(0, 12), Vector2(80, 28), 20, SAND, false, true)
	var pause_button := _button(top_right, "II   PAUSE", Vector2(92, 0), Vector2(122, 48))
	pause_button.pressed.connect(pause_requested.emit)

	var objective := _panel(_gameplay, Vector2(28, 88), Vector2(254, 76), PANEL)
	_label(objective, "PRIMARY OBJECTIVE", Vector2(14, 10), Vector2(210, 16), 12, GOLD, false, true)
	_label(objective, "NEUTRALIZE THE OUTPOST", Vector2(14, 25), Vector2(225, 22), 17, SAND, true)
	_objective = _label(
		objective, "0 / 3  TARGETS", Vector2(14, 49), Vector2(200, 16), 13, MUTED, false, true
	)

	_target_panel = _anchored(_gameplay, Control.PRESET_TOP_RIGHT, -253, 88, -28, 155)
	_panel(_target_panel, Vector2.ZERO, Vector2(225, 67), PANEL)
	_label(
		_target_panel, "TARGET ACQUIRED", Vector2(12, 7), Vector2(200, 15), 10, GOLD, false, true
	)
	_target_name = _label(
		_target_panel, "TARGET", Vector2(12, 22), Vector2(200, 20), 16, SAND, true
	)
	_target_health = _label(
		_target_panel, "INTEGRITY  100%", Vector2(12, 44), Vector2(200, 15), 12, MUTED, false, true
	)
	_target_panel.visible = false

	var bottom_left := _anchored(_gameplay, Control.PRESET_BOTTOM_LEFT, 28, -183, 355, -24)
	_panel(bottom_left, Vector2.ZERO, Vector2(300, 159), PANEL)
	_label(
		bottom_left,
		"WEAPON SYSTEM  /  01",
		Vector2(14, 10),
		Vector2(245, 14),
		10,
		GOLD,
		false,
		true
	)
	_label(bottom_left, "M-70 BASTION", Vector2(14, 25), Vector2(220, 29), 24, SAND, true)
	_ammo_name = _label(
		bottom_left, "HIGH EXPLOSIVE", Vector2(14, 57), Vector2(180, 18), 13, MUTED, false, true
	)
	_ammo_count = _label(bottom_left, "18", Vector2(228, 27), Vector2(52, 42), 35, GOLD, true)
	_status = _label(
		bottom_left, "ROUND CHAMBERED", Vector2(14, 80), Vector2(240, 18), 13, SAND, false, true
	)
	_he_button = _button(bottom_left, "HE  /  BLAST", Vector2(14, 107), Vector2(129, 39))
	_ap_button = _button(bottom_left, "AP  /  ARMOR", Vector2(152, 107), Vector2(129, 39))
	_he_button.pressed.connect(func() -> void: ammo_requested.emit(0))
	_ap_button.pressed.connect(func() -> void: ammo_requested.emit(1))

	var actions := _anchored(_gameplay, Control.PRESET_BOTTOM_RIGHT, -480, -173, -28, -24)
	_camera_button = _button(actions, "CAM  GUN", Vector2(0, 18), Vector2(105, 48))
	_zoom_button = _button(actions, "ZOOM  OFF", Vector2(115, 18), Vector2(105, 48))
	_reload_button = _button(actions, "RELOAD", Vector2(0, 76), Vector2(220, 62))
	_fire_button = _button(actions, "FIRE", Vector2(238, 0), Vector2(214, 138), true)
	_fire_button.add_theme_font_size_override("font_size", 34)
	_camera_button.pressed.connect(camera_requested.emit)
	_zoom_button.pressed.connect(zoom_requested.emit)
	_reload_button.pressed.connect(reload_requested.emit)
	_fire_button.pressed.connect(fire_requested.emit)
	var bottom_center := _anchored(_gameplay, Control.PRESET_CENTER_BOTTOM, -210, -80, 210, -20)
	_feedback = _label(
		bottom_center,
		"",
		Vector2.ZERO,
		Vector2(420, 26),
		15,
		GOLD,
		false,
		true,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_feedback.visible = false
	_label(
		bottom_center,
		"DRAG TO AIM  /  SPACE TO FIRE",
		Vector2(0, 28),
		Vector2(420, 20),
		12,
		SAND,
		false,
		true,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _build_menu() -> void:
	_menu = _overlay()
	var shade := _panel(_menu, Vector2.ZERO, Vector2(680, 720), Color(0.055, 0.075, 0.06, 0.94))
	shade.anchor_bottom = 1.0
	shade.offset_bottom = 0.0
	_label(shade, "A / F", Vector2(48, 29), Vector2(110, 40), 32, GOLD, true)
	_label(
		shade, "ARTILLERY  /  FRONTLINE", Vector2(150, 38), Vector2(330, 20), 13, SAND, false, true
	)
	_label(
		shade,
		"OFFLINE  //  SINGLE PLAYER",
		Vector2(49, 110),
		Vector2(450, 18),
		11,
		GOLD,
		false,
		true
	)
	_label(shade, "THE LAST\nARGUMENT.", Vector2(43, 133), Vector2(590, 162), 76, SAND, true)
	_label(shade, "TAKE THE HIGH GROUND.", Vector2(49, 308), Vector2(500, 28), 22, GOLD, true)
	_label(
		shade,
		"One gun. Three targets. Every round counts.\nBring the desert outpost to a standstill.",
		Vector2(49, 342),
		Vector2(510, 52),
		17,
		SAND
	)
	var card := _panel(
		shade, Vector2(49, 421), Vector2(545, 93), Color(0.13, 0.16, 0.12, 0.85), LINE
	)
	_label(card, "01", Vector2(17, 12), Vector2(75, 54), 42, GOLD, true)
	_label(card, "OPERATION DUSTLINE", Vector2(94, 12), Vector2(360, 28), 23, SAND, true)
	_label(
		card,
		"DESERT OUTPOST  /  TARGET PRACTICE",
		Vector2(95, 46),
		Vector2(390, 20),
		10,
		MUTED,
		false,
		true
	)
	var deploy := _button(shade, "DEPLOY TO DUSTLINE   >", Vector2(49, 546), Vector2(338, 60), true)
	deploy.pressed.connect(start_requested.emit)
	var settings := _button(shade, "SETTINGS", Vector2(398, 546), Vector2(196, 60))
	settings.pressed.connect(func() -> void: _open_settings("menu"))
	var licenses := _button(shade, "LICENSES", Vector2(398, 618), Vector2(196, 42))
	licenses.add_theme_font_size_override("font_size", 15)
	licenses.pressed.connect(_open_licenses)
	var footer := _anchored(shade, Control.PRESET_BOTTOM_LEFT, 49, -42, 600, -18)
	_label(
		footer,
		"VERTICAL SLICE  /  V 0.1        NO NETWORK REQUIRED",
		Vector2.ZERO,
		Vector2(500, 18),
		10,
		MUTED,
		false,
		true
	)
	var right := _anchored(_menu, Control.PRESET_BOTTOM_RIGHT, -337, -116, -32, -30)
	_label(right, "FIELD NOTES  /  001", Vector2(0, 0), Vector2(300, 18), 10, GOLD, false, true)
	_label(right, "DUSTLINE", Vector2(0, 18), Vector2(300, 40), 34, SAND, true)
	_label(
		right, "31° 12' N   /   07° 44' E", Vector2(0, 61), Vector2(300, 16), 10, SAND, false, true
	)


func _build_pause() -> void:
	_pause = _overlay()
	var panel := _center_panel(_pause, Vector2(460, 390))
	_label(
		panel, "FIELD COMMAND  /  PAUSED", Vector2(28, 25), Vector2(400, 18), 11, GOLD, false, true
	)
	_label(panel, "MISSION PAUSED", Vector2(26, 49), Vector2(410, 55), 42, SAND, true)
	var resume := _button(panel, "RESUME MISSION", Vector2(28, 122), Vector2(404, 56), true)
	var settings := _button(panel, "SETTINGS", Vector2(28, 188), Vector2(404, 48))
	var retry := _button(panel, "RESTART OPERATION", Vector2(28, 246), Vector2(404, 48))
	var menu := _button(panel, "RETURN TO MENU", Vector2(28, 304), Vector2(404, 48))
	resume.pressed.connect(resume_requested.emit)
	settings.pressed.connect(func() -> void: _open_settings("pause"))
	retry.pressed.connect(restart_requested.emit)
	menu.pressed.connect(menu_requested.emit)


func _build_results() -> void:
	_results = _overlay()
	var panel := _center_panel(_results, Vector2(570, 420))
	_label(
		panel, "OPERATION 01  /  COMPLETE", Vector2(32, 24), Vector2(480, 20), 11, GOLD, false, true
	)
	_result_title = _label(
		panel, "SECTOR SECURED", Vector2(29, 50), Vector2(510, 62), 50, SAND, true
	)
	_result_subtitle = _label(
		panel,
		"The outpost is no longer operational.",
		Vector2(32, 114),
		Vector2(490, 26),
		18,
		MUTED
	)
	_result_stars = _label(
		panel, "STAR RATING  3 / 3", Vector2(32, 159), Vector2(490, 42), 31, GOLD, true
	)
	_result_summary = _label(panel, "", Vector2(32, 220), Vector2(500, 50), 12, SAND, false, true)
	var replay := _button(panel, "REPLAY OPERATION", Vector2(32, 310), Vector2(248, 58), true)
	var menu := _button(panel, "MAIN MENU", Vector2(292, 310), Vector2(246, 58))
	replay.pressed.connect(restart_requested.emit)
	menu.pressed.connect(menu_requested.emit)


func _build_settings() -> void:
	_settings_screen = _overlay()
	var panel := _center_panel(_settings_screen, Vector2(520, 470))
	_label(
		panel, "SYSTEMS  /  PREFERENCES", Vector2(30, 20), Vector2(440, 20), 11, GOLD, false, true
	)
	_label(panel, "SETTINGS", Vector2(27, 45), Vector2(440, 54), 44, SAND, true)
	_label(panel, "Changes are saved on this device.", Vector2(30, 97), Vector2(440, 20), 15, MUTED)
	_graphics_button = _button(panel, "", Vector2(30, 132), Vector2(460, 50))
	_fps_button = _button(panel, "", Vector2(30, 191), Vector2(460, 50))
	_sound_button = _button(panel, "", Vector2(30, 250), Vector2(460, 50))
	_sensitivity_button = _button(panel, "", Vector2(30, 309), Vector2(460, 50))
	var back := _button(panel, "BACK", Vector2(30, 381), Vector2(460, 55), true)
	_graphics_button.pressed.connect(_cycle_graphics)
	_fps_button.pressed.connect(_cycle_fps)
	_sound_button.pressed.connect(_toggle_sound)
	_sensitivity_button.pressed.connect(_cycle_sensitivity)
	back.pressed.connect(func() -> void: _show_screen(_settings_return))


func _build_licenses() -> void:
	_licenses_screen = _overlay()
	var panel := _center_panel(_licenses_screen, Vector2(860, 600))
	_label(
		panel, "CREDITS  /  OPEN SOURCE", Vector2(30, 22), Vector2(700, 20), 11, GOLD, false, true
	)
	_label(panel, "LICENSES", Vector2(27, 45), Vector2(700, 54), 44, SAND, true)
	_licenses_text = RichTextLabel.new()
	_licenses_text.position = Vector2(30, 110)
	_licenses_text.size = Vector2(800, 394)
	_licenses_text.scroll_active = true
	_licenses_text.add_theme_font_override("normal_font", _regular)
	_licenses_text.add_theme_font_size_override("normal_font_size", 16)
	_licenses_text.add_theme_color_override("default_color", SAND)
	panel.add_child(_licenses_text)
	var back := _button(panel, "BACK", Vector2(30, 522), Vector2(800, 52), true)
	back.pressed.connect(func() -> void: _show_screen("menu"))


func _open_licenses() -> void:
	if _licenses_text.text.is_empty():
		_licenses_text.text = (
			"ARTILLERY FRONTLINE — LICENSES\n\n"
			+ "Original geometry, visuals and synthesized audio were created for this project.\n\n"
			+ "RAJDHANI FONT\n\n"
			+ FileAccess.get_file_as_string("res://assets/fonts/OFL-Rajdhani.txt")
			+ "\n\nIBM PLEX MONO FONT\n\n"
			+ FileAccess.get_file_as_string("res://assets/fonts/OFL-IBMPlexMono.txt")
			+ "\n\nGODOT ENGINE\n\n"
			+ FileAccess.get_file_as_string("res://assets/licenses/GODOT-LICENSE.txt")
			+ "\n\nGODOT THIRD-PARTY NOTICES\n\n"
			+ FileAccess.get_file_as_string("res://assets/licenses/GODOT-COPYRIGHT.txt")
		)
	_show_screen("licenses")


func _cycle_graphics() -> void:
	var modes := ["AUTO", "LOW", "MEDIUM", "HIGH"]
	var index := modes.find(_settings.get("graphics", "AUTO"))
	_settings.graphics = modes[(index + 1) % modes.size()]
	_commit_settings()


func _cycle_fps() -> void:
	_settings.target_fps = 30 if int(_settings.get("target_fps", 60)) == 60 else 60
	_commit_settings()


func _toggle_sound() -> void:
	_settings.sound = not bool(_settings.get("sound", true))
	_commit_settings()


func _cycle_sensitivity() -> void:
	var value := float(_settings.get("sensitivity", 1.0))
	_settings.sensitivity = 1.0 if value < 0.8 else (1.5 if value < 1.3 else 0.6)
	_commit_settings()


func _commit_settings() -> void:
	_refresh_settings()
	settings_changed.emit(_settings.duplicate(true))


func _refresh_settings() -> void:
	if _graphics_button == null:
		return
	_graphics_button.text = (
		"GRAPHICS PROFILE                         %s  >" % _settings.get("graphics", "AUTO")
	)
	_fps_button.text = (
		"FRAME RATE TARGET                         %s FPS  >" % _settings.get("target_fps", 60)
	)
	_sound_button.text = (
		"SOUND EFFECTS                                  %s  >"
		% ("ON" if _settings.get("sound", true) else "OFF")
	)
	_sensitivity_button.text = (
		"AIM SENSITIVITY                               %.1fx  >"
		% float(_settings.get("sensitivity", 1.0))
	)


func _open_settings(previous: String) -> void:
	_settings_return = previous
	_show_screen("settings")


func _show_screen(which: String) -> void:
	_menu.visible = which == "menu"
	_pause.visible = which == "pause"
	_results.visible = which == "results"
	_settings_screen.visible = which == "settings"
	_licenses_screen.visible = which == "licenses"


func _overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.015, 0.025, 0.02, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay


func _center_panel(parent: Control, dimensions: Vector2) -> Control:
	var wrapper := _anchored(
		parent,
		Control.PRESET_CENTER,
		-dimensions.x / 2,
		-dimensions.y / 2,
		dimensions.x / 2,
		dimensions.y / 2
	)
	_panel(wrapper, Vector2.ZERO, dimensions, Color(0.07, 0.095, 0.075, 0.98), LINE)
	return wrapper


func _control(parent: Node, pos: Vector2, dimensions: Vector2) -> Control:
	var control := Control.new()
	control.position = pos
	control.size = dimensions
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func _anchored(
	parent: Control, preset: int, left: float, top: float, right: float, bottom: float
) -> Control:
	var control := _control(parent, Vector2.ZERO, Vector2.ZERO)
	control.set_anchors_preset(preset)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom
	return control


func _panel(
	parent: Node, pos: Vector2, dimensions: Vector2, color: Color, border: Color = Color.TRANSPARENT
) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(
	parent: Node,
	text: String,
	pos: Vector2,
	dimensions: Vector2,
	font_size: int,
	color: Color,
	bold: bool = false,
	mono: bool = false,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", _mono if mono else (_bold if bold else _regular))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(
	parent: Node, text: String, pos: Vector2, dimensions: Vector2, primary: bool = false
) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", _bold)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", DARK if primary else SAND)
	button.add_theme_color_override("font_hover_color", DARK if primary else GOLD)
	button.add_theme_color_override("font_pressed_color", DARK if primary else GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD if primary else Color(0.12, 0.16, 0.125, 0.96)
	normal.border_color = GOLD if primary else LINE
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f6ca75") if primary else Color(0.2, 0.24, 0.18, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("c8953f") if primary else Color(0.25, 0.27, 0.18, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(button)
	return button


func _set_selected(button: Button, selected: bool) -> void:
	button.add_theme_color_override("font_color", GOLD if selected else SAND)
