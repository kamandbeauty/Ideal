class_name MaterialLibrary
extends RefCounted
## Original procedural PBR surfaces. Textures are authored locally/CI, never downloaded.
const ROOT: String = "res://assets/textures/pbr/"
static var textures: Dictionary = {}
static var surfaces: Dictionary = {}
static var surface_data: Dictionary = {}
static var detail_level: int = 512

static func texture(name: String) -> Texture2D:
	if textures.has(name):
		return textures[name]
	var path: String = ROOT + name
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		result = load(path) as Texture2D
	textures[name] = result
	return result

static func surface(kind: String, tint: Color = Color.WHITE, uv_scale: float = 1.0, metallic: float = -1.0, roughness: float = -1.0) -> StandardMaterial3D:
	var key: String = "%s|%s|%.3f|%.3f|%.3f" % [kind, tint.to_html(), uv_scale, metallic, roughness]
	if surfaces.has(key):
		return surfaces[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_triplanar_sharpness = 4.0
	result.uv1_scale = Vector3.ONE * uv_scale
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var albedo: Texture2D = texture(kind + "_albedo.jpg")
	if albedo:
		result.albedo_texture = albedo
	var normal: Texture2D = texture(kind + "_normal.png")
	if normal:
		result.normal_enabled = true
		result.normal_texture = normal
		result.normal_scale = 1.0
	var orm: Texture2D = texture(kind + "_orm.png")
	if orm:
		result.ao_enabled = true
		result.ao_texture = orm
		result.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		result.ao_light_affect = 0.35
		result.roughness_texture = orm
		result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		result.metallic_texture = orm
		result.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		result.metallic = 1.0 if metallic < 0.0 else metallic
		result.roughness = 1.0 if roughness < 0.0 else roughness
	else:
		result.metallic = 0.0 if metallic < 0.0 else metallic
		result.roughness = 0.85 if roughness < 0.0 else roughness
	match kind:
		"glass":
			result.albedo_color = Color(0.055, 0.11, 0.12)
			result.metallic = 0.65
			result.roughness = 0.16
			result.normal_enabled = false
			result.ao_enabled = false
		"lamp":
			result.albedo_color = Color(0.85, 0.70, 0.38)
			result.emission_enabled = true
			result.emission = Color(0.95, 0.72, 0.35)
			result.emission_energy_multiplier = 0.35
			result.metallic = 0.2
			result.roughness = 0.3
		"black_bore":
			result.albedo_color = Color(0.01, 0.014, 0.012)
			result.metallic = 0.1
			result.roughness = 0.9
			result.normal_enabled = false
		"warning":
			result.albedo_color = Color(0.72, 0.34, 0.08)
			result.metallic = 0.25
			result.roughness = 0.6
	surfaces[key] = result
	surface_data[key] = {"orm": orm, "roughness": result.roughness, "metallic": result.metallic}
	return result

static func apply_quality(settings: Dictionary) -> void:
	detail_level = int(settings.get("texture_size", 256))
	var full_pbr: bool = detail_level >= 512
	for key in surfaces:
		var material: StandardMaterial3D = surfaces[key]
		var data: Dictionary = surface_data.get(key, {})
		if material.normal_texture:
			material.normal_enabled = full_pbr
		var orm: Texture2D = data.get("orm", null)
		if orm:
			material.ao_enabled = full_pbr
			material.roughness_texture = orm if full_pbr else null
			material.metallic_texture = orm if full_pbr else null
		if not full_pbr:
			material.roughness = float(data.get("roughness", 0.85))
			material.metallic = float(data.get("metallic", 0.0))

static func for_model_material(material_name: String, original: Material) -> Material:
	var lower: String = material_name.to_lower()
	if "field olive" in lower or "armor edge" in lower:
		return surface("paint_olive", Color.WHITE, 0.65)
	if "sand armor" in lower:
		return surface("paint_sand", Color.WHITE, 0.65)
	if "gun steel" in lower or "recoil steel" in lower:
		return surface("steel", Color.WHITE, 0.9)
	if "rubber" in lower:
		return surface("rubber", Color.WHITE, 1.4)
	if "canvas" in lower:
		return surface("fabric", Color.WHITE, 1.1)
	if "brass" in lower:
		return surface("steel", Color(0.78, 0.56, 0.22), 1.2, 0.8, 0.35)
	if "glass" in lower:
		return surface("glass")
	if "lamp" in lower:
		return surface("lamp")
	if "black bore" in lower:
		return surface("black_bore")
	if "warning" in lower:
		return surface("warning")
	return original

static func apply_to_model(root: Node3D) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface_index in range(instance.mesh.get_surface_count()):
			var original: Material = instance.mesh.surface_get_material(surface_index)
			var material_name: String = original.resource_name if original else instance.name
			var upgraded: Material = for_model_material(material_name, original)
			if upgraded != null and upgraded != original:
				instance.set_surface_override_material(surface_index, upgraded)
