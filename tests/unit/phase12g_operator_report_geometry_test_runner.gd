extends SceneTree

const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")
const GeometryEvaluatorScript := preload("res://src/validation/phase12g_bronze_geometry_evidence_evaluator.gd")

var failures: int = 0

func _init() -> void:
	_test_operator_import_filter_and_report()
	_test_operator_metadata_fail_closed()
	_test_geometry_schema_and_insufficient_production_state()
	_test_geometry_gate_math_with_synthetic_authoritative_fixture()
	_finish()

func _test_operator_import_filter_and_report() -> void:
	var service: Phase12GEvidenceReportService = ReportServiceScript.new()
	var dataset: Dictionary = _operator_dataset()
	var path := "user://phase12g_operator_fixture.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "operator fixture file opens")
	if file != null:
		file.store_string(JSON.stringify(dataset, "  ", true, true))
		file.close()
	var loaded: Dictionary = service.load_external_json(path)
	_expect(bool(loaded.get("ok", false)), "external versioned evidence JSON imports")
	var report: Dictionary = service.evaluate_operator_dataset(loaded.get("dataset", {}))
	_expect(bool(report.get("ok", false)), "operator dataset validates and evaluates")
	_expect_equal(report.get("source_sample_count"), 6, "source count preserves excluded observations")
	_expect_equal(report.get("eligible_sample_count"), 4, "cohort filters exclude tutorial retry and mastery planning from ordinary median")
	var gates: Dictionary = report.get("gates", {})
	_expect_equal((gates.get("hypothesis_driven_retry", {}) as Dictionary).get("status"), "PASS", "post-onboarding retry evidence is evaluated")
	_expect_equal((gates.get("planning_duration", {}) as Dictionary).get("status"), "PASS", "ordinary familiar planning cohort is evaluated")
	_expect_near(float((gates.get("planning_duration", {}) as Dictionary).get("median_seconds", 0.0)), 420.0, "mastery observation does not contaminate ordinary median")
	_expect_equal((gates.get("demo_identity", {}) as Dictionary).get("status"), "PASS", "demo identity uses explicit demo cohort")
	var text: String = service.human_readable_report(report)
	_expect(text.contains("PHASE 12G EMPIRICAL GATE REPORT"), "human report has stable heading")
	_expect(text.contains("planning_duration: PASS"), "human report exposes gate state")
	var written: Dictionary = service.write_report_files(report, "user://phase12g_report/report.json", "user://phase12g_report/report.txt")
	_expect(bool(written.get("ok", false)), "machine and human reports write")
	_expect(FileAccess.file_exists("user://phase12g_report/report.json"), "machine-readable report exists")
	_expect(FileAccess.file_exists("user://phase12g_report/report.txt"), "human-readable report exists")

func _test_operator_metadata_fail_closed() -> void:
	var service: Phase12GEvidenceReportService = ReportServiceScript.new()
	var missing_metadata: Dictionary = _operator_dataset()
	missing_metadata.erase("collection_metadata")
	var result: Dictionary = service.validate_operator_dataset(missing_metadata)
	_expect(not bool(result.get("ok", true)), "operator import rejects absent provenance metadata")
	_expect_equal(result.get("error"), "missing_collection_metadata", "missing provenance has deterministic error")
	var wrong_cohort: Dictionary = _operator_dataset()
	var samples: Array = wrong_cohort["samples"]
	var demo: Dictionary = samples[4]
	demo["cohort"] = ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY
	samples[4] = demo
	wrong_cohort["samples"] = samples
	var wrong: Dictionary = service.validate_operator_dataset(wrong_cohort)
	_expect(not bool(wrong.get("ok", true)), "demo observation cannot silently enter ordinary cohort")
	_expect(String(wrong.get("error", "")).contains("demo_identity_requires_demo_cohort"), "cohort mismatch is explicit")

func _test_geometry_schema_and_insufficient_production_state() -> void:
	var evaluator: Phase12GBronzeGeometryEvidenceEvaluator = GeometryEvaluatorScript.new()
	var empty := {
		"schema_version": GeometryEvaluatorScript.SCHEMA_VERSION,
		"corpus_metadata": {
			"corpus_id": "phase12g-certified-bronze-production",
			"solver_version": "UNASSIGNED",
			"content_version": "UNASSIGNED",
			"authoritative_corpus": false,
		},
		"solutions": [],
	}
	var validation: Dictionary = evaluator.validate_dataset(empty)
	_expect(bool(validation.get("ok", false)), "empty future Bronze geometry container is structurally valid")
	var report: Dictionary = evaluator.evaluate(empty)
	_expect_equal(report.get("overall_status"), "INSUFFICIENT_EVIDENCE", "no authoritative certified corpus cannot pass geometry gates")
	var malformed: Dictionary = empty.duplicate(true)
	malformed["solutions"] = [_geometry_solution("bad", "C09", 2, 9, "A", "INFERIOR", true, true, 1.2, 1)]
	_expect(not bool(evaluator.validate_dataset(malformed).get("ok", true)), "out-of-range isolation ratio fails closed")

