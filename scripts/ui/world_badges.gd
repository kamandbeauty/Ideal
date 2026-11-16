class_name WorldBadges
extends Control
## Projects crisp 2D Roadside Empire floating badges onto the 3D station plots:
## - Unbuilt & Star-ready: Cream signboard `💵 300` + Red `⬆` badge (tap to build!)
## - Unbuilt & Star-locked: Gold Star `⭐ 2 lvl` lock shield
## - Open station: Safe/Vault pill (`🗄️ 💵 320` + green bar) + Red `⬆` upgrade badge!

signal plot_tapped(id: String)

var session: Node
var state: TownState
var _entries: Dictionary = {}


func setup(session_node: Node) -> void:
	session = session_node
	state = session.state
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for id in state.business_ids():
		var holder := Control.new()
		holder.name = "Badge_" + id
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)

		var main_btn := Button.new()
		main_btn.focus_mode = Control.FOCUS_NONE
		main_btn.custom_minimum_size = Vector2(108, 38)
		main_btn.add_theme_font_size_override("font_size", 15)
		var captured: String = String(id)
		main_btn.pressed.connect(func() -> void: plot_tapped.emit(captured))
		holder.add_child(main_btn)

		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(92, 6)
		bar.position = Vector2(8, 33)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", UiTheme.slim_style(UiTheme.TRACK, Color.TRANSPARENT, 3))
		bar.add_theme_stylebox_override("fill", UiTheme.slim_style(UiTheme.GOOD, Color.TRANSPARENT, 3))
		holder.add_child(bar)

		var arrow := Label.new()
		arrow.text = "⬆"
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.custom_minimum_size = Vector2(30, 30)
		arrow.position = Vector2(92, -10)
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
		# Keep badges inside the playable central viewport between top quests & bottom nav!
		if (
			screen_pt.x < 24.0
			or screen_pt.x > vp_size.x - 24.0
			or screen_pt.y < 235.0
			or screen_pt.y > vp_size.y - 135.0
		):
			holder.visible = false
			continue
		holder.visible = true
		holder.position = screen_pt - Vector2(54.0, 22.0)
		_style_entry(id, entry, tr)


func _style_entry(id: String, entry: Dictionary, tr: float) -> void:
	var b := state.business(id)
	var btn: Button = entry["btn"]
	var bar: ProgressBar = entry["bar"]
	var arrow: Label = entry["arrow"]
	if b == null:
		return

	if not b.unlocked:
		bar.visible = false
		var req_star := BusinessData.star_required(id)
		if state.star_level() < req_star:
			btn.text = "⭐ %s" % App.t("hud.star_lvl", [App.format_number(req_star)])
			btn.add_theme_stylebox_override("normal", UiTheme.gold_badge_style())
			btn.add_theme_stylebox_override("hover", UiTheme.gold_badge_style())
			btn.add_theme_stylebox_override("pressed", UiTheme.gold_badge_style())
			btn.add_theme_color_override("font_color", UiTheme.DARK_TEXT)
			arrow.visible = false
		else:
			var cost := state.unlock_cost(id)
			btn.text = "💵 %s" % App.format_short(cost)
			btn.add_theme_stylebox_override("normal", UiTheme.cream_card_style())
			btn.add_theme_stylebox_override("hover", UiTheme.cream_card_style())
			btn.add_theme_stylebox_override("pressed", UiTheme.cream_card_style())
			btn.add_theme_color_override("font_color", UiTheme.DARK_TEXT)
			arrow.visible = state.cash + 0.01 >= cost
		return

	# Open station: show Safe/Vault cash when waiting to be collected, or station level!
	var up_cost := state.upgrade_cost(id, 1)
	arrow.visible = b.can_upgrade_level() and state.cash + 0.01 >= up_cost
	if not b.is_automated() and b.vault_cash >= 2.0:
		btn.text = "🗄️ 💵 %s" % App.format_short(b.vault_cash)
		btn.add_theme_stylebox_override("normal", UiTheme.dark_pill_style())
		btn.add_theme_stylebox_override("hover", UiTheme.dark_pill_style())
		btn.add_theme_stylebox_override("pressed", UiTheme.dark_pill_style())
		btn.add_theme_color_override("font_color", UiTheme.TEXT)
		bar.visible = true
		bar.value = b.vault_fill_ratio(tr)
	else:
		btn.text = "%s Lv %s" % [BusinessData.icon(id), App.format_number(b.level)]
		btn.add_theme_stylebox_override("normal", UiTheme.dark_pill_style())
		btn.add_theme_stylebox_override("hover", UiTheme.dark_pill_style())
		btn.add_theme_stylebox_override("pressed", UiTheme.dark_pill_style())
		btn.add_theme_color_override("font_color", UiTheme.GOOD if b.is_automated() else UiTheme.TEXT)
		bar.visible = false
