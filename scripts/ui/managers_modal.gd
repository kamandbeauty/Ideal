class_name ManagersModal
extends Control
## Full-screen Roadside Empire Managers & Cards collection sheet:
## displays all 8 Managers, Rarity borders, Card progress, Bourbon 🥃 balance,
## automation status and 1-tap Card+Bourbon or Cash promotion!

signal closed
signal feedback(message: String)

var state: TownState
var _subtitle: Label
var _rows: Dictionary = {}
var _title: Label
var _close_btn: Button


func setup(town_state: TownState) -> void:
	state = town_state
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open() -> void:
	layout_direction = App.layout_direction()
	visible = true
	refresh()
	Sound.play("click", -12.0)


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = UiTheme.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_bottom", 46)
	add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	_title = _lbl(24, UiTheme.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.theme_type_variation = "GhostButton"
	_close_btn.custom_minimum_size = Vector2(46, 42)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.pressed.connect(close)
	header.add_child(_close_btn)

	_subtitle = _lbl(15, UiTheme.BOURBON)
	col.add_child(_subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for mgr_id in ManagerData.ORDER:
		_rows[mgr_id] = _build_row(list, mgr_id)


func _build_row(parent: VBoxContainer, mgr_id: String) -> Dictionary:
	var r_col := ManagerData.rarity_color(mgr_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.button_style(UiTheme.PANEL_SOFT, r_col, 14))
	parent.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var name_lbl := _lbl(17, UiTheme.TEXT)
	info.add_child(name_lbl)
	var fac_lbl := _lbl(13, r_col.darkened(0.42))
	info.add_child(fac_lbl)
	var cards_lbl := _lbl(13, UiTheme.MUTED)
	info.add_child(cards_lbl)

	var btn := Button.new()
	btn.theme_type_variation = "BlueButton"
	btn.custom_minimum_size = Vector2(168, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	var fac_id := str(ManagerData.data(mgr_id).get("facility", "gas_station"))
	btn.pressed.connect(func() -> void: _promote(fac_id))
	row.add_child(btn)

	return {"name": name_lbl, "fac": fac_lbl, "cards": cards_lbl, "btn": btn, "facility": fac_id}


func refresh() -> void:
	if state == null:
		return
	_title.text = "✨ " + App.t("managers.title")
	_subtitle.text = App.t("managers.subtitle", [App.format_number(state.bourbon)])

	for mgr_id in ManagerData.ORDER:
		var r: Dictionary = _rows[mgr_id]
		var fac_id := String(r["facility"])
		var b := state.business(fac_id)
		var lvl := b.manager_rank if b != null else 0
		var rarity_txt := App.t("rarity.%s" % ManagerData.rarity(mgr_id))
		(r["name"] as Label).text = (
			"%s %s · %s (Lv %s)"
			% [
				ManagerData.avatar(mgr_id),
				App.t("mgr.%s" % mgr_id),
				rarity_txt,
				App.format_number(lvl),
			]
		)
		var mult := ManagerData.income_multiplier(mgr_id, maxi(1, lvl))
		(r["fac"] as Label).text = (
			"%s %s · Profit x%.1f"
			% [
				BusinessData.icon(fac_id),
				App.t("business.%s.name" % fac_id),
				mult,
			]
		)
		var owned_cards := EmpireActions.cards_for(state, mgr_id)
		var need_cards := ManagerData.cards_needed(lvl)
		var need_bourbon := ManagerData.bourbon_needed(lvl)
		(r["cards"] as Label).text = (
			App
			. t(
				"managers.cards",
				[
					App.format_number(owned_cards),
					App.format_number(need_cards),
					App.format_number(need_bourbon),
				]
			)
		)

		var btn: Button = r["btn"]
		if b == null or not b.unlocked:
			btn.text = App.t("hud.locked", [App.format_number(BusinessData.star_required(fac_id))])
			btn.disabled = true
		elif not b.can_hire_manager():
			btn.text = App.t("hud.manager_max")
			btn.disabled = true
		elif EmpireActions.can_upgrade_manager_cards(state, fac_id):
			btn.text = App.t("managers.upgrade_cards", [App.format_number(need_bourbon)])
			btn.disabled = false
		else:
			var cash_cost := state.manager_cost(fac_id)
			btn.text = App.t("managers.upgrade_cash", [App.format_short(cash_cost)])
			btn.disabled = state.cash + 0.01 < cash_cost


func _promote(fac_id: String) -> void:
	if state.hire_manager(fac_id):
		Sound.play("hire", -4.0)
		App.tap(30)
		var b := state.business(fac_id)
		(
			feedback
			. emit(
				(
					App
					. t(
						"msg.manager_hired",
						[
							App.t("business.%s.name" % fac_id),
							App.t("manager.rank.%d" % b.manager_rank),
						]
					)
				)
			)
		)
		refresh()
	else:
		Sound.play("deny", -10.0)


func _lbl(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
