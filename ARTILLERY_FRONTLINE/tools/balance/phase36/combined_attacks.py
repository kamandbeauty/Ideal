"""Phase 3.6 combined-attack model (ranking and magnitude only; not a game measurement).

Enemy side, from source: fire interval and damage per shot (infantry_role.gd, enemy_vehicle.gd,
enemy_aircraft.gd), emplacement damage = damage * DAMAGE_SCALE (0.55, coastal_controller.gd).
Player side: time to kill each unit with its best weapon, from combat_sim.py (realistic, aim error 0.5 deg,
lead on for aircraft). Kills are sequential; SWITCH_S is an assumed retarget/aim delay.
Assumptions: every enemy is already in position at t=0 (upper bound); enemy hits on the emplacement
happen with probability P_HIT (not measured: bounded at 0.3 and 1.0); blasts on the emplacement are ignored.
Run: PYTHONPATH=<numpy dir> python3 combined_attacks.py
"""
import os

import combat_sim as cs

DAMAGE_SCALE = 0.55
EMPLACEMENT_HP = 6000.0
SWITCH_S = 1.0
P_HIT = (0.3, 1.0)
AIM_ERR = 0.5
N = 100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "combined_attacks.txt")

# Expected emplacement damage per second per unit, before P_HIT (source values).
# rifle: 12-22 dmg, one shot per 2.4 s on average (1.6-3.2 s). heavy: 13-17 dmg, burst of 3 every 4.2 s.
# rpg: 50 dmg rocket every 5.0 s (reload). tank 150/4.6 s, apc 40/3.2 s, jeep 14/2.0 s, boss 220/3.8 s.
# heli 55/3.2 s, fighter 90/5.0 s.
ENEMY = {
    "rifle": dict(rate=1.0 / 2.4, dmg=17.0, target="rifle"),
    "heavy": dict(rate=3.0 / 4.2, dmg=15.0, target="heavy"),
    "rpg": dict(rate=1.0 / 5.0, dmg=50.0, target="rpg"),
    "jeep": dict(rate=1.0 / 2.0, dmg=14.0, target="jeep"),
    "apc": dict(rate=1.0 / 3.2, dmg=40.0, target="apc"),
    "tank": dict(rate=1.0 / 4.6, dmg=150.0, target="tank"),
    "boss": dict(rate=1.0 / 3.8, dmg=220.0, target="boss"),
    "heli": dict(rate=1.0 / 3.2, dmg=55.0, target="heli"),
    "fighter": dict(rate=1.0 / 5.0, dmg=90.0, target="fighter"),
}

SCENARIOS = {
    # Wave 2 soldiers: 12 = 2 heavy + 2 RPG + 8 riflemen (wave_manager.gd). Subsets are shown as the combined pair.
    "Heavy + riflemen (2 heavy, 8 riflemen)": ["heavy"] * 2 + ["rifle"] * 8,
    "RPG + infantry (2 RPG, 8 riflemen)": ["rpg"] * 2 + ["rifle"] * 8,
    "Tank + APC": ["tank", "apc"],
    "Boss + tank": ["boss", "tank"],
    "Aircraft + ground (2 heli, 2 fighter, 8 riflemen)": ["heli"] * 2 + ["fighter"] * 2 + ["rifle"] * 8,
    "Armour + infantry (tank, APC, jeep, 8 riflemen)": ["tank", "apc", "jeep"] + ["rifle"] * 8,
    # Wave 3 soldiers: 20 = 4 heavy + 3 RPG + 13 riflemen; plus boss, tank, APC, 2 heli, 2 fighter (craft excluded).
    "Wave 3 (all types, craft excluded)": ["boss", "tank", "apc"] + ["heli"] * 2 + ["fighter"] * 2 + ["heavy"] * 4 + ["rpg"] * 3 + ["rifle"] * 13,
}


def best_ttk():
    """Best realistic time to kill per target type, and the weapon that achieves it."""
    table = {}
    for target in ENEMY:
        best = (float("inf"), None)
        for w in cs.WEAPONS:
            r = cs.engagement(target, w, "realistic", n=N, aim_err_deg=AIM_ERR)
            if r["kill"] >= 0.95 and r["ttk"] < best[0]:
                best = (r["ttk"], w)
        table[target] = best
    return table


def run_scenario(units, ttk, p_hit):
    """Greedy kill order: most damage per second removed per second of work first."""
    rows = []
    for u in units:
        spec = ENEMY[u]
        dps = spec["rate"] * spec["dmg"] * DAMAGE_SCALE * p_hit
        t_kill, weapon = ttk[spec["target"]]
        rows.append((dps / (t_kill + SWITCH_S), u, dps, t_kill + SWITCH_S, weapon))
    rows.sort(reverse=True)
    clock = 0.0
    total = 0.0
    for _, u, dps, work, _ in rows:
        clock += work
        total += dps * clock
    alive_dps = sum(r[2] for r in rows)
    return total, clock, alive_dps, rows


def main():
    cs.LEAD_AIRCRAFT = True  # shipped behaviour: shots at aircraft are led
    ttk = best_ttk()
    lines = []
    lines.append("Phase 3.6 combined attacks (model). Player best weapon per type, realistic aim 0.5 deg, lead on.")
    lines.append("Time to kill (best weapon, realistic): " + ", ".join(
        "%s %.2fs (%s)" % (k, v[0], v[1]) for k, v in ttk.items()))
    for p_hit in P_HIT:
        lines.append("")
        lines.append("P_HIT = %.1f  (emplacement HP %d)" % (p_hit, EMPLACEMENT_HP))
        lines.append("%-52s %10s %10s %10s %10s" % ("Scenario", "damage", "% HP", "clear s", "start dps"))
        for name, units in SCENARIOS.items():
            total, clock, start_dps, rows = run_scenario(units, ttk, p_hit)
            lines.append("%-52s %10.0f %9.0f%% %10.1f %10.1f" % (name, total, 100.0 * total / EMPLACEMENT_HP, clock, start_dps))
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
