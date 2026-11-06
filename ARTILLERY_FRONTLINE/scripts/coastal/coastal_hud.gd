class_name CoastalHUD
extends CanvasLayer
## Original landscape mobile HUD inspired by mounted-weapon beach defense layout.
signal fire_down
signal fire_up
signal aim_pressed
signal weapon_pressed
signal reload_pressed
signal rocket_pressed
signal auto_toggled(enabled: bool)
signal settings_pressed
signal support_pressed(id: String)
signal resume_pressed
signal restart_pressed
signal exit_pressed

var root: Control
var mission_label: Label
var enemies_label: Label
var round_label: Label
var timer_label: Label
var wave_pips: HBoxContainer
var health_bar: ProgressBar
var health_label: Label
var ammo_label: Label
var weapon_label: Label
var auto_check: CheckButton
var fire_button: Button
var aim_button: Button
var reload_button: Button
var rocket_button: Button
var support_buttons: Dictionary = {}
var pause_panel: Control
var result_panel: Control
var result_title: Label
var result_body: Label
var quality_select: OptionButton

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.name = "CoastalInterface"
	root.theme = UITheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_right()
	_build_bottom()
	_build_pause()
	_build_results()

func _glass(child: Control, padding: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.06, 0.48)
	box.border_color = Color(0.65, 0.72, 0.62, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(child)
	return panel

func _build_top() -> void:
	var left := UITheme.row(10)
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 18
	left.offset_top = 14
	var settings := UITheme.button("SETTINGS", func(): settings_pressed.emit())
	settings.custom_minimum_size = Vector2(112, 56)
	left.add_child(settings)
	auto_check = CheckButton.new()
	auto_check.text = "AUTO FIRE"
	auto_check.add_theme_font_size_override("font_size", 20)
	auto_check.custom_minimum_size = Vector2(150, 56)
	auto_check.toggled.connect(func(on): auto_toggled.emit(on); _pulse(auto_check))
	left.add_child(_glass(auto_check, 8))
	root.add_child(left)
	wave_pips = UITheme.row(8)
	wave_pips.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave_pips.offset_left = -120
	wave_pips.offset_right = 120
	wave_pips.offset_top = 18
	wave_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wave_pips)
	var info := UITheme.column(2)
	info.alignment = BoxContainer.ALIGNMENT_END
	mission_label = UITheme.label("OPERATION / TIDE WALL", 22, UITheme.TEXT, true)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemies_label = UITheme.label("ENEMIES 0", 20, UITheme.ACCENT, true)
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := UITheme.row(16)
	round_label = UITheme.label("ROUND 1/3", 18, UITheme.MUTED)
	timer_label = UITheme.label("00:00", 18, UITheme.MUTED)
	row.add_child(round_label)
	row.add_child(timer_label)
	row.alignment = BoxContainer.ALIGNMENT_END
	info.add_child(mission_label)
	info.add_child(enemies_label)
	info.add_child(row)
	var panel := _glass(info, 14)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -320
	panel.offset_right = -18
	panel.offset_top = 14
	root.add_child(panel)

func _build_right() -> void:
	var column := UITheme.column(14)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	column.offset_left = -170
	column.offset_right = -24
	column.offset_top = -150
	column.offset_bottom = 170
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	aim_button = UITheme.button("AIM", func(): aim_pressed.emit(); _pulse(aim_button))
	aim_button.custom_minimum_size = Vector2(120, 72)
	column.add_child(aim_button)
	fire_button = Button.new()
	fire_button.text = "FIRE"
	fire_button.custom_minimum_size = Vector2(148, 148)
	fire_button.add_theme_font_size_override("font_size", 30)
	var style := UITheme.style(Color(0.62, 0.22, 0.12, 0.72), Color(0.95, 0.62, 0.3), 74)
	fire_button.add_theme_stylebox_override("normal", style)
	fire_button.add_theme_stylebox_override("hover", UITheme.style(Color(0.72, 0.28, 0.16, 0.8), UITheme.ACCENT, 74))
	fire_button.add_theme_stylebox_override("pressed", UITheme.style(Color(0.85, 0.4, 0.2, 0.85), UITheme.TEXT, 74))
	fire_button.button_down.connect(func(): fire_down.emit(); fire_button.scale = Vector2.ONE * 0.94)
	fire_button.button_up.connect(func(): fire_up.emit(); fire_button.scale = Vector2.ONE)
	fire_button.pivot_offset = Vector2(74, 74)
	column.add_child(fire_button)
	var weapon := UITheme.button("WEAPON", func(): weapon_pressed.emit())
	weapon.custom_minimum_size = Vector2(120, 60)
	column.add_child(weapon)
	root.add_child(column)

