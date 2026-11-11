class_name CityLevel
extends Node3D
## The siege level. The mesh, the layout and every balance number come from
## resources; this script lights the scene, binds shared materials and wires
## the defender, the horde, the wall and the wave director together.

@export var layout: LevelLayout
@export var wave_set: WaveSet
@export var defense_data: DefenseData
## Every zombie type the waves may ask for. Each brings its own pool size.
@export var zombie_types: Array[ZombieData] = []

## The low sun is straight behind the gunner: whatever he looks at is lit from
## his side, and neither wall arm throws its shadow over the attackers.
const SUN_TRAVEL := Vector3(0.0, -0.62, -0.78)
const DEFEAT_DELAY: float = 3.4
const VICTORY_DELAY: float = 2.2

var geometry: Node3D
var defender: Defender
var horde: Horde
var defense: Defense
var director: WaveDirector
var bullets: BulletPool
var rockets: RocketPool
var grenades: GrenadePool
var explosions: Explosions
var effects: EffectPool
var environment: Environment
var sun: DirectionalLight3D
var stats := MatchStats.new()
var running: bool = false
var over: bool = false
var idle_view: bool = true
var clock: float = 0.0
var end_left: float = -1.0
var end_victory: bool = false
var gate_leaves: Array[Node3D] = []
var gate_rest: Array[float] = []
var gate_shake: float = 0.0
var gate_body: StaticBody3D
var patch_body: StaticBody3D
var patch_node: Node3D
var fire_nodes: Array[Node3D] = []
var fire_lights: Array[OmniLight3D] = []


func _ready() -> void:
	add_to_group("quality_listener")
	geometry = get_node("Geometry")
	MaterialLibrary.bind(geometry)
	_build_environment()
	_build_sun()
	effects = EffectPool.new()
	effects.name = "Effects"
	add_child(effects)
	bullets = BulletPool.new()
	bullets.name = "Bullets"
	bullets.effects = effects
	add_child(bullets)
	explosions = Explosions.new()
	explosions.name = "Explosions"
	add_child(explosions)
	rockets = RocketPool.new()
	rockets.name = "Rockets"
	rockets.explosions = explosions
	add_child(rockets)
	grenades = GrenadePool.new()
	grenades.name = "Grenades"
	grenades.explosions = explosions
	add_child(grenades)
	defender = get_node("Defender")
	defender.position = layout.mount_position
	defender.ground_height = global_position.y
	defender.equip(bullets, rockets, grenades, effects)
	defense = Defense.new()
	defense.name = "Defense"
	defense.data = defense_data
	add_child(defense)
	horde = Horde.new()
	horde.name = "Horde"
	add_child(horde)
	horde.setup(layout, defense, effects, zombie_types)
	explosions.setup(horde, defense, effects, defender, layout)
	for data: ZombieData in zombie_types:
		horde.prewarm(data.id)
	director = WaveDirector.new()
	director.name = "WaveDirector"
	director.wave_set = wave_set
	director.horde = horde
	add_child(director)
	_build_defenses()
	_build_lamps()
	_build_fires()
	_build_smoke()
	defense.struck.connect(_on_struck)
	director.finished.connect(_on_waves_finished)
	Events.gate_destroyed.connect(_on_gate_destroyed)
	Events.wall_breached.connect(_on_wall_breached)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.zombie_hit.connect(_on_zombie_hit)
	Events.zombie_killed.connect(_on_zombie_killed)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.grenade_thrown.connect(_on_grenade_thrown)
	Events.explosion.connect(_on_explosion)
	Events.boss_appeared.connect(_on_boss_appeared)
	Events.boss_fell.connect(_on_boss_fell)
	stats.waves_total = director.wave_count()
	apply_quality(Graphics.tier, Graphics.profile())


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# -- Scene dressing ------------------------------------------------------------
func _build_environment() -> void:
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/textures/world/sky_dusk.jpg")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# The panorama is painted with its cool, smoke-streaked half in the image centre; turn that half toward the street.
	environment.sky_rotation = Vector3(0.0, PI, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.72)
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0
	# The haze matches the horizon band painted into the sky, so far blocks melt into it.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.47, 0.45, 0.47)
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.0
	environment.fog_aerial_perspective = 0.0
	environment.fog_sun_scatter = 0.08
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.94
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.1
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 85.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.6
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, SUN_TRAVEL, Vector3.UP)


