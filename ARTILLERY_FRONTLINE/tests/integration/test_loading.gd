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
			var emblem: TextureRect = menus.holder.find_child("LoadingEmblem", true, false)
			t.check(art != null and art.texture != null and emblem != null and emblem.texture != null, "loading art and emblem load")
			t.check(content != null and Rect2(Vector2.ZERO, Vector2(shape)).encloses(content.get_global_rect()), "loading content fits %s in %s" % [shape, language])
			t.near(menus.loading_bar.value, 42.0, 0.01, "progress reflects the resource phase")
			t.equal(menus.loading_status.text, Loc.t("loading_prepare"), "status follows the chosen language")
			menus._show("loading", false)
			t.near(menus.loading_bar.value, 42.0, 0.01, "a screen rebuild preserves progress")
			t.equal(menus.loading_status.text, Loc.t("loading_prepare"), "a screen rebuild preserves the loading phase")
	menus.set_loading_progress(2.0)
	t.near(menus.loading_bar.value, 100.0, 0.01, "progress is clamped at completion")
	menus.show_loading()
	t.near(menus.loading_bar.value, 0.0, 0.01, "the next deployment starts at zero")
	t.equal(menus.loading_status.text, Loc.t("loading_deploy"), "deployment uses its own status")
	menus.queue_free()
	t.tree.root.size = old_size
	Profile.set_setting("language", old_language)
	await t.frames(2)
