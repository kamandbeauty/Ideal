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
	var directory := DirAccess.open(path)
	if directory == null:
		push_error("Cannot open script directory: " + path)
		_failures += 1
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var child_path := path.path_join(entry)
		if directory.current_is_dir():
			_scan(child_path)
		elif entry.ends_with(".gd"):
			_checked += 1
			var script_resource = ResourceLoader.load(child_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
			if script_resource == null or not script_resource is GDScript or not script_resource.can_instantiate():
				push_error("GDScript failed to load: " + child_path)
				_failures += 1
	 entry = directory.get_next()
	directory.list_dir_end()
