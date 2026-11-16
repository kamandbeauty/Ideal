extends Control
## Territory Map & Expeditions Hub:
## Tab 1: 6 Story Mode US Territories (Dusty Canyon AZ -> Golden Strip Vegas)
## Tab 2: Live Expeditions (Monster Hills, Special Orders Convoy, Iron Bones)!

signal closed
signal travel_selected(town_id: String)
signal feedback(message: String)

var session: Node
var tab := "story"
var _title: Label
var _subtitle: Label
var _tab_story: Button
var _tab_exp: Button
var _story_box: VBoxContainer
var _exp_box: VBoxContainer
var _town_rows: Dictionary = {}
var _monster_btn: Button
var _order_btn: Button
var _iron_btn: Button


func setup(session_node: Node) -> void:
	session = session_node
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open(initial_tab: String = "story") -> void:
	tab = initial_tab
	layout_direction = App.layout_direction()
	visible = true
	refresh()
	Sound.play("click", -12.0)


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.80)
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

	_subtitle = _lbl(14, UiTheme.GOLD)
	col.add_child(_subtitle)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)

	_tab_story = Button.new()
	_tab_story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_story.custom_minimum_size = Vector2(0, 44)
	_tab_story.focus_mode = Control.FOCUS_NONE
	_tab_story.pressed.connect(func() -> void:
		tab = "story"
		refresh())
	tabs.add_child(_tab_story)

	_tab_exp = Button.new()
	_tab_exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_exp.custom_minimum_size = Vector2(0, 44)
	_tab_exp.focus_mode = Control.FOCUS_NONE
	_tab_exp.pressed.connect(func() -> void:
		tab = "exp"
		refresh())
	tabs.add_child(_tab_exp)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	_story_box = VBoxContainer.new()
	_story_box.add_theme_constant_override("separation", 8)
	body.add_child(_story_box)
	_build_story_rows()

	_exp_box = VBoxContainer.new()
	_exp_box.add_theme_constant_override("separation", 10)
	body.add_child(_exp_box)
	_build_expedition_cards()


func _build_story_rows() -> void:
	for id in TownData.ORDER:
		var card := PanelContainer.new()
		var sb := UiTheme.button_style(Color(0.16, 0.20, 0.30), TownData.ground_color(id), 14)
		card.add_theme_stylebox_override("panel", sb)
		_story_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_lbl := _lbl(17, Color.WHITE)
		info.add_child(name_lbl)
		var sub_lbl := _lbl(13, UiTheme.MUTED)
		info.add_child(sub_lbl)
		var btn := Button.new()
		btn.theme_type_variation = "GreenButton"
		btn.custom_minimum_size = Vector2(156, 48)
		btn.focus_mode = Control.FOCUS_NONE
		var captured: String = String(id)
		btn.pressed.connect(func() -> void: _on_travel(captured))
		row.add_child(btn)
		_town_rows[id] = {"name": name_lbl, "sub": sub_lbl, "btn": btn}


func _build_expedition_cards() -> void:
	_monster_btn = _exp_card(
		_exp_box, "exp.monster_title", "exp.monster_desc", Color(0.95, 0.45, 0.18), _on_monster_hills
	)
	_order_btn = _exp_card(_exp_box, "exp.order_title", "exp.order_desc", Color(0.24, 0.72, 0.96), _on_special_order)
	_iron_btn = _exp_card(_exp_box, "exp.iron_title", "exp.iron_desc", Color(0.94, 0.72, 0.20), _on_iron_bones)


func _exp_card(
	parent: VBoxContainer, title_k: String, desc_k: String, border: Color, cb: Callable
) -> Button:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.button_style(Color(0.16, 0.20, 0.30), border, 14))
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var t_lbl := _lbl(18, Color.WHITE)
	t_lbl.set_meta("k", title_k)
	v.add_child(t_lbl)
	var d_lbl := _lbl(13, UiTheme.MUTED)
	d_lbl.set_meta("k", desc_k)
	v.add_child(d_lbl)
	var btn := Button.new()
	btn.theme_type_variation = "PurpleButton"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(cb)
	btn.set_meta("t_lbl", t_lbl)
	btn.set_meta("d_lbl", d_lbl)
	v.add_child(btn)
	return btn


