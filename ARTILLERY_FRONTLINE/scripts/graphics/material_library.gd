class_name MaterialLibrary
extends RefCounted
## Shared surface materials. The level GLB only carries material names, vertex
## colours and world-scaled UVs; the textures are bound here so every mesh
## that says "concrete" shares one material and one set of compressed textures.

const TEXTURE_DIR: String = "res://assets/textures/world/"
## name -> [roughness, metallic, normal strength]
const SURFACES: Dictionary = {
	"concrete": [0.92, 0.0, 0.9],
	"paving": [0.94, 0.0, 0.9],
	"asphalt": [0.88, 0.0, 1.0],
	"plaster": [0.95, 0.0, 0.7],
	"brick": [0.95, 0.0, 1.0],
	"metal": [0.58, 0.55, 0.8],
	"rubble": [1.0, 0.0, 1.0],
	"burlap": [1.0, 0.0, 0.8],
}
const TWO_SIDED: Array[String] = ["plaster", "brick"]

static var cache: Dictionary = {}
static var normal_maps: bool = true


static func surface(material_name: String) -> Material:
	if cache.has(material_name):
		return cache[material_name]
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.vertex_color_use_as_albedo = true
	if SURFACES.has(material_name):
		var spec: Array = SURFACES[material_name]
		material.albedo_texture = load(TEXTURE_DIR + material_name + ".jpg")
		material.roughness = spec[0]
		material.metallic = spec[1]
		material.metallic_specular = 0.35
		material.normal_scale = spec[2]
		material.normal_texture = load(TEXTURE_DIR + material_name + "_n.png")
		material.normal_enabled = normal_maps
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if TWO_SIDED.has(material_name):
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		match material_name:
			"interior":
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(0.03, 0.03, 0.035)
				material.vertex_color_use_as_albedo = false
			"marking":
				material.roughness = 0.85
			"lamp":
				material.albedo_color = Color(1.0, 0.84, 0.6)
				material.emission_enabled = true
				material.emission = Color(1.0, 0.72, 0.38)
				material.emission_energy_multiplier = 2.6
				material.vertex_color_use_as_albedo = false
			"ember":
				material.albedo_color = Color(1.0, 0.45, 0.15)
				material.emission_enabled = true
				material.emission = Color(1.0, 0.36, 0.08)
				material.emission_energy_multiplier = 2.2
				material.vertex_color_use_as_albedo = false
			"skyline":
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(0.2, 0.2, 0.22)
			_:
				material.roughness = 0.9
	cache[material_name] = material
	return material


static func set_normal_maps(enabled: bool) -> void:
	normal_maps = enabled
	for material: Material in cache.values():
		if material is StandardMaterial3D and material.normal_texture != null:
			material.normal_enabled = enabled


## Swaps every surface of every mesh under `root` for the shared material of the same name.
static func bind(root: Node) -> int:
	var bound: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		if instance.mesh == null:
			continue
		for index: int in instance.mesh.get_surface_count():
			var source: Material = instance.mesh.surface_get_material(index)
			if source == null:
				continue
			instance.set_surface_override_material(index, surface(source.resource_name))
			bound += 1
	return bound


## One of the painted skins of a zombie type (zombie_<type>_a.png, _b, ...).
static func zombie_skin(type_id: String, variant: int) -> Material:
	var key: String = "zombie_%s_%d" % [type_id, variant]
	if cache.has(key):
		return cache[key]
	var material := StandardMaterial3D.new()
	material.resource_name = key
	material.albedo_texture = load("res://assets/textures/zombies/zombie_%s_%s.png" % [type_id, "abcdefgh"[variant % 8]])
	material.roughness = 0.86
	material.metallic_specular = 0.25
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cache[key] = material
	return material


static func clear() -> void:
	cache.clear()
