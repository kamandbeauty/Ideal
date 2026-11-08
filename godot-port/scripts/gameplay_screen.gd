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

func _play_sfx(sound_name: String, pitch: float = 1.0, volume_db: float = -3.0) -> void:
	if _save != null and not _save.sfx_on:
		return
	var sound_path := "res://assets/audio/%s.wav" % sound_name
	if not ResourceLoader.exists(sound_path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(sound_path) as AudioStream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _trigger_haptic(duration_ms: int, amplitude: float) -> void:
	if _save == null or not _save.haptics_on or not OS.has_feature("android"):
		return
	Input.vibrate_handheld(duration_ms, clampf(amplitude, 0.0, 1.0))

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

func _panel_style(background: Color, border: Color, radius: int = 16, inset: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

func _style_button(button: Button, background: Color, accent: Color, radius: int = 14) -> void:
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(background, accent, radius, 8))
	button.add_theme_stylebox_override("hover", _panel_style(background.lightened(0.12), Color(1.0, 0.84, 0.48), radius, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(background.darkened(0.12), accent.lightened(0.1), radius, 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _make_hud_card(caption: String, value: Label) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.10, 0.11, 0.95), Color(0.78, 0.64, 0.36, 0.9), 16, 8))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var heading := Label.new()
	heading.text = caption
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.79, 0.86, 0.75))
	column.add_child(heading)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(value)
	return card

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

	var selected_level := _save.level_number
	if get_tree().root.has_meta("selected_level_number"):
		selected_level = int(get_tree().root.get_meta("selected_level_number"))
		get_tree().root.remove_meta("selected_level_number")
	if selected_level < 1 or selected_level > _save.level_number:
		selected_level = _save.level_number
	if selected_level > 10:
		_initial_status_message = "فصلِ اوّل را کامل کرده‌ای؛ به‌زودی فصل بعدی می‌آید"
		return
	var content := LevelContentLoader.load_level(selected_level, "ch01")
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
	back_button.text = "⌂ خانه"
	back_button.custom_minimum_size = Vector2(92, 48)
	_style_button(back_button, Color(0.035, 0.14, 0.15, 0.96), Color(0.72, 0.61, 0.39, 0.9), 13)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/home_screen.tscn"))
	header.add_child(back_button)
	_pause_button = Button.new()
	_pause_button.text = "Ⅱ مکث"
	_pause_button.custom_minimum_size = Vector2(92, 48)
	_style_button(_pause_button, Color(0.035, 0.14, 0.15, 0.96), Color(0.72, 0.61, 0.39, 0.9), 13)
	_pause_button.pressed.connect(_show_pause_overlay)
	header.add_child(_pause_button)
	var title := Label.new()
	title.text = "باغ شازده"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	header.add_child(title)

	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 10)
	layout.add_child(hud_row)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 22)
	hud_row.add_child(_make_hud_card("امتیاز", _score_label))

	_moves_label = Label.new()
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_font_size_override("font_size", 22)
	hud_row.add_child(_make_hud_card("حرکت باقی‌مانده", _moves_label))

	var goal_panel := PanelContainer.new()
	goal_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.10, 0.11, 0.94), Color(0.73, 0.61, 0.36, 0.88), 16, 10))
	layout.add_child(goal_panel)
	_goal_label = Label.new()
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 18)
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(_goal_label)

	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.07, 0.08, 0.82), Color(0.35, 0.58, 0.51, 0.55), 14, 8))
	layout.add_child(status_panel)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(_status_label)

	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(board_center)
	var board_panel := PanelContainer.new()
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.018, 0.055, 0.075, 0.97)
	board_style.border_color = Color(0.91, 0.73, 0.39, 0.98)
	board_style.set_border_width_all(3)
	board_style.set_corner_radius_all(24)
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
		booster_button.add_theme_font_size_override("font_size", 13)
		_style_button(booster_button, Color(0.035, 0.15, 0.16, 0.96), Color(0.76, 0.62, 0.35, 0.88), 15)
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
			style.bg_color = Color(0.045, 0.13, 0.17, 0.98)
			style.border_color = Color(0.58, 0.72, 0.66, 0.48)
			style.set_border_width_all(1)
			style.set_corner_radius_all(11)
			button.add_theme_stylebox_override("normal", style)
			var cell_hover := _panel_style(Color(0.12, 0.25, 0.25, 1.0), Color(0.97, 0.79, 0.43, 0.95), 11, 0)
			button.add_theme_stylebox_override("hover", cell_hover)
			button.add_theme_stylebox_override("pressed", _panel_style(Color(0.20, 0.30, 0.23, 1.0), Color(1.0, 0.88, 0.52, 1.0), 11, 0))
			button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
					piece_view.set_meta("board_piece_view", true)
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
			_play_sfx("booster", 0.96 + float(_selected_booster) * 0.07, -2.0)
			_play_result_fx(booster_result)
			_animate_next_refresh = true
		if not booster_result.accepted or not _booster_had_effect(booster_result):
			_bag.grant(_selected_booster)
			if booster_result.accepted:
				_run.revert_last_booster(_selected_booster)
		_selected_booster = -1
		if booster_result.accepted and _run.status != GameTypes.LevelStatus.PLAYING:
			var progression := Progression.new(_save, GameClock.new())
			progression.record_level_result(_run, _wallet)
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
	var before_visuals := _capture_board_visuals()
	var from_pos := _selected
	var from_texture := _cell_texture_at(from_pos)
	var to_texture := _cell_texture_at(pos)
	var result := _run.try_swap(from_pos.x, from_pos.y, pos.x, pos.y)
	_selected = Vector2i(-1, -1)
	if result.accepted:
		_play_sfx("swap", 1.0, -9.0)
		_play_result_fx(result)
		_animate_next_refresh = true
		if _run.status != GameTypes.LevelStatus.PLAYING:
			var progression := Progression.new(_save, GameClock.new())
			progression.record_level_result(_run, _wallet)
			_store.save(_save)
		_input_locked = true
		_animate_swap_and_refresh(from_pos, pos, from_texture, to_texture, before_visuals)
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
	var triggered_powerups := 0
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
				triggered_powerups += 1
				var origin := Vector2i(event.position.x, event.position.y)
				_spawn_cell_fx(origin, "res://assets/art/fx_spark.png", Color(0.7, 0.95, 1.0), 0.82)
				_play_powerup_sweep(origin, int(event.get("kind", 0)))
			"cascade":
				cascades += 1
	if cleared > 0:
		_play_sfx("clear", 0.94 + minf(float(cleared), 12.0) * 0.018, -2.5)
	if obstacle_hits > 0:
		_play_sfx("obstacle", 0.96 + minf(float(obstacle_hits), 5.0) * 0.045, -1.5)
	if created_powerups > 0:
		_play_sfx("powerup_create", 1.0 + minf(float(created_powerups), 3.0) * 0.08, -1.0)
	if triggered_powerups > 0:
		_play_sfx("powerup", 0.92 + minf(float(triggered_powerups), 4.0) * 0.06, -0.5)
	if cascades > 0:
		_play_sfx("cascade", 0.92 + minf(float(cascades), 4.0) * 0.12, -1.0)
	var combo_count := int(result.get("combo_count", cascades + triggered_powerups))
	var combo_bonus := int(result.get("combo_bonus", 0))
	if combo_count >= 2:
		_play_sfx("combo", 0.92 + minf(float(combo_count - 2), 5.0) * 0.08, -0.5)
		_trigger_haptic(110, 0.85)
	elif cleared > 0 or obstacle_hits > 0:
		_trigger_haptic(45, 0.45)
	if cleared > 0 or obstacle_hits > 0 or created_powerups > 0:
		_show_clear_summary(cleared, obstacle_hits, created_powerups, cascades, combo_count, combo_bonus)
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
	_play_sfx("reject", 1.0, -4.0)
	_trigger_haptic(28, 0.28)
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
	_play_sfx("win" if won else "lose", 1.0, -1.0)
	_trigger_haptic(150 if won else 80, 0.75)
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

