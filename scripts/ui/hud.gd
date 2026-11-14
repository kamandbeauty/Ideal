extends Control
## The in-game HUD: resources on top, context panel at the bottom, overlays for
## pause and for the end of a run.
##
## Built in code so the layout, the Persian font and the RTL direction are all
## applied in one place.

signal build_requested(kind: String)
signal upgrade_requested
signal sell_requested
signal start_wave_requested
signal speed_requested
signal pause_requested
signal resume_requested
signal quit_requested
signal retry_requested
signal menu_requested

const TOAST_TIME := 2.4

var _gold_label: Label
var _core_label: Label
var _wave_label: Label
var _speed_button: Button
var _pause_button: Button
var _status_label: Label
var _start_button: Button
var _panel: PanelContainer
var _panel_title: Label
var _panel_hint: Label
var _panel_actions: HBoxContainer
var _toast: Label
var _pause_overlay: Control
var _pause_title: Label
var _resume_button: Button
var _quit_button: Button
var _result_overlay: Control
var _result_title: Label
var _result_body: Label
var _result_retry: Button
var _result_menu: Button

var _context: Dictionary = {}
var _cost_buttons: Array[Button] = []
var _costs: Array[int] = []
var _toast_time := 0.0
var _speed := 1
var _built := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _built:
		_build()
	_apply_language()
	App.language_changed.connect(_on_language_changed)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		_toast.modulate.a = clampf(_toast_time / 0.35, 0.0, 1.0)
	elif _toast.modulate.a != 0.0:
		_toast.modulate.a = 0.0


# --- Public API used by the battle -----------------------------------------

func refresh(state: GameState) -> void:
	_gold_label.text = "%s  %d" % [App.t("hud.gold"), state.gold]
	_core_label.text = "%s  %d/%d" % [App.t("hud.core"), state.core, GameState.CORE_MAX]
	_wave_label.text = App.t("hud.wave", [maxi(state.wave, 1), GameState.TOTAL_WAVES])
	_context["gold"] = state.gold
	_refresh_affordability(state.gold)


func show_pad_panel(gold: int) -> void:
	_context = {"kind": "pad", "gold": gold}
	_panel_title.text = App.t("build.title")
	_panel_hint.text = App.t("build.choose")
	_clear(_panel_actions)
	_cost_buttons.clear()
	_costs.clear()
	for kind in TowerData.TYPES:
		var cost := TowerData.build_cost(kind)
		var button := _make_button(
			"%s · %d" % [_tower_name(kind), cost], "Button", Vector2(152, 60)
		)
		button.pressed.connect(func() -> void: build_requested.emit(kind))
		button.disabled = gold < cost
		_panel_actions.add_child(button)
		_cost_buttons.append(button)
		_costs.append(cost)
	var close := _make_button(App.t("hud.close"), "GhostButton", Vector2(96, 60))
	close.pressed.connect(hide_panels)
	_panel_actions.add_child(close)
	_panel.visible = true


func show_tower_panel(tower: Tower, gold: int) -> void:
	_context = {"kind": "tower", "tower": tower, "gold": gold}
	var stats := TowerData.stats(tower.kind, tower.level)
	_panel_title.text = "%s — %s" % [
		_tower_name(tower.kind), App.t("build.level", [tower.level])
	]
	_panel_hint.text = "%s  ·  %s  ·  %s" % [
		App.t("build.damage", [_num(float(stats.get("damage", 0.0)))]),
		App.t("build.range", [_num(float(stats.get("range", 0.0)))]),
		App.t("build.rate", [_num(1.0 / maxf(0.1, float(stats.get("cooldown", 1.0))))]),
	]
	_clear(_panel_actions)
	_cost_buttons.clear()
	_costs.clear()

	var upgrade_cost := TowerData.upgrade_cost(tower.kind, tower.level)
	if upgrade_cost > 0:
		var upgrade := _make_button(
			App.t("build.upgrade", [upgrade_cost]), "PrimaryButton", Vector2(190, 60)
		)
		upgrade.pressed.connect(func() -> void: upgrade_requested.emit())
		upgrade.disabled = gold < upgrade_cost
		_panel_actions.add_child(upgrade)
		_cost_buttons.append(upgrade)
		_costs.append(upgrade_cost)
	else:
		_panel_hint.text += "  ·  " + App.t("build.max_level")

	var sell := _make_button(
		App.t("build.sell", [TowerData.sell_value(tower.kind, tower.level)]),
		"DangerButton",
		Vector2(170, 60)
	)
	sell.pressed.connect(func() -> void: sell_requested.emit())
	_panel_actions.add_child(sell)

	var close := _make_button(App.t("hud.close"), "GhostButton", Vector2(96, 60))
	close.pressed.connect(hide_panels)
	_panel_actions.add_child(close)
	_panel.visible = true


func hide_panels() -> void:
	_context = {}
	_panel_title.text = App.t("build.tap_pad")
	_panel_hint.text = App.t("menu.controls")
	_clear(_panel_actions)
	_cost_buttons.clear()
	_costs.clear()
	_panel.visible = true


func set_wave_status(text: String) -> void:
	_status_label.text = text


func show_start_button(visible_button: bool) -> void:
	_start_button.visible = visible_button


