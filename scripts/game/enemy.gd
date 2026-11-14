class_name Enemy
extends Node3D
## One walking enemy. Follows the level path, takes damage, dies or leaks.

signal died(enemy: Enemy)
signal leaked(enemy: Enemy)

const MAX_SLOW := 0.8
const BAR_WIDTH := 0.9
const HIT_FLASH_TIME := 0.12

var kind: String = "grunt"
var max_health: float = 1.0
var health: float = 1.0
var speed: float = 1.0
var gold_reward: int = 0
var core_damage: int = 1
var alive := true

var _route: Array[Vector3] = []
var _waypoint := 1
var _slow_factor := 0.0
var _slow_timer := 0.0
var _hit_flash := 0.0
var _bob_time := 0.0
var _camera: Camera3D
var _body: Node3D
var _materials: Array[StandardMaterial3D] = []
var _bar_root: Node3D
var _bar_pivot: Node3D
var _bar_fill_material: StandardMaterial3D
var _base_color := Color.WHITE


func setup(enemy_kind: String, route: Array[Vector3], camera: Camera3D) -> void:
	kind = enemy_kind
	var data := EnemyData.get_type(kind)
	max_health = float(data["health"])
	health = max_health
	speed = float(data["speed"])
	gold_reward = int(data["gold"])
	core_damage = int(data["core_damage"])
	_base_color = data["color"]
	_route = route
	_camera = camera
	var body_scale := float(data["scale"])
	_build_visuals(body_scale)
	position = _route[0] if route.size() > 0 else Vector3.ZERO


func is_slowed() -> bool:
	return _slow_factor > 0.0


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_hit_flash = HIT_FLASH_TIME
	if health <= 0.0:
		_die()
	else:
		_update_health_bar()


func apply_slow(factor: float, duration: float) -> void:
	if not alive:
		return
	_slow_factor = maxf(_slow_factor, clampf(factor, 0.0, MAX_SLOW))
	_slow_timer = maxf(_slow_timer, duration)


func _physics_process(delta: float) -> void:
	if not alive or _route.is_empty():
		return
	_tick_effects(delta)
	if _waypoint >= _route.size():
		_leak()
		return

	var move_speed := speed * (1.0 - _slow_factor)
	var target := _route[_waypoint]
	var to_target := target - position
	to_target.y = 0.0
	var step := move_speed * delta
	if to_target.length() <= step:
		position = Vector3(target.x, 0.0, target.z)
		_waypoint += 1
		if _waypoint >= _route.size():
			_leak()
	else:
		position += to_target.normalized() * step


func _process(delta: float) -> void:
	if _bar_root == null or _camera == null or not is_inside_tree():
		return
	var direction := _camera.global_position - _bar_root.global_position
	if direction.length_squared() > 0.0001:
		_bar_root.look_at(_camera.global_position, Vector3.UP)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		var strength := _hit_flash / HIT_FLASH_TIME
		for material in _materials:
			material.emission_enabled = strength > 0.0
			material.emission = Color(1.0, 0.85, 0.7)
			material.emission_energy_multiplier = strength * 1.6
	_body.position.y = (sin(_bob_time * 9.0) * 0.05) if alive else 0.0


func _tick_effects(delta: float) -> void:
	_bob_time += delta
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 0.0


func _die() -> void:
	alive = false
	died.emit(self)
	_bar_root.visible = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
	tween.tween_callback(queue_free)


func _leak() -> void:
	if not alive:
		return
	alive = false
	leaked.emit(self)
	queue_free()


func _update_health_bar() -> void:
	var fraction := clampf(health / max_health, 0.0, 1.0)
	_bar_pivot.scale.x = maxf(fraction, 0.001)
	if _bar_fill_material != null:
		_bar_fill_material.albedo_color = UiTheme.DANGER.lerp(UiTheme.GOOD, fraction)
	if _bar_root != null:
		_bar_root.visible = fraction < 0.999


func _build_visuals(body_scale: float) -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_body.scale = Vector3.ONE * body_scale

	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.05
	torso.mesh = capsule
	var torso_material := _make_material(_base_color, 0.8)
	torso.material_override = torso_material
	torso.position.y = 0.62
	_body.add_child(torso)
	_materials.append(torso_material)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.5
	head.mesh = head_mesh
	var head_material := _make_material(_base_color.lightened(0.3), 0.6)
	head.material_override = head_material
	head.position = Vector3(0.0, 1.35, 0.05)
	_body.add_child(head)
	_materials.append(head_material)

	var eye_material := _make_material(Color(1.0, 0.35, 0.25), 0.2)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.4, 0.25)
	eye_material.emission_energy_multiplier = 1.4
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.05
		eye_mesh.height = 0.1
		eye.mesh = eye_mesh
		eye.material_override = eye_material
		eye.position = Vector3(0.09 * side, 1.4, 0.25)
		_body.add_child(eye)

	_build_health_bar(body_scale)


func _build_health_bar(body_scale: float) -> void:
	_bar_root = Node3D.new()
	_bar_root.name = "HealthBar"
	_bar_root.position.y = 1.95 * body_scale
	add_child(_bar_root)

	var back := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(BAR_WIDTH + 0.08, 0.15)
	back.mesh = back_mesh
	back.material_override = _make_flat_material(Color(0.02, 0.03, 0.05, 0.85))
	_bar_root.add_child(back)

	_bar_pivot = Node3D.new()
	_bar_pivot.position = Vector3(-BAR_WIDTH * 0.5, 0.0, 0.01)
	_bar_root.add_child(_bar_pivot)

	var fill := MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(BAR_WIDTH, 0.09)
	fill.mesh = fill_mesh
	_bar_fill_material = _make_flat_material(UiTheme.GOOD)
	fill.material_override = _bar_fill_material
	fill.position = Vector3(BAR_WIDTH * 0.5, 0.0, 0.0)
	_bar_pivot.add_child(fill)

	_bar_root.visible = false


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _make_flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material
