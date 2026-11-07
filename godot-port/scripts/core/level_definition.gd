class_name LevelDefinition
extends RefCounted

const MIN_BOARD_SIDE := 7
const MAX_BOARD_SIDE := 10

var id := ""
var number := 0
var chapter := "ch01"
var type := "normal"
var width := 9
var height := 9
var gravity: int = GameTypes.GravityDirection.DOWN
var move_limit := 20
var stage_count := 1
var pieces: Array[int] = []
var goals: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var blocked: Array[Vector2i] = []
var reward_potions := 0
var reward_coins := 0

var is_boss: bool:
	get:
		return type == "kingdom" or type == "dark_kingdom"

var is_hard: bool:
	get:
		return type == "hard" or type == "super_hard"

func is_structurally_valid() -> bool:
	if width < MIN_BOARD_SIDE or width > MAX_BOARD_SIDE:
		return false
	if height < MIN_BOARD_SIDE or height > MAX_BOARD_SIDE:
		return false
	if move_limit < 5 or move_limit > 100:
		return false
	if pieces.size() < 4 or pieces.size() > 6 or goals.is_empty():
		return false
	for goal in goals:
		if goal.is_empty() or int(goal.get("target", 0)) <= 0:
			return false
	for obstacle in obstacles:
		if obstacle.is_empty():
			return false
		var x := int(obstacle.get("x", -1))
		var y := int(obstacle.get("y", -1))
		if x < 0 or y < 0 or x >= width or y >= height:
			return false
		if int(obstacle.get("kind", 0)) == GameTypes.ObstacleKind.NONE or int(obstacle.get("layers", 1)) < 1:
			return false
	return true
