extends SceneTree

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const LaunchCommitServiceScript := preload("res://src/run/launch_commit_service.gd")
const ResultsProgressionServiceScript := preload("res://src/run/results_progression_service.gd")
const TransitReconstructionServiceScript := preload("res://src/run/transit_reconstruction_service.gd")

var failures: int = 0
var allocated_run_ids: int = 0

func _init() -> void:
	_test_duplicate_launch_payload_drift_cannot_create_or_mutate_run()
	_test_duplicate_results_survives_service_recreation()
	_test_corruption_fallback_never_guesses_progress()
	_test_reconstruction_cursor_and_authoritative_mismatch_classes()
	if failures == 0:
		print("phase12f_persistence_adversarial_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12f_persistence_adversarial_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_duplicate_launch_payload_drift_cannot_create_or_mutate_run() -> void:
	allocated_run_ids = 0
	var store: AtomicSaveStore = _fresh_store("phase12f_duplicate_launch")
	var state: AppStateMachine = _state_at_launch_confirm()
	var service: LaunchCommitService = LaunchCommitServiceScript.new(state, store, Callable(self, "_next_run_id"))
	var canonical: Dictionary = _committed_input_source()
	var first: Dictionary = service.request_launch(
		"token-first", "revision-attack", true, "profile-a", "C01", canonical,
		"rules-r1", "content-r1", "contract-checksum"
	)
	_expect(bool(first.get("ok", false)), "first launch commits")
	_expect(not bool(first.get("duplicate", true)), "first launch is not duplicate")
	_expect_equal(String(first.get("run_id", "")), "run-adversarial-1", "first launch owns stable run id")
	_expect_equal(allocated_run_ids, 1, "first launch allocates exactly once")
	var before: Dictionary = _load_payload(store, &"session")
	var before_record: Dictionary = _dict(before.get("committed_run", {}))
	var before_checksum: String = String(before_record.get("committed_input_checksum", ""))
	var before_input: Dictionary = _dict(before_record.get("canonical_committed_input", {})).duplicate(true)

	var drifted: Dictionary = canonical.duplicate(true)
	drifted["seed"] = 999
	drifted["placements"] = [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 3}]
	var duplicate: Dictionary = service.request_launch(
		"token-repeat-from-key-repeat", "revision-attack", true, "profile-a", "C01", drifted,
		"rules-r1", "content-r1", "contract-checksum"
	)
	_expect(bool(duplicate.get("ok", false)), "duplicate callback is absorbed")
	_expect(bool(duplicate.get("duplicate", false)), "duplicate callback is identified")
	_expect_equal(String(duplicate.get("run_id", "")), "run-adversarial-1", "duplicate callback returns original run identity")
	_expect_equal(allocated_run_ids, 1, "payload drift on repeated callback cannot allocate another run")
	var after: Dictionary = _load_payload(store, &"session")
	var after_record: Dictionary = _dict(after.get("committed_run", {}))
	_expect_equal(String(after_record.get("committed_input_checksum", "")), before_checksum, "duplicate payload drift cannot rewrite committed checksum")
	_expect_equal(_dict(after_record.get("canonical_committed_input", {})), before_input, "duplicate payload drift cannot rewrite immutable committed input")

