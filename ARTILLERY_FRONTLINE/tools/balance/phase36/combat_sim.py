"""Phase 3.6 combat simulator (Monte Carlo, numpy). Ports the damage rules of the Godot source.

Modelled: straight bullet flight with per-axis uniform spread (coastal_controller._on_weapon_fired),
gravity 2.2 m/s^2 for blast rounds (coastal_bullet.gd), life 4.0 s (blast) / 2.4 s, sphere hit tests on
the target's position at each instant (no lead: the aim assist aims at where the target is when firing),
ground impacts with blast, blast grounding (coastal_controller._blast_point), vehicle and craft splash with
falloff (react_to_explosion), armour (DamageModel), criticals and soldier headshots (rolled per hit),
per-weapon magazine and reload, and the shared fire schedule (interval, reload on empty).
NOT modelled: cover and terrain occlusion, reserve ammo (shared 999 pool), player reaction time, traffic.
Targets are sphere approximations."""
import math
import numpy as np

DAMAGE_SCALE = 0.55
LEAD_AIRCRAFT = False
# (orbit radius, altitude, angular speed rad/s); source: enemy_aircraft.gd configure()
AIR = {"heli": (95.0, 30.0, 0.14), "fighter": (150.0, 58.0, 0.28)}
G_BLAST = 2.2
EMP = np.array([0.0, 4.1, 58.0])   # emplacement base (pad height from coastal_controller line 62)
EYE = np.array([0.0, 5.7, 58.0])   # camera: emplacement + 1.65 m
UP = np.array([0.0, 1.0, 0.0])

# coastal_weapon.gd WEAPONS
WEAPONS = {
    "twin_hmg": dict(damage=20.0, interval=0.085, magazine=140, reload=2.3, speed=430.0, spread=0.65, blast=0.0),
    "cannon": dict(damage=150.0, interval=1.15, magazine=12, reload=3.4, speed=260.0, spread=0.18, blast=5.5),
    "rocket": dict(damage=170.0, interval=0.72, magazine=6, reload=3.0, speed=115.0, spread=0.35, blast=9.0),
    "bazooka": dict(damage=240.0, interval=1.05, magazine=4, reload=3.2, speed=140.0, spread=0.25, blast=6.5),
    "autocannon": dict(damage=42.0, interval=0.16, magazine=70, reload=2.7, speed=380.0, spread=0.45, blast=2.2),
}

# Enemy entities. hp/armor from the scripts; hc = hit centre height above pivot; r = hit radius (approx).
# pivot: soldiers and vehicles stand on the ground; aircraft pivot is the flight centre; craft pivot is the waterline.
TARGETS = {
    "rifle": dict(hp=20.0, armor=0.0, kind="soldier", hc=0.95, r=0.75, crit=0.12, real=[30.0, 45.0, 60.0], direct=40.0, motion="static"),
    "heavy": dict(hp=36.0, armor=0.5, kind="soldier", hc=0.95, r=0.75, crit=0.12, real=[22.0, 30.0], direct=22.0, motion="static"),
    "rpg": dict(hp=20.0, armor=0.0, kind="soldier", hc=0.95, r=0.75, crit=0.12, real=[40.0, 55.0], direct=40.0, motion="static"),
    "jeep": dict(hp=90.0, armor=1.0, kind="vehicle", hc=1.0, r=1.5, crit=0.08, real=[40.0, 60.0], direct=40.0, motion="strafe"),
    "apc": dict(hp=220.0, armor=1.0, kind="vehicle", hc=1.2, r=2.0, crit=0.08, real=[16.0, 24.0, 32.0], direct=30.0, motion="static"),
    "tank": dict(hp=260.0, armor=1.0, kind="vehicle", hc=1.2, r=2.2, crit=0.08, real=[16.0, 24.0, 32.0], direct=30.0, motion="static"),
    "boss": dict(hp=900.0, armor=1.0, kind="vehicle", hc=1.6, r=3.2, crit=0.08, real=[16.0, 24.0], direct=20.0, motion="static"),
    "heli": dict(hp=320.0, armor=0.0, kind="aircraft", hc=0.0, r=3.4, crit=0.0, real=[], direct=0.0, motion="heli"),
    "fighter": dict(hp=240.0, armor=0.0, kind="aircraft", hc=0.0, r=4.2, crit=0.0, real=[], direct=0.0, motion="fighter"),
    "craft": dict(hp=600.0, armor=0.0, kind="craft", hc=1.0, r=5.0, crit=0.0, real=[40.0, 100.0], direct=100.0, motion="craft"),
}


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def terrain(x, z):
    """Port of coastal_terrain.gd height_at."""
    beach = -1.35 + (5.2 + 1.35) * smoothstep(-38.0, 82.0, z)
    dunes = np.sin(x * 0.021 + 1.3) * np.cos(z * 0.017) * 1.1 + np.sin(x * 0.052 + z * 0.031) * 0.45
    dune_mask = smoothstep(28.0, 70.0, z)
    ripples = np.sin(x * 0.9 + z * 0.35) * 0.035 * (1.0 - smoothstep(-5.0, 25.0, z))
    h = beach + dunes * dune_mask + ripples
    pad = 1.0 - smoothstep(10.0, 26.0, np.hypot(x, z - 58.0))
    return h * (1.0 - pad) + 4.1 * pad


