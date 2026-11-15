extends Node
## Autoload Profile: player settings and career totals, saved as JSON.

signal changed

const DEFAULTS: Dictionary = {
	"version": 1,
	"settings": {
		"language": "fa",
		"sensitivity": 1.0,
		"invert_y": false,
		"left_handed": false,
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 0.6,
		"quality": "auto",
		"show_fps": false,
		"screen_shake": true,
		"gun": "twin_hmg",
	},
	"economy": {
		"coins": 0,
		"upgrades": {"twin_hmg": 0, "rotary_gun": 0, "dual_mauler": 0, "bushmaster": 0, "gilded_minigun": 0, "rpg_launcher": 0, "frag_grenade": 0},
	},
	"stats": {
		"matches": 0,
		"victories": 0,
		"best_wave": 0,
		"kills": 0,
		"headshots": 0,
		"stages_cleared": 0,
	},
}
const QUALITY_CHOICES: Array[String] = ["auto", "low", "medium", "high"]
const LANGUAGES: Array[String] = ["fa", "en"]
## The guns that can stand on the mount; the player picks one before a match.
const GUNS: Array[String] = ["twin_hmg", "rotary_gun", "dual_mauler", "bushmaster", "gilded_minigun"]
const EQUIPMENT: Array[String] = ["twin_hmg", "rotary_gun", "dual_mauler", "bushmaster", "gilded_minigun", "rpg_launcher", "frag_grenade"]
const MAX_UPGRADE: int = 5

var save_path: String = "user://lastwall_v1.json"
## Tests switch persistence off so they never touch a real save.
var persist: bool = true
var data: Dictionary = {}


func _enter_tree() -> void:
	load_profile()


func load_profile() -> void:
	adopt(SaveManager.load_dict(save_path) if persist else {})


## Takes a stored profile as the player's own: unknown keys dropped, missing ones filled in, every value made sane.
func adopt(stored: Dictionary) -> void:
	data = SaveManager.merge_defaults(DEFAULTS, stored)
	_credit_old_career(stored)
	_sanitize()
	Loc.language = data.settings.language


## A save from before the siege was cut into stages only knows how far its player got through the
## eight waves in one go. Nobody is sent back to the start for that: every stage that lay wholly
## behind the best wave reached is open, and the original three for a player who had already won.
func _credit_old_career(stored: Dictionary) -> void:
	var old: Variant = stored.get("stats")
	if not (old is Dictionary) or (old as Dictionary).is_empty() or (old as Dictionary).has("stages_cleared"):
		return
	var cleared: int = Campaign.place_of(int(data.stats.best_wave)).x - 1
	if int(data.stats.victories) > 0:
		cleared = mini(3, Campaign.count())
	data.economy.coins = clampi(int(data.economy.coins), 0, 100000000)
	for id: String in EQUIPMENT:
		data.economy.upgrades[id] = clampi(int(data.economy.upgrades[id]), 0, MAX_UPGRADE)
	data.stats.stages_cleared = clampi(cleared, 0, Campaign.count())


func _sanitize() -> void:
	var settings: Dictionary = data.settings
	if not LANGUAGES.has(settings.language):
		settings.language = "fa"
	if not QUALITY_CHOICES.has(settings.quality):
		settings.quality = "auto"
	if not GUNS.has(settings.gun):
		settings.gun = GUNS[0]
	data.stats.stages_cleared = clampi(int(data.stats.stages_cleared), 0, Campaign.count())
	settings.sensitivity = clampf(settings.sensitivity, 0.3, 2.5)
	for key: String in ["master_volume", "sfx_volume", "music_volume"]:
		settings[key] = clampf(settings[key], 0.0, 1.0)


func save() -> bool:
	if not persist:
		return true
	return SaveManager.save_dict(save_path, data)


func setting(key: String) -> Variant:
	return data.settings[key]


## `persist_now` is false while a slider is being dragged: the value takes
## effect at once but storage is written once, when the thumb lifts.
func set_setting(key: String, value: Variant, persist_now: bool = true) -> void:
	if not data.settings.has(key) or data.settings[key] == value:
		return
	data.settings[key] = value
	_sanitize()
	if key == "language":
		Loc.language = data.settings.language
		Events.language_changed.emit()
	if persist_now:
		save()
	changed.emit()
	Events.settings_changed.emit()


## A replay pays again; defeat pays nothing. Stage is bounded to valid values.
static func reward_for(stats: Dictionary) -> int:
	if not bool(stats.get("victory", false)):
		return 0
	return 100 + 50 * clampi(int(stats.get("stage", 0)), 0, Campaign.count() - 1)


func upgrade_level(id: String) -> int:
	return int(data.economy.upgrades.get(id, 0)) if EQUIPMENT.has(id) else 0


func upgrade_cost(id: String) -> int:
	if not EQUIPMENT.has(id) or upgrade_level(id) >= MAX_UPGRADE:
		return 0
	return 100 * (upgrade_level(id) + 1)


## Save the balance and level together. Failed storage must not grant a free upgrade.
func buy_upgrade(id: String) -> bool:
	var cost: int = upgrade_cost(id)
	if cost <= 0 or int(data.economy.coins) < cost:
		return false
	data.economy.coins -= cost
	data.economy.upgrades[id] += 1
	if not save():
		data.economy.coins += cost
		data.economy.upgrades[id] -= 1
		return false
	changed.emit()
	return true


func record_match(stats: Dictionary) -> void:
	var totals: Dictionary = data.stats
	data.economy.coins = mini(100000000, int(data.economy.coins) + reward_for(stats))
	totals.matches += 1
	if stats.get("victory", false):
		totals.victories += 1
	# The record is kept in waves of the whole siege, so that the second wave of stage 2 beats the third of stage 1.
	totals.best_wave = maxi(totals.best_wave, int(stats.get("wave_overall", stats.get("wave", 0))))
	# Winning the newest open stage opens the next one.
	if stats.get("victory", false) and int(stats.get("stage", -1)) == int(totals.stages_cleared):
		totals.stages_cleared = mini(int(totals.stages_cleared) + 1, Campaign.count())
	totals.kills += int(stats.get("kills", 0))
	totals.headshots += int(stats.get("headshots", 0))
	save()
	changed.emit()


func reset() -> void:
	data = DEFAULTS.duplicate(true)
	Loc.language = data.settings.language
	save()
	changed.emit()
	Events.settings_changed.emit()
