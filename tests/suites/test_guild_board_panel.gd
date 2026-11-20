extends TestCase
## The board screen: every job listed, a job that can be chosen, a confirm that pays
## the fee and sends the right member, and refusals that say why.
##
## The panel is built and driven without a window, so the layout rule (Persian moves
## no rectangle) is checked by comparing the row rectangles in both languages.

const SEED := 31


func _panel(cash: float = 200.0) -> Array:
	var treasury := GuildTreasury.new()
	treasury.deposit(cash)
	var stock := GuildStock.new(40)
	var desk := GuildMissionDesk.new()
	desk.setup(treasury, stock, SEED)
	desk.hire_default_roster()
	var panel := GuildBoardPanel.new()
	panel.bind(desk)
	return [panel, desk, treasury]


func test_every_job_has_a_row() -> void:
	var parts := _panel()
	var panel: GuildBoardPanel = parts[0]
	equal(panel.rows.size(), GuildMissions.ids().size(), "one row per job")
	equal(panel.row_rects().size(), GuildMissions.ids().size(), "with a rectangle each")
	for index in panel.rows.size():
		check(not panel.rows[index].name.is_empty(), "the row is a real control")
	check(not panel.is_open(), "the panel starts closed")
	panel.open()
	check(panel.is_open(), "and opens")
	panel.free()


func test_choosing_a_job_names_the_member_and_enables_confirm() -> void:
	var parts := _panel()
	var panel: GuildBoardPanel = parts[0]
	panel.open()
	equal(panel.refusal(), "no mission", "nothing can be sent before a job is chosen")
	check(panel.confirm_button.disabled, "so the button is disabled")
	panel.select("ore_run")
	equal(panel.selected_mission(), "ore_run", "the job is chosen")
	var member := panel.candidate()
	check(member != null, "the panel knows who would go")
	if member != null:
		equal(member.class_id, "mage", "the most junior member who can take it")
	check(not GuildMissions.fits_rank("F", "ore_run"), "which is why the F recruits are not sent")
	equal(panel.refusal(), "", "with gold in the vault the dispatch is allowed")
	check(not panel.confirm_button.disabled, "and the button is live")
	panel.free()


func test_confirming_pays_the_fee_and_sends_that_member() -> void:
	var parts := _panel(200.0)
	var panel: GuildBoardPanel = parts[0]
	var desk: GuildMissionDesk = parts[1]
	var treasury: GuildTreasury = parts[2]
	panel.open()
	panel.select("ore_run")
	var result := panel.confirm()
	equal(str(result["reason"]), "", "the dispatch succeeds")
	almost(treasury.cash, 200.0 - 18.0, "the fee left the vault", 0.001)
	equal(desk.active_count(), 1, "one member is out")
	equal(str(result["mission_id"]), "ore_run", "on the chosen mission")
	equal(str(result["class_id"]), "mage", "and it is the member the panel named")
	check(not panel.is_open(), "the panel closes itself after a dispatch")
	panel.free()


func test_a_broke_guild_is_refused_with_a_reason() -> void:
	var parts := _panel(2.0)
	var panel: GuildBoardPanel = parts[0]
	var desk: GuildMissionDesk = parts[1]
	var treasury: GuildTreasury = parts[2]
	panel.open()
	panel.select("relic_dig")
	equal(panel.refusal(), "no gold", "the vault cannot pay for a dig")
	check(panel.status_label.text != "", "and the reason is written on the sheet")
	check(panel.confirm_button.disabled, "the button is disabled")
	var result := panel.confirm()
	equal(str(result["reason"]), "no gold", "confirming anyway changes nothing")
	equal(desk.active_count(), 0, "nobody left")
	almost(treasury.cash, 2.0, "and nothing was spent", 0.001)
	panel.free()


func test_a_roster_that_is_too_green_says_so() -> void:
	var treasury := GuildTreasury.new()
	treasury.deposit(500.0)
	var stock := GuildStock.new(40)
	var desk := GuildMissionDesk.new()
	desk.setup(treasury, stock, SEED)
	desk.hire("warrior", "F")
	desk.hire("archer", "F")
	var panel := GuildBoardPanel.new()
	panel.bind(desk)
	panel.open()
	panel.select("relic_dig")
	equal(panel.refusal(), "rank low", "F-rank recruits cannot take a dig")
	equal(panel.status_label.text, GuildLocale.text("msg.rank_low", "en"), "and the sheet says why")
	panel.select("gather_herbs")
	equal(panel.refusal(), "", "but they can gather herbs")
	panel.free()


func test_persian_rewrites_the_words_and_moves_nothing() -> void:
	var parts := _panel()
	var panel: GuildBoardPanel = parts[0]
	panel.open()
	panel.select("slime_hunt")
	var english_names: Array[String] = []
	for label in panel.get("_name_labels"):
		english_names.append((label as Label).text)
	var english_rects := panel.row_rects()
	var english_sends := panel.send_label.text
	panel.set_language("fa")
	var persian_rects := panel.row_rects()
	equal(persian_rects.size(), english_rects.size(), "the same rows exist")
	for index in english_rects.size():
		equal(persian_rects[index], english_rects[index], "row %d did not move" % index)
	not_equal(panel.title_label.text, GuildLocale.text("mission.board", "en"), "the title is Persian")
	not_equal(panel.send_label.text, english_sends, "and so is the sentence about the member")
	var renamed := 0
	var index := 0
	for label in panel.get("_name_labels"):
		if (label as Label).text != english_names[index]:
			renamed += 1
		index += 1
	equal(renamed, GuildMissions.ids().size(), "every job name is translated")
	panel.free()
