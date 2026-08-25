extends SceneTree

const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const TransitReconstructionServiceScript := preload("res://src/run/transit_reconstruction_service.gd")

var failures: int = 0

func _init() -> void:
	_test_retained_legacy_compatibility_reconstructs_exactly()
	_test_missing_compatibility_invalidates_session_and_preserves_baseline()
	if failures == 0:
		print("phase12f_compatibility_recovery_adversarial_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12f_compatibility_recovery_adversarial_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_retained_legacy_compatibility_reconstructs_exactly() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_legacy_compatibility")
	var record: Dictionary = _record("legacy-rules", "legacy-content", "legacy-contract-checksum")
	_expect(bool(store.write(&"session", {"committed_run": record.duplicate(true)}).get("ok", false)), "legacy compatible session is durable")
	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var resumed: Dictionary = service.resume_current(_compatibility("legacy-rules", "legacy-content", "legacy-contract-checksum"))
	_expect(bool(resumed.get("ok", false)), "retained exact compatibility package reconstructs legacy run")
	_expect_equal(String(resumed.get("recovery_class", "")), "NONE", "exact retained package needs no recovery downgrade")
	var persisted: Dictionary = _dict(_load_payload(store, &"session").get("committed_run", {}))
	_expect_equal(String(persisted.get("run_id", "")), "run-compatibility", "legacy reconstruction preserves run identity")
	_expect_equal(String(persisted.get("lifecycle_state", "")), "SIMULATED", "legacy committed run advances only after exact reconstruction")
	_expect(bool(persisted.get("reconstruction_verified", false)), "legacy run records successful deterministic reconstruction")

func _test_missing_compatibility_invalidates_session_and_preserves_baseline() -> void:
	var store: AtomicSaveStore = _fresh_store("phase12f_missing_compatibility")
	var record: Dictionary = _record("legacy-rules", "legacy-content", "legacy-contract-checksum")
	var original_baseline: Dictionary = _dict(record.get("canonical_committed_input", {})).duplicate(true)
	var profile: Dictionary = {
		"profile_uuid": "profile-compatibility",
		"cleared_bronze_contract_ids": ["C01", "C16"],
		"best_medal_by_contract": {"C16": "GOLD"},
		"applied_completion_ids": ["historical-completion"],
	}
	_expect(bool(store.write(&"profile", profile).get("ok", false)), "permanent historical profile is durable before compatibility failure")
	_expect(bool(store.write(&"session", {"committed_run": record.duplicate(true)}).get("ok", false)), "incompatible legacy session is durable")

	var service: TransitReconstructionService = TransitReconstructionServiceScript.new(store)
	var failed: Dictionary = service.resume_current(_compatibility("current-rules", "current-content", "current-contract-checksum"))
	_expect(not bool(failed.get("ok", true)), "missing legacy compatibility never silently reconstructs under current rules")
	_expect_equal(String(failed.get("recovery_class", "")), "D", "missing compatibility follows recovery class D")
	_expect(bool(failed.get("restart_required", false)), "class D explicitly requires restart under current compatible version")
	_expect_equal(String(failed.get("recovery_action", "")), "restart_from_committed_layout_under_current_version", "class D exposes truthful restart action")
	_expect_equal(_dict(failed.get("planning_baseline", {})), original_baseline, "class D returns exact immutable committed layout as planning baseline")
	_expect(String(failed.get("error", "")).contains("compatibility_"), "class D explains the compatibility boundary")

	var persisted_session: Dictionary = _dict(_load_payload(store, &"session").get("committed_run", {}))
	_expect_equal(String(persisted_session.get("lifecycle_state", "")), "ABANDONED/INVALIDATED", "old incompatible run is durably invalidated")
	_expect_equal(String(persisted_session.get("run_id", "")), "run-compatibility", "invalidation preserves old run identity for diagnostics/history")
	_expect_equal(_dict(persisted_session.get("canonical_committed_input", {})), original_baseline, "invalidation never mutates authoritative old committed input")
	_expect_equal(_dict(persisted_session.get("planning_baseline", {})), original_baseline, "durable session retains explicit restart planning baseline")
	_expect(bool(persisted_session.get("restart_under_current_version_required", false)), "durable session records restart requirement")
	_expect(String(persisted_session.get("final_result_checksum", "")).is_empty(), "class D never fabricates an old outcome")

	var persisted_profile: Dictionary = _load_payload(store, &"profile")
	_expect_equal(_array(persisted_profile.get("cleared_bronze_contract_ids", [])).size(), 2, "session compatibility failure cannot roll back historical Bronze progress")
	_expect_equal(_dict(persisted_profile.get("best_medal_by_contract", {})).get("C16"), "GOLD", "session compatibility failure cannot roll back historical best medal")
	_expect_equal(_array(persisted_profile.get("applied_completion_ids", [])).size(), 1, "session compatibility failure cannot erase completion ledger")

	var second: Dictionary = service.resume_current(_compatibility("current-rules", "current-content", "current-contract-checksum"))
	_expect(not bool(second.get("ok", true)), "invalidated session cannot be silently resumed on repeated Continue")
	_expect(String(second.get("error", "")).contains("invalid_reconstruction_lifecycle"), "repeated Continue stops at explicit invalidated lifecycle boundary")

func _record(rules_version: String, content_version: String, contract_checksum: String) -> Dictionary:
	var committed_input: Dictionary = {
		"route_id": "route-compatibility",
		"manifest_instance_ids": ["specimen-a"],
		"placements": [{"instance_id": "specimen-a", "anchor": [0, 0], "orientation": 0}],
		"supports": [],
		"seed": 77,
	}
	committed_input["contract_id"] = "C01"
	committed_input["rules_version"] = rules_version
	committed_input["content_version"] = content_version
	committed_input["generator_version"] = ""
	committed_input["expected_contract_definition_checksum"] = contract_checksum
	var normalized_value: Variant = JSON.parse_string(JSON.stringify(committed_input, "", true, true))
	var normalized: Dictionary = normalized_value if normalized_value is Dictionary else {}
	return {
		"profile_uuid": "profile-compatibility",
		"run_id": "run-compatibility",
		"contract_id": "C01",
		"planning_revision_id": "revision-compatibility",
		"canonical_committed_input": normalized,
		"committed_input_checksum": JSON.stringify(normalized, "", true, true).sha256_text(),
		"rules_version": rules_version,
		"content_version": content_version,
		"generator_version": "",
		"expected_contract_definition_checksum": contract_checksum,
		"lifecycle_state": "COMMITTED",
	}

func _compatibility(rules_version: String, content_version: String, contract_checksum: String) -> Dictionary:
	return {
		"rules_version": rules_version,
		"content_version": content_version,
		"contract_definition_checksum": contract_checksum,
		"total_ticks": 2,
		"simulation_defs": {
			"route_profile": {"id": "route-compatibility", "tick_count": 2, "events": []},
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
