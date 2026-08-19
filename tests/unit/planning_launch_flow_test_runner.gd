extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const ContentRegistryScript := preload("res://src/content/content_registry.gd")
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

	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded_content: Dictionary = registry.load_families({
		"contract": "res://tests/fixtures/vertical_slice/contracts",
		"hold": "res://tests/fixtures/vertical_slice/holds",
		"species": "res://tests/fixtures/vertical_slice/species",
	})
	_expect_true(bool(loaded_content["ok"]), "launch-flow fixture loads through ContentRegistry")
	if not bool(loaded_content["ok"]):
		return
	var contract_payload: Dictionary = _payload(registry, &"contract", &"VS01")
	var hold_payload: Dictionary = _payload(registry, &"hold", &"VS_HOLD_01")
	var species_by_id: Dictionary = {}
	for document: ContentDocument in registry.ordered_documents(&"species"):
		species_by_id[String(document.id)] = document.payload.duplicate(true)

	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect_true(state_machine.transition_to(AppStateMachine.State.TITLE), "boot to title")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "title to map")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "map to brief")
	_expect_true(state_machine.transition_to(AppStateMachine.State.PLANNING), "brief to planning")

	var planning: PlanningSession = PlanningSessionScript.new(state_machine)
	var invalid_input: Dictionary = _input([
		{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		{"instance_id": "specimen-b", "anchor": [0, 0], "orientation": 0},
	])
	var invalid_revision: Dictionary = planning.apply_revision_from_content(
		"revision-invalid",
		invalid_input,
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_true(bool(invalid_revision["ok"]), "invalid arrangement is still an editable planning revision")
	_expect_true(not bool(invalid_revision["structural_legal"]), "invalid arrangement fails structural validation")
	_expect_true(Array(invalid_revision["reasons"]).has("overlap"), "overlap reason is derived from real fixture data")
	var invalid_confirm: Dictionary = planning.request_launch_confirm()
	_expect_true(not bool(invalid_confirm["ok"]), "structurally illegal arrangement cannot enter launch confirm")
	_expect_equal(String(invalid_confirm["error"]), "structural_illegal", "illegal confirm reason")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.PLANNING, "illegal confirm leaves planning editable")

	var canonical_input: Dictionary = _input([
		{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		{"instance_id": "specimen-b", "anchor": [1, 1], "orientation": 0},
	])
	var valid_revision: Dictionary = planning.apply_revision_from_content(
		"revision-valid",
		canonical_input,
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_true(bool(valid_revision["structural_legal"]), "real-data legal arrangement passes structural validation")
	_expect_true(Array(valid_revision["reasons"]).is_empty(), "real-data legal arrangement has no structural reason labels")
	var confirm: Dictionary = planning.request_launch_confirm()
	_expect_true(bool(confirm["ok"]), "legal planning revision enters launch confirm")
	_expect_equal(String(confirm["planning_revision_id"]), "revision-valid", "launch confirm owns exact planning revision")
	_expect_equal(confirm["canonical_input"], canonical_input, "launch confirm freezes real-data canonical input snapshot")
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
	_expect_true(bool(committed["ok"]), "real-data validated launch confirm commits durably")
	_expect_equal(String(committed["run_id"]), "run-planning-slice-1", "durable launch returns allocated run id")
	_expect_equal(state_machine.current_state(), AppStateMachine.State.TRANSIT_PLAYBACK, "durable commit transitions to transit")

	var loaded: Dictionary = save_store.load(&"session")
	_expect_true(bool(loaded["ok"]), "planning-to-launch committed record reloads")
	if bool(loaded["ok"]):
		var envelope: SaveEnvelope = loaded["envelope"]
		var record: Dictionary = envelope.payload["committed_run"]
		_expect_equal(String(record["planning_revision_id"]), "revision-valid", "durable record retains validated planning revision")
		_expect_equal(String(record["run_id"]), "run-planning-slice-1", "durable record retains run identity")
		_expect_equal(record["canonical_committed_input"]["placements"], canonical_input["placements"], "durable record retains resolved placement snapshot")

func _payload(registry: ContentRegistry, kind: StringName, id: StringName) -> Dictionary:
	for document: ContentDocument in registry.ordered_documents(kind):
		if document.id == id:
			return document.payload.duplicate(true)
	failures += 1
	push_error("FAIL: missing fixture %s/%s" % [String(kind), String(id)])
	return {}

func _input(placements: Array) -> Dictionary:
	return {
		"route_id": "route-slice",
		"manifest_instance_ids": ["specimen-a", "specimen-b"],
		"placements": placements,
		"supports": [],
		"seed": 101,
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
