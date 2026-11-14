extends Node
## Switches between the title screen and a run of the game.

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const BATTLE_SCENE := preload("res://scenes/game/battle.tscn")

var _current: Node


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	var menu = MENU_SCENE.instantiate()
	_replace(menu)
	menu.play_requested.connect(start_battle)


func start_battle() -> void:
	var battle = BATTLE_SCENE.instantiate()
	_replace(battle)
	battle.exit_requested.connect(show_menu)
	battle.retry_requested.connect(start_battle)


func _replace(next: Node) -> void:
	if is_instance_valid(_current):
		remove_child(_current)
		_current.queue_free()
	_current = next
	add_child(next)
