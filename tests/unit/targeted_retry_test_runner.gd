extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const LaunchCommitServiceScript := preload("res://src/run/launch_commit_service.gd")
const PlanningSessionScript := preload("res://src/planning/planning_session.gd")
const TargetedRetryServiceScript := preload("res://src/run/targeted_retry_service.gd")

var failures: int = 0
var run_counter: int = 0

func _init() -> void:
	_test_targeted_retry_preserves_completed_run_and_creates_new_launch_identity()
	if failures == 0:
		print("targeted_retry_test_runner: PASS")
		quit(0)
	else:
		push_error("targeted_retry_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_targeted_retry_preserves_completed_run_and_creates_new_launch_identity() -> void:
	var root: String = "user://targeted_retry_fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	for suffix: String in ["session.sav", "session.sav.bak", "session.sav.tmp"]:
		_remove_if_exists(root.path_join(suffix))

	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect_true(state_machine.transition_to(AppStateMachine.State.TITLE), "boot to title")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "title to map")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "map to brief")
	_expect_true(state_machine.transition_to(AppStateMachine.State.PLANNING), "brief to planning")

	var planning: PlanningSession = PlanningSessionScript.new(state_machine)
	var original_input: Dictionary = _input([{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}])
	var original_revision: Dictionary = planning.apply_revision("revision-original", original_input, _valid_structural_facts())
	_expect_true(bool(original_revision["structural_legal"]), "original plan is launchable")
	var confirm: Dictionary = planning.request_launch_confirm()
	_expect_true(bool(confirm["ok"]), "original plan enters launch confirm")

	var save_store: AtomicSaveStore = AtomicSaveStoreScript.new(root)
	var launch_service: LaunchCommitService = LaunchCommitServiceScript.new(state_machine, save_store, Callable(self, "_next_run_id"))
	var first_launch: Dictionary = launch_service.request_launch(
		"launch-token-original", "revision-original", true, "profile-retry", "contract-retry",
		confirm["canonical_input"], "rules-r1", "content-c1", "contract-checksum"
	)
	_expect_equal(String(first_launch["run_id"]), "run-1", "first launch identity")
	_expect_true(state_machine.accept_completed_transit({
		"ok": true,
		"completed": true,
		"delivery_result": {"ok": true, "success": false},
		"next_state": "CAUSAL_REVIEW",
	}), "completed transit enters causal review")

	var loaded: Dictionary = save_store.load(&"session")
	_expect_true(bool(loaded["ok"]), "completed run record reloads")
	if not bool(loaded["ok"]):
		return
	var envelope: SaveEnvelope = loaded["envelope"]
	var completed_run: Dictionary = envelope.payload["committed_run"]
	var completed_run_before_retry: Dictionary = completed_run.duplicate(true)

	var retry_service: TargetedRetryService = TargetedRetryServiceScript.new(state_machine, planning)
	var retry: Dictionary = retry_service.begin_retry(completed_run, "revision-retry-baseline", _valid_structural_facts())
	_expect_true(bool(retry["ok"]), "causal review can begin targeted retry")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.PLANNING, "retry returns ownership to planning")
	_expect_equal(String(retry["source_run_id"]), "run-1", "retry records immutable source run identity")
	_expect_equal(retry["canonical_input"], completed_run_before_retry["canonical_committed_input"], "unchanged retry baseline is byte-equivalent at Variant level")
	_expect_equal(completed_run, completed_run_before_retry, "retry seeding does not mutate authoritative completed run")

	var retry_input_value: Variant = retry["canonical_input"]
	_expect_true(retry_input_value is Dictionary, "retry canonical input remains a dictionary")
	if not retry_input_value is Dictionary:
		return
	var retry_input: Dictionary = retry_input_value
	var edited_input: Dictionary = retry_input.duplicate(true)
	var placements: Array = edited_input["placements"]
	placements[0]["anchor"] = [1, 0]
	var edited_revision: Dictionary = planning.apply_revision("revision-retry-edited", edited_input, _valid_structural_facts())
	_expect_true(bool(edited_revision["structural_legal"]), "retry edit remains launchable")
	var edited_confirm: Dictionary = planning.request_launch_confirm()
	_expect_true(bool(edited_confirm["ok"]), "edited retry enters launch confirm")
	var second_launch: Dictionary = launch_service.request_launch(
		"launch-token-retry", "revision-retry-edited", true, "profile-retry", "contract-retry",
		edited_confirm["canonical_input"], "rules-r1", "content-c1", "contract-checksum"
	)
	_expect_equal(String(second_launch["run_id"]), "run-2", "edited retry receives new launch identity")
	_expect_true(String(second_launch["run_id"]) != String(first_launch["run_id"]), "retry launch cannot reuse prior run identity")
	_expect_equal(completed_run, completed_run_before_retry, "new launch does not mutate retained completed-run snapshot")

func _next_run_id() -> String:
	run_counter += 1
	return "run-%d" % run_counter

func _input(placements: Array) -> Dictionary:
	return {
		"route_id": "route-slice",
		"manifest_instance_ids": ["specimen-a"],
		"placements": placements,
		"supports": [],
		"seed": 101,
	}

func _valid_structural_facts() -> Dictionary:
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

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
