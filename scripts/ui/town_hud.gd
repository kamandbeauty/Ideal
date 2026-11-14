extends Control
## The in-game interface: the resource bar, one card per business, the detail
## panel with upgrades and managers, and the offline-income report.

var session: Node
var state: TownState
var selected_id := ""

var _town_label: Label
var _cash_label: Label
var _gems_label: Label
var _reputation_label: Label
var _hint: Label
var _cards: Dictionary = {}
var _panel: PanelContainer
var _panel_title: Label
var _panel_desc: Label
var _panel_stats: Label
var _branches_box: GridContainer
var _branch_buttons: Dictionary = {}
var _manager_row: HBoxContainer
var _manager_label: Label
var _manager_button: Button
var _upgrade_button: Button
var _unlock_button: Button
var _offline_layer: Control
var _offline_body: Label
var _save_button: Button
var _menu_button: Button
var _close_button: Button
var _offline_title: Label
var _toast_panel: PanelContainer
var _toast: Label

var _toast_timer := 0.0
var _refresh_timer := 0.0


func setup(session_node: Node) -> void:
	session = session_node
	state = session.state
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_apply_language()
	_refresh()
	App.language_changed.connect(_on_language_changed)


func _build() -> void:
	_build_top_bar()
	_build_hint()
	_build_cards()
	_build_panel()
	_build_toast()
	_build_offline()


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 10
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)

	_town_label = _label(22, UiTheme.TEXT, true)
	row.add_child(_town_label)

	row.add_child(_spacer())

	_cash_label = _label(22, UiTheme.GOLD, true)
	row.add_child(_cash_label)
	_gems_label = _label(20, UiTheme.ACCENT, true)
	row.add_child(_gems_label)
	_reputation_label = _label(20, UiTheme.GOOD, true)
	row.add_child(_reputation_label)

	_save_button = _button("hud.save", "GhostButton", 96, 44)
	_save_button.pressed.connect(_on_save)
	row.add_child(_save_button)

	_menu_button = _button("hud.menu", "GhostButton", 96, 44)
	_menu_button.pressed.connect(_on_menu)
	row.add_child(_menu_button)


func _build_hint() -> void:
	_hint = _label(15, UiTheme.MUTED, false)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hint.offset_left = 20
	_hint.offset_top = 80
	_hint.offset_right = 520
	_hint.offset_bottom = 110
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _build_cards() -> void:
	var row := HBoxContainer.new()
	row.name = "BusinessCards"
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_top = -136
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row)

	for id in state.business_ids():
		row.add_child(_build_card(id))


func _build_card(id: String) -> Button:
	var card := Button.new()
	card.name = "Card_%s" % id
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 120)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(_on_card_pressed.bind(id))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 8
	box.offset_right = -12
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var title := _label(16, UiTheme.TEXT, true)
	box.add_child(title)
	var status := _label(13, UiTheme.MUTED, false)
	box.add_child(status)
	var income := _label(13, UiTheme.GOLD, false)
	box.add_child(income)

	_cards[id] = {"card": card, "title": title, "status": status, "income": income}
	return card


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "BusinessPanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -368
	_panel.offset_right = -12
	_panel.offset_top = 84
	_panel.offset_bottom = -150
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_panel_title = _label(22, UiTheme.TEXT, true)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_panel_title)
	_close_button = _button("hud.close", "GhostButton", 84, 40)
	_close_button.pressed.connect(_on_close_panel)
	header.add_child(_close_button)

	_panel_desc = _label(14, UiTheme.MUTED, false)
	_panel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_panel_desc)

	_panel_stats = _label(15, UiTheme.TEXT, false)
	column.add_child(_panel_stats)

	_branches_box = GridContainer.new()
	_branches_box.columns = 3
	_branches_box.add_theme_constant_override("h_separation", 6)
	_branches_box.add_theme_constant_override("v_separation", 6)
	column.add_child(_branches_box)
	for branch in BusinessData.BRANCHES:
		var button := Button.new()
		button.theme_type_variation = "Button"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_branch.bind(branch))
		_branches_box.add_child(button)
		_branch_buttons[branch] = button

	_manager_row = HBoxContainer.new()
	_manager_row.add_theme_constant_override("separation", 8)
	column.add_child(_manager_row)
	_manager_label = _label(15, UiTheme.ACCENT, false)
	_manager_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_manager_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_manager_row.add_child(_manager_label)
	_manager_button = _button("hud.hire_manager", "Button", 150, 46)
	_manager_button.pressed.connect(_on_manager)
	_manager_row.add_child(_manager_button)

	_unlock_button = _button("hud.unlock", "PrimaryButton", 0, 54)
	_unlock_button.add_theme_font_size_override("font_size", 18)
	_unlock_button.pressed.connect(_on_unlock)
	column.add_child(_unlock_button)

	_upgrade_button = _button("hud.upgrade", "PrimaryButton", 0, 54)
	_upgrade_button.add_theme_font_size_override("font_size", 18)
	_upgrade_button.pressed.connect(_on_upgrade)
	column.add_child(_upgrade_button)


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "Toast"
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.offset_left = -260
	_toast_panel.offset_right = 260
	_toast_panel.offset_top = -196
	_toast_panel.offset_bottom = -152
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	add_child(_toast_panel)
	_toast = _label(17, UiTheme.TEXT, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast)