func set_speed(speed: int) -> void:
	_speed = speed
	_speed_button.text = App.t("hud.speed", [speed])


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = TOAST_TIME


func show_pause(paused: bool) -> void:
	_pause_overlay.visible = paused


func show_result(victory: bool, survived: int, total: int) -> void:
	_result_title.text = App.t("hud.victory" if victory else "hud.defeat")
	_result_title.add_theme_color_override(
		"font_color", UiTheme.GOOD if victory else UiTheme.DANGER
	)
	_result_body.text = App.t("hud.result_waves", [survived, total])
	_result_overlay.visible = true


# --- Construction -----------------------------------------------------------

func _build() -> void:
	_built = true

	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_top = 12
	top.offset_right = -14
	top.offset_bottom = 86
	add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	top.add_child(row)

	_gold_label = _make_label("", 21, UiTheme.GOLD)
	row.add_child(_gold_label)
	_core_label = _make_label("", 21, UiTheme.ACCENT)
	row.add_child(_core_label)
	_wave_label = _make_label("", 21, UiTheme.TEXT)
	row.add_child(_wave_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_speed_button = _make_button("", "GhostButton", Vector2(150, 50))
	_speed_button.pressed.connect(func() -> void: speed_requested.emit())
	row.add_child(_speed_button)

	_pause_button = _make_button("", "GhostButton", Vector2(130, 50))
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	row.add_child(_pause_button)

	_build_bottom_panel()
	_build_toast()
	_build_pause_overlay()
	_build_result_overlay()


func _build_bottom_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "BottomPanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 14
	_panel.offset_top = -188
	_panel.offset_right = -14
	_panel.offset_bottom = -12
	add_child(_panel)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	_panel.add_child(content)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	content.add_child(left)

	_status_label = _make_label("", 19, UiTheme.TEXT)
	left.add_child(_status_label)

	_start_button = _make_button("", "PrimaryButton", Vector2(230, 58))
	_start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	left.add_child(_start_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 6)
	content.add_child(right)

	_panel_title = _make_label("", 20, UiTheme.ACCENT)
	right.add_child(_panel_title)

	_panel_hint = _make_label("", 16, UiTheme.MUTED)
	right.add_child(_panel_hint)

	_panel_actions = HBoxContainer.new()
	_panel_actions.add_theme_constant_override("separation", 10)
	right.add_child(_panel_actions)


func _build_toast() -> void:
	_toast = _make_label("", 20, UiTheme.TEXT)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_left = 20
	_toast.offset_top = 96
	_toast.offset_right = -20
	_toast.offset_bottom = 140
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)


func _build_pause_overlay() -> void:
	_pause_overlay = _build_overlay("PauseOverlay")
	var panel := _overlay_panel(_pause_overlay)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	_pause_title = _make_label("", 34, UiTheme.TEXT)
	_pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_pause_title)

	_resume_button = _make_button("", "PrimaryButton", Vector2(300, 64))
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(_resume_button)

	_quit_button = _make_button("", "GhostButton", Vector2(300, 60))
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(_quit_button)

	_pause_overlay.visible = false


func _build_result_overlay() -> void:
	_result_overlay = _build_overlay("ResultOverlay")
	var panel := _overlay_panel(_result_overlay)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	_result_title = _make_label("", 40, UiTheme.TEXT)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)

	_result_body = _make_label("", 20, UiTheme.MUTED)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_body)

	_result_retry = _make_button("", "PrimaryButton", Vector2(320, 64))
	_result_retry.pressed.connect(func() -> void: retry_requested.emit())
	box.add_child(_result_retry)

	_result_menu = _make_button("", "GhostButton", Vector2(320, 60))
	_result_menu.pressed.connect(func() -> void: menu_requested.emit())
	box.add_child(_result_menu)

	_result_overlay.visible = false


func _build_overlay(node_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.72)
	overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	return overlay


func _overlay_panel(overlay: Control) -> PanelContainer:
	var center := overlay.get_child(1) as CenterContainer
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	return panel


# --- Helpers ---------------------------------------------------------------

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String, variation: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	return button


func _refresh_affordability(gold: int) -> void:
	for i in _cost_buttons.size():
		if i < _costs.size():
			_cost_buttons[i].disabled = gold < _costs[i]


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _tower_name(kind: String) -> String:
	return App.t("tower.%s.name" % kind)


func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _on_language_changed(_language: String) -> void:
	layout_direction = App.layout_direction()
	_apply_language()
	_refresh_context()


func _apply_language() -> void:
	_speed_button.text = App.t("hud.speed", [_speed])
	_pause_button.text = App.t("hud.pause")
	_start_button.text = App.t("hud.start_wave")
	_pause_title.text = App.t("hud.paused")
	_resume_button.text = App.t("hud.resume")
	_quit_button.text = App.t("hud.quit")
	_result_retry.text = App.t("hud.retry")
	_result_menu.text = App.t("hud.menu")
	if _context.is_empty():
		hide_panels()


func _refresh_context() -> void:
	match str(_context.get("kind", "")):
		"pad":
			show_pad_panel(int(_context.get("gold", 0)))
		"tower":
			var tower: Tower = _context.get("tower")
			if is_instance_valid(tower):
				show_tower_panel(tower, int(_context.get("gold", 0)))
			else:
				hide_panels()
		_:
			hide_panels()
