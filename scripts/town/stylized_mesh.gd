class_name StylizedMesh
extends RefCounted
## Cached low-poly chamfered boxes. A tiny bevel catches a clean rim of sunlight
## without CSG, subdivision, per-object shaders or an expensive post-process.

static var _boxes: Dictionary = {}


static func box(size: Vector3, bevel: float = 0.05) -> ArrayMesh:
	var key := "%s:%.3f" % [str(size), bevel]
	if _boxes.has(key):
		return _boxes[key]
	var half := size * 0.5
	var edge := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.7)
	var inset := half - Vector3.ONE * edge
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = float(sign_value)
			var polygon: Array[Vector3] = []
			for pair in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var vertex := Vector3.ZERO
				vertex[axis] = half[axis] * float(sign_value)
				vertex[a] = inset[a] * pair.x
				vertex[b] = inset[b] * pair.y
				polygon.append(vertex)
			_polygon(tool, polygon, normal)
		# Four long bevel strips parallel to this axis.
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var polygon: Array[Vector3] = []
				for end in [-1.0, 1.0]:
					for face in range(2) if end < 0.0 else range(1, -1, -1):
						var vertex := Vector3.ZERO
						vertex[axis] = inset[axis] * float(end)
						vertex[a] = (half[a] if face == 0 else inset[a]) * float(sa)
						vertex[b] = (inset[b] if face == 0 else half[b]) * float(sb)
						polygon.append(vertex)
				var normal := Vector3.ZERO
				normal[a] = float(sa)
				normal[b] = float(sb)
				_polygon(tool, polygon, normal.normalized())
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var signs := Vector3(float(sx), float(sy), float(sz))
				var polygon: Array[Vector3] = []
				for axis in 3:
					var vertex := inset * signs
					vertex[axis] = half[axis] * signs[axis]
					polygon.append(vertex)
				_polygon(tool, polygon, signs.normalized())
	var mesh := tool.commit()
	_boxes[key] = mesh
	return mesh


static func _polygon(tool: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0:
		points.reverse()  # Godot front faces are clockwise.
	for i in range(1, points.size() - 1):
		for index in [0, i, i + 1]:
			var vertex: Vector3 = points[index]
			tool.set_normal(normal)
			tool.set_uv(Vector2(vertex.x + vertex.z, vertex.y + vertex.z))
			tool.add_vertex(vertex)