func _build_bottom() -> void:
	var row := UITheme.row(12)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 18
	row.offset_right = -18
	row.offset_top = -104
	row.offset_bottom = -16
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var health_box := UITheme.column(4)
	health_label = UITheme.label("EMPLACEMENT 100%", 18, UITheme.TEXT, true)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(230, 22)
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_box.add_child(health_label)
	health_box.add_child(health_bar)
	row.add_child(_glass(health_box, 12))
	var ammo_box := UITheme.column(0)
	weapon_label = UITheme.label("TWIN M2 HEAVY", 18, UITheme.MUTED, true)
	ammo_label = UITheme.label("140 / 140", 30, UITheme.TEXT, true)
	ammo_box.add_child(weapon_label)
	ammo_box.add_child(ammo_label)
	row.add_child(_glass(ammo_box, 12))
	reload_button = UITheme.button("RELOAD", func(): reload_pressed.emit())
	reload_button.custom_minimum_size = Vector2(120, 64)
	row.add_child(reload_button)
	rocket_button = UITheme.button("ROCKET", func(): rocket_pressed.emit())
	rocket_button.custom_minimum_size = Vector2(120, 64)
	row.add_child(rocket_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	for id in ["repair", "airstrike", "helicopter", "airdrop"]:
		var button := UITheme.button(id.to_upper(), func(): support_pressed.emit(id))
		button.custom_minimum_size = Vector2(112, 64)
		button.disabled = true
		support_buttons[id] = button
		row.add_child(button)
	root.add_child(row)

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(shade)
	var box := UITheme.column(14)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -240
	box.offset_right = 240
	box.offset_top = -220
	box.offset_bottom = 220
	box.add_child(UITheme.label("PAUSED / SETTINGS", 34, UITheme.TEXT, true))
	quality_select = OptionButton.new()
	for item in ["AUTO / ADAPTIVE", "LOW", "MEDIUM", "HIGH", "ULTRA"]:
		quality_select.add_item(item)
	quality_select.select(["auto", "low", "medium", "high", "ultra"].find(Profile.data.settings.quality))
	quality_select.item_selected.connect(func(index): Profile.set_setting("quality", ["auto", "low", "medium", "high", "ultra"][index]))
	box.add_child(quality_select)
	box.add_child(UITheme.button("RESUME", func(): resume_pressed.emit(), true))
	box.add_child(UITheme.button("RESTART", func(): restart_pressed.emit()))
	box.add_child(UITheme.button("EXIT TO COMMAND", func(): exit_pressed.emit()))
	pause_panel.add_child(_glass(box, 24))
	root.add_child(pause_panel)

func _build_results() -> void:
	result_panel = Control.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.04, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.add_child(shade)
	var box := UITheme.column(14)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -180
	box.offset_bottom = 180
	result_title = UITheme.label("BEACHHEAD HELD", 42, UITheme.ACCENT, true)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body = UITheme.label("", 22, UITheme.TEXT)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	box.add_child(result_body)
	box.add_child(UITheme.button("REPLAY MILESTONE", func(): restart_pressed.emit(), true))
	box.add_child(UITheme.button("EXIT TO COMMAND", func(): exit_pressed.emit()))
	result_panel.add_child(_glass(box, 26))
	root.add_child(result_panel)

func update_state(data: Dictionary) -> void:
	mission_label.text = "OPERATION / " + String(data.get("mission", "TIDE WALL"))
	enemies_label.text = "ENEMIES %d" % int(data.get("remaining", 0))
	round_label.text = "ROUND %d/%d" % [int(data.get("round", 1)), int(data.get("rounds", 3))]
	var seconds: int = int(data.get("time", 0.0))
	timer_label.text = "%02d:%02d" % [int(seconds / 60.0), seconds % 60]
	health_bar.value = float(data.get("health", 100.0))
	health_label.text = "EMPLACEMENT %d%%" % int(data.get("health", 100.0))
	ammo_label.text = "%d / %d" % [int(data.get("ammo", 0)), int(data.get("magazine", 0))]
	weapon_label.text = String(data.get("weapon", ""))
	reload_button.disabled = bool(data.get("reloading", false))
	rocket_button.disabled = String(data.get("weapon_id", "")) == "rocket"
	auto_check.button_pressed = bool(data.get("auto", false))
	_update_pips(int(data.get("round", 1)), int(data.get("rounds", 3)))
	var supports: Array = data.get("supports", ["repair"])
	for id in support_buttons:
		support_buttons[id].disabled = not id in supports or bool(data.get("support_cooldown", false))

func _update_pips(round_number: int, rounds: int) -> void:
	if wave_pips.get_child_count() == rounds:
		for index in range(rounds):
			var pip: Label = wave_pips.get_child(index) as Label
			pip.modulate = UITheme.ACCENT if index < round_number else Color(1, 1, 1, 0.28)
		return
	for child in wave_pips.get_children():
		child.queue_free()
	for index in range(rounds):
		var pip := UITheme.label("◆", 24, UITheme.ACCENT if index < round_number else Color(1, 1, 1, 0.28), true)
		wave_pips.add_child(pip)

func set_paused(visible: bool) -> void:
	pause_panel.visible = visible

func show_result(success: bool, stats: Dictionary) -> void:
	result_panel.visible = true
	result_title.text = "BEACHHEAD HELD" if success else "EMPLACEMENT LOST"
	result_body.text = "Rounds survived: %d\nEnemies neutralized: %d\nTime: %.1fs" % [int(stats.get("round", 1)), int(stats.get("kills", 0)), float(stats.get("time", 0.0))]

func flash_damage() -> void:
	var tween: Tween = create_tween()
	health_bar.modulate = Color(1.0, 0.45, 0.35)
	tween.tween_property(health_bar, "modulate", Color.WHITE, 0.35)

func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 0.95
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.16)