func _test_geometry_gate_math_with_synthetic_authoritative_fixture() -> void:
	var evaluator: Phase12GBronzeGeometryEvidenceEvaluator = GeometryEvaluatorScript.new()
	var solutions: Array = []
	var order := 9
	for chapter: int in range(2, 7):
		for index: int in range(2):
			var contract_number := chapter * 8 - 7 + index
			order += 1
			solutions.append(_geometry_solution("iso-%d-%d" % [chapter, index], "C%02d" % contract_number, chapter, order, "Z%d-%d" % [chapter, index], "INFERIOR", true, false, 0.25 + 0.01 * index, 2))
	var patterns := ["A", "A", "A", "B", "B", "C", "C", "C", "D", "D", "E", "E"]
	for index: int in range(patterns.size()):
		order += 1
		var chapter := 3 + mini(3, index / 3)
		solutions.append(_geometry_solution("primary-%d" % index, "P%02d" % index, chapter, order, String(patterns[index]), "VIABLE", true, true, 0.4, 1))
	var dataset := {
		"schema_version": GeometryEvaluatorScript.SCHEMA_VERSION,
		"corpus_metadata": {"corpus_id": "synthetic-test-only", "solver_version": "test-solver", "content_version": "test-content", "authoritative_corpus": true},
		"solutions": solutions,
	}
	var report: Dictionary = evaluator.evaluate(dataset)
	_expect(bool(report.get("ok", false)), "synthetic geometry fixture evaluates")
	_expect_equal(report.get("overall_status"), "PASS", "synthetic authoritative fixture passes both frozen geometry gates")
	var gates: Dictionary = report.get("gates", {})
	_expect_equal((gates.get("chapter_isolation_counterexamples", {}) as Dictionary).get("status"), "PASS", "two isolation counterexamples per chapter 2-6 pass")
	_expect_equal((gates.get("role_to_zone_antistreak", {}) as Dictionary).get("status"), "PASS", "normalized role-to-zone streak stays within three")
	var duplicate_primary: Dictionary = dataset.duplicate(true)
	var duplicated: Array = duplicate_primary["solutions"]
	duplicated.append(_geometry_solution("duplicate-primary", "P00", 3, 99, "X", "VIABLE", true, true, 0.5, 0))
	duplicate_primary["solutions"] = duplicated
	_expect(not bool(evaluator.validate_dataset(duplicate_primary).get("ok", true)), "multiple primary Bronze families for one contract are rejected")

func _operator_dataset() -> Dictionary:
	return {
		"schema_version": "phase12g-evidence-v1",
		"dataset_id": "operator-test",
		"collection_metadata": {
			"metadata_version": ReportServiceScript.COLLECTION_METADATA_VERSION,
			"source_id": "study-a",
			"collection_owner": "operator-a",
			"cohort_policy_version": "phase12g-cohort-policy-v1",
		},
		"samples": [
			_sample("retry-good", "failed_review_retry", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, {"contract_id":"C09", "causal_explanation":"heat", "intended_revision":"move cargo", "blind_shuffle":false}),
			_sample("retry-tutorial", "failed_review_retry", ReportServiceScript.COHORT_TUTORIAL, {"contract_id":"C02", "causal_explanation":"tutorial", "intended_revision":"tutorial", "blind_shuffle":false}),
			_sample("plan-ordinary", "planning_duration", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, {"contract_id":"C10", "duration_seconds":420.0, "ordinary_non_mastery":true, "rule_familiarity":true}),
			_sample("plan-mastery", "planning_duration", ReportServiceScript.COHORT_POST_ONBOARDING_MASTERY, {"contract_id":"C48", "duration_seconds":1200.0, "ordinary_non_mastery":false, "rule_familiarity":true}),
			_sample("demo-a", "demo_identity", ReportServiceScript.COHORT_DEMO, {"response_text":"plan transit behavior", "classification":"TRANSIT_BEHAVIOR"}),
			_sample("review-a", "review_usability", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, {"contract_id":"C18", "actionable_first_cause":true, "raw_log_read":false, "time_to_first_cause_seconds":18.0, "interaction_count":3}),
		],
	}

func _sample(id: String, type: String, cohort: String, fields: Dictionary) -> Dictionary:
	var sample := {"sample_id":id, "sample_type":type, "tester_id":"tester-a", "captured_at_unix":1800000000, "cohort":cohort}
	sample.merge(fields, true)
	return sample

func _geometry_solution(id: String, contract_id: String, chapter: int, order: int, pattern: String, isolation_status: String, certified: bool, primary: bool, isolation_ratio: float, beneficial: int) -> Dictionary:
	return {"solution_id":id, "contract_id":contract_id, "chapter":chapter, "campaign_order":order, "normalized_role_to_zone":pattern, "high_isolation_status":isolation_status, "certified_bronze":certified, "primary_family":primary, "isolation_ratio":isolation_ratio, "beneficial_relation_count":beneficial}

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _expect_near(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.000001:
		failures += 1
		push_error("FAIL: %s expected=%f actual=%f" % [label, expected, actual])

func _finish() -> void:
	if failures == 0:
		print("phase12g_operator_report_geometry_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12g_operator_report_geometry_test_runner: %d failure(s)" % failures)
		quit(1)
