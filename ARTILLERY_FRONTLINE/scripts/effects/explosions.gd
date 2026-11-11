class_name Explosions
extends Node3D
## Area damage and the blast the player sees. Rockets and grenades both end
## here, so there is one rule for who a detonation hurts. Flashes, shock rings
## and scorch marks are pooled; nothing is created when something goes off.

const BLASTS: int = 5
const SCORCHES: int = 10
## The light of a blast lasts FLASH_TIME; the white flash itself is over in a blink.
const FLASH_TIME: float = 0.3
const GLARE_TIME: float = 0.13
const RING_TIME: float = 0.42
const SCORCH_TIME: float = 30.0
const GORE_PER_BLAST: int = 4

var horde: Horde
var defense: Defense
var effects: EffectPool
var defender: Defender
var layout: LevelLayout
var detonations: int = 0
var kills: int = 0
var lights: Array[OmniLight3D] = []
var flashes: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var ages := PackedFloat32Array()
var scales := PackedFloat32Array()
var reaches := PackedFloat32Array()
var scorches: Array[MeshInstance3D] = []
var scorch_ages := PackedFloat32Array()
var cursor: int = 0
var scorch_cursor: int = 0
var ground_query := PhysicsRayQueryParameters3D.new()
var glow_lights: bool = true


func _ready() -> void:
	add_to_group("quality_listener")
	ground_query.collision_mask = Layers.WORLD
	ages.resize(BLASTS)
	scales.resize(BLASTS)
	reaches.resize(BLASTS)
	scorch_ages.resize(SCORCHES)
	var ring_texture: Texture2D = _radial([[0.0, Color(1, 1, 1, 0)], [0.66, Color(1, 1, 1, 0)], [0.86, Color(1, 1, 1, 0.9)],
		[1.0, Color(1, 1, 1, 0)]])
	var scorch_texture: Texture2D = _radial([[0.0, Color(0, 0, 0, 0.82)], [0.45, Color(0.02, 0.02, 0.02, 0.6)], [1.0, Color(0, 0, 0, 0)]])
	for index: int in BLASTS:
		ages[index] = 100.0
		var light := OmniLight3D.new()
		light.name = "BlastLight%d" % index
		light.light_color = Color(1.0, 0.66, 0.3)
		light.light_energy = 0.0
		light.omni_range = 16.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		lights.append(light)
		var flash := MeshInstance3D.new()
		flash.name = "Flash%d" % index
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		flash.mesh = quad
		flash.material_override = _sprite(EffectPool.soft_dot(), Color(1.0, 0.8, 0.5, 1.0), true, true)
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false
		add_child(flash)
		flashes.append(flash)
		var ring := MeshInstance3D.new()
		ring.name = "Ring%d" % index
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		ring.mesh = plane
		ring.material_override = _sprite(ring_texture, Color(1.0, 0.9, 0.75, 0.7), true, false)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		rings.append(ring)
	for index: int in SCORCHES:
		scorch_ages[index] = SCORCH_TIME
		var mark := MeshInstance3D.new()
		mark.name = "Scorch%d" % index
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		mark.mesh = plane
		mark.material_override = _sprite(scorch_texture, Color(1, 1, 1, 1), false, false)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visible = false
		add_child(mark)
		scorches.append(mark)
	apply_quality(Graphics.tier, Graphics.profile())


func setup(the_horde: Horde, wall: Defense, effect_pool: EffectPool, gunner: Defender, level_layout: LevelLayout) -> void:
	horde = the_horde
	defense = wall
	effects = effect_pool
	defender = gunner
	layout = level_layout


func apply_quality(_tier: String, settings: Dictionary) -> void:
	glow_lights = settings.shadows


static func _radial(stops: Array) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_offset(0, stops[0][0])
	gradient.set_color(0, stops[0][1])
	gradient.set_offset(1, stops[stops.size() - 1][0])
	gradient.set_color(1, stops[stops.size() - 1][1])
	for index: int in range(1, stops.size() - 1):
		gradient.add_point(stops[index][0], stops[index][1])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


