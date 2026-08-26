class_name Phase12GStudyInfrastructure
extends RefCounted

const EvaluatorScript := preload("res://src/validation/phase12g_empirical_evidence_evaluator.gd")
const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")
const GeometryEvaluatorScript := preload("res://src/validation/phase12g_bronze_geometry_evidence_evaluator.gd")

const SESSION_MANIFEST_VERSION := "phase12g-study-session-v1"
const BRONZE_EXPORT_VERSION := "phase12g-certified-bronze-export-v1"
const BRONZE_CHECKSUM_METHOD := "sha256-canonical-json-v1"
const CERTIFICATION_STATUS := "CERTIFIED"

var _report_service: Phase12GEvidenceReportService = ReportServiceScript.new()
var _geometry_evaluator: Phase12GBronzeGeometryEvidenceEvaluator = GeometryEvaluatorScript.new()

func merge_operator_files(paths: Array) -> Dictionary:
    if paths.is_empty():
        return _failure("no_source_files")
    var datasets: Array = []
    var source_keys: Array = []
    for index: int in range(paths.size()):
        var path: String = String(paths[index]).strip_edges()
        if path.is_empty():
            return _failure("source_%d:missing_path" % index)
        var loaded: Dictionary = _report_service.load_external_json(path)
        if not bool(loaded.get("ok", false)):
            return _failure("source_%d:%s" % [index, String(loaded.get("error", "load_failed"))])
        datasets.append((loaded.get("dataset", {}) as Dictionary).duplicate(true))
        var loaded_dataset: Dictionary = loaded.get("dataset", {})
        source_keys.append(String(loaded_dataset.get("dataset_id", "source-%d" % index)))
    return merge_operator_datasets(datasets, source_keys)

func merge_operator_datasets(datasets: Array, source_keys: Array = []) -> Dictionary:
    if datasets.is_empty():
        return _failure("no_source_datasets")
    if not source_keys.is_empty() and source_keys.size() != datasets.size():
        return _failure("source_key_count_mismatch")

    var entries: Array[Dictionary] = []
    var cohort_policy_version: String = ""
    var seen_dataset_ids: Dictionary = {}
    for index: int in range(datasets.size()):
        var raw_dataset: Variant = datasets[index]
        if not raw_dataset is Dictionary:
            return _failure("source_%d:not_dictionary" % index)
        var dataset: Dictionary = (raw_dataset as Dictionary).duplicate(true)
        var validation: Dictionary = _report_service.validate_operator_dataset(dataset)
        if not bool(validation.get("ok", false)):
            return _failure("source_%d:%s" % [index, String(validation.get("error", "invalid_operator_dataset"))])
        var dataset_id: String = String(dataset.get("dataset_id", "")).strip_edges()
        if seen_dataset_ids.has(dataset_id):
            return _failure("duplicate_dataset_id:%s" % dataset_id)
        seen_dataset_ids[dataset_id] = true
        var metadata: Dictionary = dataset.get("collection_metadata", {})
        var policy: String = String(metadata.get("cohort_policy_version", ""))
        if cohort_policy_version.is_empty():
            cohort_policy_version = policy
        elif policy != cohort_policy_version:
            return _failure("cohort_policy_version_mismatch")
        var source_key: String = dataset_id if source_keys.is_empty() else String(source_keys[index])
        entries.append({
            "dataset_id": dataset_id,
            "source_key": source_key,
            "source_id": String(metadata.get("source_id", "")),
            "dataset_checksum": _checksum(dataset),
            "dataset": dataset,
        })

    entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_key: String = "%s|%s" % [String(left.get("dataset_id", "")), String(left.get("source_key", ""))]
        var right_key: String = "%s|%s" % [String(right.get("dataset_id", "")), String(right.get("source_key", ""))]
        return left_key < right_key
    )

    var seen_sample_ids: Dictionary = {}
    var merged_samples: Array = []
    var source_manifest: Array = []
    for entry: Dictionary in entries:
        source_manifest.append({
            "dataset_id": String(entry["dataset_id"]),
            "source_key": String(entry["source_key"]),
            "source_id": String(entry["source_id"]),
            "dataset_checksum": String(entry["dataset_checksum"]),
        })
        var dataset: Dictionary = entry["dataset"]
        var samples: Array = dataset.get("samples", [])
        for raw_sample: Variant in samples:
            var sample: Dictionary = (raw_sample as Dictionary).duplicate(true)
            var sample_id: String = String(sample.get("sample_id", ""))
            if seen_sample_ids.has(sample_id):
                return _failure("duplicate_sample_id_across_sources:%s" % sample_id)
            seen_sample_ids[sample_id] = true
            sample["source_provenance"] = {
                "dataset_id": String(entry["dataset_id"]),
                "source_key": String(entry["source_key"]),
                "source_id": String(entry["source_id"]),
                "dataset_checksum": String(entry["dataset_checksum"]),
            }
            merged_samples.append(sample)

    merged_samples.sort_custom(func(left: Variant, right: Variant) -> bool:
        return String((left as Dictionary).get("sample_id", "")) < String((right as Dictionary).get("sample_id", ""))
    )
    var source_manifest_checksum: String = _checksum(source_manifest)
    var aggregate_dataset: Dictionary = {
        "schema_version": EvaluatorScript.SCHEMA_VERSION,
        "dataset_id": "merged-%s" % source_manifest_checksum.left(16),
        "collection_metadata": {
            "metadata_version": ReportServiceScript.COLLECTION_METADATA_VERSION,
            "source_id": "MERGED:%s" % source_manifest_checksum,
            "collection_owner": "PHASE12G_DETERMINISTIC_MERGE",
            "cohort_policy_version": cohort_policy_version,
            "source_datasets": source_manifest,
        },
        "samples": merged_samples,
    }
    var aggregate_validation: Dictionary = _report_service.validate_operator_dataset(aggregate_dataset)
    if not bool(aggregate_validation.get("ok", false)):
        return _failure("aggregate_invalid:%s" % String(aggregate_validation.get("error", "unknown")))
    var report: Dictionary = _report_service.evaluate_operator_dataset(aggregate_dataset)
    if not bool(report.get("ok", false)):
        return _failure("aggregate_report_invalid:%s" % String(report.get("error", "unknown")))
    return {
        "ok": true,
        "error": "",
        "dataset": aggregate_dataset.duplicate(true),
        "report": report.duplicate(true),
        "source_manifest": source_manifest.duplicate(true),
        "aggregate_checksum": _checksum(aggregate_dataset),
    }

