extends TestCase
## The player's hands, verbs and camera. These are the rules the carrying loop
## stands on, so they are pinned before any of it is drawn on screen.
##
## `GuildPlayer` itself is a `CharacterBody3D` and is only checked for structure
## here; the movement maths is exercised through its constants and the camera.


func test_items_respect_capacity() -> void:
	var state := GuildPlayerState.new()
	equal(state.carry, 0, "empty hands")
	equal(state.space_for_items(), 6, "carry capacity is the hand size")
	check(state.can_carry(6), "six items fit")
	check(not state.can_carry(7), "seven do not")
	equal(state.take_items(4), 4, "four items taken")
	equal(state.carry, 4, "the hands remember")
	equal(state.take_items(5), 2, "only the remaining space is filled")
	equal(state.carry, 6, "the hands are full")
	check(state.is_hands_full(), "a full stack is reported")
	equal(state.give_items(2), 2, "two items handed over")
	equal(state.carry, 4, "four left")
	equal(state.give_items(99), 4, "cannot give what is not there")
	equal(state.carry, 0, "empty again")


func test_money_is_a_second_pair_of_hands() -> void:
	var state := GuildPlayerState.new()
	state.money_capacity = 500.0
	equal(state.load_money(400.0), 400.0, "coins accepted")
	equal(state.load_money(400.0), 100.0, "the rest is capped by the coin pouch")
	check(state.is_money_full(), "the pouch reports full")
	equal(state.money, 500.0, "the pouch holds 500")
	equal(state.unload_money(), 500.0, "everything is deposited")
	equal(state.money, 0.0, "and the hands are empty")


func test_verbs_take_time_and_block_again() -> void:
	var state := GuildPlayerState.new()
	check(state.start_verb("pickup"), "picking up starts")
	check(state.is_busy(), "the player is busy")
	check(not state.start_verb("deliver"), "a second verb cannot start mid-pickup")
	state.tick(0.2)
	check(state.is_busy(), "still busy after 0.2s")
	state.tick(0.3)
	check(not state.is_busy(), "0.45s finishes the pickup")
	check(state.start_verb("deliver"), "the next verb can start")
	check(not state.start_verb("fly"), "unknown verbs are refused")


func test_signals_report_the_loop() -> void:
	var state := GuildPlayerState.new()
	var started: Array[String] = []
	var finished: Array[String] = []
	var refusals: Array[String] = []
	state.verb_started.connect(func(verb: String) -> void: started.append(verb))
	state.verb_finished.connect(func(verb: String) -> void: finished.append(verb))
	state.rejected.connect(func(reason: String) -> void: refusals.append(reason))
	state.start_verb("pickup")
	state.start_verb("deposit")
	state.tick(1.0)
	equal(started.size(), 1, "one verb started")
	equal(started[0], "pickup", "and it was the pickup")
	equal(finished.size(), 1, "one verb finished")
	equal(finished[0], "pickup", "and it was the pickup")
	equal(refusals.size(), 1, "the second verb was refused")


func test_locomotion_and_pose() -> void:
	var state := GuildPlayerState.new()
	equal(state.locomotion(0.0), GuildPlayerState.IDLE, "standing still")
	equal(state.locomotion(1.4), GuildPlayerState.WALK, "walking")
	equal(state.locomotion(4.2, true), GuildPlayerState.RUN, "running")
	equal(state.pose_for(0.0), "idle", "idle pose")
	equal(state.pose_for(1.4), "walk", "walk pose")
	equal(state.pose_for(4.2, true), "run", "run pose")
	state.take_items(2)
	equal(state.pose_for(1.4), "carry", "carrying replaces the walk pose")
	equal(state.pose_for(0.0), "carry", "and the idle pose")
	state.start_verb("pickup")
	equal(state.pose_for(0.0), "pickup", "a verb drives the pose")
	equal(state.locomotion(4.0), GuildPlayerState.BUSY, "verbs block locomotion")


func test_player_builds_with_its_stack() -> void:
	var player := GuildPlayer.new()
	player.ensure_look()
	check(player.state != null, "the player owns a state")
	check(player.character != null, "the player owns a rig")
	check(player.carry_stack != null, "the player owns a visible stack")
	equal(player.carry_stack.get_parent(), player.character.stack_anchor(), "the stack rides the hands anchor")
	player.state.carry = 3
	player.character.animate(0.016, 1.4, player.animation_pose())
	player.character.animate(0.016, 0.0, "idle")
	player._on_state_changed()
	equal(player.carry_stack.visible_count(), 3, "three items are drawn for three in hand")
	check(player.interact("pickup"), "interaction is allowed")
	check(not player.interact("deliver"), "but not twice at once")
	player.free()


func test_camera_stays_inside_its_limits() -> void:
	var rig := GuildPlayerCamera.new()
	equal(rig.pitch, GuildPlayerCamera.DEFAULT_PITCH, "starts at the isometric pitch")
	rig.zoom_by(0.2)
	almost(rig.distance, GuildPlayerCamera.MIN_DISTANCE, "zoom in stops at 9 m")
	rig.zoom_by(9.0)
	almost(rig.distance, GuildPlayerCamera.MAX_DISTANCE, "zoom out stops at 20 m")
	rig.pinch(GuildPlayerCamera.DEFAULT_DISTANCE, 4.0)
	almost(rig.distance, GuildPlayerCamera.MIN_DISTANCE, "pinching in is clamped too")
	rig.pinch(GuildPlayerCamera.DEFAULT_DISTANCE, 0.05)
	almost(rig.distance, GuildPlayerCamera.MAX_DISTANCE, "and so is pinching out")
	rig.orbit(0.0, 200.0)
	almost(rig.pitch, GuildPlayerCamera.MAX_PITCH, "pitch cannot flip under the floor")
	rig.orbit(0.0, -200.0)
	almost(rig.pitch, GuildPlayerCamera.MIN_PITCH, "nor stare straight down")
	rig.orbit(400.0, 0.0)
	check(rig.yaw >= -180.0 and rig.yaw <= 180.0, "yaw wraps instead of growing forever")
	rig.free()


func test_camera_looks_down_at_thirty_six_degrees() -> void:
	var rig := GuildPlayerCamera.new()
	rig.pitch = 36.0
	rig.distance = 12.5
	rig.target = Vector3(0.0, 0.0, 0.0)
	var spot := rig.desired_position()
	almost(spot.length(), 12.5, "the camera sits at the spring distance")
	almost(spot.y, 12.5 * sin(deg_to_rad(36.0)), "and at the pitched height")
	check(spot.z > 0.0, "behind the target, not in front of it")
	rig.focus_on(Vector3(4.0, 0.0, 4.0))
	equal(rig.target, Vector3(4.0, 0.0, 4.0), "focus moves the rig")
	rig.free()
