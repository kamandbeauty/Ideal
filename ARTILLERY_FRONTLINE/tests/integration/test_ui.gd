extends RefCounted
## Instantiates the real menu/HUD stack and audits visible copy for English.
func run(t: TestContext) -> void:
	var menu := MenuScreens.new()
	t.tree.root.add_child(menu)
	await t.tree.process_frame
	t.check(menu.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Menu root is RTL")
	for id in ["splash", "main", "campaign", "briefing", "arsenal", "upgrades", "settings", "pause", "results"]:
		t.check(menu.screens.has(id), "Menu screen built: " + id)
	var latin := RegEx.new()
	latin.compile("[A-Za-z]")
	for id in ["splash", "main", "campaign", "arsenal", "upgrades", "settings", "pause", "results"]:
		menu.show_screen(id)
		await t.tree.process_frame
		_audit(t, menu, latin, id)
	t.check(_has_texture(menu.screens["main"], UITheme.texture("hero_beach.jpg")), "Home screen uses painted beach key art")
	t.check(_count_buttons(menu.screens["main"]) >= 5, "Home screen exposes image-led command cards")
	t.check(menu.campaign_map.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Campaign map is RTL")
	menu.show_briefing("sr01")
	await t.tree.process_frame
	await t.tree.process_frame
	_audit(t, menu, latin, "briefing")
	t.check(menu.briefing_body.size.x > 900.0, "Briefing copy uses a full-width panel")
	menu.show_results({"success": true, "stars": 3, "accuracy": 100.0, "shots": 2, "objectives": 2, "required": 2, "time": 90.0, "optional": true, "coins": 250, "points": 1, "mission_id": "sr01"})
	await t.tree.process_frame
	_audit(t, menu, latin, "results-success")
	menu.show_results({"success": false, "stars": 0, "accuracy": 0.0, "shots": 0, "objectives": 0, "required": 2, "time": 210.0, "optional": false, "coins": 0, "points": 0, "mission_id": "sr01", "reason": "reason_time"})
	await t.tree.process_frame
	_audit(t, menu, latin, "results-failure")
	menu.free()
	await t.tree.process_frame
	var hud := GameplayHUD.new()
	t.tree.root.add_child(hud)
	await t.tree.process_frame
	t.check(hud.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Artillery HUD is RTL")
	t.equal(hud.fire_button.text, Loc.t("hud_fire"), "Artillery fire button Persian")
	hud.free()
	await t.tree.process_frame
	var coastal := CoastalHUD.new()
	t.tree.root.add_child(coastal)
	await t.tree.process_frame
	t.check(coastal.root.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Coastal HUD is RTL")
	t.check(Loc.is_persian(coastal.auto_check.text), "Coastal auto-fire toggle Persian")
	t.check(Loc.is_persian(coastal.reload_button.text), "Coastal reload button Persian")
	coastal.show_result(true, {"round": 3, "kills": 12, "time": 95.0})
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(coastal.result_panel.visible, "Coastal result panel visible")
	var root_center: Vector2 = coastal.root.get_global_rect().get_center()
	var title_center: Vector2 = coastal.result_title.get_global_rect().get_center()
	t.check(absf(title_center.x - root_center.x) < 60.0, "Coastal result card horizontally centered")
	t.check(title_center.y < root_center.y and title_center.y > root_center.y - 240.0, "Coastal result card not clipped to a corner")
	coastal.set_paused(true)
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(coastal.pause_panel.visible, "Coastal pause panel visible")
	var quality_center: Vector2 = coastal.quality_select.get_global_rect().get_center()
	t.check(absf(quality_center.x - root_center.x) < 80.0, "Coastal pause card horizontally centered")
	coastal.free()
	await t.tree.process_frame


func _audit(t: TestContext, node: Node, latin: RegEx, screen: String) -> void:
	var copy: Array[String] = []
	_collect(node, copy)
	var english: bool = false
	var persian: bool = false
	for text in copy:
		if latin.search(text) != null:
			english = true
		if Loc.is_persian(text):
			persian = true
	t.check(not english, "No English display copy on " + screen)
	t.check(persian, "Persian display copy present on " + screen)


func _collect(node: Node, out: Array[String]) -> void:
	if node is Control and not node.visible:
		return
	if node is OptionButton:
		for index in range(node.get_item_count()):
			out.append(node.get_item_text(index))
	elif node is Button:
		out.append(node.text)
	elif node is Label:
		out.append(node.text)
	for child in node.get_children():
		_collect(child, out)


func _has_texture(node: Node, texture: Texture2D) -> bool:
	if node is TextureRect and node.texture == texture:
		return true
	for child in node.get_children():
		if _has_texture(child, texture):
			return true
	return false


func _count_buttons(node: Node) -> int:
	var count: int = 1 if node is Button else 0
	for child in node.get_children():
		count += _count_buttons(child)
	return count
