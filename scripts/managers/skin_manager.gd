extends Node

signal skin_changed(id: String)
var skins: Array[Dictionary] = []


func _ready() -> void:
	var file := FileAccess.open("res://data/skins.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			skins.assign(parsed.get("skins", []))


func get_skin(id: String) -> Dictionary:
	for skin in skins:
		if skin.id == id:
			return skin
	return skins[0] if not skins.is_empty() else {"id": "classic", "color": "#E85D3F"}


func purchase(id: String) -> bool:
	var skin := get_skin(id)
	if skin.is_empty() or SaveManager.data.unlocked_skins.has(id):
		return false
	if int(SaveManager.data.coins) < int(skin.price):
		return false
	SaveManager.data.coins -= int(skin.price)
	SaveManager.data.unlocked_skins.append(id)
	SaveManager.save()
	AnalyticsManager.track(&"skin_purchased", {"skin_id": id})
	return true


func equip(id: String) -> bool:
	if not SaveManager.data.unlocked_skins.has(id):
		return false
	SaveManager.data.selected_skin = id
	SaveManager.save()
	skin_changed.emit(id)
	return true
