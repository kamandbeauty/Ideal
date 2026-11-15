extends TestCase
## The procedural rig: every style builds, the anchors exist, the walk cycle has
## the right shape, and the carry stack is literally the number it is told to show.


func test_every_style_builds() -> void:
	for style in GuildCharacter.STYLES:
		var character := GuildCharacter.new(str(style), true)
		check(character.part("head") != null, "no head for " + str(style))
		check(character.part("torso") != null, "no torso for " + str(style))
		check(character.part("arm_l") != null, "no left arm for " + str(style))
		check(character.part("hand_r") != null, "no right hand for " + str(style))
		check(character.part("leg_l") != null, "no legs for " + str(style))
		check(character.stack_anchor() != null, "no stack anchor for " + str(style))
		check(character.money_anchor() != null, "no money anchor for " + str(style))
		character.free()


func test_unknown_style_falls_back_to_the_guild_master() -> void:
	var character := GuildCharacter.new("no_such_class", false)
	equal(character.style_id, "guildmaster", "unknown styles must not crash the rig")
	character.free()


func test_style_differences_are_real() -> void:
	var warrior := GuildCharacter.new("warrior", false)
	var mage := GuildCharacter.new("mage", false)
	check(warrior.part("weapon") != null, "the warrior carries a sword")
	check(mage.part("weapon") != null, "the mage carries a staff")
	check(mage.part("hood") != null, "the mage wears a hood")
	check(warrior.part("hood") == null, "the warrior does not")
	check(mage.part("cape") != null, "the mage has a cape")
	check(warrior.part("cape") == null, "the warrior does not")
	not_equal(
		GuildCharacter.STYLES["warrior"]["coat"], GuildCharacter.STYLES["mage"]["coat"], "palettes differ"
	)
	warrior.free()
	mage.free()


func _count_ink(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if str(child.name).begins_with("Ink"):
			total += 1
		total += _count_ink(child)
	return total


func test_outline_can_be_switched_off() -> void:
	var outlined := GuildCharacter.new("knight", true)
	var flat_look := GuildCharacter.new("knight", false)
	var ink_on_torso := _count_ink(outlined)
	var ink_on_flat := _count_ink(flat_look)
	check(ink_on_torso > 5, "outlined characters get ink lines")
	equal(ink_on_flat, 0, "NPC-quality characters skip the extra draw calls")
	outlined.free()
	flat_look.free()


func test_walk_cycle_shape() -> void:
	almost(GuildCharacter.walk_swing(0.0), 0.0, "the cycle starts at rest")
	almost(GuildCharacter.walk_swing(PI / 2.0, 0.6), 0.6, "quarter cycle is the full step")
	almost(GuildCharacter.walk_swing(PI, 0.6), 0.0, "half cycle passes through rest")
	almost(GuildCharacter.walk_swing(PI * 1.5, 0.6), -0.6, "the other leg reaches forward")


func test_poses_move_the_arms() -> void:
	var character := GuildCharacter.new("guildmaster", false)
	character.animate(0.016, 0.0, "idle")
	var idle_arm := character.part("arm_r").rotation.x
	character.animate(0.5, 0.0, "carry")
	var carry_arm := character.part("arm_r").rotation.x
	check(carry_arm < idle_arm - 0.5, "carrying lifts the arms in front of the chest")
	character.animate(0.5, 0.0, "pickup")
	check(character.part("torso").rotation.x > 0.1, "picking something up leans the torso forward")
	character.animate(0.5, 0.0, "nonsense")
	equal(character.current_pose, "idle", "unknown poses fall back to idle")
	character.free()


func test_walking_swings_the_legs() -> void:
	var character := GuildCharacter.new("archer", false)
	character.animate(0.1, 4.2, "walk")
	var first := character.part("leg_l").rotation.x
	character.animate(0.2, 4.2, "walk")
	var second := character.part("leg_l").rotation.x
	not_equal(first, second, "the legs keep moving while walking")
	check(absf(first) <= 0.63, "the step never over-rotates")
	character.free()


func test_carry_stack_shows_the_real_count() -> void:
	var stack := GuildCarryStack.new()
	stack.show_items(3)
	equal(stack.total, 3, "three items in the hands")
	equal(stack.visible_count(), 3, "three parcels drawn")
	equal(stack.get_child(0).get_child_count(), 3, "one mesh per item")
	stack.show_items(1)
	equal(stack.get_child(0).get_child_count(), 1, "putting items back removes the meshes")
	stack.show_items(40)
	equal(stack.total, 40, "the count is honest even past the visual cap")
	equal(stack.visible_count(), GuildCarryStack.MAX_VISIBLE, "the stack caps for readability")
	equal(stack.get_child(0).get_child_count(), GuildCarryStack.MAX_VISIBLE, "capped meshes")
	stack.free()


func test_money_stacks_in_coins() -> void:
	var stack := GuildCarryStack.new()
	stack.show_money(120.0)
	equal(stack.kind, "money", "coins, not parcels")
	equal(stack.total, 3, "120 gold is three stacks of 50")
	stack.show_money(0.0)
	equal(stack.total, 0, "empty hands draw nothing")
	equal(stack.get_child(0).get_child_count(), 0, "no leftover meshes")
	stack.free()
