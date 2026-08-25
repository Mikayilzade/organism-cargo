class_name Phase12ERecoveryCompletionAcceptance
extends RefCounted

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const SaveRecoveryServiceScript := preload("res://src/save/save_recovery_service.gd")
const VerticalSliceFlowCoordinatorScript := preload("res://src/app/vertical_slice_flow_coordinator.gd")
const AccessibleVerticalSliceControlScript := preload("res://src/ui/accessible_vertical_slice_control.gd")
const SemanticVerticalSliceInputScript := preload("res://src/ui/semantic_vertical_slice_input.gd")

var _failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	await _test_validated_backup_recovery(tree)
	await _test_both_corrupt_new_profile_recovery(tree)
	await _test_campaign_completion_semantic_surface(tree)
	return _failures.duplicate()

func _test_validated_backup_recovery(tree: SceneTree) -> void:
	var root_path: String = "user://phase12e_recovery_backup_fixture"
	_clear_root(root_path)
	var store: AtomicSaveStore = AtomicSaveStoreScript.new(root_path)
	var backup_payload: Dictionary = {"profile_uuid": "profile-recovered", "bronze_cleared_contracts": ["C01"], "best_medals": {"C01": "BRONZE"}, "documented_facts": ["fact-a"], "applied_completion_ids": ["completion-a"]}
	_expect(bool(store.write(&"profile", backup_payload).get("ok", false)), "recovery fixture writes first valid profile")
	_expect(bool(store.write(&"profile", {"profile_uuid": "profile-newer", "bronze_cleared_contracts": ["C01", "C02"]}).get("ok", false)), "recovery fixture rotates first profile into backup")
	_write_raw(root_path.path_join("profile.sav"), "{ definitely corrupt primary")

	var service: SaveRecoveryService = SaveRecoveryServiceScript.new(store)
	var assessment: Dictionary = service.assess(&"profile")
	_expect_equal(assessment.get("status"), &"backup_available", "invalid primary with valid backup requires explicit backup recovery")
	_expect(bool(assessment.get("can_restore_backup", false)), "validated backup is exposed as truthful recovery choice")

	var state: AppStateMachine = AppStateMachineScript.new(); _expect(state.transition_to(AppStateMachine.State.TITLE), "recovery fixture boot -> title")
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(state, store)
	_expect(bool(flow.enter_save_recovery().get("ok", false)), "recovery flow enters SAVE_RECOVERY")
	var pair: Dictionary = await _configured_pair(tree, flow, service, "profile-recovered")
	var semantic: SemanticVerticalSliceInput = pair["semantic"]
	var control: AccessibleVerticalSliceControl = pair["control"]
	var surface: Node = control.get_node_or_null("Phase12ENavigationSurface")
	_expect(surface != null, "SAVE_RECOVERY uses the rendered Phase12E navigation surface")
	if surface != null and surface.has_method("recovery_summary_text"):
		var text: String = String(surface.call("recovery_summary_text"))
		_expect(text.contains("Backup: validated"), "recovery screen tells player only validated backup can be restored")
		_expect(text.contains("never guessed"), "recovery screen explicitly rejects guessed progress")
	_expect_equal(semantic.snapshot().get("recovery_action"), &"restore_backup", "semantic focus starts on validated backup restore")
	var restored: Dictionary = semantic.dispatch(&"accept")
	_expect(bool(restored.get("ok", false)), "Accept activates backup restore without pointer")
	_expect_equal(flow.current_state(), AppStateMachine.State.TITLE, "successful backup recovery returns to title")
	var loaded: Dictionary = store.load(&"profile")
	_expect(bool(loaded.get("ok", false)), "restored primary validates through normal AtomicSaveStore load")
	if bool(loaded.get("ok", false)):
		var envelope: SaveEnvelope = loaded["envelope"]
		_expect_equal(envelope.payload, backup_payload, "recovery restores exact validated backup payload without inference")
	var diagnostic_value: Variant = restored.get("diagnostic_paths", [])
	_expect(diagnostic_value is Array and not (diagnostic_value as Array).is_empty(), "corrupt primary is retained as a diagnostic before replacement")
	if diagnostic_value is Array and not (diagnostic_value as Array).is_empty():
		_expect(FileAccess.file_exists(String((diagnostic_value as Array)[0])), "retained corrupt-primary diagnostic remains on disk")
	control.queue_free(); semantic.queue_free(); await tree.process_frame

