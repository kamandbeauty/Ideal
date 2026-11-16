extends Control
## Authentic Roadside Empire Portrait HUD:
## - Row 1: Gear Settings + Gold Star Badge + Cash + Bourbon + Gems pills
## - Row 2: Clipboard Chapter Progress Bar + 3 Milestone Reward Chest buttons
## - Row 3: 3 Side-by-Side Cream Quest Cards (turn Bright Green on completion!)
## - Center: 2D Projected WorldBadges + StationSheet bottom renovation drawer
## - Bottom: 5-Button Bar (Map, Cases, Wide Purple x2 Income, Managers, Hammer)

var session: Node
var selected_id := ""

var _star_pill: Label
var _cash_pill: Label
var _bourbon_pill: Label
var _gems_pill: Label
var _chapter_lbl: Label
var _chapter_bar: ProgressBar
var _milestone_btns: Array[Button] = []
var _quest_cards: Array[Button] = []
var _event_chip: Button
var _toast_lbl: Label
var _toast_timer := 0.0

var _map_btn: Button
var _cases_btn: Button
var _boost_btn: Button
var _managers_btn: Button
var _build_btn: Button

var _badges: WorldBadges
var _sheet: StationSheet
var _settings: Control
var _map: Control
var _managers: ManagersModal
var _cases: CasesShopModal

var _offline_modal: Control
var _offline_body: Label
var _offline_amount := 0.0
var _bonus_modal: Control
var _bonus_body: Label
var _bonus_day := 0
var _completion_modal: Control
var _completion_shown := false


func setup(session_node: Node) -> void:
	session = session_node
	theme = App.ui_theme
	layout_direction = App.layout_direction()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_apply_language()
	App.language_changed.connect(func(_l: String) -> void:
		layout_direction = App.layout_direction()
		_apply_language())
	session.state.changed.connect(_refresh_all)
	session.state.event_started.connect(func(ev_id: String) -> void:
		show_message(App.t(TownEvents.name_key(ev_id))))
	_refresh_all()


