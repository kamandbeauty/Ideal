extends Node3D

const EnvironmentScript = preload("res://scripts/level/environment.gd")
const CharacterScript = preload("res://scripts/level/character.gd")
const GateScript = preload("res://scripts/level/gates.gd")
const HudScript = preload("res://scripts/level/hud.gd")
const SoundScript = preload("res://scripts/level/sound_effects.gd")
const END_Z := 165.0
const WALK_SPEED := 2.6
@export_range(0.05, 2.0, 0.01) var fire_interval := 0.32

var hero
var camera: Camera3D
var hud
var gate
var soldiers: Array = []
var enemies: Array = []
var running := true
var kills := 0
var coins := 0
var ammo := 30
var reload_time := 0.0
var message_time := 5.0
var message := "برای حرکت، انگشت خود را به چپ و راست بکشید."
var pending_drag := 0.0
var sound

func _ready() -> void:
	add_child(EnvironmentScript.new())
	sound = SoundScript.new()
	add_child(sound)
	hero = new_character("hero", Vector3(0, 0.05, 2))
	hero.defeated.connect(on_character_defeated)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 62
	camera.position = Vector3(0, 7.5, -10)
	add_child(camera)
	camera.look_at(Vector3(0, 1, 15), Vector3.UP)
	gate = GateScript.new()
	gate.position = Vector3(0, 0, 65)
	gate.crossed.connect(on_gate_crossed)
	gate.chosen.connect(on_gate_chosen)
	add_child(gate)
	# Each group activates only when the hero approaches it.
	for i in range(4):
		spawn_enemy("zombie", Vector3(float(i % 3 - 1) * 2.2, 0.05, 30 + i * 5))
	for i in range(8):
		spawn_enemy("runner" if i % 3 == 0 else "zombie", Vector3(float(i % 3 - 1) * 2.2, 0.05, 88 + i * 7))
	spawn_enemy("brute", Vector3(0, 0.05, 153))
	hud = HudScript.new()
	add_child(hud)
	hud.retry_requested.connect(func(): get_tree().reload_current_scene())
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/launcher.tscn"))

func new_character(kind: String, location: Vector3):
	var actor = CharacterScript.new()
	actor.position = location
	add_child(actor)
	actor.setup(kind)
	return actor

func spawn_enemy(kind: String, location: Vector3) -> void:
	var enemy = new_character(kind, location)
	enemy.defeated.connect(on_character_defeated)
	enemies.append(enemy)

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	# The camera looks along +Z, so screen-right points toward world -X.
	if event is InputEventScreenDrag:
		pending_drag -= event.relative.x * 0.018
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pending_drag -= event.relative.x * 0.018

func _physics_process(delta: float) -> void:
	if not running:
		return
	message_time = maxf(0, message_time - delta)
	hero.position.x = clampf(hero.position.x + pending_drag, -4.7, 4.7)
	pending_drag = 0
	var horizontal := Input.get_axis("ui_left", "ui_right") * 5.0
	var forward := WALK_SPEED if hero.position.z < END_Z else 0.0
	hero.step_motion(Vector3(horizontal, 0, forward), delta)
	hero.position.x = clampf(hero.position.x, -4.7, 4.7)
	hero.update_animation(delta, forward > 0 or horizontal != 0)
	if is_instance_valid(gate):
		gate.check_crossing(hero.position.z)
	update_squad(delta)
	update_enemies(delta)
	if not running:
		return
	if reload_time > 0:
		reload_time -= delta
		if reload_time <= 0:
			ammo = 30
	if hero.fire_timer <= 0 and reload_time <= 0:
		if hero_fire():
			hero.fire_timer = fire_interval
			ammo -= 1
			if ammo <= 0:
				reload_time = 1.8
				sound.play_effect("reload")
	camera.position = camera.position.lerp(Vector3(hero.position.x * 0.25, 7.5, hero.position.z - 12), minf(delta * 3, 1))
	camera.look_at(Vector3(hero.position.x * 0.25, 1, hero.position.z + 13), Vector3.UP)
	if hero.position.z >= END_Z and enemies.is_empty():
		finish(true)
	var instruction := message if message_time > 0 else ""
	if is_instance_valid(gate) and gate.selection == 0 and hero.position.z > 43 and hero.position.z < 55:
		instruction = "به سمت دروازه دلخواه حرکت کنید تا به آن شلیک شود."
	elif reload_time > 0 and instruction == "":
		instruction = "در حال پر کردن خشاب"
	hud.update_status(hero.health, soldiers.size(), coins, ammo, instruction)

func formation_position(index: int, total: int) -> Vector3:
	var column: int = index % 4
	var row: int = index / 4
	var count: int = mini(4, total - row * 4)
	var center := clampf(hero.position.x, -3.0, 3.0)
	var center_stagger := 1.2 if count % 2 == 1 and column == count / 2 else 0.0
	return Vector3(center + (float(column) - (count - 1) * 0.5) * 1.35, 0.05, hero.position.z - 2.6 - row * 1.8 - center_stagger)

func update_squad(delta: float) -> void:
	for i in range(soldiers.size()):
		var soldier = soldiers[i]
		var desired := formation_position(i, soldiers.size())
		desired.y = soldier.position.y
		var difference: Vector3 = desired - soldier.position
		var motion := difference * 4.0
		motion.y = 0
		if motion.length() > 7:
			motion = motion.normalized() * 7
		soldier.step_motion(motion, delta)
		soldier.update_animation(delta, motion.length() > 0.2)
		if soldier.fire_timer <= 0:
			var target = nearest_enemy(soldier.position, 25.0)
			if target != null:
				shoot_at(soldier, target.global_position + Vector3(0, 1.2, 0), 10)
				soldier.fire_timer = 0.7

