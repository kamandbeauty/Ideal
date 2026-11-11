class_name EnemyAircraft
extends CharacterBody3D
## Attack helicopter / fighter pass with spinning rotors, animated control
## surfaces, afterburner, weapon pylons and a burning persistent crash wreck.
signal died(aircraft: EnemyAircraft)
signal damaged(aircraft: EnemyAircraft, ratio: float)
signal shoot_requested(origin: Vector3, target: Vector3, damage: float, blast: float)

var kind: String = "helicopter"
var health: float = 320.0
var max_health: float = 320.0
var objective: Vector3 = Vector3.ZERO
var model_root: Node3D
var rotor: Node3D
var tail_rotor: Node3D
var ailerons: Array[Node3D] = []
var elevators: Array[Node3D] = []
var rudder: Node3D
var afterburners: Array[Node3D] = []
var collision: CollisionShape3D
var dead: bool = false
var clock: float = 0.0
var orbit_radius: float = 105.0
var altitude: float = 30.0
var angular_speed: float = 0.16
var phase: float = 0.0
var shoot_cooldown: float = 3.0
var crash_velocity: float = 0.0
var crash_spin: float = 0.0
var wrecked: bool = false
var rotor_speed: float = 24.0
## Smoke from the engine at 60% health and fire at 30%; both are built once and kept for the wreck.
const SMOKE_THRESHOLD: float = 0.6
const FIRE_THRESHOLD: float = 0.3
var smoke_plume: CPUParticles3D
var fire_plume: CPUParticles3D
## Metres the airframe drops after a hit; it eases back up as the aircraft recovers.
var hit_lurch: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.4 if kind == "helicopter" else 4.2
	collision.shape = shape
	add_child(collision)
	_build_model()

func configure(target: Vector3, aircraft_kind: String = "helicopter", start_phase: float = 0.0) -> void:
	var changed: bool = aircraft_kind != kind or model_root == null
	kind = aircraft_kind
	objective = target
	phase = start_phase
	if kind == "fighter":
		health = 240.0
		orbit_radius = 150.0
		altitude = 58.0
		angular_speed = 0.28
	else:
		health = 320.0
		orbit_radius = 95.0
		altitude = 30.0
		angular_speed = 0.14
	max_health = health
	shoot_cooldown = randf_range(2.0, 4.0)
	hit_lurch = 0.0
	if changed and is_inside_tree():
		if model_root:
			model_root.queue_free()
		model_root = null
		rotor = null
		tail_rotor = null
		rudder = null
		ailerons.clear()
		elevators.clear()
		afterburners.clear()
		var shape := SphereShape3D.new()
		shape.radius = 3.4 if kind == "helicopter" else 4.2
		collision.shape = shape
		_build_model()
	_update_position(0.0)

func _build_model() -> void:
	var path: String = "res://assets/models/helicopter.glb" if kind == "helicopter" else "res://assets/models/fighter.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		rotor = model_root.find_child("Rotor", true, false) as Node3D
		tail_rotor = model_root.find_child("TailRotor", true, false) as Node3D
		rudder = model_root.find_child("Rudder", true, false) as Node3D
		for side in ["L", "R"]:
			var aileron: Node3D = model_root.find_child("Aileron" + side, true, false) as Node3D
			if aileron:
				ailerons.append(aileron)
			var elevator: Node3D = model_root.find_child("Elevator" + side, true, false) as Node3D
			if elevator:
				elevators.append(elevator)
			var burner: Node3D = model_root.find_child("Afterburner" + side, true, false) as Node3D
			if burner:
				afterburners.append(burner)
	if model_root == null:
		model_root = Node3D.new()
		add_child(model_root)
		if kind == "helicopter":
			MeshFactory.sphere(model_root, "Fuselage", Vector3.ZERO, Vector3(1.3, 1.1, 3.0), Color(0.28, 0.32, 0.26), "paint_olive")
			MeshFactory.box(model_root, "Tail", Vector3(0, 0.3, 4.0), Vector3(0.3, 0.3, 4.5), Color(0.28, 0.32, 0.26), true, "paint_olive")
			rotor = Node3D.new()
			rotor.name = "Rotor"
			rotor.position.y = 1.2
			model_root.add_child(rotor)
			MeshFactory.box(rotor, "BladeA", Vector3.ZERO, Vector3(8.5, 0.05, 0.25), Color(0.1, 0.11, 0.1), false, "steel")
			MeshFactory.box(rotor, "BladeB", Vector3.ZERO, Vector3(0.25, 0.05, 8.5), Color(0.1, 0.11, 0.1), false, "steel")
		else:
			MeshFactory.sphere(model_root, "Fuselage", Vector3.ZERO, Vector3(0.9, 0.8, 4.5), Color(0.4, 0.43, 0.4), "paint_sand")
			MeshFactory.box(model_root, "Wing", Vector3(0, 0, 0.4), Vector3(9.0, 0.12, 1.8), Color(0.4, 0.43, 0.4), true, "paint_sand")
			MeshFactory.box(model_root, "Tail", Vector3(0, 0.8, 4.0), Vector3(0.12, 1.6, 1.2), Color(0.4, 0.43, 0.4), true, "paint_sand")

func is_dead() -> bool:
	return dead

## Formal armour rating (0 = unarmoured, 1 = full plate). Airframes are unarmoured on purpose: with armour,
## the 20-42 damage ground weapons would lose most of their damage to aircraft (see the Phase 3.6 audit).
var armor: float = 0.0

## Fraction of a hit of `amount` that this aircraft removes (0 for every aircraft; see DamageModel).
func damage_resistance(amount: float) -> float:
	return DamageModel.damage_resistance(amount, armor)

