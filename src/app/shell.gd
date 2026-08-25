extends Control

const AppBootstrapServiceScript := preload("res://src/app/app_bootstrap_service.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const SaveRecoveryServiceScript := preload("res://src/save/save_recovery_service.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const ACCESSIBLE_VERTICAL_SLICE_CONTROL_PATH := "res://src/ui/accessible_vertical_slice_control.gd"
const SEMANTIC_VERTICAL_SLICE_INPUT_PATH := "res://src/ui/semantic_vertical_slice_input.gd"
const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")
const AccessibilitySettingsModelScript := preload("res://src/ui/accessibility_settings_model.gd")
const SettingsRemapScreenScript := preload("res://src/ui/settings_remap_screen.gd")

const CORE_CONTENT_PATHS: Dictionary = {&"body_plans":"res://content/body_plans", &"campaign":"res://content/campaign", &"challenges":"res://content/challenges", &"contracts":"res://content/contracts", &"hazards":"res://content/hazards", &"holds":"res://content/holds", &"routes":"res://content/routes", &"species":"res://content/species", &"supports":"res://content/supports", &"traits":"res://content/traits"}
const SAVE_ROOT := "user://organism_cargo"

var _bootstrap_service: AppBootstrapService
var _save_store: AtomicSaveStore
var _save_recovery_service: SaveRecoveryService
var _slice_flow: VerticalSliceFlowCoordinator
var _slice_control: VerticalSliceControl
var _semantic_input: Node
var _accessibility_settings: AccessibilitySettingsModel
var _input_remap: InputRemapModel
var _settings_screen: SettingsRemapScreen
var _settings_button: Button

func _ready() -> void:
	InputActionCatalogScript.ensure_registered()
	_accessibility_settings = AccessibilitySettingsModelScript.new(); _input_remap = InputRemapModelScript.new(); _build_persistent_settings_path()
	_bootstrap_service = AppBootstrapServiceScript.new(); var result: Dictionary = _bootstrap_service.boot(CORE_CONTENT_PATHS)
	if not result["ok"]: print("Organism Cargo bootstrap blocked: %s" % String(result["error"])); return
	_save_store = AtomicSaveStoreScript.new(SAVE_ROOT)
	_save_recovery_service = SaveRecoveryServiceScript.new(_save_store)
	_slice_flow = VerticalSliceFlowCoordinatorScript.new(_bootstrap_service.state_machine(), _save_store)
	var recovery_assessment: Dictionary = _save_recovery_service.assess(&"profile")
	if bool(recovery_assessment.get("recovery_required", false)):
		var recovery_entry: Dictionary = _slice_flow.enter_save_recovery()
		if not bool(recovery_entry.get("ok", false)):
			print("Organism Cargo save recovery blocked: %s" % String(recovery_entry.get("error", "unknown"))); return
	var context: Dictionary = _vertical_slice_context(String(result["content_version"]))
	var slice_instance: Object = _new_script_instance(ACCESSIBLE_VERTICAL_SLICE_CONTROL_PATH)
	if not slice_instance is VerticalSliceControl:
		print("Organism Cargo accessible control blocked: script unavailable")
		return
	_slice_control = slice_instance as VerticalSliceControl
	_slice_control.name = "VerticalSliceControl"; _slice_control.set_anchors_and_offsets_preset(Control.PRESET_CENTER); _slice_control.custom_minimum_size = Vector2(640, 360); add_child(_slice_control)
	var configure_value: Variant = _slice_control.call("configure", _slice_flow, context)
	if configure_value != null and configure_value is Dictionary and not bool((configure_value as Dictionary).get("ok", true)):
		print("Organism Cargo accessible control blocked: %s" % String((configure_value as Dictionary).get("error", "unknown")))
		return
	var semantic_instance: Object = _new_script_instance(SEMANTIC_VERTICAL_SLICE_INPUT_PATH)
	if not semantic_instance is Node:
		print("Organism Cargo semantic input blocked: script unavailable")
		return
	_semantic_input = semantic_instance as Node; _semantic_input.name = "SemanticVerticalSliceInput"; add_child(_semantic_input)
	var semantic_result_value: Variant = _semantic_input.call("configure", _slice_control, _slice_flow, context)
	var semantic_result: Dictionary = semantic_result_value if semantic_result_value is Dictionary else {"ok": false, "error": "invalid_semantic_config_result"}
	if not bool(semantic_result.get("ok", false)): print("Organism Cargo semantic input blocked: %s" % String(semantic_result.get("error", "unknown")))
	move_child(_settings_screen, get_child_count() - 1); move_child(_settings_button, get_child_count() - 1)
	print("Organism Cargo bootstrap ready: content=%s state=%s" % [String(result["content_version"]), str(_bootstrap_service.state_machine().current_state())])

func flow_controller() -> VerticalSliceFlowCoordinator: return _slice_flow
func slice_control() -> VerticalSliceControl: return _slice_control
func semantic_input_controller() -> Node: return _semantic_input
func settings_screen() -> SettingsRemapScreen: return _settings_screen
func settings_button() -> Button: return _settings_button
func save_recovery_service() -> SaveRecoveryService: return _save_recovery_service
func accessibility_settings_snapshot() -> Dictionary: return {} if _accessibility_settings == null else _accessibility_settings.snapshot()
func input_remap_snapshot() -> Dictionary: return {} if _input_remap == null else _input_remap.snapshot()

func open_settings() -> void:
	if _settings_screen == null: return
	_settings_screen.visible = true
	if _slice_control != null: _slice_control.visible = false
	if _semantic_input != null: _semantic_input.set_process_unhandled_input(false)
	_settings_screen.focus_entry()

func close_settings() -> void:
	if _settings_screen == null: return
	_settings_screen.visible = false
	if _slice_control != null: _slice_control.visible = true
	if _semantic_input != null: _semantic_input.set_process_unhandled_input(true)
	if _settings_button != null: _settings_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _settings_screen == null or not _settings_screen.visible: return
	if _settings_screen.capture_action() == &"":
		var device := InputActionCatalogScript.device_for_event(event)
		if device != &"" and device != _settings_screen.last_input_device(): _settings_screen.note_input_source(device)
		if event.is_action_pressed(&"cancel"):
			close_settings(); get_viewport().set_input_as_handled()

func _build_persistent_settings_path() -> void:
	_settings_button = Button.new(); _settings_button.name = "SettingsButton"; _settings_button.text = "Settings"; _settings_button.focus_mode = Control.FOCUS_ALL
	_settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT); _settings_button.position = Vector2(-132, 16); _settings_button.size = Vector2(116, 40); _settings_button.pressed.connect(open_settings); add_child(_settings_button)
	_settings_screen = SettingsRemapScreenScript.new(_input_remap); _settings_screen.name = "SettingsRemapScreen"; _settings_screen.visible = false; _settings_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _settings_screen.close_requested.connect(close_settings); add_child(_settings_screen)

