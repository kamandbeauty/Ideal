class_name Menus
extends CanvasLayer
## Title, settings, pause and result screens. Ordinary Controls: these are the
## only places where taps go through Godot's GUI instead of the touch router.
## Every screen is laid out for the reading direction of the language in use.
## Buttons and the rows of the settings screen are 88 canvas units high and
## its choice buttons 84 (7.4 and 7.0 mm on a 6.5-inch phone).

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
## Widths of the two blocks of the title screen: the title itself, and the card of the coming battle.
const TITLE_WIDTH: float = 540.0
const PLAN_WIDTH: float = 560.0

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
var gun_choices: MenuWidgets.Choices
var gun_note: Label
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
	gun_choices = null
	gun_note = null
	play_button = null
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
	holder.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	match name:
		"main":
			# The title screen leaves the street in view: only the side the column stands on is darkened.
			dim.color = Color(0.02, 0.02, 0.025, 0.18)
			_build_main()
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
			dim.color = Color(0.02, 0.02, 0.025, 0.82)
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


## Covers the street while the next match is instantiated, so the hitch is not a frozen title.
func show_loading() -> void:
	_show("loading")


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
## The title stands at the reading edge of the screen and the coming battle on a card at the far one:
## which stage, which gun, and the button that starts it. The gun itself shows below, between the two.
func _build_main() -> void:
	var shade := MenuWidgets.Shade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(shade)
	var frame: MarginContainer = _frame(26.0)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(TITLE_WIDTH, 0.0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)
	column.add_child(MenuWidgets.Stripes.new())
	column.add_child(_heading(Loc.t("title"), 84, UITheme.AMBER, false))
	column.add_child(_heading(Loc.t("subtitle"), 32, UITheme.TEXT, false))
	column.add_child(_text(Loc.t("tagline"), 24, UITheme.MUTED, false))
	column.add_child(_spacer(10))
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 10)
	var settings_button: Button = UITheme.button(Loc.t("settings"), func() -> void: show_settings("main"))
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var language_button: Button = UITheme.button("English" if Loc.language == "fa" else "فارسی", _toggle_language)
	language_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(settings_button)
	pair.add_child(language_button)
	column.add_child(pair)
	var totals: Dictionary = Profile.data.stats
	if int(totals.matches) > 0:
		var record: String = ""
		if int(totals.best_wave) > 0:
			var place: Vector2i = Campaign.place_of(int(totals.best_wave))
			record = Loc.t("best_run", [place.x, place.y])
		var career: String = Loc.t("career", [int(totals.matches), int(totals.victories), int(totals.kills)])
		column.add_child(_text(record + ("\n" if record != "" else "") + career, 20, UITheme.TEXT, false))
	column.add_child(_text(Loc.t("version", [Loc.number(String(ProjectSettings.get_setting("application/config/version", "")))]), 20, UITheme.MUTED, false))

	# The card stands a third of the way down its side, clear of the gun in the lower part of the picture.
	var rail := VBoxContainer.new()
	rail.size_flags_horizontal = Control.SIZE_SHRINK_END
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_theme_constant_override("separation", 0)
	frame.add_child(rail)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(PLAN_WIDTH, 0.0)
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.032, 0.038, 0.8), UITheme.LINE, 10, 1, 16))
	for share: float in [1.0, 2.0]:
		var gap := Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gap.size_flags_stretch_ratio = share
		rail.add_child(gap)
	rail.add_child(card)
	rail.move_child(card, 1)
	var plan := VBoxContainer.new()
	plan.add_theme_constant_override("separation", 10)
	card.add_child(plan)
	# Which stage PLAY starts: every stage already won and the one after; the rest wait under a padlock.
	var open: int = Campaign.open_stages(int(totals.stages_cleared))
	var stages: Array = []
	for index: int in Campaign.count():
		stages.append(Loc.t("stage_n", [index + 1]))
	stage = clampi(stage, 0, open - 1)
	stage_brief = _text(stage_brief_for(stage), 22, UITheme.TEXT, false)
	plan.add_child(stage_brief)
	stage_choices = MenuWidgets.Choices.new(stages, stage)
	for index: int in range(open, Campaign.count()):
		stage_choices.lock(index)
	stage_choices.chosen.connect(func(index: int) -> void:
		stage = index
		stage_brief.text = stage_brief_for(index)
		stage_chosen.emit(index))
	plan.add_child(stage_choices)
	# Which gun stands on the mount. All five sit in one row so none are clipped
	# off the card; the street behind the menu shows the one that is lit.
	var names: Array = []
	var outlines: Array = []
	for id: String in Profile.GUNS:
		var gun: WeaponData = gun_data(id)
		names.append(Loc.t(gun.name_key + "_short"))
		outlines.append(gun.icon)
	gun_choices = MenuWidgets.Choices.new(names, maxi(Profile.GUNS.find(String(Profile.setting("gun"))), 0), outlines, 0)
	gun_choices.chosen.connect(func(index: int) -> void:
		gun_note.text = gun_note_for(Profile.GUNS[index])
		gun_chosen.emit(Profile.GUNS[index]))
	plan.add_child(gun_choices)
	gun_note = _text(gun_note_for(String(Profile.setting("gun"))), 20, UITheme.MUTED, false)
	# Room for two lines whichever gun is chosen, so the card does not jump when the choice changes.
	gun_note.custom_minimum_size = Vector2(0.0, gun_note.get_line_height() * 2.0 + 4.0)
	plan.add_child(gun_note)
	play_button = UITheme.button(Loc.t("play"), func() -> void: play_requested.emit(), "accent", "ui_start")
	plan.add_child(play_button)