def ground_at(x, z):
    """coastal_controller._blast_point: blasts ground at max(terrain, 0) (sea level)."""
    return np.maximum(terrain(x, z), 0.0)


def hit_res(a):
    return np.where(a <= 25.0, 0.78, np.where(a < 100.0, 0.35, 0.1))


def taken(amount, armor):
    """DamageModel.taken = amount * (1 - clamp(armor * hit_resistance(amount), 0, 0.9))."""
    res = np.clip(armor * hit_res(amount), 0.0, 0.9)
    return amount * (1.0 - res)


def pivot_at(name, cfg, T, s):
    """Pivot positions (n,3) at absolute time T. s holds per-sample phase (s.phase), start (s.start),
    and whether motion is on (s.moving)."""
    n = s["phase"].shape[0]
    mv = s["moving"]
    m = cfg["motion"]
    if m == "heli" or m == "fighter":
        R, alt, w = AIR[m]
        ang = s["phase"] + (w * T if mv else 0.0)
        x = EMP[0] + np.cos(ang) * R
        z = EMP[2] + np.sin(ang) * R * 0.7 - 20.0
        return np.stack([x, np.full(n, alt), z], axis=1)
    if m == "strafe":
        ang = s["phase"] + ((5.0 / 40.0) * T if mv else 0.0)
        x = np.cos(ang) * 40.0
        z = EMP[2] + np.sin(ang) * 40.0
        return np.stack([x, terrain(x, z), z], axis=1)
    if m == "craft":
        z = np.minimum(-12.0, s["start"] + (12.5 * T if mv else 0.0))
        return np.stack([np.zeros(n), np.zeros(n), z], axis=1)
    # static ground unit straight ahead; s["start"] holds its distance from the emplacement
    z = EMP[2] - s["start"]
    x = np.zeros(n)
    return np.stack([x, terrain(x, z), z], axis=1)


