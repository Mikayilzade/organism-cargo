extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const VerticalSliceControlScript := preload("res://src/ui/vertical_slice_control.gd")

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded: Dictionary = registry.load_families({
		&"contracts": "res://content/contracts",
		&"holds": "res://content/holds",
		&"species": "res://content/species",
	})
	_expect(bool(loaded.get("ok", false)), "production VS01 planning families load")
	if not bool(loaded.get("ok", false)):
		_finish()
		return

	var contract_payload: Dictionary = _payload(registry, &"contracts", &"VS01")
	var hold_payload: Dictionary = _payload(registry, &"holds", &"VS_HOLD_01")
	var species_by_id: Dictionary = {}
	for document: ContentDocument in registry.ordered_documents(&"species"):
		if document.id in [&"O01", &"O03"]:
			species_by_id[String(document.id)] = document.payload.duplicate(true)
	_expect(species_by_id.size() == 2, "two vertical-slice species are production-loadable")

	var root_path: String = "user://vertical_slice_planning_editor_fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect(state_machine.transition_to(AppStateMachine.State.TITLE), "boot -> title")
	var store: AtomicSaveStore = AtomicSaveStoreScript.new(root_path)
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(state_machine, store)
	var control: VerticalSliceControl = VerticalSliceControlScript.new()
	root.add_child(control)
	control.configure(flow, {
		"planning_contract_payload": contract_payload,
		"planning_hold_payload": hold_payload,
		"planning_species_by_id": species_by_id,
		"planning_route_id": "route-slice",
		"planning_seed": 101,
	})
	await process_frame

	_expect(bool(control.activate_primary_action().get("ok", false)), "title -> campaign")
	_expect(bool(control.activate_primary_action().get("ok", false)), "campaign -> brief")
	_expect(bool(control.activate_primary_action().get("ok", false)), "brief -> planning")
	_expect(flow.current_state() == AppStateMachine.State.PLANNING, "planning state active")

	_expect(bool(control.planning_select_manifest("specimen-a").get("ok", false)), "select first manifest item")
	_expect(bool(control.planning_activate_focused_cell().get("ok", false)), "place first item at focused [0,0]")
	var first_snapshot: Dictionary = flow.planning_snapshot()
	_expect(not bool(first_snapshot.get("structural_legal", false)), "one missing mandatory item blocks Launch")

	_expect(bool(control.planning_select_manifest("specimen-b").get("ok", false)), "select second manifest item")
	_expect(bool(control.planning_move_focus(1, 1).get("ok", false)), "discrete focus moves to [1,1]")
	_expect(bool(control.planning_activate_focused_cell().get("ok", false)), "place second item through focused-cell activation")
	var legal_snapshot: Dictionary = flow.planning_snapshot()
	_expect(bool(legal_snapshot.get("structural_legal", false)), "canonical resolver validates player-built plan")
	_expect(bool(legal_snapshot.get("mandatory_manifest_placed", false)), "both mandatory instances are placed")
	_expect(bool(control.activate_primary_action().get("ok", false)), "legal editor plan reaches Launch confirmation")
	_expect(flow.current_state() == AppStateMachine.State.LAUNCH_CONFIRM, "Launch remains deliberate second-step state")

	control.queue_free()
	_finish()

func _payload(registry: ContentRegistry, kind: StringName, id: StringName) -> Dictionary:
	for document: ContentDocument in registry.ordered_documents(kind):
		if document.id == id:
			return document.payload.duplicate(true)
	failures += 1
	push_error("FAIL: missing production content %s/%s" % [String(kind), String(id)])
	return {}

func _finish() -> void:
	if failures == 0:
		print("vertical_slice_planning_editor_test_runner: PASS")
		quit(0)
	else:
		push_error("vertical_slice_planning_editor_test_runner: %d failure(s)" % failures)
		quit(1)

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)
