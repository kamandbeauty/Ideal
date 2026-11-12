extends CanvasLayer
## Persian-language HUD per spec section 12. All player-facing strings are
## Persian; node/variable names are English. Make sure the project's default
## theme font is a Persian-capable font (e.g. Vazirmatn) and that each
## Label/RichTextLabel below has text_direction = TEXT_DIRECTION_AUTO (or RTL)
## set in the editor so Godot's TextServer shapes the Persian text correctly.

@export var health_bar_path: NodePath       # TODO: assign in editor
@export var squad_label_path: NodePath      # TODO: assign in editor
@export var ammo_bar_path: NodePath         # TODO: assign in editor
@export var boss_health_bar_path: NodePath  # TODO: assign in editor
@export var notification_label_path: NodePath  # TODO: assign in editor
@export var tutorial_label_path: NodePath   # TODO: assign in editor
@export var end_screen_path: NodePath       # TODO: assign in editor (Control shown on win/lose)
@export var end_title_label_path: NodePath  # TODO: assign in editor
@export var end_stats_label_path: NodePath  # TODO: assign in editor

# Persian UI strings (spec section 12).
const STR_LEVEL_TITLE := "مرحله ۱ – پل آسمانی"
const STR_COINS := "سکه"
const STR_SQUAD := "تعداد نیروها"
const STR_HEALTH := "سلامتی"
const STR_AMMO := "مهمات"
const STR_BOSS := "غول آخر"
const STR_BOSS_WARNING := "خطر! غول عظیم‌الجثه نزدیک می‌شود!"
const STR_MOVE_TUTORIAL := "برای حرکت، انگشت خود را به چپ و راست بکشید."
const STR_GATE_TUTORIAL := "به دروازه موردنظر شلیک کنید!"
const STR_GRENADE := "نارنجک"
const STR_SPECIAL := "قدرت ویژه"
const STR_VICTORY := "مرحله با موفقیت به پایان رسید!"
const STR_DEFEAT := "شکست خوردید!"
const STR_BTN_CONTINUE := "ادامه"
const STR_BTN_RETRY := "تکرار مرحله"
const STR_BTN_MAIN_MENU := "منوی اصلی"
const STR_INTRO_LINE := "برای زنده ماندن بجنگ!"

@onready var _health_bar: ProgressBar = get_node_or_null(health_bar_path)
@onready var _squad_label: Label = get_node_or_null(squad_label_path)
@onready var _ammo_bar: ProgressBar = get_node_or_null(ammo_bar_path)
@onready var _boss_health_bar: ProgressBar = get_node_or_null(boss_health_bar_path)
@onready var _notification_label: Label = get_node_or_null(notification_label_path)
@onready var _tutorial_label: Label = get_node_or_null(tutorial_label_path)
@onready var _end_screen: Control = get_node_or_null(end_screen_path)
@onready var _end_title_label: Label = get_node_or_null(end_title_label_path)
@onready var _end_stats_label: Label = get_node_or_null(end_stats_label_path)

func _ready() -> void:
	if _end_screen:
		_end_screen.visible = false
	if _boss_health_bar:
		_boss_health_bar.visible = false

func show_intro(intro_line: String, tutorial_line: String) -> void:
	if _tutorial_label:
		_tutorial_label.text = intro_line + "\n" + tutorial_line

func show_gate_tutorial() -> void:
	if _tutorial_label:
		_tutorial_label.text = STR_GATE_TUTORIAL

func update_health(current: float, max_health: float) -> void:
	if _health_bar:
		_health_bar.max_value = max_health
		_health_bar.value = current

func update_squad(count: int) -> void:
	if _squad_label:
		_squad_label.text = "%s: %s" % [STR_SQUAD, _to_persian_digits(count)]

func update_ammo_fraction(fraction: float) -> void:
	if _ammo_bar:
		_ammo_bar.value = fraction * _ammo_bar.max_value

func show_boss_warning() -> void:
	if _boss_health_bar:
		_boss_health_bar.visible = true
	_show_notification(STR_BOSS_WARNING)

func update_boss_health(current: float, max_health: float) -> void:
	if _boss_health_bar:
		_boss_health_bar.max_value = max_health
		_boss_health_bar.value = current

func show_kill_notification() -> void:
	# Spec asks for "Persian kill notifications" (section 9, SECTION 2).
	_show_notification("دشمن حذف شد")

func show_victory(stats: Dictionary) -> void:
	if _end_screen:
		_end_screen.visible = true
	if _end_title_label:
		_end_title_label.text = STR_VICTORY
	if _end_stats_label:
		_end_stats_label.text = _format_stats(stats)

func show_defeat() -> void:
	if _end_screen:
		_end_screen.visible = true
	if _end_title_label:
		_end_title_label.text = STR_DEFEAT

func _format_stats(stats: Dictionary) -> String:
	var killed: int = stats.get("zombies_killed", 0)
	var soldiers: int = stats.get("soldiers_remaining", 0)
	var coins: int = stats.get("coins_earned", 0)
	var time_s: float = stats.get("completion_time", 0.0)

	var lines: Array[String] = [
		"زامبی‌های کشته‌شده: %s" % _to_persian_digits(killed),
		"نیروهای باقی‌مانده: %s" % _to_persian_digits(soldiers),
		"%s: %s" % [STR_COINS, _to_persian_digits(coins)],
		"زمان تکمیل: %s ثانیه" % _to_persian_digits(int(time_s)),
	]
	return "\n".join(lines)

func _show_notification(text: String) -> void:
	if _notification_label == null:
		return
	_notification_label.text = text
	_notification_label.visible = true
	await get_tree().create_timer(1.5).timeout
	_notification_label.visible = false

## Converts Western digits to Persian digits for player-facing numbers,
## per spec requirement "Use Persian digits in the player-facing interface."
func _to_persian_digits(value: int) -> String:
	const WESTERN := "0123456789"
	const PERSIAN := "۰۱۲۳۴۵۶۷۸۹"
	var s: String = str(value)
	var result: String = ""
	for ch in s:
		var idx: int = WESTERN.find(ch)
		result += PERSIAN[idx] if idx != -1 else ch
	return result
