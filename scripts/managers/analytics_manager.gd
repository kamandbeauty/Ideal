extends Node
## Opt-in analytics boundary. Base build has no analytics SDK and sends nothing.

const ALLOWED_EVENTS := [
	&"game_started",
	&"game_over",
	&"revive_used",
	&"coin_collected",
	&"skin_purchased",
	&"daily_reward_claimed",
	&"ad_reward_received"
]
const ALLOWED_PARAMETERS := [&"score", &"amount", &"skin_id", &"reward_type", &"run_seconds"]
var enabled := false


func _ready() -> void:
	enabled = false  # Requires both a reviewed SDK and appropriate consent/config.


func track(event: StringName, parameters: Dictionary = {}) -> void:
	if not enabled or not event in ALLOWED_EVENTS:
		return
	var safe := {}
	for key in parameters:
		if StringName(key) in ALLOWED_PARAMETERS:
			safe[key] = parameters[key]
	_dispatch_to_configured_provider(event, safe)


func _dispatch_to_configured_provider(_event: StringName, _parameters: Dictionary) -> void:
	pass  # Deliberately no provider in v1 base build.
