"""Phase 3.6 weapon matrix. Writes phase36_matrix.txt next to this file.

Run (needs numpy):  python3 phase36_matrix.py
Ranking and assumptions only: this is a model of the Godot damage rules, not a game measurement.
"""
import os

import combat_sim as cs

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "phase36_matrix.txt")
N = 200
lines = []


def emit(text=""):
    lines.append(text)


def table(scenario, aim, lead):
    cs.LEAD_AIRCRAFT = lead
    emit("")
    emit("## %s | aim error %.1f deg | aircraft lead %s | n=%d" % (scenario, aim, "on" if lead else "off", N))
    emit("target     " + "  ".join("%-22s" % w for w in cs.WEAPONS))
    for name in cs.TARGETS:
        cells = []
        for w in cs.WEAPONS:
            r = cs.engagement(name, w, scenario, n=N, aim_err_deg=aim)
            ttk = "no kill" if r["ttk"] == float("inf") else "%.2fs" % r["ttk"]
            cells.append("%-22s" % ("%s hit%.2f sh%s" % (ttk, r["hit_rate"], r["shots"])))
        emit("%-10s " % name + "  ".join(cells))
    cs.LEAD_AIRCRAFT = False


emit("Phase 3.6 weapon matrix (combat_sim.py; ranking and assumptions only, not a game measurement)")
emit("Cells: time-to-kill (mean over samples, flight time included) / hit rate / shots fired (mean).")
table("direct", 0.0, False)
table("splash", 0.0, False)
table("realistic", 0.3, False)
table("realistic", 1.0, False)
table("realistic", 0.3, True)
table("realistic", 1.0, True)

emit("")
emit("## Aircraft orbit speed sweep (realistic, aim 0.5 deg, no lead)")
for speed in [0.28, 0.14, 0.07]:
    cs.AIR["fighter"] = (150.0, 58.0, speed)
    row = []
    for w in cs.WEAPONS:
        r = cs.engagement("fighter", w, "realistic", n=N, aim_err_deg=0.5)
        row.append("%s kill %.2f" % (w, r["kill"]))
    emit("fighter w=%.2f rad/s: %s" % (speed, "; ".join(row)))
cs.AIR["fighter"] = (150.0, 58.0, 0.28)

with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
print("wrote", OUT)
