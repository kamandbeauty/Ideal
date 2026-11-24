class_name BazaarBrute
extends Zombie
## Bazaar boss: after a clear warning at the defenses, it speeds up its own
## attack cycle briefly. Blasts interrupt it; no enemy or route is modified.

enum Fury { RECOVER, WARNING, ACTIVE }
const FIRST_WARNING: float = 3.0
const RECOVERY: float = 12.0
const WARNING_TIME: float = 1.8
const FURY_TIME: float = 4.0
const ATTACK_RATE: float = 1.5

var fury: Fury = Fury.RECOVER
var fury_left: float = FIRST_WARNING
var warning_ring: MeshInstance3D
var ring_material: StandardMaterial3D
static var plate_material: StandardMaterial3D
static var stripe_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "BazaarFuryIndicator"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.62
	ring.rings = 12
	ring.ring_segments = 16
	warning_ring.mesh = ring
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.emission_enabled = true
	ring_material.emission_energy_multiplier = 1.5
	warning_ring.material_override = ring_material
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_ring.position = Vector3(0, data.height() + 0.55, 0)
	warning_ring.visible = false
	add_child(warning_ring)


func _city_model_scale() -> float:
	return 1.82


## Market-colored cloth and sash follow either compatible rig. They are only
## visual, so shots still reach the ordinary body and head collision volumes.
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
		plate_material.albedo_color = Color(0.06, 0.34, 0.32)
		plate_material.metallic = 0.0
		plate_material.roughness = 0.72
		stripe_material = StandardMaterial3D.new()
		stripe_material.albedo_color = Color(0.73, 0.22, 0.10)
		stripe_material.roughness = 0.85
	var socket: BoneAttachment3D = skeleton.get_node_or_null("BazaarSash") as BoneAttachment3D
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = "BazaarSash"
		skeleton.add_child(socket)
		socket.bone_name = skeleton.get_bone_name(bone)
		_add_plate(socket, "Plate", Vector3(0.58, 0.36, 0.09), Vector3(0, 0.09, 0.17))
		_add_plate(socket, "StripeA", Vector3(0.48, 0.055, 0.012), Vector3(0, 0.03, 0.22))
		_add_plate(socket, "StripeB", Vector3(0.48, 0.055, 0.012), Vector3(0, 0.17, 0.22))
	(socket.get_node("Plate") as MeshInstance3D).material_override = plate_material
	(socket.get_node("StripeA") as MeshInstance3D).material_override = stripe_material
	(socket.get_node("StripeB") as MeshInstance3D).material_override = stripe_material


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
	_reset_fury(FIRST_WARNING)


func _sleep() -> void:
	_reset_fury(FIRST_WARNING)
	super._sleep()


func _reset_fury(delay: float) -> void:
	fury = Fury.RECOVER
	fury_left = delay
	if warning_ring:
		warning_ring.visible = false


func tick(delta: float) -> void:
	if alive and state == State.ATTACK and reel_left <= 0.0:
		fury_left -= delta
		if fury_left <= 0.0:
			match fury:
				Fury.RECOVER:
					fury = Fury.WARNING
					fury_left = WARNING_TIME
					Events.bazaar_brute_warning.emit(self)
				Fury.WARNING:
					fury = Fury.ACTIVE
					fury_left = FURY_TIME
				Fury.ACTIVE:
					_reset_fury(RECOVERY)
	else:
		if not alive or state != State.ATTACK:
			_reset_fury(FIRST_WARNING)
	if warning_ring:
		warning_ring.visible = alive and state == State.ATTACK and fury != Fury.RECOVER and reel_left <= 0.0
		if warning_ring.visible:
			var color := Color(1.0, 0.4, 0.02) if fury == Fury.WARNING else Color(0.95, 0.08, 0.05)
			ring_material.albedo_color = color
			ring_material.emission = color
			warning_ring.rotation.y += delta * 2.5
	if alive and state == State.ATTACK and reel_left <= 0.0 and anim and current_clip == "attack" and anim.has_animation("attack"):
		anim.speed_scale = anim.get_animation("attack").length / data.attack_interval * (ATTACK_RATE if fury == Fury.ACTIVE else 1.0)
	super.tick(delta)
	if not alive or state != State.ATTACK:
		_reset_fury(FIRST_WARNING)


func _swing(delta: float) -> void:
	super._swing(delta * ATTACK_RATE if fury == Fury.ACTIVE else delta)


func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	var killed: bool = super.take_blast(amount, origin, share, blast)
	if alive and reel_left > 0.0:
		_reset_fury(RECOVERY)
	return killed


func _die(headshot: bool, direction: Vector3) -> void:
	_reset_fury(FIRST_WARNING)
	super._die(headshot, direction)
