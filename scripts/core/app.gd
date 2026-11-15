extends Node
## Global app state: language, saved progress, shared theme.

signal language_changed(language: String)
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const PERSIAN_DIGITS: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
const DEFAULT_LANGUAGE := "fa"

var language: String = DEFAULT_LANGUAGE
var best_reputation: int = 0
var ui_theme: Theme
var music_volume := 0.7
var sfx_volume := 0.85
var quality := Quality.DEFAULT
var haptics := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	ui_theme = UiTheme.build()
	Quality.apply(quality)


# --- Settings --------------------------------------------------------------

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	Sound.set_music_volume(music_volume)
	_save_settings()
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	Sound.set_sfx_volume(sfx_volume)
	_save_settings()
	settings_changed.emit()


func set_quality(level: String) -> void:
	var next := Quality.normalise(level)
	if next == quality:
		return
	quality = next
	Quality.apply(quality)
	_save_settings()
	settings_changed.emit()


func cycle_quality() -> void:
	var index := Quality.LEVELS.find(quality)
	set_quality(Quality.LEVELS[(index + 1) % Quality.LEVELS.size()])


## A short tap: on phones this is the difference between a game that feels
## alive and one that feels like a form.
func tap(strength: int = 30) -> void:
	if not haptics:
		return
	if OS.has_feature("mobile") or OS.has_feature("web_android"):
		Input.vibrate_handheld(strength)


## Number formatting for the current language: Persian reads its own digits.
func format_number(value: float, decimals: int = 0) -> String:
	var text := ""
	if decimals > 0:
		text = ("%." + str(decimals) + "f") % value
	else:
		text = str(int(round(value)))
	if language != "fa":
		return text
	var converted := ""
	for character in text:
		var index := "0123456789".find(character)
		converted += PERSIAN_DIGITS[index] if index >= 0 else character
	return converted


## Localised string lookup.
func t(key: String, args: Array = []) -> String:
	return L10n.translate(language, key, args)


func set_language(code: String) -> void:
	if not L10n.has_language(code) or code == language:
		return
	language = code
	_save_settings()
	language_changed.emit(language)


func toggle_language() -> void:
	set_language("en" if language == "fa" else "fa")


func is_rtl() -> bool:
	return language == "fa"


## Layout direction for freshly built controls.
func layout_direction() -> int:
	return Control.LAYOUT_DIRECTION_RTL if is_rtl() else Control.LAYOUT_DIRECTION_LTR


func record_reputation(reputation: int) -> void:
	if reputation > best_reputation:
		best_reputation = reputation
		_save_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_language := str(config.get_value("ui", "language", language))
	if L10n.has_language(saved_language):
		language = saved_language
	best_reputation = int(config.get_value("progress", "best_reputation", 0))
	music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	haptics = bool(config.get_value("audio", "haptics", haptics))
	quality = Quality.normalise(str(config.get_value("video", "quality", quality)))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "language", language)
	config.set_value("progress", "best_reputation", best_reputation)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "haptics", haptics)
	config.set_value("video", "quality", quality)
	config.save(SETTINGS_PATH)
