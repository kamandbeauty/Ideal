class_name StationSheet
extends PanelContainer
## Bottom upgrade & renovation sheet opened when tapping any facility:
## - Level 1..100 milestone bar (Lv 10, 25, 50, 75, 100 -> x2 Profit + ⭐1)
## - Assigned Manager card slot (Cards + Bourbon 🥃 upgrade & Automation status)
## - x1 / x5 / x10 multiplier toggle + big Green UPGRADE button
## - 3 Equipment / Bay upgrade buttons (Service Bays, Speed Tech, Value Tech).

signal closed
signal action_feedback(message: String)

var session: Node
var state: TownState
var facility_id := ""
var buy_steps := 1

var _title: Label
var _desc: Label
var _milestone_label: Label
var _milestone_bar: ProgressBar
var _stats_label: Label
var _mgr_title: Label
var _mgr_status: Label
var _mgr_btn: Button
var _step_buttons: Dictionary = {}
var _upgrade_btn: Button
var _unlock_btn: Button
var _vault_btn: Button
var _branch_box: HBoxContainer
var _branch_btns: Dictionary = {}


func setup(session_node: Node) -> void:
	session = session_node
	state = session.state
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 12
	offset_right = -12
	offset_bottom = -114
	offset_top = -590
	visible = false
	_build()


func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)

	_title = _lbl(22, UiTheme.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	for step in [1, 5, 10]:
		var sbtn := Button.new()
		sbtn.text = "x%d" % step
		sbtn.custom_minimum_size = Vector2(48, 36)
		sbtn.focus_mode = Control.FOCUS_NONE
		sbtn.add_theme_font_size_override("font_size", 14)
		var captured := step
		sbtn.pressed.connect(func() -> void:
			buy_steps = captured
			Sound.play("click", -12.0)
			refresh())
		header.add_child(sbtn)
		_step_buttons[step] = sbtn

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.theme_type_variation = "GhostButton"
	close_btn.custom_minimum_size = Vector2(42, 38)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_btn)

	_desc = _lbl(14, UiTheme.MUTED)
	col.add_child(_desc)

	_milestone_bar = ProgressBar.new()
	_milestone_bar.show_percentage = false
	_milestone_bar.custom_minimum_size = Vector2(0, 14)
	var bg_sb := UiTheme.slim_style(Color(0.08, 0.10, 0.16), UiTheme.BORDER, 7)
	_milestone_bar.add_theme_stylebox_override("background", bg_sb)
	_milestone_bar.add_theme_stylebox_override("fill", UiTheme.slim_style(UiTheme.GOLD, UiTheme.GOLD, 7))
	col.add_child(_milestone_bar)

	_milestone_label = _lbl(13, UiTheme.GOLD)
	col.add_child(_milestone_label)

	_stats_label = _lbl(15, UiTheme.GOOD)
	col.add_child(_stats_label)

	# Manager Card Box inside the station sheet!
	var mgr_panel := PanelContainer.new()
	mgr_panel.add_theme_stylebox_override("panel", UiTheme.button_style(Color(0.16, 0.20, 0.31), UiTheme.BORDER, 12))
	col.add_child(mgr_panel)

	var mgr_row := HBoxContainer.new()
	mgr_row.add_theme_constant_override("separation", 10)
	mgr_panel.add_child(mgr_row)

	var mgr_info := VBoxContainer.new()
	mgr_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgr_info.add_theme_constant_override("separation", 2)
	mgr_row.add_child(mgr_info)

	_mgr_title = _lbl(15, UiTheme.TEXT)
	mgr_info.add_child(_mgr_title)
	_mgr_status = _lbl(13, UiTheme.MUTED)
	mgr_info.add_child(_mgr_status)

	_mgr_btn = Button.new()
	_mgr_btn.theme_type_variation = "PurpleButton"
	_mgr_btn.custom_minimum_size = Vector2(168, 48)
	_mgr_btn.focus_mode = Control.FOCUS_NONE
	_mgr_btn.add_theme_font_size_override("font_size", 14)
	_mgr_btn.pressed.connect(_on_manager_pressed)
	mgr_row.add_child(_mgr_btn)

	# 3 Equipment / Bay upgrade buttons side-by-side!
	_branch_box = HBoxContainer.new()
	_branch_box.add_theme_constant_override("separation", 6)
	col.add_child(_branch_box)
	for br in BusinessData.BRANCHES:
		var b_btn := Button.new()
		b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_btn.custom_minimum_size = Vector2(0, 56)
		b_btn.focus_mode = Control.FOCUS_NONE
		b_btn.add_theme_font_size_override("font_size", 13)
		var captured_br := br
		b_btn.pressed.connect(func() -> void: _on_branch_pressed(captured_br))
		_branch_box.add_child(b_btn)
		_branch_btns[br] = b_btn

	_vault_btn = Button.new()
	_vault_btn.theme_type_variation = "GhostButton"
	_vault_btn.custom_minimum_size = Vector2(0, 42)
	_vault_btn.focus_mode = Control.FOCUS_NONE
	_vault_btn.pressed.connect(_on_collect_vault)
	col.add_child(_vault_btn)

	_upgrade_btn = Button.new()
	_upgrade_btn.theme_type_variation = "GreenButton"
	_upgrade_btn.custom_minimum_size = Vector2(0, 56)
	_upgrade_btn.focus_mode = Control.FOCUS_NONE
	_upgrade_btn.add_theme_font_size_override("font_size", 19)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	col.add_child(_upgrade_btn)

	_unlock_btn = Button.new()
	_unlock_btn.theme_type_variation = "GreenButton"
	_unlock_btn.custom_minimum_size = Vector2(0, 56)
	_unlock_btn.focus_mode = Control.FOCUS_NONE
	_unlock_btn.add_theme_font_size_override("font_size", 19)
	_unlock_btn.pressed.connect(_on_unlock_pressed)
	col.add_child(_unlock_btn)


