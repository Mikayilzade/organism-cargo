class_name Phase12GEvidenceReportService
extends RefCounted

const EvaluatorScript := preload("res://src/validation/phase12g_empirical_evidence_evaluator.gd")

const COLLECTION_METADATA_VERSION := "phase12g-collection-v1"
const COHORT_POST_ONBOARDING_ORDINARY := "POST_ONBOARDING_FAMILIAR_ORDINARY"
const COHORT_POST_ONBOARDING_MASTERY := "POST_ONBOARDING_MASTERY"
const COHORT_TUTORIAL := "TUTORIAL_ONBOARDING"
const COHORT_DEMO := "DEMO_TEST"
const COHORT_REDUNDANCY := "REDUNDANCY_CLUSTER"
const ALLOWED_COHORTS: Array[String] = [
	COHORT_POST_ONBOARDING_ORDINARY,
	COHORT_POST_ONBOARDING_MASTERY,
	COHORT_TUTORIAL,
	COHORT_DEMO,
	COHORT_REDUNDANCY,
]

const GATE_ORDER: Array[String] = [
	"hypothesis_driven_retry",
	"transit_significance",
	"planning_duration",
	"species_decision_distinctness",
	"demo_identity",
	"causal_review_usability",
]

var _evaluator: Phase12GEmpiricalEvidenceEvaluator = EvaluatorScript.new()

func load_external_json(path: String) -> Dictionary:
	if path.strip_edges().is_empty():
		return _failure("missing_input_path")
	if not FileAccess.file_exists(path):
		return _failure("input_not_found")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("input_open_failed")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _failure("input_json_not_dictionary")
	return {"ok": true, "error": "", "dataset": (parsed as Dictionary).duplicate(true)}

func validate_operator_dataset(dataset: Dictionary) -> Dictionary:
	var base: Dictionary = _evaluator.validate_dataset(dataset)
	if not bool(base.get("ok", false)):
		return _failure("evidence:%s" % String(base.get("error", "invalid_dataset")))
	if String(dataset.get("dataset_id", "")).strip_edges().is_empty():
		return _failure("missing_dataset_id")
	var metadata_value: Variant = dataset.get("collection_metadata", null)
	if not metadata_value is Dictionary:
		return _failure("missing_collection_metadata")
	var metadata: Dictionary = metadata_value
	if String(metadata.get("metadata_version", "")) != COLLECTION_METADATA_VERSION:
		return _failure("unsupported_collection_metadata_version")
	for key: String in ["source_id", "collection_owner", "cohort_policy_version"]:
		if String(metadata.get(key, "")).strip_edges().is_empty():
			return _failure("missing_collection_metadata_%s" % key)
	var samples: Array = dataset.get("samples", [])
	var cohort_counts: Dictionary = {}
	for cohort: String in ALLOWED_COHORTS:
		cohort_counts[cohort] = 0
	for index: int in range(samples.size()):
		var sample: Dictionary = samples[index]
		var cohort: String = String(sample.get("cohort", ""))
		if cohort not in ALLOWED_COHORTS:
			return _failure("sample_%d:invalid_or_missing_cohort" % index)
		var compatibility_error: String = _validate_cohort_compatibility(sample, cohort)
		if not compatibility_error.is_empty():
			return _failure("sample_%d:%s" % [index, compatibility_error])
		cohort_counts[cohort] = int(cohort_counts[cohort]) + 1
	return {"ok": true, "error": "", "sample_count": samples.size(), "cohort_counts": cohort_counts}

