extends Control

var _save: SaveData
var _store: SaveStore
var _wallet: Wallet
var _progression: Progression
var _districts: Array[Dictionary] = []
var _content: VBoxContainer
var _status: Label

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_apply_theme()
	_load_data()
	_build_ui()

func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 19
	theme = ui_theme

func _load_data() -> void:
	var directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, directory)
	_save = _store.load_save().data
	_wallet = Wallet.new(_save)
	_progression = Progression.new(_save, GameClock.new())
	var result := DistrictContentLoader.load_chapter("ch01")
	_districts = result.districts

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = AssetCatalog.texture("res://assets/art/map_backdrop.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var back := Button.new()
	back.text = "بازگشت"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "ساخت قلمرو"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_content)
	_rebuild_districts()

func _rebuild_districts() -> void:
	for child in _content.get_children():
		child.queue_free()
	_status.text = "معجون‌های تو: %d" % _wallet.potions
	for district in _districts:
		var card := PanelContainer.new()
		_content.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		card.add_child(body)
		var title := Label.new()
		title.text = str(district.get("title", ""))
		title.add_theme_font_size_override("font_size", 25)
		body.add_child(title)
		var tasks: Array[Dictionary] = district.get("tasks", [])
		for task in tasks:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			body.add_child(row)
			var art := TextureRect.new()
			var art_path := "res://assets/art/prop_%s.png" % str(task.get("build_asset", ""))
			art.texture = AssetCatalog.texture(art_path)
			art.custom_minimum_size = Vector2(72, 72)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(art)
			var task_title := Label.new()
			task_title.text = str(task.get("title", ""))
			task_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(task_title)
			var key := str(task.get("key", ""))
			if _progression.is_task_complete(key):
				var done := Label.new()
				done.text = "ساخته شد ✓"
				row.add_child(done)
			else:
				var cost := int(task.get("potion_cost", 0))
				var build := Button.new()
				build.text = "ساخت · %d" % cost
				build.disabled = _wallet.potions < cost
				build.pressed.connect(_complete_task.bind(key, cost))
				row.add_child(build)
			var separator := HSeparator.new()
			body.add_child(separator)
		var chest: RewardBundle = district.get("chest")
		var chest_button := Button.new()
		var district_id := str(district.get("id", ""))
		if _progression.is_chest_claimed(district_id):
			chest_button.text = "گنج دریافت شد"
			chest_button.disabled = true
		else:
			chest_button.text = "دریافت گنج · %d سکه + %d معجون" % [chest.coins, chest.potions]
			chest_button.disabled = not _progression.is_district_complete(tasks)
			chest_button.pressed.connect(_claim_chest.bind(district_id, chest, tasks))
		body.add_child(chest_button)

func _complete_task(key: String, cost: int) -> void:
	if _progression.try_complete_task(key, cost, _wallet):
		_store.save(_save)
		_rebuild_districts()

func _claim_chest(district_id: String, chest: RewardBundle, tasks: Array[Dictionary]) -> void:
	if _progression.try_claim_chest(district_id, chest, tasks, _wallet):
		_store.save(_save)
		_rebuild_districts()