func _vertical_slice_context(content_version: String) -> Dictionary:
	var contract_payload: Dictionary = _payload(&"contracts", &"VS01"); var hold_payload: Dictionary = _payload(&"holds", &"VS_HOLD_01"); var species_by_id: Dictionary = {}
	for document: ContentDocument in _bootstrap_service.content_registry().ordered_documents(&"species"):
		if document.id in [&"O01", &"O03"]: species_by_id[String(document.id)] = document.payload.duplicate(true)
	var contract_checksum: String = JSON.stringify(contract_payload, "", true, true).sha256_text()
	return {"planning_contract_payload":contract_payload, "planning_hold_payload":hold_payload, "planning_species_by_id":species_by_id, "planning_route_id":"route-slice", "planning_seed":101,
		"launch_request_token":"shell-vs01-launch", "profile_uuid":"local-profile", "contract_id":"VS01", "rules_version":"vertical-slice-r1", "content_version":content_version,
		"contract_definition_checksum":contract_checksum, "accessibility_settings":accessibility_settings_snapshot(), "input_remap":input_remap_snapshot(), "save_recovery_service":_save_recovery_service,
		"campaign_completed_contract_count":48, "campaign_total_contract_count":48, "campaign_medal_summary":"Campaign medals remain maxima and every completed node stays replayable.", "campaign_challenge_summary":"Challenge access remains governed by the frozen Bronze(C16) progression gate.", "total_ticks":1,
		"simulation_defs":{"route_profile":{"id":"route-slice","tick_count":1,"events":[]}, "hold_definition":{"dimensions":[3,2],"blocked_cells":[[2,1]]}, "hazards_by_id":{},
			"thermal_rules":{"heat_min":0,"heat_max":20,"transfer_edges":[],"vent_by_cell":{}}, "organism_definitions":{"specimen-a":{"initial_stress":1,"initial_state":"CALM","stress_profile":_stress_profile()}, "specimen-b":{"initial_stress":1,"initial_state":"CALM","stress_profile":_stress_profile()}}},
		"mandatory_predicates":[{"id":"vs01-state","kind":"PRIMARY_STATE_IS","instance_id":"specimen-a","value":"CALM"}], "retry_revision_id":"shell-vs01-retry", "retry_structural_facts":_legal_facts()}

func _payload(kind: StringName, id: StringName) -> Dictionary:
	for document: ContentDocument in _bootstrap_service.content_registry().ordered_documents(kind):
		if document.id == id: return document.payload.duplicate(true)
	return {}

func _legal_facts() -> Dictionary:
	return {"mandatory_manifest_placed":true,"overlap_free":true,"blocked_free":true,"in_bounds":true,"orientations_valid":true,"zones_valid":true,"fixtures_valid":true,"links_valid":true,"support_resources_valid":true,"structural_prerequisites_met":true}

func _stress_profile() -> Dictionary:
	return {"heat_safe_max":2,"stress_per_heat_unit":2,"stress_min":0,"stress_max":20,"agitated_enter":5,"agitated_exit":3,"panic_enter":10,"panic_exit":7}

func _new_script_instance(path: String) -> Object:
	var script: GDScript = load(path) as GDScript
	if script == null:
		return null
	return script.new()
