extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("run")


func expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		failures += 1


func run() -> void:
	await process_frame
	expect(SaveManager.defaults().coins == 0, "save defaults are safe")
	expect(SaveManager.data.unlocked_skins.has("classic"), "classic skin always unlocked")
	expect(SkinManager.skins.size() == 5, "five data-driven skins load")
	expect(not AdManager.is_rewarded_available("revive"), "base build handles unavailable ads")
	expect(
		ComplianceManager.report().permissions.is_empty(),
		"offline base build requests no dangerous/network permissions"
	)
	var original := SaveManager.data.duplicate(true)
	SaveManager.data.coins = 1000
	expect(SkinManager.purchase("red"), "skin purchase works")
	expect(SkinManager.equip("red"), "skin equip works")
	SaveManager.data = original
	SaveManager.save()
	var ruby := RubyPlayer.new()
	root.add_child(ruby)
	ruby.reset_player()
	expect(ruby.jump(), "first jump works")
	expect(ruby.jump(), "double jump works")
	expect(not ruby.jump(), "third jump is blocked")
	ruby.queue_free()
	var valid_events := (
		AnalyticsManager.ALLOWED_EVENTS.has(&"game_started")
		and not AnalyticsManager.ALLOWED_PARAMETERS.has(&"email")
	)
	expect(valid_events, "analytics allowlist excludes personal fields")
	var provider: Node = load("res://tests/mock_ad_provider.gd").new()
	root.add_child(provider)
	set_meta("reward_placement", "")
	AdManager.rewarded_completed.connect(
		func(placement: String): set_meta("reward_placement", placement)
	)
	expect(AdManager.configure_provider(provider), "reviewed ad provider contract connects")
	expect(AdManager.show_rewarded("revive"), "configured rewarded flow starts")
	expect(get_meta("reward_placement") == "revive", "reward requires provider completion callback")
	print("TEST RESULT: ", failures, " failure(s)")
	quit(1 if failures else 0)
