class_name UiTokens
extends RefCounted
## The design tokens, ported one-to-one from client/Assets/Game/Generated/Tokens.gen.cs.
##
## Nothing in the port may invent a colour or a size: if a value is needed it goes here first, so a
## reviewer can diff this file against the C# one and see that they agree. The design space is
## 415 x 738 dp with y growing downwards, exactly like the design document.

# ---- colour -------------------------------------------------------------------------------------

const BG := Color(0.0431, 0.1020, 0.1843, 1.0)              # #0B1A2F
const SURFACE := Color(0.0784, 0.1608, 0.2902, 1.0)         # #14294A
const SURFACE_RAISED := Color(0.1137, 0.2275, 0.3804, 1.0)  # #1D3A61
const BORDER := Color(0.1725, 0.3059, 0.4706, 1.0)          # #2C4E78
const BORDER_INPUT := Color(0.3529, 0.5137, 0.6941, 1.0)    # #5A83B1
const TEXT := Color(0.9686, 0.9490, 0.9020, 1.0)            # #F7F2E6
const TEXT_MUTED := Color(0.7490, 0.7961, 0.8588, 1.0)      # #BFCBDB
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
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
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

const CANVAS_WIDTH := 415.0
const CANVAS_HEIGHT := 738.0

# ---- nine-slice borders shipped with the art ----------------------------------------------------
# client/Assets/Game/ArtLibrary.cs uses these borders; a panel drawn with the wrong border looks
# stretched, so they live next to the token values rather than inside the screens.

const BORDER_BUTTON := 18
const BORDER_PANEL := 22
const BORDER_CARD := 28
const BORDER_PILL := 24
