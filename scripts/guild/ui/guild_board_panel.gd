class_name GuildBoardPanel
extends CanvasLayer
## The mission board as a screen: every job with its rank, fee, duration and loot,
## a chosen job, and the member the guild will actually send.
##
## Same rules as the HUD (ADR-002): explicit anchors and offsets, no containers, so
## switching to Persian rewrites words and moves nothing. The panel is the only place
## the player chooses a job; the one-button board stays for a quick dispatch.

signal opened()
signal closed()
signal dispatched(result: Dictionary)

## Tall enough that the four rows, the sentence about the member and the confirm
## button never share a line: the first draft at 470 overlapped row four.
const SHEET_SIZE := Vector2(760.0, 586.0)
const ROW_HEIGHT := 86.0
const ROW_GAP := 8.0
const PAD := 26.0

var desk: GuildMissionDesk
var language := "en"
var selected := ""
var rows: Array[Button] = []
var row_panels: Array[Panel] = []
var sheet: Panel
var title_label: Label
var hint_label: Label
var status_label: Label
var send_label: Label
var confirm_button: Button
var close_button: Button
var scrim: ColorRect

var _name_labels: Array[Label] = []
var _detail_labels: Array[Label] = []
var _meta_labels: Array[Label] = []


func _init() -> void:
	name = "GuildBoardPanel"
	layer = 6
	build()
	visible = false


func bind(mission_desk: GuildMissionDesk) -> void:
	desk = mission_desk
	if desk != null and not desk.changed.is_connected(_on_desk_changed):
		desk.changed.connect(_on_desk_changed)
	refresh()


func build() -> void:
	if sheet != null:
		return
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.04, 0.03, 0.09, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	sheet = Panel.new()
	sheet.name = "Sheet"
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.size = SHEET_SIZE
	sheet.pivot_offset = SHEET_SIZE * 0.5
	sheet.position = -SHEET_SIZE * 0.5
	sheet.add_theme_stylebox_override("panel", GuildTheme.panel_style(GuildTheme.PANEL, 18))
	add_child(sheet)

	title_label = GuildTheme.label("Mission board", 22, GuildTheme.TEXT)
	title_label.name = "Title"
	title_label.position = Vector2(PAD, PAD - 8.0)
	title_label.size = Vector2(SHEET_SIZE.x - 220.0, 30.0)
	sheet.add_child(title_label)

	close_button = _button("Close")
	close_button.text = "Close"
	close_button.size = Vector2(96.0, 34.0)
	close_button.position = Vector2(SHEET_SIZE.x - PAD - 96.0, PAD - 10.0)
	close_button.pressed.connect(close)
	sheet.add_child(close_button)

	for index in GuildMissions.ids().size():
		_build_row(index)

	hint_label = GuildTheme.label("", 14, GuildTheme.MUTED)
	hint_label.name = "Hint"
	hint_label.position = Vector2(PAD, SHEET_SIZE.y - 146.0)
	hint_label.size = Vector2(SHEET_SIZE.x - PAD * 2.0, 22.0)
	sheet.add_child(hint_label)

	send_label = GuildTheme.label("", 15, GuildTheme.TURQUOISE)
	send_label.name = "Sends"
	send_label.position = Vector2(PAD, SHEET_SIZE.y - 120.0)
	send_label.size = Vector2(SHEET_SIZE.x - PAD * 2.0, 22.0)
	sheet.add_child(send_label)

	status_label = GuildTheme.label("", 14, GuildTheme.DANGER)
	status_label.name = "Status"
	status_label.position = Vector2(PAD, SHEET_SIZE.y - 92.0)
	status_label.size = Vector2(SHEET_SIZE.x - PAD * 2.0 - 200.0, 22.0)
	sheet.add_child(status_label)

	confirm_button = _button("Confirm")
	confirm_button.text = "Dispatch"
	confirm_button.size = Vector2(200.0, 52.0)
	confirm_button.position = Vector2(SHEET_SIZE.x - PAD - 200.0, SHEET_SIZE.y - 106.0)
	confirm_button.pressed.connect(confirm)
	sheet.add_child(confirm_button)


## A flat sheet button in the guild's palette: the panel has no room for the round
## action button, but it keeps the same ink-and-trim look.
func _button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", GuildTheme.action_style(GuildTheme.TURQUOISE.darkened(0.55), 12))
	button.add_theme_stylebox_override("hover", GuildTheme.action_style(GuildTheme.TURQUOISE.darkened(0.35), 12))
	button.add_theme_stylebox_override("pressed", GuildTheme.action_style(GuildTheme.TURQUOISE.darkened(0.65), 12))
	button.add_theme_stylebox_override("disabled", GuildTheme.action_style(GuildTheme.PANEL_SOFT, 12))
	button.add_theme_color_override("font_color", GuildTheme.TEXT)
	button.add_theme_color_override("font_disabled_color", GuildTheme.MUTED)
	return button


