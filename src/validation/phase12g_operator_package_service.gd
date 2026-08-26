class_name Phase12GOperatorPackageService
extends RefCounted

const InfrastructureScript := preload("res://src/validation/phase12g_study_infrastructure.gd")
const PackageServiceScript := preload("res://src/validation/phase12g_study_package_service.gd")
const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")

const MODES: Array[String] = ["manifest-create", "manifest-validate", "bind", "package", "bronze-import"]

var _infrastructure: Phase12GStudyInfrastructure = InfrastructureScript.new()
var _package: Phase12GStudyPackageService = PackageServiceScript.new()
var _report: Phase12GEvidenceReportService = ReportServiceScript.new()

func options_from_args(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"mode":"",
		"dry_run":false,
		"manifest_paths":[],
		"evidence_paths":[],
		"sample_types":[],
		"contract_ids":[],
		"trusted_authority_ids":[],
	}
	for arg: String in args:
		if arg == "--dry-run":
			options["dry_run"] = true
			continue
		if not arg.begins_with("--") or not arg.contains("="):
			return _failure("invalid_argument:%s" % arg)
		var split_at: int = arg.find("=")
		var key: String = arg.substr(2, split_at - 2)
		var value: String = arg.substr(split_at + 1).strip_edges()
		if value.is_empty():
			return _failure("empty_argument:%s" % key)
		match key:
			"mode": options["mode"] = value
			"manifest": (options["manifest_paths"] as Array).append(value)
			"evidence": (options["evidence_paths"] as Array).append(value)
			"sample-type": (options["sample_types"] as Array).append(value)
			"contract-id": (options["contract_ids"] as Array).append(value)
			"trusted-authority": (options["trusted_authority_ids"] as Array).append(value)
			"session-id", "prototype-build-id", "rules-version", "content-version", "cohort", "created-at-unix", "manifest-out", "bound-out", "aggregate-out", "audit-out", "report-json-out", "report-text-out", "bronze-export", "bronze-geometry", "geometry-out", "geometry-report-out":
				options[key.replace("-", "_")] = value
			_:
				return _failure("unknown_argument:%s" % key)
	if String(options.get("mode", "")) not in MODES:
		return _failure("missing_or_invalid_mode")
	return {"ok":true, "error":"", "options":options}

func execute(options: Dictionary) -> Dictionary:
	var mode: String = String(options.get("mode", ""))
	match mode:
		"manifest-create": return create_manifest(options)
		"manifest-validate": return validate_manifest(options)
		"bind": return bind_evidence(options)
		"package": return build_package(options)
		"bronze-import": return import_bronze(options)
	return _failure("missing_or_invalid_mode")

func create_manifest(options: Dictionary) -> Dictionary:
	var output_path: String = String(options.get("manifest_out", "")).strip_edges()
	var dry_run: bool = bool(options.get("dry_run", false))
	if output_path.is_empty() and not dry_run:
		return _failure("missing_manifest_out")
	var created_at_unix: int = int(String(options.get("created_at_unix", "0")))
	if created_at_unix <= 0:
		created_at_unix = int(Time.get_unix_time_from_system())
	var created: Dictionary = _infrastructure.create_session_manifest(
		String(options.get("session_id", "")),
		String(options.get("prototype_build_id", "")),
		String(options.get("rules_version", "")),
		String(options.get("content_version", "")),
		String(options.get("cohort", "")),
		_array_option(options, "sample_types"),
		_array_option(options, "contract_ids"),
		created_at_unix
	)
	if not bool(created.get("ok", false)):
		return created
	var manifest: Dictionary = _dictionary(created.get("manifest", {}))
	if not dry_run:
		var written: Dictionary = _infrastructure.write_session_manifest(manifest, output_path)
		if not bool(written.get("ok", false)):
			return written
	return {
		"ok":true,
		"error":"",
		"mode":"manifest-create",
		"dry_run":dry_run,
		"manifest":manifest.duplicate(true),
		"manifest_checksum":String(manifest.get("manifest_checksum", "")),
		"session_id":String(manifest.get("session_id", "")),
		"output_path":output_path,
	}

func validate_manifest(options: Dictionary) -> Dictionary:
	var paths: Array = _array_option(options, "manifest_paths")
	if paths.size() != 1:
		return _failure("manifest_validate_requires_one_manifest")
	var loaded: Dictionary = _package.load_json(String(paths[0]))
	if not bool(loaded.get("ok", false)):
		return _failure("manifest_load:%s" % String(loaded.get("error", "unknown")))
	var manifest: Dictionary = _dictionary(loaded.get("dataset", {}))
	var validation: Dictionary = _infrastructure.validate_session_manifest(manifest)
	if not bool(validation.get("ok", false)):
		return validation
	return {
		"ok":true,
		"error":"",
		"mode":"manifest-validate",
		"manifest_checksum":String(validation.get("manifest_checksum", "")),
		"session_id":String(manifest.get("session_id", "")),
		"prototype_build_id":String(manifest.get("prototype_build_id", "")),
		"declared_cohort":String(manifest.get("declared_cohort", "")),
	}

