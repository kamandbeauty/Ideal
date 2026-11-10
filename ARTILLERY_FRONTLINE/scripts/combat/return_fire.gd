class_name ReturnFire
extends Node
## Enemy emplacements and tanks answer the artillery battery once they are alerted
## by the player's fire. Deliberately light: a shell every 15-19 seconds per shooter,
## low hit chance, and modest damage per hit. Enough hits destroy the battery.

signal battery_hit(health_ratio: float, point: Vector3)
signal battery_destroyed

const RANGE: float = 620.0
const BATTERY_MAX: float = 600.0
const HIT_DAMAGE: float = 30.0
const HIT_RADIUS: float = 6.0
const SHELL_SPEED: float = 190.0
const FIRST_SHOT_DELAY: Vector2 = Vector2(2.5, 4.5)
const COOLDOWN: Dictionary = {"emplacement": 15.0, "tank": 19.0}
const HIT_CHANCE: Dictionary = {"emplacement": 0.3, "tank": 0.22}

var enabled: bool = false
var battery_position: Vector3 = Vector3.ZERO
var battery_health: float = BATTERY_MAX
var effects: EffectPool
var shooters: Array[EnemyTarget] = []
var cooldowns: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 90210

func set_shooters(targets: Array) -> void:
	shooters.clear()
	for target in targets:
		if target is EnemyTarget and COOLDOWN.has(target.data.kind):
			shooters.append(target)

func health_ratio() -> float:
	return battery_health / BATTERY_MAX

func _process(delta: float) -> void:
	if not enabled or battery_health <= 0.0:
		return
	for target in shooters:
		if not is_instance_valid(target) or target.health.is_destroyed or not target.alert:
			continue
		if target.global_position.distance_to(battery_position) >= RANGE:
			continue
		if not cooldowns.has(target):
			cooldowns[target] = rng.randf_range(FIRST_SHOT_DELAY.x, FIRST_SHOT_DELAY.y)
		cooldowns[target] = float(cooldowns[target]) - delta
		if float(cooldowns[target]) <= 0.0:
			var kind: String = target.data.kind
			cooldowns[target] = COOLDOWN[kind] * rng.randf_range(0.8, 1.25)
			fire(target)

func fire(target: EnemyTarget) -> void:
	var kind: String = target.data.kind
	var origin: Vector3 = target.damage_point()
	var hit: bool = rng.randf() < float(HIT_CHANCE[kind])
	var impact: Vector3
	if hit:
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(0.0, HIT_RADIUS)
		impact = battery_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	else:
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = rng.randf_range(12.0, 28.0)
		impact = battery_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	impact.y = TerrainSampler.height_at(impact.x, impact.z)
	var flight_time: float = maxf(0.6, origin.distance_to(impact) / SHELL_SPEED)
	_show_shell(origin, impact, flight_time, hit)
	Sound.play_at("cannon", origin, -9.0, 0.8)
	Sound.play_voice("incoming")

func _show_shell(origin: Vector3, impact: Vector3, flight_time: float, hit: bool) -> void:
	var shell := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	shell.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.35, 0.12)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.3, 0.08)
	material.emission_energy_multiplier = 2.0
	shell.material_override = material
	add_child(shell)
	shell.global_position = origin
	var apex: float = clampf(origin.distance_to(impact) * 0.25, 20.0, 90.0)
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float): shell.global_position = _arc(origin, impact, apex, t), 0.0, 1.0, flight_time)
	tween.tween_callback(resolve_shell.bind(shell, impact, hit))

func _arc(origin: Vector3, impact: Vector3, apex: float, t: float) -> Vector3:
	return origin.lerp(impact, t) + Vector3.UP * apex * sin(PI * t)

## Lands one shell: visual blast, then damage to the battery if it was a hit.
func resolve_shell(shell: Node, impact: Vector3, hit: bool) -> void:
	if is_instance_valid(shell):
		shell.queue_free()
	if effects:
		effects.explode(impact, Vector3.UP, 3.2 if hit else 2.4, impact.y)
	if not hit or battery_health <= 0.0:
		return
	battery_health = maxf(0.0, battery_health - HIT_DAMAGE)
	Sound.play_at("impact", impact, -4.0)
	Events.camera_shake_requested.emit(0.22)
	battery_hit.emit(health_ratio(), impact)
	if battery_health <= 0.0:
		enabled = false
		battery_destroyed.emit()
