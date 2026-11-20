class_name GuildMissionDesk
extends RefCounted
## The mission board as a service: who is on the roster, who is out, what came back,
## and the two transactions that make the loop real - paying a fee to send someone
## out, and paying the buy price for the loot they carry home.
##
## The desk never creates gold: a dispatch debits the vault, a purchase debits the
## vault and fills the warehouse. Both results are dictionaries with a `reason`
## that is empty only on success, exactly like GuildTrade.

signal changed()
signal departed(adventurer: GuildAdventurer, mission_id: String)
signal returned(adventurer: GuildAdventurer)
signal loot_bought(adventurer: GuildAdventurer, loot: Dictionary, paid: float)

var treasury: GuildTreasury
var stock: GuildStock
var adventurers: Array[GuildAdventurer] = []

var _rng := RandomNumberGenerator.new()


func setup(vault: GuildTreasury, goods: GuildStock, seed_value: int = 23) -> void:
	treasury = vault
	stock = goods
	_rng.seed = seed_value
	adventurers.clear()


## Adds someone to the roster. Ranks and classes are data, not decoration.
func hire(class_id: String, rank: String) -> GuildAdventurer:
	var adventurer := GuildAdventurer.new(class_id, rank)
	adventurers.append(adventurer)
	return adventurer


## The roster this desk starts with: two green recruits, a scout, and two veterans.
func hire_default_roster() -> void:
	adventurers.clear()
	hire("warrior", "F")
	hire("archer", "F")
	hire("mage", "E")
	hire("rogue", "D")
	hire("knight", "C")


func idle_count() -> int:
	var free := 0
	for adventurer in adventurers:
		if adventurer.is_free():
			free += 1
	return free


func active_count() -> int:
	var out := 0
	for adventurer in adventurers:
		if adventurer.is_away():
			out += 1
	return out


func waiting_count() -> int:
	var back := 0
	for adventurer in adventurers:
		if adventurer.has_loot():
			back += 1
	return back


## The adventurer whose pack is waiting to be bought, first in roster order.
func carrier() -> GuildAdventurer:
	for adventurer in adventurers:
		if adventurer.has_loot():
			return adventurer
	return null


## The lowest rank that can take a mission, so green recruits are sent on the
## small jobs and the veterans are saved for the dig.
func next_free_for(mission_id: String) -> GuildAdventurer:
	var best: GuildAdventurer = null
	var best_rank := 99
	for adventurer in adventurers:
		if not adventurer.can_take(mission_id):
			continue
		var index := GuildMissions.rank_index(adventurer.rank)
		if index < best_rank:
			best_rank = index
			best = adventurer
	return best


## What the action button at the board should do right now.
func next_verb() -> String:
	if carrier() != null:
		return "buy_loot"
	for mission_id in GuildMissions.ids():
		if next_free_for(mission_id) != null:
			return "dispatch"
	return ""


## Whether this exact pairing is allowed right now. An empty reason means yes, and
## every refusal is one word the panel and the toast can translate.
func dispatch_reason(adventurer: GuildAdventurer, mission_id: String) -> String:
	if adventurer == null:
		return "no adventurer"
	if not GuildMissions.exists(mission_id):
		return "no mission"
	if not adventurer.is_free():
		return "busy"
	if not GuildMissions.fits_rank(adventurer.rank, mission_id):
		return "rank low"
	var fee := float(GuildMissions.mission(mission_id).get("fee", 0.0))
	if treasury == null or not treasury.can_afford(fee):
		return "no gold"
	return ""


## Sends one specific adventurer on one specific mission, paying that mission's fee.
func dispatch_with(adventurer: GuildAdventurer, mission_id: String) -> Dictionary:
	var reason := dispatch_reason(adventurer, mission_id)
	if not reason.is_empty():
		return _result("dispatch", reason)
	var fee := float(GuildMissions.mission(mission_id).get("fee", 0.0))
	if not treasury.spend(fee):
		return _result("dispatch", "no gold")
	adventurer.send_out(mission_id)
	changed.emit()
	departed.emit(adventurer, mission_id)
	return {
		"verb": "dispatch",
		"amount": fee,
		"reason": "",
		"class_id": adventurer.class_id,
		"mission_id": mission_id,
	}


## The quick path the one-button board uses: the most junior suitable member goes on
## the cheapest job they can take.
func dispatch() -> Dictionary:
	for mission_id in GuildMissions.ids():
		var adventurer := next_free_for(mission_id)
		if adventurer == null:
			continue
		var result := dispatch_with(adventurer, mission_id)
		if str(result.get("reason", "")).is_empty():
			return result
		return result
	return _result("dispatch", "everyone out")


## Buys the pack the last adventurer carried home: the vault pays the buy price and
## the goods land in the warehouse. No pack, no gold - and no pack twice.
func buy() -> Dictionary:
	var adventurer := carrier()
	if adventurer == null:
		return _result("buy_loot", "nothing to buy")
	if treasury == null or stock == null:
		return _result("buy_loot", "no desk")
	var count := GuildMissions.item_count(adventurer.loot)
	if stock.space() < count:
		return _result("buy_loot", "warehouse full")
	var price := GuildMissions.value_of(adventurer.loot)
	if not treasury.can_afford(price):
		return _result("buy_loot", "no gold")
	if not treasury.spend(price):
		return _result("buy_loot", "no gold")
	var pack := adventurer.loot.duplicate()
	for id in pack:
		stock.add(str(id), int(pack[id]))
	adventurer.loot.clear()
	adventurer.state = GuildAdventurer.IDLE
	adventurer.mission_id = ""
	changed.emit()
	loot_bought.emit(adventurer, pack, price)
	return {
		"verb": "buy_loot",
		"amount": price,
		"reason": "",
		"loot": pack,
		"class_id": adventurer.class_id,
	}


## Runs the clock for everyone in the field and rolls their loot on return.
func tick(delta: float) -> void:
	for adventurer in adventurers:
		if not adventurer.tick(delta):
			continue
		if adventurer.state == GuildAdventurer.AWAY:
			adventurer.loot = GuildMissions.roll_loot(adventurer.mission_id, _rng)
			adventurer.state = GuildAdventurer.RETURNED
			if treasury != null:
				treasury.add_reputation(float(GuildMissions.mission(adventurer.mission_id).get("reputation", 0.0)))
			changed.emit()
			returned.emit(adventurer)


func report() -> String:
	var names: Array[String] = []
	for adventurer in adventurers:
		names.append("%s:%s" % [adventurer.class_id, adventurer.state])
	return "desk roster=%d out=%d back=%d [%s]" % [
		adventurers.size(),
		active_count(),
		waiting_count(),
		", ".join(names),
	]


func _result(verb: String, reason: String) -> Dictionary:
	return {"verb": verb, "amount": 0.0, "reason": reason}