func _build_defenses() -> void:
	for leaf_name: String in ["GateLeafA", "GateLeafB"]:
		var leaf: Node3D = geometry.find_child(leaf_name, true, false)
		if leaf:
			gate_leaves.append(leaf)
			gate_rest.append(leaf.rotation.y)
	patch_node = geometry.find_child("WallPatch", true, false)
	gate_body = _plate("GateBody", layout.gate_center, layout.gate_size)
	patch_body = _plate("PatchBody", layout.patch_center, layout.patch_size)


## Bullet stop for the gate leaves and the wall patch; removed when they fall.
func _plate(plate_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = plate_name
	body.collision_layer = Layers.DEFENSES
	body.collision_mask = 0
	body.set_meta("metal", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)
	return body


func _build_lamps() -> void:
	for spec: Dictionary in layout.lamps:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.76, 0.46)
		lamp.light_energy = spec.energy
		lamp.omni_range = spec.range
		lamp.omni_attenuation = 1.4
		lamp.shadow_enabled = false
		lamp.position = spec.position
		add_child(lamp)


func _particle_material(additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = EffectPool.soft_dot()
	material.disable_receive_shadows = true
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material


func _emitter(material: StandardMaterial3D, amount: int, life: float, speed: Vector2, size: Vector2, grow: float, start: Color,
		finish: Color, spread: float, box: Vector3) -> CPUParticles3D:
	var mesh := QuadMesh.new()
	mesh.material = material
	var ramp := Gradient.new()
	ramp.set_color(0, Color(start.r, start.g, start.b, 0.0))
	ramp.add_point(0.18, start)
	ramp.set_color(ramp.get_point_count() - 1, finish)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0 / grow))
	curve.add_point(Vector2(1.0, 1.0))
	var emitter := CPUParticles3D.new()
	emitter.mesh = mesh
	emitter.amount = amount
	emitter.lifetime = life
	emitter.preprocess = life
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = box
	emitter.direction = Vector3(0.12, 1.0, 0.05)
	emitter.spread = spread
	emitter.gravity = Vector3.ZERO
	emitter.initial_velocity_min = speed.x
	emitter.initial_velocity_max = speed.y
	emitter.scale_amount_min = size.x
	emitter.scale_amount_max = size.y
	emitter.scale_amount_curve = curve
	emitter.color_ramp = ramp
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return emitter


func _build_fires() -> void:
	var flame_material := _particle_material(true)
	var smoke_material := _particle_material(false)
	for spec: Dictionary in layout.fires:
		var size: float = spec.scale
		var root := Node3D.new()
		root.name = "Fire%02d" % fire_nodes.size()
		root.position = spec.position
		var flames := _emitter(flame_material, 14, 0.75, Vector2(1.0, 2.0) * size, Vector2(0.5, 1.0) * size, 0.6,
			Color(1.0, 0.62, 0.2, 0.85), Color(0.8, 0.12, 0.02, 0.0), 14.0, Vector3(0.45, 0.1, 0.45) * size)
		root.add_child(flames)
		var smoke := _emitter(smoke_material, 10, 3.6, Vector2(1.6, 2.8) * size, Vector2(1.4, 2.4) * size, 3.0,
			Color(0.09, 0.085, 0.08, 0.55), Color(0.2, 0.19, 0.18, 0.0), 10.0, Vector3(0.4, 0.1, 0.4) * size)
		smoke.position.y = 0.8 * size
		root.add_child(smoke)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.5, 0.18)
		glow.light_energy = 2.2 * size
		glow.omni_range = 9.0 * size
		glow.shadow_enabled = false
		glow.position.y = 0.6
		root.add_child(glow)
		fire_lights.append(glow)
		add_child(root)
		fire_nodes.append(root)


