class_name UiScreen
extends Control
## One full-screen view, ported from client/Assets/Game/Ui/UiScreen.cs.
##
## A screen builds its widgets once and afterwards only refreshes numbers. Screens never navigate:
## they expose signals and AppRoot decides what a press means, which keeps the dependency arrow
## one-way — AppRoot knows every screen, a screen knows none.

var session: GameSession
var built := false

## Full-window art and wash for this screen. Screens declare them instead of drawing them, because on
## a 20:9 phone the picture has to cover more than the 415x738 design space — AppRoot owns the layer
## that fills whatever the device actually is, and the screens own only their content.
var backdrop_art := ""
var wash_color := Color(0, 0, 0, 0)

func set_backdrop(art_id: String, wash_alpha: float) -> void:
	backdrop_art = art_id
	wash_color = Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b, wash_alpha)

func init_screen(new_session: GameSession) -> void:
	session = new_session
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not built:
		build()
		built = true
	refresh()

## Creates the widgets. Called once.
func build() -> void:
	pass

## Updates the widgets from the session. Called whenever anything changed.
func refresh() -> void:
	pass

func set_visible_screen(visible_now: bool) -> void:
	if visible != visible_now:
		visible = visible_now
