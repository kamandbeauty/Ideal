class_name MissionData
extends RefCounted
## Ordered Story Milestone chain (used alongside the 3 parallel Chapter Quest
## cards for guided progression and tests).

const MISSIONS := [
	{"id": "first_upgrade", "kind": "upgrades", "goal": 3, "cash": 200.0, "gems": 0, "bourbon": 8},
	{"id": "open_car_wash", "kind": "business", "target": "car_wash", "goal": 1, "cash": 350.0, "gems": 0, "bourbon": 12},
	{"id": "reach_level_ten", "kind": "max_level", "goal": 10, "cash": 600.0, "gems": 3, "bourbon": 15},
	{"id": "hire_manager", "kind": "managers", "goal": 1, "cash": 800.0, "gems": 5, "bourbon": 20},
	{
		"id": "open_auto_service", "kind": "business", "target": "auto_service",
		"goal": 1, "cash": 1400.0, "gems": 5, "bourbon": 20,
	},
	{"id": "buy_branch", "kind": "branches", "goal": 2, "cash": 1800.0, "gems": 5, "bourbon": 25},
	{"id": "serve_customers", "kind": "customers", "goal": 120, "cash": 3200.0, "gems": 8, "bourbon": 30},
	{"id": "open_all", "kind": "unlocked_count", "goal": 8, "cash": 25000.0, "gems": 15, "bourbon": 60},
	{"id": "complete_town", "kind": "completion", "goal": 100, "cash": 0.0, "gems": 40, "bourbon": 120},
]


static func count() -> int:
	return MISSIONS.size()


static func mission(index: int) -> Dictionary:
	if index < 0 or index >= MISSIONS.size():
		return {}
	return MISSIONS[index]
