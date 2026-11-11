class_name DamagePlume
extends RefCounted
## Smoke and fire plumes for damaged or destroyed enemy machines. A plume is a particle child of the
## machine it belongs to, built once and kept for the wreck. It has no collision and does no damage.

## Builds one plume. `scale` sizes both the particle count and the puffs (wreck profiles use it).
static func make(parent: Node3D, local_position: Vector3, burning: bool, scale: float = 1.0) -> CPUParticles3D:
	var plume := CPUParticles3D.new()
	plume.name = "FirePlume" if burning else "SmokePlume"
	plume.amount = maxi(1, roundi((18.0 if burning else 12.0) * scale))
	plume.lifetime = 1.3 if burning else 2.8
	plume.local_coords = true
	plume.emitting = true
	plume.direction = Vector3.UP
	plume.spread = 20.0
	plume.initial_velocity_min = 0.8 if burning else 1.0
	plume.initial_velocity_max = 1.6 if burning else 2.0
	plume.gravity = Vector3(0.0, 0.4, 0.0)
	plume.scale_amount_min = 0.5 * scale
	plume.scale_amount_max = 1.2 * scale
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.albedo_color = Color(1.0, 0.45, 0.12, 0.85) if burning else Color(0.18, 0.18, 0.17, 0.55)
	puff.material = puff_material
	plume.mesh = puff
	plume.position = local_position
	parent.add_child(plume)
	return plume
