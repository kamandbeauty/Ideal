extends TestCase
## The phone HUD: the facts on the bar, the stick, the action button, and the rule
## that switching to Persian changes words and nothing else.

var _player: GuildPlayer
var _stations: Array = []
var _stock: GuildStock
var _treasury: GuildTreasury
var _interaction: GuildInteraction


func _build_world() -> void:
	_player = GuildPlayer.new()
	_player.ensure_look()
	_stock = GuildStock.new(40)
	_stock.add("slime_gel", 4)
	_treasury = GuildTreasury.new()
	_treasury.deposit(1250.0)
	_stations = []
	var shelf := GuildStation.new(GuildStation.SHELF)
	shelf.position = Vector3(2.0, 0.0, 0.0)
	shelf.bind_stock(_stock)
	_stations.append(shelf)
	var counter := GuildStation.new(GuildStation.COUNTER)
	counter.position = Vector3(-3.0, 0.0, 0.0)
	counter.bind_order(GuildOrder.new("slime_gel", 2))
	_stations.append(counter)
	_interaction = GuildInteraction.new()
	_interaction.setup(_player, _stations, _treasury, _stock)


func _free_world() -> void:
	_player.free()
	_interaction.free()
	for station in _stations:
		(station as GuildStation).free()
	_stations = []


func test_bar_shows_the_real_numbers() -> void:
	_build_world()
	var hud := GuildHud.new()
	hud.bind(_interaction, _treasury, _stock)
	check(hud.gold_label.text.contains("1,250"), "gold is shown with separators: " + hud.gold_label.text)
	check(hud.gold_label.text.contains("Gold"), "and in English by default")
	check(hud.warehouse_label.text.contains("4 / 40"), "the warehouse shows used and capacity")
	almost(hud.warehouse_meter.scale.x, 0.1, "the meter fills to the ratio")
	equal(hud.waiting_customers(), 1, "one customer is waiting")
	check(hud.customers_label.text.contains("1"), "and the bar counts them")
	_treasury.deposit(750.0)
	check(hud.gold_label.text.contains("2,000"), "the bar follows the vault: " + hud.gold_label.text)
	hud.free()
	_free_world()


func test_action_button_follows_the_nearest_station() -> void:
	_build_world()
	var hud := GuildHud.new()
	hud.bind(_interaction, _treasury, _stock)
	hud._refresh_action()
	_player.position = Vector3(40.0, 0.0, 40.0)
	hud._refresh_action()
	check(not hud.action_button.visible, "nothing in reach hides the button")

	_player.position = Vector3(2.4, 0.0, 0.0)
	equal(_interaction.station_near().kind, GuildStation.SHELF, "the shelf is the nearest station")
	hud._refresh_action()
	check(hud.action_button.visible, "the shelf shows the button")
	equal(hud.action_label.text, "Pick up", "with the shelf's verb")

	_player.position = Vector3(-3.2, 0.0, 0.2)
	equal(_interaction.station_near().kind, GuildStation.COUNTER, "the counter is the nearest station now")
	hud._refresh_action()
	equal(hud.action_label.text, "Deliver", "the counter offers delivery")

	hud.set_language("fa")
	equal(hud.action_label.text, "تحویل", "and the verb is translated")
	hud.free()
	_free_world()


func test_persian_changes_words_only() -> void:
	_build_world()
	var hud := GuildHud.new()
	hud.bind(_interaction, _treasury, _stock)
	var before := [
		hud.gold_label.position, hud.reputation_label.position, hud.warehouse_label.position,
		hud.customers_label.position, hud.missions_label.position, hud.action_button.position,
		hud.stick_base.position, hud.stick_knob.position, hud.toast.position,
		hud.warehouse_meter.position, hud.warehouse_meter.scale,
	]
	var english := [hud.gold_label.text, hud.warehouse_label.text, hud.language_button.text]
	hud.set_language("fa")
	var after := [
		hud.gold_label.position, hud.reputation_label.position, hud.warehouse_label.position,
		hud.customers_label.position, hud.missions_label.position, hud.action_button.position,
		hud.stick_base.position, hud.stick_knob.position, hud.toast.position,
		hud.warehouse_meter.position, hud.warehouse_meter.scale,
	]
	equal(after, before, "no control moved when the language changed")
	not_equal(hud.gold_label.text, english[0], "the gold label is Persian now: " + hud.gold_label.text)
	check(hud.gold_label.text.contains("2"), "numbers stay Latin in both languages")
	equal(hud.language_button.text, "FA", "the toggle shows the other language")
	hud.set_language("en")
	equal(hud.gold_label.text, english[0], "and switching back restores English")
	equal(hud.root.layout_direction, Control.LAYOUT_DIRECTION_LTR, "the HUD never mirrors")
	hud.free()
	_free_world()


func test_the_stick_drives_the_player() -> void:
	_build_world()
	var hud := GuildHud.new()
	hud.bind(_interaction, _treasury, _stock)
	hud.set_stick_input(Vector2(0.0, 1.0))
	equal(_player.input_vector, Vector2(0.0, 1.0), "the stick pushes the player forward")
	equal(hud.stick_input(), Vector2(0.0, 1.0), "and remembers where it is")
	check(hud.stick_knob.position.y < (GuildHud.STICK_SIZE * 0.5 - GuildHud.KNOB_SIZE * 0.5), "the knob moved up")
	hud.set_stick_input(Vector2(3.0, 3.0))
	almost(hud.stick_input().length(), 1.0, "the stick never leaves its circle")
	hud.set_stick_input(Vector2.ZERO)
	equal(_player.input_vector, Vector2.ZERO, "releasing stops the player")
	hud.free()
	_free_world()


func test_a_trade_says_what_happened() -> void:
	_build_world()
	var hud := GuildHud.new()
	hud.bind(_interaction, _treasury, _stock)
	_player.position = Vector3(2.2, 0.0, 0.0)
	hud._refresh_action()
	hud._on_action_pressed()
	check(_interaction.last_result.is_empty(), "the trade waits for the verb to finish")
	_player.state.tick(1.0)
	check(not _interaction.last_result.is_empty(), "and lands when the verb finishes")
	check(hud.toast.text.contains("Slime Gel"), "the toast names the goods: " + hud.toast.text)
	check(hud.toast.text.contains("3 x"), "and the count")
	check(hud.toast.modulate.a > 0.9, "the toast is visible")
	hud.set_language("fa")
	hud._on_traded({})
	equal(_interaction.result_message("fa"), "3 x ژل اسلایم برداشته شد", "the same sentence in Persian")
	hud.free()
	_free_world()
