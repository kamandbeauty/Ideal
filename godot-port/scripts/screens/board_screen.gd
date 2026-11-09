class_name BoardScreen
extends UiScreen
## The level itself: header, goals, playfield, booster bar and the result card.
## Ported from client/Assets/Game/Ui/BoardScreen.cs.
##
## The screen owns presentation and input only. A tap becomes either a swap or a booster target; the
## ported LevelRun decides whether anything happens; the events it returns are handed to BoardView to
## animate. Nothing here re-implements a match-3 rule, so the headless tests cover the same logic the
## player sees.

signal home_requested
signal next_level_requested(level_number: int)
signal retry_requested(level_number: int)

# Landscape puts the playfield on the right and everything that describes the level in a column on the
# left, which is also the reading order of an RTL player: goals first, then the board they play on.
const BOARD_LEFT := 366.0
const BOARD_TOP := 60.0
const BOARD_SIZE := 330.0
# The frame art is a 256 px plate with a 24 px border, so the board sits exactly inside it.
const BOARD_FRAME_BORDER := 24.0
const COLUMN_X := 16.0
const COLUMN_W := 318.0
const CARD_HEIGHT := 46.0
const CHIP_HEIGHT := 26.0
const BOOSTER_SIZE := 52.0
const BOOSTER_GAP := 10.0
const BOOSTER_Y := 250.0
const OVERLAY_CARD_WIDTH := 440.0
const OVERLAY_CARD_HEIGHT := 330.0
const PAUSE_CARD_WIDTH := 380.0
const PAUSE_CARD_HEIGHT := 250.0
const DEFAULT_STATUS := "دو خانهٔ کنار هم را جابه‌جا کن تا سه مهره جور شوند"

var run: LevelRun
var level_number := 0

var _board: BoardView
var _level_label: Label
const HAND_SIZE := 44.0

var _moves_label: Label
var _score_label: Label
var _hint: Label
var _goal_chips: Array[Panel] = []
var _goal_icons: Array[TextureRect] = []
var _goal_labels: Array[Label] = []
var _booster_buttons: Array[Button] = []
var _booster_counts: Array[Label] = []
var _booster_badges: Array[TextureRect] = []
var _pause: Control
var _paused := false
var _overlay: Control
var _overlay_card: Panel
var _result_title: Label
var _result_body: Label
var _result_stars: Array[TextureRect] = []
var _primary: Button
var _secondary: Button
var _selected := Vector2i(-1, -1)
var _booster_kind := -1
var _finished := false
var _hint_hand: TextureRect
var _hint_move: Array[Vector2i] = []

