extends RefCounted
## Menu track selection and transitions, without requiring the licensed song in the test tree.

func run(t: TestContext) -> void:
	Profile.persist = false
	Sound.stop_loop("wind")
	Sound.stop_loop("music_theme")
	Sound.stop_loop("teeth_in_the_wire")
	var original: Resource = Sound.clips.get("teeth_in_the_wire")
	t.check(original is AudioStreamMP3, "the supplied menu recording is imported")
	if original is AudioStream:
		t.check((original as AudioStream).get_length() > 120.0, "the full recording is available")
	Sound.clips.erase("teeth_in_the_wire")
	# Reopening the game must clean up even a wind loop left by a prior scene.
	Sound.start_loop("wind", "Effects", -28.0, 0.0)
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(game)
	await t.frames(2)
	t.check(not Sound.is_looping("wind"), "the startup menu has no wind ambience")
	t.check(Sound.is_looping("music_theme"), "menu falls back to the shipped theme when the recording is absent")
	t.check(not Sound.is_looping("teeth_in_the_wire"), "the unavailable recording is not playing")
	game._stop_menu_music()
	# A stand-in exercises the same AudioStream path as an imported recording.
	Sound.clips["teeth_in_the_wire"] = Sound.clips["music_theme"]
	game._start_menu_music()
	t.check(Sound.is_looping("teeth_in_the_wire") and not Sound.is_looping("music_theme"), "the supplied recording is preferred")
	t.equal((Sound.loops["teeth_in_the_wire"] as AudioStreamPlayer).bus, &"Music", "the recording follows the music-volume setting")
	game.start_match()
	t.check(not Sound.is_looping("teeth_in_the_wire"), "starting a match stops the menu track")
	await t.frames(4)
	t.check(Sound.is_looping("wind"), "wind remains available during the match")
	t.equal((Sound.loops["wind"] as AudioStreamPlayer).bus, &"Effects", "gameplay wind follows the effects volume")
	t.near((Sound.loops["wind"] as AudioStreamPlayer).volume_db, -28.0, 0.01, "gameplay wind is quieter")
	game.pause()
	t.check(not Sound.is_looping("wind"), "the pause menu has no wind")
	game.resume()
	t.check(Sound.is_looping("wind"), "resuming restores gameplay wind")
	game.to_menu()
	t.check(not Sound.is_looping("wind"), "returning to the menu stops the wind")
	t.check(Sound.is_looping("teeth_in_the_wire"), "returning to the main menu starts the track again")
	game._stop_menu_music()
	if original != null:
		Sound.clips["teeth_in_the_wire"] = original
	else:
		Sound.clips.erase("teeth_in_the_wire")
	game.queue_free()
	await t.frames(2)
