class_name VerticalSliceFlowCoordinator
extends RefCounted

const PlanningSessionScript := preload("res://src/planning/planning_session.gd")
const LaunchCommitServiceScript := preload("res://src/run/launch_commit_service.gd")
const DeliveryCompletionRunnerScript := preload("res://src/sim/delivery_completion_runner.gd")
const CausalReviewEvidenceBuilderScript := preload("res://src/sim/causal_review_evidence_builder.gd")
const TargetedRetryServiceScript := preload("res://src/run/targeted_retry_service.gd")

var _state_machine: AppStateMachine
var _save_store: AtomicSaveStore
var _planning: PlanningSession
var _launch: LaunchCommitService
var _delivery: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
var _review_builder: CausalReviewEvidenceBuilder = CausalReviewEvidenceBuilderScript.new()
var _retry: TargetedRetryService
var _last_completed_result: Dictionary = {}
var _last_review: Dictionary = {}

func _init(
	p_state_machine: AppStateMachine,
	p_save_store: AtomicSaveStore,
	p_run_id_factory: Callable = Callable()
) -> void:
	_state_machine = p_state_machine
	_save_store = p_save_store
	_planning = PlanningSessionScript.new(_state_machine)
	_launch = LaunchCommitServiceScript.new(_state_machine, _save_store, p_run_id_factory)
	_retry = TargetedRetryServiceScript.new(_state_machine, _planning)

func enter_campaign_map() -> bool:
	return _state_machine.transition_to(AppStateMachine.State.CAMPAIGN_MAP)

func select_contract() -> bool:
	return _state_machine.transition_to(AppStateMachine.State.CONTRACT_BRIEF)

func begin_planning() -> bool:
	return _state_machine.transition_to(AppStateMachine.State.PLANNING)

func apply_plan_from_content(
	planning_revision_id: String,
	canonical_input: Dictionary,
	contract_payload: Dictionary,
	hold_payload: Dictionary,
	species_by_id: Dictionary
) -> Dictionary:
	return _planning.apply_revision_from_content(
		planning_revision_id,
		canonical_input,
		contract_payload,
		hold_payload,
		species_by_id
	)

func apply_plan(
	planning_revision_id: String,
	canonical_input: Dictionary,
	structural_facts: Dictionary
) -> Dictionary:
	return _planning.apply_revision(planning_revision_id, canonical_input, structural_facts)

func request_launch_confirm() -> Dictionary:
	return _planning.request_launch_confirm()

func cancel_launch_confirm() -> bool:
	return _planning.cancel_launch_confirm()

func commit_launch(
	launch_request_token: String,
	profile_uuid: String,
	contract_id: String,
	rules_version: String,
	content_version: String,
	expected_contract_definition_checksum: String,
	generator_version: String = ""
) -> Dictionary:
	var snapshot: Dictionary = _planning.snapshot()
	if not bool(snapshot.get("ok", false)):
		return _failure("missing_planning_revision")
	var committed: Dictionary = _launch.request_launch(
		launch_request_token,
		String(snapshot["planning_revision_id"]),
		bool(snapshot["structural_legal"]),
		profile_uuid,
		contract_id,
		snapshot["canonical_input"],
		rules_version,
		content_version,
		expected_contract_definition_checksum,
		generator_version
	)
	if not bool(committed.get("ok", false)):
		return committed
	var loaded: Dictionary = _load_committed_run()
	if not bool(loaded.get("ok", false)):
		return _failure("committed_run_reload_failed")
	committed["committed_run"] = loaded["committed_run"]
	return committed

func complete_transit(
	total_ticks: int,
	simulation_defs: Dictionary,
	mandatory_predicates: Array
) -> Dictionary:
	if _state_machine.current_state() != AppStateMachine.State.TRANSIT_PLAYBACK:
		return _failure("invalid_state")
	var loaded: Dictionary = _load_committed_run()
	if not bool(loaded.get("ok", false)):
		return _failure("missing_committed_run")
	var committed_run: Dictionary = loaded["committed_run"]
	var completed: Dictionary = _delivery.simulate_and_complete(
		committed_run,
		total_ticks,
		simulation_defs,
		mandatory_predicates
	)
	if not bool(completed.get("ok", false)):
		return completed
	if not _state_machine.accept_completed_transit(completed):
		return _failure("causal_review_transition_failed")
	var review: Dictionary = _review_builder.build(completed)
	if not bool(review.get("ok", false)):
		return _failure("causal_review_build_failed:%s" % String(review.get("error", "unknown")))
	_last_completed_result = completed.duplicate(true)
	_last_review = review.duplicate(true)
	return {
		"ok": true,
		"error": "",
		"committed_run": committed_run.duplicate(true),
		"completed_result": _last_completed_result.duplicate(true),
		"review": _last_review.duplicate(true),
	}

func begin_retry(retry_revision_id: String, structural_facts: Dictionary) -> Dictionary:
	var loaded: Dictionary = _load_committed_run()
	if not bool(loaded.get("ok", false)):
		return _failure("missing_committed_run")
	return _retry.begin_retry(loaded["committed_run"], retry_revision_id, structural_facts)

func reset_contract(reset_revision_id: String, canonical_input: Dictionary, structural_facts: Dictionary) -> Dictionary:
	if _state_machine.current_state() != AppStateMachine.State.CAUSAL_REVIEW:
		return _failure("invalid_state")
	if reset_revision_id.strip_edges().is_empty():
		return _failure("missing_reset_revision_id")
	if not _state_machine.transition_to(AppStateMachine.State.PLANNING):
		return _failure("reset_transition_failed")
	var snapshot: Dictionary = _planning.apply_revision(reset_revision_id, canonical_input, structural_facts)
	if not bool(snapshot.get("ok", false)):
		return _failure("reset_seed_failed:%s" % String(snapshot.get("error", "unknown")))
	snapshot["reset_contract"] = true
	return snapshot

func return_to_campaign_map() -> Dictionary:
	if _state_machine.current_state() not in [AppStateMachine.State.CAUSAL_REVIEW, AppStateMachine.State.RESULTS, AppStateMachine.State.PLANNING, AppStateMachine.State.CONTRACT_BRIEF]:
		return _failure("invalid_state")
	if not _state_machine.transition_to(AppStateMachine.State.CAMPAIGN_MAP):
		return _failure("campaign_map_transition_failed")
	return {"ok": true, "error": ""}

func open_codex() -> Dictionary:
	if not _state_machine.enter_codex():
		return _failure("codex_transition_failed")
	return {"ok": true, "error": "", "return_state": _state_machine.codex_return_state()}

func close_codex() -> Dictionary:
	if not _state_machine.exit_codex():
		return _failure("codex_return_failed")
	return {"ok": true, "error": "", "state": _state_machine.current_state()}

func current_state() -> AppStateMachine.State:
	return _state_machine.current_state()

func planning_snapshot() -> Dictionary:
	return _planning.snapshot()

func last_completed_result() -> Dictionary:
	return _last_completed_result.duplicate(true)

func last_review() -> Dictionary:
	return _last_review.duplicate(true)

func _load_committed_run() -> Dictionary:
	var loaded: Dictionary = _save_store.load(&"session")
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "committed_run": {}}
	var envelope: SaveEnvelope = loaded["envelope"]
	var record_value: Variant = envelope.payload.get("committed_run", null)
	if not record_value is Dictionary:
		return {"ok": false, "committed_run": {}}
	var record: Dictionary = record_value
	return {"ok": true, "committed_run": record.duplicate(true)}

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
