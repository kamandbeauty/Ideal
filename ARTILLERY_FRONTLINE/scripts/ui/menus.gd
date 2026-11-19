class_name Menus
extends CanvasLayer
## Title, armory, settings, pause and result screens. Ordinary Controls: these
## are the only places where taps go through Godot's GUI instead of the touch
## router. The spatial layout stays left-to-right in both languages.
## Deployment goes through the campaign map, then the weapon selection.

signal play_requested
signal resume_requested
signal restart_requested
signal menu_requested
## The player picked the stage PLAY will start (counted from 0).
signal stage_chosen(index: int)
## From the result of a stage that was won: go straight on to the one after it.
signal next_requested
## The player picked the gun that stands on the mount (an id from Profile.GUNS).
signal gun_chosen(id: String)

const FADE_TIME: float = 0.16
## A button that asks to be pressed twice stays armed this long.
const CONFIRM_TIME: float = 3.0
## Width of the title poster and of the armory column.
const TITLE_WIDTH: float = 640.0
const ARMORY_WIDTH: float = 660.0
const CYAN := Color(0.19, 0.78, 0.84)
const SETTINGS_GREEN := Color(0.55, 0.92, 0.18)
static var photo_edge_shader: Shader

var screen: String = ""
var came_from: String = "main"
var dim: ColorRect
var holder: Control
var result_victory: bool = false
var result_stats: Dictionary = {}
## The match just finished went further than any before it.
var result_record: bool = false
## The stage just won has one after it: the result screen offers to go on.
var result_onward: bool = false
## The stage the title screen shows as chosen, counted from 0. Game keeps it in step with its own.
var stage: int = 0
var stage_brief: Label
var stage_choices: MenuWidgets.Choices
var map_page: int = 0
var neighborhood_button: Button
var hospital_button: Button
var metro_button: Button
var region_buttons: Array[Button] = []
var region_label: Label
var gun_choices: MenuWidgets.Choices
var gun_note: Label
var gun_preview: WeaponPreview
var weapon_photo: TextureRect
var gun_preview_name: Label
var gun_stats: Label
var equipment_choices: MenuWidgets.Choices
var equipment_id: String = "twin_hmg"
var equipment_group: String = "guns"
var equipment_return: String = "main"
var equipment_summary: Label
var wallet_label: Label
var upgrade_button: Button
var equip_button: Button
var reward_label: Label
var ad_button: Button
## The title (and loading) START control. Playthrough taps this rather than searching labels.
var play_button: Button
## What the pause screen says about the match in progress: wave, waves, wall, gate.
var pause_status: Dictionary = {}
var fade: Tween
var armed: Button = null
var armed_left: float = 0.0
var armed_text: String = ""
## Tests and the screenshot run set this to lay the screens out as if the display had cut-outs: (left, right) in canvas units.
var inset_override := Vector2(-1.0, -1.0)
## The canvas and the side margins the open screen was built for; when either changes it is built again.
var built_view := Vector2.ZERO
var built_margins := Vector2.ZERO
var layout_check: float = 0.0
## Values survive a screen rebuild on a language or viewport change.
var loading_startup: bool = false
var loading_progress: float = 0.0
var loading_message: String = "loading_world"
var loading_bar: ProgressBar
var loading_status: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.025, 0.55)
	add_child(dim)
	holder = Control.new()
	holder.name = "Screen"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.theme = UITheme.theme()
	add_child(holder)
	Events.language_changed.connect(_on_language_changed)
	get_viewport().size_changed.connect(func() -> void: layout_check = 0.0)
	hide_all()


func _process(delta: float) -> void:
	if armed != null:
		armed_left -= delta
		if armed_left <= 0.0:
			_disarm()
	if screen == "":
		return
	layout_check -= delta
	if layout_check <= 0.0:
		# A phone turned over moves its camera cut-out to the other side without resizing anything;
		# a folding phone or a split screen changes the shape of the canvas itself.
		layout_check = 1.0
		if not _is_laid_out():
			_show(screen, false)


## Whether the open screen still fits the canvas and the cut-outs it was built for.
func _is_laid_out() -> bool:
	return get_viewport().get_visible_rect().size.is_equal_approx(built_view) and _side_margins().is_equal_approx(built_margins)


func _on_language_changed() -> void:
	UITheme.refresh_fonts()
	if screen != "":
		_show(screen)


func hide_all() -> void:
	screen = ""
	dim.visible = false
	holder.visible = false
	_clear()


func is_open() -> bool:
	return screen != ""


func _clear() -> void:
	armed = null
	stage_brief = null
	stage_choices = null
	neighborhood_button = null
	hospital_button = null
	metro_button = null
	region_buttons.clear()
	region_label = null
	gun_choices = null
	gun_note = null
	gun_preview = null
	weapon_photo = null
	gun_preview_name = null
	gun_stats = null
	equipment_choices = null
	equipment_summary = null
	wallet_label = null
	upgrade_button = null
	equip_button = null
	reward_label = null
	ad_button = null
	play_button = null
	loading_bar = null
	loading_status = null
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


