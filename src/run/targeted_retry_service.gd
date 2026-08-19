class_name TargetedRetryService
extends RefCounted

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")

var _state_machine: AppStateMachine
var _planning: PlanningSession

func _init(p_state_machine: AppStateMachine, p_planning: PlanningSession) -> void:
	_state_machine = p_state_machine
	_planning = p_planning

func begin_retry(completed_run: Dictionary, retry_revision_id: String, structural_facts: Dictionary) -> Dictionary:
	if _state_machine.current_state() != AppStateMachineScript.State.CAUSAL_REVIEW:
		return _failure("invalid_state")
	if retry_revision_id.strip_edges().is_empty():
		return _failure("missing_retry_revision_id")
	var source_run_id: String = String(completed_run.get("run_id", ""))
	var source_revision_id: String = String(completed_run.get("planning_revision_id", ""))
	if source_run_id.is_empty() or source_revision_id.is_empty():
		return _failure("missing_completed_run_identity")
	var committed_input_value: Variant = completed_run.get("canonical_committed_input", null)
	if not committed_input_value is Dictionary:
		return _failure("missing_committed_input")
	var committed_input: Dictionary = committed_input_value
	var editable_baseline: Dictionary = committed_input.duplicate(true)
	if not _state_machine.transition_to(AppStateMachineScript.State.PLANNING):
		return _failure("retry_transition_failed")
	var planning_snapshot: Dictionary = _planning.apply_revision(retry_revision_id, editable_baseline, structural_facts)
	if not bool(planning_snapshot.get("ok", false)):
		return _failure("retry_seed_failed:%s" % String(planning_snapshot.get("error", "unknown")))
	planning_snapshot["source_run_id"] = source_run_id
	planning_snapshot["source_planning_revision_id"] = source_revision_id
	return planning_snapshot

static func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"planning_revision_id": "",
		"canonical_input": {},
		"source_run_id": "",
		"source_planning_revision_id": "",
		"error": error,
	}
