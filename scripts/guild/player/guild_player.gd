class_name GuildPlayer
extends CharacterBody3D
## The guild manager the player walks around as.
##
## Movement is camera-relative, acceleration-based and blocked while a verb plays,
## so picking something up always reads as a deliberate action. The visible carry
## stack is rebuilt from `state.carry`, never from a guess.

const WALK_SPEED := 2.2
const RUN_SPEED := 4.2
const ACCELERATION := 12.0
const DECELERATION := 16.0
const GRAVITY := 18.0
const TURN_RATE := 12.0
const HAND_HEIGHT := 1.16

var state: GuildPlayerState
var character: GuildCharacter
var carry_stack: GuildCarryStack
var input_vector := Vector2.ZERO
var sprint := false
var camera_yaw := 0.0


func _init() -> void:
	name = "GuildPlayer"
	state = GuildPlayerState.new()
	character = GuildCharacter.new("guildmaster", true)
	add_child(character)
	carry_stack = GuildCarryStack.new()
	var anchor := character.stack_anchor()
	if anchor != null:
		anchor.add_child(carry_stack)
		carry_stack.position = Vector3(0.0, -0.12, 0.0)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	_build_collision()
	state.changed.connect(_on_state_changed)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Body"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.85, 0.0)
	add_child(shape)


func _physics_process(delta: float) -> void:
	state.tick(delta)
	_apply_movement(delta)
	character.animate(delta, Vector2(velocity.x, velocity.z).length(), animation_pose())


## Left stick (or WASD), in the -1..1 range. Y is forward.
func set_input(value: Vector2) -> void:
	input_vector = value.limit_length(1.0)


func set_sprint(enabled: bool) -> void:
	sprint = enabled


## The camera yaw in degrees, so "forward" is always away from the camera.
func set_camera_yaw(degrees: float) -> void:
	camera_yaw = degrees


func animation_pose() -> String:
	return state.pose_for(Vector2(velocity.x, velocity.z).length(), sprint)


## Starts an interaction verb and returns whether it was accepted.
func interact(verb: String) -> bool:
	return state.start_verb(verb)


func _apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var desired := Vector3.ZERO
	if not state.is_busy():
		var direction := Vector3(input_vector.x, 0.0, input_vector.y)
		if direction.length() > 0.01:
			var yaw_rad := deg_to_rad(camera_yaw)
			var rotated := direction.rotated(Vector3.UP, yaw_rad)
			var top_speed := RUN_SPEED if sprint else WALK_SPEED
			var carrying := 0.88 if state.carry > 0 else 1.0
			desired = rotated.normalized() * top_speed * carrying

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ACCELERATION if desired.length() > 0.01 else DECELERATION
	horizontal = horizontal.move_toward(desired, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if horizontal.length() > 0.05:
		var facing := atan2(-horizontal.x, -horizontal.z)
		rotation.y = lerp_angle(rotation.y, facing, minf(1.0, delta * TURN_RATE))

	move_and_slide()


func _on_state_changed() -> void:
	if carry_stack == null:
		return
	carry_stack.show_items(state.carry)
