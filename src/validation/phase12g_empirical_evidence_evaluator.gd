class_name Phase12GEmpiricalEvidenceEvaluator
extends RefCounted

const SCHEMA_VERSION := "phase12g-evidence-v1"
const FAILED_REVIEW_RETRY := "failed_review_retry"
const MEMORABLE_OUTCOME := "memorable_outcome"
const PLANNING_DURATION := "planning_duration"
const SPECIES_DECISION := "species_decision"
const DEMO_IDENTITY := "demo_identity"
const REVIEW_USABILITY := "review_usability"

const SAMPLE_TYPES: Array[String] = [FAILED_REVIEW_RETRY, MEMORABLE_OUTCOME, PLANNING_DURATION, SPECIES_DECISION, DEMO_IDENTITY, REVIEW_USABILITY]
const SOOTHER_CLUSTER: Array[String] = ["O06", "O12", "O16"]
const PROTECTOR_CLUSTER: Array[String] = ["O05", "O19", "O20"]
const POST_LAUNCH_DEPENDENCIES: Array[String] = ["STATE", "FOOTPRINT", "CHANNEL", "SUPPORT_POWER", "NONE", "UNKNOWN"]
const DEMO_CLASSIFICATIONS: Array[String] = ["TRANSIT_BEHAVIOR", "STATIC_PACKING", "OTHER"]

const RETRY_TARGET := 0.70
const MEMORABLE_POST_LAUNCH_TARGET := 0.50
const PLANNING_MEDIAN_MAX_SECONDS := 480.0
const SPECIES_REDUNDANCY_RISK_THRESHOLD := 0.70

