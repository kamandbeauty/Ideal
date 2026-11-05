extends RefCounted
func run(t: TestContext) -> void:
	var origin := Vector3(0, 10, 0)
	var velocity := Vector3(0, 30, -40)
	var full: Dictionary = Ballistics.integrate(origin, velocity, 2.0)
	t.near(full.position.y, 10.0 + 60.0 - 0.5 * 9.81 * 4.0, 0.00001, "Constant gravity displacement")
	t.near(full.position.z, -80.0, 0.00001, "Horizontal velocity preserved")
	t.near(full.velocity.y, 10.38, 0.00001, "Gravity velocity")
	var half: Dictionary = Ballistics.integrate(origin, velocity, 1.0)
	var split: Dictionary = Ballistics.integrate(half.position, half.velocity, 1.0)
	t.near(full.position.distance_to(split.position), 0.0, 0.00001, "Time composition exact")
	var prediction: PackedVector3Array = Ballistics.predict(origin, velocity, 0.0, 0.1)
	var actual: Dictionary = {"position": origin, "velocity": velocity}
	for step in range(60):
		actual = Ballistics.integrate(actual.position, actual.velocity, 1.0 / 60.0)
	t.near(prediction[10].distance_to(actual.position), 0.0, 0.0001, "Prediction and live-shell model agree")
	var dragged: Dictionary = Ballistics.integrate(origin, velocity, 40.0, 0.2)
	t.check(dragged.position.x == 0.0 and is_finite(dragged.position.y), "Drag remains finite")
	t.near(dragged.velocity.y, -9.81 / 0.2, 0.04, "Linear drag terminal velocity")
	for distance in [100.0, 250.0, 450.0, 650.0]:
		var target := Vector3(20, 3, -distance)
		var result: Dictionary = Ballistics.solution(origin, target, 90.0)
		t.check(result.valid, "Reachable target has solution")
		var shot: Dictionary = Ballistics.integrate(origin, Ballistics.direction(result.yaw, result.elevation) * 90.0, result.flight_time)
		t.near(shot.position.distance_to(target), 0.0, 0.001, "Fire-control solution lands on target")
	var drag_solution: Dictionary = Ballistics.solution(Vector3.ZERO, Vector3(0, 0, -150), 82.0, false, 0.02)
	t.check(drag_solution.valid, "Drag solution converges")
	if drag_solution.valid:
		var landed: Dictionary = Ballistics.integrate(Vector3.ZERO, Ballistics.direction(drag_solution.yaw, drag_solution.elevation) * 82.0, drag_solution.flight_time, 0.02)
		t.near(landed.position.distance_to(Vector3(0, 0, -150)), 0.0, 0.05, "Drag fire-control matches integrator")
	t.check(not Ballistics.solution(Vector3.ZERO, Vector3(0, 0, -2000), 82.0).valid, "Out-of-range solution rejected")
