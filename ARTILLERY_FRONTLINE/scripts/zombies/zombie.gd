class_name Zombie
extends Node3D
## One zombie. It has no _process of its own: the Horde ticks every active
## zombie from a single loop and recycles the node when the corpse is gone.

enum State { POOLED, ADVANCE, WAIT, ATTACK, BREACH, DYING, CORPSE }

const LOOPING: Array[String] = ["walk", "idle", "attack"]
## A blast throws a body over this long.
const KNOCK_TIME: float = 0.38

var data: ZombieData
var horde: Horde
var state: State = State.POOLED
var alive: bool = false
var health: float = 0.0
var speed: float = 1.0
var path := PackedVector3Array()
var path_index: int = 0
## Index of the court-mouth waypoint; everything before it is the street route.
var court_index: int = 0
var slot: AttackLines.Slot = null
var target: String = "gate"
var side: String = "right"
var lateral: float = 0.0
var timer: float = 0.0
var attack_clock: float = 0.0
var attack_landed: bool = false
var flinch_left: float = 0.0
var stagger_left: float = 0.0
## Time left reeling from a blast: neither walking nor striking.
var reel_left: float = 0.0
## What a blast still has to push this body, and for how long.
var knock := Vector3.ZERO
var knock_left: float = 0.0
var retry_left: float = 0.0
var facing_goal: float = 0.0
var current_clip: String = ""
var anim: AnimationPlayer
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var body_area: Area3D
var head_area: Area3D
var blows: int = 0


func _ready() -> void:
	anim = find_child("AnimationPlayer", true, false)
	skeleton = find_child("Skeleton3D", true, false)
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		body_mesh = node
		break
	if anim:
		for clip: String in LOOPING:
			if anim.has_animation(clip):
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		anim.playback_default_blend_time = 0.18
	_build_hit_volumes()
	_sleep()


func _build_hit_volumes() -> void:
	var radius: float = data.body_radius if data else 0.3
	var height: float = data.body_height if data else 1.45
	var head_radius: float = data.head_radius if data else 0.2
	body_area = _area("Body", false)
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	var body_shape := CollisionShape3D.new()
	body_shape.shape = capsule
	# The walk leans forward, so the trunk sits ahead of the feet.
	body_shape.position = Vector3(0.0, height * 0.5 + 0.02, 0.1)
	body_shape.rotation.x = deg_to_rad(10.0)
	body_area.add_child(body_shape)
	add_child(body_area)
	head_area = _area("Head", true)
	var sphere := SphereShape3D.new()
	sphere.radius = head_radius
	var head_shape := CollisionShape3D.new()
	head_shape.shape = sphere
	head_shape.position = Vector3(0.0, 0.1, 0.03)
	head_area.add_child(head_shape)
	var bone: int = skeleton.find_bone("Head") if skeleton else -1
	if bone >= 0:
		# Ride the head bone so a lunging or falling zombie keeps an honest head box.
		var attachment := BoneAttachment3D.new()
		attachment.name = "HeadSocket"
		skeleton.add_child(attachment)
		attachment.bone_name = "Head"
		attachment.add_child(head_area)
	else:
		head_area.position = Vector3(0.0, height + 0.1, 0.25)
		add_child(head_area)


func _area(area_name: String, head: bool) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	area.monitoring = false
	area.monitorable = false
	area.input_ray_pickable = false
	area.collision_mask = 0
	area.collision_layer = 0
	area.set_meta("zombie", self)
	area.set_meta("head", head)
	return area


func hit_rids() -> Array[RID]:
	return [body_area.get_rid(), head_area.get_rid()]


func _set_hittable(enabled: bool) -> void:
	body_area.collision_layer = Layers.ZOMBIE_BODY if enabled else 0
	head_area.collision_layer = Layers.ZOMBIE_HEAD if enabled else 0


func _sleep() -> void:
	state = State.POOLED
	alive = false
	visible = false
	slot = null
	_set_hittable(false)
	if anim:
		anim.stop()
	current_clip = ""


