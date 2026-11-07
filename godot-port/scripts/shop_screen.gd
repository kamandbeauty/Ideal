extends Control

var _save: SaveData
var _store: SaveStore
var _wallet: Wallet
var _bag: BoosterBag
var _status: Label
var _rows: VBoxContainer

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_apply_theme()
	_load_data()
	_build_ui()

func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 20
	theme = ui_theme

func _load_data() -> void:
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	_wallet = Wallet.new(_save)
	_bag = BoosterBag.new(_save)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "بازگشت"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "فروشگاه"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)
	_status = Label.new()
	layout.add_child(_status)
	_rows = VBoxContainer.new()
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_rows)
	_rebuild()

func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_status.text = "موجودی سکه: %d" % _wallet.coins
	for kind in range(BoosterBag.SLOTS):
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var label := Label.new()
		label.text = "%s · موجودی %d" % [BoosterBag.booster_name(kind), _bag.count(kind)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var buy := Button.new()
		buy.text = "خرید · %d سکه" % BoosterBag.price(kind)
		buy.disabled = _wallet.coins < BoosterBag.price(kind) or _bag.count(kind) >= BoosterBag.MAX_OWNED
		buy.pressed.connect(_buy.bind(kind))
		row.add_child(buy)

func _buy(kind: int) -> void:
	if _bag.buy(kind, _wallet, 1):
		_store.save(_save)
		_rebuild()
	else:
		_status.text = "سکه کافی یا ظرفیت خالی نداری"
