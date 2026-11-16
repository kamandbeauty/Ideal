class_name CartoonPalette
extends RefCounted
## Shared art direction: lime lawns, cool grey roads, orange tiled roofs and
## white, ink-outlined UI. Colours stay neutral-lit, never multiplied by ochre.

const GRASS := Color("#cce34f")
const GRASS_LIGHT := Color("#d5e956")
const LEAF := Color("#88b83e")
const LEAF_DARK := Color("#62953a")
const ASPHALT := Color("#8999a8")
const PARKING := Color("#80919f")
const SIDEWALK := Color("#e9e9eb")
const WHITE := Color("#fffdf8")
const ROOF := Color("#f56b13")
const ROOF_STRIPE := Color("#df550c")
const ROOF_RIDGE := Color("#c84a0a")
const WALL := Color("#afc36c")
const FOUNDATION := Color("#53697c")
const WINDOW := Color("#467c9d")
const WINDOW_GLINT := Color("#97d3e1")
const FRAME := Color("#ffe2ad")
const INK := Color("#29333e")
const ORANGE := Color("#ff9b38")
const BLUE := Color("#139edb")
const BLUE_DARK := Color("#0879ae")
const YELLOW := Color("#ffda35")
const ACTION_GREEN := Color("#65b923")
const POSITIVE_TEXT := Color("#347716")

const WALLS := {
	"gas_station": Color("#b4c66d"),
	"car_wash": Color("#8cbfb5"),
	"auto_service": Color("#d5bf78"),
	"toilets": Color("#9fba57"),
	"diner": Color("#dcc67b"),
	"electric_charger": Color("#8fbd97"),
	"motel": Color("#abc174"),
	"drive_in": Color("#bdca81"),
}


static func wall_color(id: String) -> Color:
	return WALLS.get(id, WALL)
