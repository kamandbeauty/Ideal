extends Node
## The game's front door: the guild hall, and - while the Roadstop town is still in
## the tree - the title screen that leads back into it.
##
## `START_IN_GUILD` is the switch that makes this build Guild Tycoon: the app boots
## straight into the hall, while the Roadstop town stays reachable from the title
## screen for the play-through captures.

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const TOWN_SCENE := preload("res://scenes/town/town.tscn")
const GUILD_SCENE := preload("res://scenes/guild.tscn")
const START_IN_GUILD := true

var _current: Node


func _ready() -> void:
	if START_IN_GUILD:
		start_guild()
		return
	show_menu()


## Opens the hall. Leaving it saves and returns to the title screen.
func start_guild() -> void:
	var guild = GUILD_SCENE.instantiate()
	_replace(guild)
	guild.exit_requested.connect(_on_guild_exit)


func _on_guild_exit() -> void:
	show_menu()


func show_menu() -> void:
	Sound.play_music("menu")
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
	# Travelling rebuilds the scene, which is the cheapest honest way to swap a
	# whole town: new ground, new economy, same profile.
	town.travel_requested.connect(_on_travel)


func _on_travel(_town_id: String) -> void:
	_start_town.call_deferred()


func _replace(next: Node) -> void:
	if is_instance_valid(_current):
		remove_child(_current)
		_current.queue_free()
	_current = next
	add_child(next)
