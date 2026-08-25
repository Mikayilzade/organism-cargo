class_name Phase12GStudyPackageService
extends RefCounted

const StudyInfrastructureScript := preload("res://src/validation/phase12g_study_infrastructure.gd")
const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")
const GeometryEvaluatorScript := preload("res://src/validation/phase12g_bronze_geometry_evidence_evaluator.gd")

const BINDING_VERSION := "phase12g-session-binding-v1"
const AUDIT_VERSION := "phase12g-study-package-audit-v1"

var _infrastructure: Phase12GStudyInfrastructure = StudyInfrastructureScript.new()
var _report_service: Phase12GEvidenceReportService = ReportServiceScript.new()
var _geometry_evaluator: Phase12GBronzeGeometryEvidenceEvaluator = GeometryEvaluatorScript.new()

func bind_dataset_to_session(dataset: Dictionary, manifest: Dictionary) -> Dictionary:
	var manifest_validation: Dictionary = _infrastructure.validate_session_manifest(manifest)
	if not bool(manifest_validation.get("ok", false)):
		return _failure("manifest:%s" % String(manifest_validation.get("error", "invalid")))
	var dataset_validation: Dictionary = _report_service.validate_operator_dataset(dataset)
	if not bool(dataset_validation.get("ok", false)):
		return _failure("dataset:%s" % String(dataset_validation.get("error", "invalid")))
	var declaration_error: String = _sample_declaration_error(dataset, manifest)
	if not declaration_error.is_empty():
		return _failure(declaration_error)
	var metadata_value: Variant = dataset.get("collection_metadata", null)
	if not metadata_value is Dictionary:
		return _failure("dataset:missing_collection_metadata")
	var metadata: Dictionary = (metadata_value as Dictionary).duplicate(true)
	var declared_cohort: String = String(manifest.get("declared_cohort", ""))
	for raw_sample: Variant in dataset.get("samples", []):
		if raw_sample is Dictionary and String((raw_sample as Dictionary).get("cohort", "")) != declared_cohort:
			return _failure("sample_cohort_outside_declared_session")
	metadata["session_binding"] = {
		"binding_version": BINDING_VERSION,
		"session_id": String(manifest.get("session_id", "")),
		"manifest_checksum": String(manifest.get("manifest_checksum", "")),
		"prototype_build_id": String(manifest.get("prototype_build_id", "")),
		"rules_version": String(manifest.get("rules_version", "")),
		"content_version": String(manifest.get("content_version", "")),
		"declared_cohort": declared_cohort,
	}
	var bound: Dictionary = dataset.duplicate(true)
	bound["collection_metadata"] = metadata
	return {"ok": true, "error": "", "dataset": bound, "session_binding": metadata["session_binding"]}

func validate_bound_dataset(dataset: Dictionary, manifests_by_checksum: Dictionary) -> Dictionary:
	var dataset_validation: Dictionary = _report_service.validate_operator_dataset(dataset)
	if not bool(dataset_validation.get("ok", false)):
		return _failure("dataset:%s" % String(dataset_validation.get("error", "invalid")))
	var metadata: Dictionary = dataset.get("collection_metadata", {})
	var binding_value: Variant = metadata.get("session_binding", null)
	if not binding_value is Dictionary:
		return _failure("missing_session_binding")
	var binding: Dictionary = binding_value
	if String(binding.get("binding_version", "")) != BINDING_VERSION:
		return _failure("unsupported_session_binding_version")
	for key: String in ["session_id", "manifest_checksum", "prototype_build_id", "rules_version", "content_version", "declared_cohort"]:
		if String(binding.get(key, "")).strip_edges().is_empty():
			return _failure("missing_session_binding_%s" % key)
	var checksum: String = String(binding.get("manifest_checksum", ""))
	if not manifests_by_checksum.has(checksum):
		return _failure("unknown_session_manifest:%s" % checksum)
	var manifest_value: Variant = manifests_by_checksum[checksum]
	if not manifest_value is Dictionary:
		return _failure("invalid_manifest_registry_entry")
	var manifest: Dictionary = manifest_value
	var manifest_validation: Dictionary = _infrastructure.validate_session_manifest(manifest)
	if not bool(manifest_validation.get("ok", false)):
		return _failure("manifest:%s" % String(manifest_validation.get("error", "invalid")))
	var expected: Dictionary = {
		"session_id": String(manifest.get("session_id", "")),
		"prototype_build_id": String(manifest.get("prototype_build_id", "")),
		"rules_version": String(manifest.get("rules_version", "")),
		"content_version": String(manifest.get("content_version", "")),
		"declared_cohort": String(manifest.get("declared_cohort", "")),
	}
	for key: String in expected.keys():
		if String(binding.get(key, "")) != String(expected[key]):
			return _failure("session_binding_%s_mismatch" % key)
	for raw_sample: Variant in dataset.get("samples", []):
		if raw_sample is Dictionary and String((raw_sample as Dictionary).get("cohort", "")) != String(expected["declared_cohort"]):
			return _failure("sample_cohort_outside_declared_session")
	var declaration_error: String = _sample_declaration_error(dataset, manifest)
	if not declaration_error.is_empty():
		return _failure(declaration_error)
	return {"ok": true, "error": "", "session_binding": binding.duplicate(true), "sample_count": int(dataset_validation.get("sample_count", 0))}

