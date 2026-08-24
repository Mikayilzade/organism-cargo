class_name AccessibilitySettingsModel
extends RefCounted

const UI_SCALE_MIN_PERCENT := 100
const UI_SCALE_MAX_PERCENT := 200
const DECK_RESOLUTION := Vector2i(1280, 800)

var _ui_scale_percent: int = UI_SCALE_MIN_PERCENT
var _reduced_motion: bool = false
var _reduced_flashing: bool = false
var _master_volume_percent: int = 100
var _non_speech_captions: bool = true
var _input_method: StringName = &"auto"

func apply_patch(patch: Dictionary) -> Dictionary:
	if patch.has("ui_scale_percent"):
		var scale := int(patch["ui_scale_percent"])
		if scale < UI_SCALE_MIN_PERCENT or scale > UI_SCALE_MAX_PERCENT:
			return {"ok": false, "error": "ui_scale_out_of_range"}
		_ui_scale_percent = scale
	if patch.has("reduced_motion"):
		_reduced_motion = bool(patch["reduced_motion"])
	if patch.has("reduced_flashing"):
		_reduced_flashing = bool(patch["reduced_flashing"])
	if patch.has("master_volume_percent"):
		var volume := int(patch["master_volume_percent"])
		if volume < 0 or volume > 100:
			return {"ok": false, "error": "master_volume_out_of_range"}
		_master_volume_percent = volume
	if patch.has("non_speech_captions"):
		_non_speech_captions = bool(patch["non_speech_captions"])
	if patch.has("input_method"):
		var method := StringName(String(patch["input_method"]).strip_edges().to_lower())
		if not [&"auto", &"keyboard_mouse", &"keyboard_only", &"controller", &"steam_deck"].has(method):
			return {"ok": false, "error": "input_method_invalid"}
		_input_method = method
	return {"ok": true, "error": "", "settings": snapshot()}

func snapshot() -> Dictionary:
	return {
		"ui_scale_percent": _ui_scale_percent,
		"reduced_motion": _reduced_motion,
		"reduced_flashing": _reduced_flashing,
		"master_volume_percent": _master_volume_percent,
		"non_speech_captions": _non_speech_captions,
		"input_method": _input_method,
	}

func first_run_preflight_fields() -> Array[StringName]:
	return [
		&"ui_scale_percent",
		&"reduced_flashing",
		&"reduced_motion",
		&"master_volume_percent",
		&"non_speech_captions",
		&"input_method",
	]

func deck_acceptance_profile() -> Dictionary:
	return {
		"resolution": [DECK_RESOLUTION.x, DECK_RESOLUTION.y],
		"default_ui_scale_percent": UI_SCALE_MIN_PERCENT,
		"maximum_ui_scale_percent": UI_SCALE_MAX_PERCENT,
		"touch_required": false,
		"trackpad_required": false,
		"full_hold_visible_at_default_scale": true,
		"drawers_allowed_at_maximum_scale": true,
		"mandatory_controls_must_remain_reachable": true,
	}

func presentation_safety_policy() -> Dictionary:
	return {
		"simulation_authority_unchanged": true,
		"reduced_motion_removes_camera_shake": true,
		"reduced_motion_keeps_authoritative_ticks": true,
		"reduced_flashing_disables_full_screen_flash": true,
		"audio_cues_require_visual_equivalent": true,
		"critical_states_require_non_color_signal": true,
		"rule_text_must_wrap_or_scroll": true,
	}
