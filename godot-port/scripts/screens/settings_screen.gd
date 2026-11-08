class_name SettingsScreen
extends UiScreen
## Settings, ported from client/Assets/Game/Ui/SettingsScreen.cs.
##
## Four switches that all live in the save, plus the one thing a Persian-first game must prove: that
## the font on screen really is Vazir and that shaped Persian and Persian numerals render. The
## "Persian check" line below is the port's equivalent of PersianCheckView.cs — on Godot the shaping
## comes from the TextServer, so what a reviewer has to look at is this line, not a shaper setting.

signal back_requested

const ROW_HEIGHT := 56.0
const SAMPLE := "نمونهٔ فارسی: کاخِ شازده — ۱۲۳۴۵۶۷۸۹۰"

var _switches: Array[Dictionary] = []
var _sample: Label
var _font_line: Label

func build() -> void:
	set_backdrop("home_palace", 0.60, 0.55, 0.5, 0.95, 0.92)

	UiKit.button(self, "back", "بازگشت", UiTokens.CANVAS_WIDTH - 16.0 - 84.0, 54.0, 84.0, 40.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_back, UiTokens.RADIUS_MD)

	var title := UiKit.label(self, "title", "تنظیمات", UiTokens.TYPE_LG, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(title, 16.0, 54.0, UiTokens.CANVAS_WIDTH - 32.0, 40.0)

	var labels := ["موسیقی", "جلوه‌های صوتی", "لرزش", "یادآوری تمرین"]
	var keys := ["music_on", "sfx_on", "haptics_on", "push_on"]
	# One icon per row, drawn from the shipped set, so the screen says what each switch controls before
	# a player reads it.
	var icons := ["icon_music", "icon_sound", "icon_vibration", "icon_push"]
	for index in range(labels.size()):
		var y := 120.0 + float(index) * (ROW_HEIGHT + 8.0)
		var row := UiKit.art_panel(self, "row_%d" % index, 16.0, y, UiTokens.CANVAS_WIDTH - 32.0,
			ROW_HEIGHT, "panel_frame", UiTokens.BORDER_PANEL, UiTokens.SURFACE, UiTokens.RADIUS_MD)

		UiKit.icon(row, "glyph", icons[index], 62.0, (ROW_HEIGHT - 28.0) * 0.5, 28.0, 28.0)

		var caption := UiKit.label(row, "caption", labels[index], UiTokens.TYPE_BASE, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_RIGHT)
		UiKit.place(caption, 100.0, 0.0, UiTokens.CANVAS_WIDTH - 32.0 - 110.0, ROW_HEIGHT)

		# A CheckButton's default theme draws a small tick, not a switch, and an empty row of it reads as
		# "off" no matter what the save says. This is a real switch: track + knob, gold when on.
		var toggle := Button.new()
		toggle.name = "toggle"
		toggle.text = ""
		toggle.toggle_mode = true
		toggle.focus_mode = Control.FOCUS_NONE
		# The row is RTL, and an RTL container mirrors the x of every child it positions — including the
		# knob inside the switch. The switch is a piece of hardware, not text: keep it LTR so "on" is
		# always the right-hand end.
		toggle.layout_direction = Control.LAYOUT_DIRECTION_LTR
		toggle.add_theme_stylebox_override("focus", UiKit.box(UiTokens.TRANSPARENT))
		toggle.add_theme_stylebox_override("normal", UiKit.box(UiTokens.SURFACE_RAISED, 16))
		toggle.add_theme_stylebox_override("hover", UiKit.box(UiTokens.SURFACE_RAISED.lightened(0.08), 16))
		toggle.add_theme_stylebox_override("pressed", UiKit.box(UiTokens.GOLD, 16))
		toggle.add_theme_stylebox_override("hover_pressed", UiKit.box(UiTokens.GOLD, 16))
		row.add_child(toggle)
		UiKit.place(toggle, 8.0, (ROW_HEIGHT - 30.0) * 0.5, UiKit.SWITCH_WIDTH, 30.0)

		var knob := Panel.new()
		knob.name = "knob"
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		knob.add_theme_stylebox_override("panel", UiKit.box(UiTokens.TEXT_MUTED, 12))
		toggle.add_child(knob)
		UiKit.place(knob, 3.0, 3.0, 24.0, 24.0)

		toggle.toggled.connect(Callable(self, "_on_toggled").bind(keys[index]))
		_switches.append({"key": keys[index], "toggle": toggle, "knob": knob})

	var sample_panel := UiKit.art_panel(self, "sample", 16.0, 404.0, UiTokens.CANVAS_WIDTH - 32.0, 96.0,
		"panel_frame", UiTokens.BORDER_PANEL, UiTokens.SURFACE, UiTokens.RADIUS_MD)
	_sample = UiKit.label(sample_panel, "sample_text", SAMPLE, UiTokens.TYPE_BASE, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_sample, 12.0, 8.0, UiTokens.CANVAS_WIDTH - 56.0, 40.0)

	_font_line = UiKit.label(sample_panel, "font_line", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_font_line, 12.0, 52.0, UiTokens.CANVAS_WIDTH - 56.0, 36.0)
	_font_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var version := Label.new()
	version.name = "version"
	version.text = "نسخهٔ ۰٫۱٫۰ — Godot " + Engine.get_version_info().get("string", "")
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_override("font", UiKit.medium_font())
	version.add_theme_font_size_override("font_size", UiTokens.TYPE_XS)
	version.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	version.clip_text = true
	add_child(version)
	UiKit.place(version, 16.0, 516.0, UiTokens.CANVAS_WIDTH - 32.0, 20.0)

	var about := UiKit.art_panel(self, "about", 16.0, 556.0, UiTokens.CANVAS_WIDTH - 32.0, 96.0,
		"panel_frame", UiTokens.BORDER_PANEL, UiTokens.SURFACE, UiTokens.RADIUS_MD)
	var about_text := UiKit.label(about, "about_text",
		"کاخِ شازده — بازی مستقل با موتور گودو\nهمهٔ هنر از کد کشیده شده، بدون تصویر تولیدشده با هوش مصنوعی",
		UiTokens.TYPE_SM, UiTokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(about_text, 12.0, 8.0, UiTokens.CANVAS_WIDTH - 56.0, 80.0)
	about_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func refresh() -> void:
	if session == null:
		return
	for entry in _switches:
		var toggle: Button = entry["toggle"]
		toggle.set_pressed_no_signal(bool(session.save.get(str(entry["key"]))))
		_paint_switch(entry)
	var font_ok := UiKit.medium_font() != null
	_font_line.text = ("فونت وزیر بارگذاری شد" if font_ok else "فونت وزیر پیدا نشد — فارسی درست دیده نمی‌شود") \
		+ " • شکل‌دهی متن با TextServer"

## The knob is a child of the switch, so it has to move when the switch flips and when the save says
## what the switch should be. One place paints it: off is left and grey, on is right and gold.
func _paint_switch(entry: Dictionary) -> void:
	var toggle: Button = entry["toggle"]
	var knob: Panel = entry["knob"]
	# The row inherits the RTL layout direction, which mirrors a child's x. Pin the knob explicitly so
	# "on" is the right-hand end regardless of how the parent is mirrored.
	var width: float = UiKit.SWITCH_WIDTH
	var x := width - 27.0 if toggle.button_pressed else 3.0
	knob.position = Vector2(x, 3.0)
	# A knob is a knob: light against the track. ON_GOLD is nearly black (it is gold-surface text), and
	# a black dot on a gold track reads as "off" no matter which end it sits on.
	knob.add_theme_stylebox_override("panel",
		UiKit.box(UiTokens.TEXT if toggle.button_pressed else UiTokens.TEXT_MUTED, 12))

func _on_toggled(pressed: bool, key: String) -> void:
	if session == null or session.save == null:
		return
	match key:
		"music_on": session.save.music_on = pressed
		"sfx_on": session.save.sfx_on = pressed
		"haptics_on": session.save.haptics_on = pressed
		"push_on": session.save.push_on = pressed
	for entry in _switches:
		if str(entry["key"]) == key:
			_paint_switch(entry)
	session.save_now()
	if SoundDirector.instance != null:
		SoundDirector.instance.apply_settings(session.save)
	Haptics.apply_settings(session.save)

func _on_back() -> void:
	back_requested.emit()
