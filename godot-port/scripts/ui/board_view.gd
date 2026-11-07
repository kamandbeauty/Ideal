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

const SWIPE_CELLS := 0.45
const CLEAR_SECONDS := 0.14
const FALL_SECONDS := 0.22
const SWAP_SECONDS := 0.14
const REJECT_SECONDS := 0.16
const TILE_INSET := 1.0
const PIECE_INSET := 2.0

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
		tile.modulate = Color(1.3, 1.3, 1.15, 1)

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
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	if run == null:
		return
	var tile_art := UiKit.texture("board_tile")
	for y in range(run.board.height):
		for x in range(run.board.width):
			var pos := Vector2i(x, y)
			var cell := run.board.at(x, y)
			var tile := _build_cell(pos, cell, tile_art)
			_tiles[pos] = tile
	_apply_highlight()

func _apply_highlight() -> void:
	var tile: Control = _tiles.get(_highlight)
	if tile != null and is_instance_valid(tile):
		tile.modulate = Color(1.3, 1.3, 1.15, 1)

func _build_cell(pos: Vector2i, cell, tile_art: Texture2D) -> Control:
	var tile := Control.new()
	tile.name = "cell_%d_%d" % [pos.x, pos.y]
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.pivot_offset = Vector2(cell_size, cell_size) * 0.5
	add_child(tile)
	tile.position = position_for(pos)
	tile.size = Vector2(cell_size, cell_size)

	if cell.blocked:
		var blocked := ColorRect.new()
		blocked.color = Color(0.02, 0.05, 0.10, 0.85)
		blocked.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(blocked)
		blocked.position = Vector2(TILE_INSET, TILE_INSET)
		blocked.size = Vector2(cell_size - TILE_INSET * 2.0, cell_size - TILE_INSET * 2.0)
		return tile

	if tile_art != null:
		var background := TextureRect.new()
		background.texture = tile_art
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		tile.add_child(background)
		background.position = Vector2(TILE_INSET, TILE_INSET)
		background.size = Vector2(cell_size - TILE_INSET * 2.0, cell_size - TILE_INSET * 2.0)

	if cell.has_piece:
		var piece_art := AssetCatalog.piece_texture(cell.piece)
		if piece_art != null:
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

	if cell.has_obstacle:
		var obstacle_art := AssetCatalog.obstacle_texture(cell.obstacle)
		if obstacle_art != null:
			var obstacle := TextureRect.new()
			obstacle.name = "obstacle"
			obstacle.texture = obstacle_art
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
	var released := cell_at(local_position)
	var pressed := _press_cell
	_press_cell = Vector2i(-1, -1)
	if released.x < 0 or pressed.x < 0:
		return

	var travel := (local_position - _press_position).length()
	if released == pressed and travel < cell_size * SWIPE_CELLS:
		cell_tapped.emit(released)
		return
	if released == pressed:
		cell_tapped.emit(released)
		return

	var dx := absi(released.x - pressed.x)
	var dy := absi(released.y - pressed.y)
	if dx + dy == 1:
		swipe_requested.emit(pressed, released)
	else:
		cell_tapped.emit(released)

# ---- animation ----------------------------------------------------------------------------------

## Plays the swap the player asked for. The board has already been mutated by the resolver, so this
## only moves the two tiles to each other's place before the settle pass redraws the truth.
func animate_swap(a: Vector2i, b: Vector2i) -> void:
	var tile_a: Control = _tiles.get(a)
	var tile_b: Control = _tiles.get(b)
	if tile_a == null or tile_b == null:
		return
	_busy = true
	var position_a := tile_a.position
	var position_b := tile_b.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile_a, "position", position_b, SWAP_SECONDS).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(tile_b, "position", position_a, SWAP_SECONDS).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	rebuild()
	_busy = false

## A refused move: the tiles go back and the player sees why without reading anything.
func animate_reject(a: Vector2i, b: Vector2i = Vector2i(-1, -1)) -> void:
	_busy = true
	var targets: Array[Control] = []
	for pos in [a, b]:
		var tile: Control = _tiles.get(pos)
		if tile != null:
			targets.append(tile)
	for tile in targets:
		var home := tile.position
		var tween := create_tween()
		tween.tween_property(tile, "position", home + Vector2(5.0, 0.0), REJECT_SECONDS * 0.25)
		tween.tween_property(tile, "position", home - Vector2(5.0, 0.0), REJECT_SECONDS * 0.5)
		tween.tween_property(tile, "position", home, REJECT_SECONDS * 0.25)
	if not targets.is_empty():
		await get_tree().create_timer(REJECT_SECONDS).timeout
	_busy = false

## Plays back one accepted move: cleared tiles pop, survivors fall, new tiles drop in, then the view
## is an exact picture of the board the resolver produced.
func play_result(before: BoardModel, events: Array) -> void:
	_busy = true
	var cleared := {}
	for event in events:
		if not event is Dictionary:
			continue
		if str(event.get("type", "")) != "piece_cleared":
			continue
		var pos = event.get("position", Vector2i(-1, -1))
		if pos is Vector2i:
			cleared[pos] = int(event.get("piece", GameTypes.PieceKind.NONE))

	if not cleared.is_empty():
		var tween := create_tween()
		tween.set_parallel(true)
		for pos in cleared:
			var tile: Control = _tiles.get(pos)
			if tile == null:
				continue
			Fx.spark(self, cell_center(pos), Fx.piece_tint(int(cleared[pos])), 8,
				cell_size / 44.0)
			tween.tween_property(tile, "scale", Vector2(0.2, 0.2), CLEAR_SECONDS)
			tween.tween_property(tile, "modulate", Color(1, 1, 1, 0), CLEAR_SECONDS)
		await tween.finished

	await _settle(before, cleared)
	_busy = false

func _settle(before: BoardModel, cleared: Dictionary) -> void:
	var offsets := {}
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
		tween.tween_property(tile, "position", target, FALL_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "modulate", Color(1, 1, 1, 1), FALL_SECONDS)
	await tween.finished
