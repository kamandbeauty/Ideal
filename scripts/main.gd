extends Node
## Switches between the title screen and a city session.

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const CITY_SCENE := preload("res://scenes/city/city.tscn")

var _current: Node


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	var menu = MENU_SCENE.instantiate()
	_replace(menu)
	menu.play_requested.connect(start_new_city)
	menu.continue_requested.connect(start_continue)


func start_new_city() -> void:
	CityState.delete_save()
	_start_city(false)


func start_continue() -> void:
	_start_city(true)


func _start_city(load_save: bool) -> void:
	var city = CITY_SCENE.instantiate()
	city.load_from_file = load_save
	_replace(city)
	city.exit_requested.connect(show_menu)


func _replace(next: Node) -> void:
	if is_instance_valid(_current):
		remove_child(_current)
		_current.queue_free()
	_current = next
	add_child(next)
