class_name Shot
extends Node3D
## A projectile in flight. Homing on its target, with optional splash and slow.

var battle
var target: Enemy
var speed := 26.0
var damage := 10.0
var splash := 0.0
var slow := 0.0
var slow_time := 0.0
var color := Color.WHITE

var _life := 5.0


func setup(battle_ref, target_enemy: Enemy, kind: String, level: int) -> void:
	battle = battle_ref
	target = target_enemy
	damage = TowerData.damage_for(kind, level)
	splash = TowerData.splash_for(kind, level)
	slow = TowerData.slow_for(kind, level)
	slow_time = TowerData.slow_time_for(kind, level)
	color = TowerData.color(kind)
	speed = 38.0 if kind == "sentry" else 20.0
	_build_visual(kind)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_fizzle()
		return
	if target == null or not is_instance_valid(target) or not target.alive:
		_fizzle()
		return

	var aim := target.global_position + Vector3(0.0, 0.75, 0.0)
	var to_aim := aim - global_position
	var step := speed * delta
	if to_aim.length() <= step:
		global_position = aim
		_impact()
	else:
		global_position += to_aim.normalized() * step
		rotation.y += delta * 8.0


func _impact() -> void:
	if splash > 0.0:
		battle.apply_area_damage(global_position, splash, damage, slow, slow_time, color)
	else:
		if target != null and is_instance_valid(target) and target.alive:
			target.take_damage(damage)
		battle.spawn_burst(global_position, color, 0.7)
	queue_free()


func _fizzle() -> void:
	if splash > 0.0 and is_inside_tree():
		battle.apply_area_damage(global_position, splash, damage, slow, slow_time, color)
	queue_free()


func _build_visual(kind: String) -> void:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22 if kind == "cannon" else 0.13
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	ball.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	ball.material_override = material
	add_child(ball)
