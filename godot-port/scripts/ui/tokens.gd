class_name UiTokens
extends RefCounted
## The design tokens, ported one-to-one from client/Assets/Game/Generated/Tokens.gen.cs.
##
## Nothing in the port may invent a colour or a size: if a value is needed it goes here first, so a
## reviewer can diff this file against the C# one and see that they agree. The design space is
## 738 x 415 dp with y growing downwards: the game is landscape, so the long side is the width.

# ---- colour -------------------------------------------------------------------------------------

# The game is painted now: cream parchment, amber rims and warm shadows, with ink for text. The
# palette changed in one place and every screen followed, because a screen only ever names a token.
const BG := Color(0.1412, 0.1020, 0.0706, 1.0)              # #241A12
const SURFACE := Color(0.9647, 0.9059, 0.7843, 1.0)         # #F6E7C8
const SURFACE_RAISED := Color(0.9882, 0.9490, 0.8588, 1.0)  # #FCF2DB
const BORDER := Color(0.7843, 0.6039, 0.3216, 1.0)          # #C89A52
const BORDER_INPUT := Color(0.6588, 0.4980, 0.2706, 1.0)    # #A87F45
const TEXT := Color(0.2314, 0.1647, 0.0941, 1.0)            # #3B2A18
const TEXT_MUTED := Color(0.4784, 0.3725, 0.2392, 1.0)      # #7A5F3D
# The board's two side rails are painted cream parchment, not a dark plate, so the ink on them is dark
# and warm rather than the light text the rest of the game uses: light text on cream is invisible.
const INK := Color(0.2784, 0.1922, 0.1059, 1.0)             # #47311B
const INK_SOFT := Color(0.4784, 0.3725, 0.2392, 1.0)        # #7A5F3D
const ACCENT := Color(0.1373, 0.7098, 0.6902, 1.0)          # #23B5B0
const ACCENT_STRONG := Color(0.0706, 0.5216, 0.4980, 1.0)   # #12857F
const ON_ACCENT := Color(0.0157, 0.1294, 0.1216, 1.0)       # #04211F
const GOLD := Color(0.8784, 0.6627, 0.2471, 1.0)            # #E0A93F
const ON_GOLD := Color(0.1647, 0.1059, 0.0078, 1.0)         # #2A1B02
const DANGER := Color(0.9412, 0.4510, 0.3529, 1.0)          # #F0735A
const ON_DANGER := Color(1.0, 0.9647, 0.9529, 1.0)          # #FFF6F3
const SUCCESS := Color(0.3451, 0.7882, 0.5412, 1.0)         # #58C98A
const WARNING := Color(0.9412, 0.7059, 0.1608, 1.0)         # #F0B429
const DANGER_STRONG := Color(0.7020, 0.2275, 0.1412, 1.0)   # #B33A24
const SHADOW := Color(0.1294, 0.0863, 0.0471, 0.30)
const TRANSPARENT := Color(1.0, 1.0, 1.0, 0.0)

const PIECE_FIROUZEH := Color(0.1804, 0.7686, 0.7137, 1.0)  # #2EC4B6
const PIECE_LAJVARD := Color(0.1843, 0.3725, 0.8157, 1.0)   # #2F5FD0
const PIECE_AQIQ := Color(0.8235, 0.3333, 0.2471, 1.0)      # #D2553F
const PIECE_ZOMORROD := Color(0.1804, 0.6196, 0.3569, 1.0)  # #2E9E5B
const PIECE_MORVARID := Color(0.9373, 0.8902, 0.7843, 1.0)  # #EFE3C8

# ---- type scale (px = dp) -----------------------------------------------------------------------

const TYPE_XS := 12
const TYPE_SM := 14
const TYPE_BASE := 16
const TYPE_LG := 20
const TYPE_XL := 26
const TYPE_DISPLAY := 34

const HUD_CURRENCY := 18
const HUD_COUNTER := 34
const HUD_GOAL_LABEL := 13
const HUD_BUTTON_LABEL := 17
const HUD_TOUCH_TARGET := 48.0
const HUD_SAFE_TOP := 44.0
const HUD_SAFE_BOTTOM := 34.0
const HUD_SAFE_SIDE := 16.0

# ---- spacing ------------------------------------------------------------------------------------

const S0 := 0.0
const S1 := 4.0
const S2 := 8.0
const S3 := 12.0
const S4 := 16.0
const S5 := 24.0
const S6 := 32.0
const S7 := 48.0
const S8 := 64.0

# ---- radii --------------------------------------------------------------------------------------

const RADIUS_SM := 8
const RADIUS_MD := 14
const RADIUS_LG := 22
const RADIUS_PANEL := 28
const RADIUS_PILL := 999

# ---- motion (seconds) ---------------------------------------------------------------------------

const MOTION_FAST := 0.120
const MOTION_BASE := 0.200
const MOTION_POP := 0.240
const MOTION_SWAP := 0.140
const MOTION_FALL := 0.220
const MOTION_REWARD := 0.600
const MOTION_SCREEN := 0.280

# ---- design space -------------------------------------------------------------------------------

const CANVAS_WIDTH := 738.0
const CANVAS_HEIGHT := 415.0

# ---- nine-slice borders shipped with the art ----------------------------------------------------
# client/Assets/Game/ArtLibrary.cs uses these borders; a panel drawn with the wrong border looks
# stretched, so they live next to the token values rather than inside the screens.

const BORDER_BUTTON := 18
const BORDER_PANEL := 22
const BORDER_CARD := 28
const BORDER_PILL := 24

# ---- nine-slice borders of the UI plates in assets/ui/ ------------------------------------------
# These are pictures, not rectangles: tools/make_ui_art.py bakes them, UiKit nine-slices them.

const BORDER_PLATE := 20
## Button's minimum height is twice the border plus the text, so a small plate has to be cut thin:
## at 12 the smallest chip was 44 dp tall inside a 30 dp row and the rows collided.
const BORDER_PLATE_SMALL := 6
## Below this height a plate takes the `_sm` picture, because a nine-slice cannot shrink past its own
## margins — the sum of a 20 dp border on two sides is 40.
# 56, not 40: the large plate is a 96 px panel whose 20 px nine-slice leaves a raised inner face, and
# on a 46-52 px button that face reads as a second frame inside the first. Every control up to 56 dp
# takes the 48 px plate and its 6 px slice instead.
const PLATE_SMALL_MAX := 56.0
const BORDER_PANEL_ART := 24
const BORDER_BUTTON_ART := 20
const BORDER_PILL_ART := 22
