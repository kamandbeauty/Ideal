extends Node2D
## Production game shell: actual endless gameplay, pooled entities and functional menus.

const RubyPlayerScript = preload("res://scripts/player/ruby.gd")
const EntityScript = preload("res://scripts/world/runner_entity.gd")
const BackgroundScript = preload("res://scripts/world/forest_background.gd")
const POOL_SIZE := 28

var background: ForestBackground
var player: RubyPlayer
var pool: Array[RunnerEntity] = []
var ui: CanvasLayer
var current_panel: Control
var hud: Control
var score_label: Label
var coins_label: Label
var best_label: Label
var rng := RandomNumberGenerator.new()
var spawn_distance := 600.0
var run_distance := 0.0
var run_time := 0.0
var world_speed := 420.0
var ending := false


func _ready() -> void:
	rng.randomize()
	background = BackgroundScript.new()
	add_child(background)
	player = RubyPlayerScript.new()
	add_child(player)
	player.hit.connect(_on_player_hit)
	player.visible = false
	for i in POOL_SIZE:
		var entity: RunnerEntity = EntityScript.new()
		add_child(entity)
		entity.deactivate()
		pool.append(entity)
	ui = CanvasLayer.new()
	add_child(ui)
	show_menu()


func clear_ui() -> void:
	for child in ui.get_children():
		child.queue_free()
	current_panel = null
	hud = null


func panel_base(title: String, subtitle: String = "") -> VBoxContainer:
	clear_ui()
	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.08, 0.18, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 80)
	ui.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)
	box.add_child(make_label(title, 55, Color("#FFF0CF")))
	if not subtitle.is_empty():
		box.add_child(make_label(subtitle, 25, Color("#D6CCE8")))
	current_panel = margin
	return box


