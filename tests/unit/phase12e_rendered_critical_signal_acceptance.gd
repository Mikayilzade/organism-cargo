class_name Phase12ERenderedCriticalSignalAcceptance
extends RefCounted

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const AccessibleVerticalSliceControlScript := preload("res://src/ui/accessible_vertical_slice_control.gd")
const AccessibilitySettingsModelScript := preload("res://src/ui/accessibility_settings_model.gd")

var _failures: Array[String] = []

func run(tree: SceneTree, run_id_factory: Callable) -> Array[String]:
	_failures.clear()
	var root_path: String = "user://vertical_slice_accessibility_fixture"
	_clear_store(root_path)

	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect(state_machine.transition_to(AppStateMachine.State.TITLE), "accessible path boot -> title")
	var store: AtomicSaveStore = AtomicSaveStoreScript.new(root_path)
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(state_machine, store, run_id_factory)
	var control: AccessibleVerticalSliceControl = AccessibleVerticalSliceControlScript.new()
	tree.root.add_child(control)
	control.configure(flow, _context())
	await tree.process_frame

	_expect(bool(control.activate_primary_action().get("ok", false)), "accessible title -> campaign")
	_expect(bool(control.activate_primary_action().get("ok", false)), "accessible campaign -> brief")
	_expect(bool(control.activate_primary_action().get("ok", false)), "accessible brief -> planning")
	var revision: Dictionary = flow.apply_plan("revision-accessible-failure", _input(), _legal_facts())
	_expect(bool(revision.get("structural_legal", false)), "accessible representative plan is structurally legal")
	_expect(bool(control.activate_primary_action().get("ok", false)), "accessible planning -> launch confirmation")
	_expect(bool(control.activate_primary_action().get("ok", false)), "accessible representative launch commits")
	_expect_equal(flow.current_state(), AppStateMachine.State.TRANSIT_PLAYBACK, "accessible representative run reaches transit")

	var completion: Dictionary = control.activate_primary_action()
	_expect(bool(completion.get("ok", false)), "accessible representative transit completes")
	_expect_equal(flow.current_state(), AppStateMachine.State.CAUSAL_REVIEW, "accessible representative failure reaches Causal Review")
	var completed: Dictionary = flow.last_completed_result()
	var delivery_value: Variant = completed.get("delivery_result", {})
	_expect(delivery_value is Dictionary, "accessible completed result owns delivery outcome")
	if delivery_value is Dictionary:
		_expect(not bool((delivery_value as Dictionary).get("success", true)), "representative path is an authoritative failure")

	var panel: Node = control.get_node_or_null("CriticalSignalPanel")
	_expect(panel != null, "rendered critical-signal panel exists on player-facing accessible control")
	if panel is Control:
		_expect((panel as Control).visible, "critical-signal panel is visible in Causal Review")

	var signals: Array = control.critical_signal_snapshot()
	var signal_list: Node = control.get_node_or_null("CriticalSignalPanel/CriticalSignalList")
	_expect(signal_list != null, "rendered critical-signal list exists")
	if signal_list != null:
		_expect_equal(signal_list.get_child_count(), signals.size(), "every critical presentation signal is rendered as a visible row")

	_expect(_has_signal_kind(signals, &"brownout_power_loss"), "actual Phase-A Brownout is surfaced")
	_expect(_has_signal_kind(signals, &"hazard_onset"), "actual route hazard onset is surfaced")
	_expect(_has_signal_kind(signals, &"hazard_end"), "actual route hazard end is surfaced")
	_expect(_has_signal_kind(signals, &"state_transition"), "actual organism state transition is surfaced")
	_expect(_has_signal_kind(signals, &"alarm_panic"), "actual panic transition has a non-audio alarm equivalent")
	_expect(_has_signal_kind(signals, &"predicate_failure"), "actual mandatory predicate failure is surfaced")
	_expect(_has_signal_kind(signals, &"transit_completion"), "actual transit completion is surfaced")

	for raw_signal: Variant in signals:
		if not raw_signal is Dictionary:
			continue
		var signal: Dictionary = raw_signal
		var kind: String = String(signal.get("kind", "event"))
		_expect(bool(signal.get("caption_visible", false)), "%s caption remains visible with master audio at zero" % kind)
		_expect(not bool(signal.get("audio_available", true)), "%s does not depend on an audio device" % kind)
		_expect(not String(signal.get("source", "")).is_empty(), "%s keeps source identity visible" % kind)
		_expect(not String(signal.get("text_label", "")).is_empty(), "%s keeps a text label visible" % kind)
		_expect(not String(signal.get("icon", "")).is_empty(), "%s keeps a non-color icon channel" % kind)
		_expect(not String(signal.get("pattern", "")).is_empty(), "%s keeps a non-color pattern channel" % kind)
		_expect(not String(signal.get("shape", "")).is_empty(), "%s keeps a non-color shape channel" % kind)
		_expect_equal(signal.get("motion_mode"), "snap_fade", "%s obeys Reduced Motion" % kind)
		_expect_equal(signal.get("overlay_motion"), "static_pattern", "%s uses static overlays under Reduced Motion" % kind)
		_expect_equal(signal.get("flash_mode"), "persistent_outline", "%s obeys Reduced Flashing" % kind)
		_expect(not bool(signal.get("full_screen_flash", true)), "%s never relies on full-screen flash" % kind)
		_expect(not bool(signal.get("authoritative_simulation_changed", true)), "%s remains presentation-only" % kind)

	var hazard_onset: Dictionary = _first_signal(signals, &"hazard_onset")
	_expect_equal(hazard_onset.get("icon"), "heat", "actual H01 onset uses frozen heat icon")
	_expect_equal(hazard_onset.get("pattern"), "thermal_lines", "actual H01 onset uses frozen thermal-line pattern")
	_expect(String(hazard_onset.get("source", "")).contains("h01-slice"), "hazard onset caption/source names the actual hazard")

	var brownout: Dictionary = _first_signal(signals, &"brownout_power_loss")
	_expect_equal(brownout.get("icon"), "slashed_power", "actual Brownout renders slashed-power symbol")
	_expect_equal(String(brownout.get("source", "")), "monitor-a", "Brownout names the affected support instance")

	var failure: Dictionary = _first_signal(signals, &"predicate_failure")
	_expect_equal(failure.get("text_label"), "FAILURE", "mandatory failure remains text-labeled")
	_expect_equal(String(failure.get("source", "")), "specimen-a", "mandatory failure names its organism source")
	_expect(String(failure.get("caption", "")).contains("m-stress"), "mandatory failure caption names the failed predicate")

	var rendered_text: String = control.critical_signal_rendered_text()
	_expect(rendered_text.contains("h01-slice"), "rendered rows visibly include hazard source")
	_expect(rendered_text.contains("monitor-a"), "rendered rows visibly include Brownout source")
	_expect(rendered_text.contains("icon=heat"), "rendered rows visibly expose non-color icon language")
	_expect(rendered_text.contains("pattern=thermal_lines"), "rendered rows visibly expose non-color pattern language")
	_expect(rendered_text.contains("FAILURE"), "rendered rows visibly expose failure label")

	var checksums_before: Variant = completed.get("tick_checksums", PackedStringArray())
	var completion_checksum_before: String = String(completed.get("completion_checksum", ""))
	var standard_patch: Dictionary = control.set_accessibility_settings({
		"reduced_motion": false,
		"reduced_flashing": false,
		"master_volume_percent": 100,
		"non_speech_captions": false,
	})
	_expect(bool(standard_patch.get("ok", false)), "rendered presentation settings can change after review without rerunning transit")
	var completed_after_patch: Dictionary = flow.last_completed_result()
	_expect_equal(completed_after_patch.get("tick_checksums", PackedStringArray()), checksums_before, "presentation settings cannot alter authoritative tick hashes")
	_expect_equal(String(completed_after_patch.get("completion_checksum", "")), completion_checksum_before, "presentation settings cannot alter completion checksum")
	var standard_hazard: Dictionary = _first_signal(control.critical_signal_snapshot(), &"hazard_onset")
	_expect_equal(standard_hazard.get("motion_mode"), "standard", "rendered panel updates when Reduced Motion is disabled")
	_expect_equal(standard_hazard.get("flash_mode"), "bounded_fade", "rendered panel updates when Reduced Flashing is disabled")
	_expect(bool(standard_hazard.get("audio_available", false)), "audio may return without becoming authoritative")
	_expect(not bool(standard_hazard.get("caption_visible", true)), "optional non-speech caption preference is respected when audio is available")
	_expect(control.critical_signal_rendered_text().contains("source=h01-slice"), "source remains visible even when optional captions are disabled")

	control.queue_free()
	await tree.process_frame
	return _failures.duplicate()

