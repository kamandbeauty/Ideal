class_name FireControl
extends RefCounted
## Line-of-fire rules for direct-fire infantry. A shot is only taken when the straight line from
## the shooter to the target stays above the ground and clears terrain and cover (physics layer 1).
## Corpses (layer 16) and other hostile units (layer 2) do not block sight.

const SIGHT_MASK: int = 1
const SAMPLES: int = 12
## Minimum clearance above the analytic ground for the sight line to be unobstructed.
const CLEARANCE: float = 0.05

static func line_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	for index in range(1, SAMPLES):
		var point: Vector3 = from.lerp(to, float(index) / float(SAMPLES))
		if point.y < CoastalTerrain.height_at(point.x, point.z) + CLEARANCE:
			return false
	if space == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, SIGHT_MASK)
	return space.intersect_ray(query).is_empty()
