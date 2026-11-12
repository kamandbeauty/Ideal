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
var visual_root: Node3D
var muzzle_flash: MeshInstance3D
var muzzle_time := 0.0

# Experimental user-provided static meshes; collision and combat stay procedural.
const MODEL_CONFIG := {
	"hero": ["res://assets/models/hero-2630.glb", 0.026, -0.011, 0.0],
	"zombie": ["res://assets/models/zombie-13899.glb", 0.0142, 0.020, PI],
	"runner": ["res://assets/models/zombie-28069.glb", 0.0644, -0.406, PI],
	"brute": ["res://assets/models/zombie-27189.glb", 0.0263, 0.001, PI],
}

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
	if not create_model(kind):
		create_placeholder()
	if not is_enemy():
		create_weapon()
	if role == "brute":
		scale = Vector3(1.6, 1.6, 1.6)

func create_model(kind: String) -> bool:
	if not MODEL_CONFIG.has(kind):
		return false
	var config: Array = MODEL_CONFIG[kind]
	var resource = load(config[0])
	if not resource is PackedScene:
		push_warning("Character model unavailable; using prototype visual for " + kind)
		return false
	visual_root = Node3D.new()
	add_child(visual_root)
	var model = resource.instantiate()
	visual_root.add_child(model)
	model.scale = Vector3.ONE * float(config[1])
	model.position.y = float(config[2])
	model.rotation.y = float(config[3])
	return true

func create_placeholder() -> void:
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

func create_weapon() -> void:
	# A lightweight rifle assembled from shared-purpose primitive components.
	weapon = Node3D.new()
	weapon.position = Vector3(0.35, 1.25, 0.44)
	add_child(weapon)
	var dark := Color(0.09, 0.11, 0.12)
	var metal := Color(0.19, 0.22, 0.23)
	var grip := Color(0.26, 0.23, 0.16)
	add_part(weapon, Vector3(0, 0, 0.05), Vector3(0.18, 0.20, 0.48), dark)
	add_part(weapon, Vector3(0, 0, 0.50), Vector3(0.07, 0.07, 0.58), metal)
	add_part(weapon, Vector3(0, 0.08, -0.30), Vector3(0.13, 0.12, 0.28), dark)
	add_part(weapon, Vector3(0, -0.15, 0.0), Vector3(0.12, 0.25, 0.13), grip)
	add_part(weapon, Vector3(0, -0.17, 0.15), Vector3(0.12, 0.25, 0.12), metal)
	add_part(weapon, Vector3(0, 0.14, 0.08), Vector3(0.08, 0.06, 0.16), metal)
	muzzle_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.15
	flash_mesh.height = 0.3
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	muzzle_flash.mesh = flash_mesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.72, 0.25)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.40, 0.04)
	muzzle_flash.material_override = glow
	muzzle_flash.position.z = 0.84
	muzzle_flash.visible = false
	weapon.add_child(muzzle_flash)

func show_shot() -> void:
	if weapon:
		weapon.position.z = 0.24
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_time = 0.07

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
	if visual_root:
		# Whole-mesh motion is only a placeholder; these imports have no rig.
		visual_root.rotation.z = sin(run_clock * 7) * 0.025 if moving else 0.0
		visual_root.position.y = absf(sin(run_clock * 7)) * 0.035 if moving else 0.0
	if left_leg and right_leg:
		left_leg.rotation.x = sin(run_clock * 9) * 0.55 if moving else 0.0
		right_leg.rotation.x = -left_leg.rotation.x
	if muzzle_time > 0:
		muzzle_time = maxf(0.0, muzzle_time - delta)
		if muzzle_time == 0.0 and muzzle_flash:
			muzzle_flash.visible = false
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