func _build_offline() -> void:
	_offline_layer = Control.new()
	_offline_layer.name = "OfflineLayer"
	_offline_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offline_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_offline_layer.visible = false
	add_child(_offline_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offline_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offline_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	_offline_title = _label(26, UiTheme.GOLD, true)
	_offline_title.text = App.t("hud.offline_title")
	_offline_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_offline_title)

	_offline_body = _label(17, UiTheme.TEXT, false)
	_offline_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offline_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_offline_body)

	var collect := _button("hud.offline_claim", "PrimaryButton", 0, 56)
	collect.add_theme_font_size_override("font_size", 19)
	collect.pressed.connect(collect_offline)
	column.add_child(collect)


func _apply_language() -> void:
	layout_direction = App.layout_direction()
	_hint.text = App.t("hud.hint")
	_save_button.text = App.t("hud.save")
	_menu_button.text = App.t("hud.menu")
	_close_button.text = App.t("hud.close")
	_offline_title.text = App.t("hud.offline_title")
	for id in _cards:
		var card: Dictionary = _cards[id]
		(card["title"] as Label).text = _business_name(id)
	if _panel.visible and not selected_id.is_empty():
		_panel_title.text = _business_name(selected_id)
		_panel_desc.text = App.t("business.%s.desc" % selected_id)
	_refresh_panel()


func _on_language_changed(_language: String) -> void:
	_apply_language()


# --- Refreshing ------------------------------------------------------------