static func _sprite(texture: Texture2D, color: Color, additive: bool, billboard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.disable_fog = true
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	return material


## Distance from a blast to the nearest part of a standing zombie (0 when it goes off against the body).
static func distance_to_body(at: Vector3, zombie: Zombie) -> float:
	var feet: Vector3 = zombie.global_position
	var height: float = (zombie.data.body_height + zombie.data.head_radius * 2.0) * zombie.scale.y
	var nearest := Vector3(feet.x, clampf(at.y, feet.y + 0.1, feet.y + height), feet.z)
	return maxf(0.0, at.distance_to(nearest) - zombie.data.body_radius * zombie.scale.x)


## Sets off a blast at `at`. `direct` is the zombie a rocket struck, which
## takes `direct_damage` on top of the blast. Returns {"hurt", "killed"}.
func detonate(at: Vector3, data: ExplosionData, direct: Zombie = null, direct_damage: float = 0.0) -> Dictionary:
	detonations += 1
	var hurt: int = 0
	var killed: int = 0
	var gore: int = 0
	if direct != null and direct.alive and direct_damage > 0.0:
		hurt += 1
		if direct.take_blast(direct_damage, at, 1.0, data):
			killed += 1
	if horde != null and data.damage > 0.0:
		for zombie: Zombie in horde.active:
			if not zombie.alive:
				continue
			var distance: float = distance_to_body(at, zombie)
			if distance > data.radius:
				continue
			hurt += 1
			if zombie.take_blast(data.damage_at(distance), at, data.falloff(distance), data):
				killed += 1
				if effects and gore < GORE_PER_BLAST:
					gore += 1
					effects.burst("gore", zombie.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	if data.structure_damage > 0.0 and defense != null and layout != null:
		_damage_structures(at, data)
	kills += killed
	_show(at, data)
	Sound.play_at(data.sound, at, data.volume_db, randf_range(0.93, 1.06))
	if defender != null and is_instance_valid(defender):
		var away: float = at.distance_to(defender.eye_position())
		defender.jolt(data.shake_degrees * clampf(10.0 / maxf(away, 3.0), 0.12, 2.0))
	Events.explosion.emit(at, data.radius, killed)
	return {"hurt": hurt, "killed": killed}


func _damage_structures(at: Vector3, data: ExplosionData) -> void:
	var targets: Array = [["gate", layout.gate_center, layout.gate_size], ["wall", layout.patch_center, layout.patch_size]]
	for entry: Array in targets:
		if entry[0] == "gate" and defense.gate_destroyed:
			continue
		var box := AABB((entry[1] as Vector3) - (entry[2] as Vector3) * 0.5, entry[2])
		var nearest := Vector3(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y),
			clampf(at.z, box.position.z, box.end.z))
		var distance: float = at.distance_to(nearest)
		if distance <= data.radius:
			defense.apply_damage(entry[0], data.structure_damage * data.falloff(distance), nearest)


func _show(at: Vector3, data: ExplosionData) -> void:
	var size: float = data.visual_scale
	if effects:
		effects.burst("fireball", at + Vector3(0.0, 0.3 * size, 0.0), Vector3.UP, size)
		effects.burst("blast_smoke", at + Vector3(0.0, 0.5 * size, 0.0), Vector3.UP, size)
		effects.burst("debris", at, Vector3.UP, size)
		effects.burst("spark", at + Vector3(0.0, 0.2, 0.0), Vector3.UP, 2.2 * size)
		effects.burst("dust", at, Vector3.UP, 3.0 * size)
	var slot: int = cursor
	cursor = (cursor + 1) % BLASTS
	ages[slot] = 0.0
	scales[slot] = size
	reaches[slot] = data.radius
	var ground: Dictionary = _ground_under(at)
	var floor_point: Vector3 = ground.get("position", at)
	lights[slot].position = at + Vector3(0.0, 0.8, 0.0)
	lights[slot].visible = glow_lights
	flashes[slot].position = at + Vector3(0.0, 0.4 * size, 0.0)
	flashes[slot].visible = true
	rings[slot].position = floor_point + Vector3(0.0, 0.08, 0.0)
	rings[slot].visible = not ground.is_empty()
	if not ground.is_empty():
		var mark_slot: int = scorch_cursor
		scorch_cursor = (scorch_cursor + 1) % SCORCHES
		scorch_ages[mark_slot] = 0.0
		var mark: MeshInstance3D = scorches[mark_slot]
		# Stacked marks sit at slightly different heights so they never fight for the same depth.
		mark.position = floor_point + Vector3(0.0, 0.03 + 0.004 * float(mark_slot), 0.0)
		mark.rotation.y = randf() * TAU
		mark.scale = Vector3.ONE * data.radius * randf_range(0.8, 1.0)
		mark.visible = true
	_animate(0.0)


## The floor below a blast, when it went off close enough to mark it.
func _ground_under(at: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	ground_query.from = at + Vector3(0.0, 0.4, 0.0)
	ground_query.to = at + Vector3(0.0, -2.2, 0.0)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_query)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
		return {}
	return hit


func _process(delta: float) -> void:
	_animate(delta)


func _animate(delta: float) -> void:
	for slot: int in BLASTS:
		if ages[slot] > RING_TIME:
			continue
		ages[slot] += delta
		var age: float = ages[slot]
		var size: float = scales[slot]
		var burn: float = clampf(1.0 - age / FLASH_TIME, 0.0, 1.0)
		lights[slot].light_energy = 10.0 * size * burn * burn
		lights[slot].omni_range = 16.0 * size
		var flash: MeshInstance3D = flashes[slot]
		flash.scale = Vector3.ONE * lerpf(1.2, 3.6, clampf(age / GLARE_TIME, 0.0, 1.0)) * size
		(flash.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - age / GLARE_TIME, 0.0, 1.0)
		var spread: float = clampf(age / RING_TIME, 0.0, 1.0)
		var ring: MeshInstance3D = rings[slot]
		ring.scale = Vector3.ONE * lerpf(1.0, reaches[slot] * 2.0, 1.0 - (1.0 - spread) * (1.0 - spread))
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - spread)
		if age > RING_TIME:
			lights[slot].visible = false
			flash.visible = false
			ring.visible = false
	for slot: int in SCORCHES:
		if scorch_ages[slot] >= SCORCH_TIME:
			continue
		scorch_ages[slot] += delta
		var left: float = SCORCH_TIME - scorch_ages[slot]
		(scorches[slot].material_override as StandardMaterial3D).albedo_color.a = clampf(left / 8.0, 0.0, 1.0)
		if left <= 0.0:
			scorches[slot].visible = false


## How many pooled flashes are burning right now.
func burning() -> int:
	var total: int = 0
	for slot: int in BLASTS:
		if ages[slot] <= RING_TIME:
			total += 1
	return total
