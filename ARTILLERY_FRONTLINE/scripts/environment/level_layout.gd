class_name LevelLayout
extends Resource
## Gameplay geometry of a level: where the gun stands, the routes the horde
## walks and the places it attacks. Written by tools/build_city.py together
## with the level mesh, and editable in the inspector afterwards.

@export var mount_position: Vector3 = Vector3.ZERO
@export var eye_position: Vector3 = Vector3(0.0, 1.6, 0.0)
## name -> {"points": PackedVector3Array, "widths": PackedFloat32Array}; the first point is the spawn.
@export var routes: Dictionary = {}
## side -> {"position": Vector3, "width": float}: where a route enters the court.
@export var mouths: Dictionary = {}
## name -> {"a", "b", "normal", "rows", "spacing", "target", "side", "priority"}
@export var attack_lines: Dictionary = {}
## target -> {"points", "widths"}: the way through once that target has fallen.
@export var breach_routes: Dictionary = {}
@export var gate_center: Vector3 = Vector3.ZERO
@export var gate_size: Vector3 = Vector3.ONE
@export var patch_center: Vector3 = Vector3.ZERO
@export var patch_size: Vector3 = Vector3.ONE
@export var fires: Array = []
@export var smokes: Array = []
@export var lamps: Array = []


func route_names() -> Array[String]:
	var names: Array[String] = []
	for key: String in routes:
		names.append(key)
	names.sort()
	return names


func has_route(route: String) -> bool:
	return routes.has(route)


## Walking path for one zombie: the route shifted sideways by `lateral`
## (-1..1 of each waypoint's half-width), ending at the court mouth for `side`.
func path_for(route: String, lateral: float, side: String) -> PackedVector3Array:
	var path := PackedVector3Array()
	if not routes.has(route):
		return path
	var points: PackedVector3Array = routes[route].points
	var widths: PackedFloat32Array = routes[route].widths
	for index: int in points.size():
		var before: Vector3 = points[maxi(index - 1, 0)]
		var after: Vector3 = points[mini(index + 1, points.size() - 1)]
		var heading: Vector3 = after - before
		heading.y = 0.0
		var across := Vector3(heading.z, 0.0, -heading.x).normalized() if heading.length_squared() > 0.0001 else Vector3.RIGHT
		path.append(points[index] + across * lateral * widths[index])
	if mouths.has(side):
		var mouth: Dictionary = mouths[side]
		# Across the mouth the offset runs along X; keep each zombie on the side it came down.
		path.append((mouth.position as Vector3) + Vector3(lateral * float(mouth.width), 0.0, 0.0))
	return path


func breach_path(target: String, lateral: float) -> PackedVector3Array:
	var path := PackedVector3Array()
	if not breach_routes.has(target):
		return path
	var points: PackedVector3Array = breach_routes[target].points
	var widths: PackedFloat32Array = breach_routes[target].widths
	for index: int in points.size():
		path.append(points[index] + Vector3(0.0, 0.0, lateral * widths[index]))
	return path


## Length of a route's centre line from spawn to the court mouth.
func route_length(route: String, side: String) -> float:
	var path: PackedVector3Array = path_for(route, 0.0, side)
	var total: float = 0.0
	for index: int in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total