func merge_bound_datasets(datasets: Array, manifests_by_checksum: Dictionary) -> Dictionary:
	if datasets.is_empty():
		return _failure("no_bound_datasets")
	var build_identity: Dictionary = {}
	var source_keys: Array = []
	for index: int in range(datasets.size()):
		var raw_dataset: Variant = datasets[index]
		if not raw_dataset is Dictionary:
			return _failure("source_%d:not_dictionary" % index)
		var dataset: Dictionary = raw_dataset
		var validation: Dictionary = validate_bound_dataset(dataset, manifests_by_checksum)
		if not bool(validation.get("ok", false)):
			return _failure("source_%d:%s" % [index, String(validation.get("error", "invalid"))])
		var binding: Dictionary = validation.get("session_binding", {})
		var current_identity: Dictionary = {
			"prototype_build_id": String(binding.get("prototype_build_id", "")),
			"rules_version": String(binding.get("rules_version", "")),
			"content_version": String(binding.get("content_version", "")),
		}
		if build_identity.is_empty():
			build_identity = current_identity
		elif current_identity != build_identity:
			return _failure("incompatible_build_identity")
		source_keys.append(String(binding.get("manifest_checksum", "")))
	var merged: Dictionary = _infrastructure.merge_operator_datasets(datasets, source_keys)
	if not bool(merged.get("ok", false)):
		return merged
	var aggregate: Dictionary = (merged.get("dataset", {}) as Dictionary).duplicate(true)
	var aggregate_metadata: Dictionary = aggregate.get("collection_metadata", {})
	aggregate_metadata["build_identity"] = build_identity.duplicate(true)
	aggregate_metadata["session_manifest_checksums"] = _sorted_unique(source_keys)
	aggregate["collection_metadata"] = aggregate_metadata
	var report: Dictionary = _report_service.evaluate_operator_dataset(aggregate)
	if not bool(report.get("ok", false)):
		return _failure("aggregate_report_invalid:%s" % String(report.get("error", "unknown")))
	return {
		"ok": true,
		"error": "",
		"dataset": aggregate,
		"report": report,
		"source_manifest": (merged.get("source_manifest", []) as Array).duplicate(true),
		"build_identity": build_identity.duplicate(true),
		"aggregate_checksum": _checksum(aggregate),
	}

func load_json(path: String) -> Dictionary:
	return _report_service.load_external_json(path)

func load_manifests(paths: Array) -> Dictionary:
	var registry: Dictionary = {}
	for index: int in range(paths.size()):
		var loaded: Dictionary = load_json(String(paths[index]))
		if not bool(loaded.get("ok", false)):
			return _failure("manifest_%d:%s" % [index, String(loaded.get("error", "load_failed"))])
		var manifest: Dictionary = loaded.get("dataset", {})
		var validation: Dictionary = _infrastructure.validate_session_manifest(manifest)
		if not bool(validation.get("ok", false)):
			return _failure("manifest_%d:%s" % [index, String(validation.get("error", "invalid"))])
		var checksum: String = String(validation.get("manifest_checksum", ""))
		if registry.has(checksum):
			return _failure("duplicate_manifest_checksum:%s" % checksum)
		registry[checksum] = manifest.duplicate(true)
	return {"ok": true, "error": "", "manifests_by_checksum": registry}

