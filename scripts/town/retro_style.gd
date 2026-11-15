class_name RetroStyle
extends RefCounted
## The chosen art direction: a 1950s roadside stop.
##
## Cherry red and cream, chrome trim, turquoise and mustard accents, a neon tube
## on every roof and a double yellow line down the highway. Everything here is a
## shared constant or a two-line material helper so the whole town can be
## re-skinned from one place.

const CHERRY := Color(0.78, 0.2, 0.2)
const CHERRY_DARK := Color(0.55, 0.13, 0.14)
const CREAM := Color(0.96, 0.9, 0.78)
const BONE := Color(0.9, 0.87, 0.8)
const TEAL := Color(0.14, 0.55, 0.55)
const TURQUOISE := Color(0.2, 0.67, 0.66)
const MUSTARD := Color(0.93, 0.71, 0.24)
const CHROME := Color(0.8, 0.83, 0.86)
const CHARCOAL := Color(0.16, 0.17, 0.2)
const NEON_RED := Color(1.0, 0.36, 0.3)
const NEON_TEAL := Color(0.36, 0.95, 0.92)
const NEON_CREAM := Color(1.0, 0.88, 0.62)


static func matte(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material


## Chrome and enamel: a little metallic so highlights read as trim, not paint.
static func enamel(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.32
	material.metallic = 0.55
	return material


## A neon tube: bright at night, a coloured stripe by day.
static func neon(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy * 0.12
	material.set_meta("night_energy", energy)
	return material


static func box(
	parent: Node3D, size: Vector3, at: Vector3, material: Material
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


## A candy-striped awning: alternating slats tilted over a shopfront.
static func awning(
	parent: Node3D, at: Vector3, width: float, depth: float, to_road: float, night: Array
) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.z = 0.0
	parent.add_child(root)
	var slats := 6
	var step := width / float(slats)
	var cream := matte(CREAM, 0.7)
	var cherry := matte(CHERRY, 0.68)
	for i in slats:
		var material := cherry if i % 2 == 0 else cream
		var slat := box(
			root,
			Vector3(depth, 0.05, step * 0.98),
			Vector3(0, 0, -width * 0.5 + step * (float(i) + 0.5)),
			material
		)
		slat.rotation_degrees.z = -14.0 * to_road
	var valance := box(
		root, Vector3(0.04, 0.2, width), Vector3(depth * 0.42 * to_road, -0.16, 0), cream
	)
	valance.rotation_degrees.z = -14.0 * to_road
	# Chrome support poles.
	for side in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 1.0
		cyl.radial_segments = 8
		pole.mesh = cyl
		pole.material_override = enamel(CHROME)
		pole.position = Vector3(depth * 0.42, -0.62, width * 0.46 * side)
		root.add_child(pole)
	# A soft bulb line under the awning that comes alive after dark.
	for i in 3:
		var bulb := box(
			root, Vector3(0.08, 0.08, 0.08),
			Vector3(depth * 0.3, -0.22, -width * 0.32 + width * 0.32 * float(i)),
			neon(NEON_CREAM, 1.1)
		)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		night.append(bulb.material_override)
	return root


## The neon outline that traces a roof edge: it is the thing you see first at
## night, so it is deliberately thin and bright.
static func roof_neon(
	parent: Node3D, at: Vector3, width: float, to_road: float, color: Color, night: Array
) -> void:
	var material := neon(color, 1.6)
	for i in 2:
		var tube := box(
			parent, Vector3(0.05, 0.05, width),
			at + Vector3(0, float(i) * 0.16, 0), material
		)
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tube.position.x = at.x + 0.01 * to_road
	night.append(material)


## A chrome band around the base of a building.
static func chrome_skirt(
	parent: Node3D, center: Vector3, size: Vector3, night: Array
) -> void:
	var band := box(parent, Vector3(size.x, 0.1, size.z), center, enamel(CHROME))
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	night.append(band.material_override)
