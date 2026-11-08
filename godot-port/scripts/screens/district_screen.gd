class_name DistrictScreen
extends UiScreen
## The building screen: every district of the chapter with its tasks, prices and chest.
## Ported from client/Assets/Game/Ui/DistrictScreen.cs.
##
## Potions earned by clearing levels are the only currency that builds the palace, so this screen is
## where the match-3 loop pays off. A task row and the district button call the same session methods
## the tests call, which is why nothing here needs a mock.

signal back_requested

const CARD_HEIGHT := 250.0

var _list: VBoxContainer
var _header: Label
var _potions: Label
var _cards: Array[Panel] = []
var _row_titles: Array[Label] = []
var _row_buttons: Array[Button] = []
var _district_buttons: Array[Button] = []
var _chest_buttons: Array[Button] = []
var _district_titles: Array[Label] = []
var _task_rows: Array[Dictionary] = []

func build() -> void:
	set_backdrop("map_backdrop", 0.42, 0.5, 0.5, 0.90, 0.80)

	UiKit.button(self, "back", "بازگشت", UiTokens.CANVAS_WIDTH - 16.0 - 84.0, 54.0, 84.0, 40.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_back, UiTokens.RADIUS_MD)

	_header = UiKit.label(self, "title", "محله‌های کاخ", UiTokens.TYPE_LG, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(_header, 16.0, 54.0, UiTokens.CANVAS_WIDTH - 32.0, 40.0)

	_potions = UiKit.label(self, "potions", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_potions, 16.0, 96.0, UiTokens.CANVAS_WIDTH - 32.0, 20.0)

	var scroll := ScrollContainer.new()
	scroll.name = "scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	UiKit.place(scroll, 12.0, 120.0, UiTokens.CANVAS_WIDTH - 24.0, 580.0)

	_list = VBoxContainer.new()
	_list.name = "list"
	_list.add_theme_constant_override("separation", 10)
	_list.custom_minimum_size = Vector2(UiTokens.CANVAS_WIDTH - 36.0, 0.0)
	scroll.add_child(_list)

	for index in range(3):
		_build_card(index)

func _build_card(index: int) -> void:
	var card := UiKit.art_panel(_list, "district_%d" % index, 0.0, 0.0, UiTokens.CANVAS_WIDTH - 36.0,
		CARD_HEIGHT, "panel_frame", UiTokens.BORDER_CARD, UiTokens.SURFACE, UiTokens.RADIUS_PANEL)
	card.custom_minimum_size = Vector2(UiTokens.CANVAS_WIDTH - 36.0, CARD_HEIGHT)
	_cards.append(card)

	var title := UiKit.label(card, "title", "", UiTokens.TYPE_BASE, UiTokens.GOLD,
		HORIZONTAL_ALIGNMENT_RIGHT, true)
	UiKit.place(title, 14.0, 6.0, card.custom_minimum_size.x - 28.0, 24.0)
	_district_titles.append(title)

	var rows: Array[Dictionary] = []
	for task_index in range(5):
		var y := 34.0 + float(task_index) * 38.0
		var row := Control.new()
		row.name = "task_%d" % task_index
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		UiKit.place(row, 14.0, y, card.custom_minimum_size.x - 28.0, 34.0)

		var label := UiKit.label(row, "title", "", UiTokens.TYPE_SM, UiTokens.TEXT,
			HORIZONTAL_ALIGNMENT_RIGHT)
		UiKit.place(label, 76.0, 0.0, card.custom_minimum_size.x - 28.0 - 76.0, 34.0)
		_row_titles.append(label)

		var button := UiKit.button(row, "build", "", 0.0, 2.0, 70.0, 30.0, UiTokens.ACCENT,
			UiTokens.ON_ACCENT, Callable(self, "_on_task_pressed").bind(index, task_index),
			UiTokens.RADIUS_SM)
		button.add_theme_font_size_override("font_size", UiTokens.TYPE_XS)
		_row_buttons.append(button)
		rows.append({"label": label, "button": button})
	_task_rows.append({"index": index, "rows": rows})

	var district_button := UiKit.button(card, "build_all", "ساخت همه", 106.0, CARD_HEIGHT - 46.0, 110.0,
		34.0, UiTokens.SURFACE_RAISED, UiTokens.TEXT, Callable(self, "_on_district_pressed").bind(index),
		UiTokens.RADIUS_MD)
	district_button.add_theme_font_size_override("font_size", UiTokens.TYPE_SM)
	_district_buttons.append(district_button)

	var chest_button := UiKit.button(card, "chest", "صندوق", 14.0, CARD_HEIGHT - 46.0, 84.0, 34.0,
		UiTokens.GOLD, UiTokens.ON_GOLD, Callable(self, "_on_chest_pressed").bind(index),
		UiTokens.RADIUS_MD)
	chest_button.add_theme_font_size_override("font_size", UiTokens.TYPE_SM)
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
			button.modulate = Color(1, 1, 1, 1) if not button.disabled else Color(0.6, 0.6, 0.65, 1)

		var built := session.is_district_built(district)
		var remaining := session.remaining_potions(district)
		_district_buttons[index].text = "کامل شد" if built else "ساخت همه (" + PersianText.number(remaining) + ")"
		_district_buttons[index].disabled = built or not session.can_afford(district)
		_district_buttons[index].modulate = Color(1, 1, 1, 1) if not _district_buttons[index].disabled \
			else Color(0.6, 0.6, 0.65, 1)

		var chest_open := session.is_chest_open(district)
		_chest_buttons[index].text = "باز شد" if chest_open else "صندوق"
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
