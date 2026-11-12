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
const DRIP := "res://assets/fx/splash_drip.png"
const STREAK := "res://assets/fx/fx_streak.png"
const WHIRLWIND := "res://assets/fx/whirlwind.png"

const SPARK_LIFETIME := 0.42
const COIN_LIFETIME := 0.7
const SPLASH_SECONDS := 0.44
const DROP_LIFETIME := 0.40
const DRIP_LIFETIME := 0.40
const SPRAY_LIFETIME := 0.26
const STREAK_SECONDS := 0.48
const WHIRLWIND_SECONDS := 0.58

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

## A fruit bursting into juice: a splat on its own tile, a spray of droplets to the left and to the
## right, and three drops that sag under it.
##
## Everything here happens inside the cell the fruit stood on. A splash big enough to reach the
## neighbouring cells reads as paint thrown over the board; a splash bounded by its own square reads as
## one fruit being crushed. `diameter` is that square.
##
## Everything is a painted picture — the splat, the droplet and the offset second splat — tinted with the
## fruit's own colour. Nothing here is a circle the engine drew, because a piece in this game squashes,
## and what sells a squash is the juice underneath it.
static func splash(parent: Node, center: Vector2, tint: Color, diameter: float = 44.0) -> void:
	# Nothing this effect draws may cross the edge of the cell the fruit stood on: the board is a grid of
	# separate fruits, and a splash that runs into the next cell turns a match into a paint fight.
	_splat(parent, center, tint, diameter * 0.92, 1.0, SPLASH_SECONDS)
	_splat(parent, center, tint.lightened(0.22), diameter * 0.56, 0.0, SPLASH_SECONDS * 0.7)
	_spray(parent, center, tint, diameter, -1.0)
	_spray(parent, center, tint, diameter, 1.0)
	_sag(parent, center, tint, diameter)

## The droplets go sideways, not up: a fruit crushed between two others sprays left and right. The
## speeds are chosen against the damping below so a droplet dies about a fifth of a cell from the
## middle of the cell, which keeps the whole spray inside the cell's own square.
static func _spray(parent: Node, center: Vector2, tint: Color, diameter: float, side: float) -> void:
	var spray := CPUParticles2D.new()
	spray.name = "spray_left" if side < 0.0 else "spray_right"
	spray.texture = load(DROP)
	spray.position = center + Vector2(side * diameter * 0.18, 0.0)
	spray.amount = 4
	spray.lifetime = SPRAY_LIFETIME
	spray.one_shot = true
	spray.explosiveness = 0.85
	spray.direction = Vector2(side, 0.0)
	spray.spread = 24.0
	spray.initial_velocity_min = diameter * 0.45
	spray.initial_velocity_max = diameter * 1.15
	spray.damping_min = diameter * 4.0
	spray.damping_max = diameter * 5.5
	spray.gravity = Vector2.ZERO
	spray.scale_amount_min = 0.16
	spray.scale_amount_max = 0.30
	spray.color = Color(tint.r, tint.g, tint.b, 0.95)
	spray.emitting = true
	parent.add_child(spray)
	spray.finished.connect(spray.queue_free)

## Three small drops that sag downwards under the fruit and stop inside the cell: the juice that does
## not fly sideways still runs, so the burst keeps its weight without staining the neighbouring cells.
static func _sag(parent: Node, center: Vector2, tint: Color, diameter: float) -> void:
	var drip := CPUParticles2D.new()
	drip.name = "sag"
	drip.texture = load(DRIP)
	drip.position = center + Vector2(0.0, diameter * 0.10)
	drip.amount = 3
	drip.lifetime = DRIP_LIFETIME
	drip.one_shot = true
	drip.explosiveness = 0.5
	drip.direction = Vector2(0.0, 1.0)
	drip.spread = 30.0
	drip.initial_velocity_min = diameter * 0.10
	drip.initial_velocity_max = diameter * 0.34
	drip.gravity = Vector2(0.0, diameter * 2.2)
	drip.damping_min = diameter * 3.0
	drip.damping_max = diameter * 4.0
	drip.scale_amount_min = 0.18
	drip.scale_amount_max = 0.30
	drip.color = Color(tint.r, tint.g, tint.b, 0.92)
	drip.emitting = true
	parent.add_child(drip)
	drip.finished.connect(drip.queue_free)

