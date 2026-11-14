extends Control
## Entry point of the game.
##
## This is a placeholder scene: it only proves the project boots. The real
## game is built on top of it once the design is set.

@onready var _title: Label = $Center/Stack/Title


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "Ideal")