func _capture_board_visuals() -> Array[Dictionary]:
	var visuals: Array[Dictionary] = []
	if _run == null:
		return visuals
	for pos in _run.board.all_positions():
		var cell = _run.board.at_pos(pos)
		if cell == null or not cell.has_piece:
			continue
		var texture: Texture2D = AssetCatalog.power_up_texture(cell.power_up) if cell.power_up != GameTypes.PowerUpKind.NONE else AssetCatalog.piece_texture(cell.piece)
		if texture == null:
			continue
		var key := "%d:%d" % [cell.piece, cell.power_up]
		var button: Button = _cell_buttons.get(pos)
		var center: Vector2 = _fx_layer.to_local(button.get_global_rect().get_center()) if button != null else Vector2.ZERO
		visuals.append({"position": pos, "key": key, "texture": texture, "center": center})

	return visuals

func _animate_swap_and_refresh(from_pos: Vector2i, to_pos: Vector2i, from_texture: Texture2D, to_texture: Texture2D, before_visuals: Array[Dictionary]) -> void:
	var from_button: Button = _cell_buttons.get(from_pos)
	var to_button: Button = _cell_buttons.get(to_pos)
	if from_button == null or to_button == null or from_texture == null or to_texture == null:
		await _animate_board_transition(before_visuals)
		_input_locked = false
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
	await _animate_board_transition(before_visuals)
	_input_locked = false

