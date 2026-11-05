class_name CombatCoordinator
extends Node
## One impact resolves direct and radial damage once per damageable object.
signal damage_dealt(target_id: String, amount: float, direct: bool, shot_id: int)
var effects: EffectPool

func resolve_impact(point: Vector3, normal: Vector3, collider: Object, ammo: AmmunitionData, multiplier: float, shot_id: int) -> void:
	for node in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var target: Node3D = node as Node3D
		var direct: bool = collider == target
		var distance: float = point.distance_to(target.damage_point())
		var damage: float = DamageSystem.calculate(ammo.damage * multiplier, distance, ammo.blast_radius, target.armor_value(), direct, ammo.direct_bonus)
		if damage > 0.0:
			var applied: float = target.receive_damage(damage, point, direct)
			var id: String = str(target.get("target_id"))
			damage_dealt.emit(id, applied, direct, shot_id)
	if effects:
		effects.explode(point + normal * 0.15, normal, ammo.blast_radius, TerrainSampler.height_at(point.x, point.z))
	Sound.play_at("explosion" if ammo.id == "he" else "impact", point, -3.0, 0.92 if ammo.id == "he" else 1.15)
	Events.projectile_impacted.emit(point, normal, collider != null)
	Events.camera_shake_requested.emit(0.18)
