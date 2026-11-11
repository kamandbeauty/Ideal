class_name UiTokens
extends RefCounted
## The design tokens, ported one-to-one from client/Assets/Game/Generated/Tokens.gen.cs.
##
## Nothing in the port may invent a colour or a size: if a value is needed it goes here first, so a
## reviewer can diff this file against the C# one and see that they agree. The design space is
## 738 x 415 dp with y growing downwards: the game is landscape, so the long side is the width.

# ---- colour -------------------------------------------------------------------------------------

# The palette is the royal garden one: royal blue for structure, gold for every edge, turquoise for the
# second line a Persian frame always carries, warm ivory for the face a player reads on, and one bright
# colour per fruit. Nothing here is brown or grey — a warm shadow under a warm plate is the one thing
# that turns cartoon chrome into a photograph of brass.
const BG := Color(0.0275, 0.2353, 0.4706, 1.0)              # #073C78  deep blue
const SURFACE := Color(1.0, 0.9451, 0.8314, 1.0)            # #FFF1D4  warm ivory
const SURFACE_RAISED := Color(1.0, 0.9765, 0.9176, 1.0)     # #FFF9EA
const BORDER := Color(0.9608, 0.7451, 0.2627, 1.0)          # #F5BE43  gold
const BORDER_INPUT := Color(0.7216, 0.5176, 0.1647, 1.0)    # #B8842A
const TEXT := Color(0.0706, 0.2235, 0.3882, 1.0)            # #123963  deep blue ink
const TEXT_MUTED := Color(0.2902, 0.4314, 0.5882, 1.0)      # #4A6E96
# The board's two side rails are painted ivory, so the ink on them is deep blue rather than the light
# text the dark plates use: light text on ivory is invisible.
const INK := Color(0.0706, 0.2235, 0.3882, 1.0)             # #123963
const INK_SOFT := Color(0.2902, 0.4314, 0.5882, 1.0)        # #4A6E96
const ACCENT := Color(0.1255, 0.7765, 0.7686, 1.0)          # #20C6C4  turquoise
const ACCENT_STRONG := Color(0.0549, 0.5569, 0.5529, 1.0)   # #0E8E8D
const ON_ACCENT := Color(0.0157, 0.1882, 0.1843, 1.0)       # #04302F
const GOLD := Color(0.9608, 0.7451, 0.2627, 1.0)            # #F5BE43
const ON_GOLD := Color(0.2902, 0.1804, 0.0, 1.0)            # #4A2E00
const DANGER := Color(0.9529, 0.3020, 0.3216, 1.0)          # #F34D52  coral red
const ON_DANGER := Color(1.0, 0.9765, 0.9608, 1.0)          # #FFF9F5
const SUCCESS := Color(0.3333, 0.7255, 0.3412, 1.0)         # #55B957  garden green
const WARNING := Color(0.9608, 0.7451, 0.2627, 1.0)         # #F5BE43
const DANGER_STRONG := Color(0.7137, 0.1725, 0.1922, 1.0)   # #B62C31

# Structure colours: the royal blue the plates are graded from, and the sky the backdrops are painted
# under. They exist as tokens so a screen never writes a hex value of its own.
const ROYAL := Color(0.0706, 0.3882, 0.7098, 1.0)           # #1263B5
const DEEP := Color(0.0275, 0.2353, 0.4706, 1.0)            # #073C78
const TURQUOISE := Color(0.1255, 0.7765, 0.7686, 1.0)       # #20C6C4
const SKY := Color(0.4000, 0.7882, 0.9608, 1.0)             # #66C9F5
const GARDEN := Color(0.3333, 0.7255, 0.3412, 1.0)          # #55B957
const CORAL := Color(0.9529, 0.3020, 0.3216, 1.0)           # #F34D52
const PURPLE := Color(0.5686, 0.2314, 0.8078, 1.0)          # #913BCE
const IVORY := Color(1.0, 0.9451, 0.8314, 1.0)              # #FFF1D4

# Text flavours of the accents. GOLD, SUCCESS and DANGER are *plate* colours: they carry their meaning
# as a button face, and on the ivory ground they are far too pale to write with. Anything that puts an
# accent straight on a panel or a chip writes in these instead.
const GOLD_TEXT := Color(0.6353, 0.4157, 0.0549, 1.0)       # #A26A0E
const SUCCESS_TEXT := Color(0.1216, 0.4784, 0.2039, 1.0)    # #1F7A34
const DANGER_TEXT := Color(0.7529, 0.1882, 0.2039, 1.0)     # #C03034
const SHADOW := Color(0.0275, 0.1569, 0.2980, 0.30)
const TRANSPARENT := Color(1.0, 1.0, 1.0, 0.0)

const PIECE_FIROUZEH := Color(0.4980, 0.7490, 0.2471, 1.0)  # #7FBF3F  pear
const PIECE_LAJVARD := Color(0.5686, 0.2314, 0.8078, 1.0)   # #913BCE  grapes
const PIECE_AQIQ := Color(0.9412, 0.4471, 0.3059, 1.0)      # #F0724E  peach
const PIECE_ZOMORROD := Color(0.2431, 0.6196, 0.3098, 1.0)  # #3E9E4F  watermelon
const PIECE_MORVARID := Color(0.9490, 0.8314, 0.3608, 1.0)  # #F2D45C  lemon
const PIECE_ANANAS := Color(0.9490, 0.6980, 0.1098, 1.0)    # #F2B21C
const PIECE_PORTEQAL := Color(0.9490, 0.4745, 0.1686, 1.0)  # #F2792B
const PIECE_MOZ := Color(0.9608, 0.8353, 0.2784, 1.0)       # #F5D547

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
