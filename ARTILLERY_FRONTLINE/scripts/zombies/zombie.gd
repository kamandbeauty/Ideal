class_name Zombie
extends Node3D
## One zombie. It has no _process of its own: the Horde ticks every active
## zombie from a single loop and recycles the node when the corpse is gone.

enum State { POOLED, ADVANCE, WAIT, ATTACK, BREACH, DYING, CORPSE }

const LOOPING: Array[String] = ["idle", "attack"]
## A blast throws a body over this long.
const KNOCK_TIME: float = 0.38
## The most a hit can tip the figure, in degrees.
const ROCK_LIMIT: float = 7.0
## A heading this close to the goal (in radians, a thirtieth of a degree) counts as reached.
const FACING_SLACK: float = 0.0006

var data: ZombieData
var horde: Horde
var state: State = State.POOLED
var alive: bool = false
var health: float = 0.0
## Health it started this life with (the type's health, hardened by the wave).
var full_health: float = 1.0
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
## Every walk the model brings (lame in one leg, lame in the other, and whatever variations its kind has),
## and the one this zombie has for this life.
var walk_clips: Array[String] = []
var walk_clip: String = "walk"
## The figure itself, under this node; a hit tips it for a moment without moving the zombie.
var model: Node3D
## Degrees the figure is tipped right now: (backwards, sideways).
var rock := Vector2.ZERO
var anim: AnimationPlayer
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var body_area: Area3D
var head_area: Area3D
var blows: int = 0
## Own model plus any extra character meshes this type mixes in.
var looks: Array[Node3D] = []
var look_anims: Array = []
var look_skeletons: Array = []
var look_meshes: Array = []
var head_areas: Array[Area3D] = []
var look_index: int = 0
## Extra lean this figure was born with, in radians, so a crowd does not stand alike.
var gait_lean := Vector3.ZERO
## Playback of the walk, on top of speed / stride_speed.
var gait_rate: float = 1.0


func _ready() -> void:
	model = get_node_or_null("Model")
	looks.clear()
	if model:
		looks.append(model)
	if data:
		for packed: PackedScene in data.extra_looks:
			if packed == null:
				continue
			var extra: Node3D = packed.instantiate()
			extra.visible = false
			extra.name = "Look%d" % looks.size()
			add_child(extra)
			looks.append(extra)
	look_anims.clear()
	look_skeletons.clear()
	look_meshes.clear()
	for look: Node3D in looks:
		var player: AnimationPlayer = look.find_child("AnimationPlayer", true, false)
		var skel: Skeleton3D = look.find_child("Skeleton3D", true, false)
		var mesh: MeshInstance3D = null
		for node: Node in look.find_children("*", "MeshInstance3D", true, false):
			mesh = node
			break
		look_anims.append(player)
		look_skeletons.append(skel)
		look_meshes.append(mesh)
		if player:
			for clip: String in player.get_animation_list():
				if clip.begins_with("walk") or clip in LOOPING:
					if player.has_animation(clip):
						player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			player.playback_default_blend_time = 0.18
	_use_look(0)
	_build_hit_volumes()
	_sleep()


func _use_look(index: int) -> void:
	if looks.is_empty():
		return
	if anim:
		anim.stop()
		current_clip = ""
	look_index = clampi(index, 0, looks.size() - 1)
	for i: int in looks.size():
		looks[i].visible = i == look_index
	model = looks[look_index]
	anim = look_anims[look_index]
	skeleton = look_skeletons[look_index]
	body_mesh = look_meshes[look_index]
	head_area = head_areas[look_index] if look_index < head_areas.size() else head_area
	walk_clips.clear()
	if anim:
		for clip: String in anim.get_animation_list():
			if _walk_name(clip).begins_with("walk"):
				walk_clips.append(clip)
		walk_clips.sort()


func _walk_name(clip: String) -> String:
	var slash: int = clip.rfind("/")
	return clip.substr(slash + 1) if slash >= 0 else clip