func _show(name: String, fade_in: bool = true) -> void:
	screen = name
	_clear()
	built_view = get_viewport().get_visible_rect().size
	built_margins = _side_margins()
	layout_check = 1.0
	dim.visible = true
	holder.visible = true
	holder.layout_direction = Control.LAYOUT_DIRECTION_LTR  # Keep the approved composition fixed in both languages.
	match name:
		"main":
			# The street stays in the picture; a veil over it so the poster reads.
			dim.color = Color(0.02, 0.02, 0.028, 0.46)
			_build_main()
		"arsenal":
			dim.color = Color(0.02, 0.02, 0.028, 0.62)
			_build_arsenal()
		"equipment":
			dim.color = Color(0.02, 0.02, 0.028, 0.80)
			_build_equipment()
		"upgrade":
			dim.color = Color(0.02, 0.02, 0.028, 0.80)
			_build_upgrade()
		"campaign":
			dim.color = Color(0.02, 0.02, 0.028, 1.0)
			_build_campaign()
		"settings":
			dim.color = Color(0.02, 0.02, 0.025, 0.74)
			_build_settings()
		"pause":
			dim.color = Color(0.02, 0.02, 0.025, 0.66)
			_build_pause()
		"result":
			dim.color = Color(0.05, 0.01, 0.01, 0.72) if not result_victory else Color(0.01, 0.035, 0.02, 0.66)
			_build_result()
		"loading":
			dim.color = Color(0.02, 0.02, 0.025, 1.0)
			_build_loading()
	if fade != null and fade.is_valid():
		fade.kill()
	if not fade_in:
		holder.modulate.a = 1.0
		return
	holder.modulate.a = 0.0
	fade = create_tween()
	fade.tween_property(holder, "modulate:a", 1.0, FADE_TIME)


func show_main() -> void:
	_show("main")


func show_arsenal() -> void:
	_show("arsenal")


func show_equipment() -> void:
	equipment_return = "arsenal" if screen == "arsenal" else "main"
	equipment_group = "guns"
	equipment_id = String(Profile.setting("gun"))
	_show("equipment")


func show_upgrade() -> void:
	_show("upgrade")


func show_campaign() -> void:
	map_page = Campaign.district(stage) / 3
	_show("campaign")


func show_pause(status: Dictionary = {}) -> void:
	if not status.is_empty():
		pause_status = status
	_show("pause")


func show_settings(from: String) -> void:
	came_from = from
	_show("settings")


func show_result(victory: bool, stats: Dictionary, record: bool = false, onward: bool = false) -> void:
	result_victory = victory
	result_stats = stats
	result_record = record
	result_onward = victory and onward
	_show("result")


## Covers the scene during startup and while the next match is instantiated.
func show_loading(startup: bool = false) -> void:
	loading_startup = startup
	loading_progress = 0.0
	loading_message = "loading_world" if startup else "loading_deploy"
	_show("loading", false)


## The bar follows resource loading and scene setup; it does not invent a percentage.
func set_loading_progress(value: float, message: String = "") -> void:
	loading_progress = clampf(value, 0.0, 1.0)
	if message != "":
		loading_message = message
	if is_instance_valid(loading_bar):
		loading_bar.value = loading_progress * 100.0
	if is_instance_valid(loading_status):
		loading_status.text = Loc.t(loading_message)


# -- Building blocks -----------------------------------------------------------------
## Clear space at the (left, right) of the screen: the HUD's margins, so menus clear the same cut-outs.
func _side_margins() -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	if inset_override.x >= 0.0:
		return Hud.margins_for(view, inset_override)
	var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	return Hud.margins_for(view, Hud.insets_for(view, window, DisplayServer.get_display_safe_area()))


func _frame(extra: float = 0.0) -> MarginContainer:
	var margins: Vector2 = _side_margins()
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", int(margins.x + extra))
	frame.add_theme_constant_override("margin_right", int(margins.y + extra))
	frame.add_theme_constant_override("margin_top", 16)
	frame.add_theme_constant_override("margin_bottom", 16)
	holder.add_child(frame)
	return frame


## A panel in the middle of the screen with a column inside it.
func _panel(width: float) -> VBoxContainer:
	var frame: MarginContainer = _frame()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	frame.add_child(panel)
	return column


func _heading(text: String, size: int, color: Color, centered: bool = true) -> Label:
	var label: Label = UITheme.label(text, size, color, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	return label


func _text(text: String, size: int = UITheme.BODY, color: Color = UITheme.MUTED, centered: bool = true) -> Label:
	var label: Label = UITheme.label(text, size, color, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A button that must be pressed twice: the first press arms it and says so.
func _confirm_button(text: String, action: Callable) -> Button:
	var button: Button = UITheme.button(text, func() -> void: pass)
	button.pressed.connect(func() -> void:
		if armed == button:
			_disarm()
			action.call()
		else:
			_disarm()
			armed = button
			armed_text = text
			armed_left = CONFIRM_TIME
			button.text = Loc.t("confirm")
			UITheme.paint_button(button, "danger"))
	return button


func _disarm() -> void:
	if armed != null and is_instance_valid(armed):
		armed.text = armed_text
		UITheme.paint_button(armed, "plain")
	armed = null


# -- Title -----------------------------------------------------------------------------
## Cinematic key art with a compact top identity and an accessible bottom action bar.
func _background(path: String, tint: Color = Color.WHITE) -> void:
	var art := TextureRect.new()
	art.name = "MenuBackdrop"
	art.texture = load(path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = tint
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(art)


## Positions from the approved concept, inside the same device-safe rectangle in either language.
func _zone(node: Control, rect: Rect2, element_name: String = "") -> void:
	if element_name != "":
		node.name = element_name
	# Zone labels are single-line and clipped to the approved rectangle; their
	# autowrap minimum must not be measured at zero width before placement.
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		node.clip_text = true
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var available := Vector2(built_view.x - built_margins.x - built_margins.y - 32.0, built_view.y - 32.0)
	node.position = Vector2(built_margins.x + 16.0, 16.0) + rect.position * available
	node.size = rect.size * available
	holder.add_child(node)


func _plate() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.025, 0.022, 0.019, 0.91), Color(0.68, 0.49, 0.27, 0.9), 2, 2, 14))
	return panel


func _column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	return column


