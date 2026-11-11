class_name Hud
extends CanvasLayer
## Combat HUD and touch controls. Every finger gets a role when it lands:
## the one on FIRE shoots (and may still drag to aim), one on a weapon card
## or the grenade does that, and one anywhere else aims, so both thumbs work
## at once. Mouse and keyboard reach the same code.
##
## Layout, in canvas units (810 high on 16:9 and wider screens, taller on
## narrower ones; everything is placed from the edges it belongs to): the wall
## and the gate top left, the wave top centre with the boss under it, kills
## and PAUSE top right; the firing hand in one bottom corner, the weapons in
## the other.

signal pause_pressed

## Clear space kept at the sides, the top and the bottom of a plain 16:9 screen.
const MARGIN: float = 36.0
const TOP: float = 22.0
const BOTTOM: float = 26.0
## Screens wider than 16:9 have rounded corners and thumbs that rest further in: the side margin grows with them, up to this much.
const WIDE_BONUS: float = 40.0
const BANNER_TIME: float = 2.6
const SLOT_SIZE := Vector2(160.0, 80.0)
const SLOT_GAP: float = 12.0
## The hint line walks through these keys once per match: [key, seconds shown].
const HINTS: Array = [["hint_aim", 4.5], ["hint_fire", 4.5], ["hint_cards", 4.5], ["hint_grenade", 4.5]]
## A threat arrow stays up this long after the last blow.
const THREAT_TIME: float = 1.6

var level: CityLevel
var defender: Defender
var active: bool = false
var fingers: Dictionary = {}
var root: Control
var crosshair: HudWidgets.Crosshair
var defense_plate: HudWidgets.Plate
var wall_meter: HudWidgets.Meter
var gate_meter: HudWidgets.Meter
var wall_title: Label
var gate_title: Label
var wall_value: Label
var gate_value: Label
var wave_plate: HudWidgets.Plate
var wave_label: Label
var wave_pips: HudWidgets.WavePips
var hostiles_label: Label
var banner_band: HudWidgets.BannerBand
var banner: Label
var sub_banner: Label
var ammo_plate: HudWidgets.Plate
var ammo_gauge: HudWidgets.AmmoGauge
var ammo_label: Label
var magazine_label: Label
var weapon_label: Label
var reload_label: Label
var feedback_label: Label
var hint_plate: HudWidgets.Plate
var hint_label: Label
var kills_plate: HudWidgets.Plate
var kills_label: Label
var fps_label: Label
var fire_button: HudWidgets.RoundButton
var reload_button: HudWidgets.RoundButton
var pause_button: HudWidgets.RoundButton
var grenade_button: HudWidgets.RoundButton
var grenade_badge: HudWidgets.Badge
var grenade_label: Label
var boss_plate: HudWidgets.Plate
var boss_meter: HudWidgets.Meter
var boss_title: Label
var boss_value: Label
var boss_shown: bool = false
var weapon_slots: Array[HudWidgets.WeaponSlot] = []
var slot_labels: Array[Label] = []
var gate_arrow: HudWidgets.ThreatArrow
var wall_arrow: HudWidgets.ThreatArrow
var gate_arrow_label: Label
var wall_arrow_label: Label
var vignette: TextureRect
var banner_left: float = 0.0
var banner_hold: bool = false
var banner_pop: float = 0.0
var feedback_left: float = 0.0
var hint_left: float = 0.0
var intermission_left: float = -1.0
var gate_struck: float = 10.0
var wall_struck: float = 10.0
## Where the wall was last hurt: the patched breach, either wall arm, or the gateway once the gate is down.
var wall_threat := Vector3.ZERO
## A blow on the wall was reported just before its health dropped (as opposed to something running in through the gateway).
var wall_blow: bool = false
var damage_flash: float = 0.0
var fade_in: float = 1.0
var kills: int = 0
var wave_index: int = -1
var wave_total: int = 0
var waves_cleared: int = 0
var hostiles_shown: int = -1
var ammo: int = 0
var magazine: int = 0
## Spare rounds of the weapon in hand; negative when its supply never runs out.
var reserve: int = -1
var grenade_total: int = -1
var hint_stage: int = 0
var insets := Vector2.ZERO
## Tests and the screenshot run set this to lay the HUD out as if the screen had cut-outs: (left, right) in canvas units.
var inset_override := Vector2(-1.0, -1.0)
var inset_check: float = 0.0
var drag_total: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	get_viewport().size_changed.connect(_layout)
	Events.wall_damaged.connect(_on_wall_damaged)
	Events.gate_damaged.connect(_on_gate_damaged)
	Events.gate_destroyed.connect(_on_gate_destroyed)
	Events.wall_breached.connect(_on_wall_breached)
	Events.defense_warning.connect(_on_warning)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.intermission_started.connect(_on_intermission)
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	Events.zombie_hit.connect(_on_zombie_hit)
	Events.zombie_killed.connect(_on_zombie_killed)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.weapon_changed.connect(_on_weapon_changed)
	Events.weapon_refused.connect(_on_weapon_refused)
	Events.grenades_changed.connect(_on_grenades_changed)
	Events.resupplied.connect(_on_resupplied)
	Events.explosion.connect(_on_explosion)
	Events.boss_appeared.connect(_on_boss_appeared)
	Events.boss_fell.connect(_on_boss_fell)
	Events.match_started.connect(_on_match_started)
	Events.language_changed.connect(refresh_text)
	Events.settings_changed.connect(_layout)
	set_active(false)
	refresh_text()


