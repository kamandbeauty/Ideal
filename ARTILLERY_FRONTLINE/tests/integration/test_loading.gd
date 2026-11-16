extends RefCounted
## Loading artwork, progress and translations survive viewport and language changes.

func run(t: TestContext) -> void:
	Profile.persist = false
	var old_size: Vector2i = t.tree.root.size
	var old_language: String = Loc.language
	var menus := Menus.new()
	t.tree.root.add_child(menus)
	for shape: Vector2i in [Vector2i(1440, 810), Vector2i(1800, 810), Vector2i(1440, 1080)]:
		t.tree.root.size = shape
		for language: String in Profile.LANGUAGES:
			Profile.set_setting("language", language)
			menus.inset_override = Vector2(100.0, 0.0)
			menus.show_loading(true)
			menus.set_loading_progress(0.42, "loading_prepare")
			await t.frames(2)
			var content: Control = menus.holder.find_child("LoadingContent", true, false)
			var art: TextureRect = menus.holder.find_child("LoadingArt", true, false)
			var title: Label = menus.holder.find_child("LoadingTitle", true, false)
			t.check(art != null and art.texture != null and title != null, "loading artwork and title load")
			t.check(art.texture.resource_path.ends_with("tehran_loading.jpg"), "startup uses the distinct Tehran defense artwork")
			t.check(content != null and Rect2(Vector2.ZERO, Vector2(shape)).encloses(content.get_global_rect()), "loading content fits %s in %s" % [shape, language])
			t.near(menus.loading_bar.value, 42.0, 0.01, "progress reflects the resource phase")
			t.equal(menus.loading_status.text, Loc.t("loading_prepare"), "status follows the chosen language")
			menus._show("loading", false)
			t.near(menus.loading_bar.value, 42.0, 0.01, "a screen rebuild preserves progress")
			t.equal(menus.loading_status.text, Loc.t("loading_prepare"), "a screen rebuild preserves the loading phase")
			art = menus.holder.find_child("LoadingArt", true, false)
			t.check(art.texture.resource_path.ends_with("tehran_loading.jpg"), "startup artwork survives a rebuild")
	menus.set_loading_progress(2.0)
	t.near(menus.loading_bar.value, 100.0, 0.01, "progress is clamped at completion")
	menus.show_loading()
	t.near(menus.loading_bar.value, 0.0, 0.01, "the next deployment starts at zero")
	t.equal(menus.loading_status.text, Loc.t("loading_deploy"), "deployment uses its own status")
	var deploy_art: TextureRect = menus.holder.find_child("LoadingArt", true, false)
	t.check(deploy_art.texture.resource_path.ends_with("design_battlefield.png"), "deployment retains its separate loading artwork")
	menus.queue_free()
	# A mobile first wave prewarms a bounded opening pool; later wave pools
	# are built incrementally during the director's countdown.
	t.equal(CityLevel.initial_prewarm_count(26, 22, true), 8, "mobile opening prewarm is bounded")
	t.equal(CityLevel.initial_prewarm_count(12, 0, true), 0, "mobile skips types absent from the first wave")
	t.equal(CityLevel.initial_prewarm_count(26, 22, false), 26, "desktop keeps its full prewarm")
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(2)
	t.check(not game.level.visible and game.level.process_mode == Node.PROCESS_MODE_DISABLED, "the opaque menu does not render or process the idle world")
	game.select_stage(6)
	game.start_match()
	t.check(game.transitioning and game.menus.screen == "loading", "deployment exposes a loading screen before preparing the world")
	game.start_match()
	t.check(not game.select_stage(0), "the target cannot change while its scene is loading")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(not t.tree.paused, "losing focus during loading does not pause the transition")
	await t.frames(6)
	t.check(not game.transitioning and game.mode == game.Mode.PLAYING and game.level.stage == 6, "duplicate deploys cannot race and the selected district loads")
	t.check(game.level.visible and game.level.process_mode == Node.PROCESS_MODE_PAUSABLE, "the gameplay world is active and visible")
	game.to_menu()
	t.check(game.transitioning and game.menus.screen == "loading", "returning to the menu has a loading screen too")
	await t.frames(6)
	t.check(not game.transitioning and game.menus.screen == "main" and not game.level.visible, "return finishes on the title with the world idle")
	game.queue_free()
	t.tree.root.size = old_size
	Profile.set_setting("language", old_language)
	await t.frames(2)
