extends Node

signal state_changed(state: State)
enum State { MENU, PLAYING, GAME_OVER, PAUSED }
var state := State.MENU
var run_coins := 0
var score := 0
var revived := false


func start_run() -> void:
	run_coins = 0
	score = 0
	revived = false
	state = State.PLAYING
	SaveManager.data.stats.runs += 1
	SaveManager.save()
	AnalyticsManager.track(&"game_started")
	state_changed.emit(state)


func finish_run() -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	SaveManager.add_coins(run_coins)
	SaveManager.submit_score(score)
	AdManager.note_run_finished()
	AnalyticsManager.track(&"game_over", {"score": score})
	state_changed.emit(state)