func _build_main() -> void:
	_background("res://assets/textures/branding/tehran_main.jpg")
	var title := UITheme.outline(_heading("LAST WALL", 68, UITheme.TEXT), 5)
	title.add_theme_font_override("font", load("res://assets/fonts/Rajdhani-SemiBold.ttf"))
	_zone(title, Rect2(0.61, 0.01, 0.36, 0.12), "MainTitle")
	var buttons := _column()
	buttons.add_theme_constant_override("separation", 12)
	_zone(buttons, Rect2(0.68, 0.23, 0.29, 0.62), "MainActions")
	play_button = UITheme.button(Loc.t("play"), show_campaign, "accent", "ui_start")
	play_button.name = "MainPlay"
	buttons.add_child(play_button)
	buttons.add_child(UITheme.button(Loc.t("armory"), show_equipment))
	buttons.add_child(UITheme.button(Loc.t("settings"), func() -> void: show_settings("main")))
	for button: Button in buttons.get_children():
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var balance := _heading(Loc.t("coin_balance", [Loc.number(int(Profile.data.economy.coins))]), 22, UITheme.AMBER, false)
	_zone(balance, Rect2(0.01, 0.01, 0.30, 0.06), "MainBalance")
	var tagline := _column()
	_zone(tagline, Rect2(0.01, 0.70, 0.48, 0.10), "MainTagline")
	tagline.add_child(UITheme.outline(_text(Loc.t("subtitle"), 19, UITheme.AMBER, false), 3))
	tagline.add_child(UITheme.outline(_text(Loc.t("tagline"), 19, UITheme.TEXT, false), 3))
	var totals: Dictionary = Profile.data.stats
	if int(totals.matches) > 0:
		var career := _column()
		_zone(career, Rect2(0.01, 0.83, 0.48, 0.14), "MainCareer")
		if int(totals.best_wave) > 0:
			var place: Vector2i = Campaign.place_of(int(totals.best_wave))
			career.add_child(UITheme.outline(_text(Loc.t("best_run", [place.x, place.y]), 18, UITheme.TEXT, false), 3))
		career.add_child(UITheme.outline(_text(Loc.t("career", [int(totals.matches), int(totals.victories), int(totals.kills)]), 18, UITheme.TEXT, false), 3))


# -- Campaign map ----------------------------------------------------------------------
## Three real stage choices, not decorative map pins: locked stages stay locked.
func _build_campaign() -> void:
	_background("res://assets/textures/branding/tehran_campaign_map.jpg")
	var map_art: TextureRect = holder.get_child(holder.get_child_count() - 1) as TextureRect
	_zone(UITheme.button(Loc.t("back"), show_main, "plain", "ui_back"), Rect2(0.01, 0.01, 0.15, 0.11), "CampaignBack")
	_zone(UITheme.outline(_heading(Loc.t("choose_neighborhood"), 30, UITheme.TEXT), 4), Rect2(0.25, 0.02, 0.50, 0.08), "MapPrompt")
	var names: Array = []
	var open: int = Campaign.open_stages(int(Profile.data.stats.stages_cleared))
	for index: int in Campaign.count():
		names.append(Loc.t("stage_n", [index + 1]))
	stage = clampi(stage, 0, open - 1)
	stage_choices = MenuWidgets.Choices.new(names, stage)
	stage_choices.name = "CampaignStages"
	holder.add_child(stage_choices)
	for index: int in range(open, Campaign.count()):
		stage_choices.lock(index)
	stage_choices.chosen.connect(func(index: int) -> void:
		stage = index
		stage_brief.text = stage_brief_for(index)
		stage_chosen.emit(index))
	for index: int in stage_choices.buttons.size():
		var button: Button = stage_choices.buttons[index]
		stage_choices.remove_child(button)
		button.text = Loc.number(index + 1)
		_zone(button, Rect2(0.05 + 0.135 * (index % 3), 0.68, 0.12, 0.12), "MapStage%d" % (index + 1))
		button.visible = false
	stage_choices.visible = false
	var region_keys: Array[String] = ["neighborhood_city", "neighborhood_hospital", "neighborhood_metro",
		"neighborhood_industrial", "neighborhood_bazaar", "neighborhood_terminal", "neighborhood_towers",
		"neighborhood_stadium", "neighborhood_refinery", "neighborhood_citadel"]
	for district: int in region_keys.size():
		var name: String = Loc.t(region_keys[district]).split("  •")[0]
		var button: Button = UITheme.button(name, func() -> void:
			_select_district(district, map_art), "plain")
		button.add_theme_font_size_override("font_size", UITheme.font_size(18))
		button.clip_text = true
		var pos := Vector2(0.01 + (district % 5) * 0.198, 0.18 + (district / 5) * 0.14)
		var node_name: String = ["Neighborhood", "HospitalNeighborhood", "MetroNeighborhood"][district] if district < 3 else "Region%d" % district
		_zone(button, Rect2(pos, Vector2(0.185, 0.115)), node_name)
		region_buttons.append(button)
	neighborhood_button = region_buttons[0]
	hospital_button = region_buttons[1]
	metro_button = region_buttons[2]
	_zone(UITheme.outline(_text(Loc.t("choose_stage"), 22, UITheme.TEXT), 3), Rect2(0.05, 0.57, 0.39, 0.06), "StagePrompt")
	region_label = UITheme.outline(_text(Loc.t("region_page", [Loc.number(Campaign.district(stage) + 1), Loc.number(10)]), 18, UITheme.TEXT), 3)
	_zone(region_label, Rect2(0.05, 0.85, 0.39, 0.05), "DistrictPage")
	var info := _plate()
	_zone(info, Rect2(0.61, 0.58, 0.37, 0.38), "MissionBrief")
	var details := _column()
	info.add_child(details)
	details.add_child(_heading(Loc.t("mission_brief"), 23, UITheme.AMBER))
	stage_brief = _text(stage_brief_for(stage), 21, UITheme.TEXT)
	details.add_child(stage_brief)
	details.add_child(UITheme.button(Loc.t("select_weapon"), show_arsenal, "accent", "ui_start"))


