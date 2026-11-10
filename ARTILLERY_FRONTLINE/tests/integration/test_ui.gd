extends RefCounted
## Instantiates the real menu/HUD stack and audits visible copy for English.
func run(t: TestContext) -> void:
	var menu := MenuScreens.new()
	t.tree.root.add_child(menu)
	await t.tree.process_frame
	t.check(menu.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Menu root is RTL")
	for id in ["splash", "main", "campaign", "briefing", "arsenal", "upgrades", "settings", "pause", "results"]:
		t.check(menu.screens.has(id), "Menu screen built: " + id)
	# Regression: settling motion for a control that was freed mid-entrance must not raise a script error.
	var stale := Button.new()
	menu.add_child(stale)
	var stale_settle: Callable = MenuMotion.snap.bind(stale)
	stale.free()
	t.check(not MenuMotion.target_alive(stale_settle), "Freed control is not settled")
	var live := Button.new()
	menu.add_child(live)
	t.check(MenuMotion.target_alive(MenuMotion.snap.bind(live)), "Live control is settled")
	live.free()
	var spent_tween: Tween = menu.create_tween()
	spent_tween.kill()
	menu._motion.append([spent_tween, stale_settle])
	menu.settle()
	t.check(menu._motion.is_empty(), "Settling clears the motion list after a freed control")
	var latin := RegEx.new()
	latin.compile("[A-Za-z]")
	for id in ["splash", "main", "campaign", "arsenal", "upgrades", "settings", "pause", "results"]:
		menu.show_screen(id)
		await t.tree.process_frame
		_audit(t, menu, latin, id)
	menu.show_screen("campaign")
	t.check(menu.is_animating(), "Menu pages animate in")
	menu.settle()
	t.check(not menu.is_animating(), "Settling ends every running menu tween")
	t.check(is_equal_approx(menu.screens["campaign"].modulate.a, 1.0), "Settled menu page is fully opaque")
	t.check(menu.screens["main"].get_child(0) is ColorRect and is_equal_approx((menu.screens["main"].get_child(0) as ColorRect).color.a, 1.0), "Animated home keeps its opaque backdrop")
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
	var viewport_rect: Rect2 = t.tree.root.get_visible_rect()
	t.check(hud.fire_button.get_global_rect().get_center().x > viewport_rect.get_center().x, "Artillery fire button stays on the physical right under RTL")
	t.check(hud.reload_button.get_global_rect().get_center().x > viewport_rect.get_center().x, "Artillery reload stays beside the right-hand fire button")
	t.check(not hud.fire_button.get_global_rect().intersects(hud.reload_button.get_global_rect()), "Artillery fire and reload controls do not overlap")
	t.check(not hud.fire_button.get_global_rect().intersects(hud.camera_button.get_global_rect()), "Artillery fire and camera controls do not overlap")
	hud.free()
	await t.tree.process_frame
	var coastal := CoastalHUD.new()
	t.tree.root.add_child(coastal)
	await t.tree.process_frame
	t.check(coastal.root.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Coastal HUD is RTL")
	t.check(coastal.fire_button.get_global_rect().get_center().x > viewport_rect.get_center().x, "Coastal fire button stays on the physical right under RTL")
	t.check(coastal.weapon_button.get_global_rect().get_center().x > viewport_rect.get_center().x, "Coastal weapon switch stays in the right-hand column")
	t.check(coastal.fire_button.get_global_rect().get_center().y < coastal.health_bar.get_global_rect().position.y, "Coastal fire column clears the bottom health panel")
	t.equal(CoastalHUD.DEFAULT_HEALTH, CoastalController.MAX_HEALTH, "Coastal HUD default matches the hardened emplacement")
	t.check(Loc.is_persian(coastal.auto_check.text), "Coastal auto-fire toggle Persian")
	t.check(Loc.is_persian(coastal.reload_button.text), "Coastal reload button Persian")
	coastal.show_result(true, {"round": 3, "kills": 12, "time": 95.0})
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(coastal.result_panel.visible, "Coastal result panel visible")
	t.check(coastal.result_panel.get_parent() == coastal.page_root, "Coastal results escape the safe-area-inset HUD root")
	t.check(coastal.result_panel.get_global_rect().is_equal_approx(viewport_rect), "Coastal results cover the full viewport")
	t.check(coastal.result_panel.get_child(0) is ColorRect and is_equal_approx((coastal.result_panel.get_child(0) as ColorRect).color.a, 1.0), "Coastal results have an opaque full-screen backdrop")
	var root_center: Vector2 = coastal.root.get_global_rect().get_center()
	var title_center: Vector2 = coastal.result_title.get_global_rect().get_center()
	t.check(absf(title_center.x - root_center.x) < 60.0, "Coastal result card horizontally centered")
	t.check(title_center.y < root_center.y and title_center.y > root_center.y - 240.0, "Coastal result card not clipped to a corner")
	coastal.set_paused(true)
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(coastal.pause_panel.visible, "Coastal pause panel visible")
	t.check(coastal.pause_panel.get_parent() == coastal.page_root, "Coastal pause escapes the safe-area-inset HUD root")
	t.check(coastal.pause_panel.get_global_rect().is_equal_approx(viewport_rect), "Coastal pause covers the full viewport")
	var quality_center: Vector2 = coastal.quality_select.get_global_rect().get_center()
	t.check(absf(quality_center.x - root_center.x) < 80.0, "Coastal pause card horizontally centered")
	coastal.free()
	await t.tree.process_frame
	await _check_application_flow(t)


func _check_application_flow(t: TestContext) -> void:
	var app: Node = load("res://scenes/core/main.tscn").instantiate()
	t.tree.root.add_child(app)
	await t.tree.process_frame
	await t.tree.process_frame
	var viewport_rect: Rect2 = t.tree.root.get_visible_rect()
	t.check(app.menu_layer.layer > app.interface.layer, "Menus render above the gameplay interface")
	t.check(app.menu_root.get_global_rect().is_equal_approx(viewport_rect), "Dedicated menu root is full-bleed")
	t.check(app.menus.get_global_rect().is_equal_approx(viewport_rect), "Menu pages are not confined to the safe area")
	t.check(not app.world.visible, "Command menus hide the old 3D battlefield")
	for id in app.menus.screens:
		var page: Control = app.menus.screens[id]
		t.check(page.get_child(0) is ColorRect and is_equal_approx((page.get_child(0) as ColorRect).color.a, 1.0), "Menu has an opaque backdrop: " + id)
	app.start_mission("sr01")
	await t.tree.process_frame
	t.check(app.world.visible and not app.menus.visible and app.hud.visible, "Deploying restores the battlefield and gameplay HUD")
	app.pause_game()
	await t.tree.process_frame
	t.check(not app.world.visible and not app.hud.visible and app.menus.visible, "Pause hides the old battlefield and HUD")
	t.check(app.menus.screens["pause"].get_global_rect().is_equal_approx(viewport_rect), "Artillery pause is full-screen")
	app.resume_game()
	await t.tree.process_frame
	t.check(app.world.visible and app.hud.visible and not app.menus.visible, "Resume restores combat without a stale menu")
	app.return_to_command()
	await t.tree.process_frame
	t.check(not app.world.visible and app.menus.current == "main", "Returning to command leaves no battlefield rendering underneath")
	app.free()
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