func tick(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		_toast_lbl.get_parent().visible = _toast_timer > 0.0
	var modal_open := (
		_settings.visible or _map.visible or _managers.visible or _cases.visible
		or _offline_modal.visible or _bonus_modal.visible or _completion_modal.visible
	)
	_badges.update_positions(modal_open or _sheet.visible)
	_refresh_live_timers()


func refresh() -> void:
	_refresh_all()


func show_message(message: String) -> void:
	if _toast_lbl == null:
		return
	_toast_lbl.text = message
	_toast_lbl.get_parent().visible = true
	_toast_timer = 3.2


func show_completion_banner() -> void:
	if _completion_modal == null or session == null:
		return
	_completion_shown = true
	(_completion_modal.get_meta("body") as Label).text = App.t("complete.body", [
		App.t("town.%s" % session.state.town_id)
	])
	_completion_modal.visible = true


func _build() -> void:
	# 1) Projected 2D World Plot Badges (behind HUD bars & modals)
	_badges = WorldBadges.new()
	_badges.setup(session)
	_badges.plot_tapped.connect(_on_badge_tapped)
	add_child(_badges)

	# 2) Top 3-Row Roadside Empire Header
	_build_top_header()

	# 3) Station Upgrade Bottom Sheet (above bottom nav)
	_sheet = StationSheet.new()
	_sheet.setup(session)
	_sheet.closed.connect(func() -> void: session.deselect())
	_sheet.action_feedback.connect(show_message)
	add_child(_sheet)

	# 4) Bottom 5-Button Navigation Bar
	_build_bottom_nav()

	# 5) Modals & Sheets (direct children so get_node("WorldMap") / get_node("Settings") work!)
	_build_modals()


func _build_top_header() -> void:
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 10)
	top.add_theme_constant_override("margin_right", 10)
	top.add_theme_constant_override("margin_top", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(stack)

	# ROW 1: Gear + Gold Star Badge + Cash + Bourbon + Gems
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(row1)

	var gear := Button.new()
	gear.text = "⚙️"
	gear.theme_type_variation = "NavButton"
	gear.custom_minimum_size = Vector2(44, 42)
	gear.focus_mode = Control.FOCUS_NONE
	gear.pressed.connect(func() -> void: _settings.open())
	row1.add_child(gear)

	_star_pill = _pill_label(UiTheme.gold_badge_style(), UiTheme.DARK_TEXT, 14)
	row1.add_child(_star_pill.get_parent())

	_cash_pill = _pill_label(UiTheme.dark_pill_style(), Color.WHITE, 16)
	_cash_pill.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_cash_pill.get_parent())

	_bourbon_pill = _pill_label(UiTheme.dark_pill_style(), UiTheme.BOURBON, 14)
	row1.add_child(_bourbon_pill.get_parent())

	_gems_pill = _pill_label(UiTheme.dark_pill_style(), UiTheme.GEM_PINK, 14)
	row1.add_child(_gems_pill.get_parent())

	# ROW 2: Clipboard Chapter Progress Bar + 3 Milestone Chest Buttons
	var row2_panel := PanelContainer.new()
	row2_panel.add_theme_stylebox_override("panel", UiTheme.dark_pill_style())
	stack.add_child(row2_panel)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	row2_panel.add_child(row2)

	_chapter_lbl = _lbl(14, Color.WHITE)
	row2.add_child(_chapter_lbl)

	_chapter_bar = ProgressBar.new()
	_chapter_bar.show_percentage = false
	_chapter_bar.min_value = 0.0
	_chapter_bar.max_value = float(ChapterQuests.TASKS_PER_CHAPTER)
	_chapter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chapter_bar.custom_minimum_size = Vector2(90, 14)
	var ch_bg := UiTheme.slim_style(Color(0.08, 0.09, 0.14), Color.TRANSPARENT, 7)
	_chapter_bar.add_theme_stylebox_override("background", ch_bg)
	_chapter_bar.add_theme_stylebox_override("fill", UiTheme.slim_style(UiTheme.GOOD, Color.TRANSPARENT, 7))
	row2.add_child(_chapter_bar)

	for step in ChapterQuests.MILESTONE_STEPS:
		var m_btn := Button.new()
		m_btn.custom_minimum_size = Vector2(54, 30)
		m_btn.focus_mode = Control.FOCUS_NONE
		m_btn.add_theme_font_size_override("font_size", 12)
		var captured_step := int(step)
		m_btn.pressed.connect(func() -> void: _on_claim_milestone(captured_step))
		row2.add_child(m_btn)
		_milestone_btns.append(m_btn)

	# ROW 3: 3 Side-by-Side Cream Quest Cards!
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	row3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(row3)

	for i in range(ChapterQuests.SLOT_COUNT):
		var q_btn := Button.new()
		q_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q_btn.custom_minimum_size = Vector2(0, 82)
		q_btn.focus_mode = Control.FOCUS_NONE
		q_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q_btn.add_theme_font_size_override("font_size", 13)
		var slot_idx := i
		q_btn.pressed.connect(func() -> void: _on_quest_card_pressed(slot_idx))
		row3.add_child(q_btn)
		_quest_cards.append(q_btn)

	# ROW 4: Active Event / Special Order Banner + Toast Pill
	_event_chip = Button.new()
	_event_chip.theme_type_variation = "PurpleButton"
	_event_chip.custom_minimum_size = Vector2(0, 36)
	_event_chip.focus_mode = Control.FOCUS_NONE
	_event_chip.add_theme_font_size_override("font_size", 13)
	_event_chip.visible = false
	_event_chip.pressed.connect(func() -> void: _map.open("exp"))
	stack.add_child(_event_chip)

	var toast_box := PanelContainer.new()
	toast_box.add_theme_stylebox_override("panel", UiTheme.dark_pill_style())
	toast_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast_box.visible = false
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(toast_box)
	_toast_lbl = _lbl(14, UiTheme.GOLD)
	toast_box.add_child(_toast_lbl)


