extends RefCounted
## Persistent rewards, upgrades, preview and the absence of a fake ad reward.

func run(t: TestContext) -> void:
	var old_path: String = Profile.save_path
	var old_persist: bool = Profile.persist
	Profile.save_path = "user://economy_test.json"
	SaveManager.remove(Profile.save_path)
	Profile.persist = true
	Profile.reset()
	t.equal(Profile.reward_for({"victory": false, "stage": 0}), 0, "a loss with no activity pays nothing")
	var play: Dictionary = {"victory": false, "kills": 20, "headshots": 5, "shots": 100, "hits": 50, "waves_cleared": 1}
	t.equal(Profile.reward_for(play), 75, "a loss still rewards kills, headshots, accuracy and waves")
	var better: Dictionary = play.duplicate()
	better["victory"] = true
	better["wall_left"] = 0.75
	t.equal(Profile.reward_for(better), 205, "victory and the wall add to the performance bonus")
	t.check(Profile.reward_for(better) > Profile.reward_for(play), "a better outcome earns more")
	t.equal(Profile.reward_for({"victory": true, "stage": 0}), 100, "stage one pays 100")
	t.equal(Profile.reward_for({"victory": true, "stage": 2}), 200, "stage three pays 200")
	Profile.record_match({"victory": false, "stage": 0})
	t.equal(int(Profile.data.economy.coins), 0, "a loss adds nothing")
	Profile.record_match({"victory": true, "stage": 0})
	t.equal(int(Profile.data.economy.coins), 100, "winning credits coins")
	t.check(not Profile.buy_upgrade("invalid") and not Profile.buy_upgrade("rpg_launcher_invalid"), "unknown items are refused")
	t.check(Profile.buy_upgrade("rpg_launcher"), "an affordable upgrade is bought")
	t.equal(int(Profile.data.economy.coins), 0, "the price is deducted")
	t.equal(Profile.upgrade_level("rpg_launcher"), 1, "the launcher is upgraded")
	t.check(not Profile.buy_upgrade("rpg_launcher"), "insufficient balance cannot buy another level")
	Profile.load_profile()
	t.check(Profile.upgrade_level("rpg_launcher") == 1 and int(Profile.data.economy.coins) == 0, "balance and level survive a reload")
	Profile.record_match({"victory": true, "stage": 2})
	t.check(Profile.buy_upgrade("frag_grenade"), "grenades can be upgraded too")
	var base_launcher: WeaponData = load("res://resources/weapons/rpg_launcher.tres")
	var base_grenade: GrenadeData = load("res://resources/weapons/frag_grenade.tres")
	var base_rocket_damage: float = base_launcher.explosion.damage
	var base_grenade_damage: float = base_grenade.explosion.damage
	var defender: Defender = (load("res://scenes/player/defender.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(defender)
	await t.frames(2)
	t.near(defender.weapons[1].data.explosion.damage, base_rocket_damage * 1.12, 0.01, "launcher blast damage is upgraded in the actual loadout")
	t.near(defender.grenade_data.explosion.damage, base_grenade_damage * 1.12, 0.01, "grenade blast damage is upgraded in the actual loadout")
	t.near(base_launcher.explosion.damage, base_rocket_damage, 0.001, "shared launcher resource was not mutated")
	t.near(base_grenade.explosion.damage, base_grenade_damage, 0.001, "shared grenade resource was not mutated")
	await t.discard(defender)
	# Old saves gain safe default selections; new selections and independent
	# upgrades survive a reload and affect the actual weapons in the match.
	Profile.set_setting("launcher", "heavy_rpg")
	Profile.set_setting("grenade", "blast_grenade")
	Profile.data.economy.coins = 300
	t.check(Profile.buy_upgrade("heavy_rpg") and Profile.buy_upgrade("blast_grenade"), "both alternate models upgrade separately")
	Profile.load_profile()
	t.equal(String(Profile.setting("launcher")), "heavy_rpg", "launcher selection persists")
	t.equal(String(Profile.setting("grenade")), "blast_grenade", "grenade selection persists")
	defender = (load("res://scenes/player/defender.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(defender)
	await t.frames(2)
	t.equal(String(defender.weapons[1].data.id), "heavy_rpg", "alternate launcher reaches the live loadout")
	t.near(defender.weapons[1].data.explosion.damage, 290.0 * 1.12, 0.01, "alternate launcher upgrade affects live damage")
	t.equal(String(defender.grenade_data.id), "blast_grenade", "alternate grenade reaches the live loadout")
	t.near(defender.grenade_data.explosion.damage, 310.0 * 1.12, 0.01, "alternate grenade upgrade affects live damage")
	t.near(defender.grenade_data.explosion.radius, 6.4, 0.01, "alternate grenade has its own blast radius")
	await t.discard(defender)
	Profile.set_setting("launcher", "rpg_launcher")
	Profile.set_setting("grenade", "frag_grenade")
	var menus := Menus.new()
	t.tree.root.add_child(menus)
	menus.show_equipment()
	await t.frames(2)
	t.equal(menus.equipment_choices.buttons.size(), Profile.EQUIPMENT.size(), "the workshop includes guns, launcher and grenade")
	var cards: Array[Button] = menus.equipment_choices.buttons
	t.check(cards[0].visible and cards[4].visible and not cards[5].visible and not cards[6].visible, "the guns and explosives use separate tabs")
	menus.equipment_group = "explosives"
	menus._show("equipment")
	await t.frames(2)
	t.check(not menus.equipment_choices.buttons[0].visible and menus.equipment_choices.buttons[5].visible and menus.equipment_choices.buttons[6].visible, "explosives tab shows its own equipment")
	menus.equipment_choices.buttons[Profile.EQUIPMENT.find("frag_grenade")].pressed.emit()
	await t.frames(2)
	t.equal(menus.screen, "upgrade", "selecting equipment opens its own upgrade page")
	t.equal(menus.gun_preview.displayed_id, "frag_grenade", "grenade has a model preview")
	t.check(menus.gun_preview.camera.size < 0.7, "the small grenade fills the preview rather than appearing as a speck")
	for id: String in Profile.EQUIPMENT:
		menus.show_equipment()
		await t.frames(2)
		menus.equipment_choices.buttons[Profile.EQUIPMENT.find(id)].pressed.emit()
		await t.frames(2)
		t.check(menus.screen == "upgrade" and menus.gun_preview.displayed_id == id and menus.upgrade_button != null, "individual upgrade page for " + id)
	menus.show_result(false, {"victory": false, "coins_earned": 75})
	await t.frames(2)
	t.check(menus.reward_label != null and menus.ad_button == null, "a defeat displays its earned performance coins")
	menus.show_result(true, {"victory": true, "stage": 0, "coins_earned": 100})
	await t.frames(2)
	t.check(menus.reward_label != null and menus.ad_button != null and menus.ad_button.disabled, "an unavailable rewarded ad cannot pay coins")
	var balance: int = int(Profile.data.economy.coins)
	menus.ad_button.pressed.emit()
	t.equal(int(Profile.data.economy.coins), balance, "an unavailable ad cannot change the balance")
	await t.discard(menus)
	t.equal(Graphics.crowd_cap("low", true, 56), 26, "low-tier phones cap concurrent enemies")
	t.equal(Graphics.crowd_cap("high", false, 56), 56, "desktop keeps the authored wave cap")
	SaveManager.remove(Profile.save_path)
	Profile.save_path = old_path
	Profile.persist = old_persist
	Profile.reset()
