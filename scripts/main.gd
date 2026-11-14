extends Node
## Switches between the title screen and a town session.

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const TOWN_SCENE := preload("res://scenes/town/town.tscn")

var _current: Node


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	var menu = MENU_SCENE.instantiate()
	_replace(menu)
	menu.play_requested.connect(start_new_game)
	menu.continue_requested.connect(start_continue)


func start_new_game() -> void:
	Game.start_new_game()
	_start_town()


func start_continue() -> void:
	Game.continue_game()
	_start_town()


func _start_town() -> void:
	var town = TOWN_SCENE.instantiate()
	_replace(town)
	town.exit_requested.connect(show_menu)


func _replace(next: Node) -> void:
	if is_instance_valid(_current):
		remove_child(_current)
		_current.queue_free()
	_current = next
	add_child(next)