func make_label(text: String, size := 28, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func make_button(text: String, callback: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 76)
	button.disabled = not enabled
	button.add_theme_font_size_override("font_size", 26)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#7B4EB2")
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	var hover := normal.duplicate()
	hover.bg_color = Color("#9565CE")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(
		func():
			AudioManager.play_sfx("button")
			callback.call()
	)
	return button


func show_menu() -> void:
	GameManager.state = GameManager.State.MENU
	background.playing = false
	player.visible = false
	_deactivate_entities()
	var box := panel_base("RUBY RUN", "روبی ران  •  Ruby Forest")
	var fox := TextureRect.new()
	fox.texture = load("res://assets/images/icon.svg")
	fox.custom_minimum_size = Vector2(180, 180)
	fox.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	fox.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(fox)
	box.add_child(
		make_label(
			"COINS  %d     BEST  %d" % [SaveManager.data.coins, SaveManager.data.best_score],
			26,
			Color("#F9C74F")
		)
	)
	box.add_child(make_button("PLAY  •  بازی", start_game))
	box.add_child(make_button("SKINS  •  پوسته‌ها", show_skins))
	box.add_child(make_button("DAILY REWARD  •  جایزه روزانه", show_daily))
	box.add_child(make_button("SETTINGS  •  تنظیمات", show_settings))


func start_game() -> void:
	clear_ui()
	ending = false
	run_distance = 0.0
	run_time = 0.0
	world_speed = 420.0
	spawn_distance = 450.0
	GameManager.start_run()
	background.playing = true
	background.speed = world_speed
	_deactivate_entities()
	player.reset_player()
	_build_hud()


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var bar := ColorRect.new()
	bar.color = Color(0.10, 0.08, 0.18, 0.68)
	bar.position = Vector2(22, 24)
	bar.size = Vector2(676, 100)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bar)
	score_label = make_label("SCORE 0", 25)
	score_label.position = Vector2(32, 46)
	score_label.size = Vector2(210, 50)
	hud.add_child(score_label)
	coins_label = make_label("COINS 0", 25, Color("#F9C74F"))
	coins_label.position = Vector2(255, 46)
	coins_label.size = Vector2(210, 50)
	hud.add_child(coins_label)
	best_label = make_label("BEST %d" % SaveManager.data.best_score, 25)
	best_label.position = Vector2(475, 46)
	best_label.size = Vector2(210, 50)
	hud.add_child(best_label)
	var hint := make_label("TAP TO JUMP  •  DOUBLE TAP", 22, Color(1, 1, 1, 0.72))
	hint.position = Vector2(80, 1130)
	hint.size = Vector2(560, 40)
	hud.add_child(hint)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(hint, "modulate:a", 0.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLAYING or ending:
		return
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and event.physical_keycode == KEY_SPACE
	if pressed:
		player.jump()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING or ending:
		return
	run_time += delta
	world_speed = minf(760.0, 420.0 + run_time * 8.0)
	background.speed = world_speed
	run_distance += world_speed * delta
	spawn_distance -= world_speed * delta
	GameManager.score = int(run_distance / 12.0)
	if spawn_distance <= 0:
		_spawn_fair_pattern()
	_check_collisions()
	if score_label:
		score_label.text = "SCORE %d" % GameManager.score
		coins_label.text = "COINS %d" % GameManager.run_coins


func _spawn_fair_pattern() -> void:
	# One grounded obstacle per pattern; spacing scales above the physics-required reaction gap.
	var obstacle_kind := RunnerEntity.Kind.ROCK if rng.randf() < 0.55 else RunnerEntity.Kind.LOG
	_spawn_entity(obstacle_kind, Vector2(800, 980), world_speed)
	var coin_count := rng.randi_range(2, 5)
	var airborne := rng.randf() < 0.65
	for i in coin_count:
		var coin_y := (
			830.0 - sin(float(i) / maxf(1.0, coin_count - 1) * PI) * 100.0 if airborne else 925.0
		)
		_spawn_entity(RunnerEntity.Kind.COIN, Vector2(930 + i * 76, coin_y), world_speed)
	# At max speed this remains >0.78s and never combines overlapping obstacles/pits.
	spawn_distance = rng.randf_range(
		maxf(570.0, world_speed * 0.82), maxf(850.0, world_speed * 1.25)
	)


func _spawn_entity(kind: RunnerEntity.Kind, at: Vector2, speed: float) -> void:
	for entity in pool:
		if not entity.active:
			entity.activate(kind, at, speed)
			return


func _check_collisions() -> void:
	var player_rect := player.collision_rect()
	for entity in pool:
		if not entity.active or not player_rect.intersects(entity.collision_rect()):
			continue
		if entity.kind == RunnerEntity.Kind.COIN:
			entity.collect()
			GameManager.run_coins += 1
			SaveManager.data.stats.coins_collected += 1
			AudioManager.play_sfx("coin")
			AnalyticsManager.track(&"coin_collected", {"amount": 1})
		else:
			player.take_hit()
			return


func _on_player_hit() -> void:
	if ending:
		return
	ending = true
	background.playing = false
	AudioManager.play_sfx("hit")
	var timer := get_tree().create_timer(0.45)
	await timer.timeout
	GameManager.finish_run()
	show_game_over()


func show_game_over() -> void:
	var box := panel_base("GAME OVER", "پایان بازی")
	box.add_child(
		make_label(
			(
				"SCORE  %d\nCOINS  +%d\nBEST  %d"
				% [GameManager.score, GameManager.run_coins, SaveManager.data.best_score]
			),
			32,
			Color("#F9C74F")
		)
	)
	box.add_child(make_button("RETRY  •  دوباره", start_game))
	box.add_child(make_button("HOME  •  خانه", show_menu))
	if not GameManager.revived and AdManager.is_rewarded_available("revive"):
		box.add_child(make_button("WATCH AD → REVIVE", func(): AdManager.show_rewarded("revive")))


func show_skins() -> void:
	var box := panel_base("SKINS", "پوسته‌ها  •  Coins: %d" % SaveManager.data.coins)
	for skin in SkinManager.skins:
		var unlocked: bool = SaveManager.data.unlocked_skins.has(skin.id)
		var equipped: bool = SaveManager.data.selected_skin == skin.id
		var text: String = (
			"%s  •  %s"
			% [
				skin.name,
				"EQUIPPED" if equipped else ("SELECT" if unlocked else "%d COINS" % skin.price)
			]
		)
		box.add_child(make_button(text, func(id = skin.id): _skin_action(id), not equipped))
	box.add_child(make_button("‹ BACK", show_menu))


func _skin_action(id: String) -> void:
	if SaveManager.data.unlocked_skins.has(id):
		SkinManager.equip(id)
	else:
		SkinManager.purchase(id)
	show_skins()


func show_daily() -> void:
	var state := RewardManager.status()
	var day := int(state.day)
	var box := panel_base("DAILY REWARD", "جایزه روزانه")
	for i in range(7):
		box.add_child(
			make_label(
				(
					"DAY %d     %d COINS%s"
					% [i + 1, RewardManager.REWARDS[i], "  ← NEXT" if i == day else ""]
				),
				23,
				Color("#F9C74F") if i == day else Color.WHITE
			)
		)
	var reason: String = str(state.get("reason", ""))
	box.add_child(
		make_button(
			(
				"CLAIM DAY %d" % (day + 1)
				if state.available
				else (reason if not reason.is_empty() else "COME BACK LATER")
			),
			_claim_daily,
			state.available
		)
	)
	box.add_child(make_button("‹ BACK", show_menu))


func _claim_daily() -> void:
	var amount := RewardManager.claim()
	if amount > 0:
		show_notice("+%d COINS!" % amount, show_daily)


func show_settings() -> void:
	var box := panel_base("SETTINGS", "تنظیمات")
	for key in ["music", "sound", "vibration"]:
		var enabled: bool = bool(SaveManager.data.settings[key])
		box.add_child(
			make_button(
				"%s     %s" % [key.to_upper(), "ON" if enabled else "OFF"],
				func(k = key): _toggle_setting(k)
			)
		)
	box.add_child(make_button("RESET LOCAL DATA", _confirm_reset))
	var privacy_url := str(ComplianceManager.config.get("privacy_policy_url", ""))
	box.add_child(
		make_button(
			"PRIVACY POLICY", func(): OS.shell_open(privacy_url), not privacy_url.is_empty()
		)
	)
	box.add_child(make_button("‹ BACK", show_menu))


func _toggle_setting(key: String) -> void:
	SaveManager.data.settings[key] = not bool(SaveManager.data.settings[key])
	SaveManager.save()
	AudioManager.apply_settings()
	show_settings()


func _confirm_reset() -> void:
	var box := panel_base(
		"RESET DATA?",
		"Coins, scores, skins, rewards and settings will be deleted from this device."
	)
	box.add_child(
		make_button(
			"DELETE LOCAL DATA",
			func():
				SaveManager.reset_all()
				show_notice("LOCAL DATA DELETED", show_menu)
		)
	)
	box.add_child(make_button("CANCEL", show_settings))


func show_notice(message: String, next: Callable) -> void:
	var box := panel_base(message)
	box.add_child(make_button("OK", next))


func _deactivate_entities() -> void:
	for entity in pool:
		entity.deactivate()
