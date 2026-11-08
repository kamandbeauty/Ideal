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
var _score_label: Label
var _goal_label: Label
var _status_label: Label
var _initial_status_message := ""
var _booster_buttons: Array[Button] = []
var _cell_buttons: Dictionary = {}
var _fx_layer: Control
var _board_panel: PanelContainer
var _animate_next_refresh := false
var _end_overlay: Control
var _input_locked := false
var _is_paused := false
var _pause_overlay: Control
var _pause_button: Button

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
	back_button.text = "خانه"
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back_button)
	_pause_button = Button.new()
	_pause_button.text = "Ⅱ مکث"
	_pause_button.pressed.connect(_show_pause_overlay)
	header.add_child(_pause_button)
	var title := Label.new()
	title.text = "باغ شازده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66))
	header.add_child(title)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 21)
	layout.add_child(_score_label)

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
	_score_label.text = "امتیاز: %s" % _format_persian_number(_run.score)
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
					if _animate_next_refresh:
						piece_view.scale = Vector2(0.72, 0.72)
						piece_view.modulate = Color(1, 1, 1, 0.35)
						piece_view.offset_top = -CELL_SIZE * 1.15
						piece_view.offset_bottom = -CELL_SIZE * 1.15
					button.add_child(piece_view)
					if _animate_next_refresh:
						var stagger := float((x * 3 + (_run.board.height - 1 - y)) % 7) * 0.018
						var appear := create_tween()
						appear.set_parallel(true)
						appear.tween_property(piece_view, "scale", Vector2.ONE, 0.25).set_delay(stagger).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						appear.tween_property(piece_view, "modulate", Color.WHITE, 0.2).set_delay(stagger)
						appear.tween_property(piece_view, "offset_top", 5.0, 0.25).set_delay(stagger).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
						appear.tween_property(piece_view, "offset_bottom", -5.0, 0.25).set_delay(stagger).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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

	_animate_next_refresh = false
	_ensure_end_overlay()
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
	if _run == null or _run.status != GameTypes.LevelStatus.PLAYING or _input_locked or _is_paused:
		return
	if _selected_booster >= 0:
		if not _bag.try_consume(_selected_booster):
			_selected_booster = -1
			_refresh_board()
			return
		var booster_result := _run.use_booster(_selected_booster, pos.x, pos.y)
		if booster_result.accepted:
			_play_result_fx(booster_result)
			_animate_next_refresh = true
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
	var from_pos := _selected
	var from_texture := _cell_texture_at(from_pos)
	var to_texture := _cell_texture_at(pos)
	var result := _run.try_swap(from_pos.x, from_pos.y, pos.x, pos.y)
	_selected = Vector2i(-1, -1)
	if result.accepted:
		_play_result_fx(result)
		_animate_next_refresh = true
		if _run.status != GameTypes.LevelStatus.PLAYING:
			var progression := Progression.new(_save, GameClock.new())
			progression.record_level_result(_run, _wallet)
			_store.save(_save)
		_input_locked = true
		_animate_swap_and_refresh(from_pos, pos, from_texture, to_texture)
		return
	_play_reject_fx(pos)
	_refresh_board()

func _on_booster_pressed(kind: int) -> void:
	if _run == null or _run.status != GameTypes.LevelStatus.PLAYING or _is_paused or _input_locked:
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
				var origin := Vector2i(event.position.x, event.position.y)
				_spawn_cell_fx(origin, "res://assets/art/fx_spark.png", Color(0.7, 0.95, 1.0), 0.82)
				_play_powerup_sweep(origin, int(event.get("kind", 0)))
			"cascade":
				cascades += 1
	if cleared > 0 or obstacle_hits > 0 or created_powerups > 0:
		_show_clear_summary(cleared, obstacle_hits, created_powerups, cascades)
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