func _context() -> Dictionary:
	var settings: AccessibilitySettingsModel = AccessibilitySettingsModelScript.new()
	var settings_result: Dictionary = settings.apply_patch({
		"reduced_motion": true,
		"reduced_flashing": true,
		"master_volume_percent": 0,
		"non_speech_captions": false,
	})
	_expect(bool(settings_result.get("ok", false)), "representative no-audio/reduced accessibility profile is valid")
	return {
		"launch_request_token": "launch-accessible-failure",
		"profile_uuid": "profile-accessible",
		"contract_id": "VS-ACCESSIBLE-FAILURE",
		"rules_version": "rules-r1",
		"content_version": "vertical-slice-test-1",
		"contract_definition_checksum": "accessible-failure-definition-checksum",
		"accessibility_settings": settings.snapshot(),
		"total_ticks": 3,
		"simulation_defs": _defs(),
		"mandatory_predicates": [
			{"id": "m-stress", "kind": "STRESS_AT_MOST", "instance_id": "specimen-a", "value": 9},
			{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "PANICKED"},
		],
		"retry_revision_id": "revision-accessible-retry",
		"retry_structural_facts": _legal_facts(),
	}

func _input() -> Dictionary:
	return {
		"route_id": "route-slice",
		"manifest_instance_ids": ["specimen-a"],
		"placements": [
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		],
		"supports": [
			{"instance_id": "monitor-a", "support_id": "S06"},
		],
		"brownout_priority": ["monitor-a"],
		"seed": 101,
	}

