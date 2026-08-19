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

	var illegal: Dictionary = service.request_launch(
		"token-illegal",
		"revision-1",
		false,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1"
	)
	_expect_true(not illegal["ok"], "structurally illegal launch rejected")
	_expect_equal(String(illegal["error"]), "structural_illegal", "illegal launch reason")
	_expect_equal(allocated_run_ids, 0, "illegal launch allocates no run id")

	var committed: Dictionary = service.request_launch(
		"token-1",
		"revision-1",
		true,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1"
	)
	_expect_true(committed["ok"], "legal launch commits")
	_expect_true(not committed["duplicate"], "first launch is not duplicate")
	_expect_equal(String(committed["run_id"]), "run-fixed-1", "allocated run id retained")
	_expect_equal(allocated_run_ids, 1, "first commit allocates once")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.TRANSIT_PLAYBACK, "durable commit precedes transit state")

	var loaded: Dictionary = save_store.load(&"session")
	_expect_true(loaded["ok"], "committed session is durable")
	if loaded["ok"]:
		var envelope: SaveEnvelope = loaded["envelope"]
		var record: Dictionary = envelope.payload["committed_run"]
		_expect_equal(String(record["run_id"]), "run-fixed-1", "durable run id")
		_expect_equal(String(record["planning_revision_id"]), "revision-1", "durable planning revision")
		_expect_equal(String(record["lifecycle_state"]), "COMMITTED", "durable lifecycle")
		var expected_checksum: String = JSON.stringify(canonical_input, "", true, true).sha256_text()
		_expect_equal(String(record["committed_input_checksum"]), expected_checksum, "committed input checksum")

	var duplicate: Dictionary = service.request_launch(
		"token-duplicate-callback",
		"revision-1",
		true,
		"profile-1",
		"contract-1",
		canonical_input,
		"rules-r1",
		"content-c1"
	)
	_expect_true(duplicate["ok"], "duplicate callback returns existing commit")
	_expect_true(duplicate["duplicate"], "duplicate callback identified")
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
		"content-c1"
	)
	_expect_true(not wrong_revision["ok"], "new revision cannot launch from transit")
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
