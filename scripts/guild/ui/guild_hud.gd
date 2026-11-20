class_name GuildHud
extends CanvasLayer
## The phone HUD: a top bar of facts, a joystick under the left thumb and one
## action button under the right, plus a toast that says what just happened.
##
## Every control is placed with explicit anchors and offsets - no containers - so
## switching the language can never move or resize anything (ADR-002). The layout
## is built once in `build()` and only ever has its text replaced.

signal language_changed(language: String)
## The missions counter doubles as the door to the board: tapping the fact opens the
## screen where the player chooses the job.
signal board_pressed()

const TOP_BAR_HEIGHT := 62.0
const STICK_SIZE := 186.0
const KNOB_SIZE := 72.0
const ACTION_SIZE := 152.0
const MARGIN := 22.0
const VERB_KEYS := {
	"pickup": "action.pick_up",
	"receive": "action.deliver",
	"deliver": "action.deliver",
	"deposit": "action.deposit",
	"dispatch": "action.dispatch",
	"buy_loot": "action.buy_loot",
}


var interaction: GuildInteraction
var treasury: GuildTreasury
var stock: GuildStock
var language := "en"

var root: Control
var gold_label: Label
var reputation_label: Label
var warehouse_label: Label
var customers_label: Label
var missions_label: Label
var action_button: Button
var action_label: Label
var stick_base: Panel
var stick_knob: Panel
var toast: Label
var language_button: Button
var missions_button: Button
var warehouse_meter: ColorRect

var _toast_left := 0.0
var _stick_pointer := -1
var _stick_touch_origin := Vector2.ZERO
var _stick_input := Vector2.ZERO
var _shown_verb := ""
var _shown_customers := -1
var _shown_missions := -1


func _init() -> void:
	name = "GuildHud"
	layer = 5
	build()


func _ready() -> void:
	refresh()


## Builds the whole interface once. Public so a suite can build it headlessly.
func build() -> void:
	if root != null:
		return
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.layout_direction = GuildLocale.layout_direction()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top_bar()
	_build_joystick()
	_build_action()
	_build_toast()
	refresh()


func bind(new_interaction: GuildInteraction, new_treasury: GuildTreasury, new_stock: GuildStock) -> void:
	interaction = new_interaction
	treasury = new_treasury
	stock = new_stock
	if interaction != null and not interaction.traded.is_connected(_on_traded):
		interaction.traded.connect(_on_traded)
	if treasury != null and not treasury.changed.is_connected(refresh):
		treasury.changed.connect(refresh)
	if stock != null and not stock.changed.is_connected(refresh):
		stock.changed.connect(refresh)
	refresh()


## Left/right language switch. Only words change: every rect stays where it was.
func toggle_language() -> void:
	set_language("fa" if language == "en" else "en")


func set_language(new_language: String) -> void:
	language = "fa" if new_language == "fa" else "en"
	refresh()
	language_changed.emit(language)


func refresh() -> void:
	if gold_label == null:
		return
	gold_label.text = "%s %s" % [
		GuildLocale.t("hud.gold", [], language),
		GuildLocale.format_money(treasury.cash if treasury != null else 0.0),
	]
	reputation_label.text = "%s %s" % [
		GuildLocale.t("hud.reputation", [], language),
		GuildLocale.format_number(treasury.reputation if treasury != null else 0.0),
	]
	var used := stock.total() if stock != null else 0
	var capacity := stock.capacity if stock != null else 0
	warehouse_label.text = "%s %s" % [
		GuildLocale.t("hud.warehouse", [], language),
		GuildLocale.t("hud.warehouse_value", [str(used), str(capacity)], language),
	]
	if warehouse_meter != null:
		var ratio := float(used) / float(maxi(capacity, 1))
		warehouse_meter.scale.x = clampf(ratio, 0.0, 1.0)
	customers_label.text = "%s %d" % [
		GuildLocale.t("hud.customers", [], language),
		waiting_customers(),
	]
	missions_label.text = "%s %d" % [GuildLocale.t("hud.missions", [], language), missions_active()]
	if language_button != null:
		language_button.text = "EN" if language == "en" else "FA"
	_refresh_action()


## How many adventurers are out right now, read from the board's desk.
func missions_active() -> int:
	if interaction == null:
		return 0
	return interaction.missions_active()


