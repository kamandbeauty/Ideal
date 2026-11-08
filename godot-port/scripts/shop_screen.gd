extends Control

const GOLD := Color(1.0, 0.82, 0.43)
const CREAM := Color(1.0, 0.94, 0.78)
const DEEP := Color(0.018, 0.075, 0.078, 0.96)

var _save: SaveData
var _store: SaveStore
var _wallet: Wallet
var _bag: BoosterBag
var _status: Label
var _rows: VBoxContainer
var _coin_label: Label

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_apply_theme()
	_load_data()
	_build_ui()

func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 17
	theme = ui_theme

func _load_data() -> void:
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	_wallet = Wallet.new(_save)
	_bag = BoosterBag.new(_save)

func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = AssetCatalog.texture("res://assets/art/home_palace_lit.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.025, 0.03, 0.67)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "⌂ خانه"
	back.custom_minimum_size = Vector2(88, 46)
	_style_button(back, Color(0.035, 0.14, 0.15), GOLD)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "بازارِ باغ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)
	var crown := TextureRect.new()
	crown.texture = AssetCatalog.texture("res://assets/art/icon_crown.png")
	crown.custom_minimum_size = Vector2(42, 42)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(crown)

	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.10, 0.10, 0.96), Color(0.84, 0.67, 0.36, 0.94), 20, 12))
	layout.add_child(hero)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 10)
	hero.add_child(hero_row)
	var feature := TextureRect.new()
	feature.texture = AssetCatalog.texture("res://assets/art/store_feature.png")
	feature.custom_minimum_size = Vector2(84, 84)
	feature.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feature.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_row.add_child(feature)
	var hero_copy := VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_copy.add_theme_constant_override("separation", 3)
	hero_row.add_child(hero_copy)
	var headline := Label.new()
	headline.text = "ابزارهای ویژهٔ باغ"
	headline.add_theme_font_size_override("font_size", 19)
	headline.add_theme_color_override("font_color", GOLD)
	hero_copy.add_child(headline)
	var subline := Label.new()
	subline.text = "برای لحظه‌های سخت، یک کمکِ کوچک همراهت داشته باش"
	subline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subline.add_theme_font_size_override("font_size", 12)
	hero_copy.add_child(subline)

	var wallet := PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.085, 0.09, 0.93), Color(0.56, 0.62, 0.43, 0.68), 15, 9))
	layout.add_child(wallet)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 8)
	wallet.add_child(wallet_row)
	var coin_icon := TextureRect.new()
	coin_icon.texture = AssetCatalog.texture("res://assets/art/icon_coin.png")
	coin_icon.custom_minimum_size = Vector2(30, 30)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wallet_row.add_child(coin_icon)
	_coin_label = Label.new()
	_coin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coin_label.text = "موجودی سکه: %s" % _fa(_wallet.coins)
	_coin_label.add_theme_color_override("font_color", GOLD)
	wallet_row.add_child(_coin_label)
	var potion_label := Label.new()
	potion_label.text = "◈  %s" % _fa(_wallet.potions)
	wallet_row.add_child(potion_label)

	var section := Label.new()
	section.text = "ابزارهای قابل خرید"
	section.add_theme_color_override("font_color", GOLD)
	section.add_theme_font_size_override("font_size", 17)
	layout.add_child(section)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.9, 0.86, 0.68))
	layout.add_child(_status)
	_rebuild()

func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_coin_label.text = "موجودی سکه: %s" % _fa(_wallet.coins)
	for kind in range(BoosterBag.SLOTS):
		_add_booster_card(kind)

func _add_booster_card(kind: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.06, 0.065, 0.97), Color(0.68, 0.58, 0.37, 0.83), 17, 9))
	_rows.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)

	var art_frame := PanelContainer.new()
	art_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.12, 0.12), Color(0.72, 0.62, 0.4, 0.55), 13, 4))
	row.add_child(art_frame)
	var art := TextureRect.new()
	art.texture = AssetCatalog.booster_texture(kind)
	art.custom_minimum_size = Vector2(66, 70)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_frame.add_child(art)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	var name := Label.new()
	name.text = BoosterBag.booster_name(kind)
	name.add_theme_font_size_override("font_size", 17)
	name.add_theme_color_override("font_color", GOLD)
	details.add_child(name)
	var owned := Label.new()
	owned.text = "موجودی: %s از %s" % [_fa(_bag.count(kind)), _fa(BoosterBag.MAX_OWNED)]
	owned.add_theme_font_size_override("font_size", 12)
	details.add_child(owned)
	var price := Label.new()
	price.text = "هر عدد: %s سکه" % _fa(BoosterBag.price(kind))
	price.add_theme_font_size_override("font_size", 12)
	price.add_theme_color_override("font_color", Color(0.83, 0.84, 0.72))
	details.add_child(price)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	row.add_child(actions)
	var one := Button.new()
	one.text = "خرید ۱"
	one.custom_minimum_size = Vector2(82, 35)
	one.disabled = _bag.count(kind) >= BoosterBag.MAX_OWNED or _wallet.coins < BoosterBag.price(kind)
	one.pressed.connect(_buy.bind(kind, 1))
	_style_button(one, Color(0.12, 0.31, 0.23), Color(0.72, 0.82, 0.51), 10)
	actions.add_child(one)
	var three := Button.new()
	three.text = "خرید %s" % _fa(quantity)
	three.custom_minimum_size = Vector2(82, 35)
	var quantity := mini(3, BoosterBag.MAX_OWNED - _bag.count(kind))
	three.disabled = quantity <= 0 or _wallet.coins < BoosterBag.price(kind) * quantity
	three.pressed.connect(_buy.bind(kind, 3))
	_style_button(three, Color(0.38, 0.25, 0.09), GOLD, 10)
	actions.add_child(three)

func _buy(kind: int, quantity: int) -> void:
	if _bag.buy(kind, _wallet, quantity):
		_store.save(_save)
		_status.text = "خریدِ %s با موفقیت انجام شد" % BoosterBag.booster_name(kind)
		_rebuild()
	else:
		_status.text = "سکهٔ کافی نداری یا ظرفیت کیف پُر شده است"

func _panel_style(bg: Color, border: Color, radius: int = 16, inset: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

func _style_button(button: Button, bg: Color, accent: Color, radius: int = 12) -> void:
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(bg, accent, radius, 5))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.12), GOLD, radius, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.12), accent.lightened(0.1), radius, 5))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.07, 0.09, 0.08, 0.85), Color(0.28, 0.31, 0.25, 0.55), radius, 5))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _fa(value: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var raw := str(maxi(0, value))
	var result := ""
	for i in range(raw.length()):
		result += digits.substr(int(raw.substr(i, 1)), 1)
	return result