func validate_dataset(dataset: Dictionary) -> Dictionary:
	if String(dataset.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("unsupported_schema_version")
	var samples_value: Variant = dataset.get("samples", null)
	if not samples_value is Array:
		return _failure("samples_must_be_array")
	var samples: Array = samples_value
	var seen_ids: Dictionary = {}
	var counts: Dictionary = {}
	for sample_type: String in SAMPLE_TYPES:
		counts[sample_type] = 0
	for index: int in range(samples.size()):
		var sample_value: Variant = samples[index]
		if not sample_value is Dictionary:
			return _failure("sample_%d_not_dictionary" % index)
		var sample: Dictionary = sample_value
		var base_error: String = _validate_common_sample(sample, seen_ids)
		if not base_error.is_empty():
			return _failure("sample_%d:%s" % [index, base_error])
		var sample_type: String = String(sample["sample_type"])
		var type_error: String = _validate_sample_by_type(sample_type, sample)
		if not type_error.is_empty():
			return _failure("sample_%d:%s" % [index, type_error])
		counts[sample_type] = int(counts[sample_type]) + 1
	return {"ok": true, "error": "", "sample_count": samples.size(), "counts": counts}

func evaluate(dataset: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_dataset(dataset)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "error": String(validation.get("error", "invalid_dataset")), "schema_version": SCHEMA_VERSION, "overall_status": "INVALID", "gates": {}}
	var samples: Array = dataset["samples"]
	var gates: Dictionary = {
		"hypothesis_driven_retry": _evaluate_retry(samples),
		"transit_significance": _evaluate_memorable_outcomes(samples),
		"planning_duration": _evaluate_planning_duration(samples),
		"species_decision_distinctness": _evaluate_species_decisions(samples),
		"demo_identity": _evaluate_demo_identity(samples),
		"causal_review_usability": _evaluate_review_usability(samples),
	}
	var overall_status := "PASS"
	for gate_value: Variant in gates.values():
		if not gate_value is Dictionary:
			continue
		var status: String = String((gate_value as Dictionary).get("status", "INSUFFICIENT_EVIDENCE"))
		if status == "FAIL":
			overall_status = "FAIL"
			break
		if status in ["INSUFFICIENT_EVIDENCE", "MEASURE_ONLY"] and overall_status == "PASS":
			overall_status = "INCOMPLETE"
	return {"ok": true, "error": "", "schema_version": SCHEMA_VERSION, "sample_count": int(validation.get("sample_count", 0)), "overall_status": overall_status, "gates": gates}

func _validate_common_sample(sample: Dictionary, seen_ids: Dictionary) -> String:
	for key: String in ["sample_id", "sample_type", "tester_id", "captured_at_unix"]:
		if not sample.has(key):
			return "missing_%s" % key
	var sample_id: String = String(sample.get("sample_id", "")).strip_edges()
	if sample_id.is_empty():
		return "empty_sample_id"
	if seen_ids.has(sample_id):
		return "duplicate_sample_id:%s" % sample_id
	seen_ids[sample_id] = true
	var sample_type: String = String(sample.get("sample_type", ""))
	if sample_type not in SAMPLE_TYPES:
		return "unknown_sample_type:%s" % sample_type
	if String(sample.get("tester_id", "")).strip_edges().is_empty():
		return "empty_tester_id"
	if int(sample.get("captured_at_unix", 0)) <= 0:
		return "invalid_captured_at_unix"
	return ""

func _validate_sample_by_type(sample_type: String, sample: Dictionary) -> String:
	match sample_type:
		FAILED_REVIEW_RETRY:
			return _validate_failed_review_retry(sample)
		MEMORABLE_OUTCOME:
			return _validate_memorable_outcome(sample)
		PLANNING_DURATION:
			return _validate_planning_duration(sample)
		SPECIES_DECISION:
			return _validate_species_decision(sample)
		DEMO_IDENTITY:
			return _validate_demo_identity(sample)
		REVIEW_USABILITY:
			return _validate_review_usability(sample)
	return "unknown_sample_type"

func _validate_failed_review_retry(sample: Dictionary) -> String:
	if String(sample.get("contract_id", "")).strip_edges().is_empty():
		return "missing_contract_id"
	for key: String in ["causal_explanation", "intended_revision", "blind_shuffle"]:
		if not sample.has(key):
			return "missing_%s" % key
	if not (sample["blind_shuffle"] is bool):
		return "blind_shuffle_must_be_bool"
	return ""

func _validate_memorable_outcome(sample: Dictionary) -> String:
	if String(sample.get("outcome_description", "")).strip_edges().is_empty():
		return "missing_outcome_description"
	if String(sample.get("post_launch_dependency", "")) not in POST_LAUNCH_DEPENDENCIES:
		return "invalid_post_launch_dependency"
	return ""

func _validate_planning_duration(sample: Dictionary) -> String:
	for key: String in ["contract_id", "duration_seconds", "ordinary_non_mastery", "rule_familiarity"]:
		if not sample.has(key):
			return "missing_%s" % key
	if String(sample["contract_id"]).strip_edges().is_empty():
		return "empty_contract_id"
	if float(sample["duration_seconds"]) <= 0.0:
		return "invalid_duration_seconds"
	if not (sample["ordinary_non_mastery"] is bool) or not (sample["rule_familiarity"] is bool):
		return "planning_qualifiers_must_be_bool"
	return ""

func _validate_species_decision(sample: Dictionary) -> String:
	for key: String in ["contract_id", "cluster_id", "species_id", "placement_choice", "support_choice", "revision_choice"]:
		if String(sample.get(key, "")).strip_edges().is_empty():
			return "missing_%s" % key
	var cluster_id: String = String(sample["cluster_id"])
	var species_id: String = String(sample["species_id"])
	if cluster_id == "SOOTHER_HELPER":
		if species_id not in SOOTHER_CLUSTER:
			return "species_not_in_soother_cluster"
	elif cluster_id == "PROTECTOR_HELPER":
		if species_id not in PROTECTOR_CLUSTER:
			return "species_not_in_protector_cluster"
	else:
		return "unknown_cluster_id"
	return ""

func _validate_demo_identity(sample: Dictionary) -> String:
	if String(sample.get("response_text", "")).strip_edges().is_empty():
		return "missing_response_text"
	if String(sample.get("classification", "")) not in DEMO_CLASSIFICATIONS:
		return "invalid_demo_classification"
	return ""

func _validate_review_usability(sample: Dictionary) -> String:
	for key: String in ["contract_id", "actionable_first_cause", "raw_log_read"]:
		if not sample.has(key):
			return "missing_%s" % key
	if String(sample["contract_id"]).strip_edges().is_empty():
		return "empty_contract_id"
	if not (sample["actionable_first_cause"] is bool) or not (sample["raw_log_read"] is bool):
		return "review_flags_must_be_bool"
	if sample.has("time_to_first_cause_seconds") and float(sample["time_to_first_cause_seconds"]) < 0.0:
		return "invalid_time_to_first_cause_seconds"
	if sample.has("interaction_count") and int(sample["interaction_count"]) < 0:
		return "invalid_interaction_count"
	return ""

func _evaluate_retry(samples: Array) -> Dictionary:
	var eligible: Array = _samples_of_type(samples, FAILED_REVIEW_RETRY)
	if eligible.is_empty():
		return _insufficient(RETRY_TARGET, ">=")
	var successes := 0
	for raw: Variant in eligible:
		var sample: Dictionary = raw
		var has_cause := not String(sample.get("causal_explanation", "")).strip_edges().is_empty()
		var has_revision := not String(sample.get("intended_revision", "")).strip_edges().is_empty()
		if has_cause and has_revision and not bool(sample.get("blind_shuffle", true)):
			successes += 1
	var rate: float = float(successes) / float(eligible.size())
	return _threshold_result(rate, RETRY_TARGET, ">=", eligible.size(), {"successful_samples": successes})

func _evaluate_memorable_outcomes(samples: Array) -> Dictionary:
	var eligible: Array = _samples_of_type(samples, MEMORABLE_OUTCOME)
	if eligible.is_empty():
		return _insufficient(MEMORABLE_POST_LAUNCH_TARGET, ">=")
	var dependent := 0
	for raw: Variant in eligible:
		var dependency: String = String((raw as Dictionary).get("post_launch_dependency", "UNKNOWN"))
		if dependency in ["STATE", "FOOTPRINT", "CHANNEL", "SUPPORT_POWER"]:
			dependent += 1
	var rate: float = float(dependent) / float(eligible.size())
	return _threshold_result(rate, MEMORABLE_POST_LAUNCH_TARGET, ">=", eligible.size(), {"post_launch_dependent_samples": dependent})

func _evaluate_planning_duration(samples: Array) -> Dictionary:
	var durations: Array[float] = []
	for raw: Variant in _samples_of_type(samples, PLANNING_DURATION):
		var sample: Dictionary = raw
		if bool(sample.get("ordinary_non_mastery", false)) and bool(sample.get("rule_familiarity", false)):
			durations.append(float(sample.get("duration_seconds", 0.0)))
	if durations.is_empty():
		return _insufficient(PLANNING_MEDIAN_MAX_SECONDS, "<=")
	durations.sort()
	var median: float = _median(durations)
	return _threshold_result(median, PLANNING_MEDIAN_MAX_SECONDS, "<=", durations.size(), {"median_seconds": median})

func _evaluate_species_decisions(samples: Array) -> Dictionary:
	var decisions: Array = _samples_of_type(samples, SPECIES_DECISION)
	if decisions.is_empty():
		return {"status": "INSUFFICIENT_EVIDENCE", "sample_count": 0, "clusters": {}, "threshold": SPECIES_REDUNDANCY_RISK_THRESHOLD}
	var clusters: Dictionary = {}
	var any_risk := false
	var all_comparable := true
	for cluster_id: String in ["SOOTHER_HELPER", "PROTECTOR_HELPER"]:
		var species_ids: Array[String] = SOOTHER_CLUSTER if cluster_id == "SOOTHER_HELPER" else PROTECTOR_CLUSTER
		var pair_results: Array = []
		for left_index: int in range(species_ids.size()):
			for right_index: int in range(left_index + 1, species_ids.size()):
				var pair: Dictionary = _species_pair_similarity(decisions, cluster_id, species_ids[left_index], species_ids[right_index])
				pair_results.append(pair)
				if int(pair.get("comparable_contexts", 0)) == 0:
					all_comparable = false
				elif float(pair.get("exact_decision_similarity", 0.0)) >= SPECIES_REDUNDANCY_RISK_THRESHOLD:
					any_risk = true
		clusters[cluster_id] = {"pairs": pair_results}
	var status := "INSUFFICIENT_EVIDENCE" if not all_comparable else ("FAIL" if any_risk else "PASS")
	return {
		"status": status,
		"sample_count": decisions.size(),
		"threshold": SPECIES_REDUNDANCY_RISK_THRESHOLD,
		"operator": "<",
		"interpretation": "exact preferred placement+support+revision tuple similarity; >=70% flags representative redundancy risk",
		"clusters": clusters,
	}

func _species_pair_similarity(decisions: Array, cluster_id: String, left_id: String, right_id: String) -> Dictionary:
	var left_by_context: Dictionary = {}
	var right_by_context: Dictionary = {}
	for raw: Variant in decisions:
		var sample: Dictionary = raw
		if String(sample.get("cluster_id", "")) != cluster_id:
			continue
		var context_key := "%s|%s" % [String(sample.get("tester_id", "")), String(sample.get("contract_id", ""))]
		var species_id: String = String(sample.get("species_id", ""))
		if species_id == left_id:
			left_by_context[context_key] = sample
		elif species_id == right_id:
			right_by_context[context_key] = sample
	var comparable := 0
	var exact_matches := 0
	var placement_matches := 0
	var support_matches := 0
	var revision_matches := 0
	for context_key: Variant in left_by_context.keys():
		if not right_by_context.has(context_key):
			continue
		comparable += 1
		var left: Dictionary = left_by_context[context_key]
		var right: Dictionary = right_by_context[context_key]
		var placement_same := String(left["placement_choice"]) == String(right["placement_choice"])
		var support_same := String(left["support_choice"]) == String(right["support_choice"])
		var revision_same := String(left["revision_choice"]) == String(right["revision_choice"])
		placement_matches += 1 if placement_same else 0
		support_matches += 1 if support_same else 0
		revision_matches += 1 if revision_same else 0
		exact_matches += 1 if placement_same and support_same and revision_same else 0
	return {
		"left_species_id": left_id,
		"right_species_id": right_id,
		"comparable_contexts": comparable,
		"exact_decision_similarity": _safe_rate(exact_matches, comparable),
		"placement_similarity": _safe_rate(placement_matches, comparable),
		"support_similarity": _safe_rate(support_matches, comparable),
		"revision_similarity": _safe_rate(revision_matches, comparable),
	}

func _evaluate_demo_identity(samples: Array) -> Dictionary:
	var eligible: Array = _samples_of_type(samples, DEMO_IDENTITY)
	if eligible.is_empty():
		return {"status": "INSUFFICIENT_EVIDENCE", "sample_count": 0, "operator": ">", "threshold": 0.50}
	var transit := 0
	var static_packing := 0
	for raw: Variant in eligible:
		var classification: String = String((raw as Dictionary).get("classification", "OTHER"))
		transit += 1 if classification == "TRANSIT_BEHAVIOR" else 0
		static_packing += 1 if classification == "STATIC_PACKING" else 0
	var rate := float(transit) / float(eligible.size())
	return {"status": "PASS" if rate > 0.50 else "FAIL", "sample_count": eligible.size(), "value": rate, "operator": ">", "threshold": 0.50, "transit_behavior_count": transit, "static_packing_count": static_packing}

func _evaluate_review_usability(samples: Array) -> Dictionary:
	var eligible: Array = _samples_of_type(samples, REVIEW_USABILITY)
	if eligible.is_empty():
		return {"status": "INSUFFICIENT_EVIDENCE", "sample_count": 0, "measurement": "actionable first cause without raw-log reading"}
	var successes := 0
	var times: Array[float] = []
	var interactions: Array[float] = []
	for raw: Variant in eligible:
		var sample: Dictionary = raw
		if bool(sample.get("actionable_first_cause", false)) and not bool(sample.get("raw_log_read", true)):
			successes += 1
		if sample.has("time_to_first_cause_seconds"):
			times.append(float(sample["time_to_first_cause_seconds"]))
		if sample.has("interaction_count"):
			interactions.append(float(sample["interaction_count"]))
	times.sort()
	interactions.sort()
	return {
		"status": "MEASURE_ONLY",
		"sample_count": eligible.size(),
		"actionable_without_raw_log_rate": float(successes) / float(eligible.size()),
		"median_time_to_first_cause_seconds": null if times.is_empty() else _median(times),
		"median_interaction_count": null if interactions.is_empty() else _median(interactions),
		"note": "Phase-11 freezes no numeric speed/interaction threshold; report these usability measurements without inventing one.",
	}

func _samples_of_type(samples: Array, sample_type: String) -> Array:
	var result: Array = []
	for raw: Variant in samples:
		if raw is Dictionary and String((raw as Dictionary).get("sample_type", "")) == sample_type:
			result.append(raw)
	return result

func _median(values: Array[float]) -> float:
	var count := values.size()
	if count == 0:
		return 0.0
	var middle: int = floori(float(count) / 2.0)
	if count % 2 == 1:
		return values[middle]
	return (values[middle - 1] + values[middle]) / 2.0

func _threshold_result(value: float, threshold: float, operator: String, sample_count: int, extra: Dictionary = {}) -> Dictionary:
	var passed := value >= threshold if operator == ">=" else value <= threshold
	var result := {"status": "PASS" if passed else "FAIL", "sample_count": sample_count, "value": value, "operator": operator, "threshold": threshold}
	result.merge(extra, true)
	return result

func _insufficient(threshold: float, operator: String) -> Dictionary:
	return {"status": "INSUFFICIENT_EVIDENCE", "sample_count": 0, "value": null, "operator": operator, "threshold": threshold}

func _safe_rate(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
