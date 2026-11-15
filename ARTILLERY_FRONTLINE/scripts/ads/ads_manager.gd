extends Node
## Optional Android monetization layer. Gameplay remains fully playable when
## the SDK is absent, consent is unavailable, or an ad request fails.
##
## Release builds stay on Google's official test IDs until the publisher has
## supplied verified production IDs and explicitly enabled real ads.

signal reward_earned(amount: int, reward_type: String)
signal rewarded_ad_availability_changed(available: bool)

const ADMOB_SCRIPT_PATH: String = "res://addons/AdmobPlugin/Admob.gd"
const TEST_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED_UNIT_ID: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_UNIT_ID: String = "ca-app-pub-3940256099942544/1033173712"
const INTERSTITIAL_COOLDOWN_MS: int = 180000

var _admob: Node
var _ads_initialization_requested: bool = false
var _ads_initialized: bool = false
var _rewarded_loaded: bool = false
var _interstitial_loaded: bool = false
var _last_interstitial_shown_ms: int = -1
var _consent_flow_finished: bool = false


func _ready() -> void:
	if not Events.match_finished.is_connected(_on_match_finished):
		Events.match_finished.connect(_on_match_finished)
	if OS.has_feature("android"):
		call_deferred("_attach_admob")


func _attach_admob() -> void:
	# The native singleton is registered by the Android plugin before the game scene starts.
	await get_tree().process_frame
	var admob_script: Script = load(ADMOB_SCRIPT_PATH) as Script
	if admob_script == null:
		push_warning("AdMob plugin script is missing; continuing without ads.")
		return

	_admob = admob_script.new() as Node
	_admob.name = "AdmobRuntime"
	_admob.set("is_real", false)
	_admob.set("android_debug_application_id", TEST_APP_ID)
	_admob.set("android_debug_rewarded_id", TEST_REWARDED_UNIT_ID)
	_admob.set("android_debug_interstitial_id", TEST_INTERSTITIAL_UNIT_ID)
	add_child(_admob)

	_connect_admob_signals()
	# UMP consent is refreshed on every app launch before requesting ads.
	_admob.call("update_consent_info")


