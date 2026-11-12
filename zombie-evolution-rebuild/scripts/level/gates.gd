extends Node3D

signal crossed(effect)
signal chosen(side)

const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
var selection := 0
var finished := false
var panels: Array[Node3D] = []

func _ready() -> void:
	make_gate(-1, "×۲", Color(0.10, 0.58, 1.0))
	make_gate(1, "+۳", Color(1.0, 0.18, 0.22))

func make_gate(side: int, caption: String, color: Color) -> void:
	# Floating glass is deliberately visual-only: neither actors nor bullets
	# collide with it, and selection happens only when the player crosses.
	var panel := Node3D.new()
	panel.position = Vector3(side * 2.9, 0, 0)
	add_child(panel)
	panels.append(panel)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(color.r, color.g, color.b, 0.32)
	glass.metallic = 0.05
	glass.roughness = 0.18
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.emission_enabled = true
	glass.emission = color * 0.14
	gate_part(panel, Vector3(0, 2.28, 0), Vector3(5.65, 3.45, 0.38), glass)
	var edge := StandardMaterial3D.new()
	edge.albedo_color = color.lightened(0.38)
	edge.metallic = 0.25
	edge.roughness = 0.25
	edge.emission_enabled = true
	edge.emission = color * 0.22
	for x in [-2.82, 2.82]:
		gate_part(panel, Vector3(x, 2.28, 0), Vector3(0.10, 3.55, 0.42), edge)
	for y in [0.53, 4.03]:
		gate_part(panel, Vector3(0, y, 0), Vector3(5.70, 0.10, 0.42), edge)
	var text := Label3D.new()
	text.font = FONT
	text.text = caption
	text.font_size = 96
	text.pixel_size = 0.012
	text.outline_size = 10
	text.outline_modulate = Color(0.02, 0.03, 0.06, 0.98)
	text.position = Vector3(0, 2.8, -0.24)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel.add_child(text)

func gate_part(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	parent.add_child(part)

func check_crossing(hero_position: Vector3) -> void:
	if finished:
		return
	var local := to_local(hero_position)
	if local.z < 0.0:
		return
	# The midpoint belongs to the red +۳ lane, deterministically.
	selection = -1 if local.x < 0.0 else 1
	finished = true
	chosen.emit(selection)
	crossed.emit("double" if selection < 0 else "add3")
	queue_free()
