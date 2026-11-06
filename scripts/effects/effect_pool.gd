class_name EffectPool
extends Node3D

const EXPLOSION_CAPACITY: int = 5
const SCORCH_CAPACITY: int = 12
var _explosions: Array[ExplosionEffect] = []
var _scorches: Array[MeshInstance3D] = []
var _next_effect: int = 0
var _next_scorch: int = 0
var _particle_scale: float = 1.0


func _ready() -> void:
	for i in range(EXPLOSION_CAPACITY):
		var explosion := ExplosionEffect.new()
		add_child(explosion)
		_explosions.append(explosion)
	var scorch_mat := ShapeFactory.material(Color("514b3c"))
	for i in range(SCORCH_CAPACITY):
		var decal := ShapeFactory.cylinder(self, 2.4, 0.025, Vector3.ZERO, scorch_mat, 14)
		decal.visible = false
		decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scorches.append(decal)


func explode(point: Vector3) -> void:
	var effect := _explosions[_next_effect]
	_next_effect = (_next_effect + 1) % _explosions.size()
	effect.particle_scale = _particle_scale
	effect.play_at(point)
	var scorch := _scorches[_next_scorch]
	_next_scorch = (_next_scorch + 1) % _scorches.size()
	scorch.global_position = Vector3(point.x, 0.08, point.z)
	scorch.visible = true


func set_particle_scale(value: float) -> void:
	_particle_scale = clampf(value, 0.1, 1.0)
