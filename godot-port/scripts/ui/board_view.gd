class_name BoardView
extends Control
## The playfield: tiles, obstacles, touch input and the four animations that make a match-3 read as
## one. Ported from the drawing half of client/Assets/Game/Ui/BoardScreen.cs.
##
## The view owns no rules. It renders whatever BoardModel the run currently holds, turns a press into
## a cell, and plays back the event list a move returned. Everything else — legality, cascades,
## scoring, goals — belongs to the ported core, which is why this file can be tested headlessly.

signal cell_tapped(pos: Vector2i)
signal swipe_requested(from: Vector2i, to: Vector2i)

# How far a finger has to travel before the gesture is a swipe. Below this the gesture is a tap on the
# cell that was pressed, whatever cell the finger happened to be over when it lifted: a thumb that
# rolls 10 dp sideways is still a tap, and treating it as a swipe is what "the swipe is not precise"
# looked like on the phone — the gem moved when the player did not mean to move it.
const SWIPE_CELLS := 0.42
## A drag shorter than this many cells is never a swipe, however far across a boundary it ended up.
const SWIPE_MIN_DP := 8.0
const CLEAR_SECONDS := 0.18
const SQUASH_SECONDS := 0.20
const FALL_SECONDS := 0.24
## A special piece takes its time: the whirlwind or the beam plays for about half a second and the
## pieces it takes start bursting a beat after it, so the player sees the cause before the effect.
const POWER_LEAD := 0.24
## How far the fan's gust is blown across the grid, in cells, and how long the board takes to empty in
## its wake. Both are short on purpose: the point of the piece is the colour that leaves, not the wind.
const FAN_SWEEP_CELLS := 2.6
const GUST_SWEEP_SECONDS := 0.26
const SHAKE_SECONDS := 0.34
const SWAP_SECONDS := 0.18
const REJECT_SECONDS := 0.20
## How much a stone grows as it is lifted off the tray for a swap. Small on purpose: past 1.1 the
## stone no longer looks handled, it looks like a button being pressed.
const SWAP_LIFT := 1.07
## A new stone arrives at this fraction of its size and swells to full, so a refilled column is seen
## to be refilled.
const SPAWN_SCALE := 0.55
const CLEAR_TWIST := 0.38
const REJECT_TINT := Color(1.0, 0.80, 0.78, 1.0)
const TILE_INSET := 1.0
# A gem that floats inside its tile with a wide dark margin is the single biggest reason the board
# read as a prototype: the art is 128 px with a gold rim, so at 36 dp the rim IS the border.
# The fruit overhangs its cell by a dp on every side: the painted plate has a margin of its own, and a
# piece that stops short of the cell reads as a sticker on a board instead of fruit on a table.
const PIECE_INSET := 0.0

var run: LevelRun
var cell_size := 44.0
var grid_origin := Vector2.ZERO

var _tiles: Dictionary = {}
var _press_cell := Vector2i(-1, -1)
var _press_position := Vector2.ZERO
var _booster_mode := -1
var _busy := false
var _highlight := Vector2i(-1, -1)

func setup(level_run: LevelRun, area: Vector2) -> void:
	run = level_run
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	var cols := run.board.width
	var rows := run.board.height
	var available_x := maxf(area.x, 1.0)
	var available_y := maxf(area.y, 1.0)
	cell_size = floor(min(available_x / float(cols), available_y / float(rows)))
	cell_size = maxf(cell_size, 8.0)
	var board_w := cell_size * float(cols)
	var board_h := cell_size * float(rows)
	grid_origin = Vector2(floor((available_x - board_w) * 0.5), floor((available_y - board_h) * 0.5))
	rebuild()

func set_booster_mode(kind: int) -> void:
	_booster_mode = kind

## Marks the cell the player has picked, so a tap-tap swap reads as clearly as a swipe.
func set_selection(pos: Vector2i) -> void:
	if _highlight == pos:
		return
	var previous: Control = _tiles.get(_highlight)
	if previous != null and is_instance_valid(previous):
		previous.modulate = Color(1, 1, 1, 1)
	_highlight = pos
	var tile: Control = _tiles.get(pos)
	if tile != null and is_instance_valid(tile):
		tile.modulate = Color(1.12, 1.10, 1.02, 1)

func is_busy() -> bool:
	return _busy

# ---- geometry -----------------------------------------------------------------------------------