func _select_district(district: int, map_art: TextureRect) -> void:
	if district < 0 or district >= 10:
		return
	# The first three areas retain their individual illustrations; the other
	# districts share the Tehran overview so all locations remain navigable.
	var art: String = "res://assets/textures/branding/tehran_campaign_map.jpg"
	if district == 0:
		art = "res://assets/textures/branding/design_map.png"
	elif district == 1:
		art = "res://assets/textures/branding/hospital_district.png"
	elif district == 2:
		art = "res://assets/textures/branding/metro_district.png"
	map_art.texture = load(art)
	for index: int in region_buttons.size():
		UITheme.paint_button(region_buttons[index], "accent" if index == district else "plain")
	region_label.text = Loc.t("region_page", [Loc.number(district + 1), Loc.number(10)])
	map_page = district / 3
	var first: int = district * 3
	if stage < first or stage >= first + 3:
		stage_choices._choose(first)
	stage_choices.visible = true
	for index: int in stage_choices.buttons.size():
		stage_choices.buttons[index].visible = index >= first and index < first + 3
	stage_brief.text = stage_brief_for(stage)

# -- Armory ----------------------------------------------------------------------------
## After PLAY: pick the stage and the gun, then go to the wall. The street behind
## the menu shows the gun that is lit.
func _build_arsenal() -> void:
	_background("res://assets/textures/branding/armory_bunker.jpg")
	_zone(UITheme.outline(_heading(Loc.t("armory"), 40, UITheme.TEXT), 4), Rect2(0.25, 0.01, 0.50, 0.07), "ArsenalTitle")
	_zone(UITheme.button(Loc.t("back"), show_campaign, "plain", "ui_back"), Rect2(0.84, 0.01, 0.14, 0.11), "ArsenalBack")
	var gallery := _column()
	gallery.add_child(UITheme.outline(_heading(Loc.t("weapon_preview"), 20, UITheme.TEXT), 3))
	_zone(gallery, Rect2(0.02, 0.13, 0.54, 0.78), "ArsenalGallery")
	weapon_photo = TextureRect.new()
	weapon_photo.name = "WeaponPhoto"
	weapon_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Fade only the edges of the still photo into the same dark studio. The
	# centre and stand remain an ordinary 2D image, not a 3D viewport.
	if photo_edge_shader == null:
		photo_edge_shader = Shader.new()
		photo_edge_shader.code = """shader_type canvas_item;
void fragment() {
	float edge = smoothstep(0.0, 0.10, UV.x) * smoothstep(0.0, 0.10, 1.0 - UV.x);
	edge *= smoothstep(0.0, 0.08, UV.y) * smoothstep(0.0, 0.08, 1.0 - UV.y);
	COLOR.a *= edge;
}
"""
	var edge_material := ShaderMaterial.new()
	edge_material.shader = photo_edge_shader
	weapon_photo.material = edge_material
	weapon_photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery.add_child(weapon_photo)
	gun_preview_name = UITheme.outline(_heading(Loc.t(gun_data(String(Profile.setting("gun"))).name_key), 30, UITheme.TEXT), 3)
	gallery.add_child(gun_preview_name)
	gun_stats = UITheme.outline(_text(gun_stats_for(String(Profile.setting("gun"))), 20, UITheme.TEXT), 3)
	gallery.add_child(gun_stats)
	_show_weapon_photo(String(Profile.setting("gun")))
	var card := _plate()
	_zone(card, Rect2(0.60, 0.13, 0.38, 0.84), "ArsenalControls")
	var plan := _column()
	card.add_child(plan)
	var open: int = Campaign.open_stages(int(Profile.data.stats.stages_cleared))
	var stages: Array = []
	for index: int in Campaign.count():
		stages.append(Loc.t("stage_n", [index + 1]))
	stage = clampi(stage, 0, open - 1)
	stage_brief = _text(stage_brief_for(stage), 19, UITheme.TEXT)
	stage_brief.custom_minimum_size.y = 40.0
	stage_brief.autowrap_mode = TextServer.AUTOWRAP_OFF
	stage_brief.clip_text = true
	plan.add_child(stage_brief)
	stage_choices = MenuWidgets.Choices.new(stages, stage)
	stage_choices.name = "ArsenalStages"
	# The map changes district; the armory only shows its three stage choices.
	for index: int in stage_choices.buttons.size():
		stage_choices.buttons[index].visible = index / 3 == stage / 3
	for index: int in range(open, Campaign.count()):
		stage_choices.lock(index)
	stage_choices.chosen.connect(func(index: int) -> void:
		stage = index
		stage_brief.text = stage_brief_for(index)
		stage_chosen.emit(index))
	plan.add_child(stage_choices)
	# Stage is chosen on the map; this internal selection stays hidden here.
	stage_choices.visible = false
	var names: Array = []
	var outlines: Array = []
	for id: String in Profile.GUNS:
		var gun: WeaponData = gun_data(id)
		names.append(Loc.t(gun.name_key))
		outlines.append(gun.icon)
	gun_choices = MenuWidgets.Choices.new(names, maxi(Profile.GUNS.find(String(Profile.setting("gun"))), 0), outlines, 2)
	gun_choices.name = "ArsenalWeapons"
	gun_choices.glyph_strip = 52.0
	gun_choices.content_bottom = 22.0
	for index: int in gun_choices.buttons.size():
		var choice: Button = gun_choices.buttons[index]
		choice.custom_minimum_size.y = 110.0
		choice.add_theme_font_size_override("font_size", UITheme.font_size(16))
		var specs: Label = _text(gun_stats_for(Profile.GUNS[index]), 12, UITheme.MUTED)
		specs.name = "WeaponStats"
		specs.autowrap_mode = TextServer.AUTOWRAP_OFF
		specs.clip_text = true
		specs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		specs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		specs.offset_left = 4.0
		specs.offset_right = -4.0
		specs.offset_top = -21.0
		specs.offset_bottom = -3.0
		choice.add_child(specs)
	_add_weapon_thumbnails(gun_choices, Profile.GUNS, 50.0)
	gun_choices.select(gun_choices.selected)
	gun_choices.chosen.connect(func(index: int) -> void:
		gun_note.text = gun_note_for(Profile.GUNS[index])
		gun_preview_name.text = Loc.t(gun_data(Profile.GUNS[index]).name_key)
		gun_stats.text = gun_stats_for(Profile.GUNS[index])
		_show_weapon_photo(Profile.GUNS[index])
		gun_chosen.emit(Profile.GUNS[index]))
	plan.add_child(gun_choices)
	gun_note = _text(gun_note_for(String(Profile.setting("gun"))), 16, UITheme.TEXT)
	gun_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	gun_note.clip_text = true
	gun_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gun_note.custom_minimum_size.y = 32.0
	plan.add_child(gun_note)
	play_button = UITheme.button(Loc.t("deploy"), func() -> void: play_requested.emit(), "accent", "ui_start")
	plan.add_child(play_button)
	plan.add_child(UITheme.button(Loc.t("equipment_upgrades"), show_equipment))