func _build_hit_volumes() -> void:
	var radius: float = data.body_radius if data else 0.3
	var height: float = data.body_height if data else 1.45
	var head_radius: float = data.head_radius if data else 0.2
	var lean: float = deg_to_rad(data.body_lean_degrees if data else 10.0)
	body_area = _area("Body", false)
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	var body_shape := CollisionShape3D.new()
	body_shape.shape = capsule
	# The walk leans forward, so the trunk sits ahead of the feet.
	body_shape.position = Vector3(0.0, height * 0.5 + 0.02, sin(lean) * height * 0.4)
	body_shape.rotation.x = lean
	body_area.add_child(body_shape)
	add_child(body_area)
	head_areas.clear()
	var hosts: Array = looks if not looks.is_empty() else [self]
	for i: int in hosts.size():
		var host: Node = hosts[i]
		var skel: Skeleton3D = look_skeletons[i] if i < look_skeletons.size() else skeleton
		var head: Area3D = _area("Head", true)
		var sphere := SphereShape3D.new()
		sphere.radius = head_radius
		var head_shape := CollisionShape3D.new()
		head_shape.shape = sphere
		# The skull sits half a radius above the joint that carries it.
		head_shape.position = Vector3(0.0, head_radius * 0.5, head_radius * 0.15)
		head.add_child(head_shape)
		var bone: int = skel.find_bone("Head") if skel else -1
		if bone >= 0:
			# Ride the head bone so a lunging or falling zombie keeps an honest head box.
			var attachment := BoneAttachment3D.new()
			attachment.name = "HeadSocket"
			skel.add_child(attachment)
			attachment.bone_name = "Head"
			attachment.add_child(head)
		else:
			head.position = Vector3(0.0, height + head_radius * 0.5, sin(lean) * height * 0.8)
			host.add_child(head)
		head_areas.append(head)
	head_area = head_areas[look_index] if look_index < head_areas.size() else head_areas[0]


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
	for i: int in head_areas.size():
		head_areas[i].collision_layer = Layers.ZOMBIE_HEAD if enabled and i == look_index else 0
	if head_areas.is_empty() and head_area:
		head_area.collision_layer = Layers.ZOMBIE_HEAD if enabled else 0


func _sleep() -> void:
	state = State.POOLED
	alive = false
	visible = false
	slot = null
	_settle_rock()
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
	var chosen: int = rng.randi() % maxi(looks.size(), 1)
	_use_look(chosen)
	var health_mul: float = 1.0
	var size_mul: float = 1.0
	if chosen > 0:
		var extra: int = chosen - 1
		if extra < data.extra_look_health.size() and data.extra_look_health[extra] > 0.0:
			health_mul = data.extra_look_health[extra]
		if extra < data.extra_look_scale.size() and data.extra_look_scale[extra] > 0.0:
			size_mul = data.extra_look_scale[extra]
	health = data.max_health * health_scale * health_mul
	full_health = health
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
	_settle_rock()
	var bulk: float = rng.randf_range(data.scale_min, data.scale_max) * size_mul
	scale = Vector3(bulk * rng.randf_range(0.93, 1.07), bulk * rng.randf_range(0.90, 1.12), bulk)
	gait_lean = Vector3(rng.randf_range(-0.03, 0.14), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.10, 0.10))
	gait_rate = rng.randf_range(0.92, 1.08)
	_apply_rock()
	position = path[0] if path.size() > 0 else Vector3.ZERO
	if path.size() > 1:
		var ahead: Vector3 = path[1] - path[0]
		facing_goal = atan2(ahead.x, ahead.z)
		rotation = Vector3(0.0, facing_goal, 0.0)
	if body_mesh:
		if chosen == 0:
			body_mesh.material_override = MaterialLibrary.zombie_skin(String(data.id), rng.randi() % data.skins)
		else:
			body_mesh.material_override = null
	visible = true
	_set_hittable(true)
	# Each life picks a limp (which leg, and how broken) and a point in the stride, so a crowd does not march.
	walk_clip = _pick_walk(rng)
	_play(walk_clip, speed / data.stride_speed * gait_rate, 0.0)
	if anim and anim.has_animation(walk_clip):
		anim.seek(rng.randf() * anim.get_animation(walk_clip).length, true)
		anim.advance(0.0)


func _pick_walk(rng: RandomNumberGenerator) -> String:
	if walk_clips.is_empty():
		return "walk"
	var broken: Array[String] = []
	var regular: Array[String] = []
	for clip: String in walk_clips:
		if _walk_name(clip).begins_with("walk_b"):
			broken.append(clip)
		else:
			regular.append(clip)
	var pool: Array[String] = broken if not broken.is_empty() and rng.randf() < 0.5 else regular
	if pool.is_empty():
		pool = walk_clips
	return pool[rng.randi() % pool.size()]


