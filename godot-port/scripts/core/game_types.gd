class_name GameTypes
extends RefCounted

# Numeric values intentionally match the Unity core. Do not reorder.
enum PieceKind {
	NONE = 0,
	FIROUZEH = 1,
	LAJVARD = 2,
	AQIQ = 3,
	ZOMORROD = 4,
	MORVARID = 5
}

enum PowerUpKind {
	NONE = 0,
	ROCKET_VERTICAL = 1,
	ROCKET_HORIZONTAL = 2,
	SPINNER = 3,
	DYNAMITE = 4,
	ELECTRO_BALL = 5,
	SUPER_ELECTRO_BALL = 6
}

enum ObstacleKind {
	NONE = 0,
	CRATE = 1,
	FROST = 2,
	IVY = 3,
	VIAL = 4,
	SAMOVAR = 5,
	FLOWER_POT = 6,
	CHAIN = 7,
	SEAL = 8
}

enum GoalKind { CLEAR_PIECES = 0, CLEAR_OBSTACLE = 1 }
enum GravityDirection { DOWN = 0, UP = 1 }
enum LevelStatus { PLAYING = 0, WON = 1, LOST = 2 }
enum BoosterKind { MALLET = 0, RAM = 1, AUGER = 2, WHIRLWIND = 3, FALCON = 4 }

enum MoveKind { REJECTED = 0, SWAP = 1, BOOSTER = 2 }