func evaluate_operator_dataset(dataset: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_operator_dataset(dataset)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "error": String(validation.get("error", "invalid_operator_dataset")), "overall_status": "INVALID", "gates": {}}
	var filtered_samples: Array = []
	var excluded_counts: Dictionary = {"tutorial_or_wrong_cohort": 0, "mastery_from_planning_median": 0}
	for raw: Variant in dataset.get("samples", []):
		var sample: Dictionary = raw
		var sample_type: String = String(sample.get("sample_type", ""))
		var cohort: String = String(sample.get("cohort", ""))
		var include := false
		match sample_type:
			EvaluatorScript.FAILED_REVIEW_RETRY, EvaluatorScript.MEMORABLE_OUTCOME, EvaluatorScript.REVIEW_USABILITY:
				include = cohort in [COHORT_POST_ONBOARDING_ORDINARY, COHORT_POST_ONBOARDING_MASTERY]
			EvaluatorScript.PLANNING_DURATION:
				include = cohort == COHORT_POST_ONBOARDING_ORDINARY
				if cohort == COHORT_POST_ONBOARDING_MASTERY:
					excluded_counts["mastery_from_planning_median"] = int(excluded_counts["mastery_from_planning_median"]) + 1
			EvaluatorScript.SPECIES_DECISION:
				include = cohort == COHORT_REDUNDANCY
			EvaluatorScript.DEMO_IDENTITY:
				include = cohort == COHORT_DEMO
		if include:
			filtered_samples.append(sample.duplicate(true))
		else:
			excluded_counts["tutorial_or_wrong_cohort"] = int(excluded_counts["tutorial_or_wrong_cohort"]) + 1
	var filtered_dataset := {"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": filtered_samples}
	var report: Dictionary = _evaluator.evaluate(filtered_dataset)
	report["dataset_id"] = String(dataset.get("dataset_id", ""))
	report["collection_metadata"] = (dataset.get("collection_metadata", {}) as Dictionary).duplicate(true)
	report["source_sample_count"] = int(validation.get("sample_count", 0))
	report["eligible_sample_count"] = filtered_samples.size()
	report["cohort_counts"] = (validation.get("cohort_counts", {}) as Dictionary).duplicate(true)
	report["excluded_counts"] = excluded_counts
	return report

func human_readable_report(report: Dictionary) -> String:
	if not bool(report.get("ok", false)):
		return "PHASE 12G EMPIRICAL GATE REPORT\nSTATUS: INVALID\nERROR: %s" % String(report.get("error", "unknown"))
	var lines := PackedStringArray()
	lines.append("PHASE 12G EMPIRICAL GATE REPORT")
	lines.append("Dataset: %s" % String(report.get("dataset_id", "unknown")))
	lines.append("Overall: %s" % String(report.get("overall_status", "INCOMPLETE")))
	lines.append("Samples: source=%d eligible=%d" % [int(report.get("source_sample_count", 0)), int(report.get("eligible_sample_count", 0))])
	var gates_value: Variant = report.get("gates", {})
	var gates: Dictionary = gates_value if gates_value is Dictionary else {}
	for gate_name: String in GATE_ORDER:
		var gate_value: Variant = gates.get(gate_name, {})
		var gate: Dictionary = gate_value if gate_value is Dictionary else {}
		lines.append("- %s: %s (n=%d)" % [gate_name, String(gate.get("status", "INSUFFICIENT_EVIDENCE")), int(gate.get("sample_count", 0))])
	return "\n".join(lines)

func write_report_files(report: Dictionary, json_path: String, text_path: String) -> Dictionary:
	if json_path.strip_edges().is_empty() or text_path.strip_edges().is_empty():
		return _failure("missing_report_output_path")
	var json_write: Dictionary = _write_text(json_path, JSON.stringify(report, "  ", true, true))
	if not bool(json_write.get("ok", false)):
		return json_write
	var text_write: Dictionary = _write_text(text_path, human_readable_report(report))
	if not bool(text_write.get("ok", false)):
		return text_write
	return {"ok": true, "error": "", "json_path": json_path, "text_path": text_path}

func _validate_cohort_compatibility(sample: Dictionary, cohort: String) -> String:
	var sample_type: String = String(sample.get("sample_type", ""))
	if sample_type == EvaluatorScript.PLANNING_DURATION and cohort == COHORT_POST_ONBOARDING_ORDINARY:
		if not bool(sample.get("ordinary_non_mastery", false)) or not bool(sample.get("rule_familiarity", false)):
			return "ordinary_familiar_cohort_requires_matching_planning_qualifiers"
	if sample_type == EvaluatorScript.DEMO_IDENTITY and cohort != COHORT_DEMO:
		return "demo_identity_requires_demo_cohort"
	if sample_type == EvaluatorScript.SPECIES_DECISION and cohort != COHORT_REDUNDANCY:
		return "species_decision_requires_redundancy_cohort"
	return ""

func _write_text(path: String, text: String) -> Dictionary:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var directory := absolute_path.get_base_dir()
	if not directory.is_empty():
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			return _failure("report_mkdir_failed:%d" % mkdir_error)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return _failure("report_open_failed")
	file.store_string(text)
	file.flush()
	file.close()
	return {"ok": true, "error": ""}

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
