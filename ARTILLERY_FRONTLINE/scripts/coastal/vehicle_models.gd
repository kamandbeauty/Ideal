class_name VehicleModels
extends RefCounted
## Procedural models for the approved vehicle designs: military jeep, 8-wheeled APC
## and heavy boss tank. Built from MeshFactory primitives, so no external GLB is needed.
## Convention: the front of each vehicle faces -Z (Godot forward), origin on the ground.

const OLIVE: Color = Color(0.36, 0.42, 0.24)
const SAND: Color = Color(0.72, 0.62, 0.42)
const DARK: Color = Color(0.16, 0.16, 0.14)
const STEEL: Color = Color(0.3, 0.31, 0.3)
const RUST: Color = Color(0.42, 0.24, 0.14)
const GLASS: Color = Color(0.5, 0.6, 0.66)
const TIRE: Color = Color(0.1, 0.1, 0.1)
const LAMP: Color = Color(0.95, 0.93, 0.8)

## Returns the procedural model for a vehicle kind, or null for kinds that still use GLB files.
static func build_kind(vehicle_kind: String) -> Node3D:
	match vehicle_kind:
		"jeep":
			return build_jeep()
		"apc":
			return build_apc()
		"boss":
			return build_boss_tank()
	return null

## Builds the light jeep: open cabin, roll cage, roof-mounted machine gun, jerrycan.
static func build_jeep() -> Node3D:
	var root := Node3D.new()
	root.name = "MilitaryJeep"
	MeshFactory.box(root, "Chassis", Vector3(0, 0.45, 0), Vector3(1.9, 0.35, 3.4), DARK)
	MeshFactory.box(root, "Hull", Vector3(0, 0.85, 0.2), Vector3(1.8, 0.5, 2.4), OLIVE)
	MeshFactory.box(root, "Hood", Vector3(0, 1.08, -1.3), Vector3(1.7, 0.2, 1.2), OLIVE)
	MeshFactory.box(root, "Grille", Vector3(0, 0.98, -1.92), Vector3(1.2, 0.5, 0.08), DARK)
	MeshFactory.sphere(root, "Headlamp", Vector3(-0.5, 1.02, -1.98), Vector3.ONE * 0.12, LAMP)
	MeshFactory.sphere(root, "Headlamp", Vector3(0.5, 1.02, -1.98), Vector3.ONE * 0.12, LAMP)
	MeshFactory.box(root, "Windshield", Vector3(0, 1.5, -0.6), Vector3(1.7, 0.7, 0.04), GLASS)
	for x in [-0.85, 0.85]:
		MeshFactory.box(root, "CagePost", Vector3(x, 1.65, -0.5), Vector3(0.07, 1.0, 0.07), STEEL)
		MeshFactory.box(root, "CagePost", Vector3(x, 1.65, 1.0), Vector3(0.07, 1.0, 0.07), STEEL)
	MeshFactory.box(root, "CageTop", Vector3(0, 2.15, 0.25), Vector3(1.8, 0.07, 1.6), STEEL)
	MeshFactory.box(root, "Bumper", Vector3(0, 0.4, -2.0), Vector3(1.9, 0.25, 0.15), DARK)
	for x in [-0.4, 0.4]:
		MeshFactory.box(root, "Seat", Vector3(x, 1.0, 0.5), Vector3(0.6, 0.5, 0.6), DARK)
	var ring := MeshFactory.cylinder(root, "MountRing", Vector3(0, 2.25, 1.1), 0.45, 0.05, STEEL, 16)
	MeshFactory.box(root, "GunCradle", Vector3(0, 2.42, 1.1), Vector3(0.22, 0.22, 0.4), STEEL)
	_barrel(root, "Barrel", Vector3(0, 2.46, 0.55), 0.035, 0.9, STEEL)
	_marker(root, "Muzzle", Vector3(0, 2.46, 0.1))
	MeshFactory.box(root, "Jerrycan", Vector3(0.95, 1.1, 1.5), Vector3(0.35, 0.6, 0.25), SAND)
	for z in [-1.2, 1.2]:
		for x in [-0.95, 0.95]:
			_wheel(root, "Wheel", Vector3(x, 0.5, z), 0.5, 0.35)
	return root

## Builds the eight-wheeled armoured personnel carrier with a roof machine gun turret.
static func build_apc() -> Node3D:
	var root := Node3D.new()
	root.name = "APC"
	MeshFactory.box(root, "Hull", Vector3(0, 1.3, 0), Vector3(2.8, 1.2, 6.0), OLIVE)
	MeshFactory.box(root, "Glacis", Vector3(0, 1.25, -3.2), Vector3(2.8, 0.9, 0.6), OLIVE)
	MeshFactory.box(root, "SandPanelLeft", Vector3(-1.42, 1.3, 0.0), Vector3(0.05, 1.0, 4.5), SAND)
	MeshFactory.box(root, "SandPanelRight", Vector3(1.42, 1.3, 0.0), Vector3(0.05, 1.0, 4.5), SAND)
	MeshFactory.box(root, "SandDeck", Vector3(0, 1.95, 0.4), Vector3(2.6, 0.2, 4.8), SAND)
	MeshFactory.box(root, "Roof", Vector3(0, 2.05, 0.4), Vector3(2.5, 0.1, 4.6), DARK)
	for x in [-0.7, 0.7]:
		MeshFactory.box(root, "Hatch", Vector3(x, 2.17, 1.8), Vector3(0.5, 0.06, 0.5), DARK)
	# Turret and gun sit on pivots so the enemy can turn and elevate them at the target.
	var turret_pivot: Node3D = _pivot(root, "TurretPivot", Vector3(0, 2.35, -0.8))
	MeshFactory.cylinder(turret_pivot, "Turret", Vector3.ZERO, 0.55, 0.5, STEEL, 16)
	var gun: Node3D = _pivot(turret_pivot, "GunPivot", Vector3(0, 0.15, -0.3))
	_barrel(gun, "Barrel", Vector3(0, 0, -0.6), 0.05, 1.0, STEEL)
	_marker(gun, "Muzzle", Vector3(0, 0, -1.1))
	for x in [-0.9, 0.9]:
		MeshFactory.box(root, "Headlamp", Vector3(x, 1.1, -3.05), Vector3(0.3, 0.2, 0.05), LAMP)
	for x in [-1.5, 1.5]:
		MeshFactory.box(root, "Mirror", Vector3(x, 1.6, -2.4), Vector3(0.12, 0.3, 0.1), DARK)
	MeshFactory.cylinder(root, "Antenna", Vector3(1.2, 2.9, 2.4), 0.02, 1.8, DARK, 6)
	for z in [-2.2, -0.7, 0.8, 2.3]:
		for x in [-1.55, 1.55]:
			_wheel(root, "Wheel", Vector3(x, 0.6, z), 0.6, 0.45)
	return root

