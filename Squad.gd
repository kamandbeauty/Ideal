extends Node3D
## Manages recruited soldiers following the hero.
## Attach to a Node3D that is a sibling/child of the hero.

signal squad_size_changed(count: int)

@export var soldier_scene: PackedScene   # TODO: assign your soldier .tscn
@export var hero_path: NodePath          # TODO: assign the Player node
@export var max_soldiers: int = 10
@export var formation_spacing: float = 1.2
@export var follow_speed: float = 8.0
@export var attack_range: float = 15.0
@export var fire_rate: float = 4.0

var _soldiers: Array[Node3D] = []
@onready var _hero: Node3D = get_node_or_null(hero_path)

func _physics_process(delta: float) -> void:
	_update_formation(delta)
	for s in _soldiers:
		if is_instance_valid(s):
			_soldier_attack_tick(s, delta)

## Add `count` soldiers, clamped to max_soldiers. Returns the number actually added.
func recruit(count: int) -> int:
	var available_slots: int = max_soldiers - _soldiers.size()
	var to_add: int = clamp(count, 0, available_slots)

	for i in range(to_add):
		if soldier_scene == null:
			push_warning("Squad.gd: soldier_scene not assigned")
			break
		var soldier := soldier_scene.instantiate()
		get_tree().current_scene.add_child(soldier)
		soldier.add_to_group("squad")
		if soldier.has_signal("died"):
			soldier.died.connect(_on_soldier_died.bind(soldier))
		_soldiers.append(soldier)

	squad_size_changed.emit(_soldiers.size())
	return to_add

## Multiply current soldier count (used by ×2 gates). Spawns extra soldiers to match.
func multiply_squad(factor: float) -> void:
	var target_count: int = clamp(int(round(_soldiers.size() * factor)), 0, max_soldiers)
	var diff: int = target_count - _soldiers.size()
	if diff > 0:
		recruit(diff)
	# Note: the spec does not call for removing soldiers on a down-multiplier gate
	# in Level 1 (only firepower has a negative gate) — adjust here if needed.

func get_count() -> int:
	return _soldiers.size()

func _update_formation(delta: float) -> void:
	if _hero == null:
		return

	var count: int = _soldiers.size()
	for i in range(count):
		var soldier: Node3D = _soldiers[i]
		if not is_instance_valid(soldier):
			continue

		var row: int = i / 4          # 4 soldiers per row behind the hero
		var col: int = i % 4 - 1       # center the row around the hero's X
		var target_pos: Vector3 = _hero.global_position \
			+ Vector3(col * formation_spacing, 0.0, (row + 1) * formation_spacing * 1.5)

		soldier.global_position = soldier.global_position.move_toward(target_pos, follow_speed * delta)

func _soldier_attack_tick(soldier: Node3D, _delta: float) -> void:
	# TODO: replace with soldier's own weapon/cooldown state if stored on the soldier scene.
	var enemies := get_tree().get_nodes_in_group("zombies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if soldier.global_position.distance_to(enemy.global_position) <= attack_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(6.0 * _delta * fire_rate)  # placeholder DPS model
			break

func _on_soldier_died(soldier: Node3D) -> void:
	_soldiers.erase(soldier)
	squad_size_changed.emit(_soldiers.size())
