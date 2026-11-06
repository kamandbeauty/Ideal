class_name BattlefieldTarget
extends AnimatableBody3D

signal destroyed(target: BattlefieldTarget)
signal health_changed(target: BattlefieldTarget)

@export_enum("RADAR", "TANK", "TRANSPORT") var target_type: String = "RADAR"
var callsign: String = "TARGET"
var max_health: float = 120.0
var health: float = 120.0
var patrol_extent: float = 0.0
var patrol_speed: float = 2.2
var is_destroyed: bool = false

var _home: Vector3
var _patrol_direction: float = 1.0
var _visual: Node3D
var _collision: CollisionShape3D
var _smoke: Node3D
var _label: Label3D


func _ready() -> void:
	_home = position
	health = max_health
	collision_layer = 2
	collision_mask = 0
	add_to_group("damageable")
	_build_model()


func _physics_process(delta: float) -> void:
	if is_destroyed or patrol_extent <= 0.0:
		return
	var new_x := position.x + _patrol_direction * patrol_speed * delta
	if new_x >= _home.x + patrol_extent:
		new_x = _home.x + patrol_extent
		_patrol_direction = -1.0
	elif new_x <= _home.x - patrol_extent:
		new_x = _home.x - patrol_extent
		_patrol_direction = 1.0
	position.x = new_x


func receive_damage(amount: float) -> bool:
	if is_destroyed or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	_smoke.visible = health < max_health * 0.55
	health_changed.emit(self)
	if health <= 0.0:
		is_destroyed = true
		remove_from_group("damageable")
		_collision.set_deferred("disabled", true)
		_label.text = "NEUTRALIZED"
		_label.modulate = Color("a3a69a")
		_visual.rotation_degrees.z = 7.0
		_visual.position.y = -0.35
		destroyed.emit(self)
	return true


func damage_center() -> Vector3:
	return global_position + Vector3(0, 2.0, 0)


func _build_model() -> void:
	var armor := ShapeFactory.material(Color("716d55"), 0.25, 0.87)
	var dark := ShapeFactory.material(Color("333b32"), 0.35, 0.85)
	var sand := ShapeFactory.material(Color("a8916c"))
	var black := ShapeFactory.material(Color("242824"))
	_collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.4, 4.2, 7.0) if target_type != "RADAR" else Vector3(6.0, 8.0, 6.0)
	_collision.position.y = box.size.y * 0.5
	_collision.shape = box
	add_child(_collision)
	_visual = Node3D.new()
	add_child(_visual)
	match target_type:
		"TANK":
			_build_tank(armor, dark, black)
		"TRANSPORT":
			_build_transport(armor, dark, black, sand)
		_:
			_build_radar(armor, dark, sand)
	_smoke = Node3D.new()
	_smoke.visible = false
	_visual.add_child(_smoke)
	var smoke_mat := ShapeFactory.material(Color("4a4841"))
	for i in range(3):
		var puff := ShapeFactory.sphere(
			_smoke,
			Vector3(1.9 + i * 0.65, 1.8 + i * 0.6, 1.9 + i * 0.65),
			Vector3(0.35 * i, 4.2 + i * 1.2, 0),
			smoke_mat,
			8
		)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label = Label3D.new()
	_label.text = callsign + "  /  " + target_type
	_label.font_size = 40
	_label.pixel_size = 0.025
	_label.modulate = Color("f2c46f")
	_label.outline_size = 6
	_label.outline_modulate = Color("222820")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = false
	_label.position = Vector3(0, 10.5 if target_type == "RADAR" else 6.0, 0)
	add_child(_label)


func _build_tank(armor: Material, dark: Material, black: Material) -> void:
	ShapeFactory.box(_visual, Vector3(4.0, 1.35, 6.0), Vector3(0, 1.2, 0), armor)
	for side in [-1.0, 1.0]:
		ShapeFactory.box(_visual, Vector3(1.05, 1.25, 6.5), Vector3(side * 2.25, 0.75, 0), black)
		for z in [-2.3, -1.15, 0.0, 1.15, 2.3]:
			var wheel := ShapeFactory.cylinder(
				_visual, 0.48, 0.16, Vector3(side * 2.82, 0.7, z), dark, 8
			)
			wheel.rotation_degrees.z = 90
	ShapeFactory.box(_visual, Vector3(3.0, 0.95, 3.4), Vector3(0, 2.3, 0.25), dark)
	ShapeFactory.box(_visual, Vector3(2.8, 0.25, 2.9), Vector3(0, 2.85, 0.25), armor)
	var gun := ShapeFactory.cylinder(_visual, 0.23, 4.2, Vector3(0, 2.4, -3.0), dark, 10)
	gun.rotation_degrees.x = 90


func _build_transport(armor: Material, dark: Material, black: Material, sand: Material) -> void:
	ShapeFactory.box(_visual, Vector3(3.7, 0.7, 7.3), Vector3(0, 1.1, 0), dark)
	ShapeFactory.box(_visual, Vector3(3.6, 2.2, 2.5), Vector3(0, 2.15, -2.15), armor)
	ShapeFactory.box(_visual, Vector3(3.65, 2.5, 4.3), Vector3(0, 2.35, 1.4), sand)
	ShapeFactory.box(_visual, Vector3(3.2, 0.7, 0.1), Vector3(0, 2.65, -3.42), dark)
	for side in [-1.0, 1.0]:
		for z in [-2.4, 0.8, 2.7]:
			var wheel := ShapeFactory.cylinder(
				_visual, 0.72, 0.38, Vector3(side * 1.95, 0.75, z), black, 10
			)
			wheel.rotation_degrees.z = 90


func _build_radar(armor: Material, dark: Material, sand: Material) -> void:
	ShapeFactory.box(_visual, Vector3(5.6, 2.8, 5.6), Vector3(0, 1.4, 0), sand)
	ShapeFactory.box(_visual, Vector3(5.9, 0.3, 5.9), Vector3(0, 2.9, 0), dark)
	ShapeFactory.box(_visual, Vector3(1.0, 3.0, 1.0), Vector3(0, 4.5, 0), armor)
	ShapeFactory.box(_visual, Vector3(5.4, 2.5, 0.28), Vector3(0, 6.4, 0), dark)
	for x in [-2.3, -1.15, 0.0, 1.15, 2.3]:
		ShapeFactory.box(_visual, Vector3(0.12, 2.5, 0.32), Vector3(x, 6.4, -0.2), sand)
	for y in [5.4, 6.4, 7.4]:
		ShapeFactory.box(_visual, Vector3(5.4, 0.1, 0.32), Vector3(0, y, -0.2), sand)