## Builds the heavy boss tank: wide tracks, twin cannon barrels, rusted armour.
static func build_boss_tank() -> Node3D:
	var root := Node3D.new()
	root.name = "BossTank"
	MeshFactory.box(root, "Hull", Vector3(0, 1.0, 0.2), Vector3(3.2, 1.0, 6.4), OLIVE)
	var glacis := MeshFactory.box(root, "Glacis", Vector3(0, 1.2, -3.0), Vector3(3.2, 0.6, 1.0), OLIVE)
	glacis.rotation.x = 0.25
	for x in [-1.85, 1.85]:
		MeshFactory.box(root, "Track", Vector3(x, 0.8, 0.2), Vector3(0.6, 1.2, 7.6), DARK)
		MeshFactory.box(root, "Fender", Vector3(x * 0.92, 1.6, 0.2), Vector3(0.2, 0.1, 7.4), STEEL)
		for z in [-3.0, -1.8, -0.6, 0.6, 1.8, 3.0]:
			_wheel(root, "TrackWheel", Vector3(x, 0.35, z), 0.3, 0.5)
	# Turret pivot at the turret centre; the gun pivot is the trunnion the twin barrels elevate around.
	var turret_pivot: Node3D = _pivot(root, "TurretPivot", Vector3(0, 2.1, -0.2))
	MeshFactory.box(turret_pivot, "Turret", Vector3.ZERO, Vector3(2.2, 0.9, 2.4), DARK)
	MeshFactory.cylinder(turret_pivot, "TurretRing", Vector3(0, 0.5, 0), 0.8, 0.2, STEEL, 18)
	MeshFactory.cylinder(turret_pivot, "Cupola", Vector3(0.5, 0.7, 0.4), 0.25, 0.25, STEEL, 12)
	MeshFactory.box(turret_pivot, "Mantlet", Vector3(0, -0.1, -1.3), Vector3(1.2, 0.6, 0.4), STEEL)
	var gun: Node3D = _pivot(turret_pivot, "GunPivot", Vector3(0, 0.2, -1.3))
	for x in [-0.32, 0.32]:
		_barrel(gun, "Barrel", Vector3(x, 0, -2.1), 0.14, 4.4, STEEL)
		_barrel(gun, "MuzzleBrake", Vector3(x, 0, -4.4), 0.2, 0.4, DARK)
	_marker(gun, "Muzzle", Vector3(0, 0, -4.6))
	MeshFactory.box(root, "RustPlate", Vector3(1.0, 1.4, 1.5), Vector3(0.6, 0.15, 1.2), RUST)
	MeshFactory.box(root, "RustPlate", Vector3(-1.0, 1.4, -0.6), Vector3(0.5, 0.15, 0.9), RUST)
	_barrel(root, "Exhaust", Vector3(1.4, 1.9, 2.8), 0.12, 0.8, DARK)
	return root

## Horizontal wheel with a hub; the tyre axis runs along X.
## Names get a unique suffix: Godot silently renames duplicate siblings otherwise.
static func _wheel(parent: Node3D, name: String, pos: Vector3, radius: float, width: float) -> void:
	var tag: String = "_%d" % parent.get_child_count()
	var tyre := MeshFactory.cylinder(parent, name + tag, pos, radius, width, TIRE, 14)
	tyre.rotation.z = PI * 0.5
	var hub := MeshFactory.cylinder(parent, name + "Hub" + tag, pos, radius * 0.5, width + 0.02, OLIVE, 10)
	hub.rotation.z = PI * 0.5

## Cylinder whose axis runs along Z (the barrel direction); centred on `center`.
static func _barrel(parent: Node3D, name: String, center: Vector3, radius: float, length: float, color: Color) -> void:
	var barrel := MeshFactory.cylinder(parent, name + "_%d" % parent.get_child_count(), center, radius, length, color, 10)
	barrel.rotation.x = PI * 0.5

## Plain transform node that a turret or gun turns around.
static func _pivot(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name
	pivot.position = pos
	parent.add_child(pivot)
	return pivot

## Invisible pivot used as the shot origin and muzzle-flash anchor.
static func _marker(parent: Node3D, name: String, pos: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = name
	marker.position = pos
	parent.add_child(marker)