func _build_smoke() -> void:
	var material := _particle_material(false)
	for spec: Dictionary in layout.smokes:
		var size: float = spec.scale
		var column := _emitter(material, 9, 16.0, Vector2(2.2, 3.4), Vector2(9.0, 14.0) * size, 2.6,
			Color(0.1, 0.095, 0.09, 0.42), Color(0.22, 0.2, 0.19, 0.0), 6.0, Vector3(2.0, 0.5, 2.0) * size)
		column.name = "SmokeColumn"
		column.position = spec.position
		column.direction = Vector3(0.35, 1.0, 0.1)
		add_child(column)


func apply_quality(_tier: String, settings: Dictionary) -> void:
	if sun:
		sun.shadow_enabled = settings.shadows
		sun.directional_shadow_max_distance = settings.shadow_distance
	if environment:
		environment.glow_enabled = settings.glow
	for index: int in fire_nodes.size():
		fire_nodes[index].visible = index < int(settings.fires)


# -- Match flow ------------------------------------------------------------------
func begin_match() -> void:
	if running:
		return
	running = true
	over = false
	idle_view = false
	stats = MatchStats.new()
	stats.waves_total = director.wave_count()
	defender.aim.reset()
	defender.set_input_enabled(true)
	Events.weapon_changed.emit(defender.weapon_index, defender.weapon)
	Events.ammo_changed.emit(defender.weapon.state.ammo, defender.weapon.data.magazine_size)
	Events.grenades_changed.emit(defender.grenade_count, defender.grenade_data.capacity)
	director.begin()
	Events.match_started.emit()


func _process(delta: float) -> void:
	clock += delta
	if running and not over:
		stats.time += delta
	if idle_view and defender:
		# Menu backdrop: the gun sweeps the street on its own.
		defender.aim.target_yaw = sin(clock * 0.16) * 30.0
		defender.aim.target_pitch = -5.0 + sin(clock * 0.11) * 2.5
	gate_shake = move_toward(gate_shake, 0.0, delta * 5.0)
	if not defense.gate_destroyed:
		for index: int in gate_leaves.size():
			var wobble: float = sin(clock * 68.0 + float(index) * 1.7) * deg_to_rad(gate_shake)
			gate_leaves[index].rotation.y = gate_rest[index] + wobble
	for index: int in fire_lights.size():
		var light: OmniLight3D = fire_lights[index]
		var base: float = light.omni_range * 0.25
		light.light_energy = base * (0.78 + 0.22 * sin(clock * (9.0 + float(index) * 1.3)) * sin(clock * 3.7 + float(index)))
	if end_left >= 0.0:
		end_left -= delta / maxf(Engine.time_scale, 0.05)
		if end_left < 0.0:
			_finish(end_victory)


func _on_wave_started(index: int, _total: int) -> void:
	stats.wave = index + 1
	Sound.play("wave_horn", -4.0)


func _on_wave_cleared(index: int, total: int) -> void:
	stats.waves_cleared = index + 1
	# Nothing is handed out after the last wave: there is nobody left to use it on.
	if index + 1 >= total or over or wave_set == null or index >= wave_set.waves.size():
		return
	var wave: WaveData = wave_set.waves[index]
	var taken: Dictionary = defender.resupply(wave.resupply_rockets, wave.resupply_grenades)
	if taken.rockets > 0 or taken.grenades > 0:
		Sound.play("resupply", -5.0)
		Events.resupplied.emit(taken.rockets, taken.grenades)


func _on_weapon_fired(weapon: Node) -> void:
	var source := weapon as Weapon
	if source == null or source.data.counts_for_accuracy():
		stats.shots += 1
	else:
		stats.rockets += 1


func _on_grenade_thrown(_target: Vector3) -> void:
	stats.grenades += 1


func _on_explosion(_at: Vector3, _radius: float, kills: int) -> void:
	stats.blast_kills += kills


func _on_zombie_hit(_at: Vector3, _headshot: bool, _lethal: bool) -> void:
	stats.hits += 1


func _on_zombie_killed(zombie: Node3D, headshot: bool) -> void:
	stats.kills += 1
	if headshot:
		stats.headshots += 1
	var fallen := zombie as Zombie
	if fallen != null and fallen.data.id != &"walker":
		stats.special_kills += 1
		if fallen.data.is_boss:
			stats.bosses += 1


