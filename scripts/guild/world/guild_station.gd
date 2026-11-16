class_name GuildStation
extends Node3D
## A place the player can act on: a shelf to pick goods from, a counter with a
## waiting customer, or the vault to deposit coins in.
##
## Each station owns the state it represents (`GuildStock`, `GuildOrder`,
## `GuildTreasury`) and draws that state: the parcels on a shelf are the stock, the
## coins by the chest are the gold. Nothing is decorative.

const SHELF := "shelf"
const COUNTER := "counter"
const VAULT := "vault"

const PARCEL := Vector3(0.22, 0.16, 0.2)

var kind := SHELF
var stock: GuildStock
var order: GuildOrder
var treasury: GuildTreasury
var customer: GuildCharacter
var interactions := 0

var _visuals: Node3D
var _customer_root: Node3D
var _label: Label3D


func _init(station_kind: String = SHELF) -> void:
	kind = station_kind
	name = "Station_" + station_kind
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_label = Label3D.new()
	_label.name = "Sign"
	_label.font_size = 44
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.94, 0.8)
	_label.position = Vector3(0.0, 2.3, 0.0)
	add_child(_label)


## Connects the station to the state it shows and draws it for the first time.
func bind_stock(goods: GuildStock) -> void:
	stock = goods
	stock.changed.connect(_refresh)
	_refresh()


func bind_order(new_order: GuildOrder) -> void:
	order = new_order
	_refresh()


func bind_treasury(vault: GuildTreasury) -> void:
	treasury = vault
	treasury.changed.connect(_refresh)
	_refresh()


## Shows the customer standing at this counter.
func set_customer(character: GuildCharacter) -> void:
	customer = character
	if _customer_root != null:
		_customer_root.queue_free()
	_customer_root = Node3D.new()
	_customer_root.name = "CustomerSpot"
	_customer_root.position = Vector3(2.0, 0.0, 0.7)
	_customer_root.rotation.y = -PI * 0.5
	add_child(_customer_root)
	_customer_root.add_child(character)
	character.animate(0.016, 0.0, "idle")


## The verb the action button offers when the player is close enough.
func verb() -> String:
	match kind:
		SHELF:
			return "pickup"
		COUNTER:
			return "deliver"
		VAULT:
			return "deposit"
		_:
			return ""


## English wording for the prompt, so the HUD and the capture say the same thing.
func prompt() -> String:
	var key := ""
	match kind:
		SHELF:
			key = "action.pick_up"
		COUNTER:
			key = "action.deliver"
		VAULT:
			key = "action.deposit"
		_:
			return ""
	return GuildLocale.t(key, [], "en")


## What is actually here, as one line: "stock 5", "order 2 x Slime Gel", "vault 240".
func summary() -> String:
	match kind:
		SHELF:
			return "stock %d" % (stock.total() if stock != null else 0)
		COUNTER:
			if order == null:
				return "no order"
			return "order %d x %s / %.0f g" % [
				order.amount,
				GuildLocale.t(GuildItems.name_key(order.item_id), [], "en"),
				order.payment,
			]
		VAULT:
			return "vault %.0f g" % (treasury.cash if treasury != null else 0.0)
		_:
			return ""


static func nearest(stations: Array, point: Vector3, radius: float = 2.4) -> GuildStation:
	var best: GuildStation = null
	var best_distance := radius
	for station in stations:
		var candidate := station as GuildStation
		if candidate == null:
			continue
		var distance := candidate.global_position.distance_to(Vector3(point.x, candidate.global_position.y, point.z))
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _refresh() -> void:
	for child in _visuals.get_children():
		_visuals.remove_child(child)
		child.free()
	match kind:
		SHELF:
			_build_shelf()
		COUNTER:
			_build_counter()
		VAULT:
			_build_vault()
	if _label != null:
		_label.text = "%s - %s" % [prompt(), summary()]


