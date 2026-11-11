"""Phase 3.6 campaign model: one HP timeline, Repair and Airdrop with a player reaction delay, craft stagger.

Built on tools/balance/prototype_campaign_model.py (kill times, unload schedule, damage rates). Those damage
rates use ASSUMED hit ratios per infantry type, so the output ranks options; it is not a game measurement.
Source values: MAX_HEALTH 6000, DAMAGE_SCALE 0.55, REPAIR_AMOUNT 1500 (3 charges, 18 s cooldown, blocked at full HP),
AIRDROP_REPAIR 1000 (2 charges, 30 s cooldown, round 3 only), charges set once per mission in start(),
intermission 6.0 s (wave_manager.gd), craft travel 14.3 s (progress 0.07/s).

Player model: the player notices HP at or below a threshold T and uses the support REACT seconds later, if HP is
still at or below T. Earlier players are not modelled as worse; the reaction delay is the only timing error.
Not modelled: airstrike and helicopter support (conservative), cover, and reaction to individual units.
Run:  python3 campaign_support_model.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import prototype_campaign_model as proto  # noqa: E402

MAX_HP = proto.EMPLACEMENT_HP
INTERMISSION = 6.0
DT = 0.1
OUT = os.path.join(HERE, "campaign_support.txt")

BASE_REPAIR = dict(heal=1500.0, charges=3, cooldown=18.0)
BASE_AIRDROP = dict(heal=1000.0, charges=2, cooldown=30.0)


class Support:
    """One support with its charges, cooldown, threshold, and the moment HP first crossed the threshold."""

    def __init__(self, spec, threshold, react, allowed_round):
        self.heal = spec["heal"]
        self.charges = spec["charges"]
        self.cooldown = spec["cooldown"]
        self.threshold = threshold
        self.react = react
        self.allowed_round = allowed_round
        self.cool = 0.0
        self.since = None
        self.used = 0

    def tick(self, hp, clock, round_no):
        self.cool = max(0.0, self.cool - DT)
        if round_no not in self.allowed_round or self.charges <= 0 or hp >= MAX_HP:
            self.since = None
            return hp
        if hp > self.threshold:
            self.since = None
            return hp
        if self.since is None:
            self.since = clock
        if clock - self.since >= self.react and self.cool <= 0.0:
            self.charges -= 1
            self.cool = self.cooldown
            self.used += 1
            self.since = None
            return min(MAX_HP, hp + self.heal)
        return hp


def run_campaign(profile, craft_gap, repair_spec, airdrop_spec, threshold, react):
    """Returns dict(survived, min_hp, end_hp, used_repair, used_airdrop, damage, time)."""
    hp = MAX_HP
    repair = Support(repair_spec, threshold, react, {1, 2, 3})
    airdrop = Support(airdrop_spec, threshold, react, {3})
    min_hp = MAX_HP
    clock = 0.0
    damage = 0.0
    for index, setup in enumerate(proto.ROUNDS):
        round_no = index + 1
        queue = proto.schedule(setup, craft_gap)
        air = ["heli"] * setup.get("helicopters", 0) + ["fighter"] * setup.get("fighters", 0)
        targets = [dict(at=3.0, kind=k) for k in air] + [dict(at=at, kind=k) for at, k in queue]
        targets += [dict(at=0.0, kind="craft") for _ in range(setup.get("craft", 0))]
        allowed = profile["weapons"]
        overhead = profile["overhead"]
        reload_mult = profile.get("reload_mult", 1.0)
        hit_mult = profile.get("hit_mult", 1.0)
        t = 0.0
        current = None
        while not all(x.get("dead") for x in targets):
            if t > 900.0:
                return dict(survived=False, min_hp=min_hp, end_hp=hp, used_repair=repair.used,
                            used_airdrop=airdrop.used, damage=damage, time=clock)
            if current is None:
                cands = []
                for x in targets:
                    if x.get("dead") or x["at"] > t:
                        continue
                    w = proto.best_weapon(x["kind"], overhead, allowed, reload_mult)
                    dps = proto.TARGETS[x["kind"]]["dps"]
                    cands.append((dps / w[1] if dps > 0 else 0.0, id(x), x, w[1]))
                if cands:
                    cands.sort(key=lambda c: (-c[0], c[1]))
                    _, _, x, kt = cands[0]
                    current = (x, t + kt)
            dps_now = sum(proto.TARGETS[x["kind"]]["dps"] for x in targets
                          if not x.get("dead") and x["at"] <= t) * hit_mult
            hp -= dps_now * DT
            damage += dps_now * DT
            clock += DT
            if hp <= 0.0:
                return dict(survived=False, min_hp=0.0, end_hp=0.0, used_repair=repair.used,
                            used_airdrop=airdrop.used, damage=damage, time=clock)
            hp = repair.tick(hp, clock, round_no)
            hp = airdrop.tick(hp, clock, round_no)
            min_hp = min(min_hp, hp)
            if current is not None and t >= current[1]:
                current[0]["dead"] = True
                current = None
            t += DT
        steps = int(round(INTERMISSION / DT))
        for _ in range(steps):
            clock += DT
            hp = repair.tick(hp, clock, round_no)
            hp = airdrop.tick(hp, clock, round_no)
    return dict(survived=True, min_hp=min_hp, end_hp=hp, used_repair=repair.used,
                used_airdrop=airdrop.used, damage=damage, time=clock)


def describe(label, res):
    return ("%-46s survived=%-5s min HP=%5.0f end HP=%5.0f repair=%d airdrop=%d damage=%5.0f"
            % (label, res["survived"], res["min_hp"], res["end_hp"], res["used_repair"], res["used_airdrop"], res["damage"]))


def main():
    lines = []
    lines.append("Phase 3.6 campaign model (model, not measured). Damage rates assumed; see the module docstring.")
    lines.append("Threshold T: HP at or below which the player notices the need. React: seconds from noticing to using.")
    lines.append("'beginner' = HMG only, overhead 2.0 s (proto.PROFILES). 'min HP' is the lowest point of the mission.")
    grid = [(2500.0, 3.0), (3000.0, 3.0), (4000.0, 3.0), (4500.0, 3.0)]
    variants = [
        ("current supports, craft gap 0 s", 0.0, BASE_REPAIR, BASE_AIRDROP),
        ("current supports, craft gap 6 s", 6.0, BASE_REPAIR, BASE_AIRDROP),
    ]
    for label, gap, rep, air in variants:
        lines.append("")
        lines.append("## " + label)
        for pname, prof in proto.PROFILES.items():
            none = run_campaign(prof, gap, dict(rep, charges=0), dict(air, charges=0), 0.0, 0.0)
            lines.append(describe("%s, no support" % pname, none))
            for threshold, react in grid:
                res = run_campaign(prof, gap, rep, air, threshold, react)
                lines.append(describe("%s, T=%.0f react=%.0fs" % (pname, threshold, react), res))
    lines.append("")
    lines.append("## reaction sensitivity, craft gap 6 s, current supports (beginner and poor_ammo)")
    for pname in ("beginner", "poor_ammo"):
        prof = proto.PROFILES[pname]
        for threshold in (2500.0, 3000.0):
            for react in (3.0, 6.0, 10.0):
                res = run_campaign(prof, 6.0, BASE_REPAIR, BASE_AIRDROP, threshold, react)
                lines.append(describe("%s, T=%.0f react=%.0fs" % (pname, threshold, react), res))
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