## Brings a pooled zombie to life at the start of `walk_path`.
func activate(walk_path: PackedVector3Array, claimed: AttackLines.Slot, wanted: String, lane_side: String, lane: float,
		health_scale: float, speed_scale: float, rng: RandomNumberGenerator) -> void:
	path = walk_path
	path_index = 1 if path.size() > 1 else 0
	court_index = path.size() - 1
	slot = claimed
	target = wanted
	side = lane_side
	lateral = lane
	health = data.max_health * health_scale
	speed = data.speed * speed_scale * (1.0 + rng.randf_range(-data.speed_variance, data.speed_variance))
	alive = true
	state = State.ADVANCE
	timer = 0.0
	flinch_left = 0.0
	stagger_left = 0.0
	reel_left = 0.0
	knock_left = 0.0
	retry_left = rng.randf_range(0.2, 0.8)
	blows = 0
	scale = Vector3.ONE * rng.randf_range(data.scale_min, data.scale_max)
	position = path[0] if path.size() > 0 else Vector3.ZERO
	if path.size() > 1:
		var ahead: Vector3 = path[1] - path[0]
		facing_goal = atan2(ahead.x, ahead.z)
		rotation = Vector3(0.0, facing_goal, 0.0)
	if body_mesh:
		body_mesh.material_override = MaterialLibrary.zombie_skin(String(data.id), rng.randi() % data.skins)
	visible = true
	_set_hittable(true)
	_play("walk", speed / data.stride_speed, 0.0)
	if anim and anim.has_animation("walk"):
		anim.seek(rng.randf() * anim.get_animation("walk").length, true)


