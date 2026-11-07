class_name MaterialLibrary
extends RefCounted
## Original procedural PBR surfaces. Textures are authored locally/CI, never downloaded.
const ROOT: String = "res://assets/textures/pbr/"
static var textures: Dictionary = {}
static var surfaces: Dictionary = {}
static var surface_data: Dictionary = {}
static var weapon_surfaces: Dictionary = {}
static var weapon_surface_data: Dictionary = {}
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
	for key in weapon_surfaces:
		var material: StandardMaterial3D = weapon_surfaces[key]
		var data: Dictionary = weapon_surface_data.get(key, {})
		if material.normal_texture:
			material.normal_enabled = full_pbr
		var orm: Texture2D = data.get("orm", null)
		if orm:
			material.ao_enabled = full_pbr
			material.roughness_texture = orm if full_pbr else null
			material.metallic_texture = orm if full_pbr else null
		if not full_pbr:
			material.roughness = float(data.get("roughness", 0.6))
			material.metallic = float(data.get("metallic", 0.2))


static func weapon_surface(kind: String, tint: Color = Color.WHITE, use_uv: bool = false) -> StandardMaterial3D:
	var key: String = kind + "|" + tint.to_html() + "|" + str(use_uv)
	if weapon_surfaces.has(key):
		return weapon_surfaces[key]
	var base_kind: String = kind
	var uv_scale: float = 1.0 if use_uv else 3.0
	var result: StandardMaterial3D = surface(base_kind, tint, uv_scale).duplicate() as StandardMaterial3D
	if use_uv:
		result.uv1_triplanar = false
		result.uv1_world_triplanar = false
	else:
		result.uv1_world_triplanar = false
		result.uv1_triplanar_sharpness = 8.0
	result.normal_scale = 0.35 if use_uv else 0.16
	result.roughness = 0.5 if kind in ["steel", "weapon_metal", "weapon_brass"] else 0.68
	result.metallic = 0.9 if kind in ["steel", "weapon_metal", "weapon_brass"] else 0.2
	weapon_surfaces[key] = result
	weapon_surface_data[key] = {"orm": result.roughness_texture, "roughness": result.roughness, "metallic": result.metallic}
	return result

static func for_model_material(material_name: String, original: Material, viewmodel: bool = false) -> Material:
	var lower: String = material_name.to_lower()
	if viewmodel:
		if "weapon steel" in lower:
			return weapon_surface("weapon_metal", Color.WHITE, true)
		if "weapon edge" in lower:
			return weapon_surface("weapon_metal", Color(1.35, 1.35, 1.32), true)
		if "weapon olive" in lower:
			return weapon_surface("weapon_paint", Color.WHITE, true)
		if "weapon grip" in lower:
			return weapon_surface("rubber", Color.WHITE, true)
		if "weapon brass" in lower:
			return weapon_surface("weapon_brass", Color.WHITE, true)
		if "gun steel" in lower:
			return weapon_surface("steel", Color(0.36, 0.4, 0.39))
		if "recoil steel" in lower:
			return weapon_surface("steel", Color(0.72, 0.75, 0.74))
		if "field olive" in lower or "armor edge" in lower:
			return weapon_surface("paint_olive", Color(0.42, 0.47, 0.36))
		if "rubber" in lower:
			return weapon_surface("rubber", Color(0.5, 0.5, 0.48))
		if "brass" in lower:
			return weapon_surface("steel", Color(0.78, 0.56, 0.22))
	if "weapon steel" in lower:
		return surface("weapon_metal", Color.WHITE, 1.0)
	if "weapon edge" in lower:
		return surface("weapon_metal", Color(1.3, 1.3, 1.28), 1.0)
	if "weapon olive" in lower or "helmet steel" in lower:
		return surface("weapon_paint", Color.WHITE, 1.0)
	if "weapon grip" in lower:
		return surface("rubber", Color.WHITE, 1.0)
	if "weapon brass" in lower:
		return surface("weapon_brass", Color.WHITE, 1.0)
	if "rifle wood" in lower:
		return surface("wood", Color(0.75, 0.62, 0.5), 1.2)
	if "skin" in lower:
		return surface("skin", Color.WHITE, 1.0)
	if "leather" in lower:
		return surface("leather", Color.WHITE, 1.2)
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
	if "uniform" in lower:
		return surface("fabric", Color(0.36, 0.40, 0.28), 1.5)
	if "webbing" in lower:
		return surface("fabric", Color(0.22, 0.24, 0.18), 1.8)
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

static func apply_to_model(root: Node3D, viewmodel: bool = false) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface_index in range(instance.mesh.get_surface_count()):
			var original: Material = instance.mesh.surface_get_material(surface_index)
			var material_name: String = original.resource_name if original else instance.name
			var upgraded: Material = for_model_material(material_name, original, viewmodel)
			if upgraded != null and upgraded != original:
				instance.set_surface_override_material(surface_index, upgraded)