func _on_boss_appeared(_zombie: Node3D) -> void:
	defender.jolt(0.8)


func _on_boss_fell(zombie: Node3D) -> void:
	# The ground shakes when it comes down.
	defender.jolt(1.6)
	effects.burst("dust", zombie.global_position + Vector3(0.0, 0.3, 0.0), Vector3.UP, 4.0)


func _on_struck(target: String, at: Vector3, amount: float) -> void:
	var outward := Vector3(-signf(at.x), 0.3, 0.0).normalized()
	# A walker's claw is the measure; a brute's fists and the boss land several times as hard.
	var weight: float = clampf(amount / 3.0, 1.0, 6.0)
	var heavy: float = (weight - 1.0) / 5.0
	if target == "gate":
		gate_shake = minf(gate_shake + 0.55 * sqrt(weight), 3.2)
		effects.burst("spark", at, outward, 1.0 + heavy * 1.5)
		Sound.play_variant_at("gate_hit", 2, at, -2.0 + heavy * 6.0, randf_range(0.9, 1.1) * (1.0 - heavy * 0.4))
	else:
		effects.burst("dust", at, outward, 1.0 + heavy * 2.0)
		Sound.play_variant_at("wall_hit", 2, at, -4.0 + heavy * 6.0, randf_range(0.9, 1.1) * (1.0 - heavy * 0.4))
	if heavy > 0.5:
		defender.jolt(0.25 * heavy)


func _on_gate_destroyed() -> void:
	gate_body.collision_layer = 0
	gate_shake = 0.0
	var swing: Array[float] = [104.0, -104.0]
	for index: int in gate_leaves.size():
		var tween: Tween = create_tween()
		tween.tween_property(gate_leaves[index], "rotation:y", gate_rest[index] + deg_to_rad(swing[index % 2]), 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var center: Vector3 = layout.gate_center
	effects.burst("smoke", center + Vector3(-1.0, -0.6, 0.0), Vector3(-1.0, 0.4, 0.0), 1.2)
	effects.burst("spark", center, Vector3(-1.0, 0.5, 0.0), 2.0)
	Sound.play_at("gate_break", center, 2.0)
	Sound.play("critical", -6.0)
	defender.jolt(1.3)
	horde.open_breach("gate")


func _on_wall_breached() -> void:
	if over:
		return
	over = true
	director.stop()
	defender.set_input_enabled(false)
	patch_body.collision_layer = 0
	if patch_node:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(patch_node, "position:x", patch_node.position.x - 3.2, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(patch_node, "rotation:z", deg_to_rad(74.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(patch_node, "position:y", patch_node.position.y - 0.4, 0.7)
	var center: Vector3 = layout.patch_center
	effects.burst("smoke", center + Vector3(1.0, -0.4, 0.0), Vector3(1.0, 0.4, 0.0), 1.5)
	effects.burst("dust", center + Vector3(0.8, 0.6, 1.5), Vector3(1.0, 0.5, 0.0), 2.5)
	effects.burst("dust", center + Vector3(0.8, 0.6, -1.5), Vector3(1.0, 0.5, 0.0), 2.5)
	Sound.play_at("wall_break", center, 4.0)
	Sound.play("alarm", -3.0)
	defender.jolt(2.2)
	horde.open_breach("wall")
	if not defense.gate_destroyed:
		horde.open_breach("gate")
	Engine.time_scale = 0.5
	end_victory = false
	end_left = DEFEAT_DELAY


func _on_waves_finished() -> void:
	if over:
		return
	over = true
	defender.set_input_enabled(false)
	Sound.play("wave_clear", -2.0)
	end_victory = true
	end_left = VICTORY_DELAY


func _finish(victory: bool) -> void:
	Engine.time_scale = 1.0
	running = false
	stats.victory = victory
	stats.wall_left = defense.wall_fraction()
	stats.gate_left = defense.gate_fraction()
	Events.match_finished.emit(victory, stats.to_dict())


## Yaw in degrees (positive to the right) at which the gun faces a point; used by the HUD's threat arrows.
func yaw_to(point: Vector3) -> float:
	return defender.aim_for(point).x
