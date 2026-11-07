class_name DeterministicRandom
extends RefCounted

# Exact xorshift64* port using two unsigned 32-bit words.
# GDScript int is signed 64-bit, so the state is represented as (high, low) words.
const MASK32: int = 0xffffffff
const FALLBACK_HIGH: int = 0x9e3779b9
const FALLBACK_LOW: int = 0x7f4a7c15
const MULTIPLIER_HIGH: int = 0x2545f491
const MULTIPLIER_LOW: int = 0x4f6cdd1d

var _high: int
var _low: int

func _init(seed_high: int = 0, seed_low: int = 1) -> void:
	_high = seed_high & MASK32
	_low = seed_low & MASK32
	if _high == 0 and _low == 0:
		_high = FALLBACK_HIGH
		_low = FALLBACK_LOW

func next_words() -> Vector2i:
	# x ^= x >> 12 (logical shift)
	var old_high := _high
	var old_low := _low
	var right_high := old_high >> 12
	var right_low := (old_low >> 12) | ((old_high & 0xfff) << 20)
	_high = (old_high ^ right_high) & MASK32
	_low = (old_low ^ right_low) & MASK32

	# x ^= x << 25
	old_high = _high
	old_low = _low
	var left_high := ((old_high << 25) | (old_low >> 7)) & MASK32
	var left_low := (old_low << 25) & MASK32
	_high = (old_high ^ left_high) & MASK32
	_low = (old_low ^ left_low) & MASK32

	# x ^= x >> 27 (logical shift)
	old_high = _high
	old_low = _low
	right_high = old_high >> 27
	right_low = (old_low >> 27) | ((old_high & 0x07ffffff) << 5)
	_high = (old_high ^ right_high) & MASK32
	_low = (old_low ^ right_low) & MASK32

	# Low 64 bits of state * 0x2545F4914F6CDD1D, using 16-bit limbs.
	var a0 := _low & 0xffff
	var a1 := (_low >> 16) & 0xffff
	var b0 := MULTIPLIER_LOW & 0xffff
	var b1 := (MULTIPLIER_LOW >> 16) & 0xffff
	var p0 := a0 * b0
	var p1 := a0 * b1 + a1 * b0
	var p2 := a1 * b1
	var low_sum := p0 + ((p1 & 0xffff) << 16)
	var output_low := low_sum & MASK32
	var carry := low_sum >> 32
	var output_high := (p2 + (p1 >> 16) + carry + ((_high * MULTIPLIER_LOW) & MASK32) + ((_low * MULTIPLIER_HIGH) & MASK32)) & MASK32
	return Vector2i(output_high, output_low)

func next(max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	var words := next_words()
	var modulus := max_exclusive
	var two32_mod := (4294967296 % modulus)
	return int((((words.x % modulus) * two32_mod) + (words.y % modulus)) % modulus)

func next_range(min_inclusive: int, max_exclusive: int) -> int:
	if max_exclusive <= min_inclusive:
		return min_inclusive
	return min_inclusive + next(max_exclusive - min_inclusive)

func next_01() -> float:
	var words := next_words()
	return float(words.x >> 8) / 16777216.0

func state_hex() -> String:
	return "%08x%08x" % [_high, _low]

func shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := next(index + 1)
		var temporary = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary
