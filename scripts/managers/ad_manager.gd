extends Node
## Sole advertising integration boundary. No ad SDK is shipped in the base build.
## A reviewed provider must expose availability, show_rewarded, and completion signals.

signal availability_changed
signal rewarded_completed(placement: String)
signal rewarded_failed(reason: String)

const MIN_INTERSTITIAL_RUNS := 3
const MIN_INTERSTITIAL_SECONDS := 180
var enabled := false
var sdk_ready := false
var _runs_since_interstitial := 0
var _last_interstitial_ms := 0
var _provider: Object


func _ready() -> void:
	enabled = false
	sdk_ready = false


func configure_provider(provider: Object) -> bool:
	# Called only by release bootstrap after SDK/privacy review and configuration.
	if (
		provider == null
		or not provider.has_method("is_rewarded_available")
		or not provider.has_method("show_rewarded")
		or not provider.has_signal("rewarded_completed")
	):
		push_error("Advertising provider does not implement the required contract")
		return false
	_provider = provider
	_provider.connect("rewarded_completed", _on_provider_rewarded)
	if _provider.has_signal("rewarded_failed"):
		_provider.connect("rewarded_failed", _on_provider_failed)
	enabled = true
	sdk_ready = true
	availability_changed.emit()
	return true


func is_rewarded_available(placement: String) -> bool:
	return (
		enabled
		and sdk_ready
		and _provider != null
		and ConsentManager.permits_optional_services()
		and bool(_provider.call("is_rewarded_available", placement))
	)


func show_rewarded(placement: String) -> bool:
	if not is_rewarded_available(placement):
		rewarded_failed.emit("Ads are not configured or available")
		return false
	return bool(_provider.call("show_rewarded", placement))


func _on_provider_rewarded(placement: String) -> void:
	# Completion must originate from the SDK callback, never from a button press.
	rewarded_completed.emit(placement)
	AnalyticsManager.track(&"ad_reward_received", {"reward_type": placement})


func _on_provider_failed(reason: String) -> void:
	rewarded_failed.emit(reason)


func note_run_finished() -> void:
	_runs_since_interstitial += 1


func may_show_interstitial() -> bool:
	return (
		enabled
		and sdk_ready
		and _runs_since_interstitial >= MIN_INTERSTITIAL_RUNS
		and Time.get_ticks_msec() - _last_interstitial_ms >= MIN_INTERSTITIAL_SECONDS * 1000
	)
