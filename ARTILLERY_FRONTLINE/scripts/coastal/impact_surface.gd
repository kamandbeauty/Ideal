class_name ImpactSurface
extends RefCounted
## Classifies what a bullet struck so each surface gets its own feedback: a soft puff on a body,
## a hard ring and sparks on metal, and a dust spot with a small crater on sand or rock.

const FLESH: String = "flesh"
const METAL: String = "metal"
const GROUND: String = "ground"

## What the collider is made of. Enemy infantry are flesh; vehicles, craft, aircraft and barrels are metal.
static func kind_for(collider: Object) -> String:
	if collider is EnemySoldier:
		return FLESH
	if collider is EnemyVehicle or collider is EnemyAircraft or collider is LandingCraft or collider is CoastalBarrel:
		return METAL
	return GROUND

## Feedback for a surface: effect radius, impact volume in dB, and the clip it plays.
## Flesh and metal have their own clips; ground reuses the original impact clip.
static func profile(kind: String) -> Dictionary:
	match kind:
		FLESH:
			return {"radius": 0.35, "volume_db": -15.0, "sound": "impact_flesh"}
		METAL:
			return {"radius": 0.5, "volume_db": -9.0, "sound": "impact_metal"}
	return {"radius": 0.7, "volume_db": -16.0, "sound": "impact"}