func bind_evidence(options: Dictionary) -> Dictionary:
	var manifests: Array = _array_option(options, "manifest_paths")
	var evidence_paths: Array = _array_option(options, "evidence_paths")
	if manifests.size() != 1 or evidence_paths.size() != 1:
		return _failure("bind_requires_one_manifest_and_one_evidence")
	var manifest_path: String = String(manifests[0])
	var evidence_path: String = String(evidence_paths[0])
	var output_path: String = String(options.get("bound_out", "")).strip_edges()
	var dry_run: bool = bool(options.get("dry_run", false))
	if not dry_run:
		if output_path.is_empty():
			return _failure("missing_bound_out")
		var path_error: String = _output_path_error(output_path, [manifest_path, evidence_path])
		if not path_error.is_empty():
			return _failure(path_error)
	var manifest_loaded: Dictionary = _package.load_json(manifest_path)
	if not bool(manifest_loaded.get("ok", false)):
		return _failure("manifest_load:%s" % String(manifest_loaded.get("error", "unknown")))
	var evidence_loaded: Dictionary = _package.load_json(evidence_path)
	if not bool(evidence_loaded.get("ok", false)):
		return _failure("evidence_load:%s" % String(evidence_loaded.get("error", "unknown")))
	var manifest: Dictionary = _dictionary(manifest_loaded.get("dataset", {}))
	var evidence: Dictionary = _dictionary(evidence_loaded.get("dataset", {}))
	var bound: Dictionary = _package.bind_dataset_to_session(evidence, manifest)
	if not bool(bound.get("ok", false)):
		return bound
	var dataset: Dictionary = _dictionary(bound.get("dataset", {}))
	if not dry_run:
		var written: Dictionary = _package.write_json(output_path, dataset)
		if not bool(written.get("ok", false)):
			return written
	return {
		"ok":true,
		"error":"",
		"mode":"bind",
		"dry_run":dry_run,
		"dataset":dataset.duplicate(true),
		"session_binding":_dictionary(bound.get("session_binding", {})),
		"output_path":output_path,
	}

func build_package(options: Dictionary) -> Dictionary:
	var manifest_paths: Array = _array_option(options, "manifest_paths")
	var evidence_paths: Array = _array_option(options, "evidence_paths")
	if manifest_paths.is_empty() or evidence_paths.is_empty():
		return _failure("package_requires_manifest_and_evidence")
	var manifests_result: Dictionary = _package.load_manifests(manifest_paths)
	if not bool(manifests_result.get("ok", false)):
		return manifests_result
	var registry: Dictionary = _dictionary(manifests_result.get("manifests_by_checksum", {}))
	var datasets: Array = []
	for index: int in range(evidence_paths.size()):
		var loaded: Dictionary = _package.load_json(String(evidence_paths[index]))
		if not bool(loaded.get("ok", false)):
			return _failure("evidence_%d:%s" % [index, String(loaded.get("error", "unknown"))])
		datasets.append(_dictionary(loaded.get("dataset", {})))
	var merged: Dictionary = _package.merge_bound_datasets(datasets, registry)
	if not bool(merged.get("ok", false)):
		return merged
	var bronze_dataset: Dictionary = {}
	var bronze_geometry_path: String = String(options.get("bronze_geometry", "")).strip_edges()
	if not bronze_geometry_path.is_empty():
		var bronze_loaded: Dictionary = _package.load_json(bronze_geometry_path)
		if not bool(bronze_loaded.get("ok", false)):
			return _failure("bronze_geometry_load:%s" % String(bronze_loaded.get("error", "unknown")))
		bronze_dataset = _dictionary(bronze_loaded.get("dataset", {}))
	var audit: Dictionary = _package.audit_package(datasets, registry, bronze_dataset)
	var aggregate: Dictionary = _dictionary(merged.get("dataset", {}))
	var report: Dictionary = _dictionary(merged.get("report", {}))
	var dry_run: bool = bool(options.get("dry_run", false))
	if not dry_run:
		var outputs: Dictionary = {
			"aggregate_out":String(options.get("aggregate_out", "")),
			"audit_out":String(options.get("audit_out", "")),
			"report_json_out":String(options.get("report_json_out", "")),
			"report_text_out":String(options.get("report_text_out", "")),
		}
		var output_paths: Array = []
		for key: String in outputs.keys():
			var output_path: String = String(outputs[key]).strip_edges()
			if output_path.is_empty():
				return _failure("missing_%s" % key)
			var normalized_output: String = ProjectSettings.globalize_path(output_path).simplify_path()
			if output_paths.has(normalized_output):
				return _failure("duplicate_output_path:%s" % output_path)
			output_paths.append(normalized_output)
		var source_paths: Array = manifest_paths.duplicate()
		source_paths.append_array(evidence_paths)
		if not bronze_geometry_path.is_empty():
			source_paths.append(bronze_geometry_path)
		for key: String in outputs.keys():
			var path_error: String = _output_path_error(String(outputs[key]), source_paths)
			if not path_error.is_empty():
				return _failure(path_error)
		var aggregate_write: Dictionary = _package.write_json(String(outputs["aggregate_out"]), aggregate)
		if not bool(aggregate_write.get("ok", false)):
			return aggregate_write
		var audit_write: Dictionary = _package.write_json(String(outputs["audit_out"]), audit)
		if not bool(audit_write.get("ok", false)):
			return audit_write
		var report_write: Dictionary = _report.write_report_files(report, String(outputs["report_json_out"]), String(outputs["report_text_out"]))
		if not bool(report_write.get("ok", false)):
			return report_write
	return {
		"ok":true,
		"error":"",
		"mode":"package",
		"dry_run":dry_run,
		"aggregate":aggregate.duplicate(true),
		"audit":audit.duplicate(true),
		"report":report.duplicate(true),
		"aggregate_checksum":String(merged.get("aggregate_checksum", "")),
		"overall_status":String(report.get("overall_status", "INCOMPLETE")),
		"certified_bronze_state":String(audit.get("certified_bronze_state", "NOT_SUPPLIED")),
	}