func _play_powerup_sweep(origin: Vector2i, kind: int) -> void:
	if _fx_layer == null or _grid == null:
		return
	var origin_button: Button = _cell_buttons.get(origin)
	if origin_button == null:
		return
	var center: Vector2 = _fx_layer.to_local(origin_button.get_global_rect().get_center())
	var board_rect: Rect2 = _grid.get_global_rect()
	var local_rect: Rect2 = Rect2(_fx_layer.to_local(board_rect.position), board_rect.size)
	var line := Line2D.new()
	line.width = 7.0
	line.default_color = Color(0.55, 0.94, 1.0, 0.0)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(center)
	if kind == GameTypes.PowerUpKind.ROCKET_HORIZONTAL:
		line.add_point(Vector2(local_rect.position.x, center.y))
		line.add_point(Vector2(local_rect.end.x, center.y))
	elif kind == GameTypes.PowerUpKind.ROCKET_VERTICAL:
		line.add_point(Vector2(center.x, local_rect.end.y))
		line.add_point(Vector2(center.x, local_rect.position.y))
	elif kind in [GameTypes.PowerUpKind.SPINNER, GameTypes.PowerUpKind.DYNAMITE, GameTypes.PowerUpKind.ELECTRO_BALL, GameTypes.PowerUpKind.SUPER_ELECTRO_BALL]:
		var radius := CELL_SIZE * (2.8 if kind == GameTypes.PowerUpKind.SUPER_ELECTRO_BALL else 1.9)
		for index in range(9):
			var angle := TAU * float(index) / 8.0
			line.add_point(center + Vector2(cos(angle), sin(angle)) * radius)
	else:
		return
	_fx_layer.add_child(line)
	var sweep := create_tween()
	sweep.tween_property(line, "default_color:a", 0.95, 0.07)
	sweep.tween_property(line, "width", 1.0, 0.24)
	sweep.parallel().tween_property(line, "default_color:a", 0.0, 0.27)
	sweep.tween_callback(line.queue_free)

func _ensure_end_overlay() -> void:
	if _run == null or _run.status == GameTypes.LevelStatus.PLAYING:
		if is_instance_valid(_end_overlay):
			_end_overlay.queue_free()
		_end_overlay = null
		return
	if is_instance_valid(_end_overlay):
		return
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_end_overlay = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270, 210)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.09, 0.13, 0.98)
	panel_style.border_color = Color(0.85, 0.69, 0.37, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(22)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var won := _run.status == GameTypes.LevelStatus.WON
	var heading := Label.new()
	heading.text = "آفرین! باغ شکوفا شد" if won else "این بار نشد!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color(1.0, 0.84, 0.43) if won else Color(1.0, 0.58, 0.45))
	column.add_child(heading)
	var detail := Label.new()
	var best_record := _save.find_level(_level.number) if _save != null and _level != null else {}
	var best_score := int(best_record.get("best_score", 0))
	detail.text = ("امتیاز: %s\nبهترین رکورد: %s" % [_format_persian_number(_run.score), _format_persian_number(maxi(best_score, _run.score))]) if won else ("امتیاز: %s\nحرکت‌ها تمام شد؛ دوباره امتحان کن" % _format_persian_number(_run.score))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 16)
	column.add_child(detail)
	if won:
		var stars := Label.new()
		var rating := StarRating.from_run(_run)
		stars.text = "★  ★  ★" if rating >= 3 else ("★  ★" if rating == 2 else "★")
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars.add_theme_font_size_override("font_size", 30)
		stars.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
		stars.scale = Vector2(0.55, 0.55)
		column.add_child(stars)
		var star_intro := create_tween()
		star_intro.tween_property(stars, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var action := Button.new()
	action.text = "ادامه" if won else "تلاش دوباره"
	action.custom_minimum_size = Vector2(0, 46)
	if won:
		action.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	else:
		action.pressed.connect(func() -> void: get_tree().reload_current_scene())
	column.add_child(action)
	var home := Button.new()
	home.text = "بازگشت به باغ"
	home.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	column.add_child(home)
	panel.scale = Vector2(0.82, 0.82)
	panel.modulate = Color(1, 1, 1, 0)
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(panel, "modulate", Color.WHITE, 0.2)


func _cell_texture_at(pos: Vector2i) -> Texture2D:
	if _run == null:
		return null
	var cell = _run.board.at_pos(pos)
	if cell == null:
		return null
	if cell.power_up != GameTypes.PowerUpKind.NONE:
		return AssetCatalog.power_up_texture(cell.power_up)
	if cell.has_piece:
		return AssetCatalog.piece_texture(cell.piece)
	return null

func _animate_swap_and_refresh(from_pos: Vector2i, to_pos: Vector2i, from_texture: Texture2D, to_texture: Texture2D) -> void:
	var from_button: Button = _cell_buttons.get(from_pos)
	var to_button: Button = _cell_buttons.get(to_pos)
	if from_button == null or to_button == null or from_texture == null or to_texture == null:
		_input_locked = false
		_refresh_board()
		return
	var from_center: Vector2 = _fx_layer.to_local(from_button.get_global_rect().get_center())
	var to_center: Vector2 = _fx_layer.to_local(to_button.get_global_rect().get_center())
	var sprite_size := Vector2(CELL_SIZE * 0.82, CELL_SIZE * 0.82)
	var sprite_a := _make_swap_sprite(from_texture, from_center, sprite_size)
	var sprite_b := _make_swap_sprite(to_texture, to_center, sprite_size)
	_fx_layer.add_child(sprite_a)
	_fx_layer.add_child(sprite_b)
	from_button.modulate.a = 0.0
	to_button.modulate.a = 0.0
	var motion := create_tween()
	motion.set_parallel(true)
	motion.tween_property(sprite_a, "position", to_center - sprite_size / 2.0, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(sprite_b, "position", from_center - sprite_size / 2.0, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	sprite_a.queue_free()
	sprite_b.queue_free()
	_input_locked = false
	_refresh_board()

func _make_swap_sprite(texture: Texture2D, center: Vector2, sprite_size: Vector2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = sprite_size
	sprite.position = center - sprite_size / 2.0
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


func _show_clear_summary(cleared: int, obstacle_hits: int, powerups: int, cascades: int) -> void:
	if _fx_layer == null:
		return
	var parts: PackedStringArray = []
	if cleared > 0:
		parts.append("%d مهره" % cleared)
	if obstacle_hits > 0:
		parts.append("%d ضربه به مانع" % obstacle_hits)
	if powerups > 0:
		parts.append("%d قدرت تازه" % powerups)
	var headline := "  •  ".join(parts)
	if cascades > 0:
		headline += "   |   زنجیره ×%d" % cascades
	var popup := Label.new()
	popup.text = headline
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 18 if cascades == 0 else 21)
	popup.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	popup.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.06, 0.9))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 3)
	popup.size = Vector2(minf(_fx_layer.size.x - 28.0, 440.0), 54)
	popup.position = Vector2((_fx_layer.size.x - popup.size.x) / 2.0, 110)
	popup.modulate = Color(1, 1, 1, 0)
	popup.scale = Vector2(0.82, 0.82)
	_fx_layer.add_child(popup)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "modulate:a", 1.0, 0.12)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position:y", 76.0, 0.75).set_delay(0.12)
	tween.tween_property(popup, "modulate:a", 0.0, 0.22).set_delay(0.65)
	tween.chain().tween_callback(popup.queue_free)

