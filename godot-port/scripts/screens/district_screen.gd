class_name DistrictScreen
extends UiScreen
## The building screen: every district of the chapter with its tasks, prices and chest.
## Ported from client/Assets/Game/Ui/DistrictScreen.cs.
##
## Potions earned by clearing levels are the only currency that builds the palace, so this screen is
## where the match-3 loop pays off. A task row and the district button call the same session methods
## the tests call, which is why nothing here needs a mock.

signal back_requested

const CARD_HEIGHT := 286.0
# The card is a painted plaque: its moulding is 18 dp deep, so nothing may be drawn outside this inset.
const EDGE := 18.0
const TITLE_Y := 22.0
const ROW_Y := 46.0
const ROW_PITCH := 38.0
const ACTION_Y := 240.0
const CARD_WIDTH := 232.0
const CARD_GAP := 8.0

var _header: Label
var _potions: Label
var _cards: Array[Panel] = []
var _row_titles: Array[Label] = []
var _row_buttons: Array[Button] = []
var _district_buttons: Array[Button] = []
var _chest_buttons: Array[Button] = []
var _chest_icons: Array[TextureRect] = []
var _chest_labels: Array[Label] = []
var _district_titles: Array[Label] = []
var _plates: Array[TextureRect] = []
var _task_rows: Array[Dictionary] = []

func build() -> void:
	set_backdrop("map_terrace", 0.26, 0.5, 0.5, 0.85, 0.78)

	UiKit.button(self, "back", "بازگشت", UiTokens.CANVAS_WIDTH - 16.0 - 84.0, 46.0, 84.0, 36.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_back, UiTokens.RADIUS_MD)

	_header = UiKit.label(self, "title", "محله‌های کاخ", UiTokens.TYPE_LG, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_header, 16.0, 46.0, UiTokens.CANVAS_WIDTH - 32.0, 36.0)

	_potions = UiKit.label(self, "potions", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_potions, 16.0, 82.0, UiTokens.CANVAS_WIDTH - 32.0, 18.0)

	# Landscape has the width for the three plates side by side, which is the whole point of the screen:
	# a player should see the palace grow as one picture, not as a list.
	for index in range(3):
		_build_card(index)

func _build_card(index: int) -> void:
	var card_x := 12.0 + float(index) * (CARD_WIDTH + CARD_GAP)
	var card := UiKit.art_panel(self, "district_%d" % index, card_x, 106.0, CARD_WIDTH,
		CARD_HEIGHT, "ui_card_tall", 0, UiTokens.SURFACE, UiTokens.RADIUS_PANEL)
	_cards.append(card)

	# The district's own illustration, dimmed to a watermark the way the Unity screen draws it: the art
	# is what tells the player which place they are rebuilding.
	var plate := TextureRect.new()
	plate.name = "plate"
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(plate)
	card.move_child(plate, 0)
	# Inside the moulding, not over it: the painted frame has to stay painted.
	UiKit.place(plate, EDGE, EDGE, CARD_WIDTH - EDGE * 2.0, CARD_HEIGHT - EDGE * 2.0)
	_plates.append(plate)

	# The plate is art, the rows are the game: a wash over the illustration keeps every price readable
	# without hiding the place being rebuilt.
	var veil := UiKit.veil(card, "plate_veil",
		Color(UiTokens.SURFACE.r, UiTokens.SURFACE.g, UiTokens.SURFACE.b, 0.62))
	card.move_child(veil, 1)
	# The wash is for the district illustration; the painted moulding stays clear of it.
	UiKit.place(veil, EDGE, EDGE, CARD_WIDTH - EDGE * 2.0, CARD_HEIGHT - EDGE * 2.0)

	var title := UiKit.label(card, "title", "", UiTokens.TYPE_BASE, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_RIGHT, true)
	UiKit.place(title, EDGE, TITLE_Y, CARD_WIDTH - EDGE * 2.0, 22.0)
	_district_titles.append(title)

	var rows: Array[Dictionary] = []
	for task_index in range(5):
		# 38 dp pitch, 32 dp rows: five of them end at 230 and the two action buttons start at 240, all
		# inside the plaque's inner 18..268.
		var y := ROW_Y + float(task_index) * ROW_PITCH
		var row := Control.new()
		row.name = "task_%d" % task_index
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		UiKit.place(row, EDGE, y, CARD_WIDTH - EDGE * 2.0, 32.0)

		var label := UiKit.label(row, "title", "", UiTokens.TYPE_XS, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_RIGHT)
		UiKit.place(label, 56.0, 0.0, CARD_WIDTH - EDGE * 2.0 - 56.0, 32.0)
		_row_titles.append(label)

		var button := UiKit.button(row, "build", "", 0.0, 0.0, 50.0, 32.0, UiTokens.ACCENT,
			UiTokens.ON_ACCENT, Callable(self, "_on_task_pressed").bind(index, task_index),
			UiTokens.RADIUS_SM)
		button.add_theme_font_size_override("font_size", UiTokens.TYPE_XS)
		_row_buttons.append(button)
		rows.append({"label": label, "button": button})
	_task_rows.append({"index": index, "rows": rows})

	var district_button := UiKit.button(card, "build_all", "ساخت همه", 112.0, ACTION_Y,
		104.0, 28.0, UiTokens.SURFACE_RAISED, UiTokens.TEXT,
		Callable(self, "_on_district_pressed").bind(index), UiTokens.RADIUS_MD)
	district_button.add_theme_font_size_override("font_size", UiTokens.TYPE_XS)
	_district_buttons.append(district_button)

	# Empty button text: the word is drawn by chest_label below, because a Button paints its own text
	# centred and would land it on top of the icon.
	var chest_button := UiKit.button(card, "chest", "", EDGE, ACTION_Y, 96.0, 28.0,
		UiTokens.GOLD, UiTokens.ON_GOLD, Callable(self, "_on_chest_pressed").bind(index),
		UiTokens.RADIUS_MD)
	_chest_icons.append(UiKit.icon(chest_button, "chest_icon", "reward_chest", 5.0, 3.0, 22.0, 22.0))
	var chest_label := UiKit.label(chest_button, "chest_label", "", UiTokens.TYPE_XS, UiTokens.ON_GOLD,
		HORIZONTAL_ALIGNMENT_RIGHT)
	UiKit.place(chest_label, 28.0, 0.0, 96.0 - 32.0, 28.0)
	_chest_labels.append(chest_label)
	_chest_buttons.append(chest_button)

