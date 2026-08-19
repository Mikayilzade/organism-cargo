extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const PlanningSessionScript := preload("res://src/planning/planning_session.gd")

var failures: int = 0

func _init() -> void:
	_test_real_data_current_footprint_resolution()
	if failures == 0:
		print("planning_structural_resolver_test_runner: PASS")
		quit(0)
	else:
		push_error("planning_structural_resolver_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_real_data_current_footprint_resolution() -> void:
	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded: Dictionary = registry.load_families({
		"contract": "res://tests/fixtures/vertical_slice/contracts",
		"hold": "res://tests/fixtures/vertical_slice/holds",
		"species": "res://tests/fixtures/vertical_slice/species",
	})
	_expect_true(bool(loaded["ok"]), "vertical-slice fixture loads through ContentRegistry")
	if not bool(loaded["ok"]):
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

	var valid_input: Dictionary = _input([
		{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		{"instance_id": "specimen-b", "anchor": [1, 1], "orientation": 0},
	])
	var valid: Dictionary = planning.apply_revision_from_content(
		"real-data-valid",
		valid_input,
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_true(bool(valid["ok"]), "real-data revision is accepted as editable")
	_expect_true(bool(valid["structural_legal"]), "current footprints are structurally legal")
	_expect_true(Array(valid["reasons"]).is_empty(), "legal real-data revision has no placement reason")
	_expect_true(bool(valid["mandatory_manifest_placed"]), "all mandatory manifest instances are derived as placed")
	_expect_true(
		bool(valid["structural_legal"]),
		"O03 future footprint may reach blocked [2,1] without invalidating current launch legality"
	)

	var blocked: Dictionary = planning.apply_revision_from_content(
		"real-data-blocked",
		_input([
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [2, 1], "orientation": 0},
		]),
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_reason(blocked, "blocked", "current footprint on blocked cell")

	var outside: Dictionary = planning.apply_revision_from_content(
		"real-data-outside",
		_input([
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [3, 0], "orientation": 0},
		]),
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_reason(outside, "outside hold", "current footprint outside hold")

	var overlap: Dictionary = planning.apply_revision_from_content(
		"real-data-overlap",
		_input([
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [0, 0], "orientation": 0},
		]),
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_reason(overlap, "overlap", "two current footprints overlap")

	var orientation: Dictionary = planning.apply_revision_from_content(
		"real-data-orientation",
		_input([
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
			{"instance_id": "specimen-b", "anchor": [1, 1], "orientation": 90},
		]),
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_reason(orientation, "forbidden orientation", "undeclared orientation rejected")

	var missing: Dictionary = planning.apply_revision_from_content(
		"real-data-missing",
		_input([
			{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0},
		]),
		contract_payload,
		hold_payload,
		species_by_id
	)
	_expect_true(not bool(missing["structural_legal"]), "missing mandatory manifest blocks launch legality")
	_expect_true(not bool(missing["mandatory_manifest_placed"]), "mandatory placement is derived from manifest and placements")

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

func _expect_reason(result: Dictionary, reason: String, label: String) -> void:
	_expect_true(not bool(result["structural_legal"]), "%s is illegal" % label)
	_expect_true(Array(result["reasons"]).has(reason), "%s uses exact reason '%s'" % [label, reason])

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)
