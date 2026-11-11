class_name MenuScreens
extends Control
## Persian-first command interface. Every screen is painted key art + textured
## plates; copy comes from Loc so no menu hard-codes English display strings.
signal deploy_requested(id: String)
signal coastal_requested
signal navigation_requested(screen: String)
signal resume_requested
signal restart_requested
signal abort_requested
signal next_requested
signal upgrade_requested(id: String)
signal weapon_selected(id: String)
var screens: Dictionary = {}
var content_margins: Array[MarginContainer] = []
var current: String = "splash"
var settings_return: String = "main"
var selected_mission: MissionData
var briefing_title: Label
var briefing_subtitle: Label
var briefing_body: Label
var briefing_objectives: Label
var briefing_supply: Label
var campaign_summary: Label
var campaign_map: CampaignMap
var upgrade_list: VBoxContainer
var currency_label: Label
var result_title: Label
var result_stars: Label
var result_stats: Label
var result_rewards: Label
var next_button: Button
var toast_label: Label
var toast_time: float = 0.0
var last_result: Dictionary = {}
var arsenal_stats: Label
## Running menu tweens as [Tween, finish Callable]; settle() ends them at rest.
var _motion: Array = []


func _ready() -> void:
	theme = UITheme.theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_splash()
	_build_main()
	_build_campaign()
	_build_briefing()
	_build_arsenal()
	_build_upgrades()
	_build_settings()
	_build_pause()
	_build_results()
	resized.connect(_update_content_insets)
	_update_content_insets.call_deferred()
	toast_label = UITheme.label("", 20, UITheme.ACCENT, true)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -450
	toast_label.offset_right = 450
	toast_label.offset_top = -58
	toast_label.offset_bottom = -20
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast_label)
	Profile.changed.connect(_profile_changed)
	show_screen("splash")


func safe_insets() -> Vector4:
	## Left/top/right/bottom display-cutout insets in interface pixels.
	if not OS.has_feature("android"):
		return Vector4.ZERO
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or safe.size.x <= 0:
		return Vector4.ZERO
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var scale: Vector2 = viewport_size / window_size
	return Vector4(maxf(0.0, safe.position.x * scale.x), maxf(0.0, safe.position.y * scale.y), maxf(0.0, (window_size.x - safe.end.x) * scale.x), maxf(0.0, (window_size.y - safe.end.y) * scale.y))


func _update_content_insets() -> void:
	var insets: Vector4 = safe_insets()
	for margin in content_margins:
		margin.add_theme_constant_override("margin_left", int(ceilf(maxf(32.0, insets.x))))
		margin.add_theme_constant_override("margin_top", int(ceilf(maxf(32.0, insets.y))))
		margin.add_theme_constant_override("margin_right", int(ceilf(maxf(32.0, insets.z))))
		margin.add_theme_constant_override("margin_bottom", int(ceilf(maxf(32.0, insets.w))))


