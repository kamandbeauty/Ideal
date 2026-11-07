extends Control

const CELL_SIZE := 58
const CELL_GAP := 4

var _level: LevelDefinition
var _run: LevelRun
var _save: SaveData
var _store: SaveStore
var _wallet: Wallet
var _bag: BoosterBag
var _lives: Lives
var _selected := Vector2i(-1, -1)
var _selected_booster := -1
var _grid: GridContainer
var _moves_label: Label
var _goal_label: Label
var _status_label: Label
var _booster_buttons: Array[Button] = []
var _cell_buttons: Dictionary = {}

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_apply_theme()
	_load_game_state()
	_build_ui()
	_refresh_board()

func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/Vazir-Medium.ttf") as Font
	ui_theme.default_font_size = 20
	theme = ui_theme

func _load_game_state() -> void:
	var save_directory := str(get_meta("save_directory", ""))
	_store = SaveStore.new(null, save_directory)
	var loaded := _store.load_save()
	_save = loaded.data
	if not FileAccess.file_exists(_store.location):
		_store.save(_save)
	_wallet = Wallet.new(_save)
	_bag = BoosterBag.new(_save)
	_lives = Lives.new(_save, GameClock.new())

	var content := LevelContentLoader.load_level(1, "ch01")
	if content.level == null or not content.errors.is_empty():
		_status_label = Label.new()
		_status_label.text = "بارگذاری مرحله ناموفق بود"
		return
	_level = content.level
	if not _lives.try_spend():
		_status_label = Label.new()
		_status_label.text = "جان کافی برای شروع مرحله ندارید"
		return
	_run = LevelRun.new(_level, 0, int(Time.get_unix_time_from_system()))
	_store.save(_save)

func _build_ui() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = AssetCatalog.texture("res://assets/art/board_backdrop_ch01.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.047, 0.08, 0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "قصرِ شاهزاده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	layout.add_child(title)

	_moves_label = Label.new()
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_font_size_override("font_size", 24)
	layout.add_child(_moves_label)

	_goal_label = Label.new()
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_goal_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(_status_label)

	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(board_center)

	_grid = GridContainer.new()
	_grid.columns = _level.width if _level != null else 9
	_grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	board_center.add_child(_grid)

	var booster_row := HBoxContainer.new()
	booster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	booster_row.add_theme_constant_override("separation", 8)
	layout.add_child(booster_row)
	for kind in range(BoosterBag.SLOTS):
		var booster_button := Button.new()
		booster_button.custom_minimum_size = Vector2(112, 76)
		booster_button.pressed.connect(_on_booster_pressed.bind(kind))
		booster_row.add_child(booster_button)
		_booster_buttons.append(booster_button)

func _refresh_board() -> void:
	if _run == null:
		if _status_label != null and _status_label.text.is_empty():
			_status_label.text = "مرحله آماده نشد"
		return
	_moves_label.text = "حرکت‌های باقی‌مانده: %d" % _run.moves_left
	_goal_label.text = _build_goal_text()
	if _run.status == GameTypes.LevelStatus.WON:
		_status_label.text = "آفرین! مرحله را با %d ستاره تمام کردی" % StarRating.from_run(_run)
	elif _run.status == GameTypes.LevelStatus.LOST:
		_status_label.text = "حرکت‌ها تمام شد؛ دوباره تلاش کن"
	elif _selected_booster >= 0:
		_status_label.text = "برای استفاده از %s یک خانه را انتخاب کن" % BoosterBag.booster_name(_selected_booster)
	else:
		_status_label.text = "دو خانهٔ کنار هم را جابه‌جا کن تا سه مهره جور شوند"

	for child in _grid.get_children():
		child.queue_free()
	_cell_buttons.clear()
	for y in range(_run.board.height - 1, -1, -1):
		for x in range(_run.board.width):
			var pos := Vector2i(x, y)
			var button := Button.new()
			button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			button.flat = true
			button.text = ""
			button.pressed.connect(_on_cell_pressed.bind(pos))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.13, 0.16, 0.23, 0.92)
			style.corner_radius_top_left = 9
			style.corner_radius_top_right = 9
			style.corner_radius_bottom_left = 9
			style.corner_radius_bottom_right = 9
			button.add_theme_stylebox_override("normal", style)
			var cell = _run.board.at_pos(pos)
			if cell != null:
				var texture: Texture2D = null
				if cell.power_up != GameTypes.PowerUpKind.NONE:
					texture = AssetCatalog.power_up_texture(cell.power_up)
				elif cell.has_piece:
					texture = AssetCatalog.piece_texture(cell.piece)
				if texture != null:
					var piece_view := TextureRect.new()
					piece_view.texture = texture
					piece_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					piece_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					piece_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					piece_view.offset_left = 5
					piece_view.offset_top = 5
					piece_view.offset_right = -5
					piece_view.offset_bottom = -5
					piece_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
					button.add_child(piece_view)
				if cell.has_obstacle:
					var obstacle_texture := AssetCatalog.obstacle_texture(cell.obstacle)
					if obstacle_texture != null:
						var obstacle_view := TextureRect.new()
						obstacle_view.texture = obstacle_texture
						obstacle_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
						obstacle_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						obstacle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
						obstacle_view.offset_left = 9
						obstacle_view.offset_top = 9
						obstacle_view.offset_right = -9
						obstacle_view.offset_bottom = -9
						obstacle_view.modulate = Color(1, 1, 1, 0.9)
						obstacle_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
						button.add_child(obstacle_view)
			if pos == _selected:
				button.modulate = Color(1.2, 1.2, 0.65, 1)
			_grid.add_child(button)
			_cell_buttons[pos] = button

	for kind in range(_booster_buttons.size()):
		var booster_button: Button = _booster_buttons[kind]
		booster_button.text = "%s  ×%d" % [BoosterBag.booster_name(kind), _bag.count(kind)]
		booster_button.disabled = _bag.count(kind) <= 0 or _run.status != GameTypes.LevelStatus.PLAYING
		booster_button.modulate = Color(1.2, 1.2, 0.65, 1) if kind == _selected_booster else Color.WHITE

