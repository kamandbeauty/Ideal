class_name GuildMaterials
extends RefCounted
## Material factory for the guild's cel look.
##
## The whole style rests on two compatible tricks instead of a custom shader:
## flat, high-roughness albedo with no specular, and an inverted-hull outline
## (the same mesh grown by a few millimetres with front faces culled). Both work
## in `gl_compatibility` on Android, so the look is identical on phone and in CI.

const OUTLINE_COLOR := Color(0.045, 0.035, 0.08)
const OUTLINE_WIDTH := 0.021


## The base surface: chalky, matte, no highlights fighting the silhouette.
static func flat(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


## Slightly metallic cloth trim, armour and gold: the same flat look with a
## restrained metal response so gold reads as gold and not as yellow paint.
static func metal(color: Color) -> StandardMaterial3D:
	var material := flat(color, 0.42)
	material.metallic = 0.72
	return material


## The ink line around a character or a prop.
static func outline(width: float = OUTLINE_WIDTH) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = OUTLINE_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = width
	material.disable_receive_shadows = true
	return material


## Self-lit surfaces: magic accents, windows, the glow a spell leaves behind.
static func glow(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var material := flat(color, 1.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## A lit floor that stays readable at a 36° camera angle.
static func floor(color: Color) -> StandardMaterial3D:
	var material := flat(color, 1.0)
	material.albedo_color = color
	return material
