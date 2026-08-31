extends SceneTree

const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const TransitReconstructionServiceScript := preload("res://src/run/transit_reconstruction_service.gd")

var failures: int = 0

func _init() -> void:
	_test_reconstructs_and_persists_from_time_zero()
	_test_authoritative_trace_mismatch_is_quarantined()
	_test_presentation_cursor_mismatch_resets_without_changing_authority()
	_test_missing_compatibility_never_silently_replays()
	if failures == 0:
		print("transit_reconstruction_test_runner: PASS")
		quit(0)
	else:
		push_error("transit_reconstruction_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_reconstructs_and_persists_from_time_zero() -> void:
	var store: AtomicSaveStore = _fresh_store("reconstruct_ok")
	var record: Dictionary = _record("COMMITTED", 1)
	_expect_true(bool(store.write(&"session", {"committed_run": record})["ok"]), "seed committed session")
	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var resumed: Dictionary = service.resume_current(_compatibility())
	_expect_true(bool(resumed.get("ok", false)), "committed run reconstructs")
	if not bool(resumed.get("ok", false)):
		return
	_expect_equal(String(resumed.get("run_id", "")), "run-reconstruct-1", "resume preserves run identity")
	_expect_equal(int(resumed.get("presentation_cursor", -1)), 1, "valid presentation cursor is restored")
	_expect_equal(String(resumed.get("recovery_class", "")), "NONE", "valid cursor requires no recovery class")
	var trace: PackedStringArray = resumed["tick_checksums"]
	_expect_equal(trace.size(), 3, "full reconstruction recomputes every tick checksum")
	_expect_true(not String(resumed.get("final_result_checksum", "")).is_empty(), "full reconstruction recomputes final result checksum")
	var loaded: Dictionary = store.load(&"session")
	_expect_true(bool(loaded.get("ok", false)), "verified reconstructed session remains durable")
	if bool(loaded.get("ok", false)):
		var envelope: SaveEnvelope = loaded["envelope"]
		var persisted: Dictionary = envelope.payload["committed_run"]
		_expect_equal(String(persisted.get("lifecycle_state", "")), "SIMULATED", "verified committed run advances only to simulated lifecycle")
		_expect_equal(persisted.get("tick_checksums", []), Array(trace), "durable trace matches reconstructed authority")
		_expect_equal(String(persisted.get("final_result_checksum", "")), String(resumed["final_result_checksum"]), "durable final checksum matches reconstruction")
		_expect_true(bool(persisted.get("reconstruction_verified", false)), "verified record is marked explicitly")

func _test_authoritative_trace_mismatch_is_quarantined() -> void:
	var store: AtomicSaveStore = _fresh_store("reconstruct_mismatch")
	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var record: Dictionary = _record("SIMULATED", 2)
	var baseline: Dictionary = service.reconstruct_record(record, _compatibility())
	_expect_true(bool(baseline.get("ok", false)), "baseline reconstruction for mismatch fixture resolves")
	if not bool(baseline.get("ok", false)):
		return
	var stored_trace: Array = Array(baseline["tick_checksums"])
	stored_trace[0] = "stored-authority-does-not-match"
	record["tick_checksums"] = stored_trace
	record["final_result_checksum"] = String(baseline["final_result_checksum"])
	_expect_true(bool(store.write(&"session", {"committed_run": record})["ok"]), "seed mismatched simulated session")
	var resumed: Dictionary = service.resume_current(_compatibility())
	_expect_true(not bool(resumed.get("ok", true)), "authoritative trace mismatch must not continue")
	_expect_equal(String(resumed.get("recovery_class", "")), "C", "authoritative mismatch uses frozen class C")
	_expect_true(String(resumed.get("error", "")).begins_with("authoritative_reconstruction_mismatch:"), "mismatch has typed recovery error")
	var loaded: Dictionary = store.load(&"session")
	_expect_true(bool(loaded.get("ok", false)), "mismatch quarantine remains durable")
	if bool(loaded.get("ok", false)):
		var envelope: SaveEnvelope = loaded["envelope"]
		var persisted: Dictionary = envelope.payload["committed_run"]
		_expect_equal(String(persisted.get("lifecycle_state", "")), "RECONSTRUCTION_MISMATCH", "suspect run is quarantined")
		var diagnostics: Dictionary = persisted.get("reconstruction_diagnostics", {})
		_expect_equal(String(diagnostics.get("kind", "")), "tick_checksum_sequence", "both checksum traces are retained as diagnostics")

func _test_presentation_cursor_mismatch_resets_without_changing_authority() -> void:
	var store: AtomicSaveStore = _fresh_store("reconstruct_cursor")
	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var record: Dictionary = _record("COMMITTED", 99)
	var baseline: Dictionary = service.reconstruct_record(record, _compatibility())
	_expect_true(bool(baseline.get("ok", false)), "cursor baseline reconstructs")
	if not bool(baseline.get("ok", false)):
		return
	record["tick_checksums"] = Array(baseline["tick_checksums"])
	record["final_result_checksum"] = String(baseline["final_result_checksum"])
	_expect_true(bool(store.write(&"session", {"committed_run": record})["ok"]), "seed invalid cursor session")
	var resumed: Dictionary = service.resume_current(_compatibility())
	_expect_true(bool(resumed.get("ok", false)), "presentation-only mismatch does not invalidate authoritative run")
	if bool(resumed.get("ok", false)):
		_expect_equal(String(resumed.get("recovery_class", "")), "A", "presentation cursor mismatch uses frozen class A")
		_expect_true(bool(resumed.get("presentation_cursor_reset", false)), "invalid cursor is explicitly reset")
		_expect_equal(int(resumed.get("presentation_cursor", -1)), 0, "in-transit invalid cursor resets to tick zero")
		_expect_equal(Array(resumed["tick_checksums"]), record["tick_checksums"], "cursor repair leaves authoritative tick hashes unchanged")

func _test_missing_compatibility_never_silently_replays() -> void:
	var store: AtomicSaveStore = _fresh_store("reconstruct_compatibility")
	var record: Dictionary = _record("COMMITTED", 0)
	_expect_true(bool(store.write(&"session", {"committed_run": record})["ok"]), "seed compatibility session")
	var incompatible: Dictionary = _compatibility()
	incompatible["rules_version"] = "rules-other"
	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var resumed: Dictionary = service.resume_current(incompatible)
	_expect_true(not bool(resumed.get("ok", true)), "wrong compatibility package is rejected before replay")
	_expect_equal(String(resumed.get("recovery_class", "")), "D", "missing exact compatibility follows frozen class D boundary")
	var loaded: Dictionary = store.load(&"session")
	_expect_true(bool(loaded.get("ok", false)), "class-D invalidation remains durable")
	if bool(loaded.get("ok", false)):
		var envelope: SaveEnvelope = loaded["envelope"]
		var persisted: Dictionary = envelope.payload["committed_run"]
		_expect_equal(String(persisted.get("lifecycle_state", "")), "ABANDONED/INVALIDATED", "missing compatibility invalidates the legacy in-progress run")
		_expect_equal(persisted.get("planning_baseline", {}), record["canonical_committed_input"], "class D preserves committed input as the planning baseline")
		_expect_true(bool(persisted.get("restart_under_current_version_required", false)), "class D requires restart under the current version")
		_expect_true(not persisted.has("tick_checksums"), "class D does not fabricate an authoritative trace")
		_expect_true(not persisted.has("final_result_checksum"), "class D does not fabricate an old result")
		_expect_true(not persisted.has("completion_id"), "class D does not fabricate a completion")
		_expect_true(not persisted.has("reconstruction_verified"), "class D does not mark an unavailable replay verified")
	var profile_load: Dictionary = store.load(&"profile")
	_expect_true(not bool(profile_load.get("ok", false)), "class D does not create or apply progression")

func _record(lifecycle: String, cursor: int) -> Dictionary:
	var committed_input: Dictionary = {
		"route_id": "route-reconstruct",
		"seed": 101,
		"placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}],
		"supports": [],
		"contract_id": "contract-reconstruct",
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"generator_version": "",
		"expected_contract_definition_checksum": "contract-def-r1",
	}
	var normalized_text: String = JSON.stringify(committed_input, "", true, true)
	var normalized_value: Variant = JSON.parse_string(normalized_text)
	var normalized: Dictionary = normalized_value
	return {
		"profile_uuid": "profile-1",
		"run_id": "run-reconstruct-1",
		"contract_id": "contract-reconstruct",
		"planning_revision_id": "revision-1",
		"canonical_committed_input": normalized,
		"committed_input_checksum": JSON.stringify(normalized, "", true, true).sha256_text(),
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"generator_version": "",
		"expected_contract_definition_checksum": "contract-def-r1",
		"lifecycle_state": lifecycle,
		"last_presented_tick_cursor": cursor,
	}

func _compatibility() -> Dictionary:
	return {
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"contract_definition_checksum": "contract-def-r1",
		"total_ticks": 3,
		"simulation_defs": _defs(),
		"mandatory_predicates": [
			{"id": "m-stress", "kind": "STRESS_AT_MOST", "instance_id": "specimen-a", "value": 20},
			{"id": "m-state", "kind": "PRIMARY_STATE_IS", "instance_id": "specimen-a", "value": "PANICKED"},
		],
	}

func _defs() -> Dictionary:
	return {
		"route_profile": {
			"id": "route-reconstruct",
			"tick_count": 3,
			"events": [{"tick": 2, "duration_ticks": 1, "hazard_id": "h01-reconstruct", "authored_order": 0}],
		},
		"hold_definition": {"dimensions": [1, 1], "blocked_cells": []},
		"hazards_by_id": {
			"h01-reconstruct": {"id": "h01-reconstruct", "family": "H01", "target_scope": "hold", "heat_delta": 6},
		},
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
	}

func _fresh_store(name: String) -> AtomicSaveStore:
	var root: String = "user://%s" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	for suffix: String in ["session.sav", "session.sav.bak", "session.sav.tmp", "profile.sav", "profile.sav.bak", "profile.sav.tmp"]:
		var path: String = root.path_join(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return AtomicSaveStoreScript.new(root)

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
