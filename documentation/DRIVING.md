# Vehicle circulation and mobile art pass

## Physical rules

- `VehicleBody` is a **CharacterBody3D**, not a visual node moved by direct position addition. A full-size swept box includes wheels, mirrors and bumpers. Cars brake rather than push one another.
- Touch targets use layer **1**; vehicles use **2**; buildings and service equipment use **4**. Vehicle masks are **6**. A large mobile tap target is never mistaken for a wall.
- A forward shape cast sets a braking speed; `move_and_collide` sweeps against physical bodies, and an additional oriented-box check against live vehicle transforms rejects penetration-recovery displacements during accelerated/hitchy ticks. Rotational clearance is checked before changing heading. Large frame deltas are subdivided into angular/motion steps.
- Highway recycling and customer spawning require free space, including bodies spawned during the same physics tick. No wrap-around teleport can land inside a vehicle.

## Route and parking ownership

`ForecourtLayout` is the single source of world coordinates for both the visual scene and the simulation:

1. Turn right off the near highway lane into the west/southbound spine.
2. Follow the assigned row's eastbound aisle, then turn into a reserved bay.
3. **Begin service only after reaching the bay.** A pending reservation has no running service timer.
4. Obtain the row manoeuvre lock, reverse into the aisle, and wait off the east spine. A FIFO corridor reservation admits one turning/exiting customer at a time; it releases once that customer has safely merged. This prevents a turning tail and through traffic from trapping each other on the narrow single-lane exit.
5. Wait outside the highway. Highway vehicles that can safely stop yield upstream; vehicles already in the junction continue through. Merge only after the junction clears.

Bay coordinates are based on the facility's maximum footprint, not its current capacity. Upgrading capacity exposes more bays without recentering existing cars. A slot remains owned until its departing vehicle has cleared the row. Parked cars never hold a manoeuvre lock, and departures get priority over new arrivals.

The visual traffic remains separate from the statistical idle economy: neither graphics quality nor a highway queue changes saved income/progression. Existing save data and business IDs remain compatible.

## Art and performance

- Subtle, neutral grass, asphalt, concrete, sand and plaster maps are baked by `tools/build_surface_textures.py` (fixed seeds, no external downloads or runtime noise shader).
- Cached low-poly chamfer geometry catches edge highlights on cars, roofs, signs and props. Framed windows, sills, skirting, wheel hubs, bumpers, mirrors and brake lamps add depth without expensive reflections.
- Neutral daylight, matte materials and soft directional shadows retain the lime/grey/orange reference palette. White kerbs, lawn islands, pitched tile roofs and original illustrated navigation replace the earlier dark/desert presentation; see [art direction](ART_DIRECTION.md). Small contact shadows work in the GL Compatibility renderer, without SSAO.
- Numbered bays, lane arrows and separate IN/OUT driveways communicate the actual traffic routes. Pedestrians stay on storefront pavement. Bay numbers switch between Persian and English without rebuilding or moving the bays.
- `ServiceEffects` is parent-owned rendering only: fixed 0 / 6 / 10-particle MultiMesh pools, service pictograms, connected fuel/EV cables and rotating wash brushes. It starts only once parked and hides at payment, before reversing. The counter-rotation used by the visuals never changes a vehicle transform or collider. No effect writes income, queue reservations or save data.
- Low quality disables real-time directional shadows; high adds 2× MSAA; medium uses FXAA. Existing customer/pedestrian caps and the night-light budget still apply; highway traffic is capped at 6 / 8 / 10 vehicles for low / medium / high. No rigid-body pile-ups, RVO swarm or real-time GI is required.

## Reproducible validation

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . res://tools/traffic_check.tscn
```

The unit suites check shell-vs-solid bounds, UI text contrast, orthographic zoom, the lightweight art budget, stable/non-overlapping bays, all car/camper/monster routes against every building and service obstacle, service-on-arrival, braking and collision layers.

The PhysicsServer integration scenario runs **six simulated minutes**, including a low customer cap, capacity upgrades while customers are present, all eight facilities, and a high-cap monster-truck event. Every physics tick checks vehicle/vehicle penetration, vehicle/scenery penetration, slot ownership, progress and the service-feedback lifecycle. It also verifies all eight effect types and live low/medium/high pool budgets. It also requires visits to every business and a minimum number of completed highway-to-highway journeys; merely stopping every car cannot pass.

The 21-capture rendered smoke walkthrough additionally covers the full-hub circulation overview, a 720×1600 tall-device layout, Persian manager/facility sheets and an actual car-wash arrival at high and low quality. It waits on physics frames and captures only after `RenderingServer.frame_post_draw`, so slow software rendering does not inflate simulation waits or capture an unfinished UI frame. A device play-test is still needed to assess GPU/frame-time behaviour on a particular phone.
