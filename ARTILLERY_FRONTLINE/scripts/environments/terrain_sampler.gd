class_name TerrainSampler
extends RefCounted

static func height_at(x: float, z: float) -> float:
	var h: float = 2.0 + sin(x * 0.012 + 1.0) * cos(z * 0.009) * 5.0 + sin(x * 0.029 + z * 0.015) * 2.2
	h = lerpf(h, 2.0, 1.0 - smoothstep(20.0, 65.0, Vector2(x, z - 105.0).length()))
	h = lerpf(h, 0.5, 1.0 - smoothstep(115.0, 190.0, Vector2(x * 0.85, z + 295.0).length()))
	var edge: float = maxf(absf(x) - 280.0, absf(z + 130.0) - 410.0)
	if edge > 0.0:
		h += maxf(0.0, pow(edge / 160.0, 1.35) * (36.0 + sin(x * 0.019 + z * 0.011) * 19.0 + cos(z * 0.027) * 12.0))
	return h
