class_name Fx
extends RefCounted
## The visual feedback layer: sparks when a piece clears, a coin burst when a reward lands, a ring for
## a power-up. All of it is built from the art the Unity project shipped — `fx_spark`, `fx_coins`,
## `fx_ring` — which until now was imported and unused.
##
## Every effect frees itself, so a long cascade cannot leak nodes, and every effect is parented to the
## thing that owns the position, so it scrolls/moves with it.

const SPARK := "res://assets/art/fx_spark.png"
const COINS := "res://assets/art/fx_coins.png"
const RING := "res://assets/art/fx_ring.png"

const SPARK_LIFETIME := 0.42
const COIN_LIFETIME := 0.7

## A short burst of sparks at a board cell.
static func spark(parent: Node, center: Vector2, tint: Color, amount: int = 10, scale: float = 1.0) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "spark"
	particles.texture = load(SPARK)
	particles.position = center
	particles.amount = maxi(amount, 1)
	particles.lifetime = SPARK_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0 * scale
	particles.initial_velocity_max = 170.0 * scale
	particles.gravity = Vector2(0.0, 340.0)
	particles.damping_min = 20.0
	particles.damping_max = 60.0
	particles.scale_amount_min = 0.25
	particles.scale_amount_max = 0.65
	particles.color = tint
	particles.emitting = true
	parent.add_child(particles)
	particles.finished.connect(particles.queue_free)

## Coins flying up and fading: the reward moment of a first clear.
static func coin_burst(parent: Node, center: Vector2, amount: int = 14) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "coins"
	particles.texture = load(COINS)
	particles.position = center
	particles.amount = maxi(amount, 1)
	particles.lifetime = COIN_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 55.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 220.0
	particles.gravity = Vector2(0.0, 220.0)
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 0.9
	particles.emitting = true
	parent.add_child(particles)
	particles.finished.connect(particles.queue_free)

## An expanding ring: reads as "this thing just fired".
static func ring(parent: Node, center: Vector2, diameter: float, tint: Color = Color(1, 1, 1, 1)) -> void:
	var sprite := TextureRect.new()
	sprite.name = "ring"
	sprite.texture = load(RING)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.modulate = tint
	parent.add_child(sprite)
	var start := diameter * 0.35
	sprite.size = Vector2(start, start)
	sprite.position = center - Vector2(start, start) * 0.5
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "size", Vector2(diameter, diameter), 0.28)
	tween.tween_property(sprite, "position", center - Vector2(diameter, diameter) * 0.5, 0.28)
	tween.tween_property(sprite, "modulate", Color(tint.r, tint.g, tint.b, 0.0), 0.28)
	tween.chain().tween_callback(sprite.queue_free)

## The colour a piece bursts in when it clears — the same palette the tile art uses.
static func piece_tint(kind: int) -> Color:
	match kind:
		GameTypes.PieceKind.FIROUZEH: return UiTokens.PIECE_FIROUZEH
		GameTypes.PieceKind.LAJVARD: return UiTokens.PIECE_LAJVARD
		GameTypes.PieceKind.AQIQ: return UiTokens.PIECE_AQIQ
		GameTypes.PieceKind.ZOMORROD: return UiTokens.PIECE_ZOMORROD
		GameTypes.PieceKind.MORVARID: return UiTokens.PIECE_MORVARID
		_: return UiTokens.TEXT