func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var dz: float = enemy.position.z - hero.position.z
		enemy.visible = absf(dz) < 60
		if dz > 30:
			continue
		var victim = hero
		var closest: float = enemy.position.distance_to(hero.position)
		for soldier in soldiers:
			var distance: float = enemy.position.distance_to(soldier.position)
			if distance < closest:
				closest = distance
				victim = soldier
		var velocity := Vector3.ZERO
		if closest > 1.35:
			velocity = (victim.position - enemy.position).normalized() * enemy.speed
			velocity.y = 0
		enemy.step_motion(velocity, delta)
		enemy.update_animation(delta, closest > 1.35)
		if closest <= 1.5 and enemy.attack_timer <= 0:
			enemy.attack_timer = 1.2
			victim.apply_damage(16 if enemy.role == "brute" else 8)
			if victim == hero:
				sound.play_effect("hurt")
			if not running:
				return

func nearest_enemy(origin: Vector3, maximum: float):
	var result = null
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var distance: float = origin.distance_to(enemy.position)
		if distance < maximum:
			maximum = distance
			result = enemy
	return result

func hero_fire() -> bool:
	if is_instance_valid(gate) and gate.selection == 0:
		var distance: float = gate.position.z - hero.position.z
		if distance > 1 and distance < 12:
			var side := -1 if hero.position.x < 0 else 1
			shoot_at(hero, gate.global_position + Vector3(side * 3, 2, 0), 18)
			return true
	var target = nearest_enemy(hero.position, 27.0)
	if target == null:
		# Keep firing down the bridge, even between enemy waves. Reloading and
		# the existing raycast, cadence and ammunition rules still apply.
		shoot_at(hero, hero.global_position + Vector3(0, 1.25, 27), 18)
	else:
		shoot_at(hero, target.global_position + Vector3(0, 1.2, 0), 18)
	return true

func shoot_at(shooter, destination: Vector3, damage: float) -> void:
	var origin: Vector3 = shooter.global_position + Vector3(0, 1.25, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 4 | 8
	query.exclude = [shooter.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end := destination
	if not hit.is_empty():
		end = hit.position
		var collider = hit.collider
		if collider.has_meta("gate_pair"):
			collider.get_meta("gate_pair").select(int(collider.get_meta("gate_side")))
		elif collider.has_method("apply_damage"):
			collider.apply_damage(damage)
			sound.play_effect("impact")
			show_impact(end)
	shooter.show_shot()
	sound.play_effect("rifle")
	var tracer_origin := origin
	if is_instance_valid(shooter.muzzle_flash):
		tracer_origin = shooter.muzzle_flash.global_position
	show_tracer(tracer_origin, end)

func show_impact(location: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	spark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.7, 0.23)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.material_override = material
	add_child(spark)
	spark.global_position = location
	get_tree().create_timer(0.08).timeout.connect(spark.queue_free)
	# Short-lived CPU particles avoid creating a per-hit light on mobile.
	var particles := CPUParticles3D.new()
	particles.name = "ImpactSparks"
	particles.amount = 8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.3
	particles.direction = Vector3(0, 1, -0.5)
	particles.spread = 65.0
	particles.gravity = Vector3(0, -8, 0)
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.color = Color(1.0, 0.55, 0.12)
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.045
	particle_mesh.height = 0.09
	particle_mesh.radial_segments = 4
	particle_mesh.rings = 2
	particle_mesh.material = material
	particles.mesh = particle_mesh
	add_child(particles)
	particles.global_position = location
	particles.emitting = true
	get_tree().create_timer(0.65).timeout.connect(particles.queue_free)

func show_tracer(origin: Vector3, end: Vector3) -> void:
	var length := origin.distance_to(end)
	if length < 0.01:
		return
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, length)
	line.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.85, 0.34)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = mat
	add_child(line)
	line.global_position = (origin + end) / 2
	line.look_at(end, Vector3.UP)
	get_tree().create_timer(0.08).timeout.connect(line.queue_free)

func on_gate_chosen(side: int) -> void:
	sound.play_effect("gate")
	message = "دروازه چپ انتخاب شد" if side < 0 else "دروازه راست انتخاب شد"
	message_time = 2

func on_gate_crossed(effect: String) -> void:
	var number := soldiers.size() + 1 if effect == "double" else 3
	var to_add := mini(10 - soldiers.size(), number)
	for i in range(to_add):
		var soldier = new_character("soldier", formation_position(soldiers.size(), soldiers.size() + (to_add - i)))
		soldier.defeated.connect(on_character_defeated)
		soldiers.append(soldier)
	message = "نیروهای تازه به گروه پیوستند!"
	message_time = 3

func on_character_defeated(actor) -> void:
	if actor == hero:
		finish(false)
	elif soldiers.has(actor):
		soldiers.erase(actor)
	else:
		enemies.erase(actor)
		kills += 1
		coins += 5

func finish(win: bool) -> void:
	if not running:
		return
	running = false
	sound.play_effect("victory" if win else "defeat")
	hud.show_result(win, kills, soldiers.size())
