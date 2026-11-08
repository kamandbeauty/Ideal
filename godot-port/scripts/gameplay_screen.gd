extends Control

var CELL_SIZE := 58
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
var _initial_status_message := ""
var _booster_buttons: Array[Button] = []
var _cell_buttons: Dictionary = {}
var _fx_layer: Control
var _board_panel: PanelContainer

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

	if _save.level_number > 10:
		_initial_status_message = "فصلِ اوّل را کامل کرده‌ای؛ به‌زودی فصل بعدی می‌آید"
		return
	var content := LevelContentLoader.load_level(_save.level_number, "ch01")
	if content.level == null or not content.errors.is_empty():
		_initial_status_message = "بارگذاری مرحله ناموفق بود"
		return
	_level = content.level
	if not _lives.try_spend():
		_initial_status_message = "جان کافی برای شروع مرحله ندارید"
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
	shade.color = Color(0.025, 0.04, 0.075, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var back_button := Button.new()
	back_button.text = "بازگشت"
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back_button)
	var title := Label.new()
	title.text = "باغ شازده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66))
	header.add_child(title)

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
	var board_panel := PanelContainer.new()
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.025, 0.045, 0.075, 0.94)
	board_style.border_color = Color(0.78, 0.62, 0.32, 0.9)
	board_style.set_border_width_all(3)
	board_style.set_corner_radius_all(20)
	board_style.content_margin_left = 9
	board_style.content_margin_right = 9
	board_style.content_margin_top = 9
	board_style.content_margin_bottom = 9
	board_panel.add_theme_stylebox_override("panel", board_style)
	_board_panel = board_panel
	board_center.add_child(board_panel)

	_grid = GridContainer.new()
	_grid.columns = _level.width if _level != null else 9
	_grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	board_panel.add_child(_grid)
	var columns := _level.width if _level != null else 9
	CELL_SIZE = clampi(int((get_viewport_rect().size.x - 70.0 - float(columns - 1) * CELL_GAP) / float(columns)), 42, 66)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	var booster_row := HBoxContainer.new()
	booster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	booster_row.add_theme_constant_override("separation", 8)
	layout.add_child(booster_row)
	for kind in range(BoosterBag.SLOTS):
		var booster_button := Button.new()
		booster_button.custom_minimum_size = Vector2(0, 82)
		booster_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		booster_button.icon = AssetCatalog.booster_texture(kind)
		booster_button.expand_icon = true
		booster_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		booster_button.icon_max_width = 42
		booster_button.add_theme_font_size_override("font_size", 12)
		booster_button.pressed.connect(_on_booster_pressed.bind(kind))
		booster_row.add_child(booster_button)
		_booster_buttons.append(booster_button)

func _refresh_board() -> void:
	if _run == null:
		if _status_label != null:
			_status_label.text = _initial_status_message if not _initial_status_message.is_empty() else "مرحله آماده نشد"
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
			style.bg_color = Color(0.09, 0.16, 0.21, 0.98)
			style.border_color = Color(0.48, 0.66, 0.65, 0.4)
			style.set_border_width_all(1)
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
		booster_button.text = "%s\n×%d" % [BoosterBag.booster_name(kind), _bag.count(kind)]
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
		if booster_result.accepted:
			_play_result_fx(booster_result)
		if not booster_result.accepted or not _booster_had_effect(booster_result):
			_bag.grant(_selected_booster)
			if booster_result.accepted:
				_run.revert_last_booster(_selected_booster)
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
		_play_result_fx(result)
	else:
		_play_reject_fx(pos)
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

func _booster_had_effect(result: Dictionary) -> bool:
	for event in result.events:
		var event_type := str(event.get("type", ""))
		if event_type in ["piece_cleared", "obstacle_hit", "power_up_triggered", "board_reshuffled"]:
			return true
	return false

func debug_level_number() -> int:
	return _level.number if _level != null else 0

func _play_result_fx(result: Dictionary) -> void:
	if _fx_layer == null:
		return
	var cleared := 0
	var obstacle_hits := 0
	var created_powerups := 0
	var cascades := 0
	for event in result.get("events", []):
		var event_type := str(event.get("type", ""))
		match event_type:
			"piece_cleared":
				cleared += 1
				if cleared <= 24:
					_spawn_cell_fx(Vector2i(event.position.x, event.position.y), "res://assets/art/fx_spark.png", Color(1.0, 0.88, 0.48), 0.42)
			"obstacle_hit":
				obstacle_hits += 1
				_spawn_cell_fx(Vector2i(event.position.x, event.position.y), "res://assets/art/fx_ring.png", Color(1.0, 0.65, 0.35), 0.58)
			"power_up_created":
				created_powerups += 1
				_spawn_cell_fx(Vector2i(event.position.x, event.position.y), "res://assets/art/fx_ring.png", Color(0.55, 0.95, 1.0), 0.78)
			"power_up_triggered":
				_spawn_cell_fx(Vector2i(event.position.x, event.position.y), "res://assets/art/fx_spark.png", Color(0.7, 0.95, 1.0), 0.72)
			"cascade":
				cascades += 1
	if cascades > 0 or cleared >= 5 or created_powerups > 0:
		_spawn_board_pulse(Color(0.85, 0.72, 0.36) if cascades > 0 else Color(0.45, 0.9, 0.88))
	if cleared >= 8 or cascades >= 2:
		_shake_board(5.0 if cascades >= 2 else 2.5)
	if obstacle_hits > 0 and cleared == 0:
		_spawn_board_pulse(Color(1.0, 0.48, 0.32))

func _spawn_cell_fx(pos: Vector2i, texture_path: String, tint: Color, intensity: float) -> void:
	var button: Button = _cell_buttons.get(pos)
	if button == null:
		return
	var texture := AssetCatalog.texture(texture_path)
	if texture == null:
		return
	var fx := TextureRect.new()
	fx.texture = texture
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx_size := Vector2(CELL_SIZE * 1.65, CELL_SIZE * 1.65)
	fx.size = fx_size
	fx.pivot_offset = fx_size / 2.0
	var center := button.get_global_rect().get_center()
	fx.position = _fx_layer.to_local(center) - fx_size / 2.0
	fx.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	fx.scale = Vector2(0.35, 0.35)
	_fx_layer.add_child(fx)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "modulate:a", intensity, 0.08)
	tween.tween_property(fx, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(fx, "modulate:a", 0.0, 0.22)
	tween.tween_callback(fx.queue_free).set_delay(0.32)

func _spawn_board_pulse(tint: Color) -> void:
	if _board_panel == null:
		return
	var original := _board_panel.modulate
	var tween := create_tween()
	tween.tween_property(_board_panel, "modulate", tint, 0.07)
	tween.tween_property(_board_panel, "modulate", original, 0.24)

func _shake_board(amount: float) -> void:
	if _board_panel == null:
		return
	var origin := _board_panel.position
	var tween := create_tween()
	for index in range(4):
		var direction := -1.0 if index % 2 == 0 else 1.0
		tween.tween_property(_board_panel, "position:x", origin.x + amount * direction, 0.035)
	tween.tween_property(_board_panel, "position", origin, 0.045)

func _play_reject_fx(pos: Vector2i) -> void:
	_spawn_cell_fx(pos, "res://assets/art/fx_ring.png", Color(1.0, 0.35, 0.28), 0.55)
	_shake_board(2.0)
