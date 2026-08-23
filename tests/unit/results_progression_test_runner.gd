extends SceneTree

const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")
const ResultsProgressionServiceScript := preload("res://src/run/results_progression_service.gd")

var failures: int = 0

func _init() -> void:
	_test_success_applies_exactly_once_and_repairs_session()
	_test_medal_and_knowledge_merge_monotonically()
	_test_crash_boundary_repairs_session_without_reaward()
	_test_failed_delivery_never_creates_completion()
	if failures == 0:
		print("results_progression_test_runner: PASS")
		quit(0)
	else:
		push_error("results_progression_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_success_applies_exactly_once_and_repairs_session() -> void:
	var store: AtomicSaveStore = _fresh_store("results_once")
	var record: Dictionary = _record("run-1", "C01")
	_seed_session(store, record)
	var service: ResultsProgressionService = ResultsProgressionServiceScript.new(store)
	var first: Dictionary = service.apply_authoritative_result(record, _result(true, "result-1"), "SILVER", ["fact-heat"])
	_expect_true(bool(first.get("ok", false)), "first successful result applies")
	_expect_true(bool(first.get("applied", false)), "first result is a new application")
	_expect_true(not bool(first.get("duplicate", true)), "first result is not duplicate")
	var completion_id: String = String(first.get("completion_id", ""))
	_expect_true(not completion_id.is_empty(), "successful result derives deterministic completion id")
	var duplicate: Dictionary = service.apply_authoritative_result(record, _result(true, "result-1"), "SILVER", ["fact-heat"])
	_expect_true(bool(duplicate.get("ok", false)), "reopened Results succeeds")
	_expect_true(bool(duplicate.get("duplicate", false)), "reopened Results is idempotent duplicate")
	_expect_equal(String(duplicate.get("completion_id", "")), completion_id, "duplicate recomputes identical completion id")
	var profile: Dictionary = _load_payload(store, &"profile")
	_expect_equal(profile.get("cleared_bronze_contract_ids", []), ["C01"], "success stores Bronze clear as set membership")
	_expect_equal(profile.get("best_medal_by_contract", {}).get("C01", ""), "SILVER", "best medal stored as maximum")
	_expect_equal(profile.get("documented_fact_ids", []), ["fact-heat"], "documented knowledge is union state")
	_expect_equal((profile.get("applied_completion_ids", []) as Array).size(), 1, "completion ledger contains exactly one id")
	var session: Dictionary = _load_payload(store, &"session")
	var persisted: Dictionary = session.get("committed_run", {})
	_expect_equal(String(persisted.get("lifecycle_state", "")), "COMPLETION_APPLIED", "profile durability precedes applied session lifecycle")
	_expect_equal(String(persisted.get("completion_id", "")), completion_id, "session records deterministic completion id")

func _test_medal_and_knowledge_merge_monotonically() -> void:
	var store: AtomicSaveStore = _fresh_store("results_merge")
	var first_record: Dictionary = _record("run-a", "C02")
	_seed_session(store, first_record)
	var service: ResultsProgressionService = ResultsProgressionServiceScript.new(store)
	var silver: Dictionary = service.apply_authoritative_result(first_record, _result(true, "result-a"), "SILVER", ["fact-a"])
	_expect_true(bool(silver.get("ok", false)), "silver result applies")
	var second_record: Dictionary = _record("run-b", "C02")
	_seed_session(store, second_record)
	var bronze: Dictionary = service.apply_authoritative_result(second_record, _result(true, "result-b"), "BRONZE", ["fact-b"])
	_expect_true(bool(bronze.get("ok", false)), "later bronze result applies as distinct run")
	var profile_after_bronze: Dictionary = _load_payload(store, &"profile")
	_expect_equal(profile_after_bronze.get("best_medal_by_contract", {}).get("C02", ""), "SILVER", "weaker replay cannot lower best medal")
	_expect_equal(profile_after_bronze.get("documented_fact_ids", []), ["fact-a", "fact-b"], "knowledge merges by union")
	var third_record: Dictionary = _record("run-c", "C02")
	_seed_session(store, third_record)
	var gold: Dictionary = service.apply_authoritative_result(third_record, _result(true, "result-c"), "GOLD", ["fact-c"])
	_expect_true(bool(gold.get("ok", false)), "gold replay applies")
	var profile_after_gold: Dictionary = _load_payload(store, &"profile")
	_expect_equal(profile_after_gold.get("best_medal_by_contract", {}).get("C02", ""), "GOLD", "stronger medal replaces weaker maximum")
	_expect_equal((profile_after_gold.get("cleared_bronze_contract_ids", []) as Array).size(), 1, "repeat successes do not duplicate Bronze membership")
	_expect_equal((profile_after_gold.get("applied_completion_ids", []) as Array).size(), 3, "distinct successful run identities have distinct completion ids")

func _test_crash_boundary_repairs_session_without_reaward() -> void:
	var store: AtomicSaveStore = _fresh_store("results_crash_repair")
	var record: Dictionary = _record("run-crash", "C03")
	_seed_session(store, record)
	var service: ResultsProgressionService = ResultsProgressionServiceScript.new(store)
	var expected_id: String = service._completion_id(record, "result-crash")
	var preapplied_profile: Dictionary = {
		"profile_uuid": "profile-1",
		"cleared_bronze_contract_ids": ["C03"],
		"best_medal_by_contract": {"C03": "GOLD"},
		"documented_fact_ids": ["fact-existing"],
		"applied_completion_ids": [expected_id],
	}
	_expect_true(bool(store.write(&"profile", preapplied_profile).get("ok", false)), "seed profile as if crash happened after atomic profile write")
	var repaired: Dictionary = service.apply_authoritative_result(record, _result(true, "result-crash"), "BRONZE", [])
	_expect_true(bool(repaired.get("ok", false)), "reopen after crash repairs session")
	_expect_true(bool(repaired.get("duplicate", false)), "already durable completion is recognized")
	_expect_true(not bool(repaired.get("applied", true)), "crash repair does not award again")
	var profile: Dictionary = _load_payload(store, &"profile")
	_expect_equal(profile.get("best_medal_by_contract", {}).get("C03", ""), "GOLD", "crash repair cannot downgrade durable profile")
	_expect_equal((profile.get("applied_completion_ids", []) as Array).size(), 1, "crash repair keeps one completion ledger entry")
	var session: Dictionary = _load_payload(store, &"session")
	_expect_equal(String(session.get("committed_run", {}).get("lifecycle_state", "")), "COMPLETION_APPLIED", "crash repair advances only session lifecycle")

func _test_failed_delivery_never_creates_completion() -> void:
	var store: AtomicSaveStore = _fresh_store("results_failure")
	var record: Dictionary = _record("run-fail", "C04")
	_seed_session(store, record)
	var service: ResultsProgressionService = ResultsProgressionServiceScript.new(store)
	var failed: Dictionary = service.apply_authoritative_result(record, _result(false, "result-fail"), "BRONZE", ["fact-should-not-apply"])
	_expect_true(bool(failed.get("ok", false)), "authoritative delivery failure is handled without persistence error")
	_expect_true(not bool(failed.get("applied", true)), "failed mandatory delivery creates no campaign completion")
	_expect_equal(String(failed.get("completion_id", "x")), "", "failed delivery has no completion id")
	var profile_load: Dictionary = store.load(&"profile")
	_expect_true(not bool(profile_load.get("ok", false)), "failed delivery does not create profile progression save")
	var session: Dictionary = _load_payload(store, &"session")
	_expect_equal(String(session.get("committed_run", {}).get("lifecycle_state", "")), "REVIEWABLE", "failed delivery does not mark completion applied")

func _record(run_id: String, contract_id: String) -> Dictionary:
	return {
		"profile_uuid": "profile-1",
		"run_id": run_id,
		"contract_id": contract_id,
		"rules_version": "rules-r1",
		"content_version": "content-r1",
		"lifecycle_state": "REVIEWABLE",
	}

func _result(success: bool, checksum: String) -> Dictionary:
	return {
		"ok": true,
		"completion_checksum": checksum,
		"delivery_result": {"success": success},
	}

func _seed_session(store: AtomicSaveStore, record: Dictionary) -> void:
	_expect_true(bool(store.write(&"session", {"committed_run": record.duplicate(true)}).get("ok", false)), "seed reviewable session")

func _load_payload(store: AtomicSaveStore, kind: StringName) -> Dictionary:
	var loaded: Dictionary = store.load(kind)
	_expect_true(bool(loaded.get("ok", false)), "load %s payload" % String(kind))
	if not bool(loaded.get("ok", false)):
		return {}
	var envelope: SaveEnvelope = loaded["envelope"]
	return envelope.payload.duplicate(true)

func _fresh_store(name: String) -> AtomicSaveStore:
	var root: String = "user://%s" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	for kind: String in ["profile", "session"]:
		for suffix: String in [".sav", ".sav.bak", ".sav.tmp"]:
			var path: String = root.path_join(kind + suffix)
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