func tick(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false
	_refresh_timer += delta
	if _refresh_timer >= 0.2:
		_refresh_timer = 0.0
		_refresh()


func refresh() -> void:
	_refresh()


func _refresh() -> void:
	if state == null:
		return
	_town_label.text = "%s · %s" % [
		App.t("town.%s" % state.town_id), App.t("hud.town_level", [state.town_level()])
	]
	_cash_label.text = "%s %s" % [App.t("hud.cash"), _money(state.cash)]
	_gems_label.text = "%s %d" % [App.t("hud.gems"), state.gems]
	_reputation_label.text = "%s %d" % [App.t("hud.reputation"), int(state.reputation)]

	for id in _cards:
		_refresh_card(id)
	if _panel.visible and not selected_id.is_empty():
		_refresh_panel()


func _refresh_card(id: String) -> void:
	var business := state.business(id)
	if business == null:
		return
	var card: Dictionary = _cards[id]
	var card_button: Button = card["card"]
	var status: Label = card["status"]
	var income: Label = card["income"]

	if business.unlocked:
		status.text = App.t("hud.level", [business.level])
		status.add_theme_color_override("font_color", UiTheme.GOOD)
		income.text = App.t("hud.income_value", [_money(business.net_per_minute(state.traffic()))])
	else:
		status.text = App.t("hud.locked")
		status.add_theme_color_override("font_color", UiTheme.MUTED)
		income.text = App.t("hud.unlock", [_money(BusinessData.unlock_cost(id) * state.cost_scale())])

	if id == selected_id:
		var accent := BusinessData.accent(id)
		var style := UiTheme.button_style(accent.darkened(0.72), accent)
		card_button.add_theme_stylebox_override("normal", style)
		card_button.add_theme_stylebox_override("hover", style)
	else:
		card_button.remove_theme_stylebox_override("normal")
		card_button.remove_theme_stylebox_override("hover")


func _refresh_panel() -> void:
	if selected_id.is_empty():
		return
	var business := state.business(selected_id)
	if business == null:
		return

	_panel_title.text = _business_name(selected_id)
	_panel_desc.text = App.t("business.%s.desc" % selected_id)

	var traffic := state.traffic()
	_panel_stats.text = "\n".join([
		App.t("hud.income_value", [_money(business.net_per_minute(traffic))]),
		"%s: %d" % [App.t("hud.customers"), int(round(business.served_per_minute(traffic)))],
		App.t("hud.capacity_value", [int(round(business.capacity()))]),
		App.t("hud.upkeep_value", [_money(business.upkeep_per_minute())]),
		App.t("hud.efficiency", [int(round(business.efficiency() * 100.0))]),
	])

	var locked := not business.unlocked
	_branches_box.visible = not locked
	_manager_row.visible = not locked
	_unlock_button.visible = locked
	_upgrade_button.visible = not locked

	if locked:
		_unlock_button.text = App.t("hud.unlock", [
			_money(BusinessData.unlock_cost(selected_id) * state.cost_scale())
		])
		_unlock_button.disabled = not state.can_afford(
			BusinessData.unlock_cost(selected_id) * state.cost_scale()
		)
		return

	for branch in BusinessData.BRANCHES:
		var button: Button = _branch_buttons[branch]
		var level := business.branch_level(branch)
		if business.can_upgrade_branch(branch):
			button.text = "%s\n%s" % [
				App.t("hud.branch", [App.t("branch.%s" % branch), level]),
				_money(business.branch_cost(branch) * state.cost_scale()),
			]
			button.disabled = not state.can_afford(business.branch_cost(branch) * state.cost_scale())
		else:
			button.text = App.t("hud.branch", [App.t("branch.%s" % branch), level])
			button.disabled = true

	_manager_label.text = App.t("manager.rank.%d" % business.manager_rank)
	if business.can_hire_manager():
		_manager_button.text = App.t("hud.hire_manager", [
			_money(business.manager_cost() * state.cost_scale())
		])
		_manager_button.disabled = not state.can_afford(
			business.manager_cost() * state.cost_scale()
		)
	else:
		_manager_button.text = App.t("hud.manager_max")
		_manager_button.disabled = true

	if business.can_upgrade_level():
		_upgrade_button.text = App.t("hud.upgrade", [
			_money(business.upgrade_cost() * state.cost_scale())
		])
		_upgrade_button.disabled = not state.can_afford(
			business.upgrade_cost() * state.cost_scale()
		)
	else:
		_upgrade_button.text = App.t("hud.max_level")
		_upgrade_button.disabled = true


# --- Public API used by the session ---------------------------------------

func show_business(id: String) -> void:
	selected_id = id
	_panel.visible = true
	_refresh()
	_apply_language()


func hide_business() -> void:
	selected_id = ""
	_panel.visible = false


func show_offline(seconds: float, earnings: float) -> void:
	var total := int(maxf(seconds, 0.0))
	_offline_body.text = App.t("hud.offline_body", [
		total / 3600, (total % 3600) / 60, _money(earnings)
	])
	_offline_layer.visible = true
	_offline_layer.move_to_front()


# --- Buttons ---------------------------------------------------------------

func _on_card_pressed(id: String) -> void:
	Sound.play("res://assets/audio/toggle.ogg", -12.0)
	session.select_business(id)


func _on_close_panel() -> void:
	session.deselect()


func _on_upgrade() -> void:
	var business := state.business(selected_id)
	if business == null:
		return
	if state.upgrade_business(selected_id):
		Sound.play("res://assets/audio/placement-*.ogg", -8.0)
		_show_toast(App.t("msg.upgraded", [_business_name(selected_id), business.level]))
	else:
		_show_toast(App.t("msg.no_cash"))
	_refresh()


func _on_branch(branch: String) -> void:
	var business := state.business(selected_id)
	if business == null:
		return
	if state.upgrade_branch(selected_id, branch):
		Sound.play("res://assets/audio/placement-*.ogg", -8.0)
		_show_toast(App.t("msg.branch_upgraded", [
			_business_name(selected_id),
			App.t("branch.%s" % branch),
			business.branch_level(branch),
		]))
	else:
		_show_toast(App.t("msg.no_cash"))
	_refresh()


func _on_manager() -> void:
	var business := state.business(selected_id)
	if business == null:
		return
	if state.hire_manager(selected_id):
		Sound.play("res://assets/audio/toggle.ogg", -6.0)
		_show_toast(App.t("msg.manager_hired", [
			_business_name(selected_id), App.t("manager.rank.%d" % business.manager_rank)
		]))
	else:
		_show_toast(App.t("msg.no_cash"))
	_refresh()


func _on_unlock() -> void:
	if state.unlock_business(selected_id):
		Sound.play("res://assets/audio/placement-*.ogg", -6.0)
		_show_toast(App.t("msg.unlocked", [_business_name(selected_id)]))
	else:
		_show_toast(App.t("msg.no_cash"))
	_refresh()


func _on_save() -> void:
	session.save_now()
	_show_toast(App.t("msg.save_ok"))


func _on_menu() -> void:
	session.leave_to_menu()


func collect_offline() -> void:
	var report: Dictionary = session.claim_offline()
	_offline_layer.visible = false
	if not report.is_empty():
		_show_toast("+%s" % _money(float(report.get("earnings", 0.0))))
	_refresh()


# --- Small helpers ---------------------------------------------------------

func _show_toast(message: String) -> void:
	_toast.text = message
	_toast_panel.visible = true
	_toast_timer = 2.6


func _business_name(id: String) -> String:
	return App.t("business.%s.name" % id)


func _money(value: float) -> String:
	var amount := maxf(0.0, value)
	if amount >= 1000000.0:
		return "%.1fM" % (amount / 1000000.0)
	return str(int(round(amount)))


func _label(font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		var font: Font = load(UiTheme.FONT_BOLD)
		label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(key: String, variation: String, width: int, height: int) -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(width, height)
	button.text = App.t(key)
	return button


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
