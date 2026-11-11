"""Time-to-kill including blast splash (source: enemy_vehicle/aircraft/landing_craft react_to_explosion).
Assumption: direct hit lands 1.5 m from the target centre (hull). Soldiers: blast only staggers (no HP).
Vehicle splash = 190*(1-d/(1.7R)) then armour; aircraft = 140*(1-d/(1.5R)) no armour;
craft splash = 160*(1-d/(1.6R)) then 35%/85% scaling. Shots are per bullet; reloads included."""
import math
from ttk import W, T, taken
D = 1.5
def splash(kind, blast, d=D):
    if blast <= 0: return 0.0
    if kind == "vehicle":
        R = 1.7 * blast; base = 190.0
        return taken(base * (1 - d / R), 1.0) if d < R else 0.0
    if kind == "aircraft":
        R = 1.5 * blast; base = 140.0
        return base * (1 - d / R) if d < R else 0.0
    if kind == "craft":
        R = 1.6 * blast; base = 160.0
        s = base * (1 - d / R) if d < R else 0.0
        return s * (0.35 if s <= 25 else 0.85)
def direct(kind, dmg, armor):
    if kind == "aircraft": return dmg
    if kind == "craft": return dmg * (0.35 if dmg <= 25 else 0.85)
    return taken(dmg, armor)
KIND = {"rifle": "soldier", "heavy": "soldier", "rpg": "soldier", "jeep": "vehicle", "apc": "vehicle",
        "tank": "vehicle", "boss": "vehicle", "helicopter": "aircraft", "fighter": "aircraft", "craft": "craft"}
HP = dict((k, v[0]) for k, v in T.items()); HP["craft"] = 600
ARM = dict((k, v[1]) for k, v in T.items()); ARM["craft"] = 0
def hits_to_kill(w, target):
    dmg, iv, mag, rl = W[w]
    kind = KIND[target]; hp = HP[target]; left = hp; shots = 0
    blast = 0.0 if kind == "soldier" else W[w] and BLAST[w]
    if kind == "soldier":
        per_fn = lambda: direct(kind, dmg, 0.0)
    else:
        per_fn = lambda: direct(kind, dmg, ARM[target]) + splash(kind, BLAST[w])
    per = per_fn()
    if kind == "soldier":
        per = direct("soldier", dmg, ARM[target])
    shots = math.ceil(hp / per - 1e-9)
    return shots, round(shots * iv + ((shots - 1) // mag) * rl, 1)
BLAST = {"twin_hmg": 0.0, "cannon": 5.5, "rocket": 9.0, "bazooka": 6.5, "autocannon": 2.2}
if __name__ == "__main__":
    print("%-12s" % "target" + "".join("%16s" % w for w in W))
    for t in HP:
        print("%-12s" % t + "".join("%16s" % ("%d/%.1fs" % hits_to_kill(w, t)) for w in W))
    print()
    for t in HP:
        sc = {w: hits_to_kill(w, t)[1] for w in W}
        b = min(sc, key=sc.get); print("%-11s best %-10s %5.1f  worst %-10s %5.1f" % (t, b, sc[b], max(sc, key=sc.get), max(sc.values())))
