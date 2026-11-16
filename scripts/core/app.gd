extends Node
## Global app state: language, compact tycoon number formatting, settings, haptics.

signal language_changed(language: String)
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const PERSIAN_DIGITS: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
const DEFAULT_LANGUAGE := "fa"
const COMPACT_SUFFIXES_EN: Array[String] = ["", "K", "M", "B", "T", "aa", "ab"]
const COMPACT_SUFFIXES_FA: Array[String] = ["", "هزار", "میلیون", "میلیارد", "تریلیون", "aa", "ab"]

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


func tap(strength: int = 28) -> void:
	if not haptics:
		return
	if OS.has_feature("mobile") or OS.has_feature("web_android"):
		Input.vibrate_handheld(strength)


## Grouped integer/decimal formatting with Persian digit conversion when active.
func format_number(value: float, decimals: int = 0) -> String:
	var negative := value < 0.0
	var abs_val := absf(value)
	var text := ""
	if decimals > 0:
		text = ("%." + str(decimals) + "f") % abs_val
	else:
		var whole := str(int(round(abs_val)))
		var parts: Array[String] = []
		while whole.length() > 3:
			parts.push_front(whole.substr(whole.length() - 3, 3))
			whole = whole.substr(0, whole.length() - 3)
		parts.push_front(whole)
		var sep := "٬" if language == "fa" else ","
		text = sep.join(parts)
	if negative:
		text = "-" + text
	return to_digits(text)


## Compact Roadside Empire currency format: 393, 2.4K, 9.76M, 3.11B.
func format_compact(value: float) -> String:
	var negative := value < 0.0
	var abs_val := absf(value)
	if abs_val < 1000.0:
		var small := str(int(round(abs_val)))
		if negative:
			small = "-" + small
		return to_digits(small)
	var tier := 0
	var scaled := abs_val
	while scaled >= 1000.0 and tier < COMPACT_SUFFIXES_EN.size() - 1:
		scaled /= 1000.0
		tier += 1
	var digits := "%.2f" % scaled if scaled < 10.0 else ("%.1f" % scaled if scaled < 100.0 else "%d" % int(round(scaled)))
	while digits.contains(".") and (digits.ends_with("0") or digits.ends_with(".")):
		digits = digits.substr(0, digits.length() - 1)
		if not digits.contains("."):
			break
	var suffix := COMPACT_SUFFIXES_EN[tier]
	if language == "fa" and tier <= 4:
		var num := to_digits(digits)
		var out_fa := ("%s %s" % [num, COMPACT_SUFFIXES_FA[tier]]).strip_edges()
		return ("-" + out_fa) if negative else out_fa
	var out_en := digits + suffix
	return ("-" + out_en) if negative else out_en


## Short compact badge (always compact K/M/B so narrow pills never overflow).
func format_short(value: float) -> String:
	var abs_val := absf(value)
	if abs_val < 1000.0:
		return to_digits(str(int(round(value))))
	var tier := 0
	var scaled := abs_val
	while scaled >= 1000.0 and tier < COMPACT_SUFFIXES_EN.size() - 1:
		scaled /= 1000.0
		tier += 1
	var digits := "%.1f" % scaled if scaled < 100.0 else "%d" % int(round(scaled))
	if digits.ends_with(".0"):
		digits = digits.substr(0, digits.length() - 2)
	var sign_prefix := "-" if value < 0.0 else ""
	return sign_prefix + to_digits(digits) + COMPACT_SUFFIXES_EN[tier]


func to_digits(text: String) -> String:
	if language != "fa":
		return text
	var converted := ""
	for character in text:
		var index := "0123456789".find(character)
		converted += PERSIAN_DIGITS[index] if index >= 0 else character
	return converted


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
