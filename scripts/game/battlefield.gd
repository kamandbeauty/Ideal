class_name Battlefield
extends RefCounted
## Builds the whole island from LevelData: ground, path, portal, core, pads and
## a little low-poly scenery. No external art files are needed.

const DECOR_SEED := 20261114
const TREE_COUNT := 40
const ROCK_COUNT := 22


static func build(root: Node3D) -> Dictionary:
	_build_environment(root)
	_build_sun(root)
	_build_water(root)
	_build_ground(root)
	_build_path(root)
	_build_decor(root)
	var portal := _build_portal(root)
	var core := _build_core(root)
	var pads := _build_pads(root)
	return {"pads": pads, "core": core, "portal": portal}


# --- Environment -----------------------------------------------------------

static func _build_environment(root: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.05, 0.085)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.54, 0.78)
	environment.ambient_light_energy = 0.7
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.07, 0.11, 0.18)
	environment.fog_density = 0.0075
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	root.add_child(world)


static func _build_sun(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-56.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)


static func _build_water(root: Node3D) -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(140.0, 0.5, 140.0)
	water.mesh = mesh
	var material := _material(Color(0.05, 0.16, 0.26), 0.25, 0.1)
	water.material_override = material
	water.position.y = -1.4
	root.add_child(water)


static func _build_ground(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(LevelData.GROUND_SIZE, 1.0, LevelData.GROUND_SIZE)
	ground.mesh = mesh
	ground.material_override = _material(Color(0.14, 0.27, 0.22), 0.95)
	ground.position.y = -0.5
	root.add_child(ground)

	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(LevelData.GROUND_SIZE + 2.5, 0.8, LevelData.GROUND_SIZE + 2.5)
	rim.mesh = rim_mesh
	rim.material_override = _material(Color(0.19, 0.2, 0.21), 1.0)
	rim.position.y = -0.72
	root.add_child(rim)


static func _build_path(root: Node3D) -> void:
	var path := Node3D.new()
	path.name = "Path"
	root.add_child(path)
	var outer := _material(Color(0.16, 0.16, 0.17), 0.95)
	var inner := _material(Color(0.44, 0.38, 0.3), 0.95)

	for i in LevelData.PATH.size() - 1:
		var a := LevelData.PATH[i]
		var b := LevelData.PATH[i + 1]
		var delta := b - a
		var length := Vector2(delta.x, delta.z).length()
		if length <= 0.01:
			continue
		var angle := atan2(delta.z, delta.x)
		var mid := (a + b) * 0.5
		var rotation := Vector3(0.0, -angle, 0.0)

		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(length + 0.8, 0.1, LevelData.PATH_WIDTH + 1.0)
		_add_mesh(path, edge_mesh, outer, Vector3(mid.x, 0.02, mid.z), rotation)

		var tile_mesh := BoxMesh.new()
		tile_mesh.size = Vector3(length + 0.6, 0.16, LevelData.PATH_WIDTH)
		_add_mesh(path, tile_mesh, inner, Vector3(mid.x, 0.07, mid.z), rotation)


static func _build_decor(root: Node3D) -> void:
	var decor := Node3D.new()
	decor.name = "Decor"
	root.add_child(decor)

	var trunk_material := _material(Color(0.28, 0.2, 0.15), 1.0)
	var leaf_material := _material(Color(0.17, 0.4, 0.3), 0.95)
	var rock_material := _material(Color(0.3, 0.33, 0.36), 1.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = DECOR_SEED
	var half := LevelData.GROUND_SIZE * 0.5 - 2.5

	var trees := 0
	var attempts := 0
	while trees < TREE_COUNT and attempts < 600:
		attempts += 1
		var point := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		if _is_blocked(point):
			continue
		var tree := Node3D.new()
		tree.position = point
		tree.rotation.y = rng.randf_range(0.0, TAU)
		decor.add_child(tree)

		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.14
		trunk_mesh.bottom_radius = 0.19
		trunk_mesh.height = 0.9
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_material
		trunk.position.y = 0.45
		tree.add_child(trunk)

		var height := rng.randf_range(1.9, 3.1)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := CylinderMesh.new()
		canopy_mesh.top_radius = 0.0
		canopy_mesh.bottom_radius = rng.randf_range(0.85, 1.2)
		canopy_mesh.height = height
		canopy_mesh.radial_segments = 7
		canopy.mesh = canopy_mesh
		canopy.material_override = leaf_material
		canopy.position.y = 0.8 + height * 0.5
		tree.add_child(canopy)
		trees += 1

	var rocks := 0
	attempts = 0
	while rocks < ROCK_COUNT and attempts < 400:
		attempts += 1
		var point := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		if _is_blocked(point):
			continue
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(0.4, 0.9)
		rock_mesh.height = rock_mesh.radius * 1.2
		rock_mesh.radial_segments = 6
		rock_mesh.rings = 3
		rock.mesh = rock_mesh
		rock.material_override = rock_material
		rock.position = Vector3(point.x, rock_mesh.radius * 0.25, point.z)
		rock.scale = Vector3(rng.randf_range(0.9, 1.6), rng.randf_range(0.6, 1.0), rng.randf_range(0.9, 1.6))
		decor.add_child(rock)
		rocks += 1


static func _build_portal(root: Node3D) -> Node3D:
	var portal := Node3D.new()
	portal.name = "Portal"
	portal.position = LevelData.SPAWN_POSITION
	root.add_child(portal)

	var glow := _emissive(Color(0.55, 0.32, 0.95), 1.8)
	var frame := MeshInstance3D.new()
	var frame_mesh := TorusMesh.new()
	frame_mesh.inner_radius = 1.15
	frame_mesh.outer_radius = 1.5
	frame_mesh.rings = 32
	frame_mesh.ring_segments = 8
	frame.mesh = frame_mesh
	frame.material_override = glow
	frame.position.y = 1.55
	frame.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	portal.add_child(frame)

	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.18
	disc_mesh.bottom_radius = 1.18
	disc_mesh.height = 0.06
	disc.mesh = disc_mesh
	var disc_material := _emissive(Color(0.22, 0.1, 0.42), 0.9)
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.albedo_color.a = 0.75
	disc.material_override = disc_material
	disc.position.y = 1.55
	disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	portal.add_child(disc)

	var pulse := portal.create_tween()
	pulse.set_loops()
	pulse.tween_property(frame, "scale", Vector3.ONE * 1.08, 1.2).from(Vector3.ONE * 0.96)
	pulse.tween_property(frame, "scale", Vector3.ONE * 0.96, 1.2)
	return portal


static func _build_core(root: Node3D) -> Node3D:
	var core := Node3D.new()
	core.name = "Core"
	core.position = LevelData.CORE_POSITION
	root.add_child(core)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 1.5
	pedestal_mesh.bottom_radius = 1.85
	pedestal_mesh.height = 1.0
	pedestal.mesh = pedestal_mesh
	pedestal.material_override = _material(Color(0.22, 0.26, 0.32), 0.85)
	pedestal.position.y = 0.5
	core.add_child(pedestal)

	var crystal := MeshInstance3D.new()
	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(1.15, 1.7, 1.15)
	crystal.mesh = crystal_mesh
	var crystal_material := _emissive(Color(0.4, 0.9, 1.0), 2.0)
	crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_material.albedo_color.a = 0.92
	crystal.material_override = crystal_material
	crystal.position.y = 1.85
	crystal.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	core.add_child(crystal)

	var halo := MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.3
	halo_mesh.outer_radius = 1.42
	halo_mesh.rings = 36
	halo_mesh.ring_segments = 6
	halo.mesh = halo_mesh
	halo.material_override = _emissive(Color(0.35, 0.8, 1.0), 1.4)
	halo.position.y = 1.2
	core.add_child(halo)

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position.y = 1.9
	core.add_child(light)

	var spin := crystal.create_tween()
	spin.set_loops()
	spin.tween_property(crystal, "rotation:y", TAU, 7.0).from(0.0)

	var bob := crystal.create_tween()
	bob.set_loops()
	bob.tween_property(crystal, "position:y", 2.05, 1.7).from(1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(crystal, "position:y", 1.7, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var halo_spin := halo.create_tween()
	halo_spin.set_loops()
	halo_spin.tween_property(halo, "rotation:y", -TAU, 9.0).from(0.0)
	return core


static func _build_pads(root: Node3D) -> Array[BuildPad]:
	var pads: Array[BuildPad] = []
	for i in LevelData.PADS.size():
		var pad := BuildPad.new()
		pad.name = "Pad%d" % i
		pad.position = LevelData.PADS[i] + Vector3(0.0, 0.02, 0.0)
		root.add_child(pad)
		pad.setup(i)
		pads.append(pad)
	return pads


# --- Helpers ---------------------------------------------------------------

static func _is_blocked(point: Vector3) -> bool:
	for i in LevelData.PATH.size() - 1:
		var closest := Geometry3D.get_closest_point_to_segment(
			point, LevelData.PATH[i], LevelData.PATH[i + 1]
		)
		if Vector2(point.x - closest.x, point.z - closest.z).length() < 3.6:
			return true
	for pad in LevelData.PADS:
		if Vector2(point.x - pad.x, point.z - pad.z).length() < LevelData.PAD_RADIUS + 1.8:
			return true
	var to_core := Vector2(
		point.x - LevelData.CORE_POSITION.x, point.z - LevelData.CORE_POSITION.z
	).length()
	return to_core < 5.0


static func _material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func _emissive(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.4
	return material


static func _add_mesh(
	parent: Node3D,
	mesh: Mesh,
	material: Material,
	position: Vector3 = Vector3.ZERO,
	rotation: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance
