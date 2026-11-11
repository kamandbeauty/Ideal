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
const WHIRLWIND := "res://assets/fx/whirlwind.png"

const SPARK_LIFETIME := 0.42
const COIN_LIFETIME := 0.7
const SPLASH_SECONDS := 0.36
const DROP_LIFETIME := 0.34
const DRIP_LIFETIME := 0.72
const WHIRLWIND_SECONDS := 0.62

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

## A fruit bursting into juice: a splat on the tile, droplets thrown off it, and drips that keep falling
## after the splat has gone.
##
## Everything is a painted picture — the splat, the droplet and the offset second splat — tinted with the
## fruit's own colour. Nothing here is a circle the engine drew, because a piece in this game squashes,
## and what sells a squash is the juice underneath it.
static func splash(parent: Node, center: Vector2, tint: Color, diameter: float = 44.0) -> void:
	_splat(parent, center, tint, diameter, 1.0, SPLASH_SECONDS)
	_splat(parent, center, tint.lightened(0.22), diameter * 0.62, 0.0, SPLASH_SECONDS * 0.72)
	_droplets(parent, center, tint, diameter)

	var drips := CPUParticles2D.new()
	drips.name = "drips"
	drips.texture = load(DROP)
	drips.position = center + Vector2(0.0, diameter * 0.16)
	drips.amount = 5
	drips.lifetime = DRIP_LIFETIME
	drips.one_shot = true
	drips.explosiveness = 0.55
	drips.direction = Vector2(0.0, 1.0)
	drips.spread = 40.0
	drips.initial_velocity_min = 10.0
	drips.initial_velocity_max = 40.0
	drips.gravity = Vector2(0.0, 520.0)
	drips.scale_amount_min = 0.30
	drips.scale_amount_max = 0.60
	drips.color = Color(tint.r, tint.g, tint.b, 0.9)
	drips.emitting = true
	parent.add_child(drips)
	drips.finished.connect(drips.queue_free)

static func _splat(parent: Node, center: Vector2, tint: Color, diameter: float, delay: float,
		lifetime: float) -> void:
	var splat := TextureRect.new()
	splat.name = "splash"
	splat.texture = load(SPLATS[randi() % SPLATS.size()])
	splat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splat.stretch_mode = TextureRect.STRETCH_SCALE
	splat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splat.modulate = Color(tint.r, tint.g, tint.b, tint.a * 0.92)
	splat.size = Vector2(diameter, diameter)
	splat.position = center - Vector2(diameter, diameter) * 0.5
	splat.pivot_offset = Vector2(diameter, diameter) * 0.5
	splat.rotation = randf_range(-0.45, 0.45)
	splat.scale = Vector2(0.35, 0.35)
	parent.add_child(splat)
	var tween := splat.create_tween()
	tween.set_parallel(true)
	tween.tween_property(splat, "scale", Vector2(1.22, 1.22), lifetime) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(splat, "modulate", Color(tint.r, tint.g, tint.b, 0.0), lifetime) \
		.set_delay(delay + lifetime * 0.35)
	tween.chain().tween_callback(splat.queue_free)

static func _droplets(parent: Node, center: Vector2, tint: Color, diameter: float) -> void:
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
	drops.initial_velocity_min = 60.0 * diameter / 44.0
	drops.initial_velocity_max = 190.0 * diameter / 44.0
	drops.gravity = Vector2(0.0, 560.0)
	drops.damping_min = 30.0
	drops.damping_max = 80.0
	drops.scale_amount_min = 0.55
	drops.scale_amount_max = 1.25
	drops.color = tint
	drops.emitting = true
	parent.add_child(drops)
	drops.finished.connect(drops.queue_free)

## The fan's whirlwind: the painted tornado spins up over the board and blows itself out.
static func whirlwind(parent: Node, center: Vector2, diameter: float = 96.0,
		tint: Color = Color(1, 1, 1, 0.92)) -> void:
	var swirl := TextureRect.new()
	swirl.name = "whirlwind"
	swirl.texture = load(WHIRLWIND)
	swirl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swirl.stretch_mode = TextureRect.STRETCH_SCALE
	swirl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swirl.modulate = tint
	swirl.size = Vector2(diameter, diameter)
	swirl.position = center - Vector2(diameter, diameter) * 0.5
	swirl.pivot_offset = Vector2(diameter, diameter) * 0.5
	swirl.scale = Vector2(0.35, 0.35)
	parent.add_child(swirl)
	var tween := swirl.create_tween()
	tween.set_parallel(true)
	tween.tween_property(swirl, "scale", Vector2(1.35, 1.35), WHIRLWIND_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(swirl, "rotation", TAU * 1.6, WHIRLWIND_SECONDS)
	tween.tween_property(swirl, "modulate", Color(tint.r, tint.g, tint.b, 0.0), WHIRLWIND_SECONDS) \
		.set_delay(WHIRLWIND_SECONDS * 0.45)
	tween.chain().tween_callback(swirl.queue_free)

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