func import_bronze(options: Dictionary) -> Dictionary:
	var source_path: String = String(options.get("bronze_export", "")).strip_edges()
	if source_path.is_empty():
		return _failure("missing_bronze_export")
	var trusted: Array = _array_option(options, "trusted_authority_ids")
	if trusted.is_empty():
		return _failure("missing_trusted_authority")
	var loaded: Dictionary = _package.load_json(source_path)
	if not bool(loaded.get("ok", false)):
		return _failure("bronze_export_load:%s" % String(loaded.get("error", "unknown")))
	var export_dataset: Dictionary = _dictionary(loaded.get("dataset", {}))
	var ingested: Dictionary = _infrastructure.ingest_certified_bronze_export(export_dataset, trusted)
	if not bool(ingested.get("ok", false)):
		return ingested
	var dry_run: bool = bool(options.get("dry_run", false))
	var geometry_out: String = String(options.get("geometry_out", "")).strip_edges()
	var report_out: String = String(options.get("geometry_report_out", "")).strip_edges()
	if not dry_run:
		if geometry_out.is_empty() or report_out.is_empty():
			return _failure("missing_bronze_output_path")
		if ProjectSettings.globalize_path(geometry_out).simplify_path() == ProjectSettings.globalize_path(report_out).simplify_path():
			return _failure("duplicate_output_path:%s" % geometry_out)
		var output_paths: Array[String] = [geometry_out, report_out]
		for output_path: String in output_paths:
			var path_error: String = _output_path_error(output_path, [source_path])
			if not path_error.is_empty():
				return _failure(path_error)
		var geometry_write: Dictionary = _package.write_json(geometry_out, _dictionary(ingested.get("geometry_dataset", {})))
		if not bool(geometry_write.get("ok", false)):
			return geometry_write
		var report_write: Dictionary = _package.write_json(report_out, _dictionary(ingested.get("geometry_report", {})))
		if not bool(report_write.get("ok", false)):
			return report_write
	var geometry_report: Dictionary = _dictionary(ingested.get("geometry_report", {}))
	return {
		"ok":true,
		"error":"",
		"mode":"bronze-import",
		"dry_run":dry_run,
		"geometry_dataset":_dictionary(ingested.get("geometry_dataset", {})),
		"geometry_report":geometry_report.duplicate(true),
		"source_export_checksum":String(ingested.get("source_export_checksum", "")),
		"certification_authority":String(ingested.get("certification_authority", "")),
		"overall_status":String(geometry_report.get("overall_status", "INSUFFICIENT_EVIDENCE")),
	}

func _array_option(options: Dictionary, key: String) -> Array:
	var value: Variant = options.get(key, [])
	if value is Array:
		return (value as Array).duplicate(true)
	return []

func _output_path_error(output_path: String, input_paths: Array) -> String:
	if output_path.strip_edges().is_empty():
		return "missing_output_path"
	var normalized_output: String = ProjectSettings.globalize_path(output_path).simplify_path()
	for raw_path: Variant in input_paths:
		var input_path: String = String(raw_path).strip_edges()
		if input_path.is_empty():
			continue
		if ProjectSettings.globalize_path(input_path).simplify_path() == normalized_output:
			return "output_would_overwrite_source:%s" % output_path
	return ""

static func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _failure(error: String) -> Dictionary:
	return {"ok":false, "error":error}
