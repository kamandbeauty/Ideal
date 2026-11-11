extends CharacterBody3D

signal defeated(character)

var role := "hero"
var health := 100.0
var max_health := 100.0
var speed := 2.0
var attack_timer := 0.0
var fire_timer := 0.0
var run_clock := 0.0
var left_leg: Node3D
var right_leg: Node3D
var weapon: Node3D
var dead := false

func setup(kind: String) -> void:
	role = kind
	if kind == "soldier":
		health = 55
	elif kind == "zombie":
		health = 55
		speed = 2.0
	elif kind == "runner":
		health = 75
		speed = 3.1
	elif kind == "brute":
		health = 400
		speed = 1.1
	max_health = health
	collision_layer = 4 if is_enemy() else 2
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 1
	add_child(collider)
	var clothes := Color(0.32, 0.42, 0.28) if is_enemy() else Color(0.22, 0.32, 0.3)
	var skin := Color(0.48, 0.64, 0.36) if is_enemy() else Color(0.75, 0.56, 0.44)
	add_part(self, Vector3(0, 1.35, 0), Vector3(0.8, 0.85, 0.45), clothes)
	add_part(self, Vector3(0, 2, 0), Vector3(0.48, 0.48, 0.48), skin)
	for side in [-1, 1]:
		add_part(self, Vector3(side * 0.52, 1.3, 0), Vector3(0.24, 0.75, 0.28), skin)
	left_leg = make_leg(-0.23)
	right_leg = make_leg(0.23)
	if not is_enemy():
		add_part(self, Vector3(0, 1.4, -0.3), Vector3(0.55, 0.55, 0.2), Color(0.29, 0.27, 0.19))
		weapon = add_part(self, Vector3(0.35, 1.25, 0.44), Vector3(0.15, 0.15, 0.95), Color(0.11, 0.12, 0.13))
	if role == "brute":
		scale = Vector3(1.6, 1.6, 1.6)

func is_enemy() -> bool:
	return role == "zombie" or role == "runner" or role == "brute"

func make_leg(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.9, 0)
	add_child(pivot)
	add_part(pivot, Vector3(0, -0.4, 0), Vector3(0.3, 0.8, 0.35), Color(0.18, 0.2, 0.2))
	return pivot

func add_part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func update_animation(delta: float, moving: bool) -> void:
	run_clock += delta
	left_leg.rotation.x = sin(run_clock * 9) * 0.55 if moving else 0.0
	right_leg.rotation.x = -left_leg.rotation.x
	attack_timer = maxf(0, attack_timer - delta)
	fire_timer = maxf(0, fire_timer - delta)
	if weapon:
		weapon.position.z = lerpf(weapon.position.z, 0.44, minf(1, delta * 10))

func step_motion(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -2.0 if is_on_floor() else velocity.y - 12.0 * delta
	move_and_slide()
	position.x = clampf(position.x, -5.0, 5.0)

func apply_damage(amount: float) -> void:
	if dead:
		return
	health -= amount
	if health <= 0:
		dead = true
		defeated.emit(self)
		queue_free()