func refresh() -> void:
	var profile: Profile = Game.profile
	var st: TownState = session.state if session != null else Game.town
	if profile == null or st == null:
		return
	_title.text = "🧭 " + App.t("map.title")
	_subtitle.text = App.t("map.subtitle", [
		App.format_number(profile.best_star_level()),
		App.format_short(profile.total_income_per_minute()),
	])
	_tab_story.text = App.t("map.tab_story")
	_tab_exp.text = App.t("map.tab_expeditions")
	_tab_story.theme_type_variation = "PurpleButton" if tab == "story" else "GhostButton"
	_tab_exp.theme_type_variation = "PurpleButton" if tab == "exp" else "GhostButton"
	_story_box.visible = tab == "story"
	_exp_box.visible = tab == "exp"

	for id in TownData.ORDER:
		var r: Dictionary = _town_rows[id]
		(r["name"] as Label).text = "Ch.%s · %s" % [
			App.format_number(TownData.chapter(id)),
			App.t("town.%s" % id),
		]
		var rates := App.t("map.rates", [
			"%.1f" % TownData.income_multiplier(id),
			"%.1f" % TownData.traffic(id),
		])
		if profile.visited(id):
			var ts := profile.town(id)
			(r["sub"] as Label).text = "%s · %s" % [
				rates,
				App.t("map.progress", [
					App.format_number(round(ts.completion() * 100.0)),
					App.format_number(ts.star_level()),
				]),
			]
		else:
			(r["sub"] as Label).text = "%s · %s" % [rates, App.t("map.unvisited")]

		var btn: Button = r["btn"]
		if id == profile.active_town:
			btn.text = App.t("map.here")
			btn.disabled = true
		elif profile.unlocked(id):
			btn.text = App.t("map.travel")
			btn.disabled = false
		else:
			btn.text = App.t("map.locked", [App.format_number(TownData.star_required(id))])
			btn.disabled = true

	for b in [_monster_btn, _order_btn, _iron_btn]:
		var tl: Label = b.get_meta("t_lbl")
		var dl: Label = b.get_meta("d_lbl")
		tl.text = App.t(String(tl.get_meta("k")))
		dl.text = App.t(String(dl.get_meta("k")))

	_monster_btn.text = App.t("exp.monster_btn")
	_monster_btn.disabled = st.active_event == "monster_hills"
	if st.special_order_active:
		_order_btn.text = App.t("exp.order_running", [
			App.format_number(floor(st.special_order_done)),
			App.format_number(st.special_order_goal),
			App.format_number(ceil(st.special_order_timer)),
		])
		_order_btn.disabled = true
	else:
		_order_btn.text = App.t("exp.order_btn")
		_order_btn.disabled = false
	if st.salvage_charges > 0:
		_iron_btn.text = App.t("exp.iron_btn", [App.format_number(st.salvage_charges)])
		_iron_btn.disabled = false
	else:
		_iron_btn.text = App.t("exp.iron_gem")
		_iron_btn.disabled = st.gems < 5


func _on_travel(id: String) -> void:
	Sound.play("travel", -5.0)
	close()
	if session != null and session.has_method("travel_to"):
		session.travel_to(id)
	travel_selected.emit(id)


func _on_monster_hills() -> void:
	var st: TownState = session.state if session != null else Game.town
	if st != null and st.start_event("monster_hills"):
		Sound.play("event", -4.0)
		App.tap(36)
		close()


func _on_special_order() -> void:
	var st: TownState = session.state if session != null else Game.town
	if st != null and EmpireActions.start_special_order(st):
		Sound.play("mission", -5.0)
		App.tap(28)
		feedback.emit(App.t("exp.order_title"))
		close()


func _on_iron_bones() -> void:
	var st: TownState = session.state if session != null else Game.town
	if st == null:
		return
	var loot := EmpireActions.salvage_iron_bones(st)
	if loot.is_empty():
		Sound.play("deny", -10.0)
		return
	Sound.play("cash", -4.0)
	App.tap(32)
	feedback.emit("🔩 +$%s · +%s 🥃 · +1 Card (%s)!" % [
		App.format_short(float(loot["cash"])),
		App.format_number(float(loot["bourbon"])),
		App.t("mgr.%s" % String(loot["card"])),
	])
	refresh()


func _lbl(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
