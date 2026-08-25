extends SceneTree

const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const PersistenceReconciliationServiceScript := preload("res://src/save/persistence_reconciliation_service.gd")

var failures: int = 0

func _init() -> void:
	_test_profile_cloud_monotonic_merge_and_uuid_separation()
	_test_divergent_active_sessions_never_auto_merge()
	_test_migration_source_preservation_and_sequential_boundary()
	_test_legacy_challenge_rejects_unsupported_version()
	_test_demo_import_idempotency_and_progress_bounds()
	if failures == 0:
		print("phase12f_reconciliation_adversarial_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12f_reconciliation_adversarial_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_profile_cloud_monotonic_merge_and_uuid_separation() -> void:
	var service: PersistenceReconciliationService = PersistenceReconciliationServiceScript.new()
	var local: Dictionary = {
		"profile_uuid": "profile-shared",
		"save_format_version": 3,
		"cleared_bronze_contract_ids": ["C01", "C16"],
		"best_medal_by_contract": {"C01": "GOLD", "C02": "BRONZE"},
		"documented_fact_ids": ["fact-local"],
		"applied_completion_ids": ["completion-local"],
		"permanent_unlock_flags": ["unlock-local"],
	}
	var cloud: Dictionary = {
		"profile_uuid": "profile-shared",
		"save_format_version": 3,
		"cleared_bronze_contract_ids": ["C02", "C17"],
		"best_medal_by_contract": {"C01": "SILVER", "C02": "GOLD", "C17": "SILVER"},
		"documented_fact_ids": ["fact-cloud"],
		"applied_completion_ids": ["completion-cloud"],
		"permanent_unlock_flags": ["unlock-cloud"],
	}
	var merged: Dictionary = service.merge_profiles(local, cloud)
	_expect(bool(merged.get("ok", false)), "same-UUID compatible profile branches merge")
	_expect_equal(String(merged.get("resolution", "")), "merged_monotonic", "profile merge explicitly uses monotonic resolution")
	var profile: Dictionary = _dict(merged.get("profile", {}))
	_expect_strings(profile.get("cleared_bronze_contract_ids", []), ["C01", "C02", "C16", "C17"], "Bronze progress is set union and cannot roll back")
	_expect_equal(_dict(profile.get("best_medal_by_contract", {})).get("C01"), "GOLD", "cloud downgrade cannot roll back local Gold")
	_expect_equal(_dict(profile.get("best_medal_by_contract", {})).get("C02"), "GOLD", "cloud higher medal advances by max")
	_expect_equal(_dict(profile.get("best_medal_by_contract", {})).get("C17"), "SILVER", "cloud-only medal is retained")
	_expect_strings(profile.get("documented_fact_ids", []), ["fact-cloud", "fact-local"], "Codex facts merge by union")
	_expect_strings(profile.get("applied_completion_ids", []), ["completion-cloud", "completion-local"], "completion ledger merges by union")
	_expect_strings(profile.get("permanent_unlock_flags", []), ["unlock-cloud", "unlock-local"], "permanent unlock flags merge by union")
	_expect(bool(merged.get("challenge_mode_unlocked", false)), "Challenge availability is re-derived from merged Bronze C16")

	var foreign: Dictionary = cloud.duplicate(true)
	foreign["profile_uuid"] = "different-profile"
	var separated: Dictionary = service.merge_profiles(local, foreign)
	_expect(not bool(separated.get("ok", true)), "different profile UUIDs cannot auto-merge")
	_expect_equal(String(separated.get("error", "")), "profile_uuid_conflict", "UUID conflict is explicit")
	_expect_equal(String(separated.get("resolution", "")), "keep_separate", "different profiles remain separate")
	_expect_equal(_array(separated.get("profiles", [])).size(), 2, "both profile branches remain recoverable")

func _test_divergent_active_sessions_never_auto_merge() -> void:
	var service: PersistenceReconciliationService = PersistenceReconciliationServiceScript.new()
	var committed: Dictionary = {
		"profile_uuid": "profile-session",
		"run_id": "run-shared",
		"committed_input_checksum": "checksum-shared",
		"lifecycle_state": "COMMITTED",
		"canonical_committed_input": {"seed": 7, "placements": [{"instance_id": "a", "anchor": [0, 0]}]},
	}
	var reviewable: Dictionary = committed.duplicate(true)
	reviewable["lifecycle_state"] = "REVIEWABLE"
	var same_lineage: Dictionary = service.resolve_active_session_conflict(committed, reviewable)
	_expect(bool(same_lineage.get("ok", false)), "same-lineage sessions can resolve by lifecycle")
	_expect_equal(String(same_lineage.get("resolution", "")), "same_lineage_later_lifecycle", "later same-lineage lifecycle is selected")
	_expect_equal(String(_dict(same_lineage.get("selected", {})).get("lifecycle_state", "")), "REVIEWABLE", "strictly later lifecycle wins only when run/checksum agree")

	var divergent: Dictionary = reviewable.duplicate(true)
	divergent["run_id"] = "run-other-device"
	divergent["committed_input_checksum"] = "checksum-other"
	divergent["canonical_committed_input"] = {"seed": 99, "placements": [{"instance_id": "a", "anchor": [1, 0]}]}
	var conflict: Dictionary = service.resolve_active_session_conflict(committed, divergent)
	_expect(bool(conflict.get("ok", false)), "divergent sessions produce recoverable conflict rather than corruption")
	_expect_equal(String(conflict.get("resolution", "")), "retain_both_require_choice", "divergent active sessions are never cell-by-cell merged")
	_expect_equal(String(conflict.get("reason", "")), "divergent_session_identity", "divergent identity is diagnosed")
	var retained: Array = _array(conflict.get("retained", []))
	_expect_equal(retained.size(), 2, "both divergent sessions remain recoverable")
	if retained.size() == 2:
		_expect_equal(_dict(retained[0]).get("canonical_committed_input"), committed["canonical_committed_input"], "first committed baseline remains immutable")
		_expect_equal(_dict(retained[1]).get("canonical_committed_input"), divergent["canonical_committed_input"], "second committed baseline remains immutable")

func _test_migration_source_preservation_and_sequential_boundary() -> void:
	var service: PersistenceReconciliationService = PersistenceReconciliationServiceScript.new()
	var store: AtomicSaveStore = _fresh_store("phase12f_migration")
	var source: Dictionary = {
		"profile_uuid": "profile-migrate",
		"save_format_version": 1,
		"cleared_bronze_contract_ids": ["C01", "C02"],
		"best_medal_by_contract": {"C01": "GOLD"},
		"documented_fact_ids": ["old-fact"],
		"applied_completion_ids": ["old-completion"],
	}
	_expect(bool(store.write(&"profile", source).get("ok", false)), "migration fixture source is durable")
	var durable_source: Dictionary = _load_payload(store, &"profile")
	var failed: Dictionary = service.migrate_profile_in_store(store, 3, {
		"1->2": Callable(self, "_migration_1_to_2"),
		"2->3": Callable(self, "_migration_fail_2_to_3"),
	})
	_expect(not bool(failed.get("ok", true)), "failed migration does not install partial target")
	_expect(String(failed.get("error", "")).contains("migration_step_failed:2->3"), "failed migration identifies exact sequential step")
	_expect_equal(_dict(failed.get("source_recovery", {})), durable_source, "failed migration returns the exact durable pre-migration recovery payload")
	var after_failure: Dictionary = _load_payload(store, &"profile")
	_expect_equal(int(after_failure.get("save_format_version", 0)), 1, "failed migration does not partially advance stored format version")
	_expect_strings(after_failure.get("cleared_bronze_contract_ids", []), ["C01", "C02"], "failed migration preserves permanent Bronze")
	var paths: Dictionary = store.paths_for(&"profile")
	_expect(FileAccess.file_exists(String(paths.get("backup", ""))), "migration preservation creates a validated backup source generation")

	var successful: Dictionary = service.migrate_profile_in_store(store, 3, {
		"1->2": Callable(self, "_migration_1_to_2"),
		"2->3": Callable(self, "_migration_2_to_3"),
	})
	_expect(bool(successful.get("ok", false)), "complete sequential migration installs current target")
	var current: Dictionary = _load_payload(store, &"profile")
	_expect_equal(int(current.get("save_format_version", 0)), 3, "successful migration reaches target format")
	_expect_strings(current.get("cleared_bronze_contract_ids", []), ["C01", "C02", "C03"], "migration may add progress but cannot roll old progress back")
	_expect_strings(current.get("documented_fact_ids", []), ["new-fact", "old-fact"], "migration preserves and explicitly extends knowledge")
	var no_op: Dictionary = service.migrate_profile_in_store(store, 3, {})
	_expect(bool(no_op.get("ok", false)), "already-current migration pipeline succeeds")
	_expect(bool(no_op.get("no_op", false)), "rerunning current migration pipeline is a no-op")
	_expect_equal(_dict(no_op.get("profile", {})), current, "no-op migration does not mutate current profile")

func _test_legacy_challenge_rejects_unsupported_version() -> void:
	var service: PersistenceReconciliationService = PersistenceReconciliationServiceScript.new()
	var supported: Array = [{"generator_version": "gen-2", "rules_version": "rules-2", "content_version": "content-2"}]
	var compatible: Dictionary = {
		"template_id": "G01", "seed": 12345,
		"generator_version": "gen-2", "rules_version": "rules-2", "content_version": "content-2",
	}
	var accepted: Dictionary = service.validate_legacy_challenge_identity(compatible, supported)
	_expect(bool(accepted.get("ok", false)), "exact compatible challenge version is accepted")
	_expect(bool(accepted.get("construct_gameplay", false)), "compatible identity may construct gameplay")

	var legacy: Dictionary = compatible.duplicate(true)
	legacy["generator_version"] = "gen-1-retired"
	var rejected: Dictionary = service.validate_legacy_challenge_identity(legacy, supported)
	_expect(not bool(rejected.get("ok", true)), "unsupported legacy generator package is rejected")
	_expect_equal(String(rejected.get("error", "")), "legacy_challenge_version", "legacy rejection is explicit rather than regenerated")
	_expect(not bool(rejected.get("construct_gameplay", true)), "unsupported legacy identity cannot construct a different puzzle")
	_expect_equal(_dict(rejected.get("identity", {})).get("seed"), 12345, "legacy rejection retains original visible seed for diagnostics")

func _test_demo_import_idempotency_and_progress_bounds() -> void:
	var service: PersistenceReconciliationService = PersistenceReconciliationServiceScript.new()
	var mapping: Dictionary = _load_json_document("res://content/demo/public_demo_mapping.json")
	_expect(not mapping.is_empty(), "canonical public demo mapping loads")
	if mapping.is_empty():
		return
	var target: Dictionary = {
		"profile_uuid": "full-profile",
		"save_format_version": 3,
		"cleared_bronze_contract_ids": ["C20"],
		"best_medal_by_contract": {"C20": "GOLD"},
		"documented_fact_ids": ["full-fact"],
		"applied_completion_ids": ["full-completion"],
		"mechanical_power": {"support_tokens": 99},
	}
	var demo: Dictionary = {
		"profile_uuid": "demo-profile",
		"demo_profile_revision": "demo-revision-44",
		"cleared_bronze_contract_ids": ["D01", "D08", "D09", "D10"],
		"documented_fact_ids": ["demo-fact", "O13"],
		"settings": {"ui_scale_percent": 175},
		"mechanical_power": {"support_tokens": 999999},
		"challenge_unlocked": true,
	}
	var first: Dictionary = service.apply_demo_import(target, demo, mapping, "demo-import-schema-1")
	_expect(bool(first.get("ok", false)), "validated demo import succeeds")
	_expect(not bool(first.get("duplicate", true)), "first import is not duplicate")
	var imported: Dictionary = _dict(first.get("profile", {}))
	_expect_strings(imported.get("cleared_bronze_contract_ids", []), ["C01", "C08", "C20"], "only D01-D08 mapping can add C01-C08 Bronze")
	_expect(not "C09" in _strings(imported.get("cleared_bronze_contract_ids", [])), "D09 never clears C09")
	_expect(not "C10" in _strings(imported.get("cleared_bronze_contract_ids", [])), "D10 never clears C10")
	_expect_strings(imported.get("documented_fact_ids", []), ["O13", "demo-fact", "full-fact"], "documented knowledge transfers monotonically")
	_expect_equal(_dict(imported.get("best_medal_by_contract", {})).get("C20"), "GOLD", "stronger full-game medal is untouched by demo import")
	_expect_equal(_dict(imported.get("mechanical_power", {})).get("support_tokens"), 99, "demo mechanical power cannot overwrite full-game mechanical state")
	_expect_equal(_dict(imported.get("settings", {})).get("ui_scale_percent"), 175, "settings may transfer through canonical mapping")
	_expect(not bool(first.get("challenge_mode_unlocked", true)), "imported knowledge/demo completion cannot unlock Challenge without Bronze C16")
	var import_id: String = String(first.get("import_id", ""))
	_expect(not import_id.is_empty(), "demo import owns deterministic import identity")

	var repeated: Dictionary = service.apply_demo_import(imported, demo, mapping, "demo-import-schema-1")
	_expect(bool(repeated.get("ok", false)), "repeating same demo import succeeds idempotently")
	_expect(bool(repeated.get("duplicate", false)), "repeated demo import is detected by durable-style import id")
	_expect_equal(_dict(repeated.get("profile", {})), imported, "repeating demo import is a no-op beyond monotonic state")

	var unlocked_target: Dictionary = imported.duplicate(true)
	var unlocked_bronze: Array = _array(unlocked_target.get("cleared_bronze_contract_ids", [])).duplicate()
	unlocked_bronze.append("C16")
	unlocked_target["cleared_bronze_contract_ids"] = unlocked_bronze
	unlocked_target["applied_demo_import_ids"] = []
	var unlocked_import: Dictionary = service.apply_demo_import(unlocked_target, demo, mapping, "demo-import-schema-2")
	_expect(bool(unlocked_import.get("challenge_mode_unlocked", false)), "Challenge derives true only when target profile already owns Bronze C16")

func _migration_1_to_2(profile: Dictionary) -> Dictionary:
	var next: Dictionary = profile.duplicate(true)
	var facts: Array = _array(next.get("documented_fact_ids", [])).duplicate()
	if not "new-fact" in facts:
		facts.append("new-fact")
	next["documented_fact_ids"] = facts
	return {"ok": true, "profile": next}

func _migration_fail_2_to_3(_profile: Dictionary) -> Dictionary:
	return {"ok": false, "error": "hostile_fixture_failure"}

func _migration_2_to_3(profile: Dictionary) -> Dictionary:
	var next: Dictionary = profile.duplicate(true)
	var bronze: Array = _array(next.get("cleared_bronze_contract_ids", [])).duplicate()
	if not "C03" in bronze:
		bronze.append("C03")
	next["cleared_bronze_contract_ids"] = bronze
	return {"ok": true, "profile": next}

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

func _load_json_document(path: String) -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}

func _strings(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is Array or value is PackedStringArray:
		for raw: Variant in value:
			result.append(String(raw))
	result.sort()
	return result

func _expect_strings(actual: Variant, expected: Array, label: String) -> void:
	var actual_strings: PackedStringArray = _strings(actual)
	var expected_strings: PackedStringArray = PackedStringArray()
	for raw: Variant in expected:
		expected_strings.append(String(raw))
	expected_strings.sort()
	_expect_equal(actual_strings, expected_strings, label)

func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _array(value: Variant) -> Array:
	return value if value is Array else Array(value) if value is PackedStringArray else []

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