## One static, compressed render per gun: no extra 3D world on this screen.
func _show_weapon_photo(id: String) -> void:
	if weapon_photo != null:
		weapon_photo.texture = load("res://assets/textures/branding/weapons/stand_%s.jpg" % id)


func _add_weapon_thumbnails(choices: MenuWidgets.Choices, ids: Array, image_height: float = 40.0) -> void:
	for index: int in ids.size():
		var path: String = "res://assets/textures/branding/weapons/%s.png" % ids[index]
		if not ResourceLoader.exists(path):
			continue
		if choices.glyphs[index] != null:
			choices.glyphs[index].visible = false
		var image := TextureRect.new()
		image.texture = load(path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		image.offset_top = 2.0
		image.offset_bottom = image_height
		choices.buttons[index].add_child(image)


## Equipment workshop: all five mounted guns plus the equipped RPG and grenade.
func _build_equipment() -> void:
	_background("res://assets/textures/branding/design_workshop.png")
	_zone(UITheme.button(Loc.t("back"), func() -> void:
		if equipment_return == "arsenal":
			show_arsenal()
		else:
			show_main(), "plain", "ui_back"), Rect2(0.01, 0.01, 0.16, 0.11), "EquipmentBack")
	_zone(UITheme.outline(_heading(Loc.t("equipment_upgrades"), 42, UITheme.TEXT), 4), Rect2(0.25, 0.01, 0.55, 0.09), "EquipmentTitle")
	wallet_label = UITheme.outline(_heading(Loc.t("coin_balance", [Loc.number(int(Profile.data.economy.coins))]), 24, UITheme.AMBER, false), 3)
	_zone(wallet_label, Rect2(0.01, 0.14, 0.20, 0.08), "EquipmentBalance")
	_zone(UITheme.outline(_text(Loc.t("select_equipment"), 20, UITheme.TEXT, false), 3), Rect2(0.01, 0.25, 0.20, 0.06), "EquipmentPrompt")
	_zone(UITheme.outline(_text(Loc.t("select_equipment_hint"), 17, UITheme.TEXT, false), 3), Rect2(0.01, 0.32, 0.20, 0.15), "EquipmentHint")
	_zone(UITheme.button(Loc.t("machine_guns"), func() -> void:
		equipment_group = "guns"
		_show("equipment"), "accent" if equipment_group == "guns" else "plain"), Rect2(0.23, 0.12, 0.32, 0.10), "MachineGunsTab")
	_zone(UITheme.button(Loc.t("explosives"), func() -> void:
		equipment_group = "explosives"
		_show("equipment"), "accent" if equipment_group == "explosives" else "plain"), Rect2(0.58, 0.12, 0.36, 0.10), "ExplosivesTab")
	var labels: Array = []
	var icons: Array = []
	for id: String in Profile.EQUIPMENT:
		if Profile.GRENADES.has(id):
			labels.append(Loc.t("grenade" if id == "frag_grenade" else "blast_grenade"))
			icons.append("grenade")
		else:
			var item: WeaponData = Profile.launcher_data(id) if Profile.LAUNCHERS.has(id) else gun_data(id)
			labels.append(Loc.t(item.name_key))
			icons.append(item.icon)
	equipment_choices = MenuWidgets.Choices.new(labels, maxi(Profile.EQUIPMENT.find(equipment_id), 0), icons, 4)
	equipment_choices.allow_reselect = true
	equipment_choices.glyph_strip = 130.0
	for button: Button in equipment_choices.buttons:
		button.custom_minimum_size.y = 205.0
	_add_weapon_thumbnails(equipment_choices, Profile.EQUIPMENT, 128.0)
	equipment_choices.select(equipment_choices.selected)
	equipment_choices.chosen.connect(func(index: int) -> void:
		equipment_id = Profile.EQUIPMENT[index]
		show_upgrade())
	_zone(equipment_choices, Rect2(0.23, 0.18, 0.74, 0.74), "EquipmentCards")
	# Match the concept: three cards on the first row, four on the second.
	for index: int in equipment_choices.buttons.size():
		var button: Button = equipment_choices.buttons[index]
		equipment_choices.remove_child(button)
		var active: bool = (index < Profile.GUNS.size()) == (equipment_group == "guns")
		var position_in_group: int = index if index < Profile.GUNS.size() else index - Profile.GUNS.size()
		var col: int = position_in_group % 3
		var row: int = position_in_group / 3
		_zone(button, Rect2(0.23 + 0.22 * col, 0.26 + 0.34 * row, 0.20, 0.29), "EquipmentCard%d" % index)
		button.visible = active


func _build_upgrade() -> void:
	_background("res://assets/textures/branding/armory_studio.jpg")
	_zone(UITheme.button(Loc.t("back"), func() -> void: _show("equipment"), "plain", "ui_back"), Rect2(0.01, 0.01, 0.16, 0.11), "UpgradeBack")
	gun_preview = WeaponPreview.new()
	_zone(gun_preview, Rect2(0.02, 0.16, 0.62, 0.72), "UpgradePreview")
	var card := _plate()
	_zone(card, Rect2(0.67, 0.06, 0.31, 0.86), "UpgradeDetails")
	var plan := _column()
	plan.add_theme_constant_override("separation", 18)
	card.add_child(plan)
	gun_preview_name = _heading("", 30, UITheme.TEXT)
	gun_preview_name.custom_minimum_size.y = 72.0
	plan.add_child(gun_preview_name)
	wallet_label = _heading("", 24, UITheme.AMBER)
	wallet_label.custom_minimum_size.y = 60.0
	plan.add_child(wallet_label)
	plan.add_child(_spacer(20))
	equipment_summary = _text("", 21, UITheme.TEXT)
	equipment_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	equipment_summary.clip_text = true
	equipment_summary.custom_minimum_size.y = 60.0
	plan.add_child(equipment_summary)
	equip_button = UITheme.button(Loc.t("equip"), func() -> void:
		if Profile.GUNS.has(equipment_id):
			gun_chosen.emit(equipment_id)
		elif Profile.LAUNCHERS.has(equipment_id):
			Profile.set_setting("launcher", equipment_id)
		elif Profile.GRENADES.has(equipment_id):
			Profile.set_setting("grenade", equipment_id)
		_refresh_equipment(false))
	equip_button.name = "EquipButton"
	plan.add_child(equip_button)
	upgrade_button = UITheme.button("", func() -> void:
		if Profile.buy_upgrade(equipment_id):
			_refresh_equipment(false), "accent")
	upgrade_button.name = "UpgradeButton"
	plan.add_child(upgrade_button)
	_refresh_equipment(true)


func _refresh_equipment(rebuild_preview: bool) -> void:
	var level: int = Profile.upgrade_level(equipment_id)
	var cost: int = Profile.upgrade_cost(equipment_id)
	wallet_label.text = Loc.t("coin_balance", [Loc.number(int(Profile.data.economy.coins))])
	if Profile.GRENADES.has(equipment_id):
		gun_preview_name.text = Loc.t("grenade" if equipment_id == "frag_grenade" else "blast_grenade")
	else:
		var item: WeaponData = Profile.launcher_data(equipment_id) if Profile.LAUNCHERS.has(equipment_id) else gun_data(equipment_id)
		gun_preview_name.text = Loc.t(item.name_key)
	var setting_key: String = "gun" if Profile.GUNS.has(equipment_id) else ("launcher" if Profile.LAUNCHERS.has(equipment_id) else "grenade")
	var equipped: bool = String(Profile.setting(setting_key)) == equipment_id
	equip_button.text = Loc.t("equipped") if equipped else Loc.t("equip")
	equip_button.disabled = equipped
	equipment_summary.text = Loc.t("upgrade_details", [Loc.number(level), Loc.number(Profile.MAX_UPGRADE), Loc.number(level * 12)])
	upgrade_button.text = Loc.t("upgrade_max") if cost == 0 else Loc.t("upgrade_cost", [Loc.number(cost)])
	upgrade_button.disabled = cost == 0 or int(Profile.data.economy.coins) < cost
	if rebuild_preview:
		gun_preview.show_weapon(equipment_id)


func _build_loading() -> void:
	_background("res://assets/textures/branding/tehran_loading.jpg" if loading_startup else "res://assets/textures/branding/design_battlefield.png")
	holder.get_child(holder.get_child_count() - 1).name = "LoadingArt"
	var title := UITheme.outline(_heading("LAST WALL", 72, UITheme.TEXT), 5)
	title.add_theme_font_override("font", load("res://assets/fonts/Rajdhani-SemiBold.ttf"))
	_zone(title, Rect2(0.23, 0.02, 0.54, 0.12), "LoadingTitle")
	var column := _column()
	_zone(column, Rect2(0.20, 0.76, 0.60, 0.22), "LoadingContent")
	loading_bar = ProgressBar.new()
	loading_bar.name = "LoadingProgress"
	loading_bar.custom_minimum_size = Vector2(0.0, 18.0)
	loading_bar.min_value = 0.0
	loading_bar.max_value = 100.0
	loading_bar.value = loading_progress * 100.0
	loading_bar.show_percentage = false
	loading_bar.add_theme_stylebox_override("background", UITheme.box(Color(0.08, 0.07, 0.06, 0.95), UITheme.AMBER, 2, 1, 0))
	loading_bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.AMBER, UITheme.AMBER, 2, 0, 0))
	column.add_child(loading_bar)
	loading_status = UITheme.outline(_heading(Loc.t(loading_message), 28, UITheme.TEXT), 3)
	loading_status.name = "LoadingStatus"
	column.add_child(loading_status)
	column.add_child(UITheme.outline(_text(Loc.t("loading_hint"), 20, UITheme.TEXT), 3))


