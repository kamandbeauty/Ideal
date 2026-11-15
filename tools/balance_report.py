#!/usr/bin/env python3
"""A headless copy of the desert economy, for balancing and for the review.

It mirrors `BusinessState`/`TownState` (same formulas, same costs) and drives them
with the same greedy policy as `AutoUpgrade`: unlock what you can afford, then buy
the upgrade with the fastest payback, always keeping a cash reserve.

    python3 tools/balance_report.py            # print the milestone table
    python3 tools/balance_report.py --minutes 600

Nothing here is shipped; it exists so a change to a price or a multiplier can be
checked against a curve instead of a hunch.
"""

from __future__ import annotations

import argparse
import math

MAX_LEVEL = 5
MAX_BRANCH = 5
MAX_MANAGER = 4

BUSINESSES = {
    "gas_station": dict(plot=(-5, 6), unlock=0, price=30, capacity=6, demand=10,
                        upkeep=30, upgrade=850, branch=480, manager=900),
    "restaurant": dict(plot=(5, 6), unlock=1400, price=40, capacity=5, demand=9,
                       upkeep=36, upgrade=980, branch=520, manager=1000),
    "store": dict(plot=(5, 0), unlock=1100, price=25, capacity=8, demand=8,
                  upkeep=24, upgrade=760, branch=420, manager=800),
    "workshop": dict(plot=(-5, 0), unlock=2000, price=60, capacity=3, demand=5,
                     upkeep=45, upgrade=1250, branch=620, manager=1200),
    "motel": dict(plot=(-5, -6), unlock=3500, price=80, capacity=4, demand=4,
                  upkeep=60, upgrade=1800, branch=900, manager=1600),
    "car_wash": dict(plot=(5, -6), unlock=2600, price=20, capacity=7, demand=7,
                     upkeep=28, upgrade=1400, branch=700, manager=1300),
}

STARTING_CASH = 1500.0
TRAFFIC = 1.0
INCOME = 1.0
COST_SCALE = 1.0
CUSTOMER_REPUTATION = 0.5
RESERVE_FRACTION = 0.0
TIP_COOLDOWN = 6.0
TIP_SECONDS = 2.0


class Building:
    def __init__(self, bid: str, unlocked: bool):
        self.id = bid
        self.data = BUSINESSES[bid]
        self.unlocked = unlocked
        self.level = 1
        self.capacity = 0
        self.speed = 0
        self.quality = 0
        self.manager = 0

    # --- the same formulas as the game ------------------------------------
    def cap(self) -> float:
        return self.data["capacity"] * (1 + 0.3 * (self.level - 1)) * (1 + 0.2 * self.capacity)

    def throughput(self) -> float:
        return 1 + 0.08 * (self.level - 1) + 0.12 * self.speed

    def qual(self) -> float:
        return 1 + 0.1 * (self.level - 1) + 0.15 * self.quality

    def price(self) -> float:
        return self.data["price"] * self.qual()

    def upkeep(self) -> float:
        return self.data["upkeep"] * (1 + 0.12 * (self.level - 1))

    def demand(self) -> float:
        return self.data["demand"] * TRAFFIC * (1 + 0.15 * (self.level - 1))

    def served(self) -> float:
        return min(self.demand(), self.cap() * self.throughput())

    def net(self) -> float:
        if not self.unlocked:
            return 0.0
        profit = max(0.0, self.served() * self.price() - self.upkeep())
        return profit * (0.6 + 0.1 * self.manager)

    def net_with(self, **changes) -> float:
        saved = (self.level, self.capacity, self.speed, self.quality, self.manager)
        for key, value in changes.items():
            setattr(self, key, value)
        value = self.net()
        self.level, self.capacity, self.speed, self.quality, self.manager = saved
        return value

    # --- costs ------------------------------------------------------------
    def unlock_cost(self) -> float:
        return (self.data["unlock"]) * COST_SCALE

    def level_cost(self) -> float:
        return 0.0 if self.level >= MAX_LEVEL else self.data["upgrade"] * 1.75 ** (self.level - 1) * COST_SCALE

    def branch_cost(self) -> float:
        return self.data["branch"] * 1.6 ** min(self.capacity, self.speed, self.quality) * COST_SCALE

    def manager_cost(self) -> float:
        return 0.0 if self.manager >= MAX_MANAGER else self.data["manager"] * 2.0 ** self.manager * COST_SCALE


