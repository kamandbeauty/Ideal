extends Node

signal rewarded_completed(placement: String)
signal rewarded_failed(reason: String)


func is_rewarded_available(_placement: String) -> bool:
	return true


func show_rewarded(placement: String) -> bool:
	rewarded_completed.emit(placement)
	return true
