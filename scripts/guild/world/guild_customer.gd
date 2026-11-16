class_name GuildCustomer
extends Node3D
## One customer in the hall: a real walk along the navigation mesh, a place in the
## queue, an order at the counter, and a walk back out.
##
## The route comes from the navigation server (`NavigationServer3D.map_get_path`),
## which is the same mesh the player and the glyph on the floor come from. It is
## read as a polyline and walked at a fixed speed in `walk(delta)`, so a headless
## suite can advance time without a physics frame and still exercise the real
## pathfinding. `NavigationAgent3D` would do the same job but only inside a running
## physics loop, which CI cannot step.

signal arrived(customer: GuildCustomer)

const WALK_SPEED := 1.35
const TURN_RATE := 9.0
const PLATE_HEIGHT := 2.15

var class_id := "warrior"
var character: GuildCharacter
var order: GuildOrder
## walking | queued | ordering | leaving
var state := "walking"
var slot := -1
var route: PackedVector3Array = PackedVector3Array()
## True when the navigation server answered with a real path. A suite with no
## navigation world gets a straight line, and says so instead of pretending.
var routed := false
var travelled := 0.0
var waited := 0.0
var plate: Label3D


func _init(customer_class: String = "warrior") -> void:
	class_id = customer_class if GuildCharacter.STYLES.has(customer_class) else "warrior"
	name = "Customer_" + class_id
	character = GuildCharacter.new(class_id, true)
	character.name = "Rig"
	add_child(character)
	_build_plate()


## A small name plate over the head, so a capture says who is standing there.
func _build_plate() -> void:
	plate = Label3D.new()
	plate.name = "Plate"
	plate.text = GuildLocale.t("customer." + class_id, [], "en")
	plate.font_size = 42
	plate.pixel_size = 0.0045
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.outline_size = 10
	plate.modulate = Color(0.92, 0.94, 1.0, 0.92)
	plate.position = Vector3(0.0, PLATE_HEIGHT, 0.0)
	add_child(plate)


func set_language(language: String) -> void:
	plate.text = GuildLocale.t("customer." + class_id, [], language)


## Asks the navigation server for a route. Falls back to a straight line only when
## the map has no polygons at all (a suite that never built a hall), and says so
## through the returned `routed` flag.
func plan_route(to_point: Vector3, map: RID) -> bool:
	route = PackedVector3Array()
	routed = false
	if map.is_valid():
		var path := NavigationServer3D.map_get_path(map, position, to_point, true)
		routed = path.size() > 0
		for point in path:
			route.append(Vector3(point.x, position.y, point.z))
	if route.is_empty():
		route.append(Vector3(to_point.x, position.y, to_point.z))
	while route.size() > 1 and route[0].distance_to(position) < 0.01:
		route.remove_at(0)
	return route.size() > 0


## Advances along the planned route. Returns true on the step that reaches the end.
func walk(delta: float) -> bool:
	if route.is_empty():
		character.animate(delta, 0.0, "idle")
		return false
	var left := WALK_SPEED * delta
	var moving := false
	while left > 0.0 and not route.is_empty():
		var goal := route[0]
		var flat := Vector3(goal.x - position.x, 0.0, goal.z - position.z)
		var distance := flat.length()
		if distance <= left:
			position = Vector3(goal.x, position.y, goal.z)
			travelled += distance
			left -= distance
			route.remove_at(0)
			continue
		var direction := flat / distance
		position += direction * left
		travelled += left
		_turn(direction, delta)
		left = 0.0
		moving = true
	character.animate(delta, WALK_SPEED if moving else 0.0, "walk" if moving else "idle")
	if route.is_empty():
		arrived.emit(self)
		return true
	return false


## Turns towards the walking direction without snapping, so the ink outline stays
## readable while the customer rounds a corner.
func _turn(direction: Vector3, delta: float) -> void:
	var wanted := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, wanted, clampf(TURN_RATE * delta, 0.0, 1.0))


## The free-standing point in the hall a customer is heading for, used by tests.
func target_point() -> Vector3:
	if route.is_empty():
		return position
	return route[route.size() - 1]


func report() -> String:
	return "customer %s state=%s slot=%d at=(%.1f, %.1f) travelled=%.1f waypoints=%d routed=%s" % [
		class_id,
		state,
		slot,
		position.x,
		position.z,
		travelled,
		route.size(),
		str(routed),
	]
