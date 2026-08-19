extends Control

const AppBootstrapServiceScript := preload("res://src/app/app_bootstrap_service.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")

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

func _ready() -> void:
	# Presentation remains non-authoritative. The persistent shell owns the
	# composition root and scene-flow coordinator; deterministic systems and
	# validated content remain scene-free and independently testable.
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
	print("Organism Cargo bootstrap ready: content=%s state=%s" % [
		String(result["content_version"]),
		str(_bootstrap_service.state_machine().current_state()),
	])

func flow_controller() -> VerticalSliceFlowCoordinator:
	return _slice_flow