func _build_row(index: int) -> void:
	var top := PAD + 34.0 + index * (ROW_HEIGHT + ROW_GAP)
	var panel := Panel.new()
	panel.name = "Row_%d" % index
	panel.position = Vector2(PAD, top)
	panel.size = Vector2(SHEET_SIZE.x - PAD * 2.0, ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", GuildTheme.panel_style(GuildTheme.PANEL_SOFT, 12))
	sheet.add_child(panel)
	row_panels.append(panel)

	var name_label := GuildTheme.label("", 19, GuildTheme.TEXT)
	name_label.position = Vector2(18.0, 12.0)
	name_label.size = Vector2(330.0, 26.0)
	panel.add_child(name_label)
	_name_labels.append(name_label)

	var detail_label := GuildTheme.label("", 13, GuildTheme.MUTED)
	detail_label.position = Vector2(18.0, 44.0)
	detail_label.size = Vector2(430.0, 22.0)
	panel.add_child(detail_label)
	_detail_labels.append(detail_label)

	var meta_label := GuildTheme.label("", 15, GuildTheme.GOLD)
	meta_label.position = Vector2(panel.size.x - 216.0, 30.0)
	meta_label.size = Vector2(200.0, 24.0)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(meta_label)
	_meta_labels.append(meta_label)

	var button := Button.new()
	button.name = "Pick_%d" % index
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.size = panel.size
	button.pressed.connect(select.bind(GuildMissions.ids()[index]))
	panel.add_child(button)
	rows.append(button)


# --- state -----------------------------------------------------------------

func open() -> void:
	selected = ""
	visible = true
	refresh()
	opened.emit()


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func select(mission_id: String) -> void:
	if not GuildMissions.exists(mission_id):
		return
	selected = mission_id
	refresh()


func selected_mission() -> String:
	return selected


## Who the guild would send for the chosen job: the most junior member who can take
## it, so veterans are kept for the digs.
func candidate() -> GuildAdventurer:
	if desk == null or selected.is_empty():
		return null
	return desk.next_free_for(selected)


## Why the confirm button cannot work right now, as one word ("" when it can).
func refusal() -> String:
	if desk == null:
		return "no desk"
	if selected.is_empty():
		return "no mission"
	var member := candidate()
	if member != null:
		return desk.dispatch_reason(member, selected)
	if desk.idle_count() == 0:
		return "busy"
	return "rank low"


func confirm() -> Dictionary:
	var result := {"verb": "dispatch", "amount": 0.0, "reason": refusal()}
	if str(result["reason"]).is_empty():
		result = desk.dispatch_with(candidate(), selected)
	dispatched.emit(result)
	if str(result.get("reason", "")).is_empty():
		close()
	refresh()
	return result


## The row rectangles, so a suite can prove the language never moves them.
func row_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for panel in row_panels:
		found.append(Rect2(panel.position, panel.size))
	return found


# --- drawing ---------------------------------------------------------------

func set_language(new_language: String) -> void:
	language = "fa" if new_language == "fa" else "en"
	refresh()


func refresh() -> void:
	if sheet == null:
		return
	var ids := GuildMissions.ids()
	title_label.text = GuildLocale.t("mission.board", [], language)
	close_button.text = GuildLocale.t("action.close", [], language)
	confirm_button.text = GuildLocale.t("action.dispatch", [], language)
	for index in ids.size():
		_paint_row(index, ids[index])
	_paint_footer()


func _paint_row(index: int, mission_id: String) -> void:
	var data := GuildMissions.mission(mission_id)
	_name_labels[index].text = GuildLocale.t(GuildMissions.name_key(mission_id), [], language)
	_detail_labels[index].text = GuildLocale.t("board.loot", [_loot_text(mission_id)], language)
	_meta_labels[index].text = "%s %s  |  %s  |  %s" % [
		GuildLocale.t("board.rank", [], language),
		str(data.get("rank", "F")),
		GuildLocale.t("board.fee", [GuildLocale.format_money(float(data.get("fee", 0.0)))], language),
		GuildLocale.t("board.time", ["%d" % int(float(data.get("duration", 0.0)))], language),
	]
	var chosen := mission_id == selected
	var color := GuildTheme.PANEL_SOFT.lightened(0.12) if chosen else GuildTheme.PANEL_SOFT
	row_panels[index].add_theme_stylebox_override("panel", GuildTheme.panel_style(color, 12))
	var ink := GuildTheme.TEXT if chosen else GuildTheme.MUTED.lightened(0.3)
	_name_labels[index].add_theme_color_override("font_color", ink)


func _paint_footer() -> void:
	if selected.is_empty():
		hint_label.text = GuildLocale.t("board.choose", [], language)
		send_label.text = ""
		status_label.text = ""
		confirm_button.disabled = true
		return
	var member := candidate()
	hint_label.text = ""
	var who := "?"
	if member != null:
		who = "%s %s" % [
			GuildLocale.t("customer." + member.class_id, [], language),
			member.rank,
		]
	send_label.text = GuildLocale.t("board.sends", [who], language)
	var reason := refusal()
	status_label.text = "" if reason.is_empty() else _reason_text(reason)
	confirm_button.disabled = not reason.is_empty()


func _reason_text(reason: String) -> String:
	match reason:
		"rank low":
			return GuildLocale.t("msg.rank_low", [], language)
		"no gold":
			return GuildLocale.t("msg.no_gold", [], language)
		"busy":
			return GuildLocale.t("msg.no_adventurer", [], language)
		_:
			return GuildLocale.t("msg.no_adventurer", [], language)


func _loot_text(mission_id: String) -> String:
	var parts: Array[String] = []
	for entry in GuildMissions.mission(mission_id).get("loot", []):
		var row := entry as Dictionary
		var item := GuildLocale.t(GuildItems.name_key(str(row.get("item", ""))), [], language)
		parts.append("%s x%d-%d" % [item, int(row.get("min", 1)), int(row.get("max", 1))])
	return ", ".join(parts)


func _on_desk_changed() -> void:
	refresh()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