func _test_both_corrupt_new_profile_recovery(tree: SceneTree) -> void:
	var root_path: String = "user://phase12e_recovery_new_profile_fixture"
	_clear_root(root_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	_write_raw(root_path.path_join("profile.sav"), "corrupt primary with fake C48 progress")
	_write_raw(root_path.path_join("profile.sav.bak"), "corrupt backup with fake GOLD medals")
	var store: AtomicSaveStore = AtomicSaveStoreScript.new(root_path)
	var service: SaveRecoveryService = SaveRecoveryServiceScript.new(store)
	var assessment: Dictionary = service.assess(&"profile")
	_expect_equal(assessment.get("status"), &"recovery_required", "two invalid generations enter truthful recovery instead of guessing")
	_expect(not bool(assessment.get("can_restore_backup", true)), "invalid backup is never offered as restorable")

	var state: AppStateMachine = AppStateMachineScript.new(); _expect(state.transition_to(AppStateMachine.State.TITLE), "new-profile fixture boot -> title")
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(state, store); _expect(bool(flow.enter_save_recovery().get("ok", false)), "two-corrupt fixture enters SAVE_RECOVERY")
	var pair: Dictionary = await _configured_pair(tree, flow, service, "profile-clean")
	var semantic: SemanticVerticalSliceInput = pair["semantic"]
	var control: AccessibleVerticalSliceControl = pair["control"]
	_expect_equal(semantic.snapshot().get("recovery_action"), &"create_new_profile", "disabled invalid-backup choice cannot strand keyboard/controller focus")
	var created: Dictionary = semantic.dispatch(&"accept")
	_expect(bool(created.get("ok", false)), "Accept creates a clean profile when no valid generation exists")
	_expect_equal(flow.current_state(), AppStateMachine.State.TITLE, "new-profile recovery exits to title")
	var loaded: Dictionary = store.load(&"profile")
	_expect(bool(loaded.get("ok", false)), "new profile is atomically persisted")
	if bool(loaded.get("ok", false)):
		var envelope: SaveEnvelope = loaded["envelope"]
		_expect_equal(envelope.payload.get("profile_uuid"), "profile-clean", "new profile uses explicit identity")
		_expect_equal(envelope.payload.get("bronze_cleared_contracts"), [], "corrupt text cannot synthesize campaign clears")
		_expect_equal(envelope.payload.get("best_medals"), {}, "corrupt text cannot synthesize medals")
		_expect(not envelope.payload.has("C48"), "corrupt progress tokens are not guessed into the clean profile")
	var diagnostic_value: Variant = created.get("diagnostic_paths", [])
	_expect(diagnostic_value is Array and (diagnostic_value as Array).size() == 2, "both corrupt generations are retained before clean profile replacement")
	control.queue_free(); semantic.queue_free(); await tree.process_frame

func _test_campaign_completion_semantic_surface(tree: SceneTree) -> void:
	var root_path: String = "user://phase12e_campaign_complete_fixture"
	_clear_root(root_path)
	var store: AtomicSaveStore = AtomicSaveStoreScript.new(root_path)
	var service: SaveRecoveryService = SaveRecoveryServiceScript.new(store)
	var state: AppStateMachine = AppStateMachineScript.new(); _expect(state.transition_to(AppStateMachine.State.TITLE), "campaign-complete fixture boot -> title"); _expect(state.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "campaign-complete fixture title -> map")
	var flow: VerticalSliceFlowCoordinator = VerticalSliceFlowCoordinatorScript.new(state, store)
	_expect(bool(flow.enter_campaign_complete().get("ok", false)), "final campaign flow enters CAMPAIGN_COMPLETE")
	var pair: Dictionary = await _configured_pair(tree, flow, service, "profile-complete", {"campaign_completed_contract_count": 48, "campaign_total_contract_count": 48, "campaign_medal_summary": "48 Bronze clears; best medals remain maxima.", "campaign_challenge_summary": "Challenge access follows Bronze(C16)."})
	var semantic: SemanticVerticalSliceInput = pair["semantic"]
	var control: AccessibleVerticalSliceControl = pair["control"]
	var surface: Node = control.get_node_or_null("Phase12ENavigationSurface")
	_expect(surface != null, "campaign completion renders a semantic navigation surface")
	if surface != null and surface.has_method("campaign_complete_summary_text"):
		var text: String = String(surface.call("campaign_complete_summary_text"))
		_expect(text.contains("CAMPAIGN COMPLETE"), "campaign completion presents an explicit completion summary")
		_expect(text.contains("48 / 48"), "campaign completion presents authored-contract completion total")
		_expect(text.contains("replayable"), "campaign completion preserves replayable completed nodes")
		_expect(text.contains("No forced New Game+"), "campaign completion preserves frozen no-forced-NG+ rule")
	_expect_equal(semantic.snapshot().get("campaign_complete_action"), &"return_to_map", "campaign completion starts on return-to-map action")
	_expect(bool(semantic.dispatch(&"inspect").get("ok", false)), "Inspect opens Codex from campaign completion without pointer")
	_expect_equal(flow.current_state(), AppStateMachine.State.CODEX, "campaign completion Codex entry owns state")
	_expect(bool(semantic.dispatch(&"cancel").get("ok", false)), "Cancel closes Codex back to campaign completion")
	_expect_equal(flow.current_state(), AppStateMachine.State.CAMPAIGN_COMPLETE, "Codex returns to campaign completion")
	_expect(bool(semantic.dispatch(&"navigate_right").get("ok", false)), "semantic navigation cycles campaign-completion actions")
	_expect_equal(semantic.snapshot().get("campaign_complete_action"), &"codex", "right navigation focuses Codex action")
	_expect(bool(semantic.dispatch(&"navigate_left").get("ok", false)), "semantic navigation cycles back to map action")
	_expect(bool(semantic.dispatch(&"accept").get("ok", false)), "Accept returns to campaign map without pointer")
	_expect_equal(flow.current_state(), AppStateMachine.State.CAMPAIGN_MAP, "campaign completion returns to replayable map")
	control.queue_free(); semantic.queue_free(); await tree.process_frame

func _configured_pair(tree: SceneTree, flow: VerticalSliceFlowCoordinator, service: SaveRecoveryService, profile_uuid: String, extras: Dictionary = {}) -> Dictionary:
	var context: Dictionary = _base_context(profile_uuid, service)
	for raw_key: Variant in extras.keys(): context[raw_key] = extras[raw_key]
	var control: AccessibleVerticalSliceControl = AccessibleVerticalSliceControlScript.new(); tree.root.add_child(control); control.configure(flow, context)
	var semantic: SemanticVerticalSliceInput = SemanticVerticalSliceInputScript.new(); tree.root.add_child(semantic)
	var configured: Dictionary = semantic.configure(control, flow, context)
	_expect(bool(configured.get("ok", false)), "semantic recovery/completion controller configures")
	await tree.process_frame
	return {"control": control, "semantic": semantic}

func _base_context(profile_uuid: String, service: SaveRecoveryService) -> Dictionary:
	return {
		"profile_uuid": profile_uuid,
		"save_recovery_service": service,
		"planning_hold_payload": {"width": 1, "height": 1},
		"planning_contract_payload": {"manifest": []},
		"planning_species_by_id": {},
		"planning_route_id": "route-recovery",
		"planning_seed": 101,
		"simulation_defs": {"route_profile": {"id": "route-recovery", "tick_count": 1, "events": []}},
		"total_ticks": 1,
	}

func _clear_root(root_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null: return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir(): DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path.path_join(name)))
		name = dir.get_next()
	dir.list_dir_end()

func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("fixture could not open %s" % path); return
	file.store_string(text); file.flush(); file.close()

func _expect(value: bool, label: String) -> void:
	if not value: _failures.append(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected: _failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
