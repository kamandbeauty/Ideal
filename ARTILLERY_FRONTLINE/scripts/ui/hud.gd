class_name Hud
extends CanvasLayer
## Combat HUD and touch controls. Every finger gets a role when it lands:
## the one on FIRE shoots (and may still drag to aim), one anywhere else
## aims, so both thumbs work at once. Mouse and keyboard reach the same code.

signal pause_pressed

const MARGIN: float = 28.0
const BANNER_TIME: float = 2.6

var level: CityLevel
var defender: Defender
var active: bool = false
var fingers: Dictionary = {}
var root: Control
var crosshair: HudWidgets.Crosshair
var wall_meter: HudWidgets.Meter
var gate_meter: HudWidgets.Meter
var wall_title: Label
var gate_title: Label
var wall_value: Label
var gate_value: Label
var wave_label: Label
var hostiles_label: Label
var banner: Label
var sub_banner: Label
var ammo_label: Label
var magazine_label: Label
var weapon_label: Label
var reload_label: Label
var hint_label: Label
var kills_label: Label
var fps_label: Label
var fire_button: HudWidgets.RoundButton
var reload_button: HudWidgets.RoundButton
var pause_button: HudWidgets.RoundButton
var gate_arrow: HudWidgets.ThreatArrow
var wall_arrow: HudWidgets.ThreatArrow
var gate_arrow_label: Label
var wall_arrow_label: Label
var vignette: TextureRect
var banner_left: float = 0.0
var banner_hold: bool = false
var hint_left: float = 0.0
var intermission_left: float = -1.0
var gate_struck: float = 10.0
var wall_struck: float = 10.0
var damage_flash: float = 0.0
var kills: int = 0
var wave_index: int = -1
var wave_total: int = 0
var ammo: int = 0
var magazine: int = 0
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
	Events.match_started.connect(_on_match_started)
	Events.language_changed.connect(refresh_text)
	Events.settings_changed.connect(_layout)
	set_active(false)
	refresh_text()
	_layout()


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
	crosshair.size = Vector2(80, 80)
	root.add_child(crosshair)
	wall_title = _label(22, UITheme.TEXT, true)
	gate_title = _label(22, UITheme.TEXT, true)
	wall_value = _label(20, UITheme.TEXT, true)
	gate_value = _label(20, UITheme.TEXT, true)
	wall_meter = HudWidgets.Meter.new()
	gate_meter = HudWidgets.Meter.new()
	root.add_child(wall_meter)
	root.add_child(gate_meter)
	wave_label = _label(32, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	hostiles_label = _label(20, UITheme.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	banner = _label(46, UITheme.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub_banner = _label(24, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label = _label(22, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	weapon_label = _label(18, UITheme.MUTED, true)
	ammo_label = _label(58, UITheme.TEXT, true)
	magazine_label = _label(24, UITheme.MUTED, true)
	reload_label = _label(22, UITheme.AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	kills_label = _label(20, UITheme.MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT)
	fps_label = _label(16, UITheme.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	fire_button = HudWidgets.RoundButton.new("fire", 88.0)
	fire_button.tint = UITheme.RED
	reload_button = HudWidgets.RoundButton.new("reload", 46.0)
	pause_button = HudWidgets.RoundButton.new("pause", 30.0)
	pause_button.tint = UITheme.TEXT
	for button: Control in [fire_button, reload_button, pause_button]:
		root.add_child(button)
	gate_arrow = HudWidgets.ThreatArrow.new()
	wall_arrow = HudWidgets.ThreatArrow.new()
	root.add_child(gate_arrow)
	root.add_child(wall_arrow)
	gate_arrow_label = _label(18, UITheme.RED, true, HORIZONTAL_ALIGNMENT_CENTER)
	wall_arrow_label = _label(18, UITheme.RED, true, HORIZONTAL_ALIGNMENT_CENTER)
	gate_arrow.visible = false
	wall_arrow.visible = false
	gate_arrow_label.visible = false
	wall_arrow_label.visible = false
	banner.modulate.a = 0.0
	sub_banner.modulate.a = 0.0
	reload_label.visible = false


func _label(size: int, color: Color, heavy: bool, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node: Label = UITheme.label("", size, color, heavy)
	node.horizontal_alignment = align
	node.set_meta("heavy", heavy)
	root.add_child(node)
	return node


func bind(siege: CityLevel) -> void:
	level = siege
	defender = siege.defender if siege else null
	fingers.clear()
	if level:
		wall_meter.set_fraction(level.defense.wall_fraction(), true)
		gate_meter.set_fraction(level.defense.gate_fraction(), true)
		gate_meter.broken = level.defense.gate_destroyed
		ammo = defender.weapon.state.ammo
		magazine = defender.weapon.data.magazine_size
		wave_total = level.director.wave_count()
	wave_index = -1
	kills = 0
	banner_left = 0.0
	banner_hold = false
	intermission_left = -1.0
	refresh_text()


func set_active(enabled: bool) -> void:
	active = enabled
	root.visible = enabled
	if not enabled:
		_release_all()


func _release_all() -> void:
	fingers.clear()
	if fire_button:
		fire_button.set_held(false)
	if defender and is_instance_valid(defender):
		defender.set_fire(false)


# -- Layout and text ---------------------------------------------------------------
func _layout() -> void:
	if root == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var left_handed: bool = Profile.setting("left_handed")
	var m: float = MARGIN
	crosshair.position = view * 0.5 - crosshair.size * 0.5
	var bar := Vector2(300.0, 20.0)
	wall_title.position = Vector2(m, m - 6.0)
	wall_title.size = Vector2(110.0, 30.0)
	wall_meter.position = Vector2(m + 112.0, m)
	wall_meter.size = bar
	wall_value.position = Vector2(m + 112.0 + bar.x + 12.0, m - 5.0)
	wall_value.size = Vector2(90.0, 30.0)
	gate_title.position = Vector2(m, m + 30.0)
	gate_title.size = Vector2(110.0, 30.0)
	gate_meter.position = Vector2(m + 112.0, m + 36.0)
	gate_meter.size = Vector2(bar.x * 0.8, 16.0)
	gate_value.position = Vector2(m + 112.0 + bar.x * 0.8 + 12.0, m + 27.0)
	gate_value.size = Vector2(90.0, 30.0)
	wave_label.position = Vector2(view.x * 0.5 - 260.0, m - 10.0)
	wave_label.size = Vector2(520.0, 42.0)
	hostiles_label.position = Vector2(view.x * 0.5 - 260.0, m + 30.0)
	hostiles_label.size = Vector2(520.0, 28.0)
	banner.position = Vector2(0.0, view.y * 0.2)
	banner.size = Vector2(view.x, 60.0)
	sub_banner.position = Vector2(0.0, view.y * 0.2 + 58.0)
	sub_banner.size = Vector2(view.x, 34.0)
	hint_label.position = Vector2(0.0, view.y - 86.0)
	hint_label.size = Vector2(view.x, 34.0)
	pause_button.position = Vector2(view.x - m - 60.0, m - 4.0)
	kills_label.position = Vector2(view.x - m - 300.0, m + 4.0)
	kills_label.size = Vector2(224.0, 30.0)
	fps_label.position = Vector2(view.x - m - 300.0, m + 34.0)
	fps_label.size = Vector2(224.0, 24.0)
	var fire_center := Vector2(view.x - m - 112.0, view.y - m - 104.0)
	var reload_center := fire_center + Vector2(-152.0, 34.0)
	var ammo_origin := Vector2(m, view.y - m - 96.0)
	if left_handed:
		fire_center.x = view.x - fire_center.x
		reload_center.x = view.x - reload_center.x
		ammo_origin.x = view.x - m - 230.0
	fire_button.position = fire_center - fire_button.size * 0.5
	reload_button.position = reload_center - reload_button.size * 0.5
	reload_label.position = Vector2(view.x * 0.5 - 200.0, view.y * 0.5 + 48.0)
	reload_label.size = Vector2(400.0, 30.0)
	weapon_label.position = ammo_origin
	weapon_label.size = Vector2(260.0, 26.0)
	ammo_label.position = ammo_origin + Vector2(0.0, 16.0)
	ammo_label.size = Vector2(130.0, 70.0)
	magazine_label.position = ammo_origin + Vector2(128.0, 50.0)
	magazine_label.size = Vector2(110.0, 32.0)
	gate_arrow.position = Vector2(view.x - 78.0, view.y * 0.42)
	wall_arrow.position = Vector2(24.0, view.y * 0.42)
	gate_arrow_label.position = gate_arrow.position + Vector2(-58.0, 76.0)
	gate_arrow_label.size = Vector2(170.0, 26.0)
	wall_arrow_label.position = wall_arrow.position + Vector2(-58.0, 76.0)
	wall_arrow_label.size = Vector2(170.0, 26.0)


func refresh_text() -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		if child is Label:
			child.add_theme_font_override("font", UITheme.font(child.get_meta("heavy", false)))
	wall_title.text = Loc.t("wall")
	gate_title.text = Loc.t("gate")
	weapon_label.text = Loc.t("weapon_twin_hmg")
	reload_label.text = Loc.t("reloading")
	hint_label.text = Loc.t("hint_controls")
	gate_arrow_label.text = Loc.t("gate")
	wall_arrow_label.text = Loc.t("wall")
	_refresh_values()


func _refresh_values() -> void:
	wall_value.text = Loc.percent(wall_meter.fraction)
	gate_value.text = Loc.percent(gate_meter.fraction)
	ammo_label.text = Loc.number(ammo)
	magazine_label.text = "/ " + Loc.number(magazine)
	ammo_label.add_theme_color_override("font_color", UITheme.RED if ammo <= magazine / 6 else UITheme.TEXT)
	kills_label.text = "%s  %s" % [Loc.t("kills"), Loc.number(kills)]
	if wave_index >= 0:
		wave_label.text = Loc.t("wave", [wave_index + 1, wave_total])
	else:
		wave_label.text = Loc.t("get_ready")


func show_banner(text: String, color: Color = UITheme.AMBER, detail: String = "", hold: bool = false) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	sub_banner.text = detail
	banner_left = BANNER_TIME
	banner_hold = hold
	banner.modulate.a = 1.0
	sub_banner.modulate.a = 1.0


# -- Per-frame ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if not active or level == null or not is_instance_valid(level):
		return
	if banner_left > 0.0 and not banner_hold:
		banner_left -= delta
		var alpha: float = clampf(banner_left / 0.5, 0.0, 1.0)
		banner.modulate.a = alpha
		sub_banner.modulate.a = alpha
	if hint_left > 0.0:
		hint_left -= delta
		hint_label.modulate.a = clampf(hint_left / 0.6, 0.0, 1.0)
	gate_struck += delta
	wall_struck += delta
	damage_flash = maxf(0.0, damage_flash - delta * 1.8)
	var danger: float = 0.0
	if level.defense.wall_fraction() <= level.defense.data.critical_threshold and not level.defense.breached:
		danger = 0.22 + 0.14 * sin(Time.get_ticks_msec() * 0.006)
	vignette.modulate.a = clampf(maxf(damage_flash, danger), 0.0, 0.8)
	if intermission_left >= 0.0:
		intermission_left -= delta
		hostiles_label.text = Loc.t("next_wave", [int(ceil(maxf(intermission_left, 0.0)))])
	else:
		hostiles_label.text = Loc.t("hostiles", [level.director.remaining()])
	var state: WeaponState = defender.weapon.state
	reload_button.set_progress(state.reload_progress())
	reload_label.visible = state.reloading
	_update_arrows()
	var show_fps: bool = Profile.setting("show_fps")
	fps_label.visible = show_fps
	if show_fps:
		fps_label.text = Loc.t("fps", [int(round(Graphics.fps))])


func _update_arrows() -> void:
	var yaw: float = defender.aim.aim_yaw()
	var half_view: float = defender.aim_settings.fov_degrees * 0.7
	var gate_yaw: float = level.yaw_to(level.layout.gate_center)
	var wall_yaw: float = level.yaw_to(level.layout.patch_center)
	var gate_on: bool = gate_struck < 1.6 and absf(gate_yaw - yaw) > half_view
	var wall_on: bool = wall_struck < 1.6 and absf(wall_yaw - yaw) > half_view
	var view: Vector2 = get_viewport().get_visible_rect().size
	_place_arrow(gate_arrow, gate_arrow_label, gate_on, signf(gate_yaw - yaw), view, 0.42)
	_place_arrow(wall_arrow, wall_arrow_label, wall_on, signf(wall_yaw - yaw), view, 0.56)


func _place_arrow(arrow: HudWidgets.ThreatArrow, caption: Label, on: bool, side: float, view: Vector2, height: float) -> void:
	arrow.visible = on
	caption.visible = on
	if not on:
		return
	arrow.side = side if side != 0.0 else 1.0
	arrow.position = Vector2(view.x - 78.0 if arrow.side > 0.0 else 24.0, view.y * height)
	caption.position = Vector2(clampf(arrow.position.x - 58.0, 4.0, view.x - 174.0), arrow.position.y + 74.0)


# -- Events ------------------------------------------------------------------------
func _on_match_started() -> void:
	kills = 0
	wave_index = -1
	hint_left = 7.0
	hint_label.modulate.a = 1.0
	gate_meter.broken = false
	_refresh_values()


func _on_wall_damaged(amount: float, health: float, max_health: float) -> void:
	wall_meter.set_fraction(health / max_health)
	wall_struck = 0.0
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
	show_banner(Loc.t("wave_incoming", [index + 1]), UITheme.TEXT)
	_refresh_values()


func _on_wave_cleared(_index: int, _total: int) -> void:
	show_banner(Loc.t("wave_cleared"), UITheme.GREEN)


func _on_intermission(seconds: float, _next_index: int) -> void:
	intermission_left = seconds


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


func _on_zombie_killed(_zombie: Node3D, _headshot: bool) -> void:
	kills += 1
	_refresh_values()


func _on_weapon_fired(_weapon: Node) -> void:
	crosshair.kick()


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
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P:
			pause_pressed.emit()


## Role of a finger that has just landed at `point` (canvas coordinates).
func role_at(point: Vector2) -> String:
	if pause_button.contains(point, 1.35):
		return "pause"
	if fire_button.contains(point):
		return "fire"
	if reload_button.contains(point, 1.25):
		return "reload"
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
		"pause":
			pause_pressed.emit()


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