static func _splat(parent: Node, center: Vector2, tint: Color, diameter: float, delay: float,
		lifetime: float) -> void:
	var splat := TextureRect.new()
	splat.name = "splash"
	splat.texture = load(SPLATS[randi() % SPLATS.size()])
	splat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splat.stretch_mode = TextureRect.STRETCH_SCALE
	splat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splat.modulate = Color(tint.r, tint.g, tint.b, tint.a * 0.92)
	# The node is laid out at the picture's own size and scaled to the cell: a TextureRect's rect is
	# clamped to its texture, so asking for a 44 dp rect gave a 512 px one and the splat came out three
	# cells wide.
	var native := float(splat.texture.get_width())
	splat.size = Vector2(native, native)
	splat.pivot_offset = Vector2(native, native) * 0.5
	splat.position = center - Vector2(native, native) * 0.5
	splat.rotation = randf_range(-0.45, 0.45)
	var full := diameter / native
	splat.scale = Vector2(full * 0.55, full * 0.55)
	parent.add_child(splat)
	var tween := splat.create_tween()
	tween.set_parallel(true)
	tween.tween_property(splat, "scale", Vector2(full, full), lifetime) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(splat, "modulate", Color(tint.r, tint.g, tint.b, 0.0), lifetime) \
		.set_delay(delay + lifetime * 0.35)
	tween.chain().tween_callback(splat.queue_free)

## The rocket's beam: a light bar laid along the row or column it is about to clear, opening from the
## cell the rocket fired from outwards. `horizontal` is the axis of the clear.
static func streak(parent: Node, center: Vector2, length: float, horizontal: bool,
		tint: Color = Color(1, 1, 1, 0.85)) -> void:
	var bar := TextureRect.new()
	bar.name = "streak"
	bar.texture = load(STREAK)
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	var native := Vector2(bar.texture.get_width(), bar.texture.get_height())
	bar.size = native
	bar.pivot_offset = native * 0.5
	bar.position = center - native * 0.5
	bar.scale = Vector2(length / native.x, maxf(0.35, length * 0.10) / native.y)
	if not horizontal:
		bar.rotation = PI * 0.5
	parent.add_child(bar)
	var tween := bar.create_tween()
	tween.set_parallel(true)
	tween.tween_property(bar, "modulate:a", tint.a, STREAK_SECONDS * 0.25)
	tween.tween_property(bar, "modulate:a", 0.0, STREAK_SECONDS * 0.75) \
		.set_delay(STREAK_SECONDS * 0.25)
	var wide := Vector2(1.0, 1.7) if horizontal else Vector2(1.7, 1.0)
	tween.tween_property(bar, "scale", bar.scale * wide, STREAK_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(bar.queue_free)


## The fan's gust: the painted whirlwind laid flat on the grid and blown straight across it.
##
## It does **not** spin. A tornado turning on the spot is a weather event happening somewhere else;
## what the player has to read is "this wind crosses the board and takes the fruit of one colour with
## it", so the picture is squashed to half its height — it lies on the grid instead of
## standing on it — and it travels in a straight line from the piece that fired it along the way the
## fruit it is about to take lies. `from` is the centre of the cell that fired, `travel` the straight
## line it covers; the sprite is mirrored, never turned, when it blows the other way.
const WHIRLWIND_FLATTEN := 0.50

static func whirlwind(parent: Node, from: Vector2, travel: Vector2, diameter: float = 96.0,
		tint: Color = Color(1, 1, 1, 0.92)) -> void:
	var gust := TextureRect.new()
	gust.name = "whirlwind"
	gust.texture = load(WHIRLWIND)
	gust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gust.stretch_mode = TextureRect.STRETCH_SCALE
	gust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gust.modulate = tint
	var native := float(gust.texture.get_width())
	gust.size = Vector2(native, native)
	gust.pivot_offset = Vector2(native, native) * 0.5
	var full := diameter / native
	var flat := Vector2(full, full * WHIRLWIND_FLATTEN)
	gust.flip_h = travel.x < 0.0
	var home := from - Vector2(native, native) * 0.5
	gust.position = home
	gust.scale = Vector2(flat.x, flat.y) * 0.55
	parent.add_child(gust)
	var tween := gust.create_tween()
	tween.set_parallel(true)
	# One straight line, no rotation: the whole action is the crossing.
	tween.tween_property(gust, "position", home + travel, WHIRLWIND_SECONDS * 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(gust, "scale", flat, WHIRLWIND_SECONDS * 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(gust, "modulate", Color(tint.r, tint.g, tint.b, 0.0),
		WHIRLWIND_SECONDS * 0.45).set_delay(WHIRLWIND_SECONDS * 0.55)
	tween.chain().tween_callback(gust.queue_free)

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
