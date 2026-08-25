extends SceneTree

const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const ResultsProgressionServiceScript := preload("res://src/run/results_progression_service.gd")
const TransitReconstructionServiceScript := preload("res://src/run/transit_reconstruction_service.gd")
const PersistenceReconciliationServiceScript := preload("res://src/save/persistence_reconciliation_service.gd")

var failures: int = 0

func _init() -> void:
	_test_results_crash_window_repairs_without_reaward()
	_test_interrupted_atomic_write_keeps_valid_generation()
	_test_reconstruction_repeats_and_all_cursors_are_authoritative_invariant()
	_test_cloud_restore_cannot_rollback_or_reaward_completion()
	if failures == 0:
		print("phase12f_crash_resume_cloud_adversarial_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12f_crash_resume_cloud_adversarial_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_results_crash_window_repairs_without_reaward() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_results_crash_window")
	var record: Dictionary = _reviewable_record("profile-crash", "run-crash", "C12")
	_expect(bool(store.write(&"session", {"committed_run": record.duplicate(true)}).get("ok", false)), "seed reviewable session before simulated Results crash")
	var result: Dictionary = _success_result("result-checksum-crash")
	var completion_id: String = _completion_id(record, String(result["completion_checksum"]))
	var profile_after_step10: Dictionary = {
		"profile_uuid": "profile-crash",
		"save_format_version": 1,
		"cleared_bronze_contract_ids": ["C12"],
		"best_medal_by_contract": {"C12": "GOLD"},
		"documented_fact_ids": ["fact-crash"],
		"applied_completion_ids": [completion_id],
	}
	_expect(bool(store.write(&"profile", profile_after_step10).get("ok", false)), "simulate durable profile step 10 before session lifecycle step 11")

	var service: ResultsProgressionService = ResultsProgressionServiceScript.new(store)
	var repaired: Dictionary = service.apply_authoritative_result(record, result, "GOLD", ["fact-crash"])
	_expect(bool(repaired.get("ok", false)), "reopening Results after crash window repairs successfully")
	_expect(bool(repaired.get("duplicate", false)), "existing completion ledger is recognized after crash")
	_expect(not bool(repaired.get("applied", true)), "crash-window repair cannot award completion twice")
	_expect_equal(String(repaired.get("completion_id", "")), completion_id, "crash-window repair derives same deterministic completion id")
	var profile: Dictionary = _load_payload(store, &"profile")
	_expect_equal(_array(profile.get("applied_completion_ids", [])).size(), 1, "completion ledger remains single-entry")
	_expect_equal(_array(profile.get("cleared_bronze_contract_ids", [])).size(), 1, "Bronze clear remains single-entry")
	_expect_equal(_array(profile.get("documented_fact_ids", [])).size(), 1, "documented fact remains single-entry")
	var session: Dictionary = _load_payload(store, &"session")
	var repaired_record: Dictionary = _dict(session.get("committed_run", {}))
	_expect_equal(String(repaired_record.get("lifecycle_state", "")), "COMPLETION_APPLIED", "stale Reviewable session is repaired to Completion Applied")
	_expect_equal(String(repaired_record.get("completion_id", "")), completion_id, "repaired session records same completion id")
	_expect_equal(String(repaired_record.get("final_result_checksum", "")), String(result["completion_checksum"]), "repaired session records authoritative result checksum")

	var repeated: Dictionary = ResultsProgressionServiceScript.new(store).apply_authoritative_result(record, result, "GOLD", ["fact-crash"])
	_expect(bool(repeated.get("duplicate", false)), "second reopen remains idempotent")
	_expect(not bool(repeated.get("applied", true)), "second reopen still cannot re-award")