## Returns the health actually removed, for damage readouts.
func receive_damage(amount: float) -> float:
	if dead:
		return 0.0
	var before: float = health
	health = maxf(0.0, health - DamageModel.taken(amount, armor))
	var removed: float = before - health
	if removed > 0.0:
		hit_lurch = maxf(hit_lurch, clampf(removed / max_health * 8.0, 0.5, 4.0))
	damaged.emit(self, health / max_health)
	_update_damage_state()
	if health <= 0.0:
		_die()
	return removed

## Smoke below 60% health, fire below 30%. Each plume is built once.
func _update_damage_state() -> void:
	var ratio: float = health / max_health
	if smoke_plume == null and ratio <= SMOKE_THRESHOLD:
		smoke_plume = DamagePlume.make(self, Vector3(0.0, 1.2, -1.0), false, 1.0)
	if fire_plume == null and ratio <= FIRE_THRESHOLD:
		fire_plume = DamagePlume.make(self, Vector3(0.0, 0.9, -1.0), true, 1.0)

func react_to_explosion(point: Vector3, radius: float) -> void:
	if dead:
		return
	var distance: float = global_position.distance_to(point)
	if distance < radius * 1.5:
		receive_damage(140.0 * (1.0 - distance / (radius * 1.5)))

func _die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision.set_deferred("disabled", true)
	# The wreck keeps burning and smoking on its way down.
	if smoke_plume == null:
		smoke_plume = DamagePlume.make(self, Vector3(0.0, 1.2, -1.0), false, 1.0)
	if fire_plume == null:
		fire_plume = DamagePlume.make(self, Vector3(0.0, 0.9, -1.0), true, 1.0)
	crash_velocity = -6.0
	crash_spin = randf_range(0.8, 1.8) * (1.0 if randf() > 0.5 else -1.0)
	died.emit(self)

## Position of the orbit at a given flight clock (the value `clock` takes), with the current lurch.
func orbit_point(at_clock: float) -> Vector3:
	var angle: float = phase + at_clock * angular_speed
	return Vector3(objective.x + cos(angle) * orbit_radius, altitude + sin(at_clock * 0.7) * 2.0 - hit_lurch, objective.z + sin(angle) * orbit_radius * 0.7 - 20.0)

## Where the aircraft will be in `seconds`, following the same orbit. Used to lead shots.
func predicted_position(seconds: float) -> Vector3:
	return orbit_point(clock + seconds)

## Aim point (the aircraft's centre plus 1.2 m, as the aim assist uses) that a bullet of `speed` must be
## sent to so that it meets the aircraft. Bullets fly straight, so the flight time depends on the aim point;
## two refinements converge for every orbit used here.
func intercept_point(origin: Vector3, speed: float) -> Vector3:
	var aim: Vector3 = global_position + Vector3.UP * 1.2
	for _pass in range(2):
		var flight: float = (aim - origin).length() / maxf(speed, 1.0)
		aim = predicted_position(flight) + Vector3.UP * 1.2
	return aim

func _update_position(delta: float) -> void:
	clock += delta
	hit_lurch = maxf(0.0, hit_lurch - delta * 3.0)
	var angle: float = phase + clock * angular_speed
	var point: Vector3 = orbit_point(clock)
	var forward: Vector3 = point - global_position
	global_position = point
	if forward.length_squared() > 0.001:
		rotation.y = atan2(forward.x, forward.z)
		rotation.z = sin(angle) * 0.18
		rotation.x = clampf(forward.y * 0.08, -0.12, 0.12)

func _animate_flight(delta: float) -> void:
	if kind == "helicopter":
		rotor_speed = lerpf(rotor_speed, 24.0, delta * 2.0)
		if rotor:
			rotor.rotation.y += delta * rotor_speed
		if tail_rotor:
			tail_rotor.rotation.x += delta * rotor_speed * 4.5
		if model_root:
			model_root.position.y = sin(clock * 2.1) * 0.05
	else:
		if rotor:
			rotor.rotation.y += delta * 30.0
		var bank: float = rotation.z
		for index in range(ailerons.size()):
			var sign_value: float = 1.0 if index == 0 else -1.0
			ailerons[index].rotation.x = bank * 1.6 * sign_value
		for elevator in elevators:
			elevator.rotation.x = -rotation.x * 1.2 + sin(clock * 0.9) * 0.03
		if rudder:
			rudder.rotation.y = -bank * 0.8
		var burner_scale: float = 0.85 + sin(clock * 37.0) * 0.12
		for burner in afterburners:
			burner.scale = Vector3(1.0, burner_scale, 1.0)

func _physics_process(delta: float) -> void:
	if dead:
		if wrecked:
			return
		rotor_speed = maxf(0.0, rotor_speed - delta * 10.0)
		if rotor:
			rotor.rotation.y += delta * rotor_speed
		if tail_rotor:
			tail_rotor.rotation.x += delta * rotor_speed * 3.0
		crash_velocity -= 18.0 * delta
		global_position.y += crash_velocity * delta
		rotation.x += delta * crash_spin
		rotation.z += delta * crash_spin * 0.6
		var ground: float = CoastalTerrain.height_at(global_position.x, global_position.z)
		if global_position.y <= ground + 0.6:
			global_position.y = ground + 0.6
			wrecked = true
			rotation.x = randf_range(-0.25, 0.25)
			rotation.z = randf_range(-0.35, 0.35)
			set_physics_process(false)
		return
	_update_position(delta)
	_animate_flight(delta)
	shoot_cooldown -= delta
	if shoot_cooldown <= 0.0:
		shoot_cooldown = 3.2 if kind == "helicopter" else 5.0
		shoot_requested.emit(global_position, objective, 55.0 if kind == "helicopter" else 90.0, 3.0 if kind == "helicopter" else 4.0)