def best_branch(b: Building):
    """Which branch the greedy buyer would take next, and what it costs."""
    top = min(b.level, MAX_BRANCH)
    options = []
    if b.capacity < top:
        options.append(("capacity", b.capacity, b.data["branch"] * 1.6 ** b.capacity * COST_SCALE,
                        b.net_with(capacity=b.capacity + 1) - b.net()))
    if b.speed < top:
        options.append(("speed", b.speed, b.data["branch"] * 1.6 ** b.speed * COST_SCALE,
                        b.net_with(speed=b.speed + 1) - b.net()))
    if b.quality < top:
        options.append(("quality", b.quality, b.data["branch"] * 1.6 ** b.quality * COST_SCALE,
                        b.net_with(quality=b.quality + 1) - b.net()))
    return options


def simulate(minutes: float = 240.0, dt: float = 1.0, tap_every: float = 0.0):
    buildings = {bid: Building(bid, bid == "gas_station") for bid in BUSINESSES}
    cash = STARTING_CASH
    reputation = 0.0
    elapsed = 0.0
    milestones: list[tuple[float, str]] = []
    seen: set[str] = set()
    tap_clock = 0.0
    idle_seconds = 0.0
    tap_total = 0.0

    def mark(name: str) -> None:
        if name not in seen:
            seen.add(name)
            milestones.append((elapsed, name))

    while elapsed < minutes * 60.0:
        net = sum(b.net() for b in buildings.values()) * INCOME / 60.0
        cash += net * dt
        reputation += sum(b.served() for b in buildings.values()) / 60.0 * dt * CUSTOMER_REPUTATION

        if tap_every > 0.0:
            tap_clock -= dt
            if tap_clock <= 0.0:
                tap_clock = tap_every
                best = max((b for b in buildings.values() if b.unlocked), key=lambda b: b.net())
                tip = max(5.0, best.net() / 60.0 * TIP_SECONDS)
                cash += tip
                tap_total += tip

        # AutoUpgrade: cheapest sensible action, never dipping below the reserve.
        reserve = max(150.0, net * 60.0 * 1.5) * RESERVE_FRACTION
        acted = False
        locked = [b for b in buildings.values() if not b.unlocked]
        locked.sort(key=lambda b: b.unlock_cost())
        if locked and cash - locked[0].unlock_cost() >= reserve:
            target = locked[0]
            cash -= target.unlock_cost()
            target.unlocked = True
            mark("open " + target.id)
            acted = True
        else:
            candidates = []
            for b in buildings.values():
                if not b.unlocked:
                    continue
                if b.level < MAX_LEVEL:
                    cost = b.level_cost()
                    gain = b.net_with(level=b.level + 1) - b.net()
                    candidates.append(("level", b, cost, gain))
                if b.manager < MAX_MANAGER:
                    cost = b.manager_cost()
                    gain = b.net_with(manager=b.manager + 1) - b.net()
                    candidates.append(("manager", b, cost, gain))
                for name, _rank, cost, gain in best_branch(b):
                    candidates.append((name, b, cost, gain))
            candidates = [c for c in candidates if c[2] > 0]
            candidates.sort(key=lambda c: (c[2] / max(c[3], 0.01)))
            for name, b, cost, _gain in candidates:
                if cash - cost >= reserve:
                    cash -= cost
                    if name == "level":
                        b.level += 1
                        mark("level %d %s" % (b.level, b.id))
                    elif name == "manager":
                        b.manager += 1
                        mark("manager %d %s" % (b.manager, b.id))
                    else:
                        setattr(b, name, getattr(b, name) + 1)
                        mark("branch %s %s" % (name, b.id))
                    acted = True
                    break

        if all(b.unlocked for b in buildings.values()) and all(
            b.level == MAX_LEVEL and b.manager == MAX_MANAGER for b in buildings.values()
        ):
            mark("town complete*")
            break

        if not acted:
            idle_seconds += dt
        elapsed += dt

    milestones.append((elapsed, "simulation end"))
    return milestones, cash, reputation, idle_seconds, tap_total


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--minutes", type=float, default=240.0)
    parser.add_argument("--tap", type=float, default=0.0, help="seconds between taps, 0 = never")
    args = parser.parse_args()
    marks, cash, reputation, idle, tap_total = simulate(args.minutes, tap_every=args.tap)

    print(f"simulated {args.minutes:.0f} minutes"
          + (f", tapping every {args.tap:.0f}s" if args.tap else ", never tapping"))
    print(f"{'time':>10}  milestone")
    for when, name in marks:
        print(f"{when / 60.0:9.1f}m  {name}")
    print(f"\ncash {cash:,.0f}   reputation {reputation:,.0f}   "
          f"idle waiting {idle / 60.0:.0f}m   tips {tap_total:,.0f}")
    if marks:
        first = marks[0][0]
        print(f"first action at {first:.0f}s")


if __name__ == "__main__":
    main()