func _animate_board_transition(before_visuals: Array[Dictionary]) -> void:
	var after_visuals := _capture_board_visuals()
	_refresh_board()
	await get_tree().process_frame
	var unused_sources: Array[int] = []
	for index in range(before_visuals.size()):
		unused_sources.append(index)
	var sprites: Array[TextureRect] = []
	var targets: Array[Vector2] = []
	var sprite_size := Vector2(CELL_SIZE * 0.78, CELL_SIZE * 0.78)
	for destination in after_visuals:
		var target_pos: Vector2i = destination["position"]
		var target_button: Button = _cell_buttons.get(target_pos)
		if target_button == null:
			continue
		var target_center: Vector2 = _fx_layer.to_local(target_button.get_global_rect().get_center())
		var best_source := -1
		var best_distance := INF
		for source_index in unused_sources:
			var source: Dictionary = before_visuals[source_index]
			if source.key != destination.key:
				continue
			var source_pos: Vector2i = source["position"]
			var source_center: Vector2 = source["center"]
			var distance: float = source_center.distance_squared_to(target_center)
			if source_pos.x == target_pos.x:
				distance *= 0.72
			if distance < best_distance:
				best_distance = distance
				best_source = source_index
		var start_center := target_center
		if best_source >= 0:
			start_center = before_visuals[best_source]["center"]
			unused_sources.erase(best_source)
		else:
			start_center.y -= CELL_SIZE * float(_run.board.height)
		var target_texture: Texture2D = destination["texture"]
		var sprite := _make_swap_sprite(target_texture, start_center, sprite_size)
		sprite.scale = Vector2(0.82, 0.82)
		sprite.modulate.a = 0.85
		_fx_layer.add_child(sprite)
		sprites.append(sprite)
		targets.append(target_center)
		for child in target_button.get_children():
			if child is TextureRect and child.has_meta("board_piece_view"):
				child.modulate.a = 0.0
	if sprites.is_empty():
		return
	var fall := create_tween()
	fall.set_parallel(true)
	for index in range(sprites.size()):
		fall.tween_property(sprites[index], "position", targets[index] - sprite_size / 2.0, 0.24 + float(index % 5) * 0.018).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fall.tween_property(sprites[index], "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fall.tween_property(sprites[index], "modulate:a", 1.0, 0.18)
	await fall.finished
	for sprite in sprites:
		sprite.queue_free()
	for button in _cell_buttons.values():
		for child in button.get_children():
			if child is TextureRect and child.has_meta("board_piece_view"):
				child.modulate.a = 1.0

func _make_swap_sprite(texture: Texture2D, center: Vector2, sprite_size: Vector2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = sprite_size
	sprite.position = center - sprite_size / 2.0
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


func _show_clear_summary(cleared: int, obstacle_hits: int, powerups: int, cascades: int, combo_count: int = 0, combo_bonus: int = 0) -> void:
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
	if combo_count >= 2:
		headline += "   |   کمبو ×%d  +%s امتیاز" % [combo_count, _format_persian_number(combo_bonus)]
	var popup := Label.new()
	popup.text = headline
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 18 if combo_count < 2 and cascades == 0 else 21)
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
