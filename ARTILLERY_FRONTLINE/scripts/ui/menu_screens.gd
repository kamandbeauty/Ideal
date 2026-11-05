class_name MenuScreens
extends Control
signal deploy_requested(id: String)
signal navigation_requested(screen: String)
signal resume_requested
signal restart_requested
signal abort_requested
signal next_requested
signal upgrade_requested(id: String)
signal weapon_selected(id: String)
var screens: Dictionary = {}
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

func _ready() -> void:
	theme = UITheme.theme()
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
	toast_label = UITheme.label("", 20, UITheme.ACCENT, true)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -450
	toast_label.offset_right = 450
	toast_label.offset_top = -55
	toast_label.offset_bottom = -20
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast_label)
	Profile.changed.connect(_profile_changed)
	show_screen("splash")

func _base(id: String, opacity: float = 0.90) -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color(0.035, 0.055, 0.045, opacity)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	var box := UITheme.column(20)
	margin.add_child(box)
	root.add_child(margin)
	add_child(root)
	screens[id] = root
	return box

func _heading(box: VBoxContainer, title: String, back: String = "main") -> void:
	var row := UITheme.row(20)
	var heading := UITheme.label(title, 38, UITheme.TEXT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	row.add_child(UITheme.button("BACK", func(): navigation_requested.emit(back)))
	box.add_child(row)
	box.add_child(UITheme.rule())

func _build_splash() -> void:
	var box := _base("splash", 1.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = load("res://assets/textures/icon.svg")
	icon.custom_minimum_size = Vector2(140, 140)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var title := UITheme.label("ARTILLERY FRONTLINE", 58, UITheme.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UITheme.label("INITIALIZING FIRE CONTROL  /  OFFLINE OPERATIONS", 19, UITheme.ACCENT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

func _build_main() -> void:
	var box := _base("main", 0.32)
	var top := UITheme.row(16)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/textures/icon.svg")
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(icon)
	var brand := UITheme.label("AF / FRONTLINE COMMAND", 23, UITheme.TEXT, true)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	currency_label = UITheme.label("", 22, UITheme.ACCENT, true)
	top.add_child(currency_label)
	box.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var content := UITheme.row(50)
	var left := UITheme.column(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UITheme.label("OPERATION 01 / SABLE RIDGE", 20, UITheme.ACCENT, true))
	var title := UITheme.label("ARTILLERY\nFRONTLINE", 86, UITheme.TEXT, true)
	title.add_theme_constant_override("line_spacing", -18)
	left.add_child(title)
	left.add_child(UITheme.wrapped("One gun. One sector. Make every round count.\nOriginal 3D artillery combat • offline single player", 22, UITheme.TEXT))
	content.add_child(left)
	var actions := UITheme.column(12)
	actions.custom_minimum_size.x = 340
	actions.add_child(UITheme.label("COMMAND DIRECTORY", 16, UITheme.MUTED))
	actions.add_child(UITheme.button("DEPLOY TO FRONTLINE", func(): deploy_requested.emit(Profile.next_mission()), true))
	actions.add_child(UITheme.button("CAMPAIGN MAP", func(): navigation_requested.emit("campaign")))
	actions.add_child(UITheme.button("ARSENAL & UPGRADES", func(): navigation_requested.emit("arsenal")))
	actions.add_child(UITheme.button("SETTINGS", func(): settings_return = "main"; navigation_requested.emit("settings")))
	content.add_child(UITheme.panel(actions, 24))
	box.add_child(content)
	box.add_child(UITheme.label("VERTICAL SLICE 0.1.0     /     NO ADS · NO PURCHASES · NO NETWORK REQUIRED", 15, UITheme.MUTED))
	_refresh_currency()

func _build_campaign() -> void:
	var box := _base("campaign")
	_heading(box, "CAMPAIGN / SABLE RIDGE")
	var content := UITheme.row(22)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	campaign_map = CampaignMap.new()
	campaign_map.mission_selected.connect(show_briefing)
	content.add_child(campaign_map)
	var info := UITheme.column(14)
	info.custom_minimum_size.x = 300
	info.add_child(UITheme.label("THEATER INTELLIGENCE", 18, UITheme.ACCENT, true))
	info.add_child(UITheme.wrapped("A remote desert garrison controls the mountain pass. Five sequential operations open the route to the ridge.", 21))
	info.add_child(UITheme.rule())
	campaign_summary = UITheme.label("", 22, UITheme.TEXT, true)
	info.add_child(campaign_summary)
	info.add_child(UITheme.wrapped("Earn up to three stars per operation. Stars unlock bragging rights; first clears supply upgrade points. Replays can improve your record.", 18))
	content.add_child(UITheme.panel(info))
	box.add_child(content)

func _build_briefing() -> void:
	var box := _base("briefing", 0.80)
	_heading(box, "MISSION BRIEFING", "campaign")
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := UITheme.column(16)
	content.custom_minimum_size.x = 900
	briefing_title = UITheme.label("", 50, UITheme.TEXT, true)
	briefing_subtitle = UITheme.label("", 20, UITheme.ACCENT, true)
	briefing_body = UITheme.wrapped("", 22, UITheme.TEXT)
	briefing_objectives = UITheme.wrapped("", 20, UITheme.MUTED)
	briefing_supply = UITheme.label("", 21, UITheme.ACCENT, true)
	for node in [briefing_title, briefing_subtitle, briefing_body, UITheme.rule(), briefing_objectives, briefing_supply]:
		content.add_child(node)
	var actions := UITheme.row(14)
	actions.add_child(UITheme.button("DEPLOY ARTILLERY", func(): deploy_requested.emit(selected_mission.id), true))
	actions.add_child(UITheme.button("REVIEW ARSENAL", func(): navigation_requested.emit("arsenal")))
	content.add_child(actions)
	center.add_child(UITheme.panel(content, 30))
	box.add_child(center)

func _build_arsenal() -> void:
	var box := _base("arsenal")
	_heading(box, "ARSENAL / ARTILLERY SELECTION")
	var content := UITheme.row(24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var identity := UITheme.column(16)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UITheme.label("FIELD ARTILLERY / 01", 18, UITheme.ACCENT, true))
	identity.add_child(UITheme.label("KESTREL\nM-42", 66, UITheme.TEXT, true))
	identity.add_child(UITheme.wrapped("155 mm towed howitzer. Split-trail carriage, independent traverse and elevation, hydro-pneumatic recoil and assisted ramming.", 23))
	identity.add_child(UITheme.button("EQUIP KESTREL M-42", func(): weapon_selected.emit("kestrel"), true))
	content.add_child(UITheme.panel(identity, 28))
	var stats := UITheme.column(16)
	stats.custom_minimum_size.x = 440
	stats.add_child(UITheme.label("WEAPON PERFORMANCE", 19, UITheme.MUTED))
	arsenal_stats = UITheme.label("", 25, UITheme.TEXT, true)
	stats.add_child(arsenal_stats)
	stats.add_child(UITheme.rule())
	stats.add_child(UITheme.wrapped("M72 HE · 17 m blast radius\nM91 AP · high-velocity armor penetrator\nBoth ammunition types are available in this milestone.", 20))
	stats.add_child(UITheme.button("FIELD MODIFICATIONS", func(): navigation_requested.emit("upgrades")))
	content.add_child(UITheme.panel(stats, 26))
	box.add_child(content)

func _build_upgrades() -> void:
	var box := _base("upgrades", 0.95)
	_heading(box, "FIELD MODIFICATIONS", "arsenal")
	box.add_child(UITheme.wrapped("Permanent offline upgrades. Each level consumes credits and one upgrade point earned from first clears.", 20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		var row := UITheme.row(20)
		var text := UITheme.column(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UITheme.label(upgrade.display_name, 24, UITheme.TEXT, true))
		text.add_child(UITheme.label(upgrade.description, 18, UITheme.MUTED))
		row.add_child(text)
		row.add_child(UITheme.label("LEVEL %d / %d" % [level, upgrade.maximum_level], 20, UITheme.ACCENT, true))
		var price: int = upgrade.cost(level)
		var button: Button = UITheme.button("MAXIMUM" if level >= upgrade.maximum_level else "INSTALL  /  %d CR + 1 PT" % price, func(): upgrade_requested.emit(id), level < upgrade.maximum_level)
		button.disabled = level >= upgrade.maximum_level or Profile.data.coins < price or Profile.data.upgrade_points < upgrade.points_per_level
		button.custom_minimum_size.x = 265
		row.add_child(button)
		upgrade_list.add_child(UITheme.panel(row, 16))

func _build_settings() -> void:
	var box := _base("settings", 0.97)
	var back := UITheme.button("BACK", func(): navigation_requested.emit(settings_return))
	var heading := UITheme.row()
	var title := UITheme.label("SYSTEM CONFIGURATION", 38, UITheme.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(back)
	box.add_child(heading)
	box.add_child(UITheme.rule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 16)
	var quality := OptionButton.new()
	for item in ["AUTO / ADAPTIVE", "LOW / PERFORMANCE", "MEDIUM / BALANCED", "HIGH / QUALITY"]:
		quality.add_item(item)
	quality.select(["auto", "low", "medium", "high"].find(Profile.data.settings.quality))
	quality.item_selected.connect(func(index): Profile.set_setting("quality", ["auto", "low", "medium", "high"][index]))
	_add_setting(grid, "GRAPHICS PROFILE", "Sustained frame-time adaptation in AUTO", quality)
	var fps := OptionButton.new()
	fps.add_item("60 FPS / RESPONSIVE")
	fps.add_item("30 FPS / BATTERY")
	fps.select(0 if Profile.data.settings.fps_target == 60 else 1)
	fps.item_selected.connect(func(index): Profile.set_setting("fps_target", 60 if index == 0 else 30))
	_add_setting(grid, "FRAME-RATE TARGET", "Gameplay simulation remains fixed at 60 Hz", fps)
	_add_slider(grid, "AIM SENSITIVITY", "Touch and mouse drag multiplier", "sensitivity", 0.3, 2.5)
	_add_slider(grid, "MASTER VOLUME", "All game audio", "master_volume", 0.0, 1.0)
	_add_slider(grid, "EFFECTS VOLUME", "Weapons, reloads and impacts", "sfx_volume", 0.0, 1.0)
	_add_slider(grid, "AMBIENCE VOLUME", "Original desert wind soundscape", "ambient_volume", 0.0, 1.0)
	_add_toggle(grid, "CAMERA SHAKE", "Controlled recoil and impact feedback", "camera_shake")
	_add_toggle(grid, "AUTOMATIC RELOAD", "Ram the next round after firing; manual reload remains available", "auto_reload")
	_add_toggle(grid, "ADVANCED AIR RESISTANCE", "Optional linear drag, shared by preview and live shells", "advanced_drag")
	_add_toggle(grid, "PERFORMANCE READOUT", "FPS, draw calls, resolution and active quality tier", "show_performance")
	scroll.add_child(grid)
	box.add_child(scroll)
	box.add_child(UITheme.label("MOBILE: Vulkan renderer · explicit OpenGL Compatibility package included. Preferences save locally.", 16, UITheme.MUTED))

func _add_setting(grid: GridContainer, title: String, description: String, control: Control) -> void:
	var text := UITheme.column(0)
	text.add_child(UITheme.label(title, 22, UITheme.TEXT, true))
	text.add_child(UITheme.label(description, 16, UITheme.MUTED))
	grid.add_child(text)
	control.custom_minimum_size = Vector2(420, 48)
	grid.add_child(control)

func _add_slider(grid: GridContainer, title: String, description: String, key: String, minimum: float, maximum: float) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = float(Profile.data.settings[key])
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var caption := UITheme.label(title + "  /  %.2f" % slider.value, 22, UITheme.TEXT, true)
	var text := UITheme.column(0)
	text.add_child(caption)
	text.add_child(UITheme.label(description, 16, UITheme.MUTED))
	grid.add_child(text)
	slider.custom_minimum_size = Vector2(420, 42)
	slider.value_changed.connect(func(value): caption.text = title + "  /  %.2f" % value)
	slider.drag_ended.connect(func(changed): if changed: Profile.set_setting(key, slider.value))
	slider.focus_exited.connect(func(): Profile.set_setting(key, slider.value))
	grid.add_child(slider)

func _add_toggle(grid: GridContainer, title: String, description: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = "ENABLED" if Profile.data.settings[key] else "DISABLED"
	toggle.button_pressed = bool(Profile.data.settings[key])
	toggle.toggled.connect(func(enabled): toggle.text = "ENABLED" if enabled else "DISABLED"; Profile.set_setting(key, enabled))
	_add_setting(grid, title, description, toggle)

func _build_pause() -> void:
	var box := _base("pause", 0.72)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var content := UITheme.column(14)
	content.custom_minimum_size.x = 480
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(UITheme.label("OPERATION PAUSED", 44, UITheme.TEXT, true))
	content.add_child(UITheme.label("Simulation and mission clock are suspended.", 19, UITheme.MUTED))
	content.add_child(UITheme.button("RESUME OPERATION", func(): resume_requested.emit(), true))
	content.add_child(UITheme.button("RESTART MISSION", func(): restart_requested.emit()))
	content.add_child(UITheme.button("SETTINGS", func(): settings_return = "pause"; navigation_requested.emit("settings")))
	content.add_child(UITheme.button("ABORT TO COMMAND", func(): abort_requested.emit()))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(UITheme.panel(content, 32))
	box.add_child(center)

func _build_results() -> void:
	var box := _base("results", 0.78)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := UITheme.column(14)
	content.custom_minimum_size.x = 760
	result_title = UITheme.label("SECTOR SECURED", 54, UITheme.ACCENT, true)
	result_stars = UITheme.label("★ ★ ★", 44, UITheme.ACCENT, true)
	result_stats = UITheme.label("", 24, UITheme.TEXT)
	result_rewards = UITheme.label("", 25, UITheme.GREEN, true)
	for node in [result_title, result_stars, UITheme.rule(), result_stats, result_rewards]:
		content.add_child(node)
	var actions := UITheme.row(12)
	next_button = UITheme.button("NEXT OPERATION", func(): next_requested.emit(), true)
	actions.add_child(next_button)
	actions.add_child(UITheme.button("REPLAY", func(): restart_requested.emit()))
	actions.add_child(UITheme.button("COMMAND", func(): navigation_requested.emit("main")))
	content.add_child(actions)
	center.add_child(UITheme.panel(content, 32))
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
		campaign_summary.text = "%d / 5 OPERATIONS\n%d / 15 STARS\n%d UPGRADE POINTS" % [Profile.data.completed.size(), Profile.data.stars, Profile.data.upgrade_points]
	if id == "arsenal":
		_refresh_arsenal()
	if id == "upgrades":
		_refresh_upgrades()
	_refresh_currency()

func show_briefing(id: String) -> void:
	selected_mission = load("res://resources/missions/%s.tres" % id)
	briefing_title.text = "%s / %s" % [selected_mission.sector, selected_mission.title]
	briefing_subtitle.text = selected_mission.subtitle.to_upper()
	briefing_body.text = selected_mission.briefing
	var objectives: String = "PRIMARY OBJECTIVES\n"
	for target_id in selected_mission.target_ids:
		objectives += "  ◆  Neutralize %s\n" % target_id.to_upper()
	objectives += "\nOPTIONAL  /  Destroy %s for a commendation" % selected_mission.optional_crate_id.to_upper()
	briefing_objectives.text = objectives
	briefing_supply.text = "HE %d   /   AP %d      TIME %d:%02d      BASE REWARD %d CR" % [selected_mission.ammunition.he, selected_mission.ammunition.ap, int(selected_mission.time_limit) / 60, int(selected_mission.time_limit) % 60, selected_mission.base_reward]
	show_screen("briefing")

func show_results(result: Dictionary) -> void:
	last_result = result
	var success: bool = result.success
	result_title.text = "SECTOR SECURED" if success else "OPERATION FAILED"
	result_title.add_theme_color_override("font_color", UITheme.ACCENT if success else UITheme.RED)
	var stars: int = int(result.get("stars", 0))
	result_stars.text = "★ ".repeat(stars) + "☆ ".repeat(3 - stars)
	result_stats.text = "TARGET ACCURACY     %.0f%%\nROUNDS FIRED             %d\nPRIMARY OBJECTIVES  %d / %d\nMISSION TIME              %02d:%02d\nOPTIONAL COMMENDATION  %s" % [result.accuracy, result.shots, result.objectives, result.required, int(result.time) / 60, int(result.time) % 60, "EARNED" if result.optional else "NOT EARNED"]
	result_rewards.text = "+ %d CREDITS    /    + %d UPGRADE POINTS" % [result.coins, result.get("points", 0)] if success else result.reason
	var index: int = ["sr01", "sr02", "sr03", "sr04", "sr05"].find(str(result.mission_id))
	next_button.visible = success and index < 4
	show_screen("results")

func _refresh_arsenal() -> void:
	var levels: Dictionary = Profile.data.upgrades
	arsenal_stats.text = "IMPACT DAMAGE    %d%%\nMUZZLE VELOCITY  %.1f m/s\nRELOAD TIME         %.2f s\nDISPERSION           %.2f°\nFIELD MAGAZINE   +%d rounds" % [roundi(100 * (1 + 0.08 * levels.damage)), 82.0 * (1 + 0.05 * levels.range), 3.4 * (1 - 0.1 * levels.reload), 0.32 * pow(0.82, levels.accuracy), 2 * levels.capacity]

func _refresh_currency() -> void:
	if currency_label:
		currency_label.text = "%d CR   /   %d ★   /   %d PT" % [Profile.data.coins, Profile.data.stars, Profile.data.upgrade_points]

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