func create_session_manifest(
    session_id: String,
    prototype_build_id: String,
    rules_version: String,
    content_version: String,
    cohort: String,
    declared_sample_types: Array,
    declared_contract_ids: Array,
    created_at_unix: int
) -> Dictionary:
    if session_id.strip_edges().is_empty():
        return _failure("missing_session_id")
    var identifiers: Dictionary = {
        "prototype_build_id": prototype_build_id,
        "rules_version": rules_version,
        "content_version": content_version,
    }
    for key: String in identifiers.keys():
        if String(identifiers[key]).strip_edges().is_empty():
            return _failure("missing_%s" % key)
    if cohort not in ReportServiceScript.ALLOWED_COHORTS:
        return _failure("invalid_cohort")
    if created_at_unix <= 0:
        return _failure("invalid_created_at_unix")
    if declared_sample_types.is_empty():
        return _failure("missing_declared_sample_types")
    var normalized_types: Array[String] = []
    for raw_type: Variant in declared_sample_types:
        var sample_type: String = String(raw_type)
        if sample_type not in EvaluatorScript.SAMPLE_TYPES:
            return _failure("unknown_sample_type:%s" % sample_type)
        if not normalized_types.has(sample_type):
            normalized_types.append(sample_type)
    normalized_types.sort()
    var normalized_contracts: Array[String] = []
    for raw_contract: Variant in declared_contract_ids:
        var contract_id: String = String(raw_contract).strip_edges()
        if contract_id.is_empty():
            return _failure("empty_declared_contract_id")
        if not normalized_contracts.has(contract_id):
            normalized_contracts.append(contract_id)
    normalized_contracts.sort()
    var payload: Dictionary = {
        "manifest_version": SESSION_MANIFEST_VERSION,
        "session_id": session_id,
        "prototype_build_id": prototype_build_id,
        "rules_version": rules_version,
        "content_version": content_version,
        "declared_cohort": cohort,
        "declared_sample_types": normalized_types,
        "declared_contract_ids": normalized_contracts,
        "created_at_unix": created_at_unix,
        "data_minimization": {
            "collect_real_name": false,
            "collect_email": false,
            "collect_device_serial": false,
            "tester_identifier_policy": "PSEUDONYMOUS_STUDY_ID_ONLY",
        },
    }
    var manifest: Dictionary = payload.duplicate(true)
    manifest["manifest_checksum"] = _checksum(payload)
    return {"ok": true, "error": "", "manifest": manifest}

func validate_session_manifest(manifest: Dictionary) -> Dictionary:
    if String(manifest.get("manifest_version", "")) != SESSION_MANIFEST_VERSION:
        return _failure("unsupported_session_manifest_version")
    for key: String in ["session_id", "prototype_build_id", "rules_version", "content_version", "declared_cohort", "manifest_checksum"]:
        if String(manifest.get(key, "")).strip_edges().is_empty():
            return _failure("missing_%s" % key)
    if String(manifest.get("declared_cohort", "")) not in ReportServiceScript.ALLOWED_COHORTS:
        return _failure("invalid_cohort")
    if int(manifest.get("created_at_unix", 0)) <= 0:
        return _failure("invalid_created_at_unix")
    var types_value: Variant = manifest.get("declared_sample_types", null)
    if not types_value is Array or (types_value as Array).is_empty():
        return _failure("missing_declared_sample_types")
    for raw_type: Variant in (types_value as Array):
        if String(raw_type) not in EvaluatorScript.SAMPLE_TYPES:
            return _failure("unknown_sample_type:%s" % String(raw_type))
    var minimization_value: Variant = manifest.get("data_minimization", null)
    if not minimization_value is Dictionary:
        return _failure("missing_data_minimization")
    var minimization: Dictionary = minimization_value
    for forbidden_flag: String in ["collect_real_name", "collect_email", "collect_device_serial"]:
        if bool(minimization.get(forbidden_flag, true)):
            return _failure("data_minimization_violation:%s" % forbidden_flag)
    var payload: Dictionary = manifest.duplicate(true)
    var declared_checksum: String = String(payload.get("manifest_checksum", ""))
    payload.erase("manifest_checksum")
    if _checksum(payload) != declared_checksum:
        return _failure("session_manifest_checksum_mismatch")
    return {"ok": true, "error": "", "manifest_checksum": declared_checksum}