func _build_shelf() -> void:
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(2.2, 0.14, 0.8)
	frame.mesh = frame_mesh
	frame.material_override = GuildMaterials.flat(Color(0.32, 0.23, 0.18))
	frame.position = Vector3(0.0, 0.9, 0.0)
	_visuals.add_child(frame)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.14, 0.9, 0.7)
		leg.mesh = leg_mesh
		leg.material_override = GuildMaterials.flat(Color(0.26, 0.19, 0.15))
		leg.position = Vector3(0.95 * side, 0.45, 0.0)
		_visuals.add_child(leg)

	var shown := 0
	var item_id := stock.first_item() if stock != null else ""
	var color := GuildItems.color(item_id) if not item_id.is_empty() else Color(0.55, 0.5, 0.65)
	var available := stock.count(item_id) if stock != null else 0
	for index in mini(available, 9):
		var parcel := MeshInstance3D.new()
		var parcel_mesh := BoxMesh.new()
		parcel_mesh.size = PARCEL
		parcel.mesh = parcel_mesh
		parcel.material_override = GuildMaterials.flat(color.darkened(0.05 * (index % 3)))
		var row := index % 3
		var layer := int(floor(index / 3.0))
		parcel.position = Vector3(-0.6 + row * 0.36, 1.06 + layer * 0.17, 0.0)
		parcel.rotation.y = deg_to_rad(-6.0 + index * 6.0)
		_visual_add(parcel)
		shown += 1
	set_meta("drawn_parcels", shown)


func _build_counter() -> void:
	var desk := MeshInstance3D.new()
	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(2.6, 0.16, 0.9)
	desk.mesh = desk_mesh
	desk.material_override = GuildMaterials.flat(Color(0.36, 0.25, 0.18))
	desk.position = Vector3(0.0, 1.02, 0.0)
	_visuals.add_child(desk)
	for side in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(0.16, 1.0, 0.8)
		panel.mesh = panel_mesh
		panel.material_override = GuildMaterials.flat(Color(0.28, 0.2, 0.16))
		panel.position = Vector3(1.2 * side, 0.5, 0.0)
		_visuals.add_child(panel)

	# The order sits on the desk as the exact number of parcels being asked for.
	if order != null and order.is_ready():
		var color := GuildItems.color(order.item_id)
		for index in mini(order.amount, 6):
			var parcel := MeshInstance3D.new()
			var parcel_mesh := BoxMesh.new()
			parcel_mesh.size = PARCEL
			parcel.mesh = parcel_mesh
			parcel.material_override = GuildMaterials.flat(color)
			parcel.position = Vector3(-0.5 + index * 0.2, 1.2, 0.1)
			_visual_add(parcel)
		var tag := MeshInstance3D.new()
		var tag_mesh := BoxMesh.new()
		tag_mesh.size = Vector3(0.4, 0.26, 0.02)
		tag.mesh = tag_mesh
		tag.material_override = GuildMaterials.flat(Color(0.94, 0.9, 0.78))
		tag.position = Vector3(0.9, 1.2, 0.2)
		_visual_add(tag)


func _build_vault() -> void:
	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(1.6, 0.9, 1.1)
	chest.mesh = chest_mesh
	chest.material_override = GuildMaterials.flat(Color(0.3, 0.22, 0.16))
	chest.position = Vector3(0.0, 0.45, 0.0)
	_visuals.add_child(chest)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.7, 0.18, 1.2)
	lid.mesh = lid_mesh
	lid.material_override = GuildMaterials.metal(Color(0.92, 0.76, 0.38))
	lid.position = Vector3(0.0, 0.98, 0.0)
	_visuals.add_child(lid)

	# One coin per 50 gold in the vault, capped so the pile stays readable.
	var coins := 0
	var cash := treasury.cash if treasury != null else 0.0
	for index in mini(int(cash / 50.0), 10):
		var coin := MeshInstance3D.new()
		var coin_mesh := CylinderMesh.new()
		coin_mesh.top_radius = 0.13
		coin_mesh.bottom_radius = 0.13
		coin_mesh.height = 0.05
		coin.mesh = coin_mesh
		coin.material_override = GuildMaterials.glow(Color(0.95, 0.79, 0.36), 1.3)
		var row := index % 5
		var layer := int(floor(index / 5.0))
		coin.position = Vector3(-0.4 + row * 0.2, 1.1 + layer * 0.05, 0.0)
		_visual_add(coin)
		coins += 1
	set_meta("drawn_coins", coins)


func _visual_add(instance: MeshInstance3D) -> void:
	var ink := MeshInstance3D.new()
	ink.name = "Ink"
	ink.mesh = instance.mesh
	ink.material_override = GuildMaterials.outline(0.008)
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_child(ink)
	_visuals.add_child(instance)
