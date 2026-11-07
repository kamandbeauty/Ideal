class_name StateHash
extends RefCounted

const MASK32 := 0xffffffff
const OFFSET_HIGH := 0xcbf29ce4
const OFFSET_LOW := 0x84222325

static func compute_run(run) -> String:
	if run == null:
		return "0000000000000000"
	var state: Array[int] = [OFFSET_HIGH, OFFSET_LOW]
	state = _mix_value(state, 0, 0xa1)
	state = _mix_value(state, 0, run.moves_left)
	state = _mix_value(state, 0, run.moves_used)
	state = _mix_value(state, 0, run.status)
	var rng_words: Array[int] = run.random.state_words()
	state = _mix_value(state, rng_words[0], rng_words[1])
	var board: BoardModel = run.board
	for y in range(board.height):
		for x in range(board.width):
			var cell = board.at(x, y)
			state = _mix_value(state, 0, cell.piece + 1)
			state = _mix_value(state, 0, cell.power_up + 1)
			state = _mix_value(state, 0, cell.obstacle + 1)
			state = _mix_value(state, 0, cell.obstacle_layers)
			state = _mix_value(state, 0, 1 if cell.blocked else 0)
	for index in range(run.goals.count()):
		state = _mix_value(state, 0, run.goals.progress(index))
		state = _mix_value(state, 0, run.goals.target(index))
	return "%08x%08x" % [state[0], state[1]]

static func compute_board(board: BoardModel) -> String:
	var state: Array[int] = [OFFSET_HIGH, OFFSET_LOW]
	for y in range(board.height):
		for x in range(board.width):
			var cell = board.at(x, y)
			state = _mix_value(state, 0, cell.piece + 1)
			state = _mix_value(state, 0, cell.power_up + 1)
	return "%08x%08x" % [state[0], state[1]]

static func _mix_value(state: Array[int], high: int, low: int) -> Array[int]:
	var result := state
	for shift in range(0, 32, 8):
		result = _mix_byte(result, (low >> shift) & 0xff)
	for shift in range(0, 32, 8):
		result = _mix_byte(result, (high >> shift) & 0xff)
	return result

static func _mix_byte(state: Array[int], value: int) -> Array[int]:
	var high: int = state[0]
	var low: int = state[1] ^ (value & 0xff)
	# FNV-1a prime = 0x00000100000001B3. Calculate low 64 bits without unsigned 64-bit ints.
	var low_product := low * 0x1b3
	var output_low := low_product & MASK32
	var carry := low_product >> 32
	var output_high := (carry + (low * 0x100) + (high * 0x1b3)) & MASK32
	return [output_high, output_low]
