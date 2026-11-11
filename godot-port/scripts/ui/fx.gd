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

# The splash set is drawn by tools/make_fx_art.py: three splat variants and a droplet, white with an
# alpha channel, tinted per fruit here. Three files cover five colours because the colour is the tint.
const SPLATS := [
	"res://assets/fx/splash_1.png",
	"res://assets/fx/splash_2.png",
	"res://assets/fx/splash_3.png",
]
const DROP := "res://assets/fx/splash_drop.png"

const SPARK_LIFETIME := 0.42
const COIN_LIFETIME := 0.7
const SPLASH_SECONDS := 0.36
const DROP_LIFETIME := 0.34

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

## A fruit bursting into juice: the splat that lands on the tile, and the droplets thrown off it.
##
## The splat is a picture that pops to full size and fades — never a circle the engine drew — because a
## cleared piece in this game squashes, and the thing that sells the squash is the splat underneath it.
static func splash(parent: Node, center: Vector2, tint: Color, diameter: float = 44.0) -> void:
	var splat := TextureRect.new()
	splat.name = "splash"
	splat.texture = load(SPLATS[randi() % SPLATS.size()])
	splat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splat.stretch_mode = TextureRect.STRETCH_SCALE
	splat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splat.modulate = tint
	splat.size = Vector2(diameter, diameter)
	splat.position = center - Vector2(diameter, diameter) * 0.5
	splat.pivot_offset = Vector2(diameter, diameter) * 0.5
	splat.rotation = randf_range(-0.45, 0.45)
	splat.scale = Vector2(0.45, 0.45)
	parent.add_child(splat)
	var tween := splat.create_tween()
	tween.set_parallel(true)
	tween.tween_property(splat, "scale", Vector2(1.2, 1.2), SPLASH_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(splat, "modulate", Color(tint.r, tint.g, tint.b, 0.0), SPLASH_SECONDS) \
		.set_delay(SPLASH_SECONDS * 0.35)
	tween.chain().tween_callback(splat.queue_free)

	var drops := CPUParticles2D.new()
	drops.name = "drops"
	drops.texture = load(DROP)
	drops.position = center
	drops.amount = 7
	drops.lifetime = DROP_LIFETIME
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.direction = Vector2(0.0, -1.0)
	drops.spread = 180.0
	drops.initial_velocity_min = 50.0
	drops.initial_velocity_max = 150.0
	drops.gravity = Vector2(0.0, 420.0)
	drops.damping_min = 40.0
	drops.damping_max = 90.0
	drops.scale_amount_min = 0.6
	drops.scale_amount_max = 1.3
	drops.color = tint
	drops.emitting = true
	parent.add_child(drops)
	drops.finished.connect(drops.queue_free)

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

## The colour a piece bursts in when it clears: the juice of the fruit, sampled off its painting.
static func piece_tint(kind: int) -> Color:
	match kind:
		GameTypes.PieceKind.FIROUZEH: return UiTokens.PIECE_FIROUZEH
		GameTypes.PieceKind.LAJVARD: return UiTokens.PIECE_LAJVARD
		GameTypes.PieceKind.AQIQ: return UiTokens.PIECE_AQIQ
		GameTypes.PieceKind.ZOMORROD: return UiTokens.PIECE_ZOMORROD
		GameTypes.PieceKind.MORVARID: return UiTokens.PIECE_MORVARID
		GameTypes.PieceKind.ANANAS: return UiTokens.PIECE_ANANAS
		GameTypes.PieceKind.PORTEQAL: return UiTokens.PIECE_PORTEQAL
		GameTypes.PieceKind.MOZ: return UiTokens.PIECE_MOZ
		_: return UiTokens.TEXT
