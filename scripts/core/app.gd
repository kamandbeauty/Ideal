extends Node
## Global app state: language, saved progress, shared theme.
##
## Autoloaded as `App`, so every scene can call `App.t("key")`.

signal language_changed(language: String)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LANGUAGE := "fa"

var language: String = DEFAULT_LANGUAGE
var best_wave: int = 0
var ui_theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	ui_theme = UiTheme.build()


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


func record_waves(waves_survived: int) -> void:
	if waves_survived > best_wave:
		best_wave = waves_survived
		_save_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_language := str(config.get_value("ui", "language", language))
	if L10n.has_language(saved_language):
		language = saved_language
	best_wave = int(config.get_value("progress", "best_wave", 0))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "language", language)
	config.set_value("progress", "best_wave", best_wave)
	config.save(SETTINGS_PATH)
