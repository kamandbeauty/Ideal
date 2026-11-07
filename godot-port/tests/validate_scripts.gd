extends SceneTree
## Loads every GDScript in the project and fails if one of them cannot be compiled.
##
## It walks the folders instead of listing files, because a list goes stale the first time somebody
## adds a screen — and a stale list means CI validates 90 % of the port and calls it done.

const ROOTS := ["res://scripts", "res://tests"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: Array[String] = []
	for root_path in ROOTS:
		_collect(root_path, paths)
	paths.sort()

	var failures := 0
	for path in paths:
		var script_resource = ResourceLoader.load(path)
		if script_resource == null or not script_resource is GDScript or not script_resource.can_instantiate():
			push_error("GDScript failed to load: " + path)
			print("::error file=godot-port/%s::GDScript does not compile" % path.replace("res://", ""))
			failures += 1
		else:
			print("ok " + path)

	print("GDScript validation: %d file(s), %d failure(s)" % [paths.size(), failures])
	quit(1 if failures > 0 else 0)

func _collect(directory: String, into: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("cannot open " + directory)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := directory.path_join(entry)
		if dir.current_is_dir():
			_collect(full_path, into)
		elif entry.ends_with(".gd"):
			into.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
