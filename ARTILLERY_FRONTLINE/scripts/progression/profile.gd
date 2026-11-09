extends Node
## Autoload Profile. Owns persistent data; UI and combat never write files directly.
signal changed
const SAVE_PATH: String = "user://frontline_v1.json"
var data: Dictionary = SaveManager.defaults()
var storage_available: bool = true

func _ready() -> void:
	var loaded: Dictionary = SaveManager.read_with_recovery(SAVE_PATH)
	data = loaded.data
	if loaded.recovered:
		Events.save_recovered.emit(Loc.t("save_recovered"))
	storage_available = SaveManager.write_atomic(SAVE_PATH, data)

func persist() -> bool:
	storage_available = SaveManager.write_atomic(SAVE_PATH, data)
	changed.emit()
	return storage_available

func set_setting(key: String, value: Variant) -> void:
	if data.settings.has(key):
		data.settings[key] = value
		persist()

func complete_mission(mission: MissionData, result: Dictionary) -> void:
	if not result.get("success", false):
		return
	data = Progression.award(data, mission, result)
	persist()

func purchase(upgrade: UpgradeData) -> String:
	var outcome: Dictionary = Progression.buy_upgrade(data, upgrade)
	if outcome.success:
		data = outcome.data
		persist()
	return Loc.t(outcome.reason)

func next_mission() -> String:
	for id in ["sr05", "sr04", "sr03", "sr02", "sr01"]:
		if id in data.unlocked and not id in data.completed:
			return id
	for id in ["sr01", "sr02", "sr03", "sr04", "sr05"]:
		if id in data.unlocked and not id in data.completed:
			return id
	return "sr05"