func _show_pause_overlay() -> void:
	if _run == null or _run.status != GameTypes.LevelStatus.PLAYING or _is_paused:
		return
	_is_paused = true
	_pause_button.disabled = true
	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.022, 0.04, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_pause_overlay = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 250)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.09, 0.13, 0.99)
	style.border_color = Color(0.82, 0.68, 0.39, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := Label.new()
	title.text = "بازی متوقف شد"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(1, 0.86, 0.55))
	column.add_child(title)
	var resume := Button.new()
	resume.text = "ادامه بازی"
	resume.custom_minimum_size.y = 46
	resume.pressed.connect(_close_pause_overlay)
	column.add_child(resume)
	var restart := Button.new()
	restart.text = "شروع دوباره مرحله"
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	column.add_child(restart)
	var home := Button.new()
	home.text = "بازگشت به باغ"
	home.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	column.add_child(home)
	panel.scale = Vector2(0.84, 0.84)
	panel.modulate = Color(1, 1, 1, 0)
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(panel, "modulate", Color.WHITE, 0.18)

func _close_pause_overlay() -> void:
	if not is_instance_valid(_pause_overlay):
		_is_paused = false
		_pause_button.disabled = false
		return
	_pause_overlay.queue_free()
	_pause_overlay = null
	_is_paused = false
	_pause_button.disabled = false


func _format_persian_number(value: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var raw := str(maxi(0, value))
	var formatted := ""
	for index in range(raw.length()):
		var digit := int(raw.substr(index, 1))
		formatted += digits.substr(digit, 1)
	return formatted
