extends Node
## Cross-system notifications. Payloads never contain UI nodes.
signal shot_fired(origin: Vector3, direction: Vector3)
signal projectile_impacted(position: Vector3, normal: Vector3, direct_hit: bool)
signal target_destroyed(target_id: String, kind: String, position: Vector3)
signal objective_changed(completed: int, required: int)
signal weapon_state_changed(state: String)
signal camera_shake_requested(strength: float)
signal mission_finished(result: Dictionary)
signal save_recovered(message: String)
