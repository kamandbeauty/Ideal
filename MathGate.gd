extends Node3D
## One gate pair (left option + right option). Attach to a parent Node3D
## containing two Area3D children: `LeftGate` and `RightGate`.
##
## Effect types supported: "multiply_squad", "add_squad", "firepower_percent".

signal gate_activated(side: String, effect_type: String, value: float)

@export var left_effect_type: String = "multiply_squad"
@export var left_value: float = 2.0
@export var right_effect_type: String = "add_squad"
@export var right_value: float = 3.0

@export var left_gate_area: NodePath   # TODO: assign LeftGate Area3D
@export var right_gate_area: NodePath  # TODO: assign RightGate Area3D

@export var squad_node_path: NodePath  # TODO: assign the Squad node
@export var player_node_path: NodePath # TODO: assign the Player node (for firepower modifiers)

var _used: bool = false

@onready var _left_area: Area3D = get_node_or_null(left_gate_area)
@onready var _right_area: Area3D = get_node_or_null(right_gate_area)
@onready var _squad = get_node_or_null(squad_node_path)
@onready var _player = get_node_or_null(player_node_path)

func _ready() -> void:
	if _left_area:
		_left_area.body_entered.connect(_on_body_entered.bind("left"))
	if _right_area:
		_right_area.body_entered.connect(_on_body_entered.bind("right"))

func _on_body_entered(body: Node3D, side: String) -> void:
	if _used:
		return
	if not body.is_in_group("player"):
		return

	_used = true
	_apply_gate(side)

func _apply_gate(side: String) -> void:
	var effect_type: String = left_effect_type if side == "left" else right_effect_type
	var value: float = left_value if side == "left" else right_value

	match effect_type:
		"multiply_squad":
			if _squad:
				_squad.multiply_squad(value)
		"add_squad":
			if _squad:
				_squad.recruit(int(value))
		"firepower_percent":
			if _player and _player.has_method("apply_firepower_modifier"):
				_player.apply_firepower_modifier(value)  # e.g. 0.5 for +50%, -0.3 for -30%
		_:
			push_warning("MathGate.gd: unknown effect_type '%s'" % effect_type)

	gate_activated.emit(side, effect_type, value)

	# Lock out the unused gate so only one can ever apply (spec requirement:
	# "Only one gate can be activated in each gate section").
	if _left_area:
		_left_area.set_deferred("monitoring", false)
	if _right_area:
		_right_area.set_deferred("monitoring", false)
