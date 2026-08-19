extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const LaunchCommitServiceScript := preload("res://src/run/launch_commit_service.gd")

var failures: int = 0
var allocated_run_ids: int = 0

func _init() -> void:
	_test_exactly_once_launch_commit()
	if failures == 0:
		print("launch_commit_test_runner: PASS")
		quit(0)
	else:
		push_error("launch_commit_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_exactly_once_launch_commit() -> void:
	var root: String = "user://launch_commit_fixture"
	var absolute_root: String = ProjectSettings.globalize_path(root)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	_remove_if_exists(root.path_join("session.sav"))
	_remove_if_exists(root.path_join("session.sav.bak"))
	_remove_if_exists(root.path_join("session.sav.tmp"))

	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect_true(state_machine.transition_to(AppStateMachine.State.TITLE), "boot to title")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "title to map")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "map to brief")
	_expect_true(state_machine.transition_to(AppStateMachine.State.PLANNING), "brief to planning")
	_expect_true(state_machine.transition_to(AppStateMachine.State.LAUNCH_CONFIRM), "planning to launch confirm")

	var save_store: AtomicSaveStore = AtomicSaveStoreScript.new(root)
	var service: LaunchCommitService = LaunchCommitServiceScript.new(state_machine, save_store, Callable(self, "_next_run_id"))
	var canonical_input: Dictionary = {
		"route_id": "route_bootstrap",
		"manifest_instance_ids": ["specimen_b", "specimen_a"],
		"placements": [
			{"instance_id": "specimen_a", "anchor": [1, 2], "orientation": 0},
			{"instance_id": "specimen_b", "anchor": [3, 4], "orientation": 1},
		],
		"seed": 17,
	}
	var contract_definition_checksum: String = "contract-def-checksum-1"

	var illegal: Dictionary = service.request_launch(
		"token-illegal",
		"revision-1",
		false,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1",
		contract_definition_checksum
	)
	_expect_true(not bool(illegal["ok"]), "structurally illegal launch rejected")
	_expect_equal(String(illegal["error"]), "structural_illegal", "illegal launch reason")
	_expect_equal(allocated_run_ids, 0, "illegal launch allocates no run id")

	var missing_contract_checksum: Dictionary = service.request_launch(
		"token-missing-contract-checksum",
		"revision-1",
		true,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1",
		""
	)
	_expect_true(not bool(missing_contract_checksum["ok"]), "missing contract definition checksum rejected")
	_expect_equal(String(missing_contract_checksum["error"]), "missing_contract_definition_checksum", "missing contract checksum reason")
	_expect_equal(allocated_run_ids, 0, "missing contract checksum allocates no run id")

	var committed: Dictionary = service.request_launch(
		"token-1",
		"revision-1",
		true,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1",
		contract_definition_checksum
	)
	_expect_true(bool(committed["ok"]), "legal launch commits")
	_expect_true(not bool(committed["duplicate"]), "first launch is not duplicate")
	_expect_equal(String(committed["run_id"]), "run-fixed-1", "allocated run id retained")
	_expect_equal(allocated_run_ids, 1, "first commit allocates once")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.TRANSIT_PLAYBACK, "durable commit precedes transit state")

	var loaded: Dictionary = save_store.load(&"session")
	_expect_true(bool(loaded["ok"]), "committed session is durable")
	if bool(loaded["ok"]):
		var envelope: SaveEnvelope = loaded["envelope"]
		var record: Dictionary = envelope.payload["committed_run"]
		_expect_equal(String(record["run_id"]), "run-fixed-1", "durable run id")
		_expect_equal(String(record["planning_revision_id"]), "revision-1", "durable planning revision")
		_expect_equal(String(record["lifecycle_state"]), "COMMITTED", "durable lifecycle")
		_expect_equal(String(record["expected_contract_definition_checksum"]), contract_definition_checksum, "durable contract definition checksum")
		_expect_true(int(record["launch_timestamp_unix"]) > 0, "recovery timestamp recorded")
		var expected_committed_input: Dictionary = canonical_input.duplicate(true)
		expected_committed_input["contract_id"] = "contract-1"
		expected_committed_input["rules_version"] = "rules-r1"
		expected_committed_input["content_version"] = "content-c1"
		expected_committed_input["generator_version"] = ""
		expected_committed_input["expected_contract_definition_checksum"] = contract_definition_checksum
		_expect_equal(record["canonical_committed_input"], expected_committed_input, "canonical committed input includes compatibility identity")
		var expected_checksum: String = JSON.stringify(expected_committed_input, "", true, true).sha256_text()
		_expect_equal(String(record["committed_input_checksum"]), expected_checksum, "committed input checksum covers compatibility identity")

	var duplicate: Dictionary = service.request_launch(
		"token-duplicate-callback",
		"revision-1",
		true,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1",
		contract_definition_checksum
	)
	_expect_true(bool(duplicate["ok"]), "duplicate callback returns existing commit")
	_expect_true(bool(duplicate["duplicate"]), "duplicate callback identified")
	_expect_equal(String(duplicate["run_id"]), "run-fixed-1", "duplicate returns same run id")
	_expect_equal(allocated_run_ids, 1, "duplicate allocates no second run id")

	var wrong_revision: Dictionary = service.request_launch(
		"token-2",
		"revision-2",
		true,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1",
		contract_definition_checksum
	)
	_expect_true(not bool(wrong_revision["ok"]), "new revision cannot launch from transit")
	_expect_equal(String(wrong_revision["error"]), "invalid_state", "transit launch rejected by state owner")
	_expect_equal(allocated_run_ids, 1, "invalid state allocates no run id")

func _next_run_id() -> String:
	allocated_run_ids += 1
	return "run-fixed-%d" % allocated_run_ids

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