func build() -> void:
	shows_top_bar = false
	# The palace backdrop is a picture, so it is never covered by a flat colour; only the veil art sits
	# over it, and only at the edges, to keep the header and the column readable.
	set_backdrop("board_backdrop_ch01", 0.18, 0.5, 0.5, 0.8, 0.7)

	# ---- header: home and pause at the right, the level chip, then the game's name ------------------
	UiKit.button(self, "home", "خانه", 650.0, 4.0, 72.0, 28.0, UiTokens.SURFACE_RAISED,
		UiTokens.TEXT, _on_home, UiTokens.RADIUS_MD)
	UiKit.button(self, "pause_button", "مکث", 570.0, 4.0, 72.0, 28.0, UiTokens.SURFACE_RAISED,
		UiTokens.TEXT, _on_pause, UiTokens.RADIUS_MD)

	var level_chip := UiKit.panel(self, "level_chip", 150.0, 4.0, 96.0, 28.0, UiTokens.GOLD,
		UiTokens.RADIUS_MD)
	_level_label = UiKit.label(level_chip, "level", "", UiTokens.TYPE_SM, UiTokens.ON_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_level_label, 4.0, 0.0, 88.0, 28.0)

	var title := UiKit.label(self, "title", "باغ شازده", UiTokens.TYPE_LG, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(title, 252.0, 4.0, 308.0, 28.0)

	# ---- the two counters, side by side, each a picture plate with a caption over its number -------
	var moves_card := _build_card("moves", COLUMN_X, 40.0, 204.0, CARD_HEIGHT)
	var moves_caption := UiKit.label(moves_card, "caption", "حرکت‌های باقی‌مانده", UiTokens.TYPE_XS,
		UiTokens.TEXT_MUTED)
	UiKit.place(moves_caption, 10.0, 2.0, 184.0, 18.0)
	_moves_label = UiKit.label(moves_card, "value", "", UiTokens.TYPE_BASE, UiTokens.ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_moves_label, 10.0, 20.0, 184.0, 24.0)

	var score_card := _build_card("score_card", 228.0, 40.0, 106.0, CARD_HEIGHT)
	var score_caption := UiKit.label(score_card, "caption", "امتیاز", UiTokens.TYPE_XS,
		UiTokens.TEXT_MUTED)
	UiKit.place(score_caption, 6.0, 2.0, 94.0, 18.0)
	_score_label = UiKit.label(score_card, "score", "", UiTokens.TYPE_BASE, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_score_label, 6.0, 20.0, 94.0, 24.0)

	# ---- goal chips, stacked under the counters ---------------------------------------------------
	for index in range(3):
		var y := 90.0 + float(index) * (CHIP_HEIGHT + 4.0)
		var chip := UiKit.panel(self, "goal_%d" % index, COLUMN_X, y, COLUMN_W, CHIP_HEIGHT,
			UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD)
		_goal_chips.append(chip)
		_goal_icons.append(UiKit.icon(chip, "icon", "piece_firouzeh", COLUMN_W - 26.0, 3.0,
			20.0, 20.0))
		var label := UiKit.label(chip, "value", "", UiTokens.TYPE_XS, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.place(label, 6.0, 0.0, COLUMN_W - 34.0, CHIP_HEIGHT)
		_goal_labels.append(label)

	# ---- the line that tells the player what to do, or what just went wrong ------------------------
	var status_card := _build_card("status_card", COLUMN_X, 182.0, COLUMN_W, CARD_HEIGHT)
	_hint = UiKit.label(status_card, "hint", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_hint, 8.0, 2.0, COLUMN_W - 16.0, CARD_HEIGHT - 4.0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var boosters_heading := UiKit.label(self, "boosters_heading", "ابزارهای کمکی",
		UiTokens.TYPE_XS, UiTokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(boosters_heading, COLUMN_X, 232.0, COLUMN_W, 16.0)

	# ---- booster bar: all five in one row, sized for a thumb --------------------------------------
	for kind in range(BoosterBag.SLOTS):
		var x := COLUMN_X + float(kind) * (BOOSTER_SIZE + BOOSTER_GAP)
		var handler := _on_booster_pressed.bind(kind)
		var button := UiKit.button(self, "booster_%d" % kind, "", x, BOOSTER_Y, BOOSTER_SIZE,
			BOOSTER_SIZE, UiTokens.SURFACE_RAISED, UiTokens.TEXT, handler, UiTokens.RADIUS_MD)
		_booster_buttons.append(button)
		_booster_badges.append(UiKit.icon(button, "badge", _booster_icon(kind), 6.0, 5.0,
			BOOSTER_SIZE - 12.0, BOOSTER_SIZE - 22.0))
		var count := UiKit.label(button, "count", "", UiTokens.TYPE_XS, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		UiKit.place(count, 2.0, BOOSTER_SIZE - 20.0, BOOSTER_SIZE - 4.0, 16.0)
		_booster_counts.append(count)

	# ---- playfield: the frame picture first, so the board draws on top of it -----------------------
	UiKit.art_panel(self, "board_frame", BOARD_LEFT - BOARD_FRAME_BORDER, BOARD_TOP - BOARD_FRAME_BORDER,
		BOARD_SIZE + BOARD_FRAME_BORDER * 2.0, BOARD_SIZE + BOARD_FRAME_BORDER * 2.0,
		"board_frame", int(BOARD_FRAME_BORDER), UiTokens.BG)
	_board = BoardView.new()
	_board.name = "board"
	add_child(_board)
	UiKit.place(_board, BOARD_LEFT, BOARD_TOP, BOARD_SIZE, BOARD_SIZE)
	_board.cell_tapped.connect(_on_cell_tapped)
	_board.swipe_requested.connect(_on_swipe)

	_hint_hand = UiKit.icon(self, "tutorial_hand", "tutorial_hand", 0.0, 0.0, HAND_SIZE, HAND_SIZE)
	_hint_hand.visible = false

	_build_overlay()
	_build_pause()

## A card: a shipped plate with a caption and a number on it. Never a StyleBoxFlat — the panel art is
## what keeps the HUD looking like the palace instead of a form.
func _build_card(node_name: String, x: float, y: float, width: float, height: float) -> Panel:
	# The small plate's 6 px nine-slice, not the large plate's 20 px one: a 20 px margin on a 46 px card
	# leaves a 6 px band for two lines of text, and Vazir's line height is not that small.
	return UiKit.art_panel(self, node_name, x, y, width, height, "ui_panel_raised_sm",
		UiTokens.BORDER_PLATE_SMALL, UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD)

# ---- lifecycle ----------------------------------------------------------------------------------

## Starts (or restarts) a level. Returns false and leaves a hint on screen when it may not start.
func start_level(level_to_play: int) -> bool:
	var attempt := session.start_attempt(level_to_play)
	var run_value: LevelRun = attempt.get("run", null)
	if run_value == null:
		_hint.text = str(attempt.get("error", "شروع مرحله ناموفق بود"))
		return false

	run = run_value
	level_number = level_to_play
	_finished = false
	_selected = Vector2i(-1, -1)
	_booster_kind = -1
	_hint.text = ""
	_overlay.visible = false
	if _pause != null:
		_pause.visible = false
	_paused = false
	_board.set_booster_mode(-1)
	_board.setup(run, Vector2(BOARD_SIZE, BOARD_SIZE))
	refresh()
	_maybe_teach()
	return true

func refresh() -> void:
	if session == null:
		return
	refresh_goals()
	for kind in range(_booster_buttons.size()):
		var owned := session.boosters.count(kind)
		_booster_counts[kind].text = PersianText.number(owned)
		_booster_buttons[kind].modulate = Color(1, 1, 1, 1) if owned > 0 else Color(0.6, 0.6, 0.65, 1)
		_booster_buttons[kind].disabled = owned <= 0
	if run == null:
		return
	_level_label.text = "مرحله " + PersianText.number(level_number)
	_moves_label.text = PersianText.number(run.moves_left)
	UiKit.fit_font(_moves_label, 176.0)
	if _score_label != null:
		# The caption above it already says «امتیاز», so the number stands alone.
		_score_label.text = PersianText.number(run.score)
	if _hint.text.strip_edges().is_empty():
		_hint.text = DEFAULT_STATUS

func refresh_goals() -> void:
	for index in range(_goal_chips.size()):
		var has_goal := run != null and index < run.level.goals.size()
		_goal_chips[index].visible = has_goal
		if not has_goal:
			continue
		var goal: Dictionary = run.level.goals[index]
		var art_id := "piece_firouzeh"
		if int(goal.get("kind", 0)) == GameTypes.GoalKind.CLEAR_OBSTACLE:
			art_id = _obstacle_art(int(goal.get("obstacle", 1)))
		else:
			art_id = _piece_art(int(goal.get("piece", 1)))
		_goal_icons[index].texture = UiKit.texture(art_id)
		_goal_icons[index].visible = _goal_icons[index].texture != null
		var progress := run.goals.progress(index)
		var target := run.goals.target(index)
		_goal_labels[index].text = PersianText.fraction(mini(progress, target), target)
		var complete := progress >= target
		_goal_labels[index].add_theme_color_override("font_color",
			UiTokens.SUCCESS if complete else UiTokens.TEXT)

static func _piece_art(kind: int) -> String:
	var path := AssetCatalog.piece_path(kind)
	return path if not path.is_empty() else "piece_firouzeh"

static func _obstacle_art(kind: int) -> String:
	var path := AssetCatalog.obstacle_path(kind)
	return path if not path.is_empty() else "obstacle_crate"

static func _booster_icon(kind: int) -> String:
	match kind:
		GameTypes.BoosterKind.MALLET: return "booster_mallet"
		GameTypes.BoosterKind.RAM: return "booster_ram"
		GameTypes.BoosterKind.AUGER: return "booster_auger"
		GameTypes.BoosterKind.WHIRLWIND: return "booster_whirlwind"
		GameTypes.BoosterKind.FALCON: return "booster_falcon"
		_: return "booster_mallet"

# ---- input --------------------------------------------------------------------------------------

func _on_cell_tapped(pos: Vector2i) -> void:
	if _paused or run == null or run.status != GameTypes.LevelStatus.PLAYING or _board.is_busy():
		return
	_hide_hand()
	SoundDirector.play("tap")
	if _booster_kind >= 0:
		_apply_booster(pos)
		return
	if _selected.x < 0:
		_selected = pos
		_board.set_selection(pos)
		return
	if _selected == pos:
		_selected = Vector2i(-1, -1)
		_board.set_selection(Vector2i(-1, -1))
		return
	var previous := _selected
	_selected = Vector2i(-1, -1)
	_board.set_selection(Vector2i(-1, -1))
	if absi(previous.x - pos.x) + absi(previous.y - pos.y) == 1:
		_attempt_swap(previous, pos)
	else:
		_selected = pos
		_board.set_selection(pos)

func _on_swipe(from: Vector2i, to: Vector2i) -> void:
	if _paused or run == null or run.status != GameTypes.LevelStatus.PLAYING or _board.is_busy():
		return
	_hide_hand()
	if _booster_kind >= 0:
		return
	_selected = Vector2i(-1, -1)
	_board.set_selection(Vector2i(-1, -1))
	_attempt_swap(from, to)

func _attempt_swap(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var before := run.board.duplicate_board()
	var result := run.try_swap(from_pos.x, from_pos.y, to_pos.x, to_pos.y)
	if not bool(result.get("accepted", false)):
		_hint.text = _reject_text(str(result.get("reject_reason", "")))
		SoundDirector.play("reject")
		Haptics.thump()
		await _board.animate_reject(from_pos, to_pos)
		return
	_hint.text = ""
	SoundDirector.play("swap")
	Haptics.tick()
	var cascades := int(result.get("cascades", 0))
	SoundDirector.play("match" if cascades <= 1 else "cascade", 1.0 + 0.06 * float(mini(cascades, 5)))
	# A cascade is felt, not just heard: the buzz gets heavier as the chain grows.
	if cascades <= 2:
		Haptics.tick()
	else:
		Haptics.thump()
	if int(result.get("power_ups_created", 0)) > 0:
		SoundDirector.play("power")
	_swap_in_copy(before, from_pos, to_pos)
	await _board.animate_swap(from_pos, to_pos)
	await _board.play_result(before, result.get("events", []))
	_play_result_cues(result)
	refresh()
	_check_finished()

static func _swap_in_copy(board: BoardModel, a: Vector2i, b: Vector2i) -> void:
	var first = board.at_pos(a)
	var second = board.at_pos(b)
	if first == null or second == null:
		return
	var piece: int = first.piece
	var power: int = first.power_up
	first.piece = second.piece
	first.power_up = second.power_up
	second.piece = piece
	second.power_up = power

func _apply_booster(pos: Vector2i) -> void:
	var before := run.board.duplicate_board()
	var outcome := session.try_use_booster(run, _booster_kind, pos.x, pos.y)
	_booster_kind = -1
	_board.set_booster_mode(-1)
	refresh()
	if not bool(outcome.get("ok", false)):
		_hint.text = "این بوستر مصرف نشد"
		return
	_hint.text = ""
	SoundDirector.play("power")
	await _board.play_result(before, outcome["result"].get("events", []))
	_play_result_cues(outcome["result"])
	refresh()
	_check_finished()

## One place reads a move's event list for the senses: what was cleared, whether an obstacle took a
## hit, whether a power-up was made or fired, how long the chain ran, and the combo bonus the core
## already computed. Nothing here decides anything — the numbers come from LevelRun._award_score.
func _play_result_cues(result: Dictionary) -> void:
	var cleared := 0
	var obstacles := 0
	var created := 0
	var triggered := 0
	var cascades := 0
	for event in result.get("events", []):
		match str(event.get("type", "")):
			"piece_cleared": cleared += 1
			"obstacle_hit": obstacles += 1
			"power_up_created": created += 1
			"power_up_triggered": triggered += 1
			"cascade": cascades += 1
	if cleared > 0:
		SoundDirector.play("clear", 0.94 + minf(float(cleared), 12.0) * 0.018)
	if obstacles > 0:
		SoundDirector.play("obstacle", 0.96 + minf(float(obstacles), 5.0) * 0.045)
	if created > 0:
		SoundDirector.play("power_create", 1.0 + minf(float(created), 3.0) * 0.08)
	if triggered > 0:
		SoundDirector.play("power", 0.92 + minf(float(triggered), 4.0) * 0.06)
	var combo_count := int(result.get("combo_count", cascades + triggered))
	var combo_bonus := int(result.get("combo_bonus", 0))
	if combo_count >= 2:
		SoundDirector.play("combo", 0.92 + minf(float(combo_count - 2), 5.0) * 0.08)
		Haptics.thump()
		_show_combo(combo_count, combo_bonus)
	elif cleared > 0 or obstacles > 0:
		Haptics.tick()

## The combo bubble: it is the only place a player learns that a chain paid a bonus, so it says the
## number out loud, floats up and gets out of the way.
func _show_combo(combo_count: int, combo_bonus: int) -> void:
	# A toast, not bare words: gold letters over a multi-coloured board cannot be read, and the fix has
	# to be a shipped plate rather than a rectangle the engine rounds at runtime.
	var toast_width := BOARD_SIZE - 30.0
	var toast_height := 40.0
	var start_y := BOARD_TOP + BOARD_SIZE * 0.5 - toast_height * 0.5
	var toast := UiKit.panel(self, "combo_toast", BOARD_LEFT + 15.0, start_y, toast_width, toast_height,
		UiTokens.SURFACE, UiTokens.RADIUS_MD)
	toast.z_index = 50
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Words and Persian digits only. A "+" or a "×" between a word and a number is a neutral character
	# in the bidi algorithm, and the run it splits can come out reading backwards on screen; a sentence
	# with a Persian connector cannot.
	var popup := UiKit.label(toast, "combo_popup", "", UiTokens.TYPE_BASE, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	popup.text = "کمبو " + PersianText.number(combo_count) + " و پاداش " \
		+ PersianText.number(combo_bonus) + " امتیاز"
	UiKit.place(popup, 0.0, 0.0, toast_width, toast_height)
	toast.modulate = Color(1, 1, 1, 0)
	toast.scale = Vector2(0.82, 0.82)
	toast.pivot_offset = Vector2(toast_width * 0.5, toast_height * 0.5)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.12)
	tween.tween_property(toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Relative, not absolute: the toast floats up 26 px from where it started, it does not fly to y=-26.
	tween.tween_property(toast, "position:y", start_y - 26.0, 0.75).set_delay(0.12)
	tween.tween_property(toast, "modulate:a", 0.0, 0.22).set_delay(0.68)
	tween.chain().tween_callback(toast.queue_free)

func _on_booster_pressed(kind: int) -> void:
	if _paused or run == null or run.status != GameTypes.LevelStatus.PLAYING:
		return
	if session.boosters.count(kind) <= 0:
		_hint.text = "بوستری از این نوع ندارید"
		return
	if _booster_kind == kind:
		_booster_kind = -1
		_board.set_booster_mode(-1)
		_hint.text = ""
		_mark_booster(kind, false)
		return
	_booster_kind = kind
	_board.set_booster_mode(kind)
	_hint.text = BoosterBag.booster_name(kind) + ": یک خانه را انتخاب کنید"
	for index in range(_booster_buttons.size()):
		_mark_booster(index, index == kind)

func _mark_booster(kind: int, selected: bool) -> void:
	if kind < 0 or kind >= _booster_buttons.size():
		return
	_booster_buttons[kind].modulate = Color(1.25, 1.25, 1.25, 1) if selected else Color(1, 1, 1, 1)

static func _reject_text(reason: String) -> String:
	match reason:
		"no match": return "این جابه‌جایی تطابقی نمی‌سازد"
		"not adjacent": return "فقط خانه‌های کنارِ هم"
		"empty cell": return "این خانه خالی است"
		_: return "حرکت پذیرفته نشد"

# ---- result -------------------------------------------------------------------------------------

func _check_finished() -> void:
	if run == null or run.status == GameTypes.LevelStatus.PLAYING or _finished:
		return
	_finished = true
	var outcome := session.finish_attempt(run)
	_show_result(bool(outcome.get("first_clear", false)), outcome.get("reward", RewardBundle.none()))

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "result"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	UiKit.stretch(_overlay, 0.0, 0.0)

	var dim := UiKit.veil(_overlay, "dim", Color(0.01, 0.02, 0.05, 0.78))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	_overlay_card = UiKit.art_panel(_overlay, "card", (UiTokens.CANVAS_WIDTH - OVERLAY_CARD_WIDTH) * 0.5,
		(UiTokens.CANVAS_HEIGHT - OVERLAY_CARD_HEIGHT) * 0.5, OVERLAY_CARD_WIDTH, OVERLAY_CARD_HEIGHT,
		"panel_frame", UiTokens.BORDER_CARD, UiTokens.SURFACE, UiTokens.RADIUS_PANEL)
	_overlay_card.mouse_filter = Control.MOUSE_FILTER_STOP

	var banner := UiKit.icon(_overlay_card, "banner", "result_win",
		(OVERLAY_CARD_WIDTH - 210.0) * 0.5, 10.0, 210.0, 58.0)
	banner.name = "banner"

	# The Unity banner plate is a frame with nothing printed on it, so the title goes inside the frame:
	# otherwise the first thing a player sees at the end of a level is an empty ornate box.
	_result_title = UiKit.label(_overlay_card, "title", "", UiTokens.TYPE_LG, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_result_title, 115.0, 10.0, 210.0, 58.0)

	var star_size := 34.0
	var star_gap := 10.0
	var star_total := star_size * 3.0 + star_gap * 2.0
	for index in range(3):
		var x := (OVERLAY_CARD_WIDTH - star_total) * 0.5 + float(index) * (star_size + star_gap)
		var star := UiKit.icon(_overlay_card, "star_%d" % index, "icon_star", x, 110.0, star_size, star_size)
		_result_stars.append(star)

	_result_body = UiKit.label(_overlay_card, "body", "", UiTokens.TYPE_SM, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_result_body, 20.0, 146.0, OVERLAY_CARD_WIDTH - 40.0, 56.0)
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_primary = UiKit.button(_overlay_card, "primary", "", 20.0, 204.0, OVERLAY_CARD_WIDTH - 40.0,
		46.0, UiTokens.ACCENT, UiTokens.ON_ACCENT, _on_primary, UiTokens.RADIUS_MD, true)
	_secondary = UiKit.button(_overlay_card, "secondary", "خانه", 20.0, 260.0, OVERLAY_CARD_WIDTH - 40.0,
		34.0, UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_home, UiTokens.RADIUS_MD)

func _show_result(first_clear: bool, reward: RewardBundle) -> void:
	var won := run.status == GameTypes.LevelStatus.WON
	var banner: TextureRect = _overlay_card.get_node("banner") as TextureRect
	banner.texture = UiKit.texture("result_win" if won else "result_lose")
	banner.visible = banner.texture != null

	var stars := StarRating.from_run(run) if won else 0
	for index in range(_result_stars.size()):
		_result_stars[index].modulate = Color(1, 1, 1, 1) if index < stars \
			else Color(0.3, 0.33, 0.4, 1.0)

	_result_title.text = "مرحله کامل شد" if won else "حرکت‌ها تمام شد"
	UiKit.fit_font(_result_title, 190.0)
	var body := ""
	if won:
		# Two lines at most: this label has a fixed box, and a third line would be clipped. The score
		# goes on the first line with the stars, the record and the reward share the second.
		body = "ستاره: " + PersianText.fraction(stars, StarRating.MAX_STARS) \
			+ " • امتیاز: " + PersianText.number(run.score)
		var second_line: Array[String] = []
		# finish_attempt has already written the record, so holding the best is ">=" not ">".
		if run.score > 0 and run.score >= int(session.save.find_level(level_number).get("best_score", 0)):
			second_line.append("رکورد تازه")
		if first_clear and reward != null and not reward.is_empty:
			second_line.append(PersianText.number(reward.coins) + " سکه و " \
				+ PersianText.number(reward.potions) + " معجون")
		elif not first_clear:
			second_line.append("این مرحله را قبلاً کامل کرده بودی")
		body += "\n" + " • ".join(second_line)
	else:
		body = "امتیاز: " + PersianText.number(run.score) + "\nیک جان کم شد. دوباره تلاش کن."
	_result_body.text = body

	if won and level_number < GameSession.LEVEL_COUNT:
		_primary.text = "مرحله بعد"
	elif won:
		_primary.text = "پایان فصل"
	else:
		_primary.text = "تلاش دوباره"
	if won:
		SoundDirector.play("win")
		if first_clear and reward != null and not reward.is_empty:
			Fx.coin_burst(_overlay_card, Vector2(OVERLAY_CARD_WIDTH * 0.5, 120.0))
			SoundDirector.play("reward", 1.0, 2.0)
	else:
		SoundDirector.play("lose")
	_overlay.visible = true

## Level one, first attempt: point at a swap that exists on the board that was dealt.
func _maybe_teach() -> void:
	_hint_move.clear()
	if _hint_hand == null or run == null or level_number != 1:
		return
	var record := session.save.find_level(1)
	if record is Dictionary and int(record.get("plays", 0)) > 0:
		return
	var move := _find_hint_move()
	if move.size() != 2:
		return
	_hint_move = [move[0], move[1]]
	# cell_center() is in the board's own space; the hand is a child of the screen. The offset is the
	# hand's half size, so its centre — where the fingertip is drawn — lands on the piece.
	var half := Vector2(HAND_SIZE * 0.5, HAND_SIZE * 0.5)
	var from_center: Vector2 = _board.position + _board.cell_center(move[0])
	var to_center: Vector2 = _board.position + _board.cell_center(move[1])
	_hint_hand.size = Vector2(HAND_SIZE, HAND_SIZE)
	_hint_hand.position = from_center - half
	_hint_hand.visible = true
	_hint.text = "برای شروع، این دو مهره را جابه‌جا کن"
	var tween := _hint_hand.create_tween().set_loops()
	tween.tween_property(_hint_hand, "position", to_center - half, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.25)
	tween.tween_property(_hint_hand, "position", from_center - half, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.6)

func _hide_hand() -> void:
	if _hint_hand != null:
		_hint_hand.visible = false
		_hint_hand.modulate = Color(1, 1, 1, 1)

## Returns the first adjacent pair whose swap creates a match, or an empty array.
func _find_hint_move() -> Array[Vector2i]:
	var board := run.board
	for y in range(board.height):
		for x in range(board.width):
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				var target := Vector2i(x + step.x, y + step.y)
				if not board.in_bounds(target.x, target.y):
					continue
				var trial := board.duplicate_board()
				_swap_in_copy(trial, Vector2i(x, y), target)
				if MatchFinder.has_match(trial):
					var found: Array[Vector2i] = [Vector2i(x, y), target]
					return found
	return []

func _on_primary() -> void:
	_overlay.visible = false
	if run != null and run.status == GameTypes.LevelStatus.WON and level_number < GameSession.LEVEL_COUNT:
		next_level_requested.emit(level_number + 1)
	elif run != null and run.status == GameTypes.LevelStatus.WON:
		home_requested.emit()
	else:
		retry_requested.emit(level_number)

## The pause card. A complete game has to be interruptible: the moves are limited, so the player needs
## a way to put the phone down without losing the board. It is a picture plate on the veil art, like
## every other surface.
func _build_pause() -> void:
	_pause = Control.new()
	_pause.name = "pause"
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.visible = false
	add_child(_pause)
	UiKit.stretch(_pause, 0.0, 0.0)

	var dim := UiKit.veil(_pause, "dim", Color(0.01, 0.02, 0.05, 0.82))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	var card := UiKit.art_panel(_pause, "card", (UiTokens.CANVAS_WIDTH - PAUSE_CARD_WIDTH) * 0.5,
		(UiTokens.CANVAS_HEIGHT - PAUSE_CARD_HEIGHT) * 0.5, PAUSE_CARD_WIDTH, PAUSE_CARD_HEIGHT,
		"panel_frame", UiTokens.BORDER_CARD, UiTokens.SURFACE, UiTokens.RADIUS_PANEL)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var title := UiKit.label(card, "title", "بازی متوقف شد", UiTokens.TYPE_LG, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(title, 16.0, 18.0, PAUSE_CARD_WIDTH - 32.0, 34.0)

	UiKit.button(card, "resume", "ادامه", 20.0, 66.0, PAUSE_CARD_WIDTH - 40.0, 46.0,
		UiTokens.ACCENT, UiTokens.ON_ACCENT, _on_resume, UiTokens.RADIUS_MD, true)
	UiKit.button(card, "restart", "شروع دوباره", 20.0, 122.0, PAUSE_CARD_WIDTH - 40.0, 46.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_restart, UiTokens.RADIUS_MD)
	UiKit.button(card, "leave", "بازگشت به خانه", 20.0, 178.0, PAUSE_CARD_WIDTH - 40.0, 46.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_home, UiTokens.RADIUS_MD)

func _on_pause() -> void:
	if run == null or run.status != GameTypes.LevelStatus.PLAYING:
		return
	_paused = true
	_pause.visible = true
	SoundDirector.play("tap")

func _on_resume() -> void:
	_paused = false
	if _pause != null:
		_pause.visible = false

func _on_restart() -> void:
	_paused = false
	if _pause != null:
		_pause.visible = false
	retry_requested.emit(level_number)

func _on_home() -> void:
	_overlay.visible = false
	_paused = false
	if _pause != null:
		_pause.visible = false
	home_requested.emit()

func clear() -> void:
	run = null
	_overlay.visible = false
	if _pause != null:
		_pause.visible = false
	_paused = false
