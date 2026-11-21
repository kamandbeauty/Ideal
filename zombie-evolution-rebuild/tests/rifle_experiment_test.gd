extends SceneTree

const Experiment = preload("res://ci/motus_rifle_experiment.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func run_test() -> void:
	var rig = Experiment.new()
	root.add_child(rig)
	check(rig.ready_ok, "experimental animated rifle rig initializes")
	if rig.ready_ok:
		for frame in range(12):
			await process_frame
		var hand_position: Vector3 = rig.right_attachment.global_position
		var grip_position: Vector3 = rig.rifle.to_global(rig.RIGHT_GRIP)
		check(hand_position.distance_to(grip_position) < 0.03, "rifle grip follows right-hand attachment")
		check(rig.solver.is_running(), "support-hand IK runs on animated skeleton")
		check(rig.support_target.global_position.distance_to(rig.rifle.to_global(rig.SUPPORT_GRIP)) < 0.01, "IK target follows rifle support point")
		check(rig.solved_frames > 0, "support IK emitted post-modifier callbacks")
		for clip in ["PistolAimWalk", "PistolAimIdle", "PistolFire"]:
			rig.animation.play(clip)
			for t in [0.0, 0.2, 0.4, 0.6]:
				rig.animation.seek(t, true)
				await process_frame
				await process_frame
				var error: float = rig.solved_hand.distance_to(rig.solved_target)
				var reach: float = rig.solved_root.distance_to(rig.solved_elbow) + rig.solved_elbow.distance_to(rig.solved_hand)
				print("IK_SAMPLE clip=", clip, " time=", t, " error=", error, " root_target=", rig.solved_root.distance_to(rig.solved_target), " arm_length=", reach)
	rig.queue_free()
	await process_frame
	quit(1 if failures else 0)
