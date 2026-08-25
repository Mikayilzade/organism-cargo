class_name Phase12GBronzeGeometryEvidenceEvaluator
extends RefCounted

const SCHEMA_VERSION := "phase12g-bronze-geometry-v1"
const HIGH_ISOLATION_STATUSES: Array[String] = ["INFERIOR", "IMPOSSIBLE", "VIABLE", "UNKNOWN"]

func validate_dataset(dataset: Dictionary) -> Dictionary:
	if String(dataset.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("unsupported_schema_version")
	var metadata_value: Variant = dataset.get("corpus_metadata", null)
	if not metadata_value is Dictionary:
		return _failure("missing_corpus_metadata")
	var metadata: Dictionary = metadata_value
	for key: String in ["corpus_id", "solver_version", "content_version"]:
		if String(metadata.get(key, "")).strip_edges().is_empty():
			return _failure("missing_corpus_metadata_%s" % key)
	if not (metadata.get("authoritative_corpus", null) is bool):
		return _failure("authoritative_corpus_must_be_bool")
	var solutions_value: Variant = dataset.get("solutions", null)
	if not solutions_value is Array:
		return _failure("solutions_must_be_array")
	var seen_ids: Dictionary = {}
	var primary_by_contract: Dictionary = {}
	var solutions: Array = solutions_value
	for index: int in range(solutions.size()):
		var raw: Variant = solutions[index]
		if not raw is Dictionary:
			return _failure("solution_%d_not_dictionary" % index)
		var solution: Dictionary = raw
		for key: String in ["solution_id", "contract_id", "normalized_role_to_zone", "high_isolation_status"]:
			if String(solution.get(key, "")).strip_edges().is_empty():
				return _failure("solution_%d:missing_%s" % [index, key])
		var solution_id: String = String(solution["solution_id"])
		if seen_ids.has(solution_id):
			return _failure("duplicate_solution_id:%s" % solution_id)
		seen_ids[solution_id] = true
		var chapter: int = int(solution.get("chapter", 0))
		var order: int = int(solution.get("campaign_order", 0))
		if chapter < 1 or chapter > 6 or order <= 0:
			return _failure("solution_%d:invalid_campaign_position" % index)
		var isolation_ratio: float = float(solution.get("isolation_ratio", -1.0))
		if isolation_ratio < 0.0 or isolation_ratio > 1.0:
			return _failure("solution_%d:invalid_isolation_ratio" % index)
		if int(solution.get("beneficial_relation_count", -1)) < 0:
			return _failure("solution_%d:invalid_beneficial_relation_count" % index)
		if String(solution["high_isolation_status"]) not in HIGH_ISOLATION_STATUSES:
			return _failure("solution_%d:invalid_high_isolation_status" % index)
		if not (solution.get("certified_bronze", null) is bool) or not (solution.get("primary_family", null) is bool):
			return _failure("solution_%d:certification_flags_must_be_bool" % index)
		if bool(solution["primary_family"]):
			var contract_id: String = String(solution["contract_id"])
			if primary_by_contract.has(contract_id):
				return _failure("multiple_primary_families:%s" % contract_id)
			primary_by_contract[contract_id] = true
	return {"ok": true, "error": "", "solution_count": solutions.size(), "primary_contract_count": primary_by_contract.size()}

func evaluate(dataset: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_dataset(dataset)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "error": String(validation.get("error", "invalid_dataset")), "overall_status": "INVALID", "gates": {}}
	var metadata: Dictionary = dataset["corpus_metadata"]
	var solutions: Array = dataset["solutions"]
	var gates: Dictionary = {
		"chapter_isolation_counterexamples": _evaluate_isolation_counterexamples(solutions),
		"role_to_zone_antistreak": _evaluate_role_to_zone_antistreak(solutions),
		"geometry_measurements": _measurement_summary(solutions),
	}
	if not bool(metadata.get("authoritative_corpus", false)) or solutions.is_empty():
		return {
			"ok": true,
			"error": "",
			"schema_version": SCHEMA_VERSION,
			"overall_status": "INSUFFICIENT_EVIDENCE",
			"authoritative_corpus": bool(metadata.get("authoritative_corpus", false)),
			"solution_count": solutions.size(),
			"gates": gates,
		}
	var overall := "PASS"
	for gate_name: String in ["chapter_isolation_counterexamples", "role_to_zone_antistreak"]:
		var status: String = String((gates[gate_name] as Dictionary).get("status", "INSUFFICIENT_EVIDENCE"))
		if status == "FAIL":
			overall = "FAIL"
			break
		if status == "INSUFFICIENT_EVIDENCE":
			overall = "INSUFFICIENT_EVIDENCE"
	return {"ok": true, "error": "", "schema_version": SCHEMA_VERSION, "overall_status": overall, "authoritative_corpus": true, "solution_count": solutions.size(), "gates": gates}

func _evaluate_isolation_counterexamples(solutions: Array) -> Dictionary:
	var qualifying_by_chapter: Dictionary = {}
	for chapter: int in range(2, 7):
		qualifying_by_chapter[chapter] = {}
	for raw: Variant in solutions:
		var solution: Dictionary = raw
		if not bool(solution.get("certified_bronze", false)):
			continue
		var chapter: int = int(solution.get("chapter", 0))
		if chapter < 2 or chapter > 6:
			continue
		if String(solution.get("high_isolation_status", "UNKNOWN")) in ["INFERIOR", "IMPOSSIBLE"]:
			(qualifying_by_chapter[chapter] as Dictionary)[String(solution.get("contract_id", ""))] = true
	var counts: Dictionary = {}
	var complete := true
	for chapter: int in range(2, 7):
		var count: int = (qualifying_by_chapter[chapter] as Dictionary).size()
		counts[chapter] = count
		if count < 2:
			complete = false
	return {"status": "PASS" if complete else "FAIL", "required_contracts_per_chapter": 2, "qualifying_contract_counts": counts}

func _evaluate_role_to_zone_antistreak(solutions: Array) -> Dictionary:
	var primary: Array = []
	for raw: Variant in solutions:
		var solution: Dictionary = raw
		if bool(solution.get("certified_bronze", false)) and bool(solution.get("primary_family", false)) and int(solution.get("chapter", 0)) > 2:
			primary.append(solution)
	primary.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("campaign_order", 0)) < int(right.get("campaign_order", 0)))
	if primary.is_empty():
		return {"status": "INSUFFICIENT_EVIDENCE", "maximum_consecutive_same_pattern": 0, "limit": 3}
	var maximum := 1
	var current := 1
	for index: int in range(1, primary.size()):
		if String((primary[index] as Dictionary).get("normalized_role_to_zone", "")) == String((primary[index - 1] as Dictionary).get("normalized_role_to_zone", "")):
			current += 1
			maximum = maxi(maximum, current)
		else:
			current = 1
	return {"status": "PASS" if maximum <= 3 else "FAIL", "maximum_consecutive_same_pattern": maximum, "limit": 3, "primary_contract_count": primary.size()}

func _measurement_summary(solutions: Array) -> Dictionary:
	if solutions.is_empty():
		return {"status": "INSUFFICIENT_EVIDENCE", "sample_count": 0}
	var isolation_sum := 0.0
	var beneficial_sum := 0
	for raw: Variant in solutions:
		var solution: Dictionary = raw
		isolation_sum += float(solution.get("isolation_ratio", 0.0))
		beneficial_sum += int(solution.get("beneficial_relation_count", 0))
	return {
		"status": "MEASURE_ONLY",
		"sample_count": solutions.size(),
		"mean_isolation_ratio": isolation_sum / float(solutions.size()),
		"mean_beneficial_relation_count": float(beneficial_sum) / float(solutions.size()),
	}

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