static func stage_brief_for(index: int) -> String:
	var waves: WaveSet = Campaign.waves(index)
	return Loc.t("stage_brief", [index + 1, waves.waves.size(), waves.total_zombies()])


static func gun_data(id: String) -> WeaponData:
	return load("res://resources/weapons/%s.tres" % id) as WeaponData


## Readouts are taken from the selected gun's real combat data.
static func gun_stats_for(id: String) -> String:
	var data: WeaponData = gun_data(id)
	return Loc.t("weapon_specs", [Loc.number(int(data.damage)), Loc.number(int(round(1.0 / data.fire_interval))), Loc.number(data.magazine_size)])


## One line on what a gun is good for, with its rate of fire and the length of its belt taken from its numbers.
static func gun_note_for(id: String) -> String:
	var gun: WeaponData = gun_data(id)
	return Loc.t("gun_note_" + id, [int(round(1.0 / gun.fire_interval)), gun.magazine_size])


# -- Pause -----------------------------------------------------------------------------
func _build_pause() -> void:
	var panel := _plate()
	_zone(panel, Rect2(0.36, 0.13, 0.28, 0.78), "PausePanel")
	var column := _column()
	panel.add_child(column)
	column.add_child(_heading(Loc.t("paused"), 34, UITheme.TEXT))
	if not pause_status.is_empty():
		var parts: PackedStringArray = []
		if int(pause_status.get("stage", 0)) > 0:
			parts.append(Loc.t("stage_n", [int(pause_status.stage)]))
		if int(pause_status.get("wave", 0)) > 0:
			parts.append(Loc.t("wave", [int(pause_status.wave), int(pause_status.get("waves", 0))]))
		parts.append("%s  %s" % [Loc.t("gate"), Loc.percent(float(pause_status.get("gate", 1.0)))])
		parts.append("%s  %s" % [Loc.t("wall"), Loc.percent(float(pause_status.get("wall", 1.0)))])
		column.add_child(_text("   ·   ".join(parts), 19, UITheme.TEXT))
	column.add_child(UITheme.button(Loc.t("resume"), func() -> void: resume_requested.emit(), "accent"))
	column.add_child(UITheme.button(Loc.t("settings"), func() -> void: show_settings("pause")))
	column.add_child(_confirm_button(Loc.t("restart"), func() -> void: restart_requested.emit()))
	column.add_child(_confirm_button(Loc.t("main_menu"), func() -> void: menu_requested.emit()))