func _test_duplicate_results_survives_service_recreation() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_duplicate_results")
	var record: Dictionary = {
		"profile_uuid": "profile-results",
		"run_id": "run-results",
		"contract_id": "C08",
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"lifecycle_state": "REVIEWABLE",
	}
	_expect(bool(store.write(&"session", {"committed_run": record.duplicate(true)}).get("ok", false)), "seed reviewable session")
	var first_service: ResultsProgressionService = ResultsProgressionServiceScript.new(store)
	var result: Dictionary = {"ok": true, "completion_checksum": "completion-checksum", "delivery_result": {"success": true}}
	var first: Dictionary = first_service.apply_authoritative_result(record, result, "GOLD", ["fact-a"])
	_expect(bool(first.get("ok", false)), "first Results application succeeds")
	_expect(bool(first.get("applied", false)), "first Results application writes progression")
	var completion_id: String = String(first.get("completion_id", ""))
	_expect(not completion_id.is_empty(), "completion id is deterministic and non-empty")

	# Recreate the service to model a screen/process callback boundary rather than relying on in-memory state.
	var reopened_service: ResultsProgressionService = ResultsProgressionServiceScript.new(store)
	var repeated: Dictionary = reopened_service.apply_authoritative_result(record, result, "GOLD", ["fact-a"])
	_expect(bool(repeated.get("ok", false)), "reopened Results succeeds after service recreation")
	_expect(bool(repeated.get("duplicate", false)), "durable ledger rejects duplicate Results after recreation")
	_expect(not bool(repeated.get("applied", true)), "duplicate Results cannot award twice")
	_expect_equal(String(repeated.get("completion_id", "")), completion_id, "reopened Results derives same completion id")
	var profile: Dictionary = _load_payload(store, &"profile")
	_expect_equal((_array(profile.get("applied_completion_ids", []))).size(), 1, "profile ledger contains one completion id")
	_expect_equal((_array(profile.get("cleared_bronze_contract_ids", []))).size(), 1, "Bronze clear remains set-like under duplicate callback")
	_expect_equal((_array(profile.get("documented_fact_ids", []))).size(), 1, "knowledge remains set-like under duplicate callback")

func _test_corruption_fallback_never_guesses_progress() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_corruption")
	_expect(bool(store.write(&"profile", {"profile_uuid": "profile-corrupt", "cleared_bronze_contract_ids": ["C01"]}).get("ok", false)), "write first valid profile generation")
	_expect(bool(store.write(&"profile", {"profile_uuid": "profile-corrupt", "cleared_bronze_contract_ids": ["C01", "C02"]}).get("ok", false)), "write second valid profile generation")
	var paths: Dictionary = store.paths_for(&"profile")
	_corrupt_file(String(paths["primary"]))
	var fallback: Dictionary = store.load(&"profile")
	_expect(bool(fallback.get("ok", false)), "corrupt primary falls back to validated backup")
	_expect_equal(String(fallback.get("source", "")), "backup", "backup is explicitly identified as recovery source")
	if bool(fallback.get("ok", false)):
		var envelope: SaveEnvelope = fallback["envelope"]
		_expect_equal(_array(envelope.payload.get("cleared_bronze_contract_ids", [])).size(), 1, "fallback exposes only actually durable backup progress")

	_corrupt_file(String(paths["backup"]))
	var total_failure: Dictionary = store.load(&"profile")
	_expect(not bool(total_failure.get("ok", true)), "corrupt primary plus corrupt backup does not fabricate a profile")
	_expect_equal(String(total_failure.get("error", "")), "no_valid_generation", "total corruption enters explicit no-valid-generation boundary")
	_expect(FileAccess.file_exists(String(paths["primary"])), "corrupt primary is retained for diagnostics")
	_expect(FileAccess.file_exists(String(paths["backup"])), "corrupt backup is retained for diagnostics")

