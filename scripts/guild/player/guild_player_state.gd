class_name GuildPlayerState
extends RefCounted
## What the player is doing and what they are holding, with no nodes involved.
##
## Carried items and carried gold are two separate hands: goods live in
## `carry`/`carry_capacity`, coins in `money`/`money_capacity`. Verbs take time,
## during which locomotion is blocked, so a pickup cannot happen mid-stride and a
## delivery cannot be double-counted by mashing the button.

signal verb_started(verb: String)
signal verb_finished(verb: String)
signal rejected(reason: String)
signal changed()

const IDLE := "idle"
const WALK := "walk"
const RUN := "run"
const BUSY := "busy"

## Seconds each interaction takes; the character rig plays the matching pose.
const VERBS := {
	"pickup": 0.45,
	"receive": 0.4,
	"deliver": 0.5,
	"deposit": 0.6,
}

var carry := 0
var carry_capacity := 6
var money := 0.0
var money_capacity := 500.0
var verb := ""
var verb_left := 0.0


func tick(delta: float) -> void:
	if verb.is_empty():
		return
	verb_left = maxf(verb_left - delta, 0.0)
	if verb_left <= 0.0:
		var finished := verb
		verb = ""
		verb_finished.emit(finished)
		changed.emit()


func is_busy() -> bool:
	return not verb.is_empty()


func can_start(verb_name: String) -> bool:
	return not is_busy() and VERBS.has(verb_name)


## Starts a timed verb. Returns false (and emits `rejected`) when the player is
## already busy, which is the only reason a verb can be refused outright.
func start_verb(verb_name: String) -> bool:
	if not VERBS.has(verb_name):
		rejected.emit("unknown verb")
		return false
	if is_busy():
		rejected.emit("busy")
		return false
	verb = verb_name
	verb_left = float(VERBS[verb_name])
	verb_started.emit(verb_name)
	changed.emit()
	return true


## How many of `amount` fit in the hands right now.
func space_for_items() -> int:
	return maxi(carry_capacity - carry, 0)


func can_carry(amount: int) -> bool:
	return amount > 0 and amount <= space_for_items()


## Adds items; returns how many were actually taken (never more than the space).
func take_items(amount: int) -> int:
	var taken := clampi(amount, 0, space_for_items())
	carry += taken
	if taken > 0:
		changed.emit()
	return taken


## Removes items; returns how many were actually handed over.
func give_items(amount: int) -> int:
	var given := clampi(amount, 0, carry)
	carry -= given
	if given > 0:
		changed.emit()
	return given


func money_space() -> float:
	return maxf(money_capacity - money, 0.0)


## Picks up coins; returns the amount accepted, the rest stays on the counter.
func load_money(amount: float) -> float:
	var accepted := clampf(amount, 0.0, money_space())
	money += accepted
	if accepted > 0.0:
		changed.emit()
	return accepted


## Empties the hands into the treasury; returns the amount handed over.
func unload_money() -> float:
	var handed := money
	money = 0.0
	if handed > 0.0:
		changed.emit()
	return handed


func is_hands_full() -> bool:
	return space_for_items() <= 0


func is_money_full() -> bool:
	return money_space() <= 0.0


## The locomotion state for the rig, given the current speed in m/s.
func locomotion(speed: float, running: bool = false) -> String:
	if is_busy():
		return BUSY
	if speed <= 0.08:
		return IDLE
	if running and speed > 2.6:
		return RUN
	return WALK


## The pose the character rig should hold this frame.
func pose_for(speed: float, running: bool = false) -> String:
	if is_busy():
		return verb
	var move := locomotion(speed, running)
	if move == RUN:
		return "run"
	if move == WALK:
		return "carry" if carry > 0 else "walk"
	return "carry" if carry > 0 else "idle"
