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
	UiKit.backdrop(self, "panel_frame")
	UiKit.color_rect(self, "wash", Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b, 0.72))

	UiKit.button(self, "back", "بازگشت", UiTokens.CANVAS_WIDTH - 16.0 - 84.0, 54.0, 84.0, 40.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_back, UiTokens.RADIUS_MD)

	var title := UiKit.label(self, "title", "تنظیمات", UiTokens.TYPE_LG, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(title, 16.0, 54.0, UiTokens.CANVAS_WIDTH - 32.0, 40.0)

	var labels := ["موسیقی", "جلوه‌های صوتی", "لرزش", "یادآوری تمرین"]
	var keys := ["music_on", "sfx_on", "haptics_on", "push_on"]
	for index in range(labels.size()):
		var y := 120.0 + float(index) * (ROW_HEIGHT + 8.0)
		var row := UiKit.art_panel(self, "row_%d" % index, 16.0, y, UiTokens.CANVAS_WIDTH - 32.0,
			ROW_HEIGHT, "panel_frame", UiTokens.BORDER_PANEL, UiTokens.SURFACE, UiTokens.RADIUS_MD)

		var caption := UiKit.label(row, "caption", labels[index], UiTokens.TYPE_BASE, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_RIGHT)
		UiKit.place(caption, 70.0, 0.0, UiTokens.CANVAS_WIDTH - 32.0 - 80.0, ROW_HEIGHT)

		var toggle := CheckButton.new()
		toggle.name = "toggle"
		toggle.text = ""
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.add_theme_stylebox_override("focus", UiKit.box(UiTokens.TRANSPARENT))
		row.add_child(toggle)
		UiKit.place(toggle, 8.0, (ROW_HEIGHT - 40.0) * 0.5, 52.0, 40.0)
		toggle.toggled.connect(Callable(self, "_on_toggled").bind(keys[index]))
		_switches.append({"key": keys[index], "toggle": toggle})

	var sample_panel := UiKit.art_panel(self, "sample", 16.0, 400.0, UiTokens.CANVAS_WIDTH - 32.0, 96.0,
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
	add_child(version)
	UiKit.place(version, 16.0, 512.0, UiTokens.CANVAS_WIDTH - 32.0, 20.0)

func refresh() -> void:
	if session == null:
		return
	for entry in _switches:
		var toggle: CheckButton = entry["toggle"]
		toggle.set_pressed_no_signal(bool(session.save.get(str(entry["key"]))))
	var font_ok := UiKit.medium_font() != null
	_font_line.text = ("فونت وزیر بارگذاری شد" if font_ok else "فونت وزیر پیدا نشد — فارسی درست دیده نمی‌شود") \
		+ " • شکل‌دهی متن با TextServer"

func _on_toggled(pressed: bool, key: String) -> void:
	if session == null or session.save == null:
		return
	match key:
		"music_on": session.save.music_on = pressed
		"sfx_on": session.save.sfx_on = pressed
		"haptics_on": session.save.haptics_on = pressed
		"push_on": session.save.push_on = pressed
	session.save_now()
	if SoundDirector.instance != null:
		SoundDirector.instance.apply_settings(session.save)

func _on_back() -> void:
	back_requested.emit()
