class_name GuildInteraction
extends Node
## The action button's brain: what is in reach, which verb it offers, and the trade
## that lands when the verb finishes.
##
## The trade happens on `verb_finished`, never on the press, so a pickup cannot be
## banked twice by mashing the button and the animation and the transaction always
## describe the same event.

signal traded(result: Dictionary)
signal verb_offered(verb: String)

const REACH := 2.6
const REASON_KEYS := {
	"hands full": "msg.hands_full",
	"empty shelf": "msg.no_stock",
	"not enough goods": "msg.no_stock",
	"pouch full": "msg.hands_full",
	"already paid": "msg.order_done",
	"no gold": "msg.no_gold",
	"warehouse full": "msg.warehouse_full",
	"everyone out": "msg.no_adventurer",
	"nothing to buy": "msg.no_loot",
	"no desk": "msg.no_desk",
}
const SILENT_REASONS: Array[String] = ["nothing near", "no coins", "busy"]

var player: GuildPlayer
var stations: Array = []
var treasury: GuildTreasury
var stock: GuildStock
var last_result: Dictionary = {}
var last_verb := ""

var _pending: Dictionary = {}


func setup(new_player: GuildPlayer, new_stations: Array, new_treasury: GuildTreasury, new_stock: GuildStock) -> void:
	player = new_player
	stations = new_stations
	treasury = new_treasury
	stock = new_stock
	if player != null and not player.state.verb_finished.is_connected(_on_verb_finished):
		player.state.verb_finished.connect(_on_verb_finished)


## The station the player could act on right now, or null.
func station_near() -> GuildStation:
	if player == null:
		return null
	return GuildStation.nearest(stations, GuildStation.world_point(player), REACH)


func verb_available() -> String:
	var station := station_near()
	return station.verb() if station != null else ""


## The prompt the HUD shows on the action button.
func prompt(language: String = "en") -> String:
	var station := station_near()
	if station == null:
		return ""
	return station.prompt_for(language)


## The mission board's desk, if the player has one in reach of the roster.
func board() -> GuildStation:
	for station in stations:
		var found := station as GuildStation
		if found != null and found.kind == GuildStation.BOARD:
			return found
	return null


func missions_active() -> int:
	var station := board()
	if station == null or station.desk == null:
		return 0
	return station.desk.active_count()


## The item a waiting customer wants, so the shelf hands out the right goods.
func waiting_item() -> String:
	for station in stations:
		var counter := station as GuildStation
		if counter == null or counter.kind != GuildStation.COUNTER or counter.order == null:
			continue
		if counter.order.is_ready():
			return counter.order.item_id
	return ""


## Starts the verb. The transaction is applied when the verb finishes.
func press() -> Dictionary:
	var station := station_near()
	if station == null:
		last_result = {"reason": "nothing near"}
		traded.emit(last_result)
		return last_result
	var verb := station.verb()
	if not player.interact(verb):
		last_result = {"reason": "busy"}
		return last_result
	_pending = {"verb": verb, "station": station}
	verb_offered.emit(verb)
	return {"verb": verb, "station": station.kind, "started": true}


func _on_verb_finished(verb: String) -> void:
	if _pending.is_empty() or str(_pending["verb"]) != verb:
		return
	var station: GuildStation = _pending["station"]
	_pending = {}
	match verb:
		"pickup":
			last_result = GuildTrade.pick(player.state, station.stock, 3, waiting_item())
		"deliver":
			last_result = GuildTrade.deliver(player.state, station.order)
		"deposit":
			last_result = GuildTrade.deposit(player.state, station.treasury)
		"dispatch":
			last_result = station.desk.dispatch() if station.desk != null else {"reason": "no desk"}
		"buy_loot":
			last_result = station.desk.buy() if station.desk != null else {"reason": "no desk"}
		_:
			last_result = {"reason": "unknown verb"}
	last_verb = verb
	traded.emit(last_result)


## A human sentence for the toast, in the requested language.
func result_message(language: String = "en") -> String:
	if last_result.is_empty():
		return ""
	var reason := str(last_result.get("reason", ""))
	var message := ""
	if not reason.is_empty():
		if SILENT_REASONS.has(reason):
			return ""
		message = _reason_message(reason, language)
	elif last_result.has("mission_id"):
		message = _dispatched_message(language)
	elif last_result.has("loot"):
		message = _bought_message(language)
	elif last_result.has("taken"):
		message = _taken_message(language)
	elif last_result.has("amount"):
		message = _amount_message(language)
	return message


func _reason_message(reason: String, language: String) -> String:
	if REASON_KEYS.has(reason):
		return GuildLocale.t(str(REASON_KEYS[reason]), [], language)
	return ""


func _dispatched_message(language: String) -> String:
	var who := GuildLocale.t("customer." + str(last_result.get("class_id", "")), [], language)
	var job := GuildLocale.t(GuildMissions.name_key(str(last_result.get("mission_id", ""))), [], language)
	return GuildLocale.t("msg.dispatched", [who, job], language)


func _bought_message(language: String) -> String:
	var coins := GuildLocale.format_money(float(last_result.get("amount", 0.0)))
	var count := GuildMissions.item_count(last_result.get("loot", {}) as Dictionary)
	return GuildLocale.t("msg.loot_bought", ["%d" % count, coins], language)


func _taken_message(language: String) -> String:
	var taken := int(last_result["taken"])
	if taken <= 0:
		return GuildLocale.t("msg.no_stock", [], language)
	var item_id := str(last_result.get("item", ""))
	var item_name := GuildLocale.t(GuildItems.name_key(item_id), [], language)
	return GuildLocale.t("msg.picked", ["%d x %s" % [taken, item_name]], language)


func _amount_message(language: String) -> String:
	var amount := float(last_result["amount"])
	if amount <= 0.0:
		return ""
	var coins := GuildLocale.format_money(amount)
	if last_verb == "deposit":
		return GuildLocale.t("msg.deposited", [coins], language)
	return GuildLocale.t("order.paid", [coins], language)
