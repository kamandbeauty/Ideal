class_name HomeScreen
extends UiScreen
## The title screen, ported from client/Assets/Game/Ui/HomeScreen.cs.
##
## It shows the two numbers that decide whether the player can start — the level they are on and the
## lives they have left — and the four doors out of it. It never navigates by itself: it emits and
## AppRoot decides.

signal play_requested
signal districts_requested
signal shop_requested
signal settings_requested

const TITLE := "کاخِ شازده"
const SUBTITLE := "کاخ را از نو بساز"

var _level_label: Label
var _progress_label: Label
var _hint: Label
var _play_button: Button
var _stars: Array[TextureRect] = []
var _chapter_label: Label

func build() -> void:
	# The palace is the window's own picture (AppRoot paints it full-bleed at whatever shape the device
	# is); the screen only dims it enough for the title to read.
	set_backdrop("garden_dusk", 0.20, 0.5, 0.5, 0.80, 0.70)

	var title := UiKit.label(self, "title", TITLE, UiTokens.TYPE_DISPLAY, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(title, 0.0, 48.0, UiTokens.CANVAS_WIDTH, 52.0)

	var subtitle := UiKit.label(self, "subtitle", SUBTITLE, UiTokens.TYPE_BASE, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(subtitle, 0.0, 98.0, UiTokens.CANVAS_WIDTH, 22.0)

	# The card is the same width in either orientation, because it holds the same four lines; what
	# changes in landscape is that there is room to centre it and to put the doors on one row.
	const CARD_W := 330.0
	var card_x := (UiTokens.CANVAS_WIDTH - CARD_W) * 0.5
	var card := UiKit.art_panel(self, "card", card_x, 126.0, CARD_W, 126.0,
		"panel_frame", UiTokens.BORDER_CARD, UiTokens.SURFACE, UiTokens.RADIUS_PANEL)

	_chapter_label = UiKit.label(card, "chapter", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_chapter_label, 0.0, 6.0, CARD_W, 18.0)

	_level_label = UiKit.label(card, "level", "", UiTokens.TYPE_XL, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_level_label, 0.0, 22.0, CARD_W, 36.0)

	var star_row := Control.new()
	star_row.name = "stars"
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(star_row)
	UiKit.place(star_row, 0.0, 60.0, CARD_W, 26.0)
	var star_size := 24.0
	var total := star_size * 3.0 + 8.0 * 2.0
	for index in range(3):
		var star_x := (CARD_W - total) * 0.5 + float(index) * (star_size + 8.0)
		_stars.append(UiKit.icon(star_row, "star_%d" % index, "icon_star", star_x, 0.0, star_size, star_size))

	_progress_label = UiKit.label(card, "progress", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_progress_label, 0.0, 90.0, CARD_W, 20.0)

	_hint = UiKit.label(self, "hint", "", UiTokens.TYPE_SM, UiTokens.WARNING,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_hint, card_x, 254.0, CARD_W, 22.0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_play_button = UiKit.button(self, "play", "بازی", (UiTokens.CANVAS_WIDTH - 240.0) * 0.5, 280.0,
		240.0, 52.0, UiTokens.GOLD, UiTokens.ON_GOLD, _on_play, UiTokens.RADIUS_LG, true)
	_play_button.add_theme_font_size_override("font_size", UiTokens.TYPE_LG)

	var width := 116.0
	var gap := 10.0
	var row_y := 344.0
	var start_x := (UiTokens.CANVAS_WIDTH - (width * 3.0 + gap * 2.0)) * 0.5
	UiKit.button(self, "districts", "محله‌ها", start_x, row_y, width, 44.0, UiTokens.SURFACE_RAISED,
		UiTokens.TEXT, _on_districts, UiTokens.RADIUS_MD)
	UiKit.button(self, "shop", "فروشگاه", start_x + width + gap, row_y, width, 44.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_shop, UiTokens.RADIUS_MD)
	UiKit.button(self, "settings", "تنظیمات", start_x + (width + gap) * 2.0, row_y, width, 44.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_settings, UiTokens.RADIUS_MD)

func refresh() -> void:
	if session == null:
		return
	var level := session.current_level
	_level_label.text = "مرحله " + PersianText.number(level) + " " + PersianText.FROM_WORD + " " \
		+ PersianText.number(GameSession.LEVEL_COUNT)
	_chapter_label.text = "فصل اول — میدانِ فیروزه"
	_progress_label.text = "محله‌های ساخته‌شده: " + PersianText.fraction(session.built_districts(),
		session.districts.size())
	_stars_update(session.stars_for(level))

	var reason := session.blocked_reason(level)
	if reason.is_empty():
		_hint.text = ""
		_play_button.disabled = false
		_play_button.modulate = Color(1, 1, 1, 1)
	else:
		_hint.text = reason
		_play_button.disabled = true
		_play_button.modulate = Color(1, 1, 1, 0.7)

func _stars_update(stars: int) -> void:
	for index in range(_stars.size()):
		var node := _stars[index]
		if node == null:
			continue
		node.modulate = Color(1, 1, 1, 1) if index < stars else Color(0.35, 0.38, 0.45, 1.0)

func _on_play() -> void:
	SoundDirector.play("tap")
	play_requested.emit()

func _on_districts() -> void:
	districts_requested.emit()

func _on_shop() -> void:
	shop_requested.emit()

func _on_settings() -> void:
	settings_requested.emit()