func write_session_manifest(manifest: Dictionary, path: String) -> Dictionary:
    var validation: Dictionary = validate_session_manifest(manifest)
    if not bool(validation.get("ok", false)):
        return validation
    if path.strip_edges().is_empty():
        return _failure("missing_manifest_output_path")
    return _write_json(path, manifest)

func bronze_export_checksum(external_export: Dictionary) -> String:
    var normalized: Dictionary = external_export.duplicate(true)
    var metadata_value: Variant = normalized.get("export_metadata", {})
    if metadata_value is Dictionary:
        var metadata: Dictionary = (metadata_value as Dictionary).duplicate(true)
        metadata.erase("export_checksum")
        normalized["export_metadata"] = metadata
    return _checksum(normalized)

func ingest_certified_bronze_export(external_export: Dictionary, trusted_authority_ids: Array) -> Dictionary:
    if String(external_export.get("format_version", "")) != BRONZE_EXPORT_VERSION:
        return _failure("unsupported_bronze_export_version")
    var metadata_value: Variant = external_export.get("export_metadata", null)
    if not metadata_value is Dictionary:
        return _failure("missing_export_metadata")
    var metadata: Dictionary = metadata_value
    for key: String in ["corpus_id", "solver_version", "content_version", "authority_id", "certification_status", "checksum_method", "export_checksum"]:
        if String(metadata.get(key, "")).strip_edges().is_empty():
            return _failure("missing_export_metadata_%s" % key)
    if String(metadata.get("certification_status", "")) != CERTIFICATION_STATUS:
        return _failure("bronze_export_not_certified")
    if String(metadata.get("checksum_method", "")) != BRONZE_CHECKSUM_METHOD:
        return _failure("unsupported_checksum_method")
    if not (metadata.get("authoritative_corpus", null) is bool) or not bool(metadata.get("authoritative_corpus", false)):
        return _failure("bronze_export_not_authoritative")
    var authority_id: String = String(metadata.get("authority_id", ""))
    var trusted: bool = false
    for raw_authority: Variant in trusted_authority_ids:
        if String(raw_authority) == authority_id:
            trusted = true
            break
    if not trusted:
        return _failure("untrusted_certification_authority:%s" % authority_id)
    var declared_checksum: String = String(metadata.get("export_checksum", ""))
    var computed_checksum: String = bronze_export_checksum(external_export)
    if declared_checksum != computed_checksum:
        return _failure("bronze_export_checksum_mismatch")
    var solutions_value: Variant = external_export.get("solutions", null)
    if not solutions_value is Array:
        return _failure("solutions_must_be_array")
    var geometry_dataset: Dictionary = {
        "schema_version": GeometryEvaluatorScript.SCHEMA_VERSION,
        "corpus_metadata": {
            "corpus_id": String(metadata["corpus_id"]),
            "solver_version": String(metadata["solver_version"]),
            "content_version": String(metadata["content_version"]),
            "authoritative_corpus": true,
            "certification_authority": authority_id,
            "source_export_checksum": declared_checksum,
        },
        "solutions": (solutions_value as Array).duplicate(true),
    }
    var validation: Dictionary = _geometry_evaluator.validate_dataset(geometry_dataset)
    if not bool(validation.get("ok", false)):
        return _failure("geometry_dataset_invalid:%s" % String(validation.get("error", "unknown")))
    return {
        "ok": true,
        "error": "",
        "geometry_dataset": geometry_dataset,
        "geometry_report": _geometry_evaluator.evaluate(geometry_dataset),
        "source_export_checksum": declared_checksum,
        "certification_authority": authority_id,
    }

func _write_json(path: String, payload: Dictionary) -> Dictionary:
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

static func _checksum(value: Variant) -> String:
    # Hash the same Variant shape that a persisted JSON document will produce.
    # Godot parses JSON numbers as floats, so hashing a pre-write tree containing
    # integer Variants and then validating the reloaded tree can otherwise change
    # the lexical JSON representation and falsely trip the checksum boundary.
    var serialized: String = JSON.stringify(value, "", true, true)
    var normalized: Variant = JSON.parse_string(serialized)
    if normalized == null:
        return serialized.sha256_text()
    return JSON.stringify(normalized, "", true, true).sha256_text()

static func _failure(error: String) -> Dictionary:
    return {"ok": false, "error": error}
