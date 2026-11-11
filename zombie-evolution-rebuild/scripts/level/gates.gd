extends Node3D

signal crossed(effect)
signal chosen(side)

const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
var selection := 0
var finished := false
var bodies: Array[StaticBody3D] = []

func _ready() -> void:
	make_gate(-1, "×۲")
	make_gate(1, "+۳")

func make_gate(side: int, caption: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = Vector3(side * 3.0, 0, 0)
	body.set_meta("gate_side", side)
	body.set_meta("gate_pair", self)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = Vector3(5.2, 4.0, 0.25)
	shape.shape = collision
	shape.position.y = 2
	body.add_child(shape)
	for x in [-2.5, 2.5]:
		gate_part(body, Vector3(x, 2, 0), Vector3(0.2, 4, 0.25))
	gate_part(body, Vector3(0, 4, 0), Vector3(5.2, 0.2, 0.25))
	var text := Label3D.new()
	text.font = FONT
	text.text = caption
	text.font_size = 80
	text.position = Vector3(0, 3, -0.2)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.add_child(text)
	add_child(body)
	bodies.append(body)

func gate_part(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.67, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.14, 0.2)
	part.material_override = mat
	part.position = pos
	parent.add_child(part)

func select(side: int) -> void:
	if finished or selection != 0:
		return
	selection = side
	chosen.emit(side)
	# Hide the other lane immediately to make the locked choice clear.
	for body in bodies:
		if int(body.get_meta("gate_side")) != side:
			body.visible = false
			body.collision_layer = 0

func check_crossing(hero_z: float) -> void:
	if finished or hero_z < position.z:
		return
	finished = true
	if selection != 0:
		crossed.emit("double" if selection < 0 else "add3")
	queue_free()