func _build_goal_text() -> String:
	var parts: PackedStringArray = []
	for index in range(_run.goals.count()):
		var goal := _run.goals.goal(index)
		var remaining := maxi(0, _run.goals.target(index) - _run.goals.progress(index))
		if int(goal.get("kind", 0)) == GameTypes.GoalKind.CLEAR_PIECES:
			parts.append("%s: %d" % [_piece_name_fa(int(goal.get("piece", 0))), remaining])
		else:
			parts.append("مانع: %d" % remaining)
	return "هدف: " + "   |   ".join(parts)

func _piece_name_fa(kind: int) -> String:
	match kind:
		GameTypes.PieceKind.FIROUZEH: return "فیروزه"
		GameTypes.PieceKind.LAJVARD: return "لاجورد"
		GameTypes.PieceKind.AQIQ: return "عقیق"
		GameTypes.PieceKind.ZOMORROD: return "زمرد"
		GameTypes.PieceKind.MORVARID: return "مروارید"
		_: return "مهره"

func _on_cell_pressed(pos: Vector2i) -> void:
	if _run == null or _run.status != GameTypes.LevelStatus.PLAYING:
		return
	if _selected_booster >= 0:
		if not _bag.try_consume(_selected_booster):
			_selected_booster = -1
			_refresh_board()
			return
		var booster_result := _run.use_booster(_selected_booster, pos.x, pos.y)
		if not booster_result.accepted:
			_bag.grant(_selected_booster)
		_selected_booster = -1
		_store.save(_save)
		_refresh_board()
		return
	if _selected.x < 0:
		_selected = pos
		_refresh_board()
		return
	if _selected == pos:
		_selected = Vector2i(-1, -1)
		_refresh_board()
		return
	var result := _run.try_swap(_selected.x, _selected.y, pos.x, pos.y)
	_selected = Vector2i(-1, -1)
	if result.accepted:
		if _run.status == GameTypes.LevelStatus.WON:
			var progression := Progression.new(_save, GameClock.new())
			progression.record_level_result(_run, _wallet)
			_store.save(_save)
	_refresh_board()

func _on_booster_pressed(kind: int) -> void:
	if _run == null or _run.status != GameTypes.LevelStatus.PLAYING:
		return
	if _selected_booster == kind:
		_selected_booster = -1
	else:
		_selected_booster = kind
	_selected = Vector2i(-1, -1)
	_refresh_board()

func debug_cell_count() -> int:
	return _cell_buttons.size()

func debug_run_status() -> int:
	return _run.status if _run != null else -1
