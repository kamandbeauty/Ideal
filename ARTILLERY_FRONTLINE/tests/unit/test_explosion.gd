extends RefCounted
## Area damage arithmetic and the shipped blast resources.


func run(t: TestContext) -> void:
	var blast := ExplosionData.new()
	blast.damage = 200.0
	blast.inner_radius = 1.0
	blast.radius = 5.0
	blast.edge_fraction = 0.2
	t.near(blast.falloff(0.0), 1.0, 0.0001, "full damage at the centre")
	t.near(blast.falloff(1.0), 1.0, 0.0001, "full damage out to the inner radius")
	t.near(blast.falloff(3.0), 0.6, 0.0001, "damage falls in a straight line between the radii")
	t.near(blast.falloff(5.0), 0.2, 0.0001, "the edge keeps its configured share")
	t.near(blast.falloff(5.01), 0.0, 0.0001, "nothing beyond the outer radius")
	t.near(blast.damage_at(3.0), 120.0, 0.001, "damage_at scales the damage by the falloff")
	var previous: float = INF
	var monotonic: bool = true
	for step: int in 60:
		var value: float = blast.damage_at(float(step) * 0.1)
		if value > previous + 0.0001:
			monotonic = false
		previous = value
	t.check(monotonic, "damage never rises with distance")
	# reach_for is the inverse of damage_at.
	t.near(blast.reach_for(120.0), 3.0, 0.0001, "reach_for finds the distance of a given damage")
	t.near(blast.reach_for(200.0), 1.0, 0.0001, "full damage reaches exactly the inner radius")
	t.near(blast.reach_for(250.0), 0.0, 0.0001, "more than the centre's damage is reached nowhere")
	t.near(blast.reach_for(30.0), 5.0, 0.0001, "less than the edge damage is reached out to the outer radius")
	for wanted: float in [50.0, 90.0, 160.0, 199.0]:
		t.near(blast.damage_at(blast.reach_for(wanted)), wanted, 0.01, "damage at reach_for(%d) is %d" % [int(wanted), int(wanted)])
	# Degenerate shapes do not divide by zero.
	var flat := ExplosionData.new()
	flat.inner_radius = 4.0
	flat.radius = 4.0
	t.near(flat.falloff(3.9), 1.0, 0.0001, "equal radii give a flat disc of full damage")
	t.near(flat.falloff(4.1), 0.0, 0.0001, "and nothing outside it")

	# The shipped blasts.
	var walker: ZombieData = load("res://resources/zombies/walker.tres")
	for path: String in ["res://resources/explosions/rocket_blast.tres", "res://resources/explosions/grenade_blast.tres"]:
		var shipped: ExplosionData = load(path)
		var label: String = path.get_file().get_basename()
		t.check(shipped != null, "%s loads as ExplosionData" % label)
		t.check(shipped.radius > shipped.inner_radius and shipped.inner_radius > 0.0, "%s has an inner and an outer radius" % label)
		t.check(shipped.damage >= walker.max_health * 2.0, "%s kills a walker outright at the centre" % label)
		t.check(shipped.damage_at(shipped.radius) < walker.max_health, "%s only wounds a walker at its edge" % label)
		var lethal: float = shipped.reach_for(walker.max_health)
		t.check(lethal >= 2.5 and lethal <= 6.0, "%s kills walkers within a few metres (%.1f m)" % [label, lethal])
		t.near(shipped.structure_damage, 0.0, 0.0001, "%s spares the gate and the wall" % label)
		t.check(Sound.has_clip(shipped.sound), "%s has its sound (%s)" % [label, shipped.sound])
		t.check(shipped.knockback > 0.0 and shipped.stagger_time > 0.0, "%s throws and staggers" % label)
	var rocket: ExplosionData = load("res://resources/explosions/rocket_blast.tres")
	var grenade: ExplosionData = load("res://resources/explosions/grenade_blast.tres")
	t.check(rocket.radius >= grenade.radius and rocket.damage >= grenade.damage, "the rocket is the bigger of the two blasts")

	# Launcher and grenade resources.
	var launcher: WeaponData = load("res://resources/weapons/rpg_launcher.tres")
	t.check(launcher != null and launcher.kind == "rocket", "rpg_launcher.tres is a rocket weapon")
	t.check(launcher.explosion == rocket, "the launcher carries the rocket blast")
	t.equal(launcher.magazine_size, 1, "the launcher holds one round")
	t.check(launcher.reserve >= 1 and launcher.reserve_max >= launcher.reserve, "rockets are a limited supply with room for resupply")
	t.check(launcher.reload_time >= 2.0, "reloading the launcher is slow (%.1f s)" % launcher.reload_time)
	t.check(not launcher.counts_for_accuracy(), "rockets are kept out of the accuracy figure")
	t.check(launcher.muzzle_velocity >= 30.0 and launcher.muzzle_velocity <= 150.0, "a rocket can be followed with the eye")
	var machine_gun: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	t.check(machine_gun.kind == "bullet" and machine_gun.counts_for_accuracy() and not machine_gun.limited_supply(),
		"the machine gun fires bullets from an unlimited supply")
	var frag: GrenadeData = load("res://resources/weapons/frag_grenade.tres")
	t.check(frag != null and frag.explosion == grenade, "frag_grenade.tres carries the grenade blast")
	t.check(frag.carried >= 1 and frag.capacity >= frag.carried, "grenades are a limited supply with room for resupply")
	t.check(frag.max_range > frag.min_range and frag.max_range >= 30.0, "a grenade reaches across the court (%.0f m)" % frag.max_range)
	t.check(frag.max_flight_time >= frag.min_flight_time and frag.min_flight_time > 0.0, "flight times are ordered")
	t.check(frag.max_life > frag.max_flight_time + frag.fuse_after_landing, "the safety fuze outlasts a normal throw")
