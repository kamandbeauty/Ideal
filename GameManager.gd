extends Node
## Drives Level 1 flow per the spec's 9 sections, tracks score/stats,
## and triggers the Persian victory/defeat screens via HUD.gd.

signal level_completed(stats: Dictionary)
signal level_failed

@export var player_path: NodePath   # TODO: assign Player node
@export var squad_path: NodePath    # TODO: assign Squad node
@export var hud_path: NodePath      # TODO: assign HUD node

@export var normal_zombie_scene: PackedScene  # TODO: assign
@export var runner_zombie_scene: PackedScene  # TODO: assign
@export var brute_zombie_scene: PackedScene   # TODO: assign
@export var spawn_points: Array[NodePath] = []  # TODO: assign Marker3D spawn points along the bridge

var _zombies_killed: int = 0
var _coins_earned: int = 0
var _start_time_ms: int = 0
var _level_ended: bool = false

@onready var _player = get_node_or_null(player_path)
@onready var _squad = get_node_or_null(squad_path)
@onready var _hud = get_node_or_null(hud_path)

func _ready() -> void:
	_start_time_ms = Time.get_ticks_msec()

	if _player:
		_player.add_to_group("player")
		_player.died.connect(_on_player_died)
		_player.health_changed.connect(func(cur, max_h): _hud.update_health(cur, max_h) if _hud else null)

	if _squad:
		_squad.squad_size_changed.connect(func(count): _hud.update_squad(count) if _hud else null)

	if _hud:
		_hud.show_intro("برای زنده ماندن بجنگ!", "برای حرکت، انگشت خود را به چپ و راست بکشید.")

	_run_level_flow()

## Coroutine driving Section 1 -> Section 9 per the spec's percentage breakdown.
## Each section is a stub you fill in with actual spawn-point references and
## bridge-progress triggers (e.g. the hero crossing an Area3D checkpoint)
## rather than a fixed timer, for a real build.
func _run_level_flow() -> void:
	# SECTION 2 - first combat: 4 normal zombies
	_spawn_wave(normal_zombie_scene, 4)

	# SECTION 3/4 - first gate + squad introduction handled by MathGate.gd /
	# Squad.gd directly when the hero crosses those Area3D triggers in-scene.

	# SECTION 5 - zombie wave: 8 normal + 3 runner
	await get_tree().create_timer(2.0).timeout
	_spawn_wave(normal_zombie_scene, 8)
	_spawn_wave(runner_zombie_scene, 3)

	# SECTION 6 - strategic gates: handled by MathGate.gd in-scene.

	# SECTION 7 - mini boss
	await get_tree().create_timer(2.0).timeout
	if _hud:
		_hud.show_boss_warning()
	_spawn_wave(brute_zombie_scene, 1)

	# SECTION 8/9 - final approach + final boss are expected to be a
	# hand-placed boss scene ("The Bridge Destroyer") with its own
	# phase-based boss script; connect its `died` signal to _on_boss_defeated.

func _spawn_wave(scene: PackedScene, count: int) -> void:
	if scene == null or spawn_points.is_empty():
		push_warning("GameManager.gd: wave spawn skipped — scene or spawn_points not assigned")
		return

	for i in range(count):
		var point := get_node_or_null(spawn_points[i % spawn_points.size()])
		if point == null:
			continue
		var zombie = scene.instantiate()
		get_tree().current_scene.add_child(zombie)
		zombie.global_position = point.global_position
		if zombie.has_signal("died"):
			zombie.died.connect(_on_zombie_died)

func _on_zombie_died(_zombie: Node3D) -> void:
	_zombies_killed += 1
	_coins_earned += 5  # placeholder coin value per kill
	if _hud:
		_hud.show_kill_notification()

func _on_boss_defeated() -> void:
	_complete_level()

func _on_player_died() -> void:
	if _level_ended:
		return
	_level_ended = true
	level_failed.emit()
	if _hud:
		_hud.show_defeat()

func _complete_level() -> void:
	if _level_ended:
		return
	_level_ended = true

	if _player:
		_player.play_victory()

	var elapsed_seconds: float = (Time.get_ticks_msec() - _start_time_ms) / 1000.0
	var stats := {
		"zombies_killed": _zombies_killed,
		"soldiers_remaining": _squad.get_count() if _squad else 0,
		"coins_earned": _coins_earned,
		"completion_time": elapsed_seconds,
	}

	level_completed.emit(stats)
	if _hud:
		_hud.show_victory(stats)
