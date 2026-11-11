extends RefCounted
## Phase 3.6 weapon checks: every weapon's numbers are sane, no hit exceeds the designed critical and
## headshot ceiling, and each weapon keeps the one trait that gives it a role (the audit's invariants).

const WEAPON_KEYS: Array[String] = ["twin_hmg", "cannon", "rocket", "bazooka", "autocannon"]
## Largest multiplier one shot can carry: a headshot on infantry (2.2) times a critical (1.6).
const HEADSHOT_CRITICAL_CEILING: float = 2.2 * 1.6

func run(t: TestContext) -> void:
	_check_values_sane(t)
	_check_hit_bounds(t)
	_check_roles(t)

func _check_values_sane(t: TestContext) -> void:
	for key in WEAPON_KEYS:
		var data: Dictionary = CoastalWeapon.WEAPONS[key]
		var sane: bool = true
		for field in ["interval", "damage", "magazine", "reload", "speed", "spread"]:
			var value: float = float(data[field])
			sane = sane and is_finite(value) and value > 0.0
		sane = sane and float(data.blast) >= 0.0
		t.check(sane, "%s: every timing, damage, speed and spread value is finite and positive" % key)
		t.check(float(data.damage) <= 300.0 and float(data.interval) >= 0.05, "%s: no single hit above 300 damage, no fire rate above 20 shots per second" % key)

func _check_hit_bounds(t: TestContext) -> void:
	for key in WEAPON_KEYS:
		var damage: float = float(CoastalWeapon.WEAPONS[key].damage)
		for armor in [0.0, 0.5, 1.0]:
			var taken: float = DamageModel.taken(damage * HEADSHOT_CRITICAL_CEILING, armor)
			t.check(taken <= damage * HEADSHOT_CRITICAL_CEILING and taken > 0.0, "%s vs armour %.1f: a headshot critical removes a positive, bounded amount" % [key, armor])
			var resisted: float = DamageModel.taken(damage, 1.0)
			t.check(resisted >= damage * (1.0 - DamageModel.MAX_RESISTANCE), "%s vs full plate: armour never removes more than %.0f%% of a hit" % [key, DamageModel.MAX_RESISTANCE * 100.0])

## Each invariant is a role the balance audit depends on. Changing one of these numbers changes a role, so update the audit with it.
func _check_roles(t: TestContext) -> void:
	var hmg: Dictionary = CoastalWeapon.WEAPONS["twin_hmg"]
	var cannon: Dictionary = CoastalWeapon.WEAPONS["cannon"]
	var rocket: Dictionary = CoastalWeapon.WEAPONS["rocket"]
	var bazooka: Dictionary = CoastalWeapon.WEAPONS["bazooka"]
	var autocannon: Dictionary = CoastalWeapon.WEAPONS["autocannon"]
	var fastest: bool = true
	for key in WEAPON_KEYS:
		if float(CoastalWeapon.WEAPONS[key].interval) < float(hmg.interval):
			fastest = false
	t.check(fastest, "Twin HMG has the fastest fire rate: the squad-clearing weapon")
	t.check(float(bazooka.damage) > float(rocket.damage) and float(bazooka.damage) > float(cannon.damage) and float(bazooka.damage) > float(autocannon.damage), "Bazooka has the largest single hit: the one-shot anti-aircraft weapon")
	t.check(float(rocket.blast) > float(cannon.blast) and float(rocket.blast) > float(bazooka.blast), "Rocket has the widest blast: the anti-armour and landing-craft splash weapon")
	t.check(float(cannon.speed) > float(rocket.speed) and float(cannon.speed) > float(bazooka.speed), "Cannon has the fastest blast round: it arrives before rocket and bazooka")
	t.check(int(bazooka.magazine) < int(rocket.magazine) and int(rocket.magazine) < int(autocannon.magazine), "Ammunition runs out fastest for the bazooka, then the rocket: their limit is the magazine")
	t.check(float(autocannon.blast) < float(cannon.blast), "Autocannon has the smallest splash of the blast weapons, so it stays a direct-fire weapon")
