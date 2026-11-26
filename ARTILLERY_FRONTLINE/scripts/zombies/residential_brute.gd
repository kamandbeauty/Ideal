class_name ResidentialBrute
extends Zombie
## A block breaker telegraphs a shockwave at the defenses. The blast hurts
## each intact defense once; an explosion interrupts it before it lands.

enum Shock { RECOVER, WARNING }
const FIRST_WARNING: float = 4.0
const RECOVERY: float = 14.0
const WARNING_TIME: float = 2.2
const SHOCK_DAMAGE: float = 48.0

var shock: Shock = Shock.RECOVER
var shock_left: float = FIRST_WARNING
var fired_this_tick: bool = false
var warning_ring: MeshInstance3D
static var vest_material: StandardMaterial3D
static var mark_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "ResidentialShockWarning"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.68
	ring.rings = 12
	ring.ring_segments = 16
	warning_ring.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.32, 0.03)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.20, 0.02)
	material.emission_energy_multiplier = 1.5
	warning_ring.material_override = material
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning_ring.position = Vector3(0, data.height() + 0.55, 0)
	warning_ring.visible = false
	add_child(warning_ring)


func _city_model_scale() -> float:
	return 1.82


## A barricade-colored vest and diagonal warning band ride the existing rig;
## the decoration adds no collision and does not alter head/body hitboxes.
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
		vest_material.albedo_color = Color(0.35, 0.25, 0.20)
		vest_material.roughness = 0.9
		mark_material = StandardMaterial3D.new()
		mark_material.albedo_color = Color(0.92, 0.53, 0.10)
		mark_material.roughness = 0.8
	var socket: BoneAttachment3D = skeleton.get_node_or_null("ResidentialArmor") as BoneAttachment3D
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = "ResidentialArmor"
		skeleton.add_child(socket)
		socket.bone_name = skeleton.get_bone_name(bone)
		_add_panel(socket, "Vest", Vector3(0.62, 0.43, 0.09), Vector3(0, 0.08, 0.17))
		_add_panel(socket, "Band", Vector3(0.52, 0.08, 0.015), Vector3(0, 0.08, 0.22))
		(socket.get_node("Band") as Node3D).rotation.z = -0.35
		_add_panel(socket, "LeftPad", Vector3(0.17, 0.18, 0.15), Vector3(-0.33, 0.17, 0.12))
		_add_panel(socket, "RightPad", Vector3(0.17, 0.18, 0.15), Vector3(0.33, 0.17, 0.12))
	(socket.get_node("Vest") as MeshInstance3D).material_override = vest_material
	for part: String in ["Band", "LeftPad", "RightPad"]:
		(socket.get_node(part) as MeshInstance3D).material_override = mark_material


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
	_reset_shock(FIRST_WARNING)


func _sleep() -> void:
	_reset_shock(FIRST_WARNING)
	super._sleep()


func _reset_shock(delay: float) -> void:
	shock = Shock.RECOVER
	shock_left = delay
	fired_this_tick = false
	if warning_ring:
		warning_ring.visible = false


func tick(delta: float) -> void:
	fired_this_tick = false
	if alive and state == State.ATTACK and slot != null and reel_left <= 0.0:
		shock_left -= delta
		if shock_left <= 0.0:
			if shock == Shock.RECOVER:
				shock = Shock.WARNING
				shock_left = WARNING_TIME
				_play("idle")
				Events.residential_brute_warning.emit(self)
			else:
				_release_shock()
				_reset_shock(RECOVERY)
				fired_this_tick = true
				if alive and state == State.ATTACK:
					_play_attack()
	else:
		if not alive or state != State.ATTACK or slot == null:
			_reset_shock(FIRST_WARNING)
	if warning_ring:
		warning_ring.visible = alive and state == State.ATTACK and shock == Shock.WARNING and reel_left <= 0.0
		if warning_ring.visible:
			warning_ring.rotation.y += delta * 2.5
	super.tick(delta)
	if not alive or state != State.ATTACK or slot == null:
		_reset_shock(FIRST_WARNING)


## Stop the normal swing during the telegraph and on the impact tick so the
## warning corresponds to a single, separate shockwave, not a hidden strike.
func _swing(delta: float) -> void:
	if shock == Shock.WARNING or fired_this_tick:
		return
	super._swing(delta)


func _release_shock() -> void:
	if horde == null or horde.defense == null or horde.layout == null:
		return
	var defense: Defense = horde.defense
	# Apply each target once. A destroyed gate must never redirect its damage
	# to the wall, and the normal defense events still handle destruction.
	defense.apply_damage("wall", SHOCK_DAMAGE, horde.layout.patch_center)
	if not defense.gate_destroyed:
		defense.apply_damage("gate", SHOCK_DAMAGE, horde.layout.gate_center)
	if horde.effects:
		horde.effects.burst("dust", horde.layout.patch_center, Vector3.UP, 1.2)
		if not defense.gate_destroyed:
			horde.effects.burst("dust", horde.layout.gate_center, Vector3.UP, 1.2)


func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	var killed: bool = super.take_blast(amount, origin, share, blast)
	if alive and reel_left > 0.0:
		_reset_shock(RECOVERY)
	return killed


func _die(headshot: bool, direction: Vector3) -> void:
	_reset_shock(FIRST_WARNING)
	super._die(headshot, direction)
