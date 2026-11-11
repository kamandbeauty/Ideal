class_name EffectPool
extends Node3D

var effects: Array[ExplosionEffect] = []
var craters: Array[MeshInstance3D] = []
var crater_index: int = 0
var active_limit: int = 7
var particle_ratio: float = 0.7
const MAX_EFFECTS: int = 10
const MAX_CRATERS: int = 24

func _ready() -> void:
	add_to_group("quality_listener")
	for index in range(MAX_EFFECTS):
		var effect := ExplosionEffect.new()
		add_child(effect)
		effects.append(effect)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/crater.gdshader")
	for index in range(MAX_CRATERS):
		var decal := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2.ONE
		decal.mesh = mesh
		decal.material_override = material
		decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decal.visible = false
		add_child(decal)
		craters.append(decal)
	var tier: String = Graphics.tier
	apply_quality(tier, Graphics.PROFILES[tier])

func apply_quality(tier: String, settings: Dictionary) -> void:
	active_limit = int(settings.effect_slots)
	particle_ratio = float(settings.particles)
	for index in range(effects.size()):
		if index >= active_limit and effects[index].active:
			effects[index].deactivate()

## `scar` puts a ground crater decal at `point`. Pass false for blasts in the air (aircraft), or the scar floats in the sky.
func explode(point: Vector3, normal: Vector3, radius: float, ground_y: float, muzzle_flash: bool = false, scar: bool = true) -> void:
	var selected: ExplosionEffect = null
	for index in range(active_limit):
		if not effects[index].active:
			selected = effects[index]
			break
	if selected == null:
		selected = effects[0]
		for index in range(1, active_limit):
			if effects[index].age > selected.age:
				selected = effects[index]
	selected.activate(point, radius, ground_y, particle_ratio, muzzle_flash)
	if not muzzle_flash and scar:
		var crater: MeshInstance3D = craters[crater_index]
		crater_index = (crater_index + 1) % craters.size()
		crater.global_position = point + normal * 0.09
		crater.basis = Basis(Quaternion(Vector3.UP, normal))
		crater.scale = Vector3(radius * 0.85, 1.0, radius * 0.85)
		crater.visible = true

func active_count() -> int:
	var count: int = 0
	for effect in effects:
		if effect.active:
			count += 1
	return count

func clear() -> void:
	for effect in effects:
		effect.deactivate()
	for crater in craters:
		crater.visible = false
	crater_index = 0