func position_for(pos: Vector2i) -> Vector2:
	return grid_origin + Vector2(float(pos.x) * cell_size, float(pos.y) * cell_size)

func cell_center(pos: Vector2i) -> Vector2:
	return position_for(pos) + Vector2(cell_size, cell_size) * 0.5

func cell_at(local_position: Vector2) -> Vector2i:
	if run == null:
		return Vector2i(-1, -1)
	var local := local_position - grid_origin
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var x := int(local.x / cell_size)
	var y := int(local.y / cell_size)
	if not run.board.in_bounds(x, y):
		return Vector2i(-1, -1)
	return Vector2i(x, y)

# ---- drawing ------------------------------------------------------------------------------------

func rebuild() -> void:
	# Out of the tree first, freed after: a queued node is still a child until the frame ends, and a new
	# tile added under the same name while the old one is still there is silently renamed. Every tile is
	# named after its cell, so the names have to stay exactly what they are.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tiles.clear()
	if run == null:
		return
	# No plate per cell. The board floor already carries one soft grey square per cell, and a second,
	# cream plate inside every one of them boxed the fruit in: the player asked for fruit with no box,
	# sitting straight on a pale grey table.
	for y in range(run.board.height):
		for x in range(run.board.width):
			var pos := Vector2i(x, y)
			var cell := run.board.at(x, y)
			var tile := _build_cell(pos, cell)
			_tiles[pos] = tile
	_apply_highlight()

func _apply_highlight() -> void:
	var tile: Control = _tiles.get(_highlight)
	if tile != null and is_instance_valid(tile):
		tile.modulate = Color(1.12, 1.10, 1.02, 1)

func _build_cell(pos: Vector2i, cell) -> Control:
	var tile := Control.new()
	tile.name = "cell_%d_%d" % [pos.x, pos.y]
	# The cell travels with the tile: a tile is asked to go home after a refused move, and reading the
	# cell back out of the name would depend on the name never being touched.
	tile.set_meta("cell", pos)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.pivot_offset = Vector2(cell_size, cell_size) * 0.5
	add_child(tile)
	tile.position = position_for(pos)
	tile.size = Vector2(cell_size, cell_size)

	if cell.blocked:
		var blocked := TextureRect.new()
		blocked.name = "blocked"
		blocked.texture = UiKit.ui_texture("ui_veil")
		blocked.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		blocked.stretch_mode = TextureRect.STRETCH_SCALE
		blocked.modulate = Color(0.10, 0.07, 0.04, 0.74)
		blocked.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(blocked)
		blocked.position = Vector2(TILE_INSET, TILE_INSET)
		blocked.size = Vector2(cell_size - TILE_INSET * 2.0, cell_size - TILE_INSET * 2.0)
		return tile

	if cell.has_piece:
		var piece_art := AssetCatalog.piece_texture(cell.piece)
		if piece_art != null:
			# The pool of shadow the fruit sits in: without it the board is twelve flat stickers on
			# tiles, and the depth the tiles gained in the plate is spent again by the pieces.
			var pool := TextureRect.new()
			pool.name = "piece_shadow"
			pool.texture = UiKit.ui_texture("ui_piece_shadow")
			pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pool.stretch_mode = TextureRect.STRETCH_SCALE
			pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(pool)
			pool.position = Vector2(cell_size * 0.08, cell_size * 0.20)
			pool.size = Vector2(cell_size * 0.84, cell_size * 0.64)
			var piece := TextureRect.new()
			piece.name = "piece"
			piece.texture = piece_art
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tile.add_child(piece)
			piece.position = Vector2(PIECE_INSET, PIECE_INSET)
			piece.size = Vector2(cell_size - PIECE_INSET * 2.0, cell_size - PIECE_INSET * 2.0)

	if cell.power_up != GameTypes.PowerUpKind.NONE:
		var power_art := AssetCatalog.power_up_texture(cell.power_up)
		if power_art != null:
			var power := TextureRect.new()
			power.name = "power_up"
			power.texture = power_art
			power.mouse_filter = Control.MOUSE_FILTER_IGNORE
			power.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			power.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tile.add_child(power)
			power.position = Vector2(0.0, 0.0)
			power.size = Vector2(cell_size, cell_size)
			# The rocket fireworks sideways as well as up: same picture, turned a quarter turn, so a
			# horizontal rocket reads as "this row goes" and not as a second picture to learn.
			if cell.power_up == GameTypes.PowerUpKind.ROCKET_HORIZONTAL:
				power.pivot_offset = Vector2(cell_size, cell_size) * 0.5
				power.rotation = PI * 0.5

	if cell.has_obstacle:
		var obstacle_art := AssetCatalog.obstacle_texture(cell.obstacle)
		if obstacle_art != null:
			var obstacle := TextureRect.new()
			obstacle.name = "obstacle"
			obstacle.texture = obstacle_art
			# The crates and the vials are the Unity project's own pictures and stay untouched, so the
			# contrast against a bright ivory tile is given to them by a shadow underneath.
			var crate_pool := TextureRect.new()
			crate_pool.name = "obstacle_shadow"
			crate_pool.texture = UiKit.ui_texture("ui_piece_shadow")
			crate_pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			crate_pool.stretch_mode = TextureRect.STRETCH_SCALE
			crate_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crate_pool.modulate = Color(1, 1, 1, 0.75)
			tile.add_child(crate_pool)
			crate_pool.position = Vector2(cell_size * 0.06, cell_size * 0.22)
			crate_pool.size = Vector2(cell_size * 0.88, cell_size * 0.62)
			obstacle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			obstacle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			obstacle.stretch_mode = TextureRect.STRETCH_SCALE
			tile.add_child(obstacle)
			obstacle.position = Vector2(0.0, 0.0)
			obstacle.size = Vector2(cell_size, cell_size)
			obstacle.modulate = Color(1.0, 1.0, 1.0, 0.92)
			if cell.obstacle_layers > 1:
				var layers := Label.new()
				layers.text = PersianText.number(cell.obstacle_layers)
				layers.add_theme_font_override("font", UiKit.bold_font())
				layers.add_theme_font_size_override("font_size", maxi(10, int(cell_size * 0.34)))
				layers.add_theme_color_override("font_color", UiTokens.TEXT)
				layers.add_theme_color_override("font_outline_color", UiTokens.BG)
				layers.add_theme_constant_override("outline_size", 4)
				layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tile.add_child(layers)
				layers.position = Vector2(0.0, cell_size * 0.55)
				layers.size = Vector2(cell_size, cell_size * 0.4)
				layers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return tile

