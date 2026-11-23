class_name FoundryBrute
extends Zombie
## Factory boss: a brief, telegraphed brace softens body shots only. Headshots
## and blasts retain their ordinary damage; a blast cancels the brace. No new
## hitbox, route, hazard or immunity is introduced.

enum Guard { RECOVER, WARNING, BRACED }
const FIRST_GUARD: float = 8.0
const RECOVERY: float = 14.0
const WARNING_TIME: float = 1.8
const GUARD_TIME: float = 4.0
const BODY_DAMAGE: float = 0.75

var guard: Guard = Guard.RECOVER
var guard_left: float = FIRST_GUARD
var warning_ring: MeshInstance3D
var ring_material: StandardMaterial3D
static var plate_material: StandardMaterial3D
static var stripe_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "FoundryGuardIndicator"
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


## Riveted industrial chest armor follows either compatible rig. It is only
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
		plate_material.albedo_color = Color(0.27, 0.24, 0.20)
		plate_material.metallic = 0.55
		plate_material.roughness = 0.72
		stripe_material = StandardMaterial3D.new()
		stripe_material.albedo_color = Color(0.95, 0.62, 0.08)
		stripe_material.roughness = 0.85
	var socket: BoneAttachment3D = skeleton.get_node_or_null("FoundryArmor") as BoneAttachment3D
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = "FoundryArmor"
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
	_reset_guard(FIRST_GUARD)


func _sleep() -> void:
	_reset_guard(FIRST_GUARD)
	super._sleep()


func _reset_guard(delay: float) -> void:
	guard = Guard.RECOVER
	guard_left = delay
	if warning_ring:
		warning_ring.visible = false


func tick(delta: float) -> void:
	if alive and state == State.ADVANCE and reel_left <= 0.0:
		guard_left -= delta
		if guard_left <= 0.0:
			match guard:
				Guard.RECOVER:
					guard = Guard.WARNING
					guard_left = WARNING_TIME
					Events.foundry_brute_warning.emit(self)
				Guard.WARNING:
					guard = Guard.BRACED
					guard_left = GUARD_TIME
				Guard.BRACED:
					_reset_guard(RECOVERY)
	else:
		# Guard never remains active while striking or crossing a fallen gate.
		if not alive or state != State.ADVANCE:
			_reset_guard(RECOVERY)
	if warning_ring:
		warning_ring.visible = alive and state == State.ADVANCE and guard != Guard.RECOVER and reel_left <= 0.0
		if warning_ring.visible:
			var color := Color(1.0, 0.45, 0.03) if guard == Guard.WARNING else Color(0.22, 0.72, 1.0)
			ring_material.albedo_color = color
			ring_material.emission = color
			warning_ring.rotation.y += delta * 2.5
	super.tick(delta)
	# A tick can arrive at the wall, enter a breach or die: never let the guard
	# survive a state transition until the next physics tick.
	if not alive or state != State.ADVANCE:
		_reset_guard(RECOVERY)


func take_hit(amount: float, headshot: bool, at: Vector3, direction: Vector3) -> bool:
	var reduced: float = amount * BODY_DAMAGE if alive and state == State.ADVANCE and guard == Guard.BRACED and not headshot else amount
	return super.take_hit(reduced, headshot, at, direction)


func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	var killed: bool = super.take_blast(amount, origin, share, blast)
	if alive and reel_left > 0.0:
		_reset_guard(RECOVERY)
	return killed


func _die(headshot: bool, direction: Vector3) -> void:
	_reset_guard(RECOVERY)
	super._die(headshot, direction)
