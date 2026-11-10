class_name TargetInfo
extends RefCounted
## What the crosshair is on. The aimed hostile is the one closest to the aim axis inside
## a narrow cone (the same cone automatic fire uses). Pure helpers, so the rules are testable.

## Returns the target nearest the aim axis within cone_deg, or null when nothing is in the cone.
static func aimed_target(origin: Vector3, forward: Vector3, targets: Array, cone_deg: float) -> Node3D:
	if forward.length_squared() < 0.0001:
		return null
	var axis: Vector3 = forward.normalized()
	var best: Node3D = null
	var best_dot: float = cos(deg_to_rad(cone_deg))
	for entry in targets:
		var target := entry as Node3D
		if target == null or not is_instance_valid(target):
			continue
		# Aim at chest height, as the lock and automatic fire do.
		var to_target: Vector3 = (target.global_position + Vector3.UP * 1.2) - origin
		if to_target.length_squared() < 0.0001:
			continue
		var dot: float = axis.dot(to_target.normalized())
		if dot >= best_dot:
			best_dot = dot
			best = target
	return best

## Localisation key for the kind of hostile.
static func kind_key(node: Node3D) -> String:
	if node is EnemySoldier:
		return "target_soldier"
	if node is LandingCraft:
		return "target_craft"
	if node is EnemyAircraft:
		return "target_fighter" if (node as EnemyAircraft).kind == "fighter" else "target_helicopter"
	if node is EnemyVehicle:
		match (node as EnemyVehicle).kind:
			"boss":
				return "target_boss"
			"apc":
				return "target_apc"
			"jeep":
				return "target_jeep"
			"transport":
				return "target_transport"
	return "target_tank"

## Remaining health as a 0..1 ratio, for any hostile that exposes health and max_health.
static func health_ratio(node: Node3D) -> float:
	var max_hp: float = float(node.get("max_health"))
	if max_hp <= 0.0:
		return 1.0
	return clampf(float(node.get("health")) / max_hp, 0.0, 1.0)

## One line for the target panel: kind, range in metres and remaining health.
static func summary(node: Node3D, range_m: float) -> String:
	var percent: int = int(roundf(health_ratio(node) * 100.0))
	return "%s   %s   %s %s٪" % [
		Loc.t(kind_key(node)),
		Loc.t("target_range") % Loc.number(int(roundf(range_m))),
		Loc.t("target_health"),
		Loc.number(percent),
	]

## Shooting state shown under the target: reloading, automatic fire on target, or ready for manual fire.
static func status(auto_fire: bool, reloading: bool) -> String:
	if reloading:
		return Loc.t("target_reloading")
	return Loc.t("target_auto_fire") if auto_fire else Loc.t("target_manual_ready")
