class_name GuildCarryStack
extends Node3D
## The visible stack of goods (or coins) a character is holding.
##
## It is a view of the real count: `show_items(4)` builds exactly four parcels,
## nothing is faked with particles. If the inventory says three, the player sees
## three, which is the whole point of the carrying loop.

const MAX_VISIBLE := 8
const ITEM_SIZE := Vector3(0.2, 0.095, 0.16)
const COIN_RADIUS := 0.075

var item_color := Color(0.58, 0.36, 0.72)
var total := 0
var kind := "items"
var _body: Node3D


func _init() -> void:
	name = "CarryStack"
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)


## `count` is the real number of items in the hands; `visible` caps at 8 so the
## stack stays readable and never clips through the head.
func show_items(count: int, color: Color = Color(0.58, 0.36, 0.72)) -> void:
	kind = "items"
	item_color = color
	total = maxi(count, 0)
	_rebuild()


func show_money(amount: float) -> void:
	kind = "money"
	item_color = Color(0.95, 0.79, 0.36)
	total = maxi(int(ceil(amount / 50.0)), 0)
	_rebuild()


func visible_count() -> int:
	return mini(total, MAX_VISIBLE)


func _rebuild() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.free()
	var shown := visible_count()
	for index in shown:
		var piece := MeshInstance3D.new()
		if kind == "money":
			var coin := CylinderMesh.new()
			coin.top_radius = COIN_RADIUS
			coin.bottom_radius = COIN_RADIUS
			coin.height = 0.02
			piece.mesh = coin
			piece.position = Vector3(0.0, 0.012 + index * 0.023, 0.0)
		else:
			var parcel := BoxMesh.new()
			parcel.size = ITEM_SIZE
			piece.mesh = parcel
			piece.position = Vector3(0.0, ITEM_SIZE.y * 0.5 + index * (ITEM_SIZE.y + 0.008), 0.0)
			piece.rotation.y = deg_to_rad(-8.0 + (index % 3) * 8.0)
		piece.material_override = GuildMaterials.flat(item_color.darkened(0.08 * (index % 2)))
		var ink := MeshInstance3D.new()
		ink.mesh = piece.mesh
		ink.material_override = GuildMaterials.outline(0.008)
		ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.add_child(ink)
		_body.add_child(piece)
