"""Phase 3.6 realistic aim sweep: time-to-kill and hit rate at 0.5, 1.5 and 3.0 degrees of aim error, n=200.

Writes realistic_aim_sweep.txt next to this file. Aircraft use the shipped lead (cs.LEAD_AIRCRAFT = True).
Ranking and assumptions only: a model of the Godot damage rules, not a game measurement.
Run (needs numpy, in the background; takes minutes):  PYTHONPATH=/home/user/pylibs python3 realistic_aim_sweep.py
"""
import os

import combat_sim as cs

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "realistic_aim_sweep.txt")
N = 200
lines = ["Phase 3.6 realistic aim sweep (model; ranking only, not a game measurement)",
         "Cells: time-to-kill (mean, flight time included) / hit rate / shots fired (mean). Aircraft lead on."]
cs.LEAD_AIRCRAFT = True
for aim in (0.5, 1.5, 3.0):
    lines.append("")
    lines.append("## realistic | aim error %.1f deg | n=%d" % (aim, N))
    lines.append("target     " + "  ".join("%-22s" % w for w in cs.WEAPONS))
    for name in cs.TARGETS:
        cells = []
        for w in cs.WEAPONS:
            r = cs.engagement(name, w, "realistic", n=N, aim_err_deg=aim)
            ttk = "no kill" if r["ttk"] == float("inf") else "%.2fs" % r["ttk"]
            cells.append("%-22s" % ("%s hit%.2f sh%s" % (ttk, r["hit_rate"], r["shots"])))
        lines.append("%-10s " % name + "  ".join(cells))
        print(aim, name, flush=True)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
print("wrote", OUT)
