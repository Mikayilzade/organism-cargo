extends Control

const AppBootstrapServiceScript := preload("res://src/app/app_bootstrap_service.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const VerticalSliceControlScript := preload("res://src/ui/vertical_slice_control.gd")

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
var _slice_control: VerticalSliceControl

func _ready() -> void:
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
	_slice_control = VerticalSliceControlScript.new()
	_slice_control.name = "VerticalSliceControl"
	_slice_control.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_slice_control.custom_minimum_size = Vector2(560, 240)
	add_child(_slice_control)
	_slice_control.configure(_slice_flow)
	print("Organism Cargo bootstrap ready: content=%s state=%s" % [
		String(result["content_version"]),
		str(_bootstrap_service.state_machine().current_state()),
	])

func flow_controller() -> VerticalSliceFlowCoordinator:
	return _slice_flow

func slice_control() -> VerticalSliceControl:
	return _slice_control
