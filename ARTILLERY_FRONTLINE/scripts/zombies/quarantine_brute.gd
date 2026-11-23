class_name QuarantineBrute
extends Zombie
## Hospital boss: every third gate/wall blow winds up into a heavier strike.
## A blast cancels its bonus while preserving ordinary pathing and hitboxes.

const EXTRA_STRIKE_DAMAGE: float = 14.0
var strike_warned: bool = false
var strike_interrupted: bool = false
var warning_ring: MeshInstance3D
static var plate_material: StandardMaterial3D
static var cross_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "HeavyStrikeWarning"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.62
	ring.rings = 12
	ring.ring_segments = 16
	warning_ring.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.22, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.08, 0.01)
	mat.emission_energy_multiplier = 1.5
	warning_ring.material_override = mat
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_ring.position = Vector3(0.0, data.height() + 0.55, 0.0)
	warning_ring.visible = false
	add_child(warning_ring)


func _city_model_scale() -> float:
	return 1.82


## A hospital plate and cross ride the shared rig. They have no collision and
## are created once per pooled look; neither changes the head or body hitbox.
func _paint_look(chosen: int, rng: RandomNumberGenerator) -> void:
	super._paint_look(chosen, rng)
	if chosen == 0 and body_mesh:
		body_mesh.material_override = MaterialLibrary.zombie_skin("boss", 0)
	if skeleton == null:
		return
	var bone: int = skeleton.find_bone("Spine2")
	if bone < 0:
		bone = skeleton.find_bone("Chest")
	if bone < 0:
		return
	if plate_material == null:
		plate_material = StandardMaterial3D.new()
		plate_material.albedo_color = Color(0.67, 0.69, 0.61)
		plate_material.roughness = 0.9
		cross_material = StandardMaterial3D.new()
		cross_material.albedo_color = Color(0.68, 0.07, 0.045)
		cross_material.roughness = 0.85
	var socket: BoneAttachment3D = skeleton.get_node_or_null("QuarantineMark") as BoneAttachment3D
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = "QuarantineMark"
		skeleton.add_child(socket)
		socket.bone_name = skeleton.get_bone_name(bone)
		_add_plate(socket, "Plate", Vector3(0.42, 0.3, 0.08), Vector3(0.0, 0.09, 0.17))
		_add_plate(socket, "CrossVertical", Vector3(0.05, 0.19, 0.012), Vector3(0.0, 0.1, 0.216))
		_add_plate(socket, "CrossHorizontal", Vector3(0.18, 0.05, 0.012), Vector3(0.0, 0.1, 0.218))
	(socket.get_node("Plate") as MeshInstance3D).material_override = plate_material
	(socket.get_node("CrossVertical") as MeshInstance3D).material_override = cross_material
	(socket.get_node("CrossHorizontal") as MeshInstance3D).material_override = cross_material


func _add_plate(parent: Node, node_name: String, dimensions: Vector3, at: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)


func activate(walk_path: PackedVector3Array, claimed: AttackLines.Slot, wanted: String, lane_side: String, lane: float,
		health_scale: float, speed_scale: float, rng: RandomNumberGenerator) -> void:
	super.activate(walk_path, claimed, wanted, lane_side, lane, health_scale, speed_scale, rng)
	_reset_strike()


func _sleep() -> void:
	_reset_strike()
	super._sleep()


func _reset_strike() -> void:
	strike_warned = false
	strike_interrupted = false
	if warning_ring:
		warning_ring.visible = false


func tick(delta: float) -> void:
	if not alive or state != State.ATTACK:
		_reset_strike()
	super.tick(delta)
	if warning_ring and warning_ring.visible:
		warning_ring.rotation.y += delta * 2.5


func _swing(delta: float) -> void:
	# The warning starts at the beginning of the third swing; the regular
	# attack animation still delivers the hit at its configured impact point.
	if blows % 3 == 2 and not attack_landed and not strike_warned:
		strike_warned = true
		if warning_ring:
			warning_ring.visible = true
		Events.quarantine_brute_warning.emit(self)
	var before: int = blows
	var target_slot: AttackLines.Slot = slot
	super._swing(delta)
	if blows > before:
		if blows % 3 == 0 and not strike_interrupted and target_slot != null and slot == target_slot and horde.defense:
			var at: Vector3 = target_slot.position + target_slot.facing * 0.75 + Vector3.UP * data.height() * 0.68
			horde.defense.apply_damage(target_slot.target, EXTRA_STRIKE_DAMAGE, at)
		_reset_strike()


func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	var killed: bool = super.take_blast(amount, origin, share, blast)
	if alive and strike_warned and reel_left > 0.0:
		strike_interrupted = true
		if warning_ring:
			warning_ring.visible = false
	return killed


func _die(headshot: bool, direction: Vector3) -> void:
	_reset_strike()
	super._die(headshot, direction)
