class_name BoardModel
extends RefCounted

class Cell:
	var piece: int = GameTypes.PieceKind.NONE
	var power_up: int = GameTypes.PowerUpKind.NONE
	var obstacle: int = GameTypes.ObstacleKind.NONE
	var obstacle_layers: int = 0
	var blocked: bool = false

	var has_piece: bool:
		get:
			return piece != GameTypes.PieceKind.NONE

	var has_obstacle: bool:
		get:
			return obstacle != GameTypes.ObstacleKind.NONE and obstacle_layers > 0

	func clear_piece() -> void:
		piece = GameTypes.PieceKind.NONE
		power_up = GameTypes.PowerUpKind.NONE

	func set_obstacle(kind: int, layers: int) -> void:
		obstacle = kind
		obstacle_layers = 0 if kind == GameTypes.ObstacleKind.NONE else maxi(1, layers)

	func duplicate_cell() -> Cell:
		var copy := Cell.new()
		copy.piece = piece
		copy.power_up = power_up
		copy.obstacle = obstacle
		copy.obstacle_layers = obstacle_layers
		copy.blocked = blocked
		return copy

var width: int
var height: int
var _cells: Array[Cell] = []

func _init(board_width: int = 1, board_height: int = 1) -> void:
	width = maxi(1, board_width)
	height = maxi(1, board_height)
	_cells.resize(width * height)
	for index in range(_cells.size()):
		_cells[index] = Cell.new()

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func at(x: int, y: int) -> Cell:
	if not in_bounds(x, y):
		return null
	return _cells[y * width + x]

func at_pos(pos: Vector2i) -> Cell:
	return at(pos.x, pos.y)

func all_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			result.append(Vector2i(x, y))
	return result

func duplicate_board() -> BoardModel:
	var copy := BoardModel.new(width, height)
	for index in range(_cells.size()):
		copy._cells[index] = _cells[index].duplicate_cell()
	return copy

func copy_from(other: BoardModel) -> void:
	for index in range(mini(_cells.size(), other._cells.size())):
		_cells[index] = other._cells[index].duplicate_cell()

func count_pieces() -> int:
	var total := 0
	for cell in _cells:
		if cell.has_piece:
			total += 1
	return total

func to_ascii() -> String:
	var lines: PackedStringArray = []
	for y in range(height - 1, -1, -1):
		var line := ""
		for x in range(width):
			line += _char_for(at(x, y))
		lines.append(line)
	return "\n".join(lines)

func _char_for(cell: Cell) -> String:
	if cell == null:
		return "?"
	if cell.blocked:
		return "#"
	match cell.power_up:
		GameTypes.PowerUpKind.ROCKET_VERTICAL: return "v"
		GameTypes.PowerUpKind.ROCKET_HORIZONTAL: return "h"
		GameTypes.PowerUpKind.FAN: return "s"
		GameTypes.PowerUpKind.KITE: return "d"
		GameTypes.PowerUpKind.ELECTRO_BALL: return "e"
		GameTypes.PowerUpKind.SUPER_ELECTRO_BALL: return "E"
	match cell.piece:
		GameTypes.PieceKind.FIROUZEH: return "F"
		GameTypes.PieceKind.LAJVARD: return "L"
		GameTypes.PieceKind.AQIQ: return "A"
		GameTypes.PieceKind.ZOMORROD: return "Z"
		GameTypes.PieceKind.MORVARID: return "M"
		GameTypes.PieceKind.ANANAS: return "P"
		GameTypes.PieceKind.PORTEQAL: return "O"
		GameTypes.PieceKind.MOZ: return "B"
		_: return "."

static func from_ascii(rows: PackedStringArray) -> BoardModel:
	if rows.is_empty():
		return BoardModel.new()
	var board_width := 0
	for row in rows:
		board_width = maxi(board_width, row.length())
	var board := BoardModel.new(board_width, rows.size())
	for row_index in range(rows.size()):
		var y := rows.size() - 1 - row_index
		for x in range(board_width):
			var ch := rows[row_index].substr(x, 1) if x < rows[row_index].length() else "."
			var cell := board.at(x, y)
			match ch:
				"F": cell.piece = GameTypes.PieceKind.FIROUZEH
				"L": cell.piece = GameTypes.PieceKind.LAJVARD
				"A": cell.piece = GameTypes.PieceKind.AQIQ
				"Z": cell.piece = GameTypes.PieceKind.ZOMORROD
				"M": cell.piece = GameTypes.PieceKind.MORVARID
				"P": cell.piece = GameTypes.PieceKind.ANANAS
				"O": cell.piece = GameTypes.PieceKind.PORTEQAL
				"B": cell.piece = GameTypes.PieceKind.MOZ
				"v":
					cell.piece = GameTypes.PieceKind.LAJVARD
					cell.power_up = GameTypes.PowerUpKind.ROCKET_VERTICAL
				"h":
					cell.piece = GameTypes.PieceKind.LAJVARD
					cell.power_up = GameTypes.PowerUpKind.ROCKET_HORIZONTAL
				"s":
					cell.piece = GameTypes.PieceKind.LAJVARD
					cell.power_up = GameTypes.PowerUpKind.FAN
				"d":
					cell.piece = GameTypes.PieceKind.LAJVARD
					cell.power_up = GameTypes.PowerUpKind.KITE
				"e":
					cell.piece = GameTypes.PieceKind.LAJVARD
					cell.power_up = GameTypes.PowerUpKind.ELECTRO_BALL
				"E":
					cell.piece = GameTypes.PieceKind.LAJVARD
					cell.power_up = GameTypes.PowerUpKind.SUPER_ELECTRO_BALL
				"#": cell.blocked = true
				_: cell.clear_piece()
	return board