func open_for(id: String) -> void:
	facility_id = id
	visible = true
	refresh()


func refresh() -> void:
	if not visible or facility_id.is_empty() or state == null:
		return
	var b := state.business(facility_id)
	if b == null:
		return
	for step in _step_buttons:
		var sb: Button = _step_buttons[step]
		sb.theme_type_variation = "PurpleButton" if buy_steps == int(step) else "GhostButton"
		sb.visible = b.unlocked

	var req_star_txt := App.format_number(BusinessData.star_required(facility_id))
	var lvl_txt := App.t("hud.level", [App.format_number(b.level)]) if b.unlocked else App.t("hud.locked", [req_star_txt])
	_title.text = "%s %s · %s" % [
		BusinessData.icon(facility_id),
		App.t("business.%s.name" % facility_id),
		lvl_txt,
	]
	_desc.text = App.t("business.%s.desc" % facility_id)

	if not b.unlocked:
		_milestone_bar.visible = false
		_milestone_label.visible = false
		_branch_box.visible = false
		_vault_btn.visible = false
		_upgrade_btn.visible = false
		_mgr_btn.get_parent().get_parent().visible = false
		_unlock_btn.visible = true
		var req_star := BusinessData.star_required(facility_id)
		var cost := state.unlock_cost(facility_id)
		_stats_label.text = "💵 $%s / customer" % App.format_short(b.price())
		if state.star_level() < req_star:
			_unlock_btn.text = App.t("hud.locked", [App.format_number(req_star)])
			_unlock_btn.disabled = true
		else:
			_unlock_btn.text = App.t("hud.unlock", [App.format_short(cost)])
			_unlock_btn.disabled = state.cash + 0.01 < cost
		return

	_milestone_bar.visible = true
	_milestone_label.visible = true
	_branch_box.visible = true
	_upgrade_btn.visible = true
	_unlock_btn.visible = false
	_mgr_btn.get_parent().get_parent().visible = true

	var prev_m := BusinessData.previous_milestone(b.level)
	var next_m := BusinessData.next_milestone(b.level)
	_milestone_bar.min_value = float(prev_m)
	_milestone_bar.max_value = float(maxi(prev_m + 1, next_m))
	_milestone_bar.value = float(b.level)
	_milestone_label.text = App.t("hud.renovation_warn", [
		App.format_number(next_m),
		App.format_number(BusinessData.automation_manager_level(next_m)),
	])

	var tr := state.traffic()
	var per_min := b.net_per_minute(tr) * state.income_multiplier() * state.event_income()
	_stats_label.text = "💵 %s · %s · %s" % [
		App.t("hud.income_value", [App.format_short(per_min)]),
		App.t("hud.capacity_value", [App.format_number(b.active_bays())]),
		App.t("hud.efficiency", ["%.1f" % b.efficiency()]),
	]

	_refresh_manager_box(b)
	_refresh_branches(b)

	_vault_btn.visible = (not b.is_automated()) and b.vault_cash >= 2.0
	if _vault_btn.visible:
		_vault_btn.text = "🗄️ " + App.t("hud.vault_collect", [App.format_short(b.vault_cash)])

	if not b.can_upgrade_level():
		_upgrade_btn.text = App.t("hud.max_level")
		_upgrade_btn.disabled = true
	else:
		var steps := mini(buy_steps, BusinessData.MAX_LEVEL - b.level)
		var u_cost := state.upgrade_cost(facility_id, steps)
		var step_prefix := ("x%d · " % steps) if steps > 1 else ""
		_upgrade_btn.text = step_prefix + App.t("hud.upgrade", [App.format_short(u_cost)])
		_upgrade_btn.disabled = state.cash + 0.01 < u_cost


