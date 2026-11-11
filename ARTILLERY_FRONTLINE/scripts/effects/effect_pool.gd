class_name EffectPool
extends Node3D
## Pooled one-shot particle bursts (blood, dust, sparks, smoke, the layers of an
## explosion). Nothing is allocated during play: a burst re-arms the next
## emitter of its kind. A kind marked "detail" is dressing that the lowest
## quality tier goes without.

const KINDS: Dictionary = {
	"blood": {"count": 12, "amount": 10, "life": 0.45, "speed": Vector2(1.8, 5.0), "spread": 38.0, "gravity": -9.0,
		"size": Vector2(0.1, 0.24), "color": Color(0.36, 0.02, 0.02, 0.95), "grow": 1.6, "additive": false},
	"gore": {"count": 6, "amount": 18, "life": 0.6, "speed": Vector2(2.5, 6.5), "spread": 60.0, "gravity": -9.0,
		"size": Vector2(0.14, 0.34), "color": Color(0.42, 0.03, 0.02, 0.95), "grow": 1.8, "additive": false},
	"dust": {"count": 12, "amount": 8, "life": 0.75, "speed": Vector2(0.8, 2.6), "spread": 45.0, "gravity": -0.8,
		"size": Vector2(0.3, 0.65), "color": Color(0.56, 0.53, 0.48, 0.55), "grow": 2.6, "additive": false},
	"spark": {"count": 8, "amount": 9, "life": 0.28, "speed": Vector2(5.0, 12.0), "spread": 50.0, "gravity": -9.8,
		"size": Vector2(0.07, 0.16), "color": Color(1.0, 0.72, 0.3, 1.0), "grow": 0.4, "additive": true},
	"smoke": {"count": 4, "amount": 26, "life": 2.6, "speed": Vector2(1.0, 4.5), "spread": 80.0, "gravity": 0.5,
		"size": Vector2(1.2, 2.8), "color": Color(0.42, 0.4, 0.37, 0.6), "grow": 2.4, "additive": false},
	# Stone knocked loose by a round: a few hard flecks that fall straight back down.
	"chips": {"count": 8, "amount": 6, "life": 0.5, "speed": Vector2(2.0, 6.0), "spread": 55.0, "gravity": -13.0,
		"size": Vector2(0.04, 0.09), "color": Color(0.62, 0.59, 0.54, 1.0), "end": Color(0.5, 0.48, 0.44, 0.6), "grow": 1.0,
		"additive": false, "detail": true},
	# The layers of an explosion. The fireball is white-hot for an instant and burns down through orange to a
	# dull red; where its puffs overlap they add up, so the heart of it is the brightest part.
	"fireball": {"count": 5, "amount": 16, "life": 0.7, "speed": Vector2(1.5, 6.5), "spread": 180.0, "gravity": 2.5,
		"size": Vector2(1.2, 2.5), "color": Color(1.0, 0.94, 0.72, 1.0),
		"ramp": [[0.16, Color(1.0, 0.68, 0.22, 0.95)], [0.55, Color(0.82, 0.24, 0.05, 0.6)]],
		"end": Color(0.24, 0.05, 0.02, 0.0), "grow": 2.0, "additive": true},
	"blast_smoke": {"count": 5, "amount": 16, "life": 3.2, "speed": Vector2(0.5, 2.4), "spread": 60.0, "gravity": 0.5,
		"size": Vector2(2.0, 3.6), "color": Color(0.07, 0.065, 0.06, 0.9), "rise": 0.09, "mid": [0.55, Color(0.16, 0.15, 0.14, 0.8)],
		"end": Color(0.3, 0.29, 0.28, 0.0), "grow": 2.2, "additive": false},
	"debris": {"count": 5, "amount": 18, "life": 1.15, "speed": Vector2(6.0, 17.0), "spread": 62.0, "gravity": -15.0,
		"size": Vector2(0.09, 0.22), "color": Color(0.1, 0.09, 0.08, 1.0), "end": Color(0.1, 0.09, 0.08, 0.6), "grow": 1.0,
		"additive": false},
	# Burning fragments: thrown high and wide, slowed by the air, glowing all the way down.
	"ember": {"count": 5, "amount": 22, "life": 1.25, "speed": Vector2(7.0, 20.0), "spread": 72.0, "gravity": -11.0,
		"size": Vector2(0.08, 0.17), "color": Color(1.0, 0.92, 0.62, 1.0), "ramp": [[0.35, Color(1.0, 0.56, 0.16, 1.0)]],
		"end": Color(0.85, 0.16, 0.03, 0.0), "grow": 0.5, "additive": true, "damping": 2.2},
	# Propellant gas ahead of the launcher: fast, thin, gone before it can hide the target.
	"launch": {"count": 2, "amount": 9, "life": 0.42, "speed": Vector2(5.0, 13.0), "spread": 13.0, "gravity": 0.4,
		"size": Vector2(0.16, 0.38), "color": Color(0.8, 0.78, 0.74, 0.34), "grow": 2.4, "additive": false, "damping": 6.0},
	# Gun smoke curling off a hot muzzle. Slow and short-lived: it is gone before it has risen to the sight line.
	"wisp": {"count": 4, "amount": 5, "life": 0.6, "speed": Vector2(0.15, 0.4), "spread": 28.0, "gravity": 0.2,
		"size": Vector2(0.1, 0.22), "color": Color(0.66, 0.65, 0.63, 0.26), "grow": 2.6, "additive": false, "detail": true},
}

