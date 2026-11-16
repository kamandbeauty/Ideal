class_name WorldBadges
extends Control
## Projects crisp 2D Roadside Empire floating badges onto the 3D station plots:
## unbuilt price/star signs, vault cash and localized facility levels.

signal plot_tapped(id: String)

var session: Node
var state: TownState
var _entries: Dictionary = {}
var _styles: Dictionary = {}


func setup(session_node: Node) -> void:
	session = session_node
	state = session.state
	# This layer uses explicit projected pixel coordinates. Mirroring its
	# zero-width holders would put an RTL button one full width to the left.
	# Text still uses automatic bidi shaping; only geometry stays LTR.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# These styles are shared, not reallocated for every badge on every frame.
	_styles = {
		"gold": UiTheme.gold_badge_style(),
		"cream": UiTheme.cream_card_style(),
		"open": UiTheme.dark_pill_style(),
	}

	for id in state.business_ids():
		var holder := Control.new()
		holder.name = "Badge_" + id
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)

		var main_btn := Button.new()
		main_btn.focus_mode = Control.FOCUS_NONE
		main_btn.custom_minimum_size = Vector2(112, 44)
		main_btn.add_theme_font_size_override("font_size", 15)
		var captured: String = String(id)
		main_btn.pressed.connect(func() -> void: plot_tapped.emit(captured))
		holder.add_child(main_btn)

		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", UiTheme.slim_style(UiTheme.TRACK, Color.TRANSPARENT, 3))
		bar.add_theme_stylebox_override("fill", UiTheme.slim_style(UiTheme.GOOD, Color.TRANSPARENT, 3))
		holder.add_child(bar)

		var arrow := Label.new()
		arrow.text = "⬆"
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.custom_minimum_size = Vector2(30, 30)
		arrow.add_theme_font_size_override("font_size", 16)
		arrow.add_theme_color_override("font_color", Color.WHITE)
		arrow.add_theme_stylebox_override("normal", UiTheme.red_arrow_style())
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(arrow)

		_entries[id] = {"holder": holder, "btn": main_btn, "bar": bar, "arrow": arrow}


func update_positions(suppressed: bool) -> void:
	visible = not suppressed
	if suppressed or session == null or session.camera_rig == null:
		return
	var cam: Camera3D = session.camera_rig.camera
	if cam == null:
		return
	var vp_size := get_viewport_rect().size
	var tr := state.traffic()

	for id in _entries.keys():
		var entry: Dictionary = _entries[id]
		var holder: Control = entry["holder"]
		var plot := BusinessData.plot(id)
		var world_pt := Vector3(plot.x, 3.05, plot.y)
		if cam.is_position_behind(world_pt):
			holder.visible = false
			continue
		var screen_pt := cam.unproject_position(world_pt)
		# Keep badges between the top quests and the bottom navigation.
		if (
			screen_pt.x < 24.0
			or screen_pt.x > vp_size.x - 24.0
			or screen_pt.y < 235.0
			or screen_pt.y > vp_size.y - 135.0
		):
			holder.visible = false
			continue
		holder.visible = true
		_style_entry(id, entry, tr)
		_fit_badge(entry, screen_pt, vp_size)


func _fit_badge(entry: Dictionary, screen_pt: Vector2, viewport_size: Vector2) -> void:
	var btn: Button = entry["btn"]
	var bar: ProgressBar = entry["bar"]
	var arrow: Label = entry["arrow"]
	btn.size = btn.get_combined_minimum_size()
	btn.position = Vector2.ZERO
	bar.position = Vector2(8, btn.size.y - 8.0)
	bar.size = Vector2(btn.size.x - 16.0, 6)
	arrow.position = Vector2(btn.size.x - 16.0, -10)
	# Account for the actual translated text AND the projecting upgrade arrow.
	var left := clampf(screen_pt.x - btn.size.x * 0.5, 8.0, viewport_size.x - btn.size.x - 22.0)
	(entry["holder"] as Control).position = Vector2(left, screen_pt.y - btn.size.y * 0.5)


func _set_style(entry: Dictionary, key: String, color: Color) -> void:
	var btn: Button = entry["btn"]
	if String(entry.get("style", "")) != key:
		for variant in ["normal", "hover", "pressed"]:
			btn.add_theme_stylebox_override(variant, _styles[key])
		entry["style"] = key
	if entry.get("color") != color:
		btn.add_theme_color_override("font_color", color)
		entry["color"] = color


func _style_entry(id: String, entry: Dictionary, tr: float) -> void:
	var b := state.business(id)
	var btn: Button = entry["btn"]
	var bar: ProgressBar = entry["bar"]
	var arrow: Label = entry["arrow"]
	if b == null:
		return
	btn.tooltip_text = App.t("business.%s.name" % id)
	if not b.unlocked:
		bar.visible = false
		var req_star := BusinessData.star_required(id)
		if state.star_level() < req_star:
			btn.text = "⭐ %s" % App.t("hud.star_lvl", [App.format_number(req_star)])
			_set_style(entry, "gold", UiTheme.DARK_TEXT)
			arrow.visible = false
		else:
			var cost := state.unlock_cost(id)
			btn.text = "💵 %s" % App.format_short(cost)
			_set_style(entry, "cream", UiTheme.DARK_TEXT)
			arrow.visible = state.cash + 0.01 >= cost
		return

	var up_cost := state.upgrade_cost(id, 1)
	arrow.visible = b.can_upgrade_level() and state.cash + 0.01 >= up_cost
	if not b.is_automated() and b.vault_cash >= 2.0:
		btn.text = "🗄️ 💵 %s" % App.format_short(b.vault_cash)
		_set_style(entry, "open", UiTheme.TEXT)
		bar.visible = true
		bar.value = b.vault_fill_ratio(tr)
	else:
		btn.text = "%s %s" % [BusinessData.icon(id), App.t("hud.level", [App.format_number(b.level)])]
		_set_style(entry, "open", UiTheme.GOOD if b.is_automated() else UiTheme.TEXT)
		bar.visible = false
