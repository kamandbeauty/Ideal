class_name TunnelBrute
extends Zombie
## The metro boss telegraphs a short rush. It follows the ordinary zombie
## routes, hitboxes, slot and breach rules; a blast interrupts its charge.

enum Rush { RECOVER, WARNING, CHARGE }
const RECOVERY: float = 10.0
const FIRST_WARNING: float = 6.0
const WARNING_TIME: float = 1.6
const CHARGE_TIME: float = 3.0
const CHARGE_SPEED: float = 1.65

var rush: Rush = Rush.RECOVER
var rush_left: float = FIRST_WARNING
var warning_ring: MeshInstance3D
static var armor_material: StandardMaterial3D
static var stripe_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "RushWarning"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.62
	ring.rings = 12
	ring.ring_segments = 16
	warning_ring.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.37, 0.025)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.18, 0.01)
	mat.emission_energy_multiplier = 1.5
	warning_ring.material_override = mat
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_ring.position = Vector3(0.0, data.height() + 0.55, 0.0)
	warning_ring.visible = false
	add_child(warning_ring)


func _city_model_scale() -> float:
	return 1.82


## Small non-colliding plates ride the chest bone on either compatible rig.
## They are created once per pooled look and never replace its hit volumes.
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
	if armor_material == null:
		armor_material = StandardMaterial3D.new()
		armor_material.albedo_color = Color(0.17, 0.19, 0.18)
		armor_material.metallic = 0.55
		armor_material.roughness = 0.72
		stripe_material = StandardMaterial3D.new()
		stripe_material.albedo_color = Color(0.85, 0.39, 0.06)
		stripe_material.roughness = 0.8
	var socket: BoneAttachment3D = skeleton.get_node_or_null("TunnelArmor") as BoneAttachment3D
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = "TunnelArmor"
		skeleton.add_child(socket)
		socket.bone_name = skeleton.get_bone_name(bone)
		var plate := MeshInstance3D.new()
		plate.name = "Plate"
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(0.55, 0.32, 0.08)
		plate.mesh = plate_mesh
		plate.position = Vector3(0.0, 0.09, 0.17)
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		socket.add_child(plate)
		var stripe := MeshInstance3D.new()
		stripe.name = "Stripe"
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.48, 0.045, 0.012)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(0.0, 0.1, 0.216)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		socket.add_child(stripe)
	(socket.get_node("Plate") as MeshInstance3D).material_override = armor_material
	(socket.get_node("Stripe") as MeshInstance3D).material_override = stripe_material


func activate(walk_path: PackedVector3Array, claimed: AttackLines.Slot, wanted: String, lane_side: String, lane: float,
		health_scale: float, speed_scale: float, rng: RandomNumberGenerator) -> void:
	super.activate(walk_path, claimed, wanted, lane_side, lane, health_scale, speed_scale, rng)
	rush = Rush.RECOVER
	rush_left = FIRST_WARNING
	if warning_ring:
		warning_ring.visible = false


func _sleep() -> void:
	if warning_ring:
		warning_ring.visible = false
	super._sleep()


func tick(delta: float) -> void:
	if alive and state == State.ADVANCE and reel_left <= 0.0:
		rush_left -= delta
		if rush_left <= 0.0:
			match rush:
				Rush.RECOVER:
					rush = Rush.WARNING
					rush_left = WARNING_TIME
					Events.tunnel_brute_warning.emit(self)
				Rush.WARNING:
					rush = Rush.CHARGE
					rush_left = CHARGE_TIME
				Rush.CHARGE:
					rush = Rush.RECOVER
					rush_left = RECOVERY
	else:
		# Do not resume an old charge after reaching the wall or a breach.
		if state != State.ADVANCE:
			rush = Rush.RECOVER
			rush_left = RECOVERY
	if warning_ring:
		warning_ring.visible = alive and state == State.ADVANCE and rush == Rush.WARNING and reel_left <= 0.0
		if warning_ring.visible:
			warning_ring.rotation.y += delta * 2.5
	var normal_speed: float = speed
	if alive and state == State.ADVANCE:
		if rush == Rush.WARNING:
			speed *= 0.35
		elif rush == Rush.CHARGE:
			speed *= CHARGE_SPEED
		if anim and current_clip == walk_clip and stagger_left <= 0.0 and reel_left <= 0.0:
			anim.speed_scale = speed / gait_stride_speed * gait_rate
	super.tick(delta)
	speed = normal_speed


func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	var killed: bool = super.take_blast(amount, origin, share, blast)
	if alive and reel_left > 0.0:
		rush = Rush.RECOVER
		rush_left = RECOVERY
		if warning_ring:
			warning_ring.visible = false
	return killed


func _die(headshot: bool, direction: Vector3) -> void:
	if warning_ring:
		warning_ring.visible = false
	super._die(headshot, direction)