var emitters: Dictionary = {}
var cursors: Dictionary = {}
var bursts: int = 0
var particle_ratio: float = 1.0
## False on the lowest tier: kinds marked "detail" are skipped.
var detail: bool = true
static var dot_texture: Texture2D
static var flare_textures: Dictionary = {}


func _ready() -> void:
	add_to_group("quality_listener")
	for kind: String in KINDS:
		var spec: Dictionary = KINDS[kind]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		# Without this the billboard discards each particle's scale and draws every quad at full size.
		material.billboard_keep_scale = true
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = soft_dot()
		material.disable_receive_shadows = true
		if spec.additive:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			# Fire is its own light: haze must not grey it out.
			material.disable_fog = true
		var mesh := QuadMesh.new()
		mesh.material = material
		var fade := Gradient.new()
		fade.set_color(0, spec.color)
		fade.set_color(1, spec.get("end", Color(spec.color.r, spec.color.g, spec.color.b, 0.0)))
		if spec.has("rise"):
			# Comes up out of nothing, so the fire is seen first and the smoke closes over it.
			fade.set_color(0, Color(spec.color.r, spec.color.g, spec.color.b, 0.0))
			fade.add_point(spec.rise, spec.color)
		if spec.has("mid"):
			# Holds the colour for a while instead of thinning from the first moment.
			fade.add_point(spec.mid[0], spec.mid[1])
		for stop: Array in spec.get("ramp", []):
			fade.add_point(stop[0], stop[1])
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
			if spec.has("damping"):
				emitter.damping_min = spec.damping
				emitter.damping_max = spec.damping
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


## A hot core with uneven rays: the muzzle flash, and the first instant of a blast.
static func flare(rays: int = 6) -> Texture2D:
	if flare_textures.has(rays):
		return flare_textures[rays]
	var size: int = 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var offset := Vector2((float(x) + 0.5) / float(size) * 2.0 - 1.0, (float(y) + 0.5) / float(size) * 2.0 - 1.0)
			var distance: float = offset.length()
			var angle: float = offset.angle()
			# A fat, hot heart: seen small on a phone, thin rays alone read as a sparkle, not as a gun going off.
			var core: float = clampf(1.0 - distance / 0.55, 0.0, 1.0)
			# Every other ray is shorter, so the flash is a burst and not a neat star.
			var reach: float = 0.72 + 0.28 * sin(angle * float(rays) * 0.5 + 0.9)
			var ray: float = pow(absf(cos(angle * float(rays) * 0.5)), 6.0) * clampf(1.0 - distance / reach, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(core * core * 1.6 + ray * 0.85, 0.0, 1.0)))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	flare_textures[rays] = texture
	return texture


func apply_quality(_tier: String, settings: Dictionary) -> void:
	particle_ratio = settings.particles
	detail = bool(settings.get("detail", true))
	for kind: String in KINDS:
		for emitter: CPUParticles3D in emitters[kind]:
			emitter.amount = maxi(3, int(round(KINDS[kind].amount * particle_ratio)))


func burst(kind: String, at: Vector3, normal: Vector3 = Vector3.UP, size: float = 1.0) -> void:
	if not emitters.has(kind) or (not detail and KINDS[kind].get("detail", false)):
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