# -- Result ----------------------------------------------------------------------------
func _build_result() -> void:
	_background("res://assets/textures/branding/design_battlefield.png", Color(0.78, 0.78, 0.78))
	var color: Color = UITheme.AMBER if result_victory else UITheme.RED
	var title: String = Loc.t("victory_title" if result_victory else "defeat_title")
	var story: String = Loc.t("victory_text" if result_victory else "defeat_text")
	if result_onward:
		title = Loc.t("stage_won_title", [int(result_stats.get("stage", 0)) + 1])
		story = Loc.t("stage_won_text")
	if not result_victory and int(result_stats.get("wave", 0)) > 0:
		story += "  " + Loc.t("fell_in_wave", [int(result_stats.get("stage", 0)) + 1, int(result_stats.wave)])
	_zone(UITheme.outline(_heading(title, 52, color), 5), Rect2(0.25, 0.02, 0.50, 0.10), "ResultTitle")
	_zone(UITheme.outline(_text(story, 20, UITheme.TEXT), 3), Rect2(0.16, 0.14, 0.68, 0.09), "ResultStory")
	var first: Array = [
		["kills", Loc.number(int(result_stats.get("kills", 0)))],
		["accuracy", Loc.percent(float(result_stats.get("accuracy", 0.0)))],
		["waves_held", "%s / %s" % [Loc.number(int(result_stats.get("waves_cleared", 0))), Loc.number(int(result_stats.get("waves_total", 0)))]],
		["time", Loc.clock(float(result_stats.get("time", 0.0)))],
		["wall_left", Loc.percent(float(result_stats.get("wall_left", 0.0)))],
		["gate_left", Loc.percent(float(result_stats.get("gate_left", 0.0)))],
		["explosives_used", "%s + %s" % [Loc.number(int(result_stats.get("rockets", 0))), Loc.number(int(result_stats.get("grenades", 0)))]],
	]
	var stats_panel := _plate()
	_zone(stats_panel, Rect2(0.24, 0.27, 0.27, 0.44), "ResultStats")
	stats_panel.add_child(_stat_column(first))
	var prize := _plate()
	_zone(prize, Rect2(0.55, 0.27, 0.27, 0.44), "ResultReward")
	var prize_column := _column()
	prize.add_child(prize_column)
	if result_record:
		prize_column.add_child(_heading(Loc.t("new_record"), 22, UITheme.AMBER))
	reward_label = _heading("", 30, UITheme.AMBER)
	prize_column.add_child(reward_label)
	var earned: int = int(result_stats.get("coins_earned", Profile.reward_for(result_stats)))
	var countup: Tween = reward_label.create_tween()
	countup.tween_method(func(amount: float) -> void:
		if is_instance_valid(reward_label):
			reward_label.text = Loc.t("coins_won", [Loc.number(int(round(amount)))]), 0.0, float(earned), 1.1)
	if result_victory:
		ad_button = UITheme.button(Loc.t("double_ad_unavailable"), func() -> void: pass)
		ad_button.disabled = true
		ad_button.add_theme_font_size_override("font_size", UITheme.font_size(17))
		prize_column.add_child(ad_button)
	else:
		prize_column.add_child(_text(Loc.t("defeat_text"), 23, UITheme.TEXT))
	var leave: Button = UITheme.button(Loc.t("main_menu"), func() -> void: menu_requested.emit())
	_zone(leave, Rect2(0.08, 0.83, 0.24, 0.12), "ResultMenu")
	var again: Button = UITheme.button(Loc.t("restart"), func() -> void: restart_requested.emit(), "plain" if result_onward else "accent", "ui_start")
	_zone(again, Rect2(0.38, 0.83, 0.24, 0.12), "ResultRestart")
	if result_onward:
		_zone(UITheme.button(Loc.t("next_stage"), func() -> void: next_requested.emit(), "accent", "ui_start"), Rect2(0.68, 0.83, 0.24, 0.12), "ResultNext")