def fire_once(rng, name, cfg, wpn, T, s, aim_ground, spread_on, aim_err_deg=0.0):
    """One shot per sample, fired at absolute time T. Returns (direct, splash, arrival, event)."""
    n = s["phase"].shape[0]
    pivot = pivot_at(name, cfg, T, s)
    if aim_ground:
        gz = pivot[:, 2] + 2.0
        gx = pivot[:, 0]
        aim = np.stack([gx, terrain(gx, gz), gz], axis=1)
    else:
        aim = pivot + np.array([0.0, 1.2, 0.0])   # aim_assist aims at +1.2 m
        if LEAD_AIRCRAFT and cfg["kind"] == "aircraft":
            # intercept: aim where the aircraft will be when the round arrives (two refinements)
            for _ in range(2):
                tof = np.linalg.norm(aim - EYE, axis=1) / wpn["speed"]
                ahead = pivot_at(name, cfg, T + tof, s)
                aim = ahead + np.array([0.0, 1.2, 0.0])
    d = aim - EYE
    d = d / np.linalg.norm(d, axis=1, keepdims=True)
    right = np.cross(d, UP)
    right = right / np.linalg.norm(right, axis=1, keepdims=True)
    up2 = np.cross(right, d)
    if spread_on and wpn["spread"] > 0.0:
        s_rad = math.radians(wpn["spread"])
        ox = rng.uniform(-s_rad, s_rad, n)
        oy = rng.uniform(-s_rad, s_rad, n)
        d = d + np.tan(ox)[:, None] * right + np.tan(oy)[:, None] * up2
        d = d / np.linalg.norm(d, axis=1, keepdims=True)
    if aim_err_deg > 0.0:
        e = math.radians(aim_err_deg)
        ex = rng.uniform(-e, e, n)
        ey = rng.uniform(-e, e, n)
        d = d + np.tan(ex)[:, None] * right + np.tan(ey)[:, None] * up2
        d = d / np.linalg.norm(d, axis=1, keepdims=True)
    v = d * wpn["speed"]
    blast = wpn["blast"]
    life = 4.0 if blast > 0.0 else 2.4
    dt = 0.02
    steps = int(round(life / dt))
    done = np.zeros(n, dtype=bool)
    event = np.zeros(n, dtype=int)  # 0 none, 1 target, 2 ground
    arrival = np.full(n, np.nan)
    point = np.zeros((n, 3))
    margin = wpn["speed"] * dt
    prev = np.broadcast_to(EYE, (n, 3)).astype(float).copy()
    for k in range(1, steps + 1):
        tau = k * dt
        p = EYE[None, :] + v * tau
        if blast > 0.0:
            p[:, 1] -= 0.5 * G_BLAST * tau * tau
        # exact segment-sphere entry against the target's position at the segment end
        tgt = pivot_at(name, cfg, T + tau, s)
        C = tgt + np.array([0.0, cfg["hc"], 0.0])
        A = prev
        D = p - A
        F = A - C
        a = np.einsum("ij,ij->i", D, D)
        b = 2.0 * np.einsum("ij,ij->i", F, D)
        c = np.einsum("ij,ij->i", F, F) - cfg["r"] ** 2
        disc = b * b - 4.0 * a * c
        ok = (disc >= 0.0) & (a > 0.0)
        sq = np.sqrt(np.maximum(disc, 0.0))
        t_in = (-b - sq) / (2.0 * np.maximum(a, 1e-12))
        hit_seg = (~done) & ok & (t_in >= 0.0) & (t_in <= 1.0)
        ground_now = (~done) & (~hit_seg) & (p[:, 1] <= terrain(p[:, 0], p[:, 2]))
        new = hit_seg | ground_now
        if new.any():
            entry = A + np.clip(t_in, 0.0, 1.0)[:, None] * D
            event[hit_seg] = 1
            event[ground_now] = 2
            arrival[new] = tau
            point[new] = np.where(hit_seg[new][:, None], entry[new], p[new])
            done |= new
        if done.all():
            break
        prev = p
    kind = cfg["kind"]
    direct = np.zeros(n)
    splash = np.zeros(n)
    hit = event == 1
    amt = np.full(n, wpn["damage"])
    if hit.any():
        if kind == "soldier":
            head = (point[:, 1] - pivot[:, 1]) >= 1.45   # EnemySoldier HEAD_HEIGHT
            scale = np.where(head, 2.2, 1.0)
            crit = rng.random(n) < cfg["crit"]
            scale = scale * np.where(crit, 1.6, 1.0)
            direct = np.where(hit, taken(amt * scale, cfg["armor"]), 0.0)
        elif kind == "vehicle":
            crit = rng.random(n) < cfg["crit"]
            direct = np.where(hit, taken(amt, 1.0) * np.where(crit, 1.6, 1.0), 0.0)
        elif kind == "craft":
            direct = np.where(hit, amt * np.where(amt <= 25.0, 0.35, 0.85), 0.0)
        else:  # aircraft: no armour, no critical
            direct = np.where(hit, amt, 0.0)
    if blast > 0.0 and (event > 0).any():
        ev = event > 0
        G = point.copy()
        G[:, 1] = ground_at(point[:, 0], point[:, 2]) + 0.08   # _blast_point grounds every blast
        dist = np.linalg.norm(G - pivot, axis=1)
        if kind == "vehicle":
            R = 1.7 * blast
            sp = np.where(dist < R, 190.0 * (1.0 - dist / R), 0.0)
            splash = np.where(ev, taken(sp, 1.0), 0.0)
        elif kind == "craft":
            R = 1.6 * blast
            sp = np.where(dist < R, 160.0 * (1.0 - dist / R), 0.0)
            sp = sp * np.where(sp <= 25.0, 0.35, 0.85)
            splash = np.where(ev, sp, 0.0)
        elif kind == "aircraft":
            R = 1.5 * blast
            sp = np.where(dist < R, 140.0 * (1.0 - dist / R), 0.0)
            splash = np.where(ev, sp, 0.0)
        # soldiers: blasts only stagger (EnemySoldier.react_to_explosion), no hit points
    return direct, splash, arrival, event


