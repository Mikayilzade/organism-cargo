extends SceneTree

const EvaluatorScript := preload("res://src/validation/phase12g_empirical_evidence_evaluator.gd")

var failures: int = 0

func _init() -> void:
	_test_empty_production_shape_is_valid_but_incomplete()
	_test_threshold_aggregation_and_species_comparison()
	_test_fail_closed_malformed_samples()
	_finish()

func _test_empty_production_shape_is_valid_but_incomplete() -> void:
	var evaluator: Phase12GEmpiricalEvidenceEvaluator = EvaluatorScript.new()
	var dataset := {"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": []}
	var validation: Dictionary = evaluator.validate_dataset(dataset)
	_expect(bool(validation.get("ok", false)), "empty production evidence container is structurally valid")
	var report: Dictionary = evaluator.evaluate(dataset)
	_expect_equal(report.get("overall_status"), "INCOMPLETE", "zero human observations cannot fabricate a passing empirical result")
	var gates: Dictionary = report.get("gates", {})
	_expect_equal((gates["hypothesis_driven_retry"] as Dictionary).get("status"), "INSUFFICIENT_EVIDENCE", "retry gate stays insufficient without observations")
	_expect_equal((gates["causal_review_usability"] as Dictionary).get("status"), "INSUFFICIENT_EVIDENCE", "review gate stays insufficient without observations")

func _test_threshold_aggregation_and_species_comparison() -> void:
	var evaluator: Phase12GEmpiricalEvidenceEvaluator = EvaluatorScript.new()
	var samples: Array = []
	var sequence := 0

	for index: int in range(10):
		sequence += 1
		var success := index < 7
		samples.append(_sample(sequence, "failed_review_retry", "retry-%d" % index, {
			"contract_id": "C09",
			"causal_explanation": "heat source reached specimen" if success else "",
			"intended_revision": "move specimen behind buffer" if success else "",
			"blind_shuffle": not success,
		}))

	sequence += 1
	samples.append(_sample(sequence, "memorable_outcome", "memorable-1", {"outcome_description": "panic after heat pulse", "post_launch_dependency": "STATE"}))
	sequence += 1
	samples.append(_sample(sequence, "memorable_outcome", "memorable-2", {"outcome_description": "tight initial fit", "post_launch_dependency": "NONE"}))

	for duration: float in [420.0, 480.0]:
		sequence += 1
		samples.append(_sample(sequence, "planning_duration", "planning-%d" % sequence, {"contract_id": "C10", "duration_seconds": duration, "ordinary_non_mastery": true, "rule_familiarity": true}))
	sequence += 1
	samples.append(_sample(sequence, "planning_duration", "planning-excluded", {"contract_id": "C48", "duration_seconds": 1200.0, "ordinary_non_mastery": false, "rule_familiarity": true}))

	sequence = _append_distinct_species_cluster(samples, sequence, "SOOTHER_HELPER", ["O06", "O12", "O16"], "C20")
	sequence = _append_distinct_species_cluster(samples, sequence, "PROTECTOR_HELPER", ["O05", "O19", "O20"], "C24")

	for classification: String in ["TRANSIT_BEHAVIOR", "TRANSIT_BEHAVIOR", "STATIC_PACKING"]:
		sequence += 1
		samples.append(_sample(sequence, "demo_identity", "demo-%d" % sequence, {"response_text": "tester response %d" % sequence, "classification": classification}))

	sequence += 1
	samples.append(_sample(sequence, "review_usability", "review-1", {"contract_id": "C18", "actionable_first_cause": true, "raw_log_read": false, "time_to_first_cause_seconds": 18.0, "interaction_count": 3}))
	sequence += 1
	samples.append(_sample(sequence, "review_usability", "review-2", {"contract_id": "C19", "actionable_first_cause": false, "raw_log_read": true, "time_to_first_cause_seconds": 42.0, "interaction_count": 7}))

	var report: Dictionary = evaluator.evaluate({"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": samples})
	_expect(bool(report.get("ok", false)), "synthetic aggregation fixture evaluates")
	var gates: Dictionary = report.get("gates", {})
	var retry: Dictionary = gates["hypothesis_driven_retry"]
	_expect_equal(retry.get("status"), "PASS", "7 of 10 retry observations meet frozen >=70 percent threshold")
	_expect_near(float(retry.get("value", 0.0)), 0.70, "retry rate is deterministic")
	var transit: Dictionary = gates["transit_significance"]
	_expect_equal(transit.get("status"), "PASS", "1 of 2 memorable outcomes meets frozen >=50 percent post-launch threshold")
	var planning: Dictionary = gates["planning_duration"]
	_expect_equal(planning.get("status"), "PASS", "ordinary familiar planning median stays within 8 minutes")
	_expect_near(float(planning.get("median_seconds", 0.0)), 450.0, "planning median excludes mastery fixture")
	var species: Dictionary = gates["species_decision_distinctness"]
	_expect_equal(species.get("status"), "PASS", "distinct synthetic choices stay below representative redundancy-risk threshold")
	var demo: Dictionary = gates["demo_identity"]
	_expect_equal(demo.get("status"), "PASS", "majority transit-behavior demo identity passes")
	var review: Dictionary = gates["causal_review_usability"]
	_expect_equal(review.get("status"), "MEASURE_ONLY", "review speed remains measurement-only because canon gives no numeric speed cutoff")
	_expect_near(float(review.get("actionable_without_raw_log_rate", 0.0)), 0.50, "review actionable rate is reported without inventing a threshold")

	var redundant: Array = samples.duplicate(true)
	var redundant_species: Array = []
	for raw: Variant in redundant:
		if raw is Dictionary and String((raw as Dictionary).get("sample_type", "")) == "species_decision" and String((raw as Dictionary).get("cluster_id", "")) == "SOOTHER_HELPER":
			var changed: Dictionary = (raw as Dictionary).duplicate(true)
			changed["placement_choice"] = "same-placement"
			changed["support_choice"] = "same-support"
			changed["revision_choice"] = "same-revision"
			redundant_species.append(changed)
		else:
			redundant_species.append(raw)
	var redundant_report: Dictionary = evaluator.evaluate({"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": redundant_species})
	_expect_equal(((redundant_report["gates"] as Dictionary)["species_decision_distinctness"] as Dictionary).get("status"), "FAIL", "interchangeable helper decision tuples fail closed at >=70 percent similarity")

