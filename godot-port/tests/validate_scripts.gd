extends SceneTree

var _failures := 0
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_scan("res://scripts")
	_scan("res://tests")
	print("GDScript validation: %d file(s), %d failure(s)" % [_checked, _failures])
	quit(1 if _failures > 0 else 0)

func _scan(path: String) -> void:
	for file_name in DirAccess.get_files_at(path):
		if not file_name.ends_with(".gd"):
			continue
		_checked += 1
		var child_path := path.path_join(file_name)
		var script_resource = ResourceLoader.load(child_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
		if script_resource == null or not script_resource is GDScript or not script_resource.can_instantiate():
			push_error("GDScript failed to load: " + child_path)
			_failures += 1
	for directory_name in DirAccess.get_directories_at(path):
		if not directory_name.begins_with("."):
			_scan(path.path_join(directory_name))
