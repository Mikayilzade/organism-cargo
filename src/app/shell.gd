extends Control

const AppBootstrapServiceScript := preload("res://src/app/app_bootstrap_service.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const AccessibleVerticalSliceControlScript := preload("res://src/ui/accessible_vertical_slice_control.gd")
const SemanticVerticalSliceInputScript := preload("res://src/ui/semantic_vertical_slice_input.gd")
const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")
const AccessibilitySettingsModelScript := preload("res://src/ui/accessibility_settings_model.gd")
const SettingsRemapControlScript := preload("res://src/ui/settings_remap_control.gd")

const CORE_CONTENT_PATHS: Dictionary = {
	&"body_plans": "res://content/body_plans",
	&"campaign": "res://content/campaign",
	&"challenges": "res://content/challenges",
	&"contracts": "res://content/contracts",
	&"hazards": "res://content/hazards",
	&"holds": "res://content/holds",
	&"routes": "res://content/routes",
	&"species": "res://content/species",
	&"supports": "res://content/supports",
	&"traits": "res://content/traits",
}

const SAVE_ROOT := "user://organism_cargo"

var _bootstrap_service: AppBootstrapService
var _save_store: AtomicSaveStore
var _slice_flow: VerticalSliceFlowCoordinator
var _slice_control: AccessibleVerticalSliceControl
var _semantic_input: SemanticVerticalSliceInput
var _accessibility_settings: AccessibilitySettingsModel
var _input_remap: InputRemapModel
var _settings_remap: SettingsRemapControl

func _ready() -> void:
	InputActionCatalogScript.ensure_registered()
	_accessibility_settings = AccessibilitySettingsModelScript.new()
	_input_remap = InputRemapModelScript.new()
	_bootstrap_service = AppBootstrapServiceScript.new()
	var result: Dictionary = _bootstrap_service.boot(CORE_CONTENT_PATHS)
	if not result["ok"]:
		print("Organism Cargo bootstrap blocked: %s" % String(result["error"]))
		return
	_save_store = AtomicSaveStoreScript.new(SAVE_ROOT)
	_slice_flow = VerticalSliceFlowCoordinatorScript.new(
		_bootstrap_service.state_machine(),
		_save_store
	)
	var context: Dictionary = _vertical_slice_context(String(result["content_version"]))
	_slice_control = AccessibleVerticalSliceControlScript.new()
	_slice_control.name = "VerticalSliceControl"
	_slice_control.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_slice_control.custom_minimum_size = Vector2(640, 360)
	add_child(_slice_control)
	_slice_control.configure(_slice_flow, context)
	_semantic_input = SemanticVerticalSliceInputScript.new()
	_semantic_input.name = "SemanticVerticalSliceInput"
	add_child(_semantic_input)
	var semantic_result: Dictionary = _semantic_input.configure(_slice_control, _slice_flow, context)
	if not bool(semantic_result.get("ok", false)):
		print("Organism Cargo semantic input blocked: %s" % String(semantic_result.get("error", "unknown")))
	_settings_remap = SettingsRemapControlScript.new()
	_settings_remap.name = "SettingsRemapControl"
	_settings_remap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_remap.offset_left = 80.0
	_settings_remap.offset_top = 40.0
	_settings_remap.offset_right = -80.0
	_settings_remap.offset_bottom = -40.0
	_settings_remap.visible = false
	add_child(_settings_remap)
	var settings_result: Dictionary = _settings_remap.configure(_input_remap)
	if not bool(settings_result.get("ok", false)):
		print("Organism Cargo settings remap blocked: %s" % String(settings_result.get("error", "unknown")))
	_settings_remap.close_requested.connect(hide_settings)
	print("Organism Cargo bootstrap ready: content=%s state=%s" % [
		String(result["content_version"]),
		str(_bootstrap_service.state_machine().current_state()),
	])

func flow_controller() -> VerticalSliceFlowCoordinator:
	return _slice_flow

func slice_control() -> AccessibleVerticalSliceControl:
	return _slice_control

func semantic_input_controller() -> SemanticVerticalSliceInput:
	return _semantic_input

func settings_remap_control() -> SettingsRemapControl:
	return _settings_remap

func show_settings(device: StringName = InputActionCatalogScript.DEVICE_KEYBOARD) -> Dictionary:
	if _settings_remap == null:
		return {"ok": false, "error": "settings_not_ready"}
	var result: Dictionary = _settings_remap.notify_input_source(device)
	if not bool(result.get("ok", false)):
		return result
	_settings_remap.visible = true
	_settings_remap.move_to_front()
	return {"ok": true, "error": "", "device": device}

func hide_settings() -> void:
	if _settings_remap != null:
		_settings_remap.visible = false

func accessibility_settings_snapshot() -> Dictionary:
	return {} if _accessibility_settings == null else _accessibility_settings.snapshot()

func input_remap_snapshot() -> Dictionary:
	return {} if _input_remap == null else _input_remap.snapshot()

func _vertical_slice_context(content_version: String) -> Dictionary:
	var contract_payload: Dictionary = _payload(&"contracts", &"VS01")
	var hold_payload: Dictionary = _payload(&"holds", &"VS_HOLD_01")
	var species_by_id: Dictionary = {}
	for document: ContentDocument in _bootstrap_service.content_registry().ordered_documents(&"species"):
		if document.id in [&"O01", &"O03"]:
			species_by_id[String(document.id)] = document.payload.duplicate(true)
	var contract_checksum: String = JSON.stringify(contract_payload, "", true, true).sha256_text()
	return {
		"planning_contract_payload": contract_payload,
		"planning_hold_payload": hold_payload,
		"planning_species_by_id": species_by_id,
		"planning_route_id": "route-slice",
		"planning_seed": 101,
		"launch_request_token": "shell-vs01-launch",
		"profile_uuid": "local-profile",
		"contract_id": "VS01",
		"rules_version": "vertical-slice-r1",
		"content_version": content_version,
		"contract_definition_checksum": contract_checksum,
		"accessibility_settings": accessibility_settings_snapshot(),
		"input_remap": input_remap_snapshot(),
		"total_ticks": 1,
		"simulation_defs": {
			"route_profile": {"id": "route-slice", "tick_count": 1, "events": []},
			"hold_definition": {"dimensions": [3, 2], "blocked_cells": [[2, 1]]},
			"hazards_by_id": {},
			"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
			"organism_definitions": {
				"specimen-a": {"initial_stress": 1, "initial_state": "CALM", "stress_profile": _stress_profile()},
				"specimen-b": {"initial_stress": 1, "initial_state": "CALM", "stress_profile": _stress_profile()},
			},
		},
		"mandatory_predicates": [{"id": "vs01-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "CALM"}],
		"retry_revision_id": "shell-vs01-retry",
		"retry_structural_facts": _legal_facts(),
	}

func _payload(kind: StringName, id: StringName) -> Dictionary:
	for document: ContentDocument in _bootstrap_service.content_registry().ordered_documents(kind):
		if document.id == id:
			return document.payload.duplicate(true)
	return {}

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