func _build() -> void:
	vignette = TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.1, 0.05, 0.0))
	gradient.set_color(1, Color(1, 0.1, 0.05, 0.85))
	gradient.add_point(0.55, Color(1, 0.1, 0.05, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 128
	texture.height = 128
	vignette.texture = texture
	vignette.modulate.a = 0.0
	root.add_child(vignette)
	crosshair = HudWidgets.Crosshair.new()
	crosshair.size = Vector2(96, 96)
	root.add_child(crosshair)

	# The wall and the gate.
	defense_plate = _plate()
	defense_plate.add_icon("wall", Vector2(30.0, 26.0), 30.0)
	defense_plate.add_icon("gate", Vector2(30.0, 67.0), 30.0)
	wall_title = _label(24, UITheme.TEXT, true)
	gate_title = _label(24, UITheme.TEXT, true)
	wall_value = _label(24, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT)
	gate_value = _label(24, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT)
	wall_meter = HudWidgets.Meter.new()
	gate_meter = HudWidgets.Meter.new()
	root.add_child(wall_meter)
	root.add_child(gate_meter)

	# The wave, and the boss under it.
	wave_plate = _plate()
	wave_label = _label(30, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	wave_pips = HudWidgets.WavePips.new()
	root.add_child(wave_pips)
	hostiles_label = _label(22, UITheme.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	boss_plate = _plate()
	boss_plate.accent = UITheme.RED
	boss_plate.edge = Color(UITheme.RED, 0.7)
	boss_plate.add_icon("skull", Vector2(36.0, 30.0), 36.0)
	boss_plate.visible = false
	boss_meter = HudWidgets.Meter.new()
	boss_meter.tint = UITheme.RED
	boss_meter.ticks = 4
	boss_meter.visible = false
	root.add_child(boss_meter)
	boss_title = _label(22, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	boss_title.visible = false
	boss_value = _label(22, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	boss_value.visible = false

	# Messages: the banner on its strip, the hint on its plate.
	banner_band = HudWidgets.BannerBand.new()
	banner_band.modulate.a = 0.0
	root.add_child(banner_band)
	banner = UITheme.outline(_label(46, UITheme.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER))
	sub_banner = UITheme.outline(_label(26, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER))
	hint_plate = _plate()
	hint_plate.fill = Color(0.025, 0.03, 0.035, 0.74)
	hint_label = _label(24, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	hint_plate.modulate.a = 0.0
	hint_label.modulate.a = 0.0

	# The weapon in hand.
	ammo_plate = _plate()
	weapon_label = _label(20, UITheme.MUTED, true)
	ammo_label = _label(54, UITheme.TEXT, true)
	magazine_label = _label(26, UITheme.MUTED, true)
	ammo_gauge = HudWidgets.AmmoGauge.new()
	root.add_child(ammo_gauge)
	reload_label = UITheme.outline(_label(22, UITheme.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER))
	feedback_label = UITheme.outline(_label(22, UITheme.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER))
	feedback_label.modulate.a = 0.0

	# Kills, the frame rate and PAUSE.
	kills_plate = _plate()
	kills_plate.accent = Color(0, 0, 0, 0)
	kills_plate.add_icon("skull", Vector2(28.0, 24.0), 28.0)
	kills_label = _label(28, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT)
	fps_label = UITheme.outline(_label(18, UITheme.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT), 4)

	# The firing hand.
	fire_button = HudWidgets.RoundButton.new("fire", 92.0)
	fire_button.tint = UITheme.RED
	reload_button = HudWidgets.RoundButton.new("reload", 50.0)
	pause_button = HudWidgets.RoundButton.new("pause", 34.0)
	pause_button.tint = UITheme.TEXT
	grenade_button = HudWidgets.RoundButton.new("grenade", 54.0)
	for button: Control in [fire_button, reload_button, pause_button, grenade_button]:
		root.add_child(button)
	grenade_badge = HudWidgets.Badge.new()
	grenade_badge.size = Vector2(40, 40)
	root.add_child(grenade_badge)
	grenade_label = _label(26, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)

	gate_arrow = HudWidgets.ThreatArrow.new()
	wall_arrow = HudWidgets.ThreatArrow.new()
	root.add_child(gate_arrow)
	root.add_child(wall_arrow)
	gate_arrow_label = UITheme.outline(_label(22, UITheme.RED, true, HORIZONTAL_ALIGNMENT_CENTER))
	wall_arrow_label = UITheme.outline(_label(22, UITheme.RED, true, HORIZONTAL_ALIGNMENT_CENTER))
	gate_arrow.visible = false
	wall_arrow.visible = false
	gate_arrow_label.visible = false
	wall_arrow_label.visible = false
	banner.modulate.a = 0.0
	sub_banner.modulate.a = 0.0
	reload_label.visible = false


func _plate() -> HudWidgets.Plate:
	var plate := HudWidgets.Plate.new()
	root.add_child(plate)
	return plate


func _label(size: int, color: Color, heavy: bool, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node: Label = UITheme.label("", size, color, heavy)
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(node)
	return node


func bind(siege: CityLevel) -> void:
	level = siege
	defender = siege.defender if siege else null
	fingers.clear()
	_build_slots()
	if level:
		wall_meter.set_fraction(level.defense.wall_fraction(), true)
		gate_meter.set_fraction(level.defense.gate_fraction(), true)
		gate_meter.broken = level.defense.gate_destroyed
		ammo = defender.weapon.state.ammo
		magazine = defender.weapon.data.magazine_size
		reserve = defender.weapon.state.reserve
		grenade_total = defender.grenade_count
		crosshair.set_style("rocket" if defender.weapon.data.kind == "rocket" else "cross")
		wave_total = level.director.wave_count()
		wall_threat = level.layout.patch_center
		if not level.defense.struck.is_connected(_on_struck):
			level.defense.struck.connect(_on_struck)
	wave_index = -1
	waves_cleared = 0
	hostiles_shown = -1
	kills = 0
	boss_shown = false
	if boss_meter:
		_show_boss(false)
	banner_left = 0.0
	banner_hold = false
	intermission_left = -1.0
	gate_struck = 10.0
	wall_struck = 10.0
	refresh_text()


## One card per weapon the gunner carries, rebuilt whenever a level is bound.
func _build_slots() -> void:
	for slot: HudWidgets.WeaponSlot in weapon_slots:
		slot.queue_free()
	for caption: Label in slot_labels:
		caption.queue_free()
	weapon_slots.clear()
	slot_labels.clear()
	if defender == null:
		return
	for item: Weapon in defender.weapons:
		var slot := HudWidgets.WeaponSlot.new(item.data.kind)
		slot.endless = not item.data.limited_supply()
		root.add_child(slot)
		weapon_slots.append(slot)
		slot_labels.append(_label(28, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT))
	_layout()


func set_active(enabled: bool) -> void:
	if enabled and not active:
		fade_in = 0.0
		root.modulate.a = 0.0
	active = enabled
	root.visible = enabled
	if not enabled:
		_release_all()


func _release_all() -> void:
	fingers.clear()
	if fire_button:
		fire_button.set_held(false)
		reload_button.set_held(false)
		grenade_button.set_held(false)
	if defender and is_instance_valid(defender):
		defender.set_fire(false)


# -- Layout and text ---------------------------------------------------------------
## Puts a label in `box`, centred on the box's middle line whatever the line height of the font in use.
func _fit(node: Label, box: Rect2) -> void:
	node.size = box.size
	node.position = Vector2(box.position.x, box.position.y + (box.size.y - node.size.y) * 0.5)


func _layout() -> void:
	if root == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var left_handed: bool = Profile.setting("left_handed")
	insets = safe_insets(view)
	var margins: Vector2 = margins_for(view, insets)
	var left: float = margins.x
	var right: float = view.x - margins.y
	var top: float = TOP
	var bottom: float = view.y - BOTTOM
	var middle: float = view.x * 0.5
	crosshair.position = view * 0.5 - crosshair.size * 0.5

	# Top left: the wall and the gate, one row each.
	defense_plate.position = Vector2(left, top)
	defense_plate.size = Vector2(436.0, 92.0)
	_fit(wall_title, Rect2(left + 56.0, top + 8.0, 104.0, 36.0))
	wall_meter.position = Vector2(left + 164.0, top + 18.0)
	wall_meter.size = Vector2(190.0, 16.0)
	_fit(wall_value, Rect2(left + 358.0, top + 8.0, 66.0, 36.0))
	_fit(gate_title, Rect2(left + 56.0, top + 49.0, 104.0, 36.0))
	gate_meter.position = Vector2(left + 164.0, top + 59.0)
	gate_meter.size = Vector2(190.0, 16.0)
	_fit(gate_value, Rect2(left + 358.0, top + 49.0, 66.0, 36.0))

	# Top centre: the wave, its place in the siege, and what is left of it.
	wave_plate.position = Vector2(middle - 170.0, top)
	wave_plate.size = Vector2(340.0, 92.0)
	_fit(wave_label, Rect2(middle - 165.0, top + 4.0, 330.0, 40.0))
	wave_pips.position = Vector2(middle - 120.0, top + 47.0)
	wave_pips.size = Vector2(240.0, 8.0)
	_fit(hostiles_label, Rect2(middle - 165.0, top + 58.0, 330.0, 30.0))
	boss_plate.position = Vector2(middle - 300.0, top + 100.0)
	boss_plate.size = Vector2(600.0, 60.0)
	_fit(boss_title, Rect2(middle - 230.0, top + 103.0, 460.0, 30.0))
	boss_meter.position = Vector2(middle - 230.0, top + 135.0)
	boss_meter.size = Vector2(460.0, 16.0)
	_fit(boss_value, Rect2(middle + 232.0, top + 114.0, 66.0, 32.0))
	var banner_top: float = maxf(view.y * 0.235, top + 174.0)
	banner_band.position = Vector2(middle - 560.0, banner_top - 6.0)
	banner_band.size = Vector2(1120.0, 104.0)
	_fit(banner, Rect2(0.0, banner_top, view.x, 58.0))
	banner.pivot_offset = banner.size * 0.5
	_fit(sub_banner, Rect2(0.0, banner_top + 58.0, view.x, 36.0))

	# Top right: PAUSE in the corner, kills beside it.
	pause_button.position = Vector2(right - 68.0, top)
	kills_plate.position = Vector2(right - 68.0 - 16.0 - 150.0, top + 10.0)
	kills_plate.size = Vector2(150.0, 48.0)
	_fit(kills_label, Rect2(kills_plate.position.x + 50.0, top + 10.0, 86.0, 48.0))
	_fit(fps_label, Rect2(kills_plate.position.x, top + 62.0, 150.0, 26.0))

	# The firing hand: FIRE in the corner, RELOAD beside it, the grenade above and inside.
	var side: float = -1.0 if left_handed else 1.0
	var fire_center := Vector2((left + 120.0) if left_handed else (right - 120.0), bottom - 112.0)
	var reload_center := fire_center + Vector2(-164.0 * side, 44.0)
	var grenade_center := fire_center + Vector2(-132.0 * side, -132.0)
	fire_button.position = fire_center - fire_button.size * 0.5
	reload_button.position = reload_center - reload_button.size * 0.5
	grenade_button.position = grenade_center - grenade_button.size * 0.5
	grenade_badge.position = grenade_center + Vector2(40.0 * side, -40.0) - grenade_badge.size * 0.5
	_fit(grenade_label, Rect2(grenade_badge.position, grenade_badge.size))
	_fit(reload_label, Rect2(middle - 220.0, view.y * 0.5 + 52.0, 440.0, 34.0))
	_fit(feedback_label, Rect2(middle - 220.0, view.y * 0.5 - 98.0, 440.0, 34.0))

	# The other hand: the weapon cards along the bottom, the round count above them.
	var count: int = weapon_slots.size()
	var cards_width: float = SLOT_SIZE.x * float(count) + SLOT_GAP * float(maxi(count - 1, 0))
	var cards_left: float = (right - cards_width) if left_handed else left
	var cards_top: float = bottom - SLOT_SIZE.y
	for index: int in count:
		var slot: HudWidgets.WeaponSlot = weapon_slots[index]
		slot.position = Vector2(cards_left + (SLOT_SIZE.x + SLOT_GAP) * float(index), cards_top)
		slot.size = SLOT_SIZE
		_fit(slot_labels[index], Rect2(slot.position + Vector2(SLOT_SIZE.x - 62.0, SLOT_SIZE.y - 40.0), Vector2(50.0, 34.0)))
	var ammo_width: float = maxf(cards_width, SLOT_SIZE.x * 2.0 + SLOT_GAP)
	var ammo_origin := Vector2((right - ammo_width) if left_handed else left, cards_top - 10.0 - 104.0)
	ammo_plate.position = ammo_origin
	ammo_plate.size = Vector2(ammo_width, 104.0)
	_fit(weapon_label, Rect2(ammo_origin.x + 16.0, ammo_origin.y + 4.0, ammo_width - 32.0, 28.0))
	_fit(ammo_label, Rect2(ammo_origin.x + 14.0, ammo_origin.y + 33.0, 126.0, 52.0))
	_fit(magazine_label, Rect2(ammo_origin.x + 146.0, ammo_origin.y + 46.0, 120.0, 34.0))
	ammo_gauge.position = Vector2(ammo_origin.x + 16.0, ammo_origin.y + 86.0)
	ammo_gauge.size = Vector2(ammo_width - 32.0, 9.0)
	_place_hint()


## The hint sits bottom centre, between the two hands, on a plate just wide enough for its text.
func _place_hint() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var width: float = clampf(hint_label.get_minimum_size().x + 56.0, 220.0, 660.0)
	hint_plate.size = Vector2(width, 48.0)
	hint_plate.position = Vector2(view.x * 0.5 - width * 0.5, view.y - BOTTOM - 48.0)
	_fit(hint_label, Rect2(hint_plate.position, hint_plate.size))


## Width of the screen cut-outs (camera notch, rounded corners) on the left
## and right, in canvas units, so thumb controls never sit under them.
func safe_insets(view: Vector2) -> Vector2:
	if inset_override.x >= 0.0:
		return inset_override
	var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	return insets_for(view, window, DisplayServer.get_display_safe_area())


## `window` and `safe` are in screen pixels; the answer is (left, right) in canvas units.
static func insets_for(view: Vector2, window: Rect2i, safe: Rect2i) -> Vector2:
	if window.size.x <= 0 or safe.size.x <= 0 or view.x <= 0.0:
		return Vector2.ZERO
	var scale: float = view.x / float(window.size.x)
	# No cut-out eats more than an eighth of the width; anything larger is a display reporting nonsense.
	var limit: float = view.x * 0.125
	var inset_left: float = clampf(float(safe.position.x - window.position.x) * scale, 0.0, limit)
	var inset_right: float = clampf(float(window.end.x - safe.end.x) * scale, 0.0, limit)
	return Vector2(inset_left, inset_right)


## Clear space to keep on the (left, right) of a canvas of size `view` whose cut-outs are `cutouts` wide.
static func margins_for(view: Vector2, cutouts: Vector2) -> Vector2:
	var wide: float = clampf((view.x / maxf(view.y, 1.0) - 16.0 / 9.0) * 110.0, 0.0, WIDE_BONUS)
	var base: float = MARGIN + wide
	# Past a cut-out a small gap is enough: the cut-out has already moved everything inward.
	return Vector2(maxf(base, cutouts.x + 20.0), maxf(base, cutouts.y + 20.0))


func refresh_text() -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		if child is Label:
			UITheme.restyle(child)
	wall_title.text = Loc.t("wall")
	gate_title.text = Loc.t("gate")
	weapon_label.text = Loc.t(defender.weapon.data.name_key) if (defender != null and is_instance_valid(defender)) else ""
	reload_label.text = Loc.t("reloading")
	hint_label.text = Loc.t(HINTS[mini(hint_stage, HINTS.size() - 1)][0])
	gate_arrow_label.text = Loc.t("gate")
	wall_arrow_label.text = Loc.t("wall")
	hostiles_shown = -1
	_refresh_values()
	_layout()


func _refresh_values() -> void:
	wall_value.text = Loc.percent(wall_meter.fraction)
	gate_value.text = Loc.percent(gate_meter.fraction)
	ammo_label.text = Loc.number(ammo)
	# A belt-fed gun shows the belt; a launcher shows the rounds still on the gunner's back.
	magazine_label.text = "/ " + Loc.number(magazine if reserve < 0 else reserve)
	ammo_label.add_theme_color_override("font_color", UITheme.RED if _ammo_low() else UITheme.TEXT)
	grenade_label.text = Loc.number(maxi(grenade_total, 0))
	grenade_label.add_theme_color_override("font_color", UITheme.RED if grenade_total <= 0 else UITheme.TEXT)
	grenade_badge.set_tint(UITheme.RED if grenade_total <= 0 else UITheme.AMBER)
	kills_label.text = Loc.number(kills)
	if wave_index >= 0:
		wave_label.text = Loc.t("wave", [wave_index + 1, wave_total])
	else:
		wave_label.text = Loc.t("get_ready")
	wave_pips.set_state(wave_total, wave_index if intermission_left < 0.0 else -1, waves_cleared, Loc.is_rtl())


func _ammo_low() -> bool:
	return ammo <= magazine / 6 if reserve < 0 else (ammo + reserve) <= 1


func show_banner(text: String, color: Color = UITheme.AMBER, detail: String = "", hold: bool = false) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner_band.set_color(color)
	sub_banner.text = detail
	banner_left = BANNER_TIME
	banner_hold = hold
	banner_pop = 1.0
	banner.modulate.a = 1.0
	sub_banner.modulate.a = 1.0
	banner_band.modulate.a = 1.0


## A word by the crosshair for a moment: a head shot that killed, several down in one blast.
func show_feedback(text: String, color: Color = UITheme.AMBER) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)
	feedback_left = 0.9
	feedback_label.modulate.a = 1.0


# -- Per-frame ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if not active or level == null or not is_instance_valid(level):
		return
	if fade_in < 1.0:
		fade_in = minf(1.0, fade_in + delta * 3.0)
		root.modulate.a = fade_in
	if banner_left > 0.0 and not banner_hold:
		banner_left -= delta
		var alpha: float = clampf(banner_left / 0.5, 0.0, 1.0)
		banner.modulate.a = alpha
		sub_banner.modulate.a = alpha
		banner_band.modulate.a = alpha
	if banner_pop > 0.0:
		# The banner lands a little large and settles.
		banner_pop = maxf(0.0, banner_pop - delta * 6.0)
		banner.scale = Vector2.ONE * (1.0 + 0.12 * banner_pop * banner_pop)
	if feedback_left > 0.0:
		feedback_left -= delta
		feedback_label.modulate.a = clampf(feedback_left / 0.4, 0.0, 1.0)
	if hint_left > 0.0:
		hint_left -= delta
		var shown: float = clampf(hint_left / 0.5, 0.0, 1.0)
		hint_label.modulate.a = shown
		hint_plate.modulate.a = shown
		if hint_left <= 0.0 and hint_stage + 1 < HINTS.size():
			hint_stage += 1
			_show_hint()
	inset_check -= delta
	if inset_check <= 0.0:
		# Turning the phone over moves the camera notch to the other side without resizing the window.
		inset_check = 1.0
		if not safe_insets(get_viewport().get_visible_rect().size).is_equal_approx(insets):
			_layout()
	gate_struck += delta
	wall_struck += delta
	defense_plate.set_alert(0, clampf(1.0 - wall_struck / 0.45, 0.0, 1.0))
	defense_plate.set_alert(1, clampf(1.0 - gate_struck / 0.45, 0.0, 1.0))
	damage_flash = maxf(0.0, damage_flash - delta * 1.8)
	var danger: float = 0.0
	if level.defense.wall_fraction() <= level.defense.data.critical_threshold and not level.defense.breached:
		danger = 0.22 + 0.14 * sin(Time.get_ticks_msec() * 0.006)
	vignette.modulate.a = clampf(maxf(damage_flash, danger), 0.0, 0.8)
	if intermission_left >= 0.0:
		intermission_left -= delta
		var seconds: int = int(ceil(maxf(intermission_left, 0.0)))
		if seconds != hostiles_shown:
			hostiles_shown = seconds
			hostiles_label.text = Loc.t("next_wave", [seconds])
	else:
		var remaining: int = level.director.remaining()
		if remaining != hostiles_shown:
			hostiles_shown = remaining
			hostiles_label.text = Loc.t("hostiles", [remaining])
	var state: WeaponState = defender.weapon.state
	var reloading: float = state.reload_progress() if state.reloading else -1.0
	reload_button.set_progress(state.reload_progress())
	reload_label.visible = state.reloading
	crosshair.set_reload(reloading)
	if state.ammo != ammo or state.reserve != reserve or defender.grenade_count != grenade_total:
		ammo = state.ammo
		magazine = defender.weapon.data.magazine_size
		reserve = state.reserve
		grenade_total = defender.grenade_count
		_refresh_values()
	if defender.weapon.data.kind == "rocket":
		ammo_gauge.set_rockets(state.ammo, maxi(state.reserve, 0), defender.weapon.data.magazine_size + maxi(defender.weapon.data.reserve_max, 0),
			reloading)
	else:
		ammo_gauge.set_belt(float(state.ammo) / float(maxi(defender.weapon.data.magazine_size, 1)), _ammo_low(), reloading)
	_update_weapons()
	_update_boss()
	_update_arrows()
	var show_fps: bool = Profile.setting("show_fps")
	fps_label.visible = show_fps
	if show_fps:
		fps_label.text = Loc.t("fps", [int(round(Graphics.fps))])


func _update_weapons() -> void:
	for index: int in mini(weapon_slots.size(), defender.weapons.size()):
		var item: Weapon = defender.weapons[index]
		weapon_slots[index].set_state(index == defender.weapon_index, item.state.is_spent(), item.state.reload_progress())
		var left: int = item.state.rounds_left()
		var caption: String = "" if left < 0 else Loc.number(left)
		if slot_labels[index].text != caption:
			slot_labels[index].text = caption
			slot_labels[index].add_theme_color_override("font_color", UITheme.RED if left == 0 else UITheme.TEXT)
	grenade_button.set_progress(defender.throw_readiness())
	grenade_button.set_dim(defender.grenade_count <= 0)


func _show_boss(shown: bool) -> void:
	boss_shown = shown
	boss_plate.visible = shown
	boss_meter.visible = shown
	boss_title.visible = shown
	boss_value.visible = shown


func _update_boss() -> void:
	var boss: Zombie = level.horde.boss
	var here: bool = boss != null and is_instance_valid(boss) and boss.alive
	if here != boss_shown:
		_show_boss(here)
		if here:
			boss_title.text = Loc.t(boss.data.name_key)
			boss_meter.set_fraction(boss.health_fraction(), true)
			boss_value.text = Loc.percent(boss_meter.fraction)
	if here and not is_equal_approx(boss_meter.fraction, boss.health_fraction()):
		boss_meter.set_fraction(boss.health_fraction())
		boss_value.text = Loc.percent(boss_meter.fraction)
		boss_plate.set_alert(0, 0.6)
	elif here:
		boss_plate.set_alert(0, maxf(0.0, boss_plate.alerts[0] - 0.05))


func _update_arrows() -> void:
	var yaw: float = defender.aim.aim_yaw()
	var half_view: float = defender.aim_settings.fov_degrees * 0.7
	var gate_yaw: float = level.yaw_to(level.layout.gate_center)
	# The wall is hurt in more than one place: point at wherever the last blow fell.
	var wall_yaw: float = level.yaw_to(wall_threat)
	var gate_on: bool = gate_struck < THREAT_TIME and absf(gate_yaw - yaw) > half_view
	var wall_on: bool = wall_struck < THREAT_TIME and absf(wall_yaw - yaw) > half_view
	var view: Vector2 = get_viewport().get_visible_rect().size
	_place_arrow(gate_arrow, gate_arrow_label, gate_on, signf(gate_yaw - yaw), view, 0.42)
	_place_arrow(wall_arrow, wall_arrow_label, wall_on, signf(wall_yaw - yaw), view, 0.56)


func _place_arrow(arrow: HudWidgets.ThreatArrow, caption: Label, on: bool, side: float, view: Vector2, height: float) -> void:
	arrow.visible = on
	caption.visible = on
	if not on:
		return
	arrow.side = side if side != 0.0 else 1.0
	var margins: Vector2 = margins_for(view, insets)
	arrow.position = Vector2(view.x - margins.y - arrow.size.x if arrow.side > 0.0 else margins.x, view.y * height)
	# The caption is as wide as its word, under the arrow, and like everything else stays inside the margins.
	var width: float = clampf(caption.get_minimum_size().x + 8.0, arrow.size.x, 180.0)
	var from: float = clampf(arrow.position.x + (arrow.size.x - width) * 0.5, margins.x, maxf(margins.x, view.x - margins.y - width))
	_fit(caption, Rect2(from, arrow.position.y + arrow.size.y - 2.0, width, 30.0))


func _show_hint() -> void:
	hint_left = HINTS[hint_stage][1]
	hint_label.text = Loc.t(HINTS[hint_stage][0])
	hint_label.modulate.a = 1.0
	hint_plate.modulate.a = 1.0
	_place_hint()


# -- Events ------------------------------------------------------------------------
func _on_match_started() -> void:
	kills = 0
	wave_index = -1
	waves_cleared = 0
	hostiles_shown = -1
	hint_stage = 0
	_show_hint()
	gate_meter.broken = false
	_refresh_values()


## A blow landed on the gate or somewhere along the wall.
func _on_struck(target: String, at: Vector3, _amount: float) -> void:
	if target == "wall":
		wall_threat = at
		wall_blow = true



func _on_wall_damaged(amount: float, health: float, max_health: float) -> void:
	wall_meter.set_fraction(health / max_health)
	wall_struck = 0.0
	if not wall_blow and level != null and is_instance_valid(level):
		# No blow went with it: something ran through the open gateway into the city.
		wall_threat = level.layout.gate_center
	wall_blow = false
	damage_flash = minf(0.6, damage_flash + 0.1 + amount / max_health * 4.0)
	_refresh_values()


func _on_gate_damaged(_amount: float, health: float, max_health: float) -> void:
	gate_meter.set_fraction(health / max_health)
	gate_struck = 0.0
	_refresh_values()


func _on_gate_destroyed() -> void:
	gate_meter.broken = true
	gate_meter.set_fraction(0.0)
	show_banner(Loc.t("warn_gate_destroyed"), UITheme.RED)
	_refresh_values()


func _on_wall_breached() -> void:
	show_banner(Loc.t("warn_wall_breached"), UITheme.RED, "", true)
	damage_flash = 0.8
	_release_all()


func _on_warning(kind: String) -> void:
	var critical: bool = kind.ends_with("critical")
	if critical:
		Sound.play("critical", -5.0)
	# An "under attack" call never talks over a more serious message.
	if kind.ends_with("attack") and banner_left > 0.6:
		return
	show_banner(Loc.t("warn_" + kind), UITheme.RED if critical else UITheme.AMBER)


func _on_wave_started(index: int, total: int) -> void:
	wave_index = index
	wave_total = total
	intermission_left = -1.0
	hostiles_shown = -1
	# What is new or dangerous in this wave is written under its number.
	var hint: String = ""
	if level != null and is_instance_valid(level) and level.wave_set != null and index < level.wave_set.waves.size():
		var key: String = level.wave_set.waves[index].hint_key
		if key != "":
			hint = Loc.t(key)
	show_banner(Loc.t("wave_incoming", [index + 1]), UITheme.TEXT, hint)
	_refresh_values()


func _on_boss_appeared(zombie: Node3D) -> void:
	var advice: String = (zombie as Zombie).data.advice_key
	show_banner(Loc.t("warn_boss"), UITheme.RED, Loc.t(advice) if advice != "" else "")


func _on_boss_fell(_zombie: Node3D) -> void:
	show_banner(Loc.t("boss_down"), UITheme.GREEN)


func _on_wave_cleared(index: int, _total: int) -> void:
	waves_cleared = index + 1
	show_banner(Loc.t("wave_cleared"), UITheme.GREEN)
	_refresh_values()


func _on_intermission(seconds: float, _next_index: int) -> void:
	intermission_left = seconds
	hostiles_shown = -1
	_refresh_values()


func _on_ammo_changed(value: int, size: int) -> void:
	ammo = value
	magazine = size
	_refresh_values()


func _on_reload_started(_duration: float) -> void:
	reload_label.visible = true


func _on_reload_finished() -> void:
	reload_label.visible = false


func _on_zombie_hit(_at: Vector3, headshot: bool, lethal: bool) -> void:
	crosshair.mark(lethal, headshot)
	if headshot and lethal:
		show_feedback(Loc.t("feedback_headshot"), UITheme.AMBER)


func _on_zombie_killed(_zombie: Node3D, _headshot: bool) -> void:
	kills += 1
	_refresh_values()


func _on_weapon_fired(_weapon: Node) -> void:
	crosshair.kick()


func _on_weapon_changed(_index: int, weapon: Node) -> void:
	var item: Weapon = weapon
	weapon_label.text = Loc.t(item.data.name_key)
	crosshair.set_style("rocket" if item.data.kind == "rocket" else "cross")
	ammo = item.state.ammo
	magazine = item.data.magazine_size
	reserve = item.state.reserve
	_refresh_values()


func _on_weapon_refused(index: int) -> void:
	if index >= 0 and index < weapon_slots.size():
		weapon_slots[index].refuse()
	if banner_left <= 0.6:
		show_banner(Loc.t("out_of_rockets"), UITheme.AMBER)


func _on_grenades_changed(count: int, _capacity: int) -> void:
	grenade_total = count
	_refresh_values()


## What came up to the wall after a wave, written under the "wave cleared" banner.
func _on_resupplied(rockets: int, grenades: int) -> void:
	var parts: PackedStringArray = []
	if rockets > 0:
		parts.append(Loc.t("resupply_rockets", [rockets]))
	if grenades > 0:
		parts.append(Loc.t("resupply_grenades", [grenades]))
	if parts.is_empty():
		return
	sub_banner.text = "  ·  ".join(parts)
	sub_banner.modulate.a = 1.0
	banner_left = maxf(banner_left, BANNER_TIME)


func _on_explosion(_at: Vector3, _radius: float, killed: int) -> void:
	if killed > 0:
		crosshair.mark(true, false)
	if killed >= 2:
		show_feedback(Loc.t("feedback_multi", [killed]), UITheme.RED)


# -- Touch router ------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not active or defender == null or not is_instance_valid(defender):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_down(event.index, event.position)
		else:
			touch_up(event.index)
	elif event is InputEventScreenDrag:
		touch_drag(event.index, event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE, KEY_P:
				pause_pressed.emit()
			KEY_1:
				defender.select_weapon(0)
			KEY_2:
				defender.select_weapon(1)
			KEY_Q:
				defender.cycle_weapon()
			KEY_G:
				defender.throw_grenade()


## Role of a finger that has just landed at `point` (canvas coordinates).
func role_at(point: Vector2) -> String:
	if pause_button.contains(point, 1.4):
		return "pause"
	if fire_button.contains(point):
		return "fire"
	if reload_button.contains(point, 1.25):
		return "reload"
	if grenade_button.contains(point, 1.2):
		return "grenade"
	for index: int in weapon_slots.size():
		if weapon_slots[index].contains(point):
			return "weapon_%d" % index
	return "aim"


func touch_down(index: int, point: Vector2) -> void:
	if not active:
		return
	var role: String = role_at(point)
	fingers[index] = role
	match role:
		"fire":
			fire_button.set_held(true)
			defender.set_fire(true)
		"reload":
			reload_button.set_held(true)
			defender.reload()
		"grenade":
			grenade_button.set_held(true)
			defender.throw_grenade()
		"pause":
			pause_pressed.emit()
		_:
			if role.begins_with("weapon_"):
				defender.select_weapon(int(role.trim_prefix("weapon_")))


func touch_drag(index: int, relative: Vector2) -> void:
	if not active:
		return
	var role: String = fingers.get(index, "")
	if role == "aim" or role == "fire":
		drag_total += relative
		defender.add_drag(relative)


func touch_up(index: int) -> void:
	var role: String = fingers.get(index, "")
	fingers.erase(index)
	if role == "fire" and not fingers.values().has("fire"):
		fire_button.set_held(false)
		defender.set_fire(false)
	elif role == "reload":
		reload_button.set_held(false)
	elif role == "grenade":
		grenade_button.set_held(false)
