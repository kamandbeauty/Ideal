extends Control
## The city HUD: resources on top, category tabs and build buttons at the
## bottom, a toast line for feedback.

signal structure_chosen(id: String)
signal rotate_requested
signal undo_requested
signal demolish_requested
signal save_requested
signal menu_requested

const TOAST_TIME := 2.2

var _cash_label: Label
var _people_label: Label
var _income_label: Label
var _happy_label: Label
var _goal_label: Label
var _tabs: HBoxContainer
var _items: HBoxContainer
var _hint_label: Label
var _rotate_button: Button
var _undo_button: Button
var _demolish_button: Button
var _save_button: Button
var _menu_button: Button
var _toast: Label

var _category := "road"
var _selected := ""
var _demolish := false
var _item_buttons: Array[Button] = []
var _item_costs: Array[int] = []
var _item_ids: Array[String] = []
var _toast_time := 0.0
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


# --- Public API -------------------------------------------------------------

func refresh(state: CityState) -> void:
	_cash_label.text = "%s  %s" % [App.t("hud.cash"), _format_int(state.cash)]
	_people_label.text = "%s  %s" % [
		App.t("hud.population"),
		App.t("hud.population_value", [int(state.population), int(state.capacity)]),
	]
	_income_label.text = "%s  %s" % [
		App.t("hud.income"), App.t("hud.income_value", ["%.1f" % state.income_per_second()])
	]
	_happy_label.text = "%s  %s" % [
		App.t("hud.happiness"), App.t("hud.happiness_value", [int(round(state.happiness))])
	]
	var next := state.next_milestone()
	_goal_label.text = App.t("hud.all_goals") if next < 0 else App.t("hud.next_goal", [next])

	for i in _item_buttons.size():
		if i < _item_costs.size():
			_item_buttons[i].disabled = state.cash < float(_item_costs[i])
	_update_tools(state)


func set_selection(id: String) -> void:
	_selected = id
	_build_items()
	_update_hint()
	_hint_label.modulate.a = 1.0


func set_demolish(enabled: bool) -> void:
	_demolish = enabled
	_demolish_button.theme_type_variation = "PrimaryButton" if enabled else "GhostButton"
	_update_hint()


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = TOAST_TIME


# --- Construction -----------------------------------------------------------

func _build() -> void:
	_built = true
	_build_top_bar()
	_build_bottom_bar()
	_build_toast()


func _build_top_bar() -> void:
	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_top = 12
	top.offset_right = -14
	top.offset_bottom = 86
	add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	top.add_child(row)

	_cash_label = _make_label(19, UiTheme.GOLD)
	row.add_child(_cash_label)
	_people_label = _make_label(19, UiTheme.ACCENT)
	row.add_child(_people_label)
	_income_label = _make_label(19, UiTheme.GOOD)
	row.add_child(_income_label)
	_happy_label = _make_label(19, UiTheme.TEXT)
	row.add_child(_happy_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_goal_label = _make_label(17, UiTheme.MUTED)
	row.add_child(_goal_label)

	_save_button = _make_button(96, 48)
	_save_button.pressed.connect(func() -> void: save_requested.emit())
	row.add_child(_save_button)

	_menu_button = _make_button(96, 48)
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(_menu_button)


func _build_bottom_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "BottomBar"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 14
	panel.offset_top = -206
	panel.offset_right = -14
	panel.offset_bottom = -12
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	tools.add_child(_tabs)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)

	_rotate_button = _make_button(110, 50, "GhostButton")
	_rotate_button.pressed.connect(func() -> void: rotate_requested.emit())
	tools.add_child(_rotate_button)

	_demolish_button = _make_button(110, 50, "GhostButton")
	_demolish_button.pressed.connect(func() -> void: demolish_requested.emit())
	tools.add_child(_demolish_button)

	_undo_button = _make_button(110, 50, "GhostButton")
	_undo_button.pressed.connect(func() -> void: undo_requested.emit())
	tools.add_child(_undo_button)

	_items = HBoxContainer.new()
	_items.add_theme_constant_override("separation", 8)
	column.add_child(_items)

	_hint_label = _make_label(16, UiTheme.MUTED)
	_hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_hint_label)


func _build_toast() -> void:
	_toast = _make_label(20, UiTheme.TEXT)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_left = 20
	_toast.offset_top = 96
	_toast.offset_right = -20
	_toast.offset_bottom = 140
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)


func _build_tabs() -> void:
	_clear(_tabs)
	for category in CityData.CATEGORIES:
		var button := _make_button(0, 50, "PrimaryButton" if category == _category else "GhostButton")
		button.text = App.t("category." + category)
		button.pressed.connect(_on_category_pressed.bind(category))
		_tabs.add_child(button)


func _build_items() -> void:
	_clear(_items)
	_item_buttons.clear()
	_item_costs.clear()
	_item_ids.clear()
	for id in CityData.ids_in_category(_category):
		var cost := CityData.cost(id)
		var button := _make_button(0, 58, "PrimaryButton" if id == _selected else "Button")
		button.text = "%s · %d" % [App.t("structure.%s.name" % id), cost]
		button.pressed.connect(_on_item_pressed.bind(id))
		_items.add_child(button)
		_item_buttons.append(button)
		_item_costs.append(cost)
		_item_ids.append(id)


# --- Helpers ----------------------------------------------------------------

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(min_width: int, height: int, variation: String = "GhostButton") -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(min_width, height)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _update_hint() -> void:
	if _demolish:
		_hint_label.text = App.t("hud.demolish")
	elif _selected.is_empty():
		_hint_label.text = App.t("hud.hint")
	else:
		_hint_label.text = App.t("structure.%s.desc" % _selected)


func _update_tools(_state: CityState) -> void:
	var rotatable := false
	if not _selected.is_empty():
		rotatable = bool(CityData.structure(_selected).get("rotatable", false))
	_rotate_button.visible = rotatable
	_rotate_button.disabled = not rotatable


func _format_int(value: float) -> String:
	var whole := int(floor(value))
	var digits := str(absi(whole))
	var text := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		text = digits[i] + text
		count += 1
		if count % 3 == 0 and i > 0:
			text = "," + text
	return ("-" if whole < 0 else "") + text


func _on_category_pressed(category: String) -> void:
	if _category == category:
		return
	_category = category
	_selected = ""
	_build_tabs()
	_build_items()
	_update_hint()


func _on_item_pressed(id: String) -> void:
	_selected = id
	_build_items()
	_update_hint()
	structure_chosen.emit(id)


func _on_language_changed(_language: String) -> void:
	layout_direction = App.layout_direction()
	_apply_language()


func _apply_language() -> void:
	_save_button.text = App.t("hud.save")
	_menu_button.text = App.t("hud.menu")
	_rotate_button.text = App.t("hud.rotate")
	_undo_button.text = App.t("hud.undo")
	_demolish_button.text = App.t("hud.demolish")
	_build_tabs()
	_build_items()
	_update_hint()