func _refresh_manager_box(b: BusinessState) -> void:
	var mgr_id := BusinessData.manager_id(facility_id)
	var rarity_txt := App.t("rarity.%s" % ManagerData.rarity(mgr_id))
	_mgr_title.text = "%s %s (%s · Lv %s)" % [
		ManagerData.avatar(mgr_id),
		App.t("mgr.%s" % mgr_id),
		rarity_txt,
		App.format_number(b.manager_rank),
	]
	if b.is_automated():
		_mgr_status.text = App.t("hud.automated")
		_mgr_status.add_theme_color_override("font_color", UiTheme.GOOD)
	else:
		_mgr_status.text = App.t("hud.manual_need", [App.format_number(b.required_manager_level())])
		_mgr_status.add_theme_color_override("font_color", UiTheme.BOURBON)

	if not b.can_hire_manager():
		_mgr_btn.text = App.t("hud.manager_max")
		_mgr_btn.disabled = true
	elif EmpireActions.can_upgrade_manager_cards(state, facility_id):
		var b_need := ManagerData.bourbon_needed(b.manager_rank)
		_mgr_btn.text = App.t("managers.upgrade_cards", [App.format_number(b_need)])
		_mgr_btn.disabled = false
	else:
		var c_cost := state.manager_cost(facility_id)
		_mgr_btn.text = App.t("managers.upgrade_cash", [App.format_short(c_cost)])
		_mgr_btn.disabled = state.cash + 0.01 < c_cost


func _refresh_branches(b: BusinessState) -> void:
	for br in BusinessData.BRANCHES:
		var btn: Button = _branch_btns[br]
		var cur := b.branch_level(br)
		var cap := b.max_branch_for(br)
		var title := App.t(BusinessData.branch_label_key(br))
		if cur >= cap:
			btn.text = "%s\nMAX (%s)" % [title, App.format_number(cur)]
			btn.disabled = true
		else:
			var cost := state.branch_cost(facility_id, br)
			btn.text = "%s (%s/%s)\n💵 %s" % [
				title, App.format_number(cur), App.format_number(cap), App.format_short(cost)
			]
			btn.disabled = (not b.can_upgrade_branch(br)) or state.cash + 0.01 < cost


func _on_upgrade_pressed() -> void:
	var b := state.business(facility_id)
	if b == null:
		return
	var steps := mini(buy_steps, BusinessData.MAX_LEVEL - b.level)
	if state.upgrade_business(facility_id, steps):
		Sound.play("upgrade", -5.0)
		App.tap(24)
		action_feedback.emit(App.t("msg.upgraded", [
			App.t("business.%s.name" % facility_id),
			App.format_number(b.level),
		]))
		refresh()
	else:
		Sound.play("deny", -10.0)


func _on_unlock_pressed() -> void:
	if state.unlock_business(facility_id):
		Sound.play("build", -4.0)
		App.tap(36)
		action_feedback.emit(App.t("msg.unlocked", [App.t("business.%s.name" % facility_id)]))
		refresh()
	else:
		Sound.play("deny", -10.0)


func _on_branch_pressed(branch: String) -> void:
	if state.upgrade_branch(facility_id, branch):
		Sound.play("upgrade", -6.0)
		App.tap(22)
		refresh()
	else:
		Sound.play("deny", -10.0)


func _on_manager_pressed() -> void:
	if state.hire_manager(facility_id):
		var b := state.business(facility_id)
		Sound.play("hire", -4.0)
		App.tap(32)
		action_feedback.emit(App.t("msg.manager_hired", [
			App.t("business.%s.name" % facility_id),
			App.t("manager.rank.%d" % b.manager_rank),
		]))
		refresh()
	else:
		Sound.play("deny", -10.0)


func _on_collect_vault() -> void:
	var got := state.collect_vault(facility_id)
	if got > 0.0:
		Sound.play("cash", -5.0)
		App.tap(20)
		if session != null and session.view != null:
			session.view.pop_income(facility_id, got)
		refresh()


func _lbl(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
