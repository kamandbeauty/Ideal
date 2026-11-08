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

const BOARD_TOP := 150.0
const BOARD_SIDE := 16.0
const BOARD_HEIGHT := 392.0
const CHIP_HEIGHT := 32.0
const BOOSTER_SIZE := 56.0
const BOOSTER_GAP := 8.0
const BOOSTER_Y := 596.0
const OVERLAY_CARD_WIDTH := 336.0

var run: LevelRun
var level_number := 0

var _board: BoardView
var _level_label: Label
const HAND_SIZE := 44.0

var _moves_label: Label
var _hint: Label
var _goal_chips: Array[Panel] = []
var _goal_icons: Array[TextureRect] = []
var _goal_labels: Array[Label] = []
var _booster_buttons: Array[Button] = []
var _booster_counts: Array[Label] = []
var _booster_badges: Array[TextureRect] = []
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
	set_backdrop("board_backdrop_ch01", 0.30, 0.5, 0.5, 0.75, 0.55)

	# ---- header: back (right, RTL), level, moves (left) ------------------------------------------
	UiKit.button(self, "home", "خانه", UiTokens.CANVAS_WIDTH - 16.0 - 76.0, 54.0, 76.0, 40.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_home, UiTokens.RADIUS_MD)

	_level_label = UiKit.label(self, "level", "", UiTokens.TYPE_LG, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_level_label, 96.0, 54.0, UiTokens.CANVAS_WIDTH - 192.0, 40.0)

	var moves_pill := UiKit.panel(self, "moves", 16.0, 54.0, 76.0, 40.0, UiTokens.SURFACE_RAISED,
		UiTokens.RADIUS_MD)
	_moves_label = UiKit.label(moves_pill, "value", "", UiTokens.TYPE_BASE, UiTokens.ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.stretch(_moves_label, 4.0, 0.0)

	# ---- goal chips ------------------------------------------------------------------------------
	var chip_gap := 6.0
	var chips := 3
	var chip_width := (UiTokens.CANVAS_WIDTH - 32.0 - chip_gap * float(chips - 1)) / float(chips)
	for index in range(chips):
		var x := 16.0 + float(index) * (chip_width + chip_gap)
		var chip := UiKit.panel(self, "goal_%d" % index, x, 102.0, chip_width, CHIP_HEIGHT,
			UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD)
		_goal_chips.append(chip)
		_goal_icons.append(UiKit.icon(chip, "icon", "piece_firouzeh", chip_width - 26.0,
			(CHIP_HEIGHT - 20.0) * 0.5, 20.0, 20.0))
		var label := UiKit.label(chip, "value", "", UiTokens.TYPE_SM, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.place(label, 4.0, 0.0, chip_width - 30.0, CHIP_HEIGHT)
		_goal_labels.append(label)

	# ---- playfield -------------------------------------------------------------------------------
	_board = BoardView.new()
	_board.name = "board"
	add_child(_board)
	UiKit.place(_board, BOARD_SIDE, BOARD_TOP, UiTokens.CANVAS_WIDTH - BOARD_SIDE * 2.0, BOARD_HEIGHT)
	_board.cell_tapped.connect(_on_cell_tapped)
	_board.swipe_requested.connect(_on_swipe)

	_hint_hand = UiKit.icon(self, "tutorial_hand", "tutorial_hand", 0.0, 0.0, HAND_SIZE, HAND_SIZE)
	_hint_hand.visible = false

	_hint = UiKit.label(self, "hint", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_hint, 20.0, 552.0, UiTokens.CANVAS_WIDTH - 40.0, 22.0)

	# ---- booster bar -----------------------------------------------------------------------------
	var total_width := BOOSTER_SIZE * 5.0 + BOOSTER_GAP * 4.0
	var start_x := (UiTokens.CANVAS_WIDTH - total_width) * 0.5
	for kind in range(BoosterBag.SLOTS):
		var x := start_x + float(kind) * (BOOSTER_SIZE + BOOSTER_GAP)
		var handler := _on_booster_pressed.bind(kind)
		var button := UiKit.button(self, "booster_%d" % kind, "", x, BOOSTER_Y, BOOSTER_SIZE,
			BOOSTER_SIZE, UiTokens.SURFACE_RAISED, UiTokens.TEXT, handler, UiTokens.RADIUS_MD)
		_booster_buttons.append(button)
		_booster_badges.append(UiKit.icon(button, "badge", _booster_icon(kind), 8.0, 6.0,
			BOOSTER_SIZE - 16.0, BOOSTER_SIZE - 22.0))
		var count := UiKit.label(button, "count", "", UiTokens.TYPE_XS, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		UiKit.place(count, 2.0, BOOSTER_SIZE - 20.0, BOOSTER_SIZE - 4.0, 16.0)
		_booster_counts.append(count)

	_build_overlay()

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
	_board.set_booster_mode(-1)
	_board.setup(run, Vector2(UiTokens.CANVAS_WIDTH - BOARD_SIDE * 2.0, BOARD_HEIGHT))
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
	UiKit.fit_font(_moves_label, 68.0)

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
		_goal_labels[index].text = PersianText.number(mini(progress, target)) + "/" \
			+ PersianText.number(target)
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
	if run == null or run.status != GameTypes.LevelStatus.PLAYING or _board.is_busy():
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
	if run == null or run.status != GameTypes.LevelStatus.PLAYING or _board.is_busy():
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
	refresh()
	_check_finished()

func _on_booster_pressed(kind: int) -> void:
	if run == null or run.status != GameTypes.LevelStatus.PLAYING:
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

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	UiKit.stretch(dim, 0.0, 0.0)

	_overlay_card = UiKit.art_panel(_overlay, "card", (UiTokens.CANVAS_WIDTH - OVERLAY_CARD_WIDTH) * 0.5,
		196.0, OVERLAY_CARD_WIDTH, 380.0, "panel_frame", UiTokens.BORDER_CARD, UiTokens.SURFACE,
		UiTokens.RADIUS_PANEL)
	_overlay_card.mouse_filter = Control.MOUSE_FILTER_STOP

	var banner := UiKit.icon(_overlay_card, "banner", "result_win",
		(OVERLAY_CARD_WIDTH - 104.0) * 0.5, 12.0, 104.0, 104.0)
	banner.name = "banner"

	_result_title = UiKit.label(_overlay_card, "title", "", UiTokens.TYPE_XL, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_result_title, 16.0, 116.0, OVERLAY_CARD_WIDTH - 32.0, 40.0)

	var star_size := 44.0
	var star_gap := 10.0
	var star_total := star_size * 3.0 + star_gap * 2.0
	for index in range(3):
		var x := (OVERLAY_CARD_WIDTH - star_total) * 0.5 + float(index) * (star_size + star_gap)
		var star := UiKit.icon(_overlay_card, "star_%d" % index, "icon_star", x, 160.0, star_size, star_size)
		_result_stars.append(star)

	_result_body = UiKit.label(_overlay_card, "body", "", UiTokens.TYPE_SM, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_result_body, 20.0, 214.0, OVERLAY_CARD_WIDTH - 40.0, 52.0)
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_primary = UiKit.button(_overlay_card, "primary", "", 20.0, 274.0, OVERLAY_CARD_WIDTH - 40.0,
		52.0, UiTokens.ACCENT, UiTokens.ON_ACCENT, _on_primary, UiTokens.RADIUS_MD, true)
	_secondary = UiKit.button(_overlay_card, "secondary", "خانه", 20.0, 332.0, OVERLAY_CARD_WIDTH - 40.0,
		36.0, UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_home, UiTokens.RADIUS_MD)

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
	var body := ""
	if won:
		body = "ستاره: " + PersianText.fraction(stars, StarRating.MAX_STARS)
		if first_clear and reward != null and not reward.is_empty:
			body += "\n" + PersianText.number(reward.coins) + " سکه و " \
				+ PersianText.number(reward.potions) + " معجون"
		elif not first_clear:
			body += "\nاین مرحله را قبلاً کامل کرده بودی"
	else:
		body = "یک جان کم شد. دوباره تلاش کن."
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

func _on_home() -> void:
	_overlay.visible = false
	home_requested.emit()

func clear() -> void:
	run = null
	_overlay.visible = false