func _stat_column(rows: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	for row: Array in rows:
		var line := HBoxContainer.new()
		var name_label: Label = UITheme.label(Loc.t(row[0]), 19, UITheme.MUTED, true)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var value_label: Label = UITheme.label(row[1], 23, UITheme.TEXT, true)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(name_label)
		line.add_child(value_label)
		column.add_child(line)
	return column


# -- Settings --------------------------------------------------------------------------
func _build_settings() -> void:
	_background("res://assets/textures/branding/design_bunker.png")
	_zone(UITheme.outline(_heading(Loc.t("title"), 46, UITheme.TEXT), 4), Rect2(0.26, 0.01, 0.48, 0.08), "SettingsTitle")
	_zone(UITheme.outline(_heading(Loc.t("settings"), 36, UITheme.TEXT), 4), Rect2(0.30, 0.09, 0.40, 0.07), "SettingsHeading")
	var panel := _plate()
	_zone(panel, Rect2(0.03, 0.20, 0.94, 0.63), "SettingsPanel")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	panel.add_child(columns)
	var sound: VBoxContainer = _group("group_sound")
	sound.add_child(_slider_row("music_volume", 0.0, 1.0, 0.05))
	sound.add_child(_slider_row("sfx_volume", 0.0, 1.0, 0.05))
	sound.add_child(_slider_row("master_volume", 0.0, 1.0, 0.05))
	var controls: VBoxContainer = _group("group_controls")
	controls.add_child(_check_row("screen_shake"))
	controls.add_child(_check_row("invert_y"))
	controls.add_child(_check_row("left_handed"))
	controls.add_child(_slider_row("sensitivity", 0.3, 2.5, 0.05))
	var display: VBoxContainer = _group("group_display")
	display.add_child(_choice_row("language", ["فارسی", "English"], Profile.LANGUAGES.find(Loc.language),
		func(index: int) -> void: Profile.set_setting("language", Profile.LANGUAGES[index]), 190.0))
	var qualities: Array = []
	for choice: String in Profile.QUALITY_CHOICES:
		qualities.append(Loc.t("quality_" + choice))
	var quality := MenuWidgets.Choices.new(qualities, Profile.QUALITY_CHOICES.find(String(Profile.setting("quality"))))
	quality.chosen.connect(func(index: int) -> void: Profile.set_setting("quality", Profile.QUALITY_CHOICES[index]))
	display.add_child(quality)
	display.add_child(_check_row("show_fps"))
	columns.add_child(sound)
	columns.add_child(controls)
	columns.add_child(display)
	_zone(UITheme.button(Loc.t("back"), func() -> void: _show(came_from), "plain", "ui_back"), Rect2(0.01, 0.86, 0.17, 0.12), "SettingsBack")


func _group_title(key: String) -> Label:
	var title: Label = UITheme.label(Loc.t(key), 22, UITheme.AMBER, true)
	title.custom_minimum_size = Vector2(0.0, 45.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return title


func _group(key: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 4)
	group.add_child(_group_title(key))
	return group


func _row(key: String) -> MenuWidgets.Row:
	var row := MenuWidgets.Row.new()
	row.name = "Setting_" + key
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR  # Same control positions for both translations.
	var label: Label = UITheme.label(Loc.t(key), 20, UITheme.TEXT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


func _readout(key: String, value: float) -> String:
	if key == "sensitivity":
		return Loc.number("%.2f" % value) + "×"
	return Loc.percent(value)


func _slider_row(key: String, low: float, high: float, step: float) -> MenuWidgets.Row:
	var row: MenuWidgets.Row = _row(key)
	var slider := MenuWidgets.SlideBar.new(low, high, step, Profile.setting(key))
	slider.accent = UITheme.AMBER
	slider.custom_minimum_size = Vector2(140.0, 72.0)
	var readout: Label = UITheme.label(_readout(key, slider.value), 22, UITheme.AMBER, true)
	readout.custom_minimum_size = Vector2(55.0, 0.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# While the thumb is moving the value is applied but not written to storage; it is saved once on release.
	slider.value_changed.connect(func(value: float) -> void:
		Profile.set_setting(key, value, false)
		readout.text = _readout(key, value))
	slider.released.connect(func() -> void:
		Profile.save()
		if key != "sensitivity":
			Sound.play("click", -6.0))
	row.add_child(slider)
	row.add_child(readout)
	return row


func _check_row(key: String) -> MenuWidgets.Row:
	var row: MenuWidgets.Row = _row(key)
	var toggle := MenuWidgets.Switch.new(bool(Profile.setting(key)))
	toggle.accent = UITheme.AMBER
	toggle.toggled.connect(func(pressed: bool) -> void: Profile.set_setting(key, pressed))
	row.toggle = toggle
	row.add_child(toggle)
	return row


## A setting with a few named choices, beside its name.
func _choice_row(key: String, labels: Array, selected: int, action: Callable, width: float) -> MenuWidgets.Row:
	var row: MenuWidgets.Row = _row(key)
	var choices := MenuWidgets.Choices.new(labels, selected)
	choices.accent = UITheme.AMBER
	choices.select(choices.selected)
	choices.custom_minimum_size = Vector2(width, 0.0)
	choices.chosen.connect(action)
	row.add_child(choices)
	return row


func _toggle_language() -> void:
	Profile.set_setting("language", "en" if Loc.language == "fa" else "fa")
