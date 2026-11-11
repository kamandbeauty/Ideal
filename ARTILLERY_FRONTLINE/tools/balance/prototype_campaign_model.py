# PROTOTYPE. Omits vehicle/craft blast splash and repair/airdrop; used only for rough campaign pacing. See documentation/UPGRADE_AUDIT.md section 14.
"""Deterministic combat model for Phase 3.5 balance (prototype; mirrors balance_model.gd).
Constants are copied from the Godot source files named in comments. No physics and no playtest."""
import math

SCALE = 0.55             # coastal_controller.gd DAMAGE_SCALE
EMPLACEMENT_HP = 6000.0  # coastal_controller.gd MAX_HEALTH

WEAPONS = {              # coastal_weapon.gd WEAPONS
    "twin_hmg": dict(damage=20.0, interval=0.085, magazine=140, reload=2.3, blast=0.0),
    "cannon": dict(damage=150.0, interval=1.15, magazine=12, reload=3.4, blast=5.5),
    "rocket": dict(damage=170.0, interval=0.72, magazine=6, reload=3.0, blast=9.0),
    "bazooka": dict(damage=240.0, interval=1.05, magazine=4, reload=3.2, blast=6.5),
    "autocannon": dict(damage=42.0, interval=0.16, magazine=70, reload=2.7, blast=2.2),
}


def hit_res(a):  # damage_model.gd hit_resistance
    if a <= 25.0:
        return 0.78
    if a < 100.0:
        return 0.35
    return 0.1


def taken_armoured(a, armor):  # DamageModel.taken for soldiers and vehicles
    res = min(max(armor, 0.0), 1.0) * hit_res(a)
    res = min(max(res, 0.0), 0.9)
    return a * (1.0 - res)


def taken_craft(a):  # landing_craft.gd receive_damage
    return a * (0.35 if a <= 25.0 else 0.85)


# dps = expected HP per second taken by the emplacement while the unit is alive and engaging.
# dps uses raw damage * DAMAGE_SCALE / interval * hit ratio (hit ratio is an assumption, see report).
TARGETS = {
    "rifle": dict(hp=20.0, armor=0.0, kind="inf", dps=0.5 * SCALE * 17.0 / 2.4),
    "heavy": dict(hp=36.0, armor=0.5, kind="inf", dps=0.9 * SCALE * 45.0 / 4.2),
    "rpg": dict(hp=20.0, armor=0.0, kind="inf", dps=0.8 * SCALE * 50.0 / 6.5),
    "jeep": dict(hp=90.0, armor=1.0, kind="veh", dps=SCALE * 14.0 / 2.0),
    "transport": dict(hp=120.0, armor=1.0, kind="veh", dps=SCALE * 22.0 / 2.6),
    "apc": dict(hp=220.0, armor=1.0, kind="veh", dps=SCALE * 40.0 / 3.2),
    "tank": dict(hp=260.0, armor=1.0, kind="veh", dps=SCALE * 150.0 / 4.6),
    "boss": dict(hp=900.0, armor=1.0, kind="veh", dps=SCALE * 220.0 / 3.8),
    "heli": dict(hp=320.0, armor=0.0, kind="air", dps=SCALE * 55.0 / 3.2),
    "fighter": dict(hp=240.0, armor=0.0, kind="air", dps=SCALE * 90.0 / 5.0),
    "craft": dict(hp=600.0, armor=0.0, kind="craft", dps=0.0),
}

ROUNDS = [  # wave_manager.gd ROUNDS (heavy and rpg are inside soldiers)
    dict(soldiers=8, rpg=1, tanks=1, helicopters=1, craft=1),
    dict(soldiers=12, heavy=2, rpg=2, tanks=1, jeeps=1, helicopters=2, fighters=2, craft=2),
    dict(soldiers=20, heavy=4, rpg=3, tanks=1, apcs=1, bosses=1, helicopters=2, fighters=2, craft=2),
]


def kill_time(target, weapon, overhead, reload_mult=1.0):
    w = WEAPONS[weapon]
    t = TARGETS[target]
    if t["kind"] == "craft":
        taken = taken_craft(w["damage"])
    elif t["kind"] == "air":
        taken = w["damage"]
    else:
        taken = taken_armoured(w["damage"], t["armor"])
    shots = math.ceil(t["hp"] / taken - 1e-9)
    reloads = (shots - 1) // w["magazine"]
    return shots * w["interval"] + reloads * w["reload"] * reload_mult + overhead


def best_weapon(target, overhead, allowed, reload_mult=1.0):
    best = None
    for wname in allowed:
        tt = kill_time(target, wname, overhead, reload_mult)
        if best is None or tt < best[1]:
            best = (wname, tt)
    return best


