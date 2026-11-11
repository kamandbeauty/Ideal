class_name EffectPool
extends Node3D
## Pooled one-shot particle bursts (blood, dust, sparks, breach smoke). Nothing
## is allocated during play: a burst re-arms the next emitter of its kind.

const KINDS: Dictionary = {
	"blood": {"count": 12, "amount": 10, "life": 0.45, "speed": Vector2(1.8, 5.0), "spread": 38.0, "gravity": -9.0,
		"size": Vector2(0.05, 0.13), "color": Color(0.34, 0.02, 0.02, 0.95), "grow": 1.6, "additive": false},
	"gore": {"count": 6, "amount": 18, "life": 0.6, "speed": Vector2(2.5, 6.5), "spread": 60.0, "gravity": -9.0,
		"size": Vector2(0.07, 0.18), "color": Color(0.4, 0.03, 0.02, 0.95), "grow": 1.8, "additive": false},
	"dust": {"count": 12, "amount": 8, "life": 0.75, "speed": Vector2(0.8, 2.6), "spread": 45.0, "gravity": -0.8,
		"size": Vector2(0.22, 0.5), "color": Color(0.56, 0.53, 0.48, 0.55), "grow": 2.6, "additive": false},
	"spark": {"count": 8, "amount": 9, "life": 0.28, "speed": Vector2(5.0, 12.0), "spread": 50.0, "gravity": -9.8,
		"size": Vector2(0.03, 0.07), "color": Color(1.0, 0.72, 0.3, 1.0), "grow": 0.4, "additive": true},
	"smoke": {"count": 4, "amount": 26, "life": 2.6, "speed": Vector2(1.0, 4.5), "spread": 80.0, "gravity": 0.5,
		"size": Vector2(1.2, 2.8), "color": Color(0.42, 0.4, 0.37, 0.6), "grow": 2.4, "additive": false},
}

var emitters: Dictionary = {}
var cursors: Dictionary = {}
var bursts: int = 0
var particle_ratio: float = 1.0
static var dot_texture: Texture2D


func _ready() -> void:
	add_to_group("quality_listener")
	for kind: String in KINDS:
		var spec: Dictionary = KINDS[kind]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = soft_dot()
		material.disable_receive_shadows = true
		if spec.additive:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var mesh := QuadMesh.new()
		mesh.material = material
		var fade := Gradient.new()
		fade.set_color(0, spec.color)
		fade.set_color(1, Color(spec.color.r, spec.color.g, spec.color.b, 0.0))
		var growth := Curve.new()
		growth.add_point(Vector2(0.0, 1.0 / maxf(spec.grow, 1.0)))
		growth.add_point(Vector2(1.0, minf(1.0, spec.grow)))
		var list: Array[CPUParticles3D] = []
		for index: int in spec.count:
			var emitter := CPUParticles3D.new()
			emitter.name = "%s%02d" % [kind.capitalize(), index]
			emitter.mesh = mesh
			emitter.emitting = false
			emitter.one_shot = true
			emitter.explosiveness = 0.92
			emitter.amount = spec.amount
			emitter.lifetime = spec.life
			emitter.local_coords = false
			emitter.direction = Vector3.UP
			emitter.spread = spec.spread
			emitter.initial_velocity_min = spec.speed.x
			emitter.initial_velocity_max = spec.speed.y
			emitter.gravity = Vector3(0.0, spec.gravity, 0.0)
			emitter.scale_amount_min = spec.size.x
			emitter.scale_amount_max = spec.size.y
			emitter.scale_amount_curve = growth
			emitter.color_ramp = fade
			emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(emitter)
			list.append(emitter)
		emitters[kind] = list
		cursors[kind] = 0
	apply_quality(Graphics.tier, Graphics.profile())


static func soft_dot() -> Texture2D:
	if dot_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.75))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		dot_texture = texture
	return dot_texture


func apply_quality(_tier: String, settings: Dictionary) -> void:
	particle_ratio = settings.particles
	for kind: String in KINDS:
		for emitter: CPUParticles3D in emitters[kind]:
			emitter.amount = maxi(3, int(round(KINDS[kind].amount * particle_ratio)))


func burst(kind: String, at: Vector3, normal: Vector3 = Vector3.UP, size: float = 1.0) -> void:
	if not emitters.has(kind):
		return
	var list: Array = emitters[kind]
	var index: int = cursors[kind]
	cursors[kind] = (index + 1) % list.size()
	var emitter: CPUParticles3D = list[index]
	emitter.global_position = at
	emitter.direction = normal if normal.length_squared() > 0.01 else Vector3.UP
	emitter.scale = Vector3.ONE * size
	emitter.restart()
	emitter.emitting = true
	bursts += 1


func pool_size() -> int:
	var total: int = 0
	for kind: String in emitters:
		total += emitters[kind].size()
	return total
