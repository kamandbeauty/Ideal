extends SceneTree

const SCRIPT_PATHS := [
	"res://scripts/core/game_types.gd",
	"res://scripts/core/board_model.gd",
	"res://scripts/core/match_finder.gd",
	"res://scripts/core/deterministic_random.gd",
	"res://scripts/core/level_definition.gd",
	"res://scripts/core/goal_tracker.gd",
	"res://scripts/core/power_ups.gd",
	"res://scripts/core/board_factory.gd",
	"res://scripts/core/move_resolver.gd",
	"res://scripts/main.gd",
	"res://tests/test_core.gd"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	for path in SCRIPT_PATHS:
		var script_resource = ResourceLoader.load(path)
		if script_resource == null or not script_resource is GDScript or not script_resource.can_instantiate():
			push_error("GDScript failed to load: " + path)
			failures += 1
	print("GDScript validation: %d file(s), %d failure(s)" % [SCRIPT_PATHS.size(), failures])
	quit(1 if failures > 0 else 0)
