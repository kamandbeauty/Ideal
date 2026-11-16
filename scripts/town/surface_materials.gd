class_name SurfaceMaterials
extends RefCounted
## Small pre-baked maps, reused across the scene. Works on GL Compatibility;
## no SSAO, real-time reflections, screen-reading shaders or HDR are required.

const MAPS := {
	"asphalt": preload("res://assets/textures/asphalt.png"),
	"sand": preload("res://assets/textures/sand.png"),
	"concrete": preload("res://assets/textures/concrete.png"),
	"plaster": preload("res://assets/textures/plaster.png"),
}
const SHADOW := preload("res://assets/textures/contact-shadow.png")

static var _shadow_mat: StandardMaterial3D


static func textured(kind: String, color: Color, tiling: Vector2 = Vector2.ONE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = MAPS.get(kind)
	material.roughness = 0.88
	material.metallic = 0.0
	material.uv1_scale = Vector3(tiling.x, tiling.y, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func contact_shadow(size: Vector2) -> MeshInstance3D:
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_texture = SHADOW
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	var mesh := PlaneMesh.new()
	mesh.size = size
	shadow.mesh = mesh
	shadow.material_override = _shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = 0.015
	return shadow


static func paving(parent: Node3D, kind: String, color: Color, at: Vector3, size: Vector2) -> void:
	var surface := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	surface.mesh = mesh
	surface.position = at
	surface.material_override = textured(kind, color, size / 2.0)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(surface)
