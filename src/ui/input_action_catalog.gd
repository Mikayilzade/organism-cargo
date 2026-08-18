class_name InputActionCatalog
extends RefCounted

const REQUIRED_ACTIONS: Array[StringName] = [
	&"navigate_up",
	&"navigate_down",
	&"navigate_left",
	&"navigate_right",
	&"accept",
	&"cancel",
	&"inspect",
	&"rotate",
	&"remove",
	&"region_next",
	&"region_previous",
	&"overlay_next",
	&"overlay_previous",
	&"undo",
	&"redo",
	&"launch_focus",
	&"pause_playback",
	&"speed_up",
	&"speed_down",
	&"tick_step",
	&"review_event_previous",
	&"review_event_next",
	&"jump_failed_predicate",
	&"jump_root_cause",
	&"compare_start_final",
	&"panel_next",
	&"panel_previous",
]

const PLANNING_FOCUS_REGIONS: Array[StringName] = [
	&"MANIFEST",
	&"HOLD",
	&"INSPECTOR",
	&"ROUTE",
	&"OBJECTIVES_SUPPORTS",
	&"TOOLBAR",
]

static func validate_required_actions(actions: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for action: StringName in actions:
		if String(action).strip_edges().is_empty() or seen.has(action):
			return false
		seen[action] = true
	for required: StringName in REQUIRED_ACTIONS:
		if not seen.has(required):
			return false
	return true

static func is_valid_focus_region(region: StringName) -> bool:
	return PLANNING_FOCUS_REGIONS.has(region)