def schedule(r, craft_gap=0.0):
    """Activation times for cargo. Mirrors coastal_controller: each craft holds its vehicles first, then
    its infantry; _unload walks that list with ONE timer (0.6 s, then +0.45 per infantry, +1.7 per vehicle).
    Craft progress is normalised, so every craft arrives 1/0.07 = 14.3 s after its own launch."""
    crafts = r.get("craft", 0)
    if crafts == 0:
        return []
    cargo = []
    for kind, key in (("tank", "tanks"), ("transport", "transports"), ("jeep", "jeeps"), ("apc", "apcs"), ("boss", "bosses")):
        cargo += [kind] * r.get(key, 0)
    rifles = r["soldiers"] - r.get("heavy", 0) - r.get("rpg", 0)
    infantry = ["heavy"] * r.get("heavy", 0) + ["rpg"] * r.get("rpg", 0) + ["rifle"] * rifles
    loads = [[] for _ in range(crafts)]
    for i, k in enumerate(cargo):
        loads[i % crafts].append(("veh", k))
    for i, k in enumerate(infantry):
        loads[i % crafts].append(("inf", k))
    queue = []
    for c in range(crafts):
        t = c * craft_gap + 14.3 + 0.6
        for kind, name in loads[c]:
            queue.append((t + 12.0, name))
            t += 0.45 if kind == "inf" else 1.7
    return queue


def simulate_round(r, profile, dt=0.05):
    """Player greedily kills the active target with the highest threat per kill time.
    profile: overhead (s per target), weapons (allowed list), hit_mult, reload_mult, craft_gap."""
    queue = schedule(r, profile.get("craft_gap", 0.0))
    air = ["heli"] * r.get("helicopters", 0) + ["fighter"] * r.get("fighters", 0)
    targets = [dict(at=3.0, kind=k) for k in air] + [dict(at=at, kind=k) for at, k in queue]
    for k in range(r.get("craft", 0)):
        targets.append(dict(at=0.0, kind="craft"))
    overhead = profile["overhead"]
    allowed = profile["weapons"]
    reload_mult = profile.get("reload_mult", 1.0)
    hit_mult = profile.get("hit_mult", 1.0)
    t = 0.0
    damage = 0.0
    peak = 0.0
    current = None  # (target_dict, finish_time)
    while t < 900.0:
        if current is None:
            active = [x for x in targets if x["alive"] and x["at"] <= t] if False else None
            cands = []
            for x in targets:
                if x.get("dead") or x["at"] > t:
                    continue
                w = best_weapon(x["kind"], overhead, allowed, reload_mult)
                dps = TARGETS[x["kind"]]["dps"]
                cands.append((dps / w[1] if dps > 0 else 0.0, id(x), x, w[1]))
            if cands:
                cands.sort(key=lambda c: (-c[0], c[1]))
                _, _, x, kt = cands[0]
                current = (x, t + kt)
        dps_now = sum(TARGETS[x["kind"]]["dps"] for x in targets if not x.get("dead") and x["at"] <= t) * hit_mult
        damage += dps_now * dt
        peak = max(peak, dps_now)
        if current is not None and t >= current[1]:
            current[0]["dead"] = True
            current = None
        t += dt
        if all(x.get("dead") for x in targets):
            break
    return dict(damage=damage, time=t, peak=peak, killed=sum(1 for x in targets if x.get("dead")), total=len(targets))


PROFILES = {
    "skilled": dict(overhead=0.7, weapons=list(WEAPONS), hit_mult=1.0),
    "average": dict(overhead=1.2, weapons=list(WEAPONS), hit_mult=1.0),
    "beginner": dict(overhead=2.0, weapons=["twin_hmg"], hit_mult=1.0),
    "poor_ammo": dict(overhead=1.2, weapons=["twin_hmg"], hit_mult=1.0, reload_mult=2.0),
}

if __name__ == "__main__":
    for k in TARGETS:
        if k == "craft":
            continue
        print(k, {w: round(kill_time(k, w, 0.0), 2) for w in WEAPONS})
    print("craft", {w: round(kill_time("craft", w, 0.0), 2) for w in WEAPONS})
    for name, prof in PROFILES.items():
        total = 0.0
        for i, r in enumerate(ROUNDS, 1):
            res = simulate_round(r, prof)
            total += res["damage"]
            print(name, "round", i, "damage", round(res["damage"]), "time", round(res["time"], 1),
                  "peak", round(res["peak"], 1), "killed", res["killed"], "/", res["total"])
        print(name, "campaign damage", round(total), "=", round(100 * total * 1.0 / EMPLACEMENT_HP), "% of MAX")
