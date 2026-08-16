extends Node
## Sole advertising integration boundary. No ad SDK is shipped in the base build.

signal availability_changed
signal rewarded_completed(placement: String)
signal rewarded_failed(reason: String)

const MIN_INTERSTITIAL_RUNS := 3
const MIN_INTERSTITIAL_SECONDS := 180
var enabled := false
var sdk_ready := false
var _runs_since_interstitial := 0
var _last_interstitial_ms := 0


func _ready() -> void:
	enabled = false
	sdk_ready = false


func is_rewarded_available(_placement: String) -> bool:
	return enabled and sdk_ready and ConsentManager.permits_optional_services()


func show_rewarded(placement: String) -> bool:
	if not is_rewarded_available(placement):
		rewarded_failed.emit("Ads are not configured or available")
		return false
	# Provider adapter must emit rewarded_completed only after verified completion.
	return _provider_show_rewarded(placement)


func _provider_show_rewarded(_placement: String) -> bool:
	return false  # Implemented only when a reviewed official plugin is installed.


func note_run_finished() -> void:
	_runs_since_interstitial += 1


func may_show_interstitial() -> bool:
	return (
		enabled
		and sdk_ready
		and _runs_since_interstitial >= MIN_INTERSTITIAL_RUNS
		and Time.get_ticks_msec() - _last_interstitial_ms >= MIN_INTERSTITIAL_SECONDS * 1000
	)