func _test_interrupted_atomic_write_keeps_valid_generation() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_interrupted_atomic")
	var old_payload: Dictionary = {"profile_uuid": "profile-atomic", "generation": 1, "cleared_bronze_contract_ids": ["C01"]}
	var new_payload: Dictionary = {"profile_uuid": "profile-atomic", "generation": 2, "cleared_bronze_contract_ids": ["C01", "C02"]}
	_expect(bool(store.write(&"profile", old_payload).get("ok", false)), "atomic fixture generation 1 is durable")
	_expect(bool(store.write(&"profile", new_payload).get("ok", false)), "atomic fixture generation 2 is durable")
	var paths: Dictionary = store.paths_for(&"profile")
	var primary_path: String = String(paths.get("primary", ""))
	var backup_path: String = String(paths.get("backup", ""))
	var temp_path: String = String(paths.get("temp", ""))
	var newest_serialized: String = FileAccess.get_file_as_string(primary_path)
	_expect(not newest_serialized.is_empty(), "newest validated generation can be captured for interrupted-write fixture")

	# Model crash after primary -> backup rotation but before temp -> primary install.
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	var rotate_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(primary_path), ProjectSettings.globalize_path(backup_path))
	_expect_equal(rotate_error, OK, "hostile fixture rotates primary to backup")
	var temp_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	_expect(temp_file != null, "hostile fixture can leave temp generation behind")
	if temp_file != null:
		temp_file.store_string(newest_serialized)
		temp_file.flush()
		temp_file.close()
	var recovered: Dictionary = store.load(&"profile")
	_expect(bool(recovered.get("ok", false)), "interrupted install still leaves a loadable generation")
	_expect_equal(String(recovered.get("source", "")), "backup", "backup is authoritative when primary install never completed")
	if bool(recovered.get("ok", false)):
		var envelope: SaveEnvelope = recovered["envelope"]
		_expect_equal(int(envelope.payload.get("generation", 0)), 2, "rotated validated generation survives crash boundary")

	# A torn/corrupt temp is likewise ignored; backup remains valid and diagnostic files survive.
	var torn: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	_expect(torn != null, "hostile fixture can overwrite temp with torn bytes")
	if torn != null:
		torn.store_string("{torn-temp-write")
		torn.flush()
		torn.close()
	var recovered_from_torn: Dictionary = store.load(&"profile")
	_expect(bool(recovered_from_torn.get("ok", false)), "torn temp cannot destroy validated backup generation")
	_expect_equal(String(recovered_from_torn.get("source", "")), "backup", "recovery continues to use validated backup")
	_expect(FileAccess.file_exists(backup_path), "validated backup is not erased by interrupted temp write")
	_expect(FileAccess.file_exists(temp_path), "torn temp remains available for diagnostics until a later save")

func _test_reconstruction_repeats_and_all_cursors_are_authoritative_invariant() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_reconstruction_repetition")
	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var compatibility: Dictionary = _compatibility()
	var record: Dictionary = _reconstructable_record("profile-repeat", "run-repeat")
	var baseline: Dictionary = service.reconstruct_record(record, compatibility)
	_expect(bool(baseline.get("ok", false)), "reconstruction baseline succeeds")
	if not bool(baseline.get("ok", false)):
		return
	var baseline_trace: PackedStringArray = baseline.get("tick_checksums", PackedStringArray())
	var baseline_final: String = String(baseline.get("final_result_checksum", ""))
	_expect_equal(baseline_trace.size(), 3, "representative reconstruction owns three authoritative tick hashes")

	for iteration: int in range(128):
		var hostile_record: Dictionary = record.duplicate(true)
		hostile_record["playback_speed"] = 0.25 + float(iteration % 8)
		hostile_record["paused"] = iteration % 2 == 0
		hostile_record["reduced_motion"] = iteration % 3 == 0
		hostile_record["reduced_flashing"] = iteration % 5 == 0
		hostile_record["master_volume_percent"] = 0 if iteration % 4 == 0 else 100
		hostile_record["presentation_skip_requested"] = iteration % 7 == 0
		var repeated: Dictionary = service.reconstruct_record(hostile_record, compatibility)
		_expect(bool(repeated.get("ok", false)), "reconstruction repeat %d succeeds" % iteration)
		if not bool(repeated.get("ok", false)):
			continue
		_expect_equal(repeated.get("tick_checksums", PackedStringArray()), baseline_trace, "reconstruction repeat %d preserves tick hashes" % iteration)
		_expect_equal(String(repeated.get("final_result_checksum", "")), baseline_final, "reconstruction repeat %d preserves final hash" % iteration)

	var stored_record: Dictionary = record.duplicate(true)
	stored_record["tick_checksums"] = Array(baseline_trace)
	stored_record["final_result_checksum"] = baseline_final
	stored_record["lifecycle_state"] = "SIMULATED"
	for cursor: int in range(0, 4):
		var cursor_record: Dictionary = stored_record.duplicate(true)
		cursor_record["last_presented_tick_cursor"] = cursor
		var resumed: Dictionary = service.reconstruct_record(cursor_record, compatibility)
		_expect(bool(resumed.get("ok", false)), "valid playback cursor %d reconstructs" % cursor)
		if not bool(resumed.get("ok", false)):
			continue
		_expect_equal(int(resumed.get("presentation_cursor", -1)), cursor, "valid playback cursor %d is restored exactly" % cursor)
		_expect(not bool(resumed.get("presentation_cursor_reset", true)), "valid playback cursor %d is not treated as authority mismatch" % cursor)
		_expect_equal(resumed.get("tick_checksums", PackedStringArray()), baseline_trace, "cursor %d cannot alter tick hashes" % cursor)
		_expect_equal(String(resumed.get("final_result_checksum", "")), baseline_final, "cursor %d cannot alter final hash" % cursor)