func waiting_customers() -> int:
	if interaction == null:
		return 0
	var total := 0
	for station in interaction.stations:
		var counter := station as GuildStation
		if counter != null and counter.kind == GuildStation.COUNTER and counter.order != null:
			if counter.order.is_ready():
				total += 1
	return total


## The action button shows the verb the nearest station offers, or hides.
func _refresh_action() -> void:
	if action_button == null:
		return
	var verb := interaction.verb_available() if interaction != null else ""
	action_button.visible = not verb.is_empty()
	if verb.is_empty():
		_shown_verb = ""
		return
	var prompt := interaction.prompt(language)
	if prompt.is_empty():
		prompt = GuildLocale.t(str(VERB_KEYS.get(verb, "action.pick_up")), [], language)
	var stamp := verb + "|" + language
	if stamp == _shown_verb and action_label.text == prompt:
		return
	_shown_verb = stamp
	action_label.text = prompt


func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = 14.0
	bar.offset_bottom = 14.0 + TOP_BAR_HEIGHT
	bar.add_theme_stylebox_override("panel", GuildTheme.panel_style(GuildTheme.PANEL, 18))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	gold_label = _place(bar, "Gold", 22.0, 5.0, 24)
	gold_label.add_theme_color_override("font_color", GuildTheme.GOLD)
	reputation_label = _place(bar, "Reputation", 196.0, 8.0, 17)
	reputation_label.add_theme_color_override("font_color", GuildTheme.TURQUOISE)
	warehouse_label = _place(bar, "Warehouse", 360.0, 5.0, 17)
	missions_label = _place(bar, "Missions", 540.0, 8.0, 15)
	missions_label.add_theme_color_override("font_color", GuildTheme.MUTED)
	# A flat button laid exactly over the missions fact, so the counter is the way in
	# to the board without a seventeenth control on a phone screen.
	missions_button = Button.new()
	missions_button.name = "MissionsButton"
	missions_button.flat = true
	missions_button.focus_mode = Control.FOCUS_NONE
	missions_button.position = Vector2(536.0, 2.0)
	missions_button.size = Vector2(136.0, 32.0)
	missions_button.pressed.connect(func() -> void: board_pressed.emit())
	bar.add_child(missions_button)
	customers_label = _place(bar, "Customers", 680.0, 8.0, 15)
	customers_label.add_theme_color_override("font_color", GuildTheme.MUTED)

	warehouse_meter = ColorRect.new()
	warehouse_meter.name = "WarehouseMeter"
	warehouse_meter.color = GuildTheme.TURQUOISE
	warehouse_meter.position = Vector2(360.0, 30.0)
	warehouse_meter.size = Vector2(160.0, 4.0)
	warehouse_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warehouse_meter.pivot_offset = Vector2.ZERO
	bar.add_child(warehouse_meter)

	language_button = Button.new()
	language_button.name = "Language"
	language_button.text = "EN"
	language_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	language_button.offset_left = -96.0
	language_button.offset_right = -20.0
	language_button.offset_top = 12.0
	language_button.offset_bottom = 56.0
	language_button.add_theme_stylebox_override("normal", GuildTheme.panel_style(GuildTheme.PANEL_SOFT, 14))
	language_button.pressed.connect(toggle_language)
	bar.add_child(language_button)


func _build_joystick() -> void:
	stick_base = Panel.new()
	stick_base.name = "Stick"
	stick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick_base.offset_left = MARGIN
	stick_base.offset_right = MARGIN + STICK_SIZE
	stick_base.offset_top = -(MARGIN + STICK_SIZE)
	stick_base.offset_bottom = -MARGIN
	stick_base.add_theme_stylebox_override("panel", GuildTheme.panel_style(GuildTheme.PANEL_SOFT, int(STICK_SIZE * 0.5)))
	stick_base.gui_input.connect(_on_stick_input)
	root.add_child(stick_base)

	stick_knob = Panel.new()
	stick_knob.name = "Knob"
	stick_knob.size = Vector2(KNOB_SIZE, KNOB_SIZE)
	stick_knob.position = (Vector2(STICK_SIZE, STICK_SIZE) - Vector2(KNOB_SIZE, KNOB_SIZE)) * 0.5
	stick_knob.add_theme_stylebox_override("panel", GuildTheme.action_style(GuildTheme.VIOLET, int(KNOB_SIZE * 0.5)))
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_base.add_child(stick_knob)


