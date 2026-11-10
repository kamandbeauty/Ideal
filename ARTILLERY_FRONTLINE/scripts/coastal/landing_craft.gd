class_name LandingCraft
extends StaticBody3D
## Moving, destructible amphibious landing craft; delivers infantry to the beachhead.
signal arrived(craft: LandingCraft)
signal died(craft: LandingCraft)

var start: Vector3 = Vector3.ZERO
var destination: Vector3 = Vector3.ZERO
var progress: float = 0.0
var speed: float = 0.07
## Troops and vehicles carried inside the hull. They leave through the ramp when
## the craft grounds, or spill out of the wreck if it is sunk on the way in.
var cargo: Array[String] = []
var ramp: Node3D
var model_root: Node3D
var has_arrived: bool = false
var bob_clock: float = 0.0
var health: float = 600.0
var max_health: float = 600.0
var dead: bool = false
var engine: AudioStreamPlayer3D
var collision: CollisionShape3D
var propellers: Array[Node3D] = []
var radar: Node3D
var wake_clock: float = 0.0

## Puts the craft on its landing point at once (tests and the smoke driver).
func ground_now() -> void:
	if dead:
		return
	progress = 1.0
	has_arrived = true
	_stop_engine()
	global_position = Vector3(destination.x, maxf(0.08, CoastalTerrain.height_at(destination.x, destination.z) + 0.15), destination.z)

func load_cargo(kinds: Array[String]) -> void:
	cargo = kinds.duplicate()

## Returns and clears the cargo so it can only be unloaded once.
func unload() -> Array[String]:
	var kinds: Array[String] = cargo.duplicate()
	cargo.clear()
	return kinds

## World point just outside the ramp, on the sea surface, where cargo steps off.
func disembark_point() -> Vector3:
	var point: Vector3
	if ramp and ramp.is_inside_tree():
		point = ramp.global_position
	else:
		point = global_position + global_transform.basis.z * 6.0
	point.y = 0.0
	return point

func configure(from: Vector3, to: Vector3) -> void:
	start = from
	destination = to
	global_position = from
	progress = 0.0
	has_arrived = false
	_start_engine()

## Diesel throb while under way; silent once grounded or sunk.
func _start_engine() -> void:
	if engine != null or not Sound.clips.has("boat_engine"):
		return
	engine = AudioStreamPlayer3D.new()
	engine.stream = Sound.looped("boat_engine")
	engine.max_distance = 900.0
	engine.unit_size = 40.0
	engine.volume_db = -12.0
	add_child(engine)
	if Sound.playback_enabled:
		engine.play()

func _stop_engine() -> void:
	if engine:
		engine.stop()

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("damageable")
	collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 3.2, 12.0)
	collision.shape = shape
	collision.position.y = 1.6
	add_child(collision)
	var path: String = "res://assets/models/landing_craft.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		ramp = model_root.find_child("Ramp", true, false) as Node3D
		radar = model_root.find_child("Radar", true, false) as Node3D
		for side in ["L", "R"]:
			var prop: Node3D = model_root.find_child("Propeller" + side, true, false) as Node3D
			if prop:
				propellers.append(prop)
	if model_root == null:
		model_root = Node3D.new()
		add_child(model_root)
		MeshFactory.box(model_root, "Hull", Vector3(0, 0.8, 0), Vector3(4.2, 1.6, 11.5), Color(0.45, 0.48, 0.42), true, "paint_sand")
		MeshFactory.box(model_root, "Superstructure", Vector3(0, 2.0, 3.6), Vector3(2.6, 1.6, 2.4), Color(0.5, 0.52, 0.46), true, "paint_sand")
		ramp = Node3D.new()
		ramp.name = "Ramp"
		ramp.position = Vector3(0, 0.8, -5.7)
		model_root.add_child(ramp)
		MeshFactory.box(ramp, "RampPlate", Vector3(0, 0, -1.5), Vector3(3.6, 0.18, 3.0), Color(0.4, 0.42, 0.38), true, "steel")

func is_dead() -> bool:
	return dead

func receive_damage(amount: float) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount * (0.35 if amount <= 25.0 else 0.85))
	if health <= 0.0:
		dead = true
		_stop_engine()
		collision_layer = 0
		collision.set_deferred("disabled", true)
		if model_root:
			var tween: Tween = create_tween().set_parallel(true)
			tween.tween_property(model_root, "rotation:z", 0.10, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(model_root, "position:y", -0.12, 1.4)
		if ramp:
			var ramp_tween: Tween = create_tween()
			ramp_tween.tween_property(ramp, "rotation:x", -0.35, 1.2)
		died.emit(self)

func react_to_explosion(point: Vector3, radius: float) -> void:
	if dead:
		return
	var distance: float = global_position.distance_to(point)
	if distance < radius * 1.6:
		receive_damage(160.0 * (1.0 - distance / (radius * 1.6)))

func tick(delta: float) -> void:
	if dead:
		return
	bob_clock += delta
	wake_clock += delta
	for prop in propellers:
		prop.rotate_object_local(Vector3.FORWARD, delta * (18.0 if not has_arrived else 4.0))
	if radar:
		radar.rotation.y += delta * 1.2
	if not has_arrived:
		progress = minf(1.0, progress + speed * delta)
		var point: Vector3 = start.lerp(destination, progress)
		point.y = maxf(0.08, CoastalTerrain.height_at(point.x, point.z) + 0.15) + sin(bob_clock * 1.4) * 0.08
		global_position = point
		var direction: Vector3 = destination - start
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			rotation.y = atan2(direction.x, direction.z)
		if progress >= 1.0:
			has_arrived = true
			_stop_engine()
			arrived.emit(self)
	if ramp and has_arrived:
		ramp.rotation.x = lerpf(ramp.rotation.x, -1.25, delta * 1.5)