func _test_cloud_restore_cannot_rollback_or_reaward_completion() -> void:
	var reconciliation: PersistenceReconciliationService = PersistenceReconciliationServiceScript.new()
	var record: Dictionary = _reviewable_record("profile-cloud", "run-cloud", "C16")
	var result: Dictionary = _success_result("result-checksum-cloud")
	var completion_id: String = _completion_id(record, String(result["completion_checksum"]))
	var completed_profile: Dictionary = {
		"profile_uuid": "profile-cloud",
		"save_format_version": 4,
		"cleared_bronze_contract_ids": ["C01", "C16"],
		"best_medal_by_contract": {"C16": "GOLD"},
		"documented_fact_ids": ["fact-earned"],
		"applied_completion_ids": [completion_id],
	}
	var stale_cloud_profile: Dictionary = {
		"profile_uuid": "profile-cloud",
		"save_format_version": 4,
		"cleared_bronze_contract_ids": ["C01"],
		"best_medal_by_contract": {"C16": "BRONZE"},
		"documented_fact_ids": [],
		"applied_completion_ids": [],
	}
	var merged_result: Dictionary = reconciliation.merge_profiles(completed_profile, stale_cloud_profile)
	_expect(bool(merged_result.get("ok", false)), "stale cloud profile can reconcile with completed local lineage")
	var merged_profile: Dictionary = _dict(merged_result.get("profile", {}))
	_expect("C16" in _array(merged_profile.get("cleared_bronze_contract_ids", [])), "stale cloud restore cannot roll back Bronze C16")
	_expect_equal(_dict(merged_profile.get("best_medal_by_contract", {})).get("C16"), "GOLD", "stale cloud restore cannot roll back best medal")
	_expect(completion_id in _array(merged_profile.get("applied_completion_ids", [])), "completion ledger survives monotonic cloud merge")
	_expect(bool(merged_result.get("challenge_mode_unlocked", false)), "derived Challenge gate remains unlocked after stale cloud merge")

	var stale_session: Dictionary = record.duplicate(true)
	stale_session["committed_input_checksum"] = "same-lineage-checksum"
	stale_session["lifecycle_state"] = "REVIEWABLE"
	var applied_session: Dictionary = stale_session.duplicate(true)
	applied_session["lifecycle_state"] = "COMPLETION_APPLIED"
	applied_session["completion_id"] = completion_id
	applied_session["final_result_checksum"] = String(result["completion_checksum"])
	var session_resolution: Dictionary = reconciliation.resolve_active_session_conflict(stale_session, applied_session)
	_expect(bool(session_resolution.get("ok", false)), "same-lineage cloud sessions reconcile")
	_expect_equal(String(_dict(session_resolution.get("selected", {})).get("lifecycle_state", "")), "COMPLETION_APPLIED", "later applied lifecycle wins over stale Reviewable cloud session")

	var store: AtomicSaveStore = _fresh_store("phase12f_cloud_completion_restore")
	_expect(bool(store.write(&"profile", merged_profile).get("ok", false)), "persist merged monotonic profile")
	_expect(bool(store.write(&"session", {"committed_run": stale_session.duplicate(true)}).get("ok", false)), "simulate stale cloud session restored after permanent profile merge")
	var replay: Dictionary = ResultsProgressionServiceScript.new(store).apply_authoritative_result(record, result, "GOLD", ["fact-earned"])
	_expect(bool(replay.get("ok", false)), "restored stale session can repair against permanent merged profile")
	_expect(bool(replay.get("duplicate", false)), "restored stale session sees completion already applied")
	_expect(not bool(replay.get("applied", true)), "restored stale session cannot award completion twice")
	var final_profile: Dictionary = _load_payload(store, &"profile")
	_expect_equal(_array(final_profile.get("applied_completion_ids", [])).size(), 1, "cloud replay leaves one completion ledger entry")
	_expect_equal(_dict(final_profile.get("best_medal_by_contract", {})).get("C16"), "GOLD", "cloud replay preserves permanent best medal")
	var final_session: Dictionary = _dict(_load_payload(store, &"session").get("committed_run", {}))
	_expect_equal(String(final_session.get("lifecycle_state", "")), "COMPLETION_APPLIED", "cloud replay repairs stale session lifecycle")
	_expect_equal(String(final_session.get("completion_id", "")), completion_id, "cloud replay repairs same completion identity")

