extends Node
## Release preflight reporter. It never alters behavior for reviewers.

var config: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open("res://data/release_config.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			config = parsed


func report() -> Dictionary:
	return {
		"permissions":
		(
			["INTERNET"]
			if (
				bool(config.get("ads_enabled", false))
				or bool(config.get("analytics_enabled", false))
			)
			else []
		),
		"ads_configured": bool(config.get("production_ad_units_configured", false)),
		"analytics_enabled": bool(config.get("analytics_enabled", false)),
		"consent_state": ConsentManager.Status.keys()[ConsentManager.status],
		"privacy_policy_url": str(config.get("privacy_policy_url", "")),
		"environment": str(config.get("environment", "development")),
		"target_sdk": int(config.get("target_sdk", 0)),
		"signing": "Provided at CI runtime; never stored in project"
	}


func release_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if str(config.get("environment", "")) != "production":
		errors.append("environment must be production")
	if str(config.get("privacy_policy_url", "")).is_empty():
		errors.append("PRIVACY_POLICY_URL is missing")
	if (
		bool(config.get("ads_enabled", false))
		and not bool(config.get("production_ad_units_configured", false))
	):
		errors.append("Production ads are not configured")
	if int(config.get("target_sdk", 0)) < 36:
		errors.append("Target SDK must be reviewed/current (expected API 36)")
	return errors
