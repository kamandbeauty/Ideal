class_name MissionManager
extends Node
## Mission rules are independent of HUD, rendering and persistence.
signal objective_changed(completed: int, required: int)
signal finished(result: Dictionary)
var mission: MissionData
var active: bool = false
var elapsed: float = 0.0
var shots: int = 0
var successful_shots: Dictionary = {}
var destroyed_ids: Array[String] = []
var optional_done: bool = false
var result: Dictionary = {}

func begin(data: MissionData) -> void:
	mission = data
	elapsed = 0.0
	shots = 0
	successful_shots.clear()
	destroyed_ids.clear()
	optional_done = false
	result.clear()
	active = true

func register_shot() -> int:
	shots += 1
	return shots

func register_damage(target_id: String, shot_id: int, amount: float) -> void:
	if not active or amount <= 0.0:
		return
	if target_id in mission.target_ids:
		successful_shots[shot_id] = true

func register_destroyed(target_id: String) -> void:
	if not active:
		return
	if target_id in mission.target_ids and not target_id in destroyed_ids:
		destroyed_ids.append(target_id)
		objective_changed.emit(destroyed_ids.size(), mission.target_ids.size())
	if target_id == mission.optional_crate_id:
		optional_done = true

func accuracy() -> float:
	return 100.0 * successful_shots.size() / maxi(1, shots)

func tick(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if destroyed_ids.size() >= mission.target_ids.size():
		finish(true, "All primary targets neutralized")
	elif elapsed >= mission.time_limit:
		finish(false, "Mission time expired")

func check_ammunition(empty: bool, projectiles_active: bool, reloading: bool) -> void:
	if active and empty and not projectiles_active and not reloading:
		finish(false, "Ammunition exhausted with objectives incomplete")

func finish(success: bool, reason: String = "") -> void:
	if not active:
		return
	active = false
	var supply: int = int(mission.ammunition.get("he", 0)) + int(mission.ammunition.get("ap", 0))
	result = {"success": success, "reason": reason, "mission_id": mission.id, "shots": shots, "hits": successful_shots.size(), "accuracy": accuracy(), "time": elapsed, "objectives": destroyed_ids.size(), "required": mission.target_ids.size(), "optional": optional_done, "coins": 0, "stars": 0, "points": 0}
	if success:
		var reward: Dictionary = Economy.mission_reward(mission.base_reward, accuracy(), shots, supply, elapsed, mission.par_time, optional_done)
		result.merge(reward, true)
	finished.emit(result)

func abort() -> void:
	finish(false, "Mission abandoned")
