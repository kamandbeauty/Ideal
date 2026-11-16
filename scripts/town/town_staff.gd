class_name TownStaff
extends Node3D
## Roadside Empire attendants & managers:
## - Each open bay has a uniformed attendant (showing floating `Zzz` when manual
##   and idle, or energetic pumping/washing motion when automated!).
## - Each hired Manager patrols the station plot with a golden aura ring under
##   their feet (matching Screenshot 6 of Roadside Empire!).

const PATROL := 0.85
const MANAGER_SPEED := 0.52

var state: TownState
var _crew: Dictionary = {}
var _phase := 0.0


func setup(town_state: TownState) -> void:
	state = town_state
	refresh()


func refresh() -> void:
	if state == null:
		return
	for id in _crew.keys():
		(_crew[id]["root"] as Node3D).queue_free()
	_crew.clear()
	for id in state.business_ids():
		var b = state.business(id)
		if b != null and b.unlocked:
			_build(id, b)


func refresh_business(id: String) -> void:
	if state == null:
		return
	if _crew.has(id):
		(_crew[id]["root"] as Node3D).queue_free()
		_crew.erase(id)
	var b = state.business(id)
	if b != null and b.unlocked:
		_build(id, b)


func _build(id: String, b: BusinessState) -> void:
	var plot := BusinessData.plot(id)
	var bay_off := BusinessData.bay_offset(id)
	var root := Node3D.new()
	root.name = "Crew_" + id
	add_child(root)

	var bays := maxi(1, b.active_bays())
	var workers: Array[Node3D] = []
	var zzz_labels: Array[Label3D] = []
	var uniform_col := BusinessData.accent(id)

	for i in mini(3, bays):
		var ox := bay_off.x + (float(i) - float(bays - 1) * 0.5) * 1.65
		var worker := PersonMesh.build(absi(hash(id)) % 5)
		worker.position = Vector3(plot.x + ox + 0.55, 0.03, plot.y + bay_off.y - 0.35)
		worker.rotation_degrees.y = -35.0
		root.add_child(worker)

		# Uniform overalls & cap in the station's signature color!
		var overalls := MeshInstance3D.new()
		var ov_mesh := BoxMesh.new()
		ov_mesh.size = Vector3(0.32, 0.42, 0.24)
		overalls.mesh = ov_mesh
		overalls.position = Vector3(0, 0.64, 0)
		overalls.material_override = PersonMesh.flat(uniform_col)
		worker.add_child(overalls)

		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.24, 0.08, 0.26)
		cap.mesh = cap_mesh
		cap.position = Vector3(0, 1.13, 0.02)
		cap.material_override = PersonMesh.flat(uniform_col.darkened(0.15))
		worker.add_child(cap)

		# Floating Zzz indicator shown whenever the station is NOT automated!
		var zzz := Label3D.new()
		zzz.text = "Zzz"
		zzz.font_size = 36
		zzz.pixel_size = 0.0075
		zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		zzz.modulate = Color(0.95, 0.97, 1.0)
		zzz.outline_modulate = Color(0.12, 0.16, 0.28)
		zzz.outline_size = 8
		zzz.position = Vector3(0.0, 1.48, 0.0)
		zzz.visible = not b.is_automated()
		worker.add_child(zzz)

		workers.append(worker)
		zzz_labels.append(zzz)

	var manager: Node3D = null
	if b.manager_rank > 0:
		var mgr_id := BusinessData.manager_id(id)
		manager = _build_manager(mgr_id)
		manager.position = Vector3(plot.x + bay_off.x * 0.45, 0.03, plot.y + 1.45)
		root.add_child(manager)

	_crew[id] = {
		"root": root,
		"workers": workers,
		"zzz": zzz_labels,
		"manager": manager,
		"origin_x": plot.x + bay_off.x * 0.45,
		"direction": 1.0,
	}


func _build_manager(mgr_id: String) -> Node3D:
	var col := ManagerData.rarity_color(mgr_id)
	var manager := PersonMesh.build(absi(hash(mgr_id)) % 5)

	var suit := MeshInstance3D.new()
	var suit_mesh := BoxMesh.new()
	suit_mesh.size = Vector3(0.34, 0.42, 0.26)
	suit.mesh = suit_mesh
	suit.position = Vector3(0, 0.68, 0)
	suit.material_override = PersonMesh.flat(col)
	manager.add_child(suit)

	var hat := MeshInstance3D.new()
	var hat_mesh := BoxMesh.new()
	hat_mesh.size = Vector3(0.28, 0.10, 0.28)
	hat.mesh = hat_mesh
	hat.position = Vector3(0, 1.15, 0)
	hat.material_override = PersonMesh.flat(Color(1.0, 0.84, 0.24))
	manager.add_child(hat)

	# Glowing golden manager aura ring on the ground (just like Screenshot 6!).
	var aura := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.52
	cyl.bottom_radius = 0.52
	cyl.height = 0.025
	aura.mesh = cyl
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(1.0, 0.88, 0.24, 0.55)
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(1.0, 0.84, 0.18)
	aura_mat.emission_energy_multiplier = 1.1
	aura.material_override = aura_mat
	aura.position = Vector3(0, 0.02, 0)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	manager.add_child(aura)
	return manager


func _process(delta: float) -> void:
	if state == null:
		return
	_phase += delta * 5.2
	for id in _crew.keys():
		var entry: Dictionary = _crew[id]
		var b = state.business(id)
		if b == null:
			continue
		var auto_ok: bool = b.is_automated()
		var workers: Array = entry["workers"]
		var zzzs: Array = entry["zzz"]
		for i in workers.size():
			var w: Node3D = workers[i]
			var zlbl: Label3D = zzzs[i]
			zlbl.visible = not auto_ok
			if auto_ok:
				PersonMesh.animate(w, _phase + float(i), 0.75)
			else:
				PersonMesh.animate(w, _phase * 0.3, 0.12)
				zlbl.position.y = 1.46 + sin(_phase * 0.8 + float(i)) * 0.07

		var mgr: Node3D = entry["manager"]
		if mgr != null:
			var dir := float(entry["direction"])
			mgr.position.x += dir * MANAGER_SPEED * delta
			var ox := float(entry["origin_x"])
			if mgr.position.x > ox + PATROL:
				mgr.position.x = ox + PATROL
				entry["direction"] = -1.0
				mgr.rotation_degrees.y = -90.0
			elif mgr.position.x < ox - PATROL:
				mgr.position.x = ox - PATROL
				entry["direction"] = 1.0
				mgr.rotation_degrees.y = 90.0
			PersonMesh.animate(mgr, _phase * 1.15, 0.9)
