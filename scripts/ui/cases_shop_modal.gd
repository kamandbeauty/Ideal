class_name CasesShopModal
extends Control
## Supply Cases, Bourbon Shop & Quick Empire Build list!
## Mode "cases" shows Free Crate, Standard/Rare/Epic Cases & Bourbon Barrel;
## Mode "build" shows all 8 facilities for rapid 1-tap building & upgrading!

signal closed
signal feedback(message: String)
signal facility_selected(id: String)

var state: TownState
var mode := "cases"
var _title: Label
var _subtitle: Label
var _cases_box: VBoxContainer
var _build_box: VBoxContainer
var _case_btns: Dictionary = {}
var _bourbon_btn: Button
var _build_rows: Dictionary = {}


func setup(town_state: TownState) -> void:
	state = town_state
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open(which_mode: String = "cases") -> void:
	mode = which_mode
	layout_direction = App.layout_direction()
	visible = true
	refresh()
	Sound.play("click", -12.0)


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.78)
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
	_title = _lbl(23, UiTheme.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.theme_type_variation = "GhostButton"
	close_btn.custom_minimum_size = Vector2(46, 42)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	_subtitle = _lbl(14, UiTheme.MUTED)
	col.add_child(_subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_cases_box = VBoxContainer.new()
	_cases_box.add_theme_constant_override("separation", 10)
	content.add_child(_cases_box)
	_build_cases_content()

	_build_box = VBoxContainer.new()
	_build_box.add_theme_constant_override("separation", 8)
	content.add_child(_build_box)
	_build_facilities_content()


func _build_cases_content() -> void:
	var defs := [
		{"id": "free_crate", "icon": "📦", "key": "cases.free", "col": UiTheme.GOOD},
		{"id": "common_case", "icon": "🧰", "key": "cases.common", "col": Color(0.54, 0.64, 0.78)},
		{"id": "rare_case", "icon": "💼", "key": "cases.rare", "col": Color(0.24, 0.62, 0.98)},
		{"id": "epic_case", "icon": "👑", "key": "cases.epic", "col": Color(0.76, 0.38, 0.98)},
	]
	for d in defs:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.button_style(Color(0.16, 0.20, 0.30), d["col"], 14))
		_cases_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var lbl := _lbl(16, Color.WHITE)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var btn := Button.new()
		btn.theme_type_variation = "GreenButton" if d["id"] == "free_crate" else "PurpleButton"
		btn.custom_minimum_size = Vector2(160, 50)
		btn.focus_mode = Control.FOCUS_NONE
		var cid := String(d["id"])
		btn.pressed.connect(func() -> void: _on_open_case(cid))
		row.add_child(btn)
		_case_btns[cid] = {"label": lbl, "btn": btn, "icon": d["icon"], "key": d["key"]}

	# Bourbon Barrel Gem Pack!
	var b_card := PanelContainer.new()
	b_card.add_theme_stylebox_override("panel", UiTheme.button_style(Color(0.24, 0.17, 0.12), UiTheme.BOURBON, 14))
	_cases_box.add_child(b_card)
	var b_row := HBoxContainer.new()
	b_card.add_child(b_row)
	var b_lbl := _lbl(16, UiTheme.GOLD)
	b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_row.add_child(b_lbl)
	_bourbon_btn = Button.new()
	_bourbon_btn.theme_type_variation = "PurpleButton"
	_bourbon_btn.custom_minimum_size = Vector2(160, 50)
	_bourbon_btn.focus_mode = Control.FOCUS_NONE
	_bourbon_btn.pressed.connect(_on_buy_bourbon)
	b_row.add_child(_bourbon_btn)
	_case_btns["bourbon_pack"] = {"label": b_lbl}


func _build_facilities_content() -> void:
	for id in BusinessData.ORDER:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.button_style(Color(0.16, 0.20, 0.30), BusinessData.accent(id), 14))
		_build_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var info := _lbl(16, Color.WHITE)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var btn := Button.new()
		btn.theme_type_variation = "GreenButton"
		btn.custom_minimum_size = Vector2(165, 50)
		btn.focus_mode = Control.FOCUS_NONE
		var captured: String = String(id)
		btn.pressed.connect(func() -> void: _on_quick_facility(captured))
		row.add_child(btn)
		_build_rows[id] = {"info": info, "btn": btn}


func refresh() -> void:
	if state == null:
		return
	var is_cases := mode == "cases"
	_cases_box.visible = is_cases
	_build_box.visible = not is_cases

	if is_cases:
		_title.text = "🧰 " + App.t("cases.title")
		_subtitle.text = App.t("cases.subtitle")
		for cid in ["free_crate", "common_case", "rare_case", "epic_case"]:
			var e: Dictionary = _case_btns[cid]
			(e["label"] as Label).text = "%s %s" % [e["icon"], App.t(String(e["key"]))]
			var btn: Button = e["btn"]
			if cid == "free_crate":
				if state.free_crate_cooldown <= 0.0:
					btn.text = App.t("cases.free_btn")
					btn.disabled = false
				else:
					btn.text = App.t("cases.free_wait", [App.format_number(ceil(state.free_crate_cooldown))])
					btn.disabled = true
			else:
				var g_cost := int(ManagerData.CASES[cid]["gem_cost"])
				btn.text = App.t("cases.open_gems", [App.format_number(g_cost)])
				btn.disabled = state.gems < g_cost
		(_case_btns["bourbon_pack"]["label"] as Label).text = "🥃 " + App.t("cases.bourbon_pack")
		_bourbon_btn.text = App.t("cases.open_gems", [App.format_number(15)])
		_bourbon_btn.disabled = state.gems < 15
	else:
		_title.text = "🔨 " + App.t("build.title")
		_subtitle.text = "💵 %s · ⭐ %s" % [
			App.format_short(state.cash),
			App.t("hud.star_lvl", [App.format_number(state.star_level())]),
		]
		for id in BusinessData.ORDER:
			var r: Dictionary = _build_rows[id]
			var b := state.business(id)
			var btn: Button = r["btn"]
			if not b.unlocked:
				var req_s := BusinessData.star_required(id)
				(r["info"] as Label).text = "%s %s\n%s" % [
					BusinessData.icon(id),
					App.t("business.%s.name" % id),
					App.t("business.%s.desc" % id),
				]
				if state.star_level() < req_s:
					btn.text = App.t("hud.locked", [App.format_number(req_s)])
					btn.disabled = true
				else:
					var uc := state.unlock_cost(id)
					btn.text = App.t("hud.unlock", [App.format_short(uc)])
					btn.disabled = state.cash + 0.01 < uc
			else:
				var rate := b.net_per_minute(state.traffic()) * state.income_multiplier()
				(r["info"] as Label).text = "%s %s · Lv %s\n💵 %s/min" % [
					BusinessData.icon(id),
					App.t("business.%s.name" % id),
					App.format_number(b.level),
					App.format_short(rate),
				]
				if b.can_upgrade_level():
					var c := state.upgrade_cost(id, 1)
					btn.text = App.t("hud.upgrade", [App.format_short(c)])
					btn.disabled = state.cash + 0.01 < c
				else:
					btn.text = App.t("hud.max_level")
					btn.disabled = true


func _on_open_case(cid: String) -> void:
	var loot := EmpireActions.open_case(state, cid)
	if loot.is_empty():
		Sound.play("deny", -10.0)
		return
	Sound.play("gem", -4.0)
	App.tap(36)
	feedback.emit(App.t("cases.reward_toast", [
		App.format_short(float(loot["cash"])),
		App.format_number(float(loot["bourbon"])),
		App.format_number(float(loot["card_count"])),
	]))
	refresh()


func _on_buy_bourbon() -> void:
	if EmpireActions.buy_bourbon_pack(state, 15, 60):
		Sound.play("cash", -5.0)
		App.tap(28)
		feedback.emit("+60 🥃 Bourbon!")
		refresh()
	else:
		Sound.play("deny", -10.0)


func _on_quick_facility(id: String) -> void:
	var b := state.business(id)
	if b != null and not b.unlocked:
		if state.unlock_business(id):
			Sound.play("build", -4.0)
			App.tap(36)
			feedback.emit(App.t("msg.unlocked", [App.t("business.%s.name" % id)]))
			refresh()
			return
	elif b != null and b.can_upgrade_level():
		if state.upgrade_business(id, 1):
			Sound.play("upgrade", -5.0)
			App.tap(22)
			refresh()
			return
	close()
	facility_selected.emit(id)


func _lbl(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