func audit_package(datasets: Array, manifests_by_checksum: Dictionary, bronze_dataset: Dictionary = {}) -> Dictionary:
	var dataset_rows: Array = []
	var build_coverage: Dictionary = {}
	var cohort_coverage: Dictionary = {}
	var sample_types: Dictionary = {}
	var invalid_sources: Array = []
	for index: int in range(datasets.size()):
		var raw_dataset: Variant = datasets[index]
		if not raw_dataset is Dictionary:
			invalid_sources.append("source_%d:not_dictionary" % index)
			continue
		var dataset: Dictionary = raw_dataset
		var validation: Dictionary = validate_bound_dataset(dataset, manifests_by_checksum)
		if not bool(validation.get("ok", false)):
			invalid_sources.append("source_%d:%s" % [index, String(validation.get("error", "invalid"))])
			continue
		var binding: Dictionary = validation.get("session_binding", {})
		var build_key: String = "%s|%s|%s" % [String(binding.get("prototype_build_id", "")), String(binding.get("rules_version", "")), String(binding.get("content_version", ""))]
		build_coverage[build_key] = int(build_coverage.get(build_key, 0)) + 1
		var cohort: String = String(binding.get("declared_cohort", ""))
		cohort_coverage[cohort] = int(cohort_coverage.get(cohort, 0)) + int(validation.get("sample_count", 0))
		for raw_sample: Variant in dataset.get("samples", []):
			if raw_sample is Dictionary:
				var sample_type: String = String((raw_sample as Dictionary).get("sample_type", ""))
				sample_types[sample_type] = int(sample_types.get(sample_type, 0)) + 1
		dataset_rows.append({"dataset_id": String(dataset.get("dataset_id", "")), "manifest_checksum": String(binding.get("manifest_checksum", "")), "sample_count": int(validation.get("sample_count", 0))})
	dataset_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("dataset_id", "")) < String(b.get("dataset_id", ""))
	)
	var missing_evidence_classes: Array[String] = []
	for required_type: String in ["failed_review_retry", "memorable_outcome", "planning_duration", "species_decision", "demo_identity", "review_usability"]:
		if int(sample_types.get(required_type, 0)) == 0:
			missing_evidence_classes.append(required_type)
	var bronze_state: String = "NOT_SUPPLIED"
	if not bronze_dataset.is_empty():
		var bronze_validation: Dictionary = _geometry_evaluator.validate_dataset(bronze_dataset)
		if not bool(bronze_validation.get("ok", false)):
			bronze_state = "INVALID"
		elif bool((bronze_dataset.get("corpus_metadata", {}) as Dictionary).get("authoritative_corpus", false)):
			bronze_state = String(_geometry_evaluator.evaluate(bronze_dataset).get("overall_status", "INSUFFICIENT_EVIDENCE"))
		else:
			bronze_state = "INSUFFICIENT_EVIDENCE"
	var eligible: bool = invalid_sources.is_empty() and not datasets.is_empty()
	var audit_payload: Dictionary = {
		"datasets": dataset_rows,
		"build_coverage": build_coverage,
		"cohort_sample_coverage": cohort_coverage,
		"sample_type_counts": sample_types,
		"missing_evidence_classes": missing_evidence_classes,
		"certified_bronze_state": bronze_state,
		"invalid_sources": invalid_sources,
	}
	return {
		"audit_version": AUDIT_VERSION,
		"eligible_for_gate_evaluation": eligible,
		"invalid_sources": invalid_sources,
		"datasets": dataset_rows,
		"manifest_count": manifests_by_checksum.size(),
		"build_coverage": build_coverage,
		"cohort_sample_coverage": cohort_coverage,
		"sample_type_counts": sample_types,
		"missing_evidence_classes": missing_evidence_classes,
		"certified_bronze_state": bronze_state,
		"human_evidence_complete": missing_evidence_classes.is_empty(),
		"audit_checksum": _checksum(audit_payload),
	}

func write_json(path: String, payload: Dictionary) -> Dictionary:
	if path.strip_edges().is_empty():
		return _failure("missing_output_path")
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var directory: String = absolute_path.get_base_dir()
	if not directory.is_empty():
		var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			return _failure("mkdir_failed:%d" % mkdir_error)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return _failure("open_write_failed")
	file.store_string(JSON.stringify(payload, "  ", true, true))
	file.flush()
	file.close()
	return {"ok": true, "error": "", "path": path}

func _sample_declaration_error(dataset: Dictionary, manifest: Dictionary) -> String:
	var declared_types_value: Variant = manifest.get("declared_sample_types", [])
	var declared_contracts_value: Variant = manifest.get("declared_contract_ids", [])
	if not declared_types_value is Array or not declared_contracts_value is Array:
		return "invalid_manifest_declarations"
	var declared_types: Array = declared_types_value
	var declared_contracts: Array = declared_contracts_value
	for raw_sample: Variant in dataset.get("samples", []):
		if not raw_sample is Dictionary:
			continue
		var sample: Dictionary = raw_sample
		var sample_type: String = String(sample.get("sample_type", ""))
		if not declared_types.has(sample_type):
			return "sample_type_not_declared:%s" % sample_type
		var contract_id: String = String(sample.get("contract_id", "")).strip_edges()
		if not contract_id.is_empty() and not declared_contracts.has(contract_id):
			return "sample_contract_not_declared:%s" % contract_id
	return ""

static func _sorted_unique(values: Array) -> Array[String]:
	var result: Array[String] = []
	for raw: Variant in values:
		var value: String = String(raw)
		if not result.has(value):
			result.append(value)
	result.sort()
	return result

static func _checksum(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
