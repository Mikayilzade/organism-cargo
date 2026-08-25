extends SceneTree

const StoreScript := preload("res://src/validation/phase12g_empirical_evidence_store.gd")

var failures: int = 0
const TEST_PATH := "user://phase12g_evidence_store_test/observations.json"

func _init() -> void:
	_clear_test_path()
	_test_append_load_evaluate_and_reject()
	_clear_test_path()
	_finish()

func _test_append_load_evaluate_and_reject() -> void:
	var store: Phase12GEmpiricalEvidenceStore = StoreScript.new(TEST_PATH)
	var initial: Dictionary = store.load_dataset()
	_expect(bool(initial.get("ok", false)), "missing evidence file opens as an empty versioned dataset")
	_expect_equal(((initial.get("dataset", {}) as Dictionary).get("samples", []) as Array).size(), 0, "new evidence store starts empty")

	var first: Dictionary = _retry_sample("capture-1", 1800000101)
	var appended: Dictionary = store.append_sample(first)
	_expect(bool(appended.get("ok", false)), "valid empirical observation is recorded")
	_expect_equal(appended.get("sample_count"), 1, "recorded sample count is returned")
	_expect(FileAccess.file_exists(TEST_PATH), "recording persists an evidence file")

	var reloaded: Dictionary = store.load_dataset()
	_expect(bool(reloaded.get("ok", false)), "recorded evidence reloads through schema validation")
	var samples: Array = (reloaded.get("dataset", {}) as Dictionary).get("samples", [])
	_expect_equal(samples.size(), 1, "reloaded evidence preserves the observation")
	_expect_equal((samples[0] as Dictionary).get("sample_id"), "capture-1", "reloaded observation identity is stable")

	var duplicate: Dictionary = store.append_sample(first)
	_expect(not bool(duplicate.get("ok", true)), "duplicate sample identity is rejected before write")
	_expect(String(duplicate.get("error", "")).contains("duplicate_sample_id"), "duplicate rejection reports schema reason")
	var after_duplicate: Dictionary = store.load_dataset()
	_expect_equal((((after_duplicate.get("dataset", {}) as Dictionary).get("samples", [])) as Array).size(), 1, "rejected duplicate does not corrupt persisted evidence")

	var malformed: Dictionary = _retry_sample("capture-2", 1800000102)
	malformed.erase("intended_revision")
	var malformed_result: Dictionary = store.append_sample(malformed)
	_expect(not bool(malformed_result.get("ok", true)), "incomplete observation is rejected before write")
	var after_malformed: Dictionary = store.load_dataset()
	_expect_equal((((after_malformed.get("dataset", {}) as Dictionary).get("samples", [])) as Array).size(), 1, "rejected malformed sample does not alter persisted evidence")

	var report: Dictionary = store.evaluate_current()
	_expect(bool(report.get("ok", false)), "stored raw evidence can be evaluated independently")
	_expect_equal(report.get("overall_status"), "INCOMPLETE", "one retry observation cannot fabricate completion of unrelated empirical gates")

func _retry_sample(sample_id: String, captured_at_unix: int) -> Dictionary:
	return {
		"sample_id": sample_id,
		"sample_type": "failed_review_retry",
		"tester_id": "tester-store",
		"captured_at_unix": captured_at_unix,
		"contract_id": "C09",
		"causal_explanation": "heat pulse caused the failure",
		"intended_revision": "move the target outside the pulse relationship",
		"blind_shuffle": false,
	}

func _clear_test_path() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var temp_path := "%s.tmp" % absolute_path
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _finish() -> void:
	if failures == 0:
		print("phase12g_empirical_evidence_store_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12g_empirical_evidence_store_test_runner: %d failure(s)" % failures)
		quit(1)
