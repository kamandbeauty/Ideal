class_name TerminalBrute
extends Zombie
## A signaler warns before briefly rallying nearby walkers and runners. It
## cannot create enemies or change routes; a blast interrupts the signal.

enum Rally { RECOVER, WARNING, ACTIVE }
const FIRST_SIGNAL: float = 8.0
const RECOVERY: float = 16.0
const WARNING_TIME: float = 1.8
const SIGNAL_TIME: float = 5.0
const RALLY_RADIUS: float = 12.0
const RALLY_SPEED: float = 1.3

var signal_state: Rally = Rally.RECOVER
var signal_left: float = FIRST_SIGNAL
var warning_ring: MeshInstance3D
var aura_ring: MeshInstance3D
var warning_material: StandardMaterial3D
static var vest_material: StandardMaterial3D
static var stripe_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "TerminalSignalIndicator"
	var indicator := TorusMesh.new()
	indicator.inner_radius = 0.46
	indicator.outer_radius = 0.62
	indicator.rings = 12
	indicator.ring_segments = 16
	warning_ring.mesh = indicator
	warning_material = StandardMaterial3D.new()
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_material.emission_enabled = true
	warning_material.emission_energy_multiplier = 1.5
	warning_ring.material_override = warning_material
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_ring.position = Vector3(0, data.height() + 0.55, 0)
	warning_ring.visible = false
	add_child(warning_ring)
	aura_ring = MeshInstance3D.new()
	aura_ring.name = "TerminalSignalRadius"
	var ground_ring := TorusMesh.new()
	ground_ring.inner_radius = RALLY_RADIUS - 0.16
	ground_ring.outer_radius = RALLY_RADIUS
	ground_ring.rings = 24
	ground_ring.ring_segments = 8
	aura_ring.mesh = ground_ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.17, 0.72, 0.95, 0.48)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.48, 0.8)
	mat.emission_energy_multiplier = 0.5
	aura_ring.material_override = mat
	aura_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura_ring.visible = false
	add_child(aura_ring)


func _city_model_scale() -> float:
	return 1.82


## A high-visibility transit vest and shoulder patches follow either existing
## rig. They are decoration only and do not add or alter hitboxes.
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
	if vest_material == null:
		vest_material = StandardMaterial3D.new()
		vest_material.albedo_color = Color(0.16, 0.30, 0.34)
		vest_material.roughness = 0.85
		stripe_material = StandardMaterial3D.new()
		stripe_material.albedo_color = Color(0.96, 0.64, 0.10)
		stripe_material.roughness = 0.8
	var socket: BoneAttachment3D = skeleton.get_node_or_null("TerminalVest") as BoneAttachment3D
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = "TerminalVest"
		skeleton.add_child(socket)
		socket.bone_name = skeleton.get_bone_name(bone)
		_add_panel(socket, "Vest", Vector3(0.60, 0.40, 0.09), Vector3(0, 0.08, 0.17))
		_add_panel(socket, "Stripe", Vector3(0.52, 0.07, 0.015), Vector3(0, 0.02, 0.22))
		_add_panel(socket, "Badge", Vector3(0.13, 0.13, 0.016), Vector3(-0.15, 0.16, 0.22))
		_add_panel(socket, "LeftPatch", Vector3(0.12, 0.14, 0.12), Vector3(-0.32, 0.17, 0.13))
		_add_panel(socket, "RightPatch", Vector3(0.12, 0.14, 0.12), Vector3(0.32, 0.17, 0.13))
	(socket.get_node("Vest") as MeshInstance3D).material_override = vest_material
	for part: String in ["Stripe", "Badge", "LeftPatch", "RightPatch"]:
		(socket.get_node(part) as MeshInstance3D).material_override = stripe_material


func _add_panel(parent: Node, part_name: String, size: Vector3, at: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)


func activate(walk_path: PackedVector3Array, claimed: AttackLines.Slot, wanted: String, lane_side: String, lane: float,
		health_scale: float, speed_scale: float, rng: RandomNumberGenerator) -> void:
	super.activate(walk_path, claimed, wanted, lane_side, lane, health_scale, speed_scale, rng)
	_reset_signal(FIRST_SIGNAL)
	# Cancel the rig's randomized scale so the drawn ground radius is in meters.
	if aura_ring:
		aura_ring.scale = Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)
		aura_ring.position = Vector3(0, 0.05 / scale.y, 0)


func _sleep() -> void:
	_reset_signal(FIRST_SIGNAL)
	super._sleep()


func _reset_signal(delay: float) -> void:
	signal_state = Rally.RECOVER
	signal_left = delay
	if warning_ring:
		warning_ring.visible = false
	if aura_ring:
		aura_ring.visible = false


func tick(delta: float) -> void:
	if alive and state == State.ADVANCE and reel_left <= 0.0:
		signal_left -= delta
		if signal_left <= 0.0:
			match signal_state:
				Rally.RECOVER:
					signal_state = Rally.WARNING
					signal_left = WARNING_TIME
					Events.terminal_brute_warning.emit(self)
				Rally.WARNING:
					signal_state = Rally.ACTIVE
					signal_left = SIGNAL_TIME
				Rally.ACTIVE:
					_reset_signal(RECOVERY)
	else:
		if not alive or state != State.ADVANCE:
			_reset_signal(RECOVERY)
	if warning_ring:
		warning_ring.visible = alive and state == State.ADVANCE and signal_state != Rally.RECOVER and reel_left <= 0.0
		if warning_ring.visible:
			var color := Color(1.0, 0.43, 0.03) if signal_state == Rally.WARNING else Color(0.16, 0.72, 1.0)
			warning_material.albedo_color = color
			warning_material.emission = color
			warning_ring.rotation.y += delta * 2.5
	if aura_ring:
		aura_ring.visible = alive and state == State.ADVANCE and signal_state == Rally.ACTIVE and reel_left <= 0.0
	super.tick(delta)
	if not alive or state != State.ADVANCE:
		_reset_signal(RECOVERY)


## Called only as other enemies walk; no shared speed or resource is mutated.
func escort_speed_multiplier(other: Zombie) -> float:
	if not alive or state != State.ADVANCE or signal_state != Rally.ACTIVE or reel_left > 0.0:
		return 1.0
	if other == self or not other.alive or other.state != State.ADVANCE:
		return 1.0
	if other.data.id != &"walker" and other.data.id != &"runner":
		return 1.0
	var distance := Vector2(position.x - other.position.x, position.z - other.position.z)
	return RALLY_SPEED if distance.length_squared() <= RALLY_RADIUS * RALLY_RADIUS else 1.0


func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	var killed: bool = super.take_blast(amount, origin, share, blast)
	if alive and reel_left > 0.0:
		_reset_signal(RECOVERY)
	return killed


func _die(headshot: bool, direction: Vector3) -> void:
	_reset_signal(RECOVERY)
	super._die(headshot, direction)
