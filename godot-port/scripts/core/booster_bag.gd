class_name BoosterBag
extends RefCounted

const SLOTS := 5
const START_OWNED := 1
const MAX_OWNED := 9

var _data: SaveData

func _init(data: SaveData) -> void:
	_data = data
	_normalise()

static func price(kind: int) -> int:
	match kind:
		GameTypes.BoosterKind.MALLET: return 40
		GameTypes.BoosterKind.RAM: return 60
		GameTypes.BoosterKind.AUGER: return 60
		GameTypes.BoosterKind.WHIRLWIND: return 80
		GameTypes.BoosterKind.FALCON: return 100
		_: return 40

static func booster_name(kind: int) -> String:
	match kind:
		GameTypes.BoosterKind.MALLET: return "پتک"
		GameTypes.BoosterKind.RAM: return "قوچ"
		GameTypes.BoosterKind.AUGER: return "مته"
		GameTypes.BoosterKind.WHIRLWIND: return "گردباد"
		GameTypes.BoosterKind.FALCON: return "شاهین"
		_: return "بوستر"

func count(kind: int) -> int:
	if kind < 0 or kind >= SLOTS:
		return 0
	return _data.boosters[kind]

func has(kind: int) -> bool:
	return count(kind) > 0

func try_consume(kind: int) -> bool:
	if kind < 0 or kind >= SLOTS or _data.boosters[kind] <= 0:
		return false
	_data.boosters[kind] -= 1
	return true

func grant(kind: int, amount: int = 1) -> void:
	if kind < 0 or kind >= SLOTS or amount <= 0:
		return
	_data.boosters[kind] = mini(MAX_OWNED, _data.boosters[kind] + amount)

func buy(kind: int, wallet: Wallet, quantity: int = 1) -> bool:
	if wallet == null or quantity <= 0 or kind < 0 or kind >= SLOTS:
		return false
	var room := MAX_OWNED - _data.boosters[kind]
	if room <= 0:
		return false
	quantity = mini(quantity, room)
	var total := price(kind) * quantity
	if not wallet.can_afford_coins(total):
		return false
	if not wallet.try_spend_coins(total):
		return false
	_data.boosters[kind] += quantity
	return true

var total: int:
	get:
		var result := 0
		for amount in _data.boosters:
			result += amount
		return result

func _normalise() -> void:
	while _data.boosters.size() < SLOTS:
		_data.boosters.append(0)
	while _data.boosters.size() > SLOTS:
		_data.boosters.pop_back()
	for index in range(_data.boosters.size()):
		_data.boosters[index] = clampi(_data.boosters[index], 0, MAX_OWNED)
