class_name CoastalTerrain
extends RefCounted
## Shared height field for the coastal milestone: mesh, actors and ballistics agree.

static func height_at(x: float, z: float) -> float:
	var beach: float = lerpf(-1.35, 5.2, smoothstep(-38.0, 82.0, z))
	var dunes: float = sin(x * 0.021 + 1.3) * cos(z * 0.017) * 1.1 + sin(x * 0.052 + z * 0.031) * 0.45
	var dune_mask: float = smoothstep(28.0, 70.0, z)
	var ripples: float = sin(x * 0.9 + z * 0.35) * 0.035 * (1.0 - smoothstep(-5.0, 25.0, z))
	var h: float = beach + dunes * dune_mask + ripples
	var pad: float = 1.0 - smoothstep(10.0, 26.0, Vector2(x, z - 58.0).length())
	h = lerpf(h, 4.1, pad)
	return h