func _play(clip: String, rate: float = 1.0, blend: float = -1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if current_clip == clip:
		anim.speed_scale = rate
		return
	current_clip = clip
	anim.play(clip, blend, 1.0)
	anim.speed_scale = rate


## Share of its starting health that is left.
func health_fraction() -> float:
	return clampf(health / maxf(full_health, 1.0), 0.0, 1.0)


## Pushed off its place by something bigger: steps back to `point` and looks for another.
func fall_back(point: Vector3) -> void:
	slot = null
	if not alive or state == State.BREACH:
		return
	path = PackedVector3Array([position, point])
	path_index = 1
	court_index = 0
	state = State.ADVANCE
	retry_left = 0.3
	_play(walk_clip, speed / data.stride_speed * gait_rate)


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
		_play(walk_clip, speed / data.stride_speed * gait_rate)
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
	_play(walk_clip, speed * 1.25 / data.stride_speed * gait_rate)


func tick(delta: float) -> void:
	if rock != Vector2.ZERO:
		# The figure rights itself in a fraction of a second.
		rock = rock.lerp(Vector2.ZERO, 1.0 - exp(-13.0 * delta))
		if rock.length_squared() < 0.0004:
			rock = Vector2.ZERO
		_apply_rock()
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
				horde.fell(self)
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
	# One that already faces its goal is left alone: writing the same heading every tick re-sends the
	# transform of the figure and of both its hit volumes for nothing, and a full line at the wall stands still.
	if absf(angle_difference(rotation.y, facing_goal)) < FACING_SLACK:
		return
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
			_play(walk_clip, speed / data.stride_speed * gait_rate)
		State.BREACH:
			_play(walk_clip, speed * 1.25 / data.stride_speed * gait_rate)
		State.ATTACK:
			_play_attack()
		State.WAIT:
			_play("idle")


## Returns true when the hit kills. `direction` is the bullet's travel.
func take_hit(amount: float, headshot: bool, _at: Vector3, direction: Vector3) -> bool:
	if not alive:
		return false
	if headshot:
		amount *= data.head_damage_scale
	health -= amount
	if health <= 0.0:
		_die(headshot, direction)
		return true
	flinch_left = 0.3
	_rock(direction, clampf(amount / maxf(full_health, 1.0) * 6.0, 0.35, 1.0))
	if state == State.ADVANCE and stagger_left <= 0.0 and amount >= data.max_health * data.stagger_health_share:
		stagger_left = 0.36
		_play("hit", 1.15, 0.06)
	return false


## Area damage. `share` is 1 at the heart of the blast and falls toward its
## edge; it scales how long a survivor reels and how far a body is thrown.
## Returns true when the blast kills.
func take_blast(amount: float, origin: Vector3, share: float, blast: ExplosionData) -> bool:
	if not alive:
		return false
	health -= amount * data.blast_damage_scale
	var away := Vector3(position.x - origin.x, 0.0, position.z - origin.z)
	if away.length_squared() < 0.0004:
		away = -Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	away = away.normalized()
	if health <= 0.0:
		var throw: Vector3 = away * blast.knockback * share * data.knockback_scale
		knock = horde.clamp_throw(position, throw) if horde else throw
		knock_left = KNOCK_TIME
		_die(false, away)
		return true
	if data.blast_reel_scale <= 0.0:
		# Too big to be stopped by a blast: it only shows the hit.
		flinch_left = 0.3
		_rock(away, 1.6)
		return false
	reel_left = maxf(reel_left, maxf(0.25, blast.stagger_time * share * data.blast_reel_scale))
	flinch_left = reel_left + 0.3
	stagger_left = 0.0
	if anim and anim.has_animation("hit"):
		current_clip = "hit"
		anim.play("hit", 0.06, 1.0)
		anim.speed_scale = clampf(anim.get_animation("hit").length / reel_left, 0.35, 1.4)
	return false


## Tips the figure away from a hit travelling along `direction` (world space). `weight` is 1 for a solid hit.
func _rock(direction: Vector3, weight: float) -> void:
	if model == null or data.hit_rock_degrees <= 0.0:
		return
	# In the zombie's own frame, +Z is where it faces and +X is its left.
	var local: Vector3 = direction.rotated(Vector3.UP, -rotation.y)
	var push: float = data.hit_rock_degrees * weight
	rock = (rock + Vector2(local.z, -local.x) * push).limit_length(ROCK_LIMIT)
	_apply_rock()


func _apply_rock() -> void:
	if model:
		model.rotation = gait_lean + Vector3(deg_to_rad(rock.x), 0.0, deg_to_rad(rock.y))


func _settle_rock() -> void:
	rock = Vector2.ZERO
	if model:
		model.rotation = gait_lean


## Where the body lies once it has fallen: on the ground, between the feet and the head.
func resting_point() -> Vector3:
	var rest: Vector3 = global_position
	if head_area != null and head_area.is_inside_tree():
		var head: Vector3 = head_area.global_position
		rest = Vector3(lerpf(rest.x, head.x, 0.55), rest.y, lerpf(rest.z, head.z, 0.55))
	return rest


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
