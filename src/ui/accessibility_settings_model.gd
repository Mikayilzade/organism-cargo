class_name AccessibilitySettingsModel
extends RefCounted

const UI_SCALE_MIN_PERCENT := 100
const UI_SCALE_MAX_PERCENT := 200
const DECK_RESOLUTION := Vector2i(1280, 800)

const CRITICAL_SIGNAL_KINDS: Array[StringName] = [
	&"hazard_onset",
	&"hazard_end",
	&"state_transition",
	&"alarm_panic",
	&"growth",
	&"blocked_growth",
	&"feeding_soothing",
	&"brownout_power_loss",
	&"discovery_evidence",
	&"predicate_failure",
	&"transit_completion",
]

const NON_COLOR_CHANNELS := {
	"heat": {"icon": "heat", "pattern": "thermal_lines"},
	"stress": {"icon": "stress", "pattern": "jagged_ripple"},
	"contamination": {"icon": "contamination", "pattern": "particulate_mottle"},
}

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

func critical_signal(kind: StringName, source_label: String, detail: String = "", channel: StringName = &"") -> Dictionary:
	if not CRITICAL_SIGNAL_KINDS.has(kind):
		return {"ok": false, "error": "unknown_critical_signal"}
	var source := source_label.strip_edges()
	if source.is_empty():
		source = "System"
	var base := _signal_language(kind)
	var caption := "%s — %s" % [source, String(base.get("caption", "event"))]
	if not detail.strip_edges().is_empty():
		caption += ": %s" % detail.strip_edges()
	var non_color := _non_color_language(kind, channel)
	return {
		"ok": true,
		"error": "",
		"kind": kind,
		"source": source,
		"caption": caption,
		"caption_visible": _non_speech_captions or _master_volume_percent == 0,
		"text_label": String(base.get("label", "Event")),
		"icon": String(non_color.get("icon", base.get("icon", "info"))),
		"pattern": String(non_color.get("pattern", base.get("pattern", "solid_outline"))),
		"shape": String(base.get("shape", "outlined_badge")),
		"audio_optional": true,
		"audio_available": _master_volume_percent > 0,
		"motion_mode": "snap_fade" if _reduced_motion else "standard",
		"camera_shake": false if _reduced_motion else bool(base.get("camera_shake", false)),
		"overlay_motion": "static_pattern" if _reduced_motion else "standard",
		"flash_mode": "persistent_outline" if _reduced_flashing else "bounded_fade",
		"full_screen_flash": false,
		"authoritative_simulation_changed": false,
	}

func _signal_language(kind: StringName) -> Dictionary:
	match kind:
		&"hazard_onset":
			return {"caption": "hazard started", "label": "HAZARD", "icon": "hazard", "pattern": "warning_stripe", "shape": "warning_badge"}
		&"hazard_end":
			return {"caption": "hazard ended", "label": "HAZARD ENDED", "icon": "hazard_clear", "pattern": "outlined_clear", "shape": "status_badge"}
		&"state_transition":
			return {"caption": "state changed", "label": "STATE CHANGE", "icon": "state_change", "pattern": "double_outline", "shape": "state_badge"}
		&"alarm_panic":
			return {"caption": "alarm pulse", "label": "ALARM", "icon": "alarm", "pattern": "jagged_ripple", "shape": "warning_badge", "camera_shake": true}
		&"growth":
			return {"caption": "growth", "label": "GROWTH", "icon": "growth", "pattern": "before_after_outline", "shape": "state_badge"}
		&"blocked_growth":
			return {"caption": "growth blocked", "label": "GROWTH BLOCKED", "icon": "blocked", "pattern": "crossed_outline", "shape": "blocked_badge"}
		&"feeding_soothing":
			return {"caption": "support effect activated", "label": "SUPPORT EFFECT", "icon": "support", "pattern": "pulse_ring", "shape": "status_badge"}
		&"brownout_power_loss":
			return {"caption": "power lost", "label": "BROWNOUT / OFF", "icon": "slashed_power", "pattern": "power_slash", "shape": "power_badge"}
		&"discovery_evidence":
			return {"caption": "discovery evidence", "label": "DISCOVERY", "icon": "evidence", "pattern": "evidence_marker", "shape": "evidence_badge"}
		&"predicate_failure":
			return {"caption": "mandatory objective failed", "label": "FAILURE", "icon": "failure", "pattern": "crossed_outline", "shape": "failure_badge"}
		&"transit_completion":
			return {"caption": "transit complete", "label": "TRANSIT COMPLETE", "icon": "completion", "pattern": "completion_frame", "shape": "result_badge"}
	return {}

func _non_color_language(kind: StringName, channel: StringName) -> Dictionary:
	var channel_key := String(channel).strip_edges().to_lower()
	if NON_COLOR_CHANNELS.has(channel_key):
		var channel_value: Variant = NON_COLOR_CHANNELS[channel_key]
		if typeof(channel_value) == TYPE_DICTIONARY:
			return (channel_value as Dictionary).duplicate(true)
	if kind == &"brownout_power_loss":
		return {"icon": "slashed_power", "pattern": "power_slash"}
	if kind == &"predicate_failure":
		return {"icon": "failure", "pattern": "crossed_outline"}
	return {}
