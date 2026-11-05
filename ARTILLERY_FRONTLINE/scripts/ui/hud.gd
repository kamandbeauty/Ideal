class_name GameplayHUD
extends Control
signal fire_requested
signal reload_requested
signal zoom_requested
signal camera_requested
signal pause_requested
signal target_requested
signal solution_requested
signal ammunition_requested(id: String)
var battle: BattleController
var overlay: TacticalOverlay
var mission_label: Label
var objective_label: Label
var bearing_label: Label
var elevation_label: Label
var range_label: Label
var target_label: Label
var target_health: ProgressBar
var status_label: Label
var notice_label: Label
var performance_label: Label
var currency_label: Label
var fire_button: Button
var reload_button: Button
var camera_button: Button
var ammo_buttons: Dictionary = {}
var notice_time: float = 0.0
var data: Dictionary = {}

func _ready() -> void:
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay = TacticalOverlay.new()
	add_child(overlay)
	_build_top_bar()
	_build_target_card()
	_build_bottom_controls()
	notice_label = UITheme.label("", 19, UITheme.ACCENT, true)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_label.offset_left = -430
	notice_label.offset_right = 430
	notice_label.offset_top = 105
	notice_label.offset_bottom = 145
	add_child(notice_label)
	performance_label = UITheme.label("", 15, UITheme.GREEN)
	performance_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	performance_label.offset_left = -370
	performance_label.offset_right = -25
	performance_label.offset_top = 98
	performance_label.offset_bottom = 163
	add_child(performance_label)

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = 18
	bar.offset_bottom = 88
	bar.add_theme_constant_override("separation", 24)
	var mission_box := UITheme.column(0)
	mission_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_label = UITheme.label("01 / FIRST LIGHT", 24, UITheme.TEXT, true)
	objective_label = UITheme.label("PRIMARY TARGETS  0 / 2", 16, UITheme.MUTED)
	mission_box.add_child(mission_label)
	mission_box.add_child(objective_label)
	bar.add_child(UITheme.panel(mission_box, 12))
	var bearing_box := UITheme.column(0)
	bearing_box.custom_minimum_size.x = 185
	bearing_box.add_child(UITheme.label("MAGNETIC BEARING", 14, UITheme.MUTED))
	bearing_label = UITheme.label("000.0°", 30, UITheme.ACCENT, true)
	bearing_box.add_child(bearing_label)
	bar.add_child(UITheme.panel(bearing_box, 10))
	var right := UITheme.row(18)
	var values := UITheme.column(0)
	currency_label = UITheme.label("", 19, UITheme.ACCENT, true)
	values.add_child(currency_label)
	values.add_child(UITheme.label("OFFLINE / LOCAL SAVE", 13, UITheme.MUTED))
	right.add_child(values)
	right.add_child(UITheme.button("PAUSE", func(): pause_requested.emit()))
	bar.add_child(UITheme.panel(right, 10))
	add_child(bar)

func _build_target_card() -> void:
	var box := UITheme.column(8)
	box.custom_minimum_size.x = 275
	box.add_child(UITheme.label("OBSERVER / TARGET ACQUISITION", 14, UITheme.MUTED))
	target_label = UITheme.label("WATCHTOWER / AT POST", 21, UITheme.TEXT, true)
	box.add_child(target_label)
	target_health = ProgressBar.new()
	target_health.custom_minimum_size = Vector2(245, 7)
	target_health.show_percentage = false
	target_health.max_value = 1.0
	target_health.value = 1.0
	box.add_child(target_health)
	box.add_child(UITheme.button("NEXT TARGET  [TAB]", func(): target_requested.emit()))
	box.add_child(UITheme.button("FIRE CONTROL  [F]", func(): solution_requested.emit(), true))
	var panel: PanelContainer = UITheme.panel(box, 16)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(24, 158)
	add_child(panel)

