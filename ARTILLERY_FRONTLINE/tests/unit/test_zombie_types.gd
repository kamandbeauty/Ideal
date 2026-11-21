extends RefCounted
## The four zombie types as data: every number sane, and the differences
## between them the ones the design promises.

const IDS: Array[String] = ["walker", "runner", "brute", "boss"]
const CLIPS: Array[String] = ["walk_clean", "run_clean", "idle", "attack", "hit", "hit_chest", "hit_head", "death_back", "death_front"]


func run(t: TestContext) -> void:
	var types: Dictionary = {}
	for id: String in IDS:
		var data: ZombieData = load("res://resources/zombies/%s.tres" % id)
		t.check(data != null and data.scene != null, "%s.tres loads with its scene" % id)
		types[id] = data
		t.equal(String(data.id), id, "%s carries its own id" % id)
		t.check(Loc.TEXT.en.has(data.name_key) and Loc.TEXT.fa.has(data.name_key), "%s has a name in both languages" % id)
		t.check(data.max_health > 0.0 and data.speed > 0.0 and data.attack_damage > 0.0 and data.breach_damage > 0.0,
			"%s numbers are positive" % id)
		t.check(data.attack_hit_point > 0.0 and data.attack_hit_point < 1.0, "%s lands its blow inside the swing" % id)
		t.check(data.scale_min <= data.scale_max, "%s scale range is ordered" % id)
		t.check(data.scale_min >= 0.85, "%s is large enough to read against the wall" % id)
		t.check(data.prewarm >= 1, "%s is built before the match" % id)
		var pace: float = data.speed / data.stride_speed
		t.check(pace > 0.6 and pace < 1.6, "%s walks at a pace its legs can show (clip rate %.2f)" % [id, pace])
		t.check(data.body_height >= data.body_radius * 2.0 and data.head_radius > 0.0, "%s hit volumes are well formed" % id)
		for skin: int in data.skins:
			t.check(ResourceLoader.exists("res://assets/textures/zombies/zombie_%s_%s.png" % [id, "abcdefgh"[skin]]),
				"%s skin %d is painted" % [id, skin + 1])
		for sound: String in [data.spawn_sound, data.death_sound]:
			t.check(sound == "" or Sound.has_clip(sound), "%s sound '%s' exists" % [id, sound])
		# The model itself: the shared skeleton and every clip the state machine plays.
		var model: Node3D = (load("res://assets/models/zombies/zombie_%s.glb" % id) as PackedScene).instantiate()
		var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		t.check(skeleton != null and skeleton.get_bone_count() == 18 and skeleton.find_bone("Head") >= 0, "%s has the 18-bone skeleton" % id)
		var missing: Array[String] = []
		for clip: String in CLIPS:
			if player == null or not player.has_animation(clip):
				missing.append(clip)
		t.check(missing.is_empty(), "%s has every clip (%s)" % [id, str(missing)])
		if player != null and player.has_animation("walk_clean") and player.has_animation("run_clean"):
			t.tree.root.add_child(model)
			for clip: String in ["walk_clean", "run_clean"]:
				var steps: Dictionary = _limp(skeleton, player, clip)
				t.check(steps.left > 0.02 and steps.right > 0.02, "%s %s lifts both feet" % [id, clip])
				t.check(absf(steps.left - steps.right) < maxf(steps.left, steps.right) * 0.3, "%s %s has balanced leg lift (%.3f, %.3f)" % [id, clip, steps.left, steps.right])
		var tallest: float = 0.0
		var triangles: int = 0
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			tallest = maxf(tallest, mesh.get_aabb().end.y)
			for surface: int in mesh.mesh.get_surface_count():
				triangles += (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		t.check(absf(tallest - data.height()) < data.height() * 0.1, "%s hit volumes match the model's height (%.2f m model, %.2f m volumes)" % [
			id, tallest, data.height()])
		t.check(triangles > 3000 and triangles < 6500, "%s is detailed, and stays inside the mobile triangle budget (%d)" % [id, triangles])
		model.free()

	var walker: ZombieData = types.walker
	var runner: ZombieData = types.runner
	var brute: ZombieData = types.brute
	var boss: ZombieData = types.boss
	# Fast: quick and frail.
	t.check(runner.speed > walker.speed * 1.8, "the runner is much faster than a walker")
	t.check(runner.max_health < walker.max_health, "and frailer")
	t.check(runner.attack_interval < walker.attack_interval, "it strikes more often")
	t.check(runner.body_lean_degrees > walker.body_lean_degrees, "it runs bent forward")
	t.check(runner.voice_pitch > 1.0, "and its voice is higher")
	# Heavy: slow, tough, hard to stop.
	t.check(brute.speed < walker.speed and brute.max_health > walker.max_health, "the brute is slower and has more health")
	t.check(brute.attack_damage / brute.attack_interval > 2.0 * walker.attack_damage / walker.attack_interval, "it hurts the gate at least twice as fast")
	t.check(brute.flinch_slow > walker.flinch_slow and brute.blast_reel_scale < 1.0 and brute.knockback_scale < 1.0, "bullets and blasts barely slow it")
	t.check(brute.footprint == 2 and walker.footprint == 1 and runner.footprint == 1, "it takes two places at the wall")
	t.check(brute.voice_pitch < 1.0, "its voice is lower")
	# Boss.
	t.check(boss.is_boss and not walker.is_boss and not runner.is_boss and not brute.is_boss, "only the boss is a boss")
	t.check(boss.max_health >= brute.max_health * 8.0, "the boss has many times a brute's health")
	t.check(boss.attack_damage > brute.attack_damage * 2.0 and boss.breach_damage > brute.breach_damage * 2.0, "and hits several times as hard")
	t.check(boss.footprint == 3 and boss.head_damage_scale < 1.0, "it is three places wide and thick-skulled")
	t.check(is_zero_approx(boss.blast_reel_scale) and is_zero_approx(boss.knockback_scale) and is_equal_approx(boss.flinch_slow, 1.0),
		"nothing stops it or throws it")
	t.check(boss.spawn_sound != "" and boss.death_sound != "", "it announces itself and dies loudly")
	t.check(boss.height() > brute.height() and brute.height() > walker.height() and walker.height() > runner.height() * 0.95,
		"sizes are ordered: boss, brute, walker and runner")
	t.check(walker.skins >= 5, "walkers wear at least five painted outfits")
	t.check(walker.scale_max <= 1.25 and walker.scale_min >= 1.05, "walkers stand near a man's height against the wall")
	t.check(walker.extra_looks.size() == 2 and brute.extra_looks.size() == 3 and runner.extra_looks.size() == 1,
		"walker, runner and brute can use additional painted figures")
	t.check(boss.extra_looks.size() == 1 and boss.extra_looks[0].resource_path.ends_with("zombie_city.glb"), "the Behemoth has the realistic figure")

	# Against the weapons.
	var gun: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	var launcher: WeaponData = load("res://resources/weapons/rpg_launcher.tres")
	var direct: float = launcher.damage + launcher.explosion.damage
	t.check(gun.damage * 2.0 > runner.max_health and gun.damage < runner.max_health, "a runner falls to two body rounds")
	t.check(gun.damage * gun.headshot_multiplier >= runner.max_health, "or to one in the head")
	t.check(brute.max_health > gun.damage * 2.0 and brute.max_health <= gun.damage * 3.0, "a brute takes exactly three base body rounds")
	t.check(gun.damage * gun.headshot_multiplier * brute.head_damage_scale >= brute.max_health, "one base headshot drops a brute")
	t.check(direct >= brute.max_health, "a direct rocket kills a fresh brute")
	t.check(boss.max_health > gun.damage * 49.0 and boss.max_health <= gun.damage * 50.0, "the boss takes exactly fifty base body rounds")
	var wall: DefenseData = load("res://resources/defense/city_wall.tres")
	t.check(boss.breach_damage >= wall.wall_max_health * 0.5 and boss.breach_damage < wall.wall_max_health,
		"a boss inside the city costs most of the wall, but not all of it")
	t.check(wall.gate_max_health / (boss.attack_damage / boss.attack_interval) > 20.0, "a sound gate stands up to the boss for a while")


## How high each foot is lifted over one turn of a walk clip: {"left", "right"} in metres.
func _limp(skeleton: Skeleton3D, player: AnimationPlayer, clip: String) -> Dictionary:
	var feet: Dictionary = {"left": skeleton.find_bone("Foot_L"), "right": skeleton.find_bone("Foot_R")}
	var low: Dictionary = {"left": INF, "right": INF}
	var high: Dictionary = {"left": -INF, "right": -INF}
	var length: float = player.get_animation(clip).length
	player.play(clip)
	for step: int in 24:
		player.seek(length * float(step) / 24.0, true)
		player.advance(0.0)
		for side: String in feet:
			var height: float = skeleton.get_bone_global_pose(feet[side]).origin.y
			low[side] = minf(low[side], height)
			high[side] = maxf(high[side], height)
	player.stop()
	return {"left": high.left - low.left, "right": high.right - low.right}
