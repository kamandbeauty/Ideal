extends RefCounted
## The arithmetic of a thrown grenade.


func run(t: TestContext) -> void:
	var gravity: float = 9.8
	# A lob lands exactly where it was sent, whatever the height difference.
	var cases: Array = [
		[Vector3(0.3, 5.4, -0.6), Vector3(15.0, 0.0, -19.0), 1.3],
		[Vector3(0.0, 5.4, 0.0), Vector3(-12.0, 0.0, -44.0), 2.2],
		[Vector3(0.0, 1.0, 0.0), Vector3(0.0, 4.0, -10.0), 1.0],
		[Vector3(2.0, 5.0, 1.0), Vector3(2.0, 0.0, -6.0), 0.9],
	]
	for case: Array in cases:
		var velocity: Vector3 = Ballistics.lob_velocity(case[0], case[1], case[2], gravity)
		var landing: Vector3 = Ballistics.position_at(case[0], velocity, case[2], gravity)
		t.check(landing.distance_to(case[1]) < 0.0001, "a %.1f s lob lands on its target (miss %.5f m)" % [case[2], landing.distance_to(case[1])])
	# Stepping the same motion in small ticks stays close to the closed form.
	var from := Vector3(0.3, 5.4, -0.6)
	var to := Vector3(15.0, 0.0, -19.0)
	var launch: Vector3 = Ballistics.lob_velocity(from, to, 1.3, gravity)
	var point: Vector3 = from
	var speed: Vector3 = launch
	var tick: float = 1.0 / 60.0
	for index: int in 78:
		speed.y -= gravity * tick
		point += speed * tick
	t.check(point.distance_to(to) < 0.25, "sixty ticks a second follow the same arc (off by %.2f m)" % point.distance_to(to))
	t.check(launch.y > 0.0, "a throw from the wall leaves the hand rising")
	t.near(Ballistics.apex_height(Vector3(3.0, 4.9, 0.0), 9.8), 1.225, 0.0001, "the apex follows from the upward speed")
	t.near(Ballistics.apex_height(Vector3(3.0, -2.0, 0.0), 9.8), 0.0, 0.0001, "a downward throw has no apex above the hand")

	# Flight time grows with distance between its limits.
	t.near(Ballistics.flight_time(10.0, 20.0, 1.25, 2.4), 1.25, 0.0001, "a short throw takes the minimum time")
	t.near(Ballistics.flight_time(40.0, 20.0, 1.25, 2.4), 2.0, 0.0001, "a long throw takes distance over speed")
	t.near(Ballistics.flight_time(90.0, 20.0, 1.25, 2.4), 2.4, 0.0001, "the flight time is capped")

	# Range clamp keeps the bearing.
	var origin := Vector3(0.0, 0.0, 0.0)
	var far: Vector3 = Ballistics.clamp_range(origin, Vector3(30.0, 2.0, -40.0), 6.0, 25.0)
	t.near(Vector2(far.x, far.z).length(), 25.0, 0.0001, "a far target is pulled in to the longest range")
	t.near(atan2(far.x, -far.z), atan2(30.0, 40.0), 0.0001, "the bearing is kept")
	t.near(far.y, 2.0, 0.0001, "the height of the target is kept by the clamp itself")
	var near: Vector3 = Ballistics.clamp_range(origin, Vector3(0.0, 0.0, -2.0), 6.0, 25.0)
	t.near(near.z, -6.0, 0.0001, "a target under the wall is pushed out to the shortest range")
	var inside := Vector3(4.0, 0.0, -12.0)
	t.check(Ballistics.clamp_range(origin, inside, 6.0, 25.0) == inside, "a target inside the range is untouched")
	t.near(Ballistics.clamp_range(origin, Vector3(0.0, 0.0, 0.0), 6.0, 25.0).z, -6.0, 0.0001, "a target straight down gets a default bearing")

	# Bounce.
	var bounced: Vector3 = Ballistics.rebound(Vector3(4.0, -6.0, 0.0), Vector3.UP, 0.3, 0.5)
	t.near(bounced.y, 1.8, 0.0001, "a bounce returns its share of the speed into the ground")
	t.near(bounced.x, 2.0, 0.0001, "and keeps its share of the speed along it")
	var off_wall: Vector3 = Ballistics.rebound(Vector3(5.0, 1.0, 0.0), Vector3.LEFT, 0.3, 0.5)
	t.check(off_wall.x < 0.0, "a wall sends the grenade back")
	t.check(Ballistics.rebound(Vector3(0.0, -3.0, 0.0), Vector3.UP, 0.3, 0.5).length() < 3.0, "every bounce loses energy")
