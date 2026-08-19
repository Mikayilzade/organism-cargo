extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const LaunchCommitServiceScript := preload("res://src/run/launch_commit_service.gd")
const PlanningSessionScript := preload("res://src/planning/planning_session.gd")

var failures: int = 0

func _init() -> void:
	_test_planning_validation_to_durable_launch()
	if failures == 0:
		print("planning_launch_flow_test_runner: PASS")
		quit(0)
	else:
		push_error("planning_launch_flow_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_planning_validation_to_durable_launch() -> void:
	var root: String = "user://planning_launch_flow_fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_remove_if_exists(root.path_join("session.sav"))
	_remove_if_exists(root.path_join("session.sav.bak"))
	_remove_if_exists(root.path_join("session.sav.tmp"))

	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect_true(state_machine.transition_to(AppStateMachine.State.TITLE), "boot to title")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "title to map")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "map to brief")
	_expect_true(state_machine.transition_to(AppStateMachine.State.PLANNING), "brief to planning")

	var planning: PlanningSession = PlanningSessionScript.new(state_machine)
	var canonical_input: Dictionary = {
		"route_id": "route-slice",
		"manifest_instance_ids": ["specimen-a", "specimen-b"],
		"placements": [
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [1, 0], "orientation": 0},
		],
		"supports": [],
		"seed": 101,
	}
	var invalid_facts: Dictionary = _legal_facts()
	invalid_facts["mandatory_manifest_placed"] = false
	invalid_facts["overlap_free"] = false
	var invalid_revision: Dictionary = planning.apply_revision("revision-invalid", canonical_input, invalid_facts)
	_expect_true(bool(invalid_revision["ok"]), "invalid arrangement is still an editable planning revision")
	_expect_true(not bool(invalid_revision["structural_legal"]), "invalid arrangement fails structural validation")
	_expect_true(Array(invalid_revision["reasons"]).has("overlap"), "overlap reason is exact canonical label")
	var invalid_confirm: Dictionary = planning.request_launch_confirm()
	_expect_true(not bool(invalid_confirm["ok"]), "structurally illegal arrangement cannot enter launch confirm")
	_expect_equal(String(invalid_confirm["error"]), "structural_illegal", "illegal confirm reason")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.PLANNING, "illegal confirm leaves planning editable")

	var valid_revision: Dictionary = planning.apply_revision("revision-valid", canonical_input, _legal_facts())
	_expect_true(bool(valid_revision["structural_legal"]), "legal arrangement passes structural validation")
	var confirm: Dictionary = planning.request_launch_confirm()
	_expect_true(bool(confirm["ok"]), "legal planning revision enters launch confirm")
	_expect_equal(String(confirm["planning_revision_id"]), "revision-valid", "launch confirm owns exact planning revision")
	_expect_equal(confirm["canonical_input"], canonical_input, "launch confirm freezes current canonical input snapshot")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.LAUNCH_CONFIRM, "state owned by launch confirm")

	_expect_true(planning.cancel_launch_confirm(), "launch confirm can return to editable planning")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.PLANNING, "cancel returns to planning")
	confirm = planning.request_launch_confirm()
	_expect_true(bool(confirm["ok"]), "same unchanged legal revision can re-enter launch confirm")

	var save_store: AtomicSaveStore = AtomicSaveStoreScript.new(root)
	var launch_service: LaunchCommitService = LaunchCommitServiceScript.new(state_machine, save_store, func() -> String: return "run-planning-slice-1")
	var committed: Dictionary = launch_service.request_launch(
		"launch-token-1",
		String(confirm["planning_revision_id"]),
		bool(confirm["structural_legal"]),
		"profile-slice-1",
		"contract-slice-1",
		confirm["canonical_input"],
		"rules-r1",
		"content-c1",
		"contract-definition-slice-1"
	)
	_expect_true(bool(committed["ok"]), "validated launch confirm commits durably")
	_expect_equal(String(committed["run_id"]), "run-planning-slice-1", "durable launch returns allocated run id")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.TRANSIT_PLAYBACK, "durable commit transitions to transit")

	var loaded: Dictionary = save_store.load(&"session")
	_expect_true(bool(loaded["ok"]), "planning-to-launch committed record reloads")
	if bool(loaded["ok"]):
		var envelope: SaveEnvelope = loaded["envelope"]
		var record: Dictionary = envelope.payload["committed_run"]
		_expect_equal(String(record["planning_revision_id"]), "revision-valid", "durable record retains validated planning revision")
		_expect_equal(String(record["run_id"]), "run-planning-slice-1", "durable record retains run identity")

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
