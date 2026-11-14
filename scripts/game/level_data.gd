class_name LevelData
extends RefCounted
## The single map the game ships with: a path, build pads and the core.
##
## Geometry is generated from this data, so the visuals and the pathfinding can
## never disagree.

const PATH: Array[Vector3] = [
	Vector3(-20.0, 0.0, -12.0),
	Vector3(-6.0, 0.0, -12.0),
	Vector3(-6.0, 0.0, 0.0),
	Vector3(8.0, 0.0, 0.0),
	Vector3(8.0, 0.0, 12.0),
	Vector3(-2.0, 0.0, 12.0),
	Vector3(-2.0, 0.0, 17.0),
]

const PADS: Array[Vector3] = [
	Vector3(-11.0, 0.0, -6.0),
	Vector3(-10.0, 0.0, 4.0),
	Vector3(0.0, 0.0, -6.0),
	Vector3(3.0, 0.0, 6.0),
	Vector3(13.0, 0.0, 6.0),
	Vector3(-8.0, 0.0, 12.0),
	Vector3(3.0, 0.0, 16.0),
	Vector3(12.0, 0.0, 16.0),
	Vector3(-12.0, 0.0, 10.0),
]

const CORE_POSITION := Vector3(-2.0, 0.0, 17.0)
const SPAWN_POSITION := Vector3(-20.0, 0.0, -12.0)
const GROUND_SIZE := 52.0
const PATH_WIDTH := 3.6
const PAD_RADIUS := 1.7
const CAMERA_FOCUS := Vector3(-1.0, 0.0, 2.0)


static func route() -> Array[Vector3]:
	var points: Array[Vector3] = []
	points.assign(PATH)
	return points


static func path_segments() -> int:
	return PATH.size() - 1