func _build_bottom_controls() -> void:
	var telemetry := UITheme.column(4)
	var numbers := UITheme.row(22)
	var elevation_box := UITheme.column(0)
	elevation_box.add_child(UITheme.label("ELEVATION", 14, UITheme.MUTED))
	elevation_label = UITheme.label("15.0°", 40, UITheme.TEXT, true)
	elevation_box.add_child(elevation_label)
	numbers.add_child(elevation_box)
	var status_box := UITheme.column(0)
	status_box.add_child(UITheme.label("BREECH STATUS", 14, UITheme.MUTED))
	status_label = UITheme.label("READY", 27, UITheme.GREEN, true)
	status_box.add_child(status_label)
	numbers.add_child(status_box)
	telemetry.add_child(numbers)
	range_label = UITheme.label("PREDICTED  000 m  /  0.0 s", 17, UITheme.ACCENT)
	telemetry.add_child(range_label)
	telemetry.add_child(UITheme.label("KESTREL M-42  /  155 mm", 14, UITheme.MUTED))
	var panel: PanelContainer = UITheme.panel(telemetry, 16)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 24
	panel.offset_top = -174
	panel.offset_right = 344
	panel.offset_bottom = -26
	add_child(panel)
	var ammo_box := UITheme.row(8)
	for id in ["he", "ap"]:
		var button: Button = UITheme.button(id.to_upper() + "  00", func(): ammunition_requested.emit(id))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(130, 56)
		ammo_buttons[id] = button
		ammo_box.add_child(button)
	var ammo_holder := VBoxContainer.new()
	ammo_holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_holder.offset_left = -138
	ammo_holder.offset_right = 138
	ammo_holder.offset_top = -112
	ammo_holder.offset_bottom = -24
	var hint := UITheme.label("DRAG TO AIM  ·  1 / 2 SELECT SHELL", 14, UITheme.TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_holder.add_child(hint)
	ammo_holder.add_child(ammo_box)
	add_child(ammo_holder)
	fire_button = UITheme.button("FIRE", func(): fire_requested.emit(), true)
	fire_button.add_theme_font_size_override("font_size", 37)
	fire_button.add_theme_stylebox_override("normal", UITheme.style(UITheme.ACCENT, UITheme.TEXT, 80))
	fire_button.add_theme_stylebox_override("hover", UITheme.style(UITheme.ACCENT.lightened(0.12), UITheme.TEXT, 80))
	fire_button.add_theme_stylebox_override("pressed", UITheme.style(UITheme.ACCENT.darkened(0.15), UITheme.ACCENT, 80))
	fire_button.add_theme_stylebox_override("disabled", UITheme.style(Color(0.16, 0.18, 0.14), UITheme.LINE, 80))
	fire_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_button.offset_left = -186
	fire_button.offset_top = -186
	fire_button.offset_right = -36
	fire_button.offset_bottom = -36
	fire_button.custom_minimum_size = Vector2(150, 150)
	add_child(fire_button)
	reload_button = UITheme.button("RELOAD  [R]", func(): reload_requested.emit())
	reload_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	reload_button.offset_left = -350
	reload_button.offset_top = -92
	reload_button.offset_right = -200
	reload_button.offset_bottom = -36
	add_child(reload_button)
	camera_button = UITheme.button("CAM / GUN", func(): camera_requested.emit())
	camera_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	camera_button.offset_left = -186
	camera_button.offset_top = -254
	camera_button.offset_right = -36
	camera_button.offset_bottom = -202
	add_child(camera_button)
	var zoom := UITheme.button("ZOOM  [Z]", func(): zoom_requested.emit())
	zoom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom.offset_left = -350
	zoom.offset_top = -254
	zoom.offset_right = -200
	zoom.offset_bottom = -202
	add_child(zoom)

func bind(value: BattleController) -> void:
	if battle and battle.telemetry_changed.is_connected(update):
		battle.telemetry_changed.disconnect(update)
	if battle and battle.notice.is_connected(show_notice):
		battle.notice.disconnect(show_notice)
	battle = value
	overlay.battle = value
	battle.telemetry_changed.connect(update)
	battle.notice.connect(show_notice)
	mission_label.text = "%s / %s" % [battle.mission.sector, battle.mission.title]
	currency_label.text = "%d CR  /  %d STARS" % [Profile.data.coins, Profile.data.stars]
	update(battle.telemetry())

func update(value: Dictionary) -> void:
	data = value
	elevation_label.text = "%.1f°" % value.elevation
	bearing_label.text = "%05.1f°" % fposmod(value.yaw, 360.0)
	range_label.text = "PREDICTED  %d m  /  %.1f s" % [roundi(value.predicted_range), value.flight_time]
	target_label.text = value.target_name
	target_health.value = value.target_health
	objective_label.text = "PRIMARY TARGETS  %d / %d     %02d:%02d" % [value.objectives, value.required, int(value.time) / 60, int(value.time) % 60]
	status_label.text = value.state
	status_label.add_theme_color_override("font_color", UITheme.GREEN if value.state == "READY" else UITheme.ACCENT)
	fire_button.disabled = value.state != "READY" or int(value.ammo.get(value.selected_ammo, 0)) <= 0
	reload_button.disabled = value.state != "EMPTY" or int(value.ammo.get(value.selected_ammo, 0)) <= 0
	reload_button.text = "RELOAD  %.1fs" % ((1.0 - value.reload) * battle.loadout.reload_seconds()) if value.state == "RELOADING" else "RELOAD  [R]"
	camera_button.text = "CAM / " + value.camera
	for id in ammo_buttons:
		var button: Button = ammo_buttons[id]
		button.text = "%s  %02d" % [id.to_upper(), int(value.ammo.get(id, 0))]
		button.button_pressed = id == value.selected_ammo
		button.disabled = int(value.ammo.get(id, 0)) <= 0

func show_notice(message: String) -> void:
	notice_label.text = message
	notice_time = 3.5

func _process(delta: float) -> void:
	notice_time = maxf(0.0, notice_time - delta)
	notice_label.modulate.a = minf(1.0, notice_time)
	performance_label.visible = Profile.data.settings.show_performance
	if performance_label.visible:
		var snapshot: Dictionary = Graphics.snapshot()
		performance_label.text = "%.0f FPS  /  %s  /  %d DRAW\n%.0f%% RESOLUTION  /  %d NODES" % [snapshot.fps, snapshot.tier.to_upper(), snapshot.draw_calls, float(snapshot.scale) * 100, snapshot.objects]
