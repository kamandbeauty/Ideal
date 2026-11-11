"""Time-to-kill from source values only (no accuracy assumed). Hits per kill, seconds of fire incl. reloads.
Armour: DamageModel.taken(amount, armor) = amount*(1 - clamp(armor*hit_res, 0, 0.9)); hit_res 0.78 (<=25), 0.35 (<100), 0.1 (>=100).
Vehicles armor 1.0; heavy infantry armor 0.5; rifle/RPG 0; aircraft no armour (see enemy_aircraft.gd)."""
import math
W = {  # damage, interval, magazine, reload
 "twin_hmg": (20, 0.085, 140, 2.3), "cannon": (150, 1.15, 12, 3.4), "rocket": (170, 0.72, 6, 3.0),
 "bazooka": (240, 1.05, 4, 3.2), "autocannon": (42, 0.16, 70, 2.7)}
def hit_res(a):
    return 0.78 if a <= 25 else (0.35 if a < 100 else 0.1)
def taken(a, armor):
    return a * (1 - min(max(min(max(armor,0),1) * hit_res(a), 0), 0.9))
T = {  # name: (hp, armor)
 "rifle": (20, 0.0), "heavy": (36, 0.5), "rpg": (20, 0.0), "jeep": (90, 1.0), "apc": (220, 1.0),
 "tank": (260, 1.0), "boss": (900, 1.0), "helicopter": (320, 0.0), "fighter": (240, 0.0)}
def ttk(w, target):
    dmg, iv, mag, rl = W[w]
    hp, armor = T[target]
    if target in ("helicopter", "fighter"):
        per = dmg
    else:
        per = taken(dmg, armor)
    shots = math.ceil(hp / per - 1e-9)
    mags_reloads = (shots - 1) // mag
    return shots, round(shots * iv + mags_reloads * rl, 1)
# craft: 600 HP; 35% of hits <=25, 85% of larger
def craft_ttk(w):
    dmg, iv, mag, rl = W[w]
    per = dmg * (0.35 if dmg <= 25 else 0.85)
    shots = math.ceil(600 / per - 1e-9)
    return shots, round(shots * iv + ((shots - 1) // mag) * rl, 1)
if __name__ == "__main__":
    targets = list(T.keys())
    print("%-12s" % "target" + "".join("%16s" % w for w in W))
    for t in targets:
        print("%-12s" % t + "".join("%16s" % ("%d/%.1fs" % ttk(w, t)) for w in W))
    print("%-12s" % "craft" + "".join("%16s" % ("%d/%.1fs" % craft_ttk(w)) for w in W))
    # Per-target fastest and what each weapon is best at
    print()
    for t in targets + ["craft"]:
        scores = {w: (ttk(w, t)[1] if t != "craft" else craft_ttk(w)[1]) for w in W}
        best = min(scores, key=scores.get)
        print(t, "best:", best, scores[best], "worst:", max(scores, key=scores.get), max(scores.values()))
