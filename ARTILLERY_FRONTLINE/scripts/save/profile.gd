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
		"vibration": true,
	},
	"stats": {
		"matches": 0,
		"victories": 0,
		"best_wave": 0,
		"kills": 0,
		"headshots": 0,
	},
}
const QUALITY_CHOICES: Array[String] = ["auto", "low", "medium", "high"]
const LANGUAGES: Array[String] = ["fa", "en"]

var save_path: String = "user://lastwall_v1.json"
## Tests switch persistence off so they never touch a real save.
var persist: bool = true
var data: Dictionary = {}


func _enter_tree() -> void:
	load_profile()


func load_profile() -> void:
	data = SaveManager.merge_defaults(DEFAULTS, SaveManager.load_dict(save_path) if persist else {})
	_sanitize()
	Loc.language = data.settings.language


func _sanitize() -> void:
	var settings: Dictionary = data.settings
	if not LANGUAGES.has(settings.language):
		settings.language = "fa"
	if not QUALITY_CHOICES.has(settings.quality):
		settings.quality = "auto"
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


func record_match(stats: Dictionary) -> void:
	var totals: Dictionary = data.stats
	totals.matches += 1
	if stats.get("victory", false):
		totals.victories += 1
	totals.best_wave = maxi(totals.best_wave, int(stats.get("wave", 0)))
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