# ---- input --------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	# Godot emulates a mouse from every touch (and, in this project, a touch from every mouse). Handling
	# both would run press/release twice per tap: the first pair selects a piece and the second pair
	# selects it again, which on a phone reads as "the tiles do not respond, or respond elsewhere".
	# The emulation device is -1, so the real event wins and its copy is dropped.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_press(mouse.position)
		else:
			_release(mouse.position)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.position)
		else:
			_release(touch.position)
		accept_event()

func _press(local_position: Vector2) -> void:
	_press_cell = cell_at(local_position)
	_press_position = local_position

func _release(local_position: Vector2) -> void:
	var pressed := _press_cell
	_press_cell = Vector2i(-1, -1)
	if pressed.x < 0:
		return

	# The gesture is decided by the vector the finger travelled, not by which cell it happened to be
	# over at the end. Ending in the neighbouring cell used to be enough on its own, so a tap whose
	# thumb rolled 4 dp past the boundary swapped two gems.
	var drag := local_position - _press_position
	var travel := drag.length()
	var threshold := maxf(cell_size * SWIPE_CELLS, SWIPE_MIN_DP)
	if travel < threshold:
		cell_tapped.emit(pressed)
		return

	# One axis only: the dominant one. A diagonal drag is a drag along the axis the player leaned
	# towards, not a refusal — refusing was the other half of "not precise".
	var step := Vector2i(0, 1 if drag.y > 0.0 else -1)
	if absf(drag.x) >= absf(drag.y):
		step = Vector2i(1 if drag.x > 0.0 else -1, 0)
	var target := pressed + step
	if run == null or not run.board.in_bounds(target.x, target.y):
		return
	swipe_requested.emit(pressed, target)

# ---- animation ----------------------------------------------------------------------------------

## Plays the swap the player asked for. The board has already been mutated by the resolver, so this
## only moves the two tiles to each other's place before the settle pass redraws the truth.
##
## Three things together make a swap read as a gem being moved rather than two pictures sliding: the
## pair is drawn on top of the rest of the tray while it travels, both stones lift as they leave their
## cell (a stone that is being handled is closer to the eye, so it is briefly bigger), and the travel
## is eased in and out instead of running at a constant speed. The lift is a second tween on the same
## nodes: the move and the scale run on different curves, and only the move decides when the swap is
## over, so both are the same length and can be awaited once.
func animate_swap(a: Vector2i, b: Vector2i) -> void:
	var tile_a: Control = _tiles.get(a)
	var tile_b: Control = _tiles.get(b)
	if tile_a == null or tile_b == null:
		return
	_busy = true
	move_child(tile_a, -1)
	move_child(tile_b, -1)
	var position_a := tile_a.position
	var position_b := tile_b.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile_a, "position", position_b, SWAP_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile_b, "position", position_a, SWAP_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var lift := create_tween()
	lift.set_parallel(true)
	for tile in [tile_a, tile_b]:
		lift.tween_property(tile, "scale", Vector2(SWAP_LIFT, SWAP_LIFT),
			SWAP_SECONDS * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lift.tween_property(tile, "scale", Vector2.ONE, SWAP_SECONDS * 0.55) \
			.set_delay(SWAP_SECONDS * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if lift.is_valid():
		lift.kill()
	rebuild()
	_busy = false

## A refused move: the pair shakes along the axis the player pushed, the swing dying out like a stone
## nudged against another that will not give, and the stones warm towards red for the length of the
## shake so the refusal is seen as well as felt. Both halves use the same clock, so the shake is over
## exactly when the tint is, and the tiles are put back on their cells by hand afterwards: a tween that
## is interrupted must never leave a gem a few dp off its cell.
func animate_reject(a: Vector2i, b: Vector2i = Vector2i(-1, -1)) -> void:
	_busy = true
	var axis := Vector2.RIGHT
	if b.x >= 0 and b != a:
		var step := b - a
		axis = Vector2(signf(float(step.x)), 0.0)
		if absi(step.y) > absi(step.x):
			axis = Vector2(0.0, signf(float(step.y)))
	var amplitude := maxf(cell_size * 0.16, 5.0)
	var swing := [1.0, -0.72, 0.46, -0.22]
	var targets: Array[Control] = []
	for pos in [a, b]:
		var tile: Control = _tiles.get(pos)
		if tile != null and not targets.has(tile):
			targets.append(tile)
	for tile in targets:
		var home := tile.position
		var tween := create_tween()
		for step in swing:
			tween.tween_property(tile, "position", home + axis * amplitude * float(step),
				REJECT_SECONDS * 0.22).set_trans(Tween.TRANS_SINE)
		tween.tween_property(tile, "position", home, REJECT_SECONDS * 0.12)
		var blush := create_tween()
		blush.tween_property(tile, "modulate", REJECT_TINT, REJECT_SECONDS * 0.35)
		blush.tween_property(tile, "modulate", Color(1, 1, 1, 1), REJECT_SECONDS * 0.65)
	if not targets.is_empty():
		await get_tree().create_timer(REJECT_SECONDS).timeout
	for tile in targets:
		if not is_instance_valid(tile):
			continue
		tile.position = _home_of(tile)
		tile.modulate = Color(1, 1, 1, 1)
	_busy = false

## The cell a tile belongs on, carried on the tile itself, so a tile can always be put back after an
## interrupted tween without a second lookup table.
func _home_of(tile: Control) -> Vector2:
	var cell = tile.get_meta("cell", null)
	if cell is Vector2i:
		return position_for(cell)
	return tile.position

## Plays back one accepted move: cleared tiles pop, survivors fall, new tiles drop in, then the view
## is an exact picture of the board the resolver produced.
func play_result(before: BoardModel, events: Array) -> void:
	_busy = true
	# What the move takes is read first, because the effects are drawn from it: the gust of a fan has to
	# know which way the fruit it is about to take lies before it can be blown across the board.
	var cleared := {}
	for event in events:
		if not event is Dictionary:
			continue
		if str(event.get("type", "")) != "piece_cleared":
			continue
		var pos = event.get("position", Vector2i(-1, -1))
		if pos is Vector2i:
			cleared[pos] = int(event.get("piece", GameTypes.PieceKind.NONE))

	# A special piece that fired gets its own effect before the pieces it took start to burst: the fan
	# blows a gust across the board, the rocket a ring where it went off, the kite a ring where it landed.
	var fired_any := false
	var gust_from := Vector2.ZERO
	var gust_travel := Vector2.ZERO
	var has_gust := false
	for event in events:
		if not event is Dictionary:
			continue
		if str(event.get("type", "")) != "power_up_triggered":
			continue
		var fired = event.get("position", Vector2i(-1, -1))
		if not fired is Vector2i:
			continue
		fired_any = true
		var centre := cell_center(fired)
		match int(event.get("kind", 0)):
			GameTypes.PowerUpKind.FAN:
				# Straight across the grid, towards the middle of what it takes: the wind crosses, and
				# the pieces go where the wind has been, not all at once under a spinning top.
				gust_from = centre
				gust_travel = _gust_travel(fired, cleared)
				has_gust = true
				# A hand's width above the row it was fired on: the wind passes over the fruit, not
				# through it.
				Fx.whirlwind(self, centre - Vector2(0.0, cell_size * 0.10), gust_travel, cell_size * 2.8)
				_shake(cell_size * 0.10)
			GameTypes.PowerUpKind.ROCKET_HORIZONTAL:
				Fx.streak(self, centre, cell_size * float(run.board.width), true)
				_shake(cell_size * 0.16)
			GameTypes.PowerUpKind.ROCKET_VERTICAL:
				Fx.streak(self, centre, cell_size * float(run.board.height), false)
				_shake(cell_size * 0.16)
			_:
				Fx.ring(self, centre, cell_size * 2.2, UiTokens.ACCENT)
				_shake(cell_size * 0.08)
	if fired_any:
		await get_tree().create_timer(POWER_LEAD).timeout

	if not cleared.is_empty():
		var tween := create_tween()
		tween.set_parallel(true)
		var gust_reach := maxf(1.0, gust_travel.length())
		for pos in cleared:
			var tile: Control = _tiles.get(pos)
			if tile == null:
				continue
			# A piece the gust takes goes when the gust reaches it: the delay is how far down the wind's
			# own line the cell lies, so the board empties in the order the player watched the wind cross.
			var delay := 0.0
			if has_gust:
				var along := (cell_center(pos) - gust_from).dot(gust_travel / gust_reach)
				delay = clampf(along / gust_reach, 0.0, 1.0) * GUST_SWEEP_SECONDS
			# Juice, not sparks: the fruit bursts into its own colour, and the splat is a piece of art.
			# The cell itself is the boundary of the splash: one fruit's juice never lands in the next
			# fruit's square. It is hung on this tween rather than a timer so that leaving the board
			# mid-animation cannot leave a burst firing into a scene that is gone.
			var juice: Color = Fx.piece_tint(int(cleared[pos]))
			var burst_at: Vector2 = cell_center(pos)
			var juice_burst := func() -> void:
				Fx.splash(self, burst_at, juice, cell_size)
			tween.tween_callback(juice_burst).set_delay(delay)
			tween.tween_property(tile, "scale", Vector2(0.2, 0.2), CLEAR_SECONDS) \
				.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			# A small twist as it goes: a matched stone is lifted and taken, and a stone that only
			# shrinks on its own axis is the one effect every match-3 has already shown the player.
			tween.tween_property(tile, "rotation", CLEAR_TWIST, CLEAR_SECONDS).set_delay(delay)
			tween.tween_property(tile, "modulate", Color(1, 1, 1, 0), CLEAR_SECONDS).set_delay(delay)
		await tween.finished

	await _settle(before, cleared)
	_busy = false

## The line the gust travels: across the grid, from the cell that fired it towards the side the fruit it
## is taking lies on. It is level — never diagonal — because a wind that climbs over the board reads as
## something walking across it, and the player asked for the wind to pass flat over the grid. The
## direction is taken from the fruit itself, so the gust always blows towards what it is about to take,
## and its length is the shorter of the sweep and the room left on that side.
func _gust_travel(origin: Vector2i, cleared: Dictionary) -> Vector2:
	var balance := 0.0
	for pos in cleared:
		balance += float(pos.x - origin.x)
	if is_zero_approx(balance):
		balance = 1.0
	var direction := 1.0 if balance > 0.0 else -1.0
	var right_room := float(run.board.width - 1 - origin.x)
	var left_room := float(origin.x)
	var room := right_room if direction > 0.0 else left_room
	var other := left_room if direction > 0.0 else right_room
	# A fan fired from the last column has nowhere to blow that way, so it blows the other way rather
	# than across the rim of the board.
	if room < 1.2 and other > room:
		direction = -direction
		room = other
	var reach := minf(FAN_SWEEP_CELLS, maxf(1.2, room))
	return Vector2(direction * reach * cell_size, 0.0)

## The board takes the hit: three short steps out and a longer one back, on the board's own position
## rather than on each tile, so a firing rocket moves everything it is about to clear and nothing has
## to be put back afterwards except the board itself.
func _shake(amount: float) -> void:
	var home := position
	var tween := create_tween()
	for step in [1.0, -0.78, 0.5, -0.24]:
		tween.tween_property(self, "position", home + Vector2(amount * float(step),
			amount * float(step) * 0.55), SHAKE_SECONDS * 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", home, SHAKE_SECONDS * 0.28) \
		.set_trans(Tween.TRANS_SINE)

## A piece that lands is a piece with weight. One short, staggered squash per landed tile — the
## cheapest thing that makes a fall read as a fall rather than a teleport.
func _squash_all(landed: Array) -> void:
	var any := false
	for pos in landed:
		var tile: Control = _tiles.get(pos)
		if tile == null:
			continue
		any = true
		tile.pivot_offset = Vector2(cell_size, cell_size) * 0.5
		var tween := create_tween()
		tween.tween_property(tile, "scale", Vector2(1.06, 0.92), SQUASH_SECONDS * 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", Vector2(1.0, 1.0), SQUASH_SECONDS * 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if any:
		await get_tree().create_timer(SQUASH_SECONDS).timeout

func _settle(before: BoardModel, cleared: Dictionary) -> void:
	var offsets := {}
	var spawned_cells: Array[Vector2i] = []
	var board := run.board
	var falls_down := run.level.gravity == GameTypes.GravityDirection.DOWN
	for x in range(board.width):
		var survivors: Array[int] = []
		for y in range(board.height):
			var old_cell = before.at(x, y)
			if old_cell == null or old_cell.blocked or not old_cell.has_piece:
				continue
			if cleared.has(Vector2i(x, y)):
				continue
			survivors.append(y)
		var finals: Array[int] = []
		for y in range(board.height):
			var cell = board.at(x, y)
			if cell == null or cell.blocked or not cell.has_piece:
				continue
			finals.append(y)
		if finals.size() < survivors.size():
			continue
		var spawned := finals.size() - survivors.size()
		for index in range(survivors.size()):
			var from_y: int = survivors[index]
			var to_y: int = finals[spawned + index] if falls_down else finals[index]
			offsets[Vector2i(x, to_y)] = float(from_y - to_y)
		for index in range(spawned):
			var to_y: int = finals[index] if falls_down else finals[finals.size() - 1 - index]
			var depth := float(spawned - index)
			offsets[Vector2i(x, to_y)] = -depth if falls_down else depth
			spawned_cells.append(Vector2i(x, to_y))

	rebuild()
	if offsets.is_empty():
		return

	var tween := create_tween()
	tween.set_parallel(true)
	for pos in offsets:
		var tile: Control = _tiles.get(pos)
		if tile == null:
			continue
		var target: Vector2 = tile.position
		tile.position = target + Vector2(0.0, float(offsets[pos]) * cell_size)
		tile.modulate = Color(1, 1, 1, 0.9)
		# A stone travels further the higher its row was, so the fall lasts as long as the distance it
		# has to cover: every column lands together instead of the top rows snapping down in one frame.
		var drop := absf(float(offsets[pos]))
		var travel := clampf(FALL_SECONDS * 0.62 + FALL_SECONDS * 0.24 * drop,
			FALL_SECONDS * 0.62, FALL_SECONDS * 2.0)
		tween.tween_property(tile, "position", target, travel) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(tile, "modulate", Color(1, 1, 1, 1), travel)
		# A gem that comes in from beyond the tray is new, so it arrives small and swells to its size
		# while it falls. Without this the refilled column is a teleport: five stones appear already
		# in place, which is the one thing on the board that a real tray of stones would never do.
		if spawned_cells.has(pos):
			tile.scale = Vector2(SPAWN_SCALE, SPAWN_SCALE)
			tween.tween_property(tile, "scale", Vector2.ONE, travel) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await _squash_all(offsets.keys())