func _test_reconstruction_cursor_and_authoritative_mismatch_classes() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_reconstruction")
	var compatibility: Dictionary = _compatibility()
	var committed_input: Dictionary = _committed_input_source()
	committed_input["contract_id"] = "C01"
	committed_input["rules_version"] = "rules-r1"
	committed_input["content_version"] = "content-r1"
	committed_input["generator_version"] = ""
	committed_input["expected_contract_definition_checksum"] = "contract-checksum"
	var normalized_value: Variant = JSON.parse_string(JSON.stringify(committed_input, "", true, true))
	_expect(normalized_value is Dictionary, "committed input normalizes through persistence representation")
	if not normalized_value is Dictionary:
		return
	var normalized: Dictionary = normalized_value
	var record: Dictionary = {
		"profile_uuid": "profile-reconstruct",
		"run_id": "run-reconstruct",
		"contract_id": "C01",
		"planning_revision_id": "revision-reconstruct",
		"canonical_committed_input": normalized,
		"committed_input_checksum": JSON.stringify(normalized, "", true, true).sha256_text(),
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"generator_version": "",
		"expected_contract_definition_checksum": "contract-checksum",
		"lifecycle_state": "COMMITTED",
	}
	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var baseline: Dictionary = service.reconstruct_record(record, compatibility)
	_expect(bool(baseline.get("ok", false)), "baseline committed run reconstructs")
	if not bool(baseline.get("ok", false)):
		return

	var bad_cursor_record: Dictionary = record.duplicate(true)
	bad_cursor_record["tick_checksums"] = Array(baseline.get("tick_checksums", PackedStringArray()))
	bad_cursor_record["final_result_checksum"] = String(baseline.get("final_result_checksum", ""))
	bad_cursor_record["last_presented_tick_cursor"] = 999
	var cursor_recovery: Dictionary = service.reconstruct_record(bad_cursor_record, compatibility)
	_expect(bool(cursor_recovery.get("ok", false)), "presentation cursor corruption does not invalidate authoritative run")
	_expect_equal(String(cursor_recovery.get("recovery_class", "")), "A", "invalid presentation cursor is recovery class A")
	_expect(bool(cursor_recovery.get("presentation_cursor_reset", false)), "invalid presentation cursor is explicitly reset")
	_expect_equal(String(cursor_recovery.get("final_result_checksum", "")), String(baseline.get("final_result_checksum", "")), "cursor repair cannot alter authoritative final checksum")

	var mismatch_record: Dictionary = bad_cursor_record.duplicate(true)
	mismatch_record["last_presented_tick_cursor"] = 0
	mismatch_record["final_result_checksum"] = "hostile-stored-final-checksum"
	_expect(bool(store.write(&"session", {"committed_run": mismatch_record}).get("ok", false)), "seed hostile authoritative mismatch")
	var mismatch: Dictionary = service.resume_current(compatibility)
	_expect(not bool(mismatch.get("ok", true)), "authoritative checksum mismatch never silently resumes")
	_expect_equal(String(mismatch.get("recovery_class", "")), "C", "authoritative checksum mismatch is recovery class C")
	_expect(String(mismatch.get("error", "")).contains("final_result_checksum"), "mismatch diagnostic identifies final checksum")
	var persisted: Dictionary = _load_payload(store, &"session")
	var persisted_record: Dictionary = _dict(persisted.get("committed_run", {}))
	_expect_equal(String(persisted_record.get("lifecycle_state", "")), "RECONSTRUCTION_MISMATCH", "mismatch is durably quarantined")
	var diagnostics: Dictionary = _dict(persisted_record.get("reconstruction_diagnostics", {}))
	_expect_equal(String(diagnostics.get("kind", "")), "final_result_checksum", "durable diagnostics retain mismatch class detail")
	_expect_equal(String(persisted_record.get("run_id", "")), "run-reconstruct", "quarantine preserves original run identity")
	_expect_equal(_dict(persisted_record.get("canonical_committed_input", {})), normalized, "quarantine preserves immutable committed baseline")

func _state_at_launch_confirm() -> AppStateMachine:
	var state: AppStateMachine = AppStateMachineScript.new()
	_expect(state.transition_to(AppStateMachine.State.TITLE), "boot -> title")
	_expect(state.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "title -> map")
	_expect(state.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "map -> brief")
	_expect(state.transition_to(AppStateMachine.State.PLANNING), "brief -> planning")
	_expect(state.transition_to(AppStateMachine.State.LAUNCH_CONFIRM), "planning -> launch confirm")
	return state

func _committed_input_source() -> Dictionary:
	return {
		"route_id": "route-adversarial",
		"manifest_instance_ids": ["specimen-a"],
		"placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}],
		"supports": [],
		"seed": 77,
	}

func _compatibility() -> Dictionary:
	return {
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"contract_definition_checksum": "contract-checksum",
		"total_ticks": 2,
		"simulation_defs": {
			"route_profile": {"id": "route-adversarial", "tick_count": 2, "events": []},
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

func _next_run_id() -> String:
	allocated_run_ids += 1
	return "run-adversarial-%d" % allocated_run_ids

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

func _corrupt_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("FAIL: cannot corrupt fixture %s" % path)
		return
	file.store_string("{hostile-corruption")
	file.flush()
	file.close()

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
