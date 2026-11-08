class_name AssetCatalog
extends RefCounted

static func piece_path(kind: int) -> String:
	match kind:
		GameTypes.PieceKind.FIROUZEH: return "res://assets/art/piece_firouzeh.png"
		GameTypes.PieceKind.LAJVARD: return "res://assets/art/piece_lajvard.png"
		GameTypes.PieceKind.AQIQ: return "res://assets/art/piece_aqiq.png"
		GameTypes.PieceKind.ZOMORROD: return "res://assets/art/piece_zomorrod.png"
		GameTypes.PieceKind.MORVARID: return "res://assets/art/piece_morvarid.png"
		_: return ""

static func power_up_path(kind: int) -> String:
	match kind:
		GameTypes.PowerUpKind.ROCKET_VERTICAL: return "res://assets/art/powerup_rocket_col.png"
		GameTypes.PowerUpKind.ROCKET_HORIZONTAL: return "res://assets/art/powerup_rocket_row.png"
		GameTypes.PowerUpKind.SPINNER: return "res://assets/art/powerup_spinner.png"
		GameTypes.PowerUpKind.DYNAMITE: return "res://assets/art/powerup_dynamite.png"
		GameTypes.PowerUpKind.ELECTRO_BALL: return "res://assets/art/powerup_electro.png"
		GameTypes.PowerUpKind.SUPER_ELECTRO_BALL: return "res://assets/art/powerup_electro_super.png"
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
