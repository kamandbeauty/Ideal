class_name TopBar
extends Control
## The always-on strip: coins, potions, lives and the refill clock. Ported from TopBar.cs.
##
## It exists on every screen because the whole game is the loop between those three numbers.
## RTL placement: lives are what playing spends, so they sit at the right end where a Persian
## reader's eye starts; the two currencies sit at the other end.

const HEIGHT := 44.0
const PAD := 16.0
const PILL_WIDTH := 118.0
const PILL_HEIGHT := 44.0

const COIN_WORD := "سکه"
const POTION_WORD := "معجون"
const LIFE_WORD := "جان"
const FULL_WORD := "پر"

var _coins: Label
var _potions: Label
var _lives: Label
var _timer: Label
var _session: GameSession

func build(owner_session: GameSession) -> void:
	_session = owner_session
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	place_bar()

	var coins_pill := UiKit.panel(self, "coins", PAD, 0.0, PILL_WIDTH, PILL_HEIGHT,
		UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD)
	UiKit.icon(coins_pill, "icon_coin", "icon_coin", 8.0, (PILL_HEIGHT - 26.0) * 0.5, 26.0, 26.0)
	_coins = UiKit.raw_label(coins_pill, "value", UiTokens.HUD_CURRENCY, UiTokens.GOLD)
	UiKit.place(_coins, 34.0, 0.0, PILL_WIDTH - 40.0, PILL_HEIGHT)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var potions_pill := UiKit.panel(self, "potions", PAD + PILL_WIDTH + UiTokens.S2, 0.0,
		PILL_WIDTH, PILL_HEIGHT, UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD)
	UiKit.icon(potions_pill, "icon_potion", "icon_potion", 8.0, (PILL_HEIGHT - 26.0) * 0.5, 26.0, 26.0)
	_potions = UiKit.raw_label(potions_pill, "value", UiTokens.HUD_CURRENCY, UiTokens.ACCENT)
	UiKit.place(_potions, 34.0, 0.0, PILL_WIDTH - 40.0, PILL_HEIGHT)

	var lives_pill := UiKit.panel(self, "lives", UiTokens.CANVAS_WIDTH - PAD - PILL_WIDTH, 0.0,
		PILL_WIDTH, PILL_HEIGHT, UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD)
	UiKit.icon(lives_pill, "icon_life", "icon_life", PILL_WIDTH - 34.0, (PILL_HEIGHT - 26.0) * 0.5,
		26.0, 26.0)
	_lives = UiKit.raw_label(lives_pill, "value", UiTokens.HUD_CURRENCY, UiTokens.TEXT)
	UiKit.place(_lives, 4.0, 1.0, PILL_WIDTH - 40.0, 22.0)
	_timer = UiKit.raw_label(lives_pill, "timer", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED)
	UiKit.place(_timer, 4.0, 22.0, PILL_WIDTH - 40.0, 16.0)

	refresh()

func place_bar() -> void:
	UiKit.place(self, 0.0, 6.0, UiTokens.CANVAS_WIDTH, HEIGHT)

func refresh() -> void:
	if _session == null or _coins == null:
		return
	_coins.text = PersianText.number(_session.wallet.coins) + " " + COIN_WORD
	_potions.text = PersianText.number(_session.wallet.potions) + " " + POTION_WORD
	_lives.text = PersianText.number(_session.lives.current) + " " + LIFE_WORD
	# "۵ جان / پر" stacked in a 44 px pill is two lines of mush; only show the clock line when there is
	# actually a countdown, and centre the lives number when there is not.
	_timer.visible = not _session.lives.is_full
	if _session.lives.is_full:
		_timer.text = ""
		UiKit.place(_lives, 4.0, 0.0, PILL_WIDTH - 40.0, PILL_HEIGHT)
	else:
		_timer.text = PersianText.time(_session.lives.next_refill_in_seconds)
		UiKit.place(_lives, 4.0, 1.0, PILL_WIDTH - 40.0, 22.0)
	for entry in [[_coins, PILL_WIDTH - 42.0], [_potions, PILL_WIDTH - 42.0], [_lives, PILL_WIDTH - 42.0],
			[_timer, PILL_WIDTH - 42.0]]:
		UiKit.fit_font(entry[0], float(entry[1]))