def engagement(name, weapon_name, scenario, n=300, seed=1, max_shots=260, aim_err_deg=0.0):
    cfg = TARGETS[name]
    wpn = WEAPONS[weapon_name]
    rng = np.random.default_rng(seed)
    s = {"phase": np.zeros(n), "start": np.zeros(n), "moving": scenario == "realistic"}
    real = scenario == "realistic"
    if cfg["motion"] in ("heli", "fighter"):
        s["phase"] = rng.uniform(0.0, 2.0 * math.pi, n) if real else np.zeros(n)
    elif cfg["motion"] == "strafe":
        s["phase"] = rng.uniform(0.0, 2.0 * math.pi, n) if real else np.zeros(n)
        s["start"] = np.full(n, 40.0)
    elif cfg["motion"] == "craft":
        s["start"] = rng.choice(np.array(cfg["real"]), n) if real else np.full(n, cfg["direct"])
        # craft start z = 58 - distance (sea side), then sail to -12
        s["start"] = EMP[2] - s["start"]
    else:
        s["start"] = rng.choice(np.array(cfg["real"]), n) if real else np.full(n, cfg["direct"])
    aim_ground = scenario == "splash"
    hp = np.full(n, cfg["hp"])
    alive = np.ones(n, dtype=bool)
    t_kill = np.full(n, np.nan)
    shots = np.zeros(n)
    hits = np.zeros(n)
    dsum = np.zeros(n)
    ssum = np.zeros(n)
    t = 0.0
    ammo = wpn["magazine"]
    for _ in range(max_shots):
        if not alive.any():
            break
        direct, splash, arrival, event = fire_once(rng, name, cfg, wpn, t, s, aim_ground, real, aim_err_deg)
        shots += alive
        hits += ((event == 1) & alive)
        dsum += direct * alive
        ssum += splash * alive
        hp = hp - (direct + splash) * alive
        newly = alive & (hp <= 0.0)
        t_kill[newly] = t + arrival[newly]
        alive = alive & ~newly
        t += wpn["interval"]
        ammo -= 1
        if ammo == 0:
            t += wpn["reload"]
            ammo = wpn["magazine"]
    killed = ~np.isnan(t_kill)
    total_dmg = dsum.sum() + ssum.sum()
    return dict(
        target=name, weapon=weapon_name, scenario=scenario,
        kill=round(float(killed.mean()), 3),
        ttk=round(float(np.nanmean(t_kill)), 2) if killed.any() else float("inf"),
        shots=round(float(shots[killed].mean()), 1) if killed.any() else float("inf"),
        hit_rate=round(float(hits.sum() / max(1.0, shots.sum())), 3),
        splash_share=round(float(ssum.sum() / max(1e-9, total_dmg)), 3),
    )


if __name__ == "__main__":
    import sys
    scen = sys.argv[1] if len(sys.argv) > 1 else "direct"
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    for name in TARGETS:
        cells = []
        for w in WEAPONS:
            r = engagement(name, w, scen, n=n)
            cells.append("%s: ttk=%s kill=%.2f hit=%.2f spl=%.2f" % (w, r["ttk"], r["kill"], r["hit_rate"], r["splash_share"]))
        print(name)
        for c in cells:
            print("   ", c)
