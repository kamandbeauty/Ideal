class_name AssetCatalog
extends RefCounted

## The five stones are drawn twice: the Unity project's sprites ship untouched in `assets/art` (the
## port contract keeps all 85 of them byte-identical), and `assets/gems` holds the re-cut versions
## that the board actually draws. The re-cut art is a picture like any other — it is generated once by
## `tools/make_gem_art.py` and never drawn at runtime — and it is what makes a gem read as a stone at
## 36 dp instead of as a coloured polygon. The fallback keeps the port working from the Unity art
## alone if the gems folder is ever removed.
const GEM_DIR := "res://assets/gems/"

static func piece_name(kind: int) -> String:
	match kind:
		GameTypes.PieceKind.FIROUZEH: return "firouzeh"
		GameTypes.PieceKind.LAJVARD: return "lajvard"
		GameTypes.PieceKind.AQIQ: return "aqiq"
		GameTypes.PieceKind.ZOMORROD: return "zomorrod"
		GameTypes.PieceKind.MORVARID: return "morvarid"
		_: return ""

static func piece_path(kind: int) -> String:
	var name := piece_name(kind)
	if name.is_empty():
		return ""
	var gem := GEM_DIR + "piece_%s.png" % name
	if ResourceLoader.exists(gem):
		return gem
	return "res://assets/art/piece_%s.png" % name

## The three power-ups the board draws, from `assets/powerups/` — a rocket, a hand fan and a kite.
##
## The Unity plates (`assets/art/powerup_*.png`) still ship untouched; the port simply draws its own
## pictures now. Six kinds of special piece share three pictures because the player only ever needs to
## tell three things apart: "clears a line", "clears around here", "flies off and takes things with it".
static func power_up_path(kind: int) -> String:
	match kind:
		GameTypes.PowerUpKind.ROCKET_VERTICAL: return "res://assets/powerups/rocket.png"
		GameTypes.PowerUpKind.ROCKET_HORIZONTAL: return "res://assets/powerups/rocket.png"
		GameTypes.PowerUpKind.SPINNER: return "res://assets/powerups/fan.png"
		GameTypes.PowerUpKind.DYNAMITE: return "res://assets/powerups/fan.png"
		GameTypes.PowerUpKind.ELECTRO_BALL: return "res://assets/powerups/kite.png"
		GameTypes.PowerUpKind.SUPER_ELECTRO_BALL: return "res://assets/powerups/kite.png"
		_: return ""

static func obstacle_path(kind: int) -> String:
	match kind:
		GameTypes.ObstacleKind.CRATE: return "res://assets/art/obstacle_crate.png"
		GameTypes.ObstacleKind.FROST: return "res://assets/art/obstacle_frost.png"
		GameTypes.ObstacleKind.IVY: return "res://assets/art/obstacle_ivy.png"
		GameTypes.ObstacleKind.VIAL: return "res://assets/art/obstacle_vial.png"
		GameTypes.ObstacleKind.SAMOVAR: return "res://assets/art/obstacle_samovar.png"
		GameTypes.ObstacleKind.FLOWER_POT: return "res://assets/art/obstacle_flowerpot.png"
		GameTypes.ObstacleKind.CHAIN: return "res://assets/art/obstacle_chain.png"
		GameTypes.ObstacleKind.SEAL: return "res://assets/art/obstacle_seal.png"
		_: return ""

static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("[art] missing " + path)
		return null
	var loaded := load(path) as Texture2D
	if loaded == null:
		push_warning("[art] missing " + path)
	return loaded

static func piece_texture(kind: int) -> Texture2D:
	return texture(piece_path(kind))

static func power_up_texture(kind: int) -> Texture2D:
	return texture(power_up_path(kind))

static func obstacle_texture(kind: int) -> Texture2D:
	return texture(obstacle_path(kind))
