extends SceneTree
func _initialize() -> void:
	var image := Image.new()
	var error: int = image.load("res://assets/textures/icon.svg")
	if error == OK:
		error = image.save_png("res://assets/textures/icon.png")
	print("Icon rasterization: ", error_string(error))
	quit(error)
