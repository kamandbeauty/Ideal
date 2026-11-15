extends RefCounted
## Every machine-gun kit keeps its sights physically seated on the correct
## moving component and shares the lightweight weathered finish.


func run(t: TestContext) -> void:
	Profile.persist = false
	for id: String in Profile.GUNS:
		var gun: Weapon = (load(Defender.GUN_SCENES[id]) as PackedScene).instantiate()
		t.tree.root.add_child(gun)
		await t.frames(1)
		var textured: int = 0
		var model: Node = gun.get_node("Model")
		for part: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := part as MeshInstance3D
			if mesh.mesh == null:
				continue
			for surface: int in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(surface) as StandardMaterial3D
				if mat != null and mat.albedo_texture == Weapon.GUN_FINISH:
					textured += 1
					t.check(mat.uv1_triplanar, "%s applies finish even without UVs" % id)
		t.check(textured > 0, "%s uses the shared brushed finish" % id)
		if gun is TwinHmg:
			var twin := gun as TwinHmg
			for slide: Node3D in twin.recoilers:
				var seat := slide.get_node_or_null("FrontSightSeat") as MeshInstance3D
				t.check(seat != null and seat.mesh is BoxMesh, "%s sight has a seat on each recoil slide" % id)
				if seat:
					var half: Vector3 = (seat.mesh as BoxMesh).size * 0.5
					t.check(seat.position.y - half.y <= 0.032 and seat.position.y + half.y >= 0.037,
						"the seat bridges barrel radius to the original sight foot")
					t.check(seat.position.z - half.z <= 1.47 and seat.position.z + half.z >= 1.53,
						"the seat covers the sight foot longitudinally")
					var before: Vector3 = seat.global_position
					slide.position.z += 0.04
					t.near(before.distance_to(seat.global_position), 0.04, 0.001, "the sight seat moves with recoil")
					var details := slide.get_node_or_null("ReceiverDetails") as MeshInstance3D
					t.check(details != null and details.mesh.get_surface_count() == 1, "receiver details are batched")
		elif gun is RotaryGun:
			var rotary := gun as RotaryGun
			var seat := rotary.pivot.get_node_or_null("SightRailSeat") as MeshInstance3D
			t.check(seat != null and seat.mesh is BoxMesh, "%s rail is on the housing" % id)
			if seat:
				var half: Vector3 = (seat.mesh as BoxMesh).size * 0.5
				t.check(seat.position.y - half.y <= 0.10 and seat.position.y + half.y >= 0.108, "rotary rail connects to the real housing and sight rail")
			t.check(rotary.rotor.get_node_or_null("OpenCollar") != null, "the barrel clamp follows the rotor")
		elif gun is ChainGun:
			var chain := gun as ChainGun
			var seat := chain.pivot.get_node_or_null("SightRailSeat") as MeshInstance3D
			t.check(seat != null and seat.mesh is BoxMesh, "chain gun rail is supported")
			if seat:
				var half: Vector3 = (seat.mesh as BoxMesh).size * 0.5
				t.check(seat.position.y - half.y <= 0.066 and seat.position.y + half.y >= 0.105, "chain rail joins receiver and front post")
				t.check(seat.position.z - half.z <= -0.286 and seat.position.z + half.z >= -0.23, "chain rail bridges the original fore-and-aft gap")
		gun.queue_free()
		await t.frames(1)