func _build_loading() -> void:
	var column: VBoxContainer = _panel(480.0)
	column.add_child(_heading(Loc.t("get_ready"), 56, UITheme.AMBER))


## What a stage holds, in a line: its number, its waves and how many zombies it fields.
static func stage_brief_for(index: int) -> String:
	var waves: WaveSet = Campaign.waves(index)
	return Loc.t("stage_brief", [index + 1, waves.waves.size(), waves.total_zombies()])


static func gun_data(id: String) -> WeaponData:
	return load("res://resources/weapons/%s.tres" % id) as WeaponData


## One line on what a gun is good for, with its rate of fire and the length of its belt taken from its numbers.
static func gun_note_for(id: String) -> String:
	var gun: WeaponData = gun_data(id)
	return Loc.t("gun_note_" + id, [int(round(1.0 / gun.fire_interval)), gun.magazine_size])


# -- Pause -----------------------------------------------------------------------------
func _build_pause() -> void:
	var column: VBoxContainer = _panel(580.0)
	column.add_child(MenuWidgets.Stripes.new())
	column.add_child(_heading(Loc.t("paused"), 54, UITheme.TEXT))
	if not pause_status.is_empty():
		# Where the match stands, so RESTART and MAIN MENU are weighed against what would be lost.
		var parts: PackedStringArray = []
		if int(pause_status.get("stage", 0)) > 0:
			parts.append(Loc.t("stage_n", [int(pause_status.stage)]))
		if int(pause_status.get("wave", 0)) > 0:
			parts.append(Loc.t("wave", [int(pause_status.wave), int(pause_status.get("waves", 0))]))
		parts.append("%s %s" % [Loc.t("wall"), Loc.percent(float(pause_status.get("wall", 1.0)))])
		parts.append("%s %s" % [Loc.t("gate"), Loc.percent(float(pause_status.get("gate", 1.0)))])
		column.add_child(_text("   ·   ".join(parts), 24, UITheme.MUTED))
	column.add_child(_spacer(2))
	column.add_child(UITheme.button(Loc.t("resume"), func() -> void: resume_requested.emit(), "accent"))
	column.add_child(_confirm_button(Loc.t("restart"), func() -> void: restart_requested.emit()))
	column.add_child(UITheme.button(Loc.t("settings"), func() -> void: show_settings("pause")))
	column.add_child(_confirm_button(Loc.t("main_menu"), func() -> void: menu_requested.emit()))


# -- Result ----------------------------------------------------------------------------
func _build_result() -> void:
	var column: VBoxContainer = _panel(1080.0)
	var color: Color = UITheme.GREEN if result_victory else UITheme.RED
	column.add_child(MenuWidgets.Stripes.new())
	var title: String = Loc.t("victory_title" if result_victory else "defeat_title")
	var story: String = Loc.t("victory_text" if result_victory else "defeat_text")
	if result_onward:
		# A stage was held and the siege goes on: the last word is kept for the last stage.
		title = Loc.t("stage_won_title", [int(result_stats.get("stage", 0)) + 1])
		story = Loc.t("stage_won_text")
	column.add_child(_heading(title, 60, color))
	if not result_victory and int(result_stats.get("wave", 0)) > 0:
		story += "  " + Loc.t("fell_in_wave", [int(result_stats.get("stage", 0)) + 1, int(result_stats.wave)])
	column.add_child(_text(story, 24, UITheme.TEXT))
	if result_record:
		column.add_child(_heading(Loc.t("new_record"), 24, UITheme.AMBER))
	column.add_child(MenuWidgets.Rule.new(8.0))
	var first: Array = [
		["waves_held", "%s / %s" % [Loc.number(int(result_stats.get("waves_cleared", 0))), Loc.number(int(result_stats.get("waves_total", 0)))]],
		["time", Loc.clock(float(result_stats.get("time", 0.0)))],
		["wall_left", Loc.percent(float(result_stats.get("wall_left", 0.0)))],
		["gate_left", Loc.percent(float(result_stats.get("gate_left", 0.0)))],
		["accuracy", Loc.percent(float(result_stats.get("accuracy", 0.0)))],
	]
	var second: Array = [
		["kills", Loc.number(int(result_stats.get("kills", 0)))],
		["headshots", Loc.number(int(result_stats.get("headshots", 0)))],
		["special_kills", Loc.number(int(result_stats.get("special_kills", 0)))],
		["blast_kills", Loc.number(int(result_stats.get("blast_kills", 0)))],
		["explosives_used", "%s + %s" % [Loc.number(int(result_stats.get("rockets", 0))), Loc.number(int(result_stats.get("grenades", 0)))]],
	]
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	columns.add_child(_stat_column(first))
	columns.add_child(_stat_column(second))
	column.add_child(columns)
	column.add_child(MenuWidgets.Rule.new(8.0))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	if result_onward:
		var onward: Button = UITheme.button(Loc.t("next_stage"), func() -> void: next_requested.emit(), "accent", "ui_start")
		onward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(onward)
	var again: Button = UITheme.button(Loc.t("restart"), func() -> void: restart_requested.emit(), "plain" if result_onward else "accent",
		"ui_start")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var leave: Button = UITheme.button(Loc.t("main_menu"), func() -> void: menu_requested.emit())
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(again)
	buttons.add_child(leave)
	column.add_child(buttons)


func _stat_column(rows: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	for row: Array in rows:
		var line := HBoxContainer.new()
		var name_label: Label = UITheme.label(Loc.t(row[0]), 24, UITheme.MUTED, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var value_label: Label = UITheme.label(row[1], 30, UITheme.TEXT, true)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(name_label)
		line.add_child(value_label)
		column.add_child(line)
	return column


# -- Settings --------------------------------------------------------------------------
func _build_settings() -> void:
	var column: VBoxContainer = _panel(1200.0)
	column.add_child(_heading(Loc.t("settings"), 36, UITheme.TEXT))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 52)
	var controls: VBoxContainer = _group("group_controls")
	controls.add_child(_slider_row("sensitivity", 0.3, 2.5, 0.05))
	controls.add_child(_check_row("invert_y"))
	controls.add_child(_check_row("left_handed"))
	controls.add_child(_check_row("screen_shake"))
	controls.add_child(_choice_row("language", ["فارسی", "English"], Profile.LANGUAGES.find(Loc.language),
		func(index: int) -> void: Profile.set_setting("language", Profile.LANGUAGES[index]), 300.0))
	var sound: VBoxContainer = _group("group_sound")
	sound.add_child(_slider_row("master_volume", 0.0, 1.0, 0.05))
	sound.add_child(_slider_row("sfx_volume", 0.0, 1.0, 0.05))
	sound.add_child(_slider_row("music_volume", 0.0, 1.0, 0.05))
	# Four words do not fit beside a label on a phone, so the quality choices sit under their own heading.
	sound.add_child(_group_title("group_display"))
	var qualities: Array = []
	for choice: String in Profile.QUALITY_CHOICES:
		qualities.append(Loc.t("quality_" + choice))
	var quality := MenuWidgets.Choices.new(qualities, Profile.QUALITY_CHOICES.find(String(Profile.setting("quality"))))
	quality.chosen.connect(func(index: int) -> void: Profile.set_setting("quality", Profile.QUALITY_CHOICES[index]))
	sound.add_child(quality)
	sound.add_child(_check_row("show_fps"))
	columns.add_child(controls)
	columns.add_child(sound)
	column.add_child(columns)
	column.add_child(UITheme.button(Loc.t("back"), func() -> void: _show(came_from), "accent", "ui_back"))


func _group_title(key: String) -> Label:
	var title: Label = UITheme.label(Loc.t(key), 22, UITheme.AMBER, true)
	title.custom_minimum_size = Vector2(0.0, 34.0)
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
	var label: Label = UITheme.label(Loc.t(key), UITheme.BODY, UITheme.TEXT, false)
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
	slider.custom_minimum_size = Vector2(250.0, 72.0)
	var readout: Label = UITheme.label(_readout(key, slider.value), 24, UITheme.AMBER, true)
	readout.custom_minimum_size = Vector2(76.0, 0.0)
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
	toggle.toggled.connect(func(pressed: bool) -> void: Profile.set_setting(key, pressed))
	row.toggle = toggle
	row.add_child(toggle)
	return row


## A setting with a few named choices, beside its name.
func _choice_row(key: String, labels: Array, selected: int, action: Callable, width: float) -> MenuWidgets.Row:
	var row: MenuWidgets.Row = _row(key)
	var choices := MenuWidgets.Choices.new(labels, selected)
	choices.custom_minimum_size = Vector2(width, 0.0)
	choices.chosen.connect(action)
	row.add_child(choices)
	return row


func _toggle_language() -> void:
	Profile.set_setting("language", "en" if Loc.language == "fa" else "fa")