func _build_action() -> void:
	action_button = Button.new()
	action_button.name = "Action"
	action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.offset_left = -(MARGIN + ACTION_SIZE)
	action_button.offset_right = -MARGIN
	action_button.offset_top = -(MARGIN + ACTION_SIZE)
	action_button.offset_bottom = -MARGIN
	action_button.add_theme_stylebox_override("normal", GuildTheme.action_style(GuildTheme.TURQUOISE.darkened(0.62)))
	action_button.add_theme_stylebox_override("hover", GuildTheme.action_style(GuildTheme.TURQUOISE.darkened(0.5)))
	action_button.add_theme_stylebox_override("pressed", GuildTheme.action_style(GuildTheme.TURQUOISE.darkened(0.72)))
	action_button.pressed.connect(_on_action_pressed)
	root.add_child(action_button)

	action_label = Label.new()
	action_label.name = "ActionLabel"
	action_label.text = ""
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	action_label.add_theme_font_size_override("font_size", 19)
	action_label.add_theme_color_override("font_color", GuildTheme.TEXT)
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_button.add_child(action_label)


func _build_toast() -> void:
	toast = GuildTheme.label("", 17, GuildTheme.TEXT)
	toast.name = "Toast"
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.offset_left = -300.0
	toast.offset_right = 300.0
	toast.offset_top = -(MARGIN + ACTION_SIZE + 66.0)
	toast.offset_bottom = -(MARGIN + ACTION_SIZE + 30.0)
	toast.modulate.a = 0.0
	root.add_child(toast)


func _place(parent: Control, label_text: String, x: float, y: float, size: int) -> Label:
	var node := GuildTheme.label(label_text, size)
	node.position = Vector2(x, y)
	node.size = Vector2(210.0, 26.0)
	parent.add_child(node)
	return node


# --- input -----------------------------------------------------------------

func _on_stick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _stick_pointer < 0:
			_stick_pointer = touch.index
			_stick_touch_origin = touch.position
			_apply_stick(Vector2.ZERO)
		elif not touch.pressed and touch.index == _stick_pointer:
			_stick_pointer = -1
			_apply_stick(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_pointer:
			_apply_stick(_from_screen(drag.position - _stick_touch_origin) / (STICK_SIZE * 0.35))
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_stick_touch_origin = button.position
				_apply_stick(Vector2.ZERO)
			else:
				_apply_stick(Vector2.ZERO)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_apply_stick(_from_screen(motion.position - _stick_touch_origin) / (STICK_SIZE * 0.35))


## Pushes the stick from code: the suite and the play-through use the same path a
## thumb does.
func set_stick_input(direction: Vector2) -> void:
	_apply_stick(direction)


func stick_input() -> Vector2:
	return _stick_input


## `direction` is a game direction: x right, y forward. The knob is drawn with the
## screen's Y pointing down, so pushing forward moves the knob up.
func _apply_stick(direction: Vector2) -> void:
	_stick_input = direction.limit_length(1.0)
	if interaction != null and interaction.player != null:
		interaction.player.set_input(_stick_input)
	if stick_knob != null:
		var travel := STICK_SIZE * 0.5 - KNOB_SIZE * 0.5
		var center := Vector2(STICK_SIZE, STICK_SIZE) * 0.5 - Vector2(KNOB_SIZE, KNOB_SIZE) * 0.5
		stick_knob.position = center + Vector2(_stick_input.x, -_stick_input.y) * travel


func _from_screen(delta: Vector2) -> Vector2:
	return Vector2(delta.x, -delta.y)


func _on_action_pressed() -> void:
	if interaction == null:
		return
	interaction.press()
	_refresh_action()


func _on_traded(_result: Dictionary) -> void:
	refresh()
	var message := interaction.result_message(language)
	if message.is_empty():
		return
	toast.text = message
	toast.modulate.a = 1.0
	_toast_left = 3.0


func _process(delta: float) -> void:
	var waiting := waiting_customers()
	var missions := missions_active()
	if waiting != _shown_customers or missions != _shown_missions:
		_shown_customers = waiting
		_shown_missions = missions
		refresh()
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.6:
			toast.modulate.a = clampf(_toast_left / 0.6, 0.0, 1.0)
	_refresh_action()