func _play(clip: String, rate: float = 1.0, blend: float = -1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if current_clip == clip:
		anim.speed_scale = rate
		return
	current_clip = clip
	anim.play(clip, blend, 1.0)
	anim.speed_scale = rate


## Sends the zombie to a (new) standing place.
func assign_slot(claimed: AttackLines.Slot) -> void:
	slot = claimed
	if not alive or state == State.BREACH:
		return
	if state == State.WAIT or state == State.ATTACK:
		path = PackedVector3Array([position, claimed.position])
		path_index = 1
		court_index = 0
		state = State.ADVANCE
		_play("walk", speed / data.stride_speed)
	elif path.size() > 0:
		path[path.size() - 1] = claimed.position


## The target fell: run through the gap instead of attacking it.
func enter_breach(route: PackedVector3Array) -> void:
	if not alive:
		return
	slot = null
	var through := PackedVector3Array([position])
	if state == State.ADVANCE and path_index <= court_index:
		# Still out in the streets: finish the walk to the court mouth first.
		for index: int in range(path_index, mini(court_index + 1, path.size())):
			through.append(path[index])
	through.append_array(route)
	path = through
	path_index = 1
	court_index = 0
	state = State.BREACH
	_play("walk", speed * 1.25 / data.stride_speed)


func tick(delta: float) -> void:
	if knock_left > 0.0:
		# Thrown by a blast: the push fades out as the body goes down.
		var share: float = minf(delta, knock_left) / KNOCK_TIME
		position += knock * share
		knock_left -= delta
	if reel_left > 0.0:
		reel_left -= delta
		if alive:
			if reel_left <= 0.0:
				_resume_clip()
			return
	match state:
		State.ADVANCE:
			if _walk(delta, 1.0):
				_arrive()
		State.WAIT:
			_turn(delta)
			if slot == null:
				retry_left -= delta
				if retry_left <= 0.0:
					retry_left = 0.8
					horde.find_place(self)
		State.ATTACK:
			_turn(delta)
			_swing(delta)
		State.BREACH:
			if _walk(delta, 1.25):
				horde.entered_city(self)
		State.DYING:
			timer -= delta
			if timer <= 0.0:
				state = State.CORPSE
				timer = data.corpse_time
		State.CORPSE:
			timer -= delta
			if timer < 1.6:
				position.y -= delta * 0.5
			if timer <= 0.0:
				horde.recycle(self)
	if stagger_left > 0.0:
		stagger_left -= delta
		if stagger_left <= 0.0 and alive:
			_resume_clip()
	if flinch_left > 0.0:
		flinch_left -= delta


## True when the end of the path is reached.
func _walk(delta: float, pace: float) -> bool:
	if path_index >= path.size():
		return true
	var goal: Vector3 = path[path_index]
	var offset: Vector3 = goal - position
	offset.y = 0.0
	var distance: float = offset.length()
	var slow: float = data.flinch_slow if flinch_left > 0.0 else 1.0
	var step: float = speed * pace * slow * delta
	if distance <= step:
		position = Vector3(goal.x, position.y, goal.z)
		path_index += 1
		return path_index >= path.size()
	position += offset / distance * step
	facing_goal = atan2(offset.x, offset.z)
	_turn(delta)
	return false


func _turn(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, facing_goal, 1.0 - exp(-data.turn_speed * delta))


func _arrive() -> void:
	if slot == null:
		state = State.WAIT
		_play("idle")
		return
	facing_goal = atan2(slot.facing.x, slot.facing.z)
	if slot.row == 0:
		state = State.ATTACK
		# Stagger the swings so a full line does not strike as one.
		attack_clock = float(slot.column % 4) * 0.21 * data.attack_interval
		attack_landed = attack_clock > data.attack_hit_point * data.attack_interval
		_play_attack()
	else:
		state = State.WAIT
		_play("idle")


func _play_attack() -> void:
	if anim and anim.has_animation("attack"):
		_play("attack", anim.get_animation("attack").length / data.attack_interval)
		anim.seek(fmod(attack_clock, data.attack_interval) / data.attack_interval * anim.get_animation("attack").length, true)


func _swing(delta: float) -> void:
	attack_clock += delta
	if not attack_landed and attack_clock >= data.attack_hit_point * data.attack_interval:
		attack_landed = true
		blows += 1
		if slot != null:
			horde.strike(self, slot)
	if attack_clock >= data.attack_interval:
		attack_clock -= data.attack_interval
		attack_landed = false


func _resume_clip() -> void:
	match state:
		State.ADVANCE:
			_play("walk", speed / data.stride_speed)
		State.BREACH:
			_play("walk", speed * 1.25 / data.stride_speed)
		State.ATTACK:
			_play_attack()
		State.WAIT:
			_play("idle")


## Returns true when the hit kills. `direction` is the bullet's travel.
func take_hit(amount: float, headshot: bool, _at: Vector3, direction: Vector3) -> bool:
	if not alive:
		return false
	health -= amount
	if health <= 0.0:
		_die(headshot, direction)
		return true
	flinch_left = 0.3
	if state == State.ADVANCE and stagger_left <= 0.0 and amount >= data.max_health * 0.3:
		stagger_left = 0.36
		_play("hit", 1.15, 0.06)
	return false


## Area damage. `share` is 1 at the heart of the blast and falls toward its
## edge; it scales how long a survivor reels and how far a body is thrown.
## Returns true when the blast kills.
func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	if not alive:
		return false
	health -= amount
	var away := Vector3(position.x - origin.x, 0.0, position.z - origin.z)
	if away.length_squared() < 0.0004:
		away = -Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	away = away.normalized()
	if health <= 0.0:
		knock = horde.clamp_throw(position, away * blast.knockback * share) if horde else away * blast.knockback * share
		knock_left = KNOCK_TIME
		_die(false, away)
		return true
	reel_left = maxf(reel_left, maxf(0.25, blast.stagger_time * share))
	flinch_left = reel_left + 0.3
	stagger_left = 0.0
	if anim and anim.has_animation("hit"):
		current_clip = "hit"
		anim.play("hit", 0.06, 1.0)
		anim.speed_scale = clampf(anim.get_animation("hit").length / reel_left, 0.35, 1.4)
	return false


func kill(headshot: bool = false, direction: Vector3 = Vector3.BACK) -> void:
	if alive:
		_die(headshot, direction)


func _die(headshot: bool, direction: Vector3) -> void:
	alive = false
	state = State.DYING
	_set_hittable(false)
	stagger_left = 0.0
	reel_left = 0.0
	horde.release_place(self)
	# Shot from the front it goes over backwards; caught from behind or the side it pitches forward.
	var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var clip: String = "death_back" if (headshot or forward.dot(direction) < -0.2) else "death_front"
	if anim and anim.has_animation(clip):
		current_clip = clip
		anim.play(clip, 0.08, 1.0)
		anim.speed_scale = 1.0
		timer = anim.get_animation(clip).length
	else:
		timer = 0.5
	horde.died(self, headshot)


func recycle() -> void:
	_sleep()