func refresh() -> void:
	if session == null:
		return
	_potions.text = "معجون: " + PersianText.number(session.wallet.potions) + " • محله‌های ساخته‌شده: " \
		+ PersianText.fraction(session.built_districts(), session.districts.size())

	for index in range(_cards.size()):
		var has_district := index < session.districts.size()
		_cards[index].visible = has_district
		if not has_district:
			continue

		var district: Dictionary = session.districts[index]
		_district_titles[index].text = str(district.get("title", ""))
		var tasks: Array = district.get("tasks", [])
		var rows: Array = _task_rows[index]["rows"]
		for task_index in range(rows.size()):
			var row: Dictionary = rows[task_index]
			var label: Label = row["label"]
			var button: Button = row["button"]
			var has_task := task_index < tasks.size()
			label.visible = has_task
			button.visible = has_task
			if not has_task:
				continue
			var task: Dictionary = tasks[task_index]
			var done := session.progression.is_task_complete(str(task.get("key", "")))
			label.text = str(task.get("title", ""))
			label.add_theme_color_override("font_color",
				UiTokens.SUCCESS if done else UiTokens.TEXT)
			button.text = "ساخته شد" if done else PersianText.number(int(task.get("potion_cost", 0)))
			button.disabled = done or not session.wallet.can_afford_potions(int(task.get("potion_cost", 0)))
			button.modulate = Color(1, 1, 1, 1) if not button.disabled else Color(0.76, 0.78, 0.84, 1)

		var built := session.is_district_built(district)
		var remaining := session.remaining_potions(district)
		_district_buttons[index].text = "کامل شد" if built else "ساخت همه (" + PersianText.number(remaining) + ")"
		_district_buttons[index].disabled = built or not session.can_afford(district)
		_district_buttons[index].modulate = Color(1, 1, 1, 1) if not _district_buttons[index].disabled \
			else Color(0.76, 0.78, 0.84, 1)

		var built_now := session.is_district_built(district)
		var district_id := str(district.get("id", "")).replace("-", "_")
		var plate_id := "district_" + district_id + ("_lit" if built_now else "")
		var plate_art := UiKit.texture(plate_id)
		if plate_art == null:
			plate_art = UiKit.texture("district_" + district_id)
		_plates[index].texture = plate_art
		_plates[index].modulate = Color(1, 1, 1, 0.46 if built_now else 0.35)

		var chest_open := session.is_chest_open(district)
		_chest_icons[index].texture = UiKit.texture("reward_chest_open" if chest_open
			else "reward_chest")
		_chest_labels[index].text = "باز شد" if chest_open else "باز کن"
		_chest_buttons[index].disabled = chest_open or not built
		_chest_buttons[index].modulate = Color(1, 1, 1, 1) if not _chest_buttons[index].disabled \
			else Color(0.55, 0.55, 0.6, 1)

func _on_task_pressed(district_index: int, task_index: int) -> void:
	if district_index >= session.districts.size():
		return
	var district: Dictionary = session.districts[district_index]
	var tasks: Array = district.get("tasks", [])
	if task_index >= tasks.size():
		return
	if session.build_task(district, tasks[task_index]):
		SoundDirector.play("reward")
		session.notify_changed()
		refresh()

func _on_district_pressed(district_index: int) -> void:
	if district_index >= session.districts.size():
		return
	if session.build_district(session.districts[district_index]):
		session.notify_changed()
		refresh()

func _on_chest_pressed(district_index: int) -> void:
	if district_index >= session.districts.size():
		return
	if session.open_chest(session.districts[district_index]):
		SoundDirector.play("reward", 1.15)
		Fx.coin_burst(_cards[district_index], Vector2(_cards[district_index].size.x * 0.5, 40.0))
		session.notify_changed()
		refresh()

func _on_back() -> void:
	back_requested.emit()
