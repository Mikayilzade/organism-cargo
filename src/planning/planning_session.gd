class_name PlanningSession
extends RefCounted

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const PlanningValidatorScript := preload("res://src/planning/planning_validator.gd")

var _state_machine: AppStateMachine
var _planning_revision_id: String = ""
var _canonical_input: Dictionary = {}
var _validation: Dictionary = {
	"structural_legal": false,
	"reasons": [],
	"mandatory_manifest_placed": false,
	"structural_prerequisites_met": false,
}

func _init(p_state_machine: AppStateMachine) -> void:
	_state_machine = p_state_machine

func apply_revision(planning_revision_id: String, canonical_input: Dictionary, structural_facts: Dictionary) -> Dictionary:
	if _state_machine.current_state() != AppStateMachineScript.State.PLANNING:
		return _failure("invalid_state")
	if planning_revision_id.strip_edges().is_empty():
		return _failure("missing_planning_revision_id")
	_planning_revision_id = planning_revision_id
	_canonical_input = canonical_input.duplicate(true)
	_validation = PlanningValidatorScript.validate(structural_facts)
	return snapshot()

func snapshot() -> Dictionary:
	return {
		"ok": not _planning_revision_id.is_empty(),
		"planning_revision_id": _planning_revision_id,
		"canonical_input": _canonical_input.duplicate(true),
		"structural_legal": bool(_validation.get("structural_legal", false)),
		"reasons": _validation.get("reasons", []).duplicate(),
		"mandatory_manifest_placed": bool(_validation.get("mandatory_manifest_placed", false)),
		"structural_prerequisites_met": bool(_validation.get("structural_prerequisites_met", false)),
		"error": "",
	}

func request_launch_confirm() -> Dictionary:
	if _state_machine.current_state() != AppStateMachineScript.State.PLANNING:
		return _failure("invalid_state")
	if _planning_revision_id.is_empty():
		return _failure("missing_planning_revision")
	if not bool(_validation.get("structural_legal", false)):
		var failure: Dictionary = _failure("structural_illegal")
		failure["reasons"] = _validation.get("reasons", []).duplicate()
		failure["mandatory_manifest_placed"] = bool(_validation.get("mandatory_manifest_placed", false))
		failure["structural_prerequisites_met"] = bool(_validation.get("structural_prerequisites_met", false))
		return failure
	if not _state_machine.transition_to(AppStateMachineScript.State.LAUNCH_CONFIRM):
		return _failure("launch_confirm_transition_failed")
	var result: Dictionary = snapshot()
	result["ok"] = true
	return result

func cancel_launch_confirm() -> bool:
	if _state_machine.current_state() != AppStateMachineScript.State.LAUNCH_CONFIRM:
		return false
	return _state_machine.transition_to(AppStateMachineScript.State.PLANNING)

static func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"planning_revision_id": "",
		"canonical_input": {},
		"structural_legal": false,
		"reasons": [],
		"mandatory_manifest_placed": false,
		"structural_prerequisites_met": false,
		"error": error,
	}
