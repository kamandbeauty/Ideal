extends RefCounted
## Useful, compatible pieces of the supplied packs are actually wired to play.

func run(t: TestContext) -> void:
	Profile.persist = false
	t.check(Sound.has_clip("kenney_weapon_change"), "Kenney's weapon-change layer is imported")
	if Sound.has_clip("kenney_weapon_change"):
		t.check(Sound.clips["kenney_weapon_change"] is AudioStreamOggVorbis, "the effect uses the supplied Ogg clip")
	var level: CityLevel = t.make_level()
	await t.frames(2)
	var brute: Zombie = level.horde.spawn(&"brute", "ring_right", "gate")
	t.check(brute != null, "a brute is available for hit-reaction tests")
	if brute != null:
		t.check(brute.anim.has_animation("hit_chest") and brute.anim.has_animation("hit_head"), "retargeted hit reactions are on the actual model")
		var hp: float = brute.health
		brute.take_hit(brute.data.max_health * 0.31, false, brute.position, Vector3.FORWARD)
		t.equal(brute.current_clip, "hit_chest", "a nonlethal staggering body hit chooses the chest reaction")
		t.check(brute.health < hp and brute.alive, "a reaction does not change damage rules")
		brute.stagger_left = 0.0
		brute.take_hit(brute.data.max_health * 0.31, true, brute.position, Vector3.FORWARD)
		t.equal(brute.current_clip, "hit_head", "a nonlethal staggering head hit chooses the head reaction")
		t.check(brute.alive, "the second hit remains nonlethal")
	await t.discard(level)