func _base(id: String, art_file: String = "hero_beach.jpg", dim: float = 0.62, ambient: bool = false) -> VBoxContainer:
	var root := Control.new()
	root.name = id.capitalize()
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(UITheme.backdrop())
	var art := UITheme.art(art_file, dim)
	root.add_child(art)
	MenuMotion.drift(art)
	root.add_child(UITheme.overlay("scrim_right.png", 0.88))
	root.add_child(UITheme.overlay("scrim_bottom.png", 0.72))
	root.add_child(UITheme.overlay("vignette.png", 0.9))
	if ambient:
		MenuMotion.dust(root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The page itself is full-bleed; only the content respects the display cutout.
	content_margins.append(margin)
	var box := UITheme.column(16)
	margin.add_child(box)
	root.add_child(margin)
	add_child(root)
	screens[id] = root
	return box


func _heading(box: VBoxContainer, title: String, back: String = "main") -> void:
	var row := UITheme.row(20)
	var heading := UITheme.label(title, 34, UITheme.TEXT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var back_button: Button = UITheme.button(Loc.t("back"), func(): navigation_requested.emit(back))
	back_button.custom_minimum_size.x = 132
	row.add_child(back_button)
	box.add_child(row)
	box.add_child(UITheme.rule())


func _art_button(title: String, hint: String, art_file: String, action: Callable, accent: bool = false, compact: bool = false) -> Button:
	## Image-led command card: thumbnail on the RTL start side, copy beside it.
	var node: Button = UITheme.button("", action, accent)
	node.custom_minimum_size = Vector2(396, 70 if compact else 86)
	if accent:
		MenuMotion.add_sweep(node)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	var row := UITheme.row(12)
	var thumb := TextureRect.new()
	thumb.texture = UITheme.texture(art_file)
	thumb.custom_minimum_size = Vector2(84, 52)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if art_file == "emblem.png" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(thumb)
	var text := UITheme.column(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_color: Color = UITheme.INK if accent else UITheme.TEXT
	var hint_color: Color = Color(0.16, 0.19, 0.14) if accent else UITheme.MUTED
	text.add_child(UITheme.label(title, 21, title_color, true))
	text.add_child(UITheme.label(hint, 14, hint_color))
	row.add_child(text)
	var chevron := TextureRect.new()
	chevron.texture = UITheme.texture("chevron_left.png")
	chevron.custom_minimum_size = Vector2(20, 20)
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.modulate = UITheme.INK if accent else UITheme.ACCENT
	row.add_child(chevron)
	margin.add_child(row)
	node.add_child(margin)
	UITheme.ignore_mouse(margin)
	return node


func _build_splash() -> void:
	var box := _base("splash", "hero_beach.jpg", 0.78, true)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon: TextureRect = UITheme.emblem(150)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	_track(MenuMotion.reveal(icon, 0.1, 0.9, 0.55), MenuMotion.snap.bind(icon))
	var title := UITheme.label(Loc.t("game_title"), 56, UITheme.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_track(MenuMotion.reveal(title, 0.42, 0.9), MenuMotion.snap.bind(title))
	var rule := ColorRect.new()
	rule.color = Color(UITheme.ACCENT, 0.85)
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	var rule_tween := MenuMotion.tween_on(rule)
	rule_tween.tween_property(rule, "custom_minimum_size:x", 300.0, 1.0).set_delay(0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_track(rule_tween, MenuMotion.finish.bind(rule, "custom_minimum_size:x", 300.0))
	var subtitle := UITheme.label(Loc.t("splash_boot") + "  /  " + Loc.t("splash_offline"), 20, UITheme.ACCENT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	_track(MenuMotion.reveal(subtitle, 0.9, 0.7), MenuMotion.snap.bind(subtitle))
	## Loading meter matches the 1.4 s boot delay in game.gd, so the menu appears as it fills.
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.min_value = 0.0
	meter.max_value = 100.0
	meter.value = 0.0
	meter.custom_minimum_size = Vector2(320.0, 4.0)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.add_theme_stylebox_override("background", MenuMotion.bar_style(Color(1.0, 1.0, 1.0, 0.12)))
	meter.add_theme_stylebox_override("fill", MenuMotion.bar_style(UITheme.ACCENT))
	box.add_child(meter)
	var meter_tween := MenuMotion.tween_on(meter)
	meter_tween.tween_property(meter, "value", 100.0, 1.2).set_delay(0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_track(meter_tween, MenuMotion.finish.bind(meter, "value", 100.0))


func _build_main() -> void:
	var box := _base("main", "hero_beach.jpg", 1.0, true)
	var top := UITheme.row(14)
	var icon: TextureRect = UITheme.emblem(52)
	top.add_child(icon)
	var brand := UITheme.label(Loc.t("brand"), 22, UITheme.TEXT, true)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	currency_label = UITheme.label("", 19, UITheme.ACCENT, true)
	top.add_child(currency_label)
	box.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var content := UITheme.row(36)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# RTL: first child sits on the right (the reading start side).
	var actions := UITheme.column(9)
	actions.custom_minimum_size.x = 416
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	actions.add_child(UITheme.label(Loc.t("home_directory"), 15, UITheme.MUTED))
	actions.add_child(_art_button(Loc.t("home_deploy"), Loc.t("home_deploy_hint"), "hero_beach.jpg", func(): coastal_requested.emit(), true))
	actions.add_child(_art_button(Loc.t("home_map"), Loc.t("home_map_hint"), "hero_ridge.jpg", func(): navigation_requested.emit("campaign"), false, true))
	actions.add_child(_art_button(Loc.t("home_arsenal"), Loc.t("home_arsenal_hint"), "hero_gun.jpg", func(): navigation_requested.emit("arsenal"), false, true))
	actions.add_child(_art_button(Loc.t("home_settings"), Loc.t("home_settings_hint"), "emblem.png", func(): settings_return = "main"; navigation_requested.emit("settings"), false, true))
	content.add_child(UITheme.card(actions, 16))
	var identity := UITheme.column(10)
	identity.custom_minimum_size.x = 520
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_END
	identity.add_child(UITheme.label(Loc.t("home_kicker"), 20, UITheme.ACCENT, true))
	var title := UITheme.label(Loc.t("home_title"), 68, UITheme.TEXT, true)
	title.add_theme_constant_override("line_spacing", -12)
	identity.add_child(title)
	identity.add_child(UITheme.wrapped(Loc.t("home_tagline"), 22, UITheme.TEXT))
	identity.add_child(UITheme.label(Loc.t("home_note"), 17, UITheme.MUTED))
	content.add_child(identity)
	box.add_child(content)
	box.add_child(UITheme.label(Loc.t("home_footer"), 14, UITheme.MUTED))
	_refresh_currency()


func _build_campaign() -> void:
	var box := _base("campaign", "hero_ridge.jpg", 0.72)
	_heading(box, Loc.t("campaign_title"))
	var content := UITheme.row(22)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	campaign_map = CampaignMap.new()
	campaign_map.mission_selected.connect(show_briefing)
	content.add_child(campaign_map)
	var info := UITheme.column(14)
	info.custom_minimum_size.x = 320
	info.add_child(UITheme.label(Loc.t("campaign_intel"), 18, UITheme.ACCENT, true))
	info.add_child(UITheme.wrapped(Loc.t("campaign_body"), 20))
	info.add_child(UITheme.rule())
	campaign_summary = UITheme.label("", 22, UITheme.TEXT, true)
	info.add_child(campaign_summary)
	info.add_child(UITheme.wrapped(Loc.t("campaign_stars_note"), 17))
	content.add_child(UITheme.panel(info, 20))
	box.add_child(content)


func _build_briefing() -> void:
	var box := _base("briefing", "hero_ridge.jpg", 0.66)
	_heading(box, Loc.t("briefing_title"), "campaign")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := UITheme.column(14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	briefing_title = UITheme.label("", 44, UITheme.TEXT, true)
	briefing_subtitle = UITheme.label("", 20, UITheme.ACCENT, true)
	briefing_body = UITheme.wrapped("", 21, UITheme.TEXT)
	briefing_objectives = UITheme.wrapped("", 19, UITheme.MUTED)
	briefing_supply = UITheme.label("", 20, UITheme.ACCENT, true)
	for node in [briefing_title, briefing_subtitle, briefing_body, UITheme.rule(), briefing_objectives, briefing_supply]:
		content.add_child(node)
	var actions := UITheme.row(14)
	actions.add_child(UITheme.button(Loc.t("briefing_deploy"), func(): deploy_requested.emit(selected_mission.id), true))
	actions.add_child(UITheme.button(Loc.t("briefing_arsenal"), func(): navigation_requested.emit("arsenal")))
	content.add_child(actions)
	var briefing_panel: PanelContainer = UITheme.panel(content, 28)
	briefing_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(briefing_panel)
	box.add_child(scroll)


func _build_arsenal() -> void:
	var box := _base("arsenal", "hero_gun.jpg", 0.58)
	_heading(box, Loc.t("arsenal_title"))
	var content := UITheme.row(24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var identity := UITheme.column(14)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var portrait := TextureRect.new()
	portrait.texture = UITheme.texture("hero_gun.jpg")
	portrait.custom_minimum_size.y = 210
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(portrait)
	identity.add_child(UITheme.label(Loc.t("arsenal_kicker"), 17, UITheme.ACCENT, true))
	identity.add_child(UITheme.label(Loc.t("arsenal_name"), 52, UITheme.TEXT, true))
	identity.add_child(UITheme.wrapped(Loc.t("arsenal_body"), 20))
	identity.add_child(UITheme.button(Loc.t("arsenal_equip"), func(): weapon_selected.emit("kestrel"), true))
	var identity_panel: PanelContainer = UITheme.panel(identity, 24)
	identity_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(identity_panel)
	var stats := UITheme.column(16)
	stats.custom_minimum_size.x = 430
	stats.add_child(UITheme.label(Loc.t("arsenal_performance"), 18, UITheme.MUTED))
	arsenal_stats = UITheme.label("", 23, UITheme.TEXT, true)
	stats.add_child(arsenal_stats)
	stats.add_child(UITheme.rule())
	stats.add_child(UITheme.wrapped(Loc.t("arsenal_ammo"), 19))
	stats.add_child(UITheme.button(Loc.t("arsenal_mods"), func(): navigation_requested.emit("upgrades")))
	content.add_child(UITheme.panel(stats, 24))
	box.add_child(content)


func _build_upgrades() -> void:
	var box := _base("upgrades", "hero_gun.jpg", 0.60)
	_heading(box, Loc.t("upgrades_title"), "arsenal")
	box.add_child(UITheme.wrapped(Loc.t("upgrades_body"), 19))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upgrade_list = UITheme.column(10)
	upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(upgrade_list)
	box.add_child(scroll)
	_refresh_upgrades()


func _refresh_upgrades() -> void:
	if upgrade_list == null:
		return
	for child in upgrade_list.get_children():
		child.queue_free()
	for id in ["damage", "accuracy", "reload", "range", "capacity"]:
		var upgrade: UpgradeData = load("res://resources/upgrades/%s.tres" % id)
		var level: int = int(Profile.data.upgrades.get(id, 0))
		var row := UITheme.row(18)
		var badge: TextureRect = UITheme.emblem(46)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
		var text := UITheme.column(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UITheme.label(upgrade.display_name, 23, UITheme.TEXT, true))
		text.add_child(UITheme.wrapped(upgrade.description, 17, UITheme.MUTED))
		row.add_child(text)
		row.add_child(UITheme.label(Loc.t("upgrades_level") % [Loc.number(level), Loc.number(upgrade.maximum_level)], 19, UITheme.ACCENT, true))
		var price: int = upgrade.cost(level)
		var caption: String = Loc.t("upgrades_maxed") if level >= upgrade.maximum_level else Loc.t("upgrades_install") % [Loc.number(price), Loc.number(upgrade.points_per_level)]
		var button: Button = UITheme.button(caption, func(): upgrade_requested.emit(id), level < upgrade.maximum_level)
		button.disabled = level >= upgrade.maximum_level or Profile.data.coins < price or Profile.data.upgrade_points < upgrade.points_per_level
		button.custom_minimum_size.x = 280
		row.add_child(button)
		upgrade_list.add_child(UITheme.card(row, 16))


func _build_settings() -> void:
	var box := _base("settings", "hero_ridge.jpg", 0.55)
	var heading := UITheme.row(20)
	var title := UITheme.label(Loc.t("settings_title"), 34, UITheme.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var back: Button = UITheme.button(Loc.t("back"), func(): navigation_requested.emit(settings_return))
	back.custom_minimum_size.x = 132
	heading.add_child(back)
	box.add_child(heading)
	box.add_child(UITheme.rule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 14)
	var quality := OptionButton.new()
	for key in ["quality_auto", "quality_low", "quality_medium", "quality_high", "quality_ultra"]:
		quality.add_item(Loc.t(key))
	quality.select(["auto", "low", "medium", "high", "ultra"].find(Profile.data.settings.quality))
	quality.item_selected.connect(func(index): Profile.set_setting("quality", ["auto", "low", "medium", "high", "ultra"][index]))
	_add_setting(grid, Loc.t("settings_quality"), Loc.t("settings_quality_note"), quality)
	var fps := OptionButton.new()
	fps.add_item(Loc.t("fps_60"))
	fps.add_item(Loc.t("fps_30"))
	fps.select(0 if Profile.data.settings.fps_target == 60 else 1)
	fps.item_selected.connect(func(index): Profile.set_setting("fps_target", 60 if index == 0 else 30))
	_add_setting(grid, Loc.t("settings_fps"), Loc.t("settings_fps_note"), fps)
	_add_slider(grid, Loc.t("settings_sensitivity"), Loc.t("settings_sensitivity_note"), "sensitivity", 0.3, 2.5)
	_add_slider(grid, Loc.t("settings_master"), Loc.t("settings_master_note"), "master_volume", 0.0, 1.0)
	_add_slider(grid, Loc.t("settings_sfx"), Loc.t("settings_sfx_note"), "sfx_volume", 0.0, 1.0)
	_add_slider(grid, Loc.t("settings_ambient"), Loc.t("settings_ambient_note"), "ambient_volume", 0.0, 1.0)
	_add_toggle(grid, Loc.t("settings_aim_assist"), Loc.t("settings_aim_assist_note"), "aim_assist")
	_add_slider(grid, Loc.t("settings_aim_assist_strength"), Loc.t("settings_aim_assist_strength_note"), "aim_assist_strength", 0.0, 1.0)
	_add_toggle(grid, Loc.t("settings_shake"), Loc.t("settings_shake_note"), "camera_shake")
	_add_toggle(grid, Loc.t("settings_autoreload"), Loc.t("settings_autoreload_note"), "auto_reload")
	_add_toggle(grid, Loc.t("settings_drag"), Loc.t("settings_drag_note"), "advanced_drag")
	_add_toggle(grid, Loc.t("settings_perf"), Loc.t("settings_perf_note"), "show_performance")
	scroll.add_child(grid)
	box.add_child(scroll)
	box.add_child(UITheme.wrapped(Loc.t("settings_footer"), 15, UITheme.MUTED))


func _add_setting(grid: GridContainer, title: String, description: String, control: Control) -> void:
	var text := UITheme.column(2)
	text.custom_minimum_size.x = 520
	text.add_child(UITheme.label(title, 21, UITheme.TEXT, true))
	text.add_child(UITheme.wrapped(description, 15, UITheme.MUTED))
	grid.add_child(text)
	control.custom_minimum_size = Vector2(400, 48)
	grid.add_child(control)


func _add_slider(grid: GridContainer, title: String, description: String, key: String, minimum: float, maximum: float) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = float(Profile.data.settings[key])
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var caption := UITheme.label(title + "  /  " + Loc.decimal(slider.value, 2), 21, UITheme.TEXT, true)
	var text := UITheme.column(2)
	text.custom_minimum_size.x = 520
	text.add_child(caption)
	text.add_child(UITheme.wrapped(description, 15, UITheme.MUTED))
	grid.add_child(text)
	slider.custom_minimum_size = Vector2(400, 42)
	slider.value_changed.connect(func(value): caption.text = title + "  /  " + Loc.decimal(value, 2))
	slider.drag_ended.connect(func(changed):
		if changed:
			Profile.set_setting(key, slider.value)
	)
	slider.focus_exited.connect(func(): Profile.set_setting(key, slider.value))
	grid.add_child(slider)


func _add_toggle(grid: GridContainer, title: String, description: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = Loc.t("enabled") if Profile.data.settings[key] else Loc.t("disabled")
	toggle.button_pressed = bool(Profile.data.settings[key])
	toggle.toggled.connect(func(on):
		toggle.text = Loc.t("enabled") if on else Loc.t("disabled")
		Profile.set_setting(key, on)
	)
	_add_setting(grid, title, description, toggle)


func _build_pause() -> void:
	var box := _base("pause", "hero_beach.jpg", 0.45)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var content := UITheme.column(13)
	content.custom_minimum_size.x = 500
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon: TextureRect = UITheme.emblem(72)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	var title := UITheme.label(Loc.t("pause_title"), 40, UITheme.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var body := UITheme.label(Loc.t("pause_body"), 18, UITheme.MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body)
	content.add_child(UITheme.button(Loc.t("pause_resume"), func(): resume_requested.emit(), true))
	content.add_child(UITheme.button(Loc.t("pause_restart"), func(): restart_requested.emit()))
	content.add_child(UITheme.button(Loc.t("home_settings"), func(): settings_return = "pause"; navigation_requested.emit("settings")))
	content.add_child(UITheme.button(Loc.t("pause_abort"), func(): abort_requested.emit()))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(UITheme.panel(content, 30))
	box.add_child(center)


func _build_results() -> void:
	var box := _base("results", "hero_beach.jpg", 0.55)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := UITheme.column(12)
	content.custom_minimum_size.x = 780
	result_title = UITheme.label(Loc.t("results_success"), 48, UITheme.ACCENT, true)
	result_stars = UITheme.label("★ ★ ★", 40, UITheme.ACCENT, true)
	result_stats = UITheme.label("", 22, UITheme.TEXT)
	result_rewards = UITheme.wrapped("", 23, UITheme.GREEN)
	for node in [result_title, result_stars, UITheme.rule(), result_stats, result_rewards]:
		content.add_child(node)
	var actions := UITheme.row(12)
	next_button = UITheme.button(Loc.t("results_next"), func(): next_requested.emit(), true)
	actions.add_child(next_button)
	actions.add_child(UITheme.button(Loc.t("results_replay"), func(): restart_requested.emit()))
	actions.add_child(UITheme.button(Loc.t("results_command"), func(): navigation_requested.emit("main")))
	content.add_child(actions)
	center.add_child(UITheme.panel(content, 30))
	box.add_child(center)


func show_screen(id: String) -> void:
	if not screens.has(id):
		return
	for key in screens:
		screens[key].visible = key == id
	current = id
	visible = true
	if id == "campaign":
		campaign_map.refresh()
		campaign_summary.text = Loc.t("campaign_progress") % [Loc.number(Profile.data.completed.size()), Loc.number(5), Loc.number(Profile.data.stars), Loc.number(15), Loc.number(Profile.data.upgrade_points)]
	if id == "arsenal":
		_refresh_arsenal()
	if id == "upgrades":
		_refresh_upgrades()
	_refresh_currency()
	_enter(id)


func _enter(id: String) -> void:
	## Each page fades in, and its command controls step in one after another.
	var root: Control = screens[id]
	root.modulate.a = 0.0
	var fade := MenuMotion.tween_on(root)
	fade.tween_property(root, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_track(fade, MenuMotion.finish.bind(root, "modulate:a", 1.0))
	var index := 0
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or not button.is_visible_in_tree():
			continue
		MenuMotion.attach_press(button)
		_track(MenuMotion.reveal(button, 0.05 + minf(index, 14) * 0.045, 0.45, 0.94), MenuMotion.snap.bind(button))
		index += 1


func settle() -> void:
	## Finishes every running menu tween at its resting state. Smoke captures call
	## this so screenshots show the settled interface rather than a mid-motion frame.
	for entry in _motion:
		var tween: Tween = entry[0]
		if tween.is_valid():
			tween.kill()
		# A control freed mid-motion has nothing left to settle; calling its bound callback
		# would pass a freed object as an argument and raise a script error.
		if MenuMotion.target_alive(entry[1]):
			entry[1].call()
	_motion.clear()


func is_animating() -> bool:
	for entry in _motion:
		if entry[0].is_valid():
			return true
	return false


func _track(tween: Tween, finish: Callable) -> void:
	_motion = _motion.filter(func(entry): return entry[0].is_valid())
	_motion.append([tween, finish])


func show_briefing(id: String) -> void:
	selected_mission = load("res://resources/missions/%s.tres" % id)
	briefing_title.text = selected_mission.title
	briefing_subtitle.text = Loc.sector(selected_mission.sector) + "  /  " + selected_mission.subtitle
	briefing_body.text = selected_mission.briefing
	var objectives: String = Loc.t("briefing_objectives") + "\n"
	for target_id in selected_mission.target_ids:
		objectives += "  ◆  " + Loc.t("briefing_neutralize") % Loc.target_name(target_id) + "\n"
	objectives += "\n" + Loc.t("briefing_optional") % Loc.target_name(selected_mission.optional_crate_id)
	briefing_objectives.text = objectives
	briefing_supply.text = Loc.t("briefing_supply") % [Loc.number(selected_mission.ammunition.he), Loc.number(selected_mission.ammunition.ap), Loc.clock(selected_mission.time_limit), Loc.number(selected_mission.base_reward)]
	show_screen("briefing")


func show_results(result: Dictionary) -> void:
	last_result = result
	var success: bool = result.success
	result_title.text = Loc.t("results_success") if success else Loc.t("results_failure")
	result_title.add_theme_color_override("font_color", UITheme.ACCENT if success else UITheme.RED)
	var stars: int = int(result.get("stars", 0))
	result_stars.text = "★ ".repeat(stars) + "☆ ".repeat(3 - stars)
	result_stats.text = Loc.t("results_stats") % [Loc.decimal(result.accuracy, 0), Loc.number(result.shots), Loc.number(result.objectives), Loc.number(result.required), Loc.clock(result.time), Loc.t("results_earned") if result.optional else Loc.t("results_not_earned")]
	result_rewards.text = Loc.t("results_rewards") % [Loc.number(result.coins), Loc.number(int(result.get("points", 0)))] if success else Loc.t(String(result.get("reason", "")))
	var index: int = ["sr01", "sr02", "sr03", "sr04", "sr05"].find(str(result.mission_id))
	next_button.visible = success and index < 4
	show_screen("results")


func _refresh_arsenal() -> void:
	var levels: Dictionary = Profile.data.upgrades
	arsenal_stats.text = Loc.t("arsenal_stats") % [Loc.number(roundi(100 * (1 + 0.08 * levels.damage))), Loc.decimal(82.0 * (1 + 0.05 * levels.range), 1), Loc.decimal(3.4 * (1 - 0.1 * levels.reload), 2), Loc.decimal(0.32 * pow(0.82, levels.accuracy), 2), Loc.number(2 * levels.capacity)]


func _refresh_currency() -> void:
	if currency_label:
		currency_label.text = "%s %s   ·   %s %s   ·   %s %s" % [Loc.t("credits"), Loc.number(Profile.data.coins), Loc.t("stars"), Loc.number(Profile.data.stars), Loc.t("points"), Loc.number(Profile.data.upgrade_points)]


func _profile_changed() -> void:
	_refresh_currency()
	if current == "upgrades":
		_refresh_upgrades.call_deferred()


func toast(message: String) -> void:
	toast_label.text = message
	toast_time = 3.5


func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	toast_label.modulate.a = minf(1.0, toast_time)