func _build_bottom_nav() -> void:
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -104
	bottom.add_theme_constant_override("margin_left", 10)
	bottom.add_theme_constant_override("margin_right", 10)
	bottom.add_theme_constant_override("margin_bottom", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bottom.add_child(bar)

	_map_btn = _nav_btn("NavButton", 1.0, func() -> void: _map.open("story"))
	bar.add_child(_map_btn)

	_cases_btn = _nav_btn("NavButton", 1.0, func() -> void: _cases.open("cases"))
	bar.add_child(_cases_btn)

	_boost_btn = _nav_btn("PurpleButton", 1.55, _on_boost_pressed)
	bar.add_child(_boost_btn)

	_managers_btn = _nav_btn("NavButton", 1.05, func() -> void: _managers.open())
	bar.add_child(_managers_btn)

	_build_btn = _nav_btn("PurpleButton", 1.05, func() -> void: _cases.open("build"))
	bar.add_child(_build_btn)


func _nav_btn(variation: String, stretch: float, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = stretch
	b.custom_minimum_size = Vector2(0, 86)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b


func _build_modals() -> void:
	_offline_modal = _simple_modal("offline.title", "offline.collect", collect_offline)
	_offline_body = _offline_modal.get_meta("body")
	add_child(_offline_modal)

	_bonus_modal = _simple_modal("bonus.title", "bonus.claim", collect_daily_bonus)
	_bonus_body = _bonus_modal.get_meta("body")
	add_child(_bonus_modal)

	_completion_modal = _simple_modal("complete.title", "complete.stay", dismiss_completion)
	add_child(_completion_modal)

	_map = load("res://scripts/ui/world_map.gd").new()
	_map.name = "WorldMap"
	_map.setup(session)
	_map.feedback.connect(show_message)
	add_child(_map)

	_managers = ManagersModal.new()
	_managers.name = "ManagersModal"
	_managers.setup(session.state)
	_managers.feedback.connect(show_message)
	add_child(_managers)

	_cases = CasesShopModal.new()
	_cases.name = "CasesModal"
	_cases.setup(session.state)
	_cases.feedback.connect(show_message)
	_cases.facility_selected.connect(func(id: String) -> void: session.select_business(id))
	add_child(_cases)

	_settings = load("res://scripts/ui/settings_panel.gd").new()
	_settings.name = "Settings"
	_settings.session = session
	_settings.visible = false
	_settings.menu_requested.connect(func() -> void: session.leave_to_menu())
	add_child(_settings)


func _simple_modal(title_k: String, btn_k: String, cb: Callable) -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.visible = false
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var tl := _lbl(25, UiTheme.GOLD)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.set_meta("k", title_k)
	col.add_child(tl)
	var bl := _lbl(17, UiTheme.TEXT)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(bl)
	var btn := Button.new()
	btn.theme_type_variation = "GreenButton"
	btn.custom_minimum_size = Vector2(0, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("k", btn_k)
	btn.pressed.connect(cb)
	col.add_child(btn)
	wrap.set_meta("title", tl)
	wrap.set_meta("body", bl)
	wrap.set_meta("btn", btn)
	return wrap


func _refresh_all() -> void:
	var st: TownState = session.state
	var sp := EmpireActions.star_progress(st)
	_star_pill.text = "⭐ %s · %s/%s" % [
		App.t("hud.star_lvl", [App.format_number(int(sp["level"]))]),
		App.format_number(int(sp["current"])),
		App.format_number(int(sp["needed"])),
	]
	_cash_pill.text = "💵 %s" % App.format_short(st.cash)
	_bourbon_pill.text = "🥃 %s" % App.format_number(st.bourbon)
	_gems_pill.text = "💎 %s" % App.format_number(st.gems)

	_chapter_lbl.text = "📋 " + App.t("hud.chapter_bar", [
		App.format_number(st.chapter_index),
		App.format_number(st.chapter_tasks_done),
		App.format_number(ChapterQuests.TASKS_PER_CHAPTER),
	])
	_chapter_bar.value = float(st.chapter_tasks_done)
	var icons := ["💵", "🥃", "💎"]
	for idx in range(ChapterQuests.MILESTONE_STEPS.size()):
		var step := int(ChapterQuests.MILESTONE_STEPS[idx])
		var m_btn := _milestone_btns[idx]
		var claimed := st.chapter_milestones.has(step)
		var ready := EmpireActions.can_claim_chapter_milestone(st, step)
		m_btn.text = "%s✓" % icons[idx] if claimed else "%s %d" % [icons[idx], step]
		m_btn.theme_type_variation = "GreenButton" if ready else "GhostButton"
		m_btn.disabled = not ready

	_refresh_quest_cards()
	_refresh_bottom_nav()
	if _sheet.visible:
		_sheet.refresh()
	if _managers.visible:
		_managers.refresh()
	if _cases.visible:
		_cases.refresh()
	if _map.visible:
		_map.refresh()
	if not _completion_shown and st.is_complete():
		show_completion_banner()


func _refresh_quest_cards() -> void:
	var st: TownState = session.state
	for i in range(_quest_cards.size()):
		var card := _quest_cards[i]
		if i >= st.quest_slots.size():
			card.visible = false
			continue
		card.visible = true
		var q: Dictionary = st.quest_slots[i]
		var done := ChapterQuests.is_complete(q, st)
		var icon := ChapterQuests.icon_for(q)
		if done:
			card.text = "%s %s\n✅ %s" % [
				icon,
				ChapterQuests.title_text(q),
				App.t("quest.claim"),
			]
			card.add_theme_stylebox_override("normal", UiTheme.green_card_style())
			card.add_theme_stylebox_override("hover", UiTheme.green_card_style())
			card.add_theme_stylebox_override("pressed", UiTheme.green_card_style())
			card.add_theme_color_override("font_color", Color.WHITE)
		else:
			card.text = "%s %s\n🔑 %s" % [
				icon,
				ChapterQuests.title_text(q),
				ChapterQuests.progress_label(q, st),
			]
			card.add_theme_stylebox_override("normal", UiTheme.cream_card_style())
			card.add_theme_stylebox_override("hover", UiTheme.cream_card_style())
			card.add_theme_stylebox_override("pressed", UiTheme.cream_card_style())
			card.add_theme_color_override("font_color", UiTheme.DARK_TEXT)


func _refresh_bottom_nav() -> void:
	var st: TownState = session.state
	_map_btn.text = "📍\n" + App.t("nav.map")
	var crate_dot := " ●" if st.free_crate_cooldown <= 0.0 else ""
	_cases_btn.text = "🧰%s\n%s" % [crate_dot, App.t("nav.cases")]
	_managers_btn.text = "✨\n" + App.t("nav.managers")

	var affordable := 0
	for id in st.business_ids():
		var b := st.business(id)
		if (
			not b.unlocked
			and st.star_level() >= BusinessData.star_required(id)
			and st.cash + 0.01 >= st.unlock_cost(id)
		):
			affordable += 1
		elif b.unlocked and b.can_upgrade_level() and st.cash + 0.01 >= st.upgrade_cost(id, 1):
			affordable += 1
	var badge := (" (%d)" % affordable) if affordable > 0 else ""
	_build_btn.text = "🔨%s\n%s" % [badge, App.t("nav.build")]


func _refresh_live_timers() -> void:
	var st: TownState = session.state
	if st.x2_boost_seconds > 0.0:
		_boost_btn.text = "⚡ " + App.t("nav.boost_active", [App.format_number(ceil(st.x2_boost_seconds))])
	else:
		_boost_btn.text = "▶ " + App.t("nav.boost")

	if st.special_order_active:
		_event_chip.visible = true
		_event_chip.text = "🚚 %s" % App.t("exp.order_running", [
			App.format_number(floor(st.special_order_done)),
			App.format_number(st.special_order_goal),
			App.format_number(ceil(st.special_order_timer)),
		])
	elif not st.active_event.is_empty():
		_event_chip.visible = true
		_event_chip.text = "🔥 %s (%ss)" % [
			App.t(TownEvents.name_key(st.active_event)),
			App.format_number(ceilf(st.event_time_left)),
		]
	else:
		_event_chip.visible = false


func _on_badge_tapped(id: String) -> void:
	var st: TownState = session.state
	var b := st.business(id)
	if b == null:
		return
	if b.unlocked and (not b.is_automated()) and b.vault_cash >= 2.0:
		var got := st.collect_vault(id)
		if got > 0.0:
			Sound.play("cash", -5.0)
			App.tap(20)
			session.view.pop_income(id, got)
	elif (
		(not b.unlocked)
		and st.star_level() >= BusinessData.star_required(id)
		and st.cash + 0.01 >= st.unlock_cost(id)
	):
		if st.unlock_business(id):
			Sound.play("build", -4.0)
			App.tap(36)
			show_message(App.t("msg.unlocked", [App.t("business.%s.name" % id)]))
	session.select_business(id)


func _on_quest_card_pressed(slot_idx: int) -> void:
	var st: TownState = session.state
	if slot_idx < 0 or slot_idx >= st.quest_slots.size():
		return
	var q: Dictionary = st.quest_slots[slot_idx]
	if ChapterQuests.is_complete(q, st):
		var reward := EmpireActions.claim_quest_slot(st, slot_idx)
		if not reward.is_empty():
			Sound.play("mission", -4.0)
			App.tap(32)
			show_message(App.t("msg.quest_claimed", [
				App.format_short(float(reward["cash"])),
				App.format_number(float(reward["gems"])),
			]))
	else:
		var target_id := String(q.get("target", ""))
		if not target_id.is_empty() and st.business(target_id) != null:
			session.select_business(target_id)


func _on_claim_milestone(step: int) -> void:
	var st: TownState = session.state
	var reward := EmpireActions.claim_chapter_milestone(st, step)
	if reward.is_empty():
		return
	Sound.play("gem", -4.0)
	App.tap(34)
	show_message("📋 +$%s · +%s 🥃 · +%s 💎!" % [
		App.format_short(float(reward["cash"])),
		App.format_number(float(reward["bourbon"])),
		App.format_number(float(reward["gems"])),
	])


func _on_boost_pressed() -> void:
	var st: TownState = session.state
	EmpireActions.activate_x2_boost(st)
	Sound.play("event", -5.0)
	App.tap(28)
	show_message(App.t("msg.boost_activated"))


func show_business(id: String) -> void:
	selected_id = id
	_sheet.open_for(id)


func hide_business() -> void:
	selected_id = ""
	_sheet.visible = false


func show_offline(seconds: float, earnings: float) -> void:
	if earnings < 1.0:
		return
	_offline_amount = earnings
	var mins := maxi(1, int(roundf(seconds / 60.0)))
	_offline_body.text = "%s\n\n💵 %s" % [
		App.t("offline.away", [App.format_number(mins)]),
		App.format_money(earnings),
	]
	_offline_modal.visible = true


func collect_offline() -> void:
	if _offline_amount > 0.0:
		var st: TownState = session.state
		EmpireActions.grant_cash(st, _offline_amount)
		_offline_amount = 0.0
		Sound.play("cash", -4.0)
	_offline_modal.visible = false


func show_daily_bonus(day: int) -> void:
	_bonus_day = day
	var st: TownState = session.state
	var c := DailyBonus.cash(st.net_per_minute(), day)
	var g := DailyBonus.gems(day)
	_bonus_body.text = "%s\n\n💵 %s   💎 %s" % [
		App.t("bonus.day", [App.format_number(day)]),
		App.format_short(c),
		App.format_number(g),
	]
	_bonus_modal.visible = true


func collect_daily_bonus() -> void:
	if _bonus_day > 0:
		var st: TownState = session.state
		var c := DailyBonus.cash(st.net_per_minute(), _bonus_day)
		var g := DailyBonus.gems(_bonus_day)
		EmpireActions.grant_cash(st, c)
		st.gems += g
		st.bourbon += 15
		_bonus_day = 0
		Sound.play("gem", -4.0)
		st.changed.emit()
	_bonus_modal.visible = false


func dismiss_completion() -> void:
	_completion_modal.visible = false


func _apply_language() -> void:
	for modal in [_offline_modal, _bonus_modal, _completion_modal]:
		var tl: Label = modal.get_meta("title")
		var btn: Button = modal.get_meta("btn")
		tl.text = App.t(String(tl.get_meta("k")))
		btn.text = App.t(String(btn.get_meta("k")))
	_refresh_all()


func _pill_label(style: StyleBoxFlat, col: Color, size: int) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return l


func _lbl(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