func _connect_admob_signals() -> void:
	_admob.connect("consent_info_updated", _on_consent_info_updated)
	_admob.connect("consent_info_update_failed", _on_consent_info_update_failed)
	_admob.connect("consent_form_loaded", _on_consent_form_loaded)
	_admob.connect("consent_form_dismissed", _on_consent_form_dismissed)
	_admob.connect("consent_form_failed_to_load", _on_consent_form_failed_to_load)
	_admob.connect("initialization_completed", _on_admob_initialized)
	_admob.connect("rewarded_ad_loaded", _on_rewarded_ad_loaded)
	_admob.connect("rewarded_ad_failed_to_load", _on_rewarded_ad_failed_to_load)
	_admob.connect("rewarded_ad_user_earned_reward", _on_reward_earned)
	_admob.connect("rewarded_ad_dismissed_full_screen_content", _on_rewarded_ad_dismissed)
	_admob.connect("rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_ad_failed_to_show)
	_admob.connect("interstitial_ad_loaded", _on_interstitial_ad_loaded)
	_admob.connect("interstitial_ad_failed_to_load", _on_interstitial_ad_failed_to_load)
	_admob.connect("interstitial_ad_dismissed_full_screen_content", _on_interstitial_ad_dismissed)
	_admob.connect("interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_ad_failed_to_show)


func _consent_status() -> String:
	if _admob == null:
		return "UNKNOWN"
	var consent: Variant = _admob.call("get_consent_status")
	if consent == null:
		return "UNKNOWN"
	return String(consent.call("to_status_string"))


func _on_consent_info_updated() -> void:
	var status: String = _consent_status()
	if status == "REQUIRED":
		if bool(_admob.call("is_consent_form_available")):
			_admob.call("load_consent_form")
		return
	if status == "OBTAINED" or status == "NOT_REQUIRED":
		_finish_consent_flow()


func _on_consent_info_update_failed(_error: Variant) -> void:
	# Fail closed: do not request ads when the required consent state is unknown.
	_consent_flow_finished = false


func _on_consent_form_loaded() -> void:
	if _consent_status() == "REQUIRED":
		_admob.call("show_consent_form")
	else:
		_finish_consent_flow()


func _on_consent_form_dismissed(_error: Variant) -> void:
	var status: String = _consent_status()
	if status == "OBTAINED" or status == "NOT_REQUIRED":
		_finish_consent_flow()


func _on_consent_form_failed_to_load(_error: Variant) -> void:
	# No ads until a valid consent state is available on a later launch.
	_consent_flow_finished = false


func _finish_consent_flow() -> void:
	if _consent_flow_finished:
		return
	_consent_flow_finished = true
	if not _ads_initialization_requested:
		_ads_initialization_requested = true
		_admob.call("initialize")


func _on_admob_initialized(_status_data: Variant) -> void:
	_ads_initialized = true
	_load_rewarded()
	_load_interstitial()


func _load_rewarded() -> void:
	if _ads_initialized and not _rewarded_loaded:
		_admob.call("load_rewarded_ad")


func _load_interstitial() -> void:
	if _ads_initialized and not _interstitial_loaded:
		_admob.call("load_interstitial_ad")


func _on_rewarded_ad_loaded(_ad_info: Variant, _response_info: Variant) -> void:
	_rewarded_loaded = true
	rewarded_ad_availability_changed.emit(true)


func _on_rewarded_ad_failed_to_load(_ad_info: Variant, _error: Variant) -> void:
	_rewarded_loaded = false
	rewarded_ad_availability_changed.emit(false)


func _on_reward_earned(_ad_info: Variant, reward_data: Variant) -> void:
	# The game grants its reward only from this verified SDK callback.
	reward_earned.emit(int(reward_data.call("get_amount")), String(reward_data.call("get_type")))


func _on_rewarded_ad_dismissed(_ad_info: Variant) -> void:
	_rewarded_loaded = false
	rewarded_ad_availability_changed.emit(false)
	_load_rewarded()


func _on_rewarded_ad_failed_to_show(_ad_info: Variant, _error: Variant) -> void:
	_rewarded_loaded = false
	rewarded_ad_availability_changed.emit(false)
	_load_rewarded()


func _on_interstitial_ad_loaded(_ad_info: Variant, _response_info: Variant) -> void:
	_interstitial_loaded = true


func _on_interstitial_ad_failed_to_load(_ad_info: Variant, _error: Variant) -> void:
	_interstitial_loaded = false


func _on_interstitial_ad_dismissed(_ad_info: Variant) -> void:
	_interstitial_loaded = false
	_load_interstitial()


func _on_interstitial_ad_failed_to_show(_ad_info: Variant, _error: Variant) -> void:
	_interstitial_loaded = false
	_load_interstitial()


func _on_match_finished(_victory: bool, _stats: Dictionary) -> void:
	if OS.has_feature("android"):
		call_deferred("_try_show_interstitial_after_result")


func _try_show_interstitial_after_result() -> void:
	await get_tree().process_frame
	if not _ads_initialized or not _interstitial_loaded or _admob == null:
		return
	var now: int = Time.get_ticks_msec()
	if _last_interstitial_shown_ms >= 0 and now - _last_interstitial_shown_ms < INTERSTITIAL_COOLDOWN_MS:
		return
	_interstitial_loaded = false
	_last_interstitial_shown_ms = now
	_admob.call("show_interstitial_ad")


func is_rewarded_ad_ready() -> bool:
	return OS.has_feature("android") and _ads_initialized and _rewarded_loaded


func show_rewarded_ad() -> bool:
	if not OS.has_feature("android") or not _ads_initialized or _admob == null:
		return false
	if not _rewarded_loaded:
		_load_rewarded()
		return false
	_rewarded_loaded = false
	rewarded_ad_availability_changed.emit(false)
	_admob.call("show_rewarded_ad")
	return true