func _defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-slice",
			"tick_count": 3,
			"events": [
				{"tick": 2, "duration_ticks": 1, "hazard_id": "h01-slice", "authored_order": 0},
			],
		},
		"hold_definition": {
			"dimensions": [1, 1],
			"blocked_cells": [],
			"power_capacity": 1,
		},
		"hazards_by_id": {
			"h01-slice": {"id": "h01-slice", "family": "H01", "target_scope": "hold", "heat_delta": 6},
		},
		"support_definitions_by_id": {
			"S06": {
				"id": "S06",
				"family": "S06",
				"powered": true,
				"power_draw": 2,
				"supports_degraded_operation": false,
			},
		},
		"thermal_rules": {
			"heat_min": 0,
			"heat_max": 20,
			"transfer_edges": [],
			"vent_by_cell": {},
		},
		"organism_definitions": {
			"specimen-a": {
				"initial_stress": 1,
				"initial_state": "CALM",
				"stress_profile": _stress_profile(),
			},
		},
	}

func _legal_facts() -> Dictionary:
	return {
		"mandatory_manifest_placed": true,
		"overlap_free": true,
		"blocked_free": true,
		"in_bounds": true,
		"orientations_valid": true,
		"zones_valid": true,
		"fixtures_valid": true,
		"links_valid": true,
		"support_resources_valid": true,
		"structural_prerequisites_met": true,
	}

func _stress_profile() -> Dictionary:
	return {
		"heat_safe_max": 2,
		"stress_per_heat_unit": 2,
		"stress_min": 0,
		"stress_max": 20,
		"agitated_enter": 5,
		"agitated_exit": 3,
		"panic_enter": 10,
		"panic_exit": 7,
	}

func _has_signal_kind(signals: Array, kind: StringName) -> bool:
	return not _first_signal(signals, kind).is_empty()

func _first_signal(signals: Array, kind: StringName) -> Dictionary:
	for raw_signal: Variant in signals:
		if raw_signal is Dictionary and String((raw_signal as Dictionary).get("kind", "")) == String(kind):
			return (raw_signal as Dictionary).duplicate(true)
	return {}

func _clear_store(root_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	for suffix: String in ["session.sav", "session.sav.bak", "session.sav.tmp"]:
		var path: String = root_path.path_join(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(value: bool, label: String) -> void:
	if not value:
		_failures.append(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
