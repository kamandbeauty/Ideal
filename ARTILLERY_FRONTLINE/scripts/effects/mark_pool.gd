class_name MarkPool
extends Node3D
## What a fight leaves behind: the scars of rounds on stone and blood where a
## body fell. Each kind is one MultiMesh used as a ring buffer, so however long
## the siege lasts it costs one draw call per kind and nothing is allocated:
## the newest mark replaces the oldest.

## Share of its final width that a spreading mark starts at.
const START_SHARE: float = 0.3
const KINDS: Dictionary = {
	"scar": {"count": 48, "size": Vector2(0.16, 0.3), "color": Color(0.05, 0.045, 0.04, 0.82), "lift": 0.02, "grow": 0.0},
	"blood": {"count": 28, "size": Vector2(0.95, 1.55), "color": Color(0.2, 0.012, 0.01, 0.88), "lift": 0.03, "grow": 1.3},
}

var meshes: Dictionary = {}
var cursors: Dictionary = {}
## Where every mark lies at its full size, and how much of that size it shows now (0 = hidden), by kind.
## Kept on this side because a renderer cannot be asked what it was told.
var places: Dictionary = {}
var shares: Dictionary = {}
## Marks laid down since the level was built, by kind; tests read it instead of looking.
var placed: Dictionary = {}
## Blood spreads for a moment after the body lands: [kind, slot, age].
var spreading: Array = []
var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -1000.0, 0.0))
var rng := RandomNumberGenerator.new()
static var textures: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	for kind: String in KINDS:
		var spec: Dictionary = KINDS[kind]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = texture_for(kind)
		material.albedo_color = spec.color
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.disable_receive_shadows = true
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		# Marks lie on the ground: they are drawn before smoke, fire and everything else that is see-through.
		material.render_priority = -1
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		plane.material = material
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = plane
		multimesh.instance_count = spec.count
		for index: int in spec.count:
			multimesh.set_instance_transform(index, hidden)
		var instance := MultiMeshInstance3D.new()
		instance.name = kind.capitalize() + "Marks"
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The marks are scattered over the whole field; the batch is never culled as one.
		instance.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 200, 800))
		add_child(instance)
		meshes[kind] = multimesh
		cursors[kind] = 0
		placed[kind] = 0
		var laid: Array[Transform3D] = []
		laid.resize(spec.count)
		places[kind] = laid
		var shown := PackedFloat32Array()
		shown.resize(spec.count)
		shares[kind] = shown
	set_process(false)


## A dark soft-edged blot for a bullet scar; an uneven splash for blood.
static func texture_for(kind: String) -> Texture2D:
	if textures.has(kind):
		return textures[kind]
	var size: int = 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var lobes: Array = [[3.0, 0.9, 0.13], [5.0, 2.4, 0.09], [9.0, 4.1, 0.05]] if kind == "blood" else [[5.0, 0.4, 0.05]]
	var reach: float = 0.66 if kind == "blood" else 0.8
	var soft: float = 0.16 if kind == "blood" else 0.55
	for y: int in size:
		for x: int in size:
			var offset := Vector2((float(x) + 0.5) / float(size) * 2.0 - 1.0, (float(y) + 0.5) / float(size) * 2.0 - 1.0)
			var angle: float = offset.angle()
			var edge: float = reach
			for lobe: Array in lobes:
				edge += sin(angle * float(lobe[0]) + float(lobe[1])) * float(lobe[2])
			var alpha: float = 1.0 - smoothstep(edge - soft, edge, offset.length())
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	textures[kind] = texture
	return texture


## Lays a mark of `kind` at `at`, flat against a surface facing `normal`. Returns the slot used.
func mark(kind: String, at: Vector3, normal: Vector3 = Vector3.UP, size: float = 1.0) -> int:
	if not meshes.has(kind):
		return -1
	var spec: Dictionary = KINDS[kind]
	var slot: int = cursors[kind]
	cursors[kind] = (slot + 1) % int(spec.count)
	var up: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	# Any two directions across the surface, then a random turn about its normal.
	var across: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	across = across.rotated(up, rng.randf() * TAU)
	var along: Vector3 = across.cross(up)
	var width: float = rng.randf_range(spec.size.x, spec.size.y) * size
	var frame := Basis(across * width, up, along * width * rng.randf_range(0.8, 1.2))
	var place := Transform3D(frame, at + up * (float(spec.lift) + 0.0006 * float(slot)))
	places[kind][slot] = place
	_drop_spreading(kind, slot)
	if float(spec.grow) > 0.0:
		spreading.append([kind, slot, 0.0])
		_show(kind, slot, START_SHARE)
		set_process(true)
	else:
		_show(kind, slot, 1.0)
	placed[kind] = int(placed[kind]) + 1
	return slot


## Shows a mark at `share` of its full width (0 hides it).
func _show(kind: String, slot: int, share: float) -> void:
	shares[kind][slot] = share
	var place: Transform3D = places[kind][slot]
	(meshes[kind] as MultiMesh).set_instance_transform(slot, hidden if share <= 0.0 else _scaled(place, share))


## The mark in `slot` as it is drawn now.
func shown(kind: String, slot: int) -> Transform3D:
	var share: float = shares[kind][slot]
	return hidden if share <= 0.0 else _scaled(places[kind][slot], share)


func _drop_spreading(kind: String, slot: int) -> void:
	for index: int in range(spreading.size() - 1, -1, -1):
		if spreading[index][0] == kind and spreading[index][1] == slot:
			spreading.remove_at(index)


static func _scaled(place: Transform3D, share: float) -> Transform3D:
	return Transform3D(Basis(place.basis.x * share, place.basis.y, place.basis.z * share), place.origin)


func _process(delta: float) -> void:
	for index: int in range(spreading.size() - 1, -1, -1):
		var entry: Array = spreading[index]
		var kind: String = entry[0]
		entry[2] = float(entry[2]) + delta
		var share: float = clampf(float(entry[2]) / float(KINDS[kind].grow), 0.0, 1.0)
		# Quick at first, then creeping.
		var eased: float = 1.0 - (1.0 - share) * (1.0 - share)
		_show(kind, entry[1], lerpf(START_SHARE, 1.0, eased))
		if share >= 1.0:
			spreading.remove_at(index)
	if spreading.is_empty():
		set_process(false)


func clear() -> void:
	spreading.clear()
	for kind: String in meshes:
		for index: int in int(KINDS[kind].count):
			_show(kind, index, 0.0)
		cursors[kind] = 0
	set_process(false)


func capacity() -> int:
	var total: int = 0
	for kind: String in KINDS:
		total += int(KINDS[kind].count)
	return total
