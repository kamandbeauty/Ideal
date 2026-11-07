class_name ShopScreen
extends UiScreen
## The booster shop: what the booster bar spends, bought back with coins. Ported from ShopScreen.cs.
##
## The prices come from BoosterBag.Price, the same function the tests assert against, so the shop can
## never drift from the wallet rules.

signal back_requested

const ROW_HEIGHT := 72.0

var _rows: Array[Dictionary] = []
var _coins: Label
var _feedback: Label

func build() -> void:
	UiKit.backdrop(self, "store_feature")
	UiKit.color_rect(self, "wash", Color(UiTokens.BG.r, UiTokens.BG.g, UiTokens.BG.b, 0.62))

	UiKit.button(self, "back", "بازگشت", UiTokens.CANVAS_WIDTH - 16.0 - 84.0, 54.0, 84.0, 40.0,
		UiTokens.SURFACE_RAISED, UiTokens.TEXT, _on_back, UiTokens.RADIUS_MD)

	var title := UiKit.label(self, "title", "فروشگاه", UiTokens.TYPE_LG, UiTokens.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	UiKit.place(title, 16.0, 54.0, UiTokens.CANVAS_WIDTH - 32.0, 40.0)

	_coins = UiKit.label(self, "coins", "", UiTokens.TYPE_SM, UiTokens.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_coins, 16.0, 98.0, UiTokens.CANVAS_WIDTH - 32.0, 22.0)

	for kind in range(BoosterBag.SLOTS):
		var y := 132.0 + float(kind) * (ROW_HEIGHT + 10.0)
		var row := UiKit.art_panel(self, "row_%d" % kind, 16.0, y, UiTokens.CANVAS_WIDTH - 32.0,
			ROW_HEIGHT, "panel_frame", UiTokens.BORDER_PANEL, UiTokens.SURFACE, UiTokens.RADIUS_MD)

		UiKit.icon(row, "icon", _booster_icon(kind), 10.0, (ROW_HEIGHT - 44.0) * 0.5, 44.0, 44.0)

		var name_label := UiKit.label(row, "name", BoosterBag.booster_name(kind), UiTokens.TYPE_BASE,
			UiTokens.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, true)
		UiKit.place(name_label, 62.0, 8.0, UiTokens.CANVAS_WIDTH - 32.0 - 200.0, 26.0)

		var owned := UiKit.label(row, "owned", "", UiTokens.TYPE_XS, UiTokens.TEXT_MUTED,
			HORIZONTAL_ALIGNMENT_RIGHT)
		UiKit.place(owned, 62.0, 36.0, UiTokens.CANVAS_WIDTH - 32.0 - 200.0, 20.0)

		var price := UiKit.button(row, "buy", "", UiTokens.CANVAS_WIDTH - 32.0 - 138.0, 18.0, 128.0, 36.0,
			UiTokens.GOLD, UiTokens.ON_GOLD, Callable(self, "_on_buy").bind(kind), UiTokens.RADIUS_MD)
		price.add_theme_font_size_override("font_size", UiTokens.TYPE_SM)

		_rows.append({"owned": owned, "buy": price})

	_feedback = UiKit.label(self, "feedback", "", UiTokens.TYPE_SM, UiTokens.SUCCESS,
		HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(_feedback, 16.0, 620.0, UiTokens.CANVAS_WIDTH - 32.0, 40.0)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func _booster_icon(kind: int) -> String:
	match kind:
		GameTypes.BoosterKind.MALLET: return "booster_mallet"
		GameTypes.BoosterKind.RAM: return "booster_ram"
		GameTypes.BoosterKind.AUGER: return "booster_auger"
		GameTypes.BoosterKind.WHIRLWIND: return "booster_whirlwind"
		GameTypes.BoosterKind.FALCON: return "booster_falcon"
		_: return "booster_mallet"

func refresh() -> void:
	if session == null:
		return
	_coins.text = "سکه: " + PersianText.number(session.wallet.coins)
	for kind in range(_rows.size()):
		var row: Dictionary = _rows[kind]
		var owned_label: Label = row["owned"]
		var buy_button: Button = row["buy"]
		var count := session.boosters.count(kind)
		owned_label.text = "در اختیار: " + PersianText.fraction(count, BoosterBag.MAX_OWNED)
		var price := BoosterBag.price(kind)
		buy_button.text = PersianText.number(price) + " سکه"
		buy_button.disabled = not session.wallet.can_afford_coins(price) or count >= BoosterBag.MAX_OWNED
		buy_button.modulate = Color(1, 1, 1, 1) if not buy_button.disabled else Color(0.6, 0.6, 0.65, 1)

func _on_buy(kind: int) -> void:
	if session.buy_booster(kind):
		SoundDirector.play("reward")
		_feedback.add_theme_color_override("font_color", UiTokens.SUCCESS)
		_feedback.text = BoosterBag.booster_name(kind) + " خریداری شد"
	else:
		_feedback.add_theme_color_override("font_color", UiTokens.DANGER)
		_feedback.text = "سکه کافی نیست یا انبار پر است"
	session.notify_changed()
	refresh()

func _on_back() -> void:
	back_requested.emit()