func _test_fail_closed_malformed_samples() -> void:
	var evaluator: Phase12GEmpiricalEvidenceEvaluator = EvaluatorScript.new()
	var bad_schema: Dictionary = evaluator.validate_dataset({"schema_version": "old", "samples": []})
	_expect(not bool(bad_schema.get("ok", true)), "unknown evidence schema is rejected")

	var incomplete := {"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": [_sample(1, "failed_review_retry", "bad-retry", {"contract_id": "C09", "causal_explanation": "cause", "blind_shuffle": false})]}
	var incomplete_result: Dictionary = evaluator.validate_dataset(incomplete)
	_expect(not bool(incomplete_result.get("ok", true)), "missing intended revision is rejected")
	_expect(String(incomplete_result.get("error", "")).contains("missing_intended_revision"), "missing retry field has explicit error")

	var invalid_dependency := {"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": [_sample(2, "memorable_outcome", "bad-dependency", {"outcome_description": "x", "post_launch_dependency": "MAGIC"})]}
	_expect(not bool(evaluator.validate_dataset(invalid_dependency).get("ok", true)), "invented post-launch dependency category is rejected")

	var wrong_species := {"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": [_sample(3, "species_decision", "bad-species", {"contract_id": "C20", "cluster_id": "SOOTHER_HELPER", "species_id": "O05", "placement_choice": "a", "support_choice": "b", "revision_choice": "c"})]}
	_expect(not bool(evaluator.validate_dataset(wrong_species).get("ok", true)), "species cannot be silently moved between frozen redundancy clusters")

	var duplicate: Dictionary = _sample(4, "demo_identity", "duplicate", {"response_text": "x", "classification": "OTHER"})
	var duplicates := {"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": [duplicate, duplicate.duplicate(true)]}
	_expect(not bool(evaluator.validate_dataset(duplicates).get("ok", true)), "duplicate observation IDs are rejected")

func _append_distinct_species_cluster(samples: Array, sequence: int, cluster_id: String, species_ids: Array[String], contract_id: String) -> int:
	var next_sequence := sequence
	for index: int in range(species_ids.size()):
		next_sequence += 1
		samples.append(_sample(next_sequence, "species_decision", "%s-%s" % [cluster_id, species_ids[index]], {
			"contract_id": contract_id,
			"cluster_id": cluster_id,
			"species_id": species_ids[index],
			"placement_choice": "placement-%d" % index,
			"support_choice": "support-%d" % index,
			"revision_choice": "revision-%d" % index,
		}))
	return next_sequence

func _sample(sequence: int, sample_type: String, sample_id: String, fields: Dictionary) -> Dictionary:
	var sample := {
		"sample_id": sample_id,
		"sample_type": sample_type,
		"tester_id": "tester-a",
		"captured_at_unix": 1800000000 + sequence,
	}
	sample.merge(fields, true)
	return sample

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
		print("phase12g_empirical_evidence_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12g_empirical_evidence_test_runner: %d failure(s)" % failures)
		quit(1)