func _reviewable_record(profile_uuid: String, run_id: String, contract_id: String) -> Dictionary:
	return {
		"profile_uuid": profile_uuid,
		"run_id": run_id,
		"contract_id": contract_id,
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"lifecycle_state": "REVIEWABLE",
	}

func _success_result(checksum: String) -> Dictionary:
	return {"ok": true, "completion_checksum": checksum, "delivery_result": {"success": true}}

func _completion_id(record: Dictionary, result_checksum: String) -> String:
	return "\u001f".join(PackedStringArray([
		String(record["profile_uuid"]),
		String(record["run_id"]),
		String(record["contract_id"]),
		result_checksum,
		String(record["rules_version"]),
		String(record["content_version"]),
	])).sha256_text()

func _reconstructable_record(profile_uuid: String, run_id: String) -> Dictionary:
	var committed: Dictionary = {
		"route_id": "route-repeat",
		"manifest_instance_ids": ["specimen-a"],
		"placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}],
		"supports": [],
		"seed": 44,
		"contract_id": "C04",
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"generator_version": "",
		"expected_contract_definition_checksum": "contract-checksum",
	}
	var normalized_value: Variant = JSON.parse_string(JSON.stringify(committed, "", true, true))
	var normalized: Dictionary = normalized_value if normalized_value is Dictionary else {}
	return {
		"profile_uuid": profile_uuid,
		"run_id": run_id,
		"contract_id": "C04",
		"planning_revision_id": "revision-repeat",
		"canonical_committed_input": normalized,
		"committed_input_checksum": JSON.stringify(normalized, "", true, true).sha256_text(),
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"generator_version": "",
		"expected_contract_definition_checksum": "contract-checksum",
		"lifecycle_state": "COMMITTED",
	}

func _compatibility() -> Dictionary:
	return {
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"contract_definition_checksum": "contract-checksum",
		"total_ticks": 3,
		"simulation_defs": {
			"route_profile": {"id": "route-repeat", "tick_count": 3, "events": []},
			"hold_definition": {"dimensions": [1, 1], "blocked_cells": []},
			"hazards_by_id": {},
			"thermal_rules": {"heat_min": 0, "heat_max": 20, "transfer_edges": [], "vent_by_cell": {}},
			"organism_definitions": {
				"specimen-a": {
					"initial_stress": 1,
					"initial_state": "CALM",
					"stress_profile": {
						"heat_safe_max": 2,
						"stress_per_heat_unit": 2,
						"stress_min": 0,
						"stress_max": 20,
						"agitated_enter": 5,
						"agitated_exit": 3,
						"panic_enter": 10,
						"panic_exit": 7,
					},
				},
			},
		},
		"mandatory_predicates": [
			{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "CALM"},
		],
	}

func _fresh_store(name: String) -> AtomicSaveStore:
	var root: String = "user://%s" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	for kind: String in ["profile", "session", "settings"]:
		for suffix: String in [".sav", ".sav.bak", ".sav.tmp"]:
			var path: String = root.path_join(kind + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return AtomicSaveStoreScript.new(root)

func _load_payload(store: AtomicSaveStore, kind: StringName) -> Dictionary:
	var loaded: Dictionary = store.load(kind)
	_expect(bool(loaded.get("ok", false)), "load %s payload" % String(kind))
	if not bool(loaded.get("ok", false)):
		return {}
	var envelope: SaveEnvelope = loaded["envelope"]
	return envelope.payload.duplicate(true)

func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _array(value: Variant) -> Array:
	return value if value is Array else []

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
