extends SceneTree

const OperatorServiceScript := preload("res://src/validation/phase12g_operator_package_service.gd")
const InfrastructureScript := preload("res://src/validation/phase12g_study_infrastructure.gd")
const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")

const ROOT := "user://phase12g_operator_package"
var failures: int = 0

func _init() -> void:
	_clear_root()
	_test_cli_manifest_bind_and_package()
	_test_fail_closed_and_bronze_path()
	_finish()

func _test_cli_manifest_bind_and_package() -> void:
	var service: Phase12GOperatorPackageService = OperatorServiceScript.new()
	var parsed: Dictionary = service.options_from_args(PackedStringArray([
		"--mode=manifest-create", "--session-id=session-a", "--prototype-build-id=build-204",
		"--rules-version=rules-r1", "--content-version=content-v1",
		"--cohort=%s" % ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY,
		"--sample-type=planning_duration", "--contract-id=C10", "--created-at-unix=1800000204", "--dry-run",
	]))
	_expect(bool(parsed.get("ok", false)), "CLI argument contract parses repeated/value switches and dry-run")
	var options: Dictionary = _dict(parsed.get("options", {}))
	_expect(bool(options.get("dry_run", false)), "CLI argument contract preserves dry-run")
	_expect_equal((options.get("sample_types", []) as Array).size(), 1, "CLI argument contract preserves declared sample types")
	_expect_equal(service.options_from_args(PackedStringArray(["--mode=package", "--invented=x"])).get("error"), "unknown_argument:invented", "unknown CLI switch fails closed")

	var manifest_path: String = "%s/session-a.json" % ROOT
	var raw_path: String = "%s/raw-a.json" % ROOT
	var bound_path: String = "%s/bound-a.json" % ROOT
	var create_result: Dictionary = service.create_manifest({
		"mode":"manifest-create", "session_id":"session-a", "prototype_build_id":"build-204",
		"rules_version":"rules-r1", "content_version":"content-v1",
		"cohort":ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY,
		"sample_types":["planning_duration"], "contract_ids":["C10"],
		"created_at_unix":"1800000204", "manifest_out":manifest_path,
	})
	_expect(bool(create_result.get("ok", false)), "operator creates pre-collection session manifest")
	_expect(bool(service.validate_manifest({"manifest_paths":[manifest_path]}).get("ok", false)), "persisted session manifest validates")

	_write_json(raw_path, _operator_dataset("dataset-a", [_planning_sample("plan-a")]))
	var raw_before: String = _read_text(raw_path)
	var bound: Dictionary = service.bind_evidence({"manifest_paths":[manifest_path], "evidence_paths":[raw_path], "bound_out":bound_path})
	_expect(bool(bound.get("ok", false)), "valid raw evidence binds to pre-collection manifest")
	_expect(FileAccess.file_exists(bound_path), "bound evidence writes to separate output")
	_expect_equal(_read_text(raw_path), raw_before, "raw evidence remains immutable after binding")
	var binding: Dictionary = _dict(bound.get("session_binding", {}))
	_expect_equal(binding.get("session_id"), "session-a", "bound evidence records session identity")
	_expect(not String(binding.get("manifest_checksum", "")).is_empty(), "bound evidence records manifest checksum")

	var dry_outputs: Array[String] = ["%s/dry.aggregate.json" % ROOT, "%s/dry.audit.json" % ROOT, "%s/dry.report.json" % ROOT, "%s/dry.report.txt" % ROOT]
	var dry: Dictionary = service.build_package({
		"manifest_paths":[manifest_path], "evidence_paths":[bound_path], "aggregate_out":dry_outputs[0],
		"audit_out":dry_outputs[1], "report_json_out":dry_outputs[2], "report_text_out":dry_outputs[3], "dry_run":true,
	})
	_expect(bool(dry.get("ok", false)), "package dry-run validates partial evidence without writing")
	_expect_equal(dry.get("overall_status"), "INCOMPLETE", "partial human evidence stays visibly INCOMPLETE rather than PASS/error")
	_expect_equal(dry.get("certified_bronze_state"), "NOT_SUPPLIED", "missing Bronze evidence remains explicit")
	for output_path: String in dry_outputs:
		_expect(not FileAccess.file_exists(output_path), "dry-run does not write %s" % output_path)

	var aggregate_path: String = "%s/aggregate.json" % ROOT
	var audit_path: String = "%s/audit.json" % ROOT
	var report_json_path: String = "%s/report.json" % ROOT
	var report_text_path: String = "%s/report.txt" % ROOT
	var built: Dictionary = service.build_package({
		"manifest_paths":[manifest_path], "evidence_paths":[bound_path], "aggregate_out":aggregate_path,
		"audit_out":audit_path, "report_json_out":report_json_path, "report_text_out":report_text_path,
	})
	_expect(bool(built.get("ok", false)), "package writes deterministic aggregate/audit/reports")
	for output_path: String in [aggregate_path, audit_path, report_json_path, report_text_path]:
		_expect(FileAccess.file_exists(output_path), "derived package output exists: %s" % output_path)
	_expect(_read_text(report_text_path).contains("Overall: INCOMPLETE"), "text report exposes incomplete empirical state")
	_expect_equal(_read_text(raw_path), raw_before, "package generation does not mutate raw evidence")
	var overwrite: Dictionary = service.bind_evidence({"manifest_paths":[manifest_path], "evidence_paths":[raw_path], "bound_out":raw_path})
	_expect(String(overwrite.get("error", "")).begins_with("output_would_overwrite_source:"), "operator path refuses source overwrite")

func _test_fail_closed_and_bronze_path() -> void:
	var service: Phase12GOperatorPackageService = OperatorServiceScript.new()
	var manifest_path: String = "%s/session-bad.json" % ROOT
	_expect(bool(service.create_manifest({
		"session_id":"session-bad", "prototype_build_id":"build-204", "rules_version":"rules-r1", "content_version":"content-v1",
		"cohort":ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, "sample_types":["planning_duration"], "contract_ids":["C10"],
		"created_at_unix":"1800000205", "manifest_out":manifest_path,
	}).get("ok", false)), "malformed-input fixture manifest is valid")
	var malformed: Dictionary = _operator_dataset("dataset-malformed", [_planning_sample("bad-plan")])
	var malformed_samples: Array = malformed.get("samples", [])
	var malformed_sample: Dictionary = _dict(malformed_samples[0])
	malformed_sample.erase("tester_id")
	malformed_samples[0] = malformed_sample
	malformed["samples"] = malformed_samples
	var malformed_path: String = "%s/raw-malformed.json" % ROOT
	var rejected_path: String = "%s/rejected.bound.json" % ROOT
	_write_json(malformed_path, malformed)
	var rejected: Dictionary = service.bind_evidence({"manifest_paths":[manifest_path], "evidence_paths":[malformed_path], "bound_out":rejected_path})
	_expect(String(rejected.get("error", "")).contains("missing_tester_id"), "malformed evidence is rejected before persistence")
	_expect(not FileAccess.file_exists(rejected_path), "malformed evidence creates no bound output")

	var infrastructure: Phase12GStudyInfrastructure = InfrastructureScript.new()
	var external_export: Dictionary = {
		"format_version":InfrastructureScript.BRONZE_EXPORT_VERSION,
		"export_metadata":{"corpus_id":"solver-corpus-204", "solver_version":"solver-4.2", "content_version":"content-v1", "authority_id":"trusted-solver-lab", "certification_status":InfrastructureScript.CERTIFICATION_STATUS, "checksum_method":InfrastructureScript.BRONZE_CHECKSUM_METHOD, "authoritative_corpus":true},
		"solutions":[{"solution_id":"bronze-204", "contract_id":"C09", "chapter":2, "campaign_order":9, "normalized_role_to_zone":"PROTECTOR@A|SOOTHER@B", "high_isolation_status":"INFERIOR", "certified_bronze":true, "primary_family":true, "isolation_ratio":0.35, "beneficial_relation_count":2}],
	}
	var export_metadata: Dictionary = _dict(external_export.get("export_metadata", {}))
	export_metadata["export_checksum"] = infrastructure.bronze_export_checksum(external_export)
	external_export["export_metadata"] = export_metadata
	var export_path: String = "%s/certified-export.json" % ROOT
	var geometry_path: String = "%s/geometry.json" % ROOT
	var geometry_report_path: String = "%s/geometry-report.json" % ROOT
	_write_json(export_path, external_export)
	var export_before: String = _read_text(export_path)
	var dry: Dictionary = service.import_bronze({"bronze_export":export_path, "trusted_authority_ids":["trusted-solver-lab"], "geometry_out":geometry_path, "geometry_report_out":geometry_report_path, "dry_run":true})
	_expect(bool(dry.get("ok", false)), "trusted checksummed Bronze export validates in dry-run")
	_expect_equal(dry.get("overall_status"), "FAIL", "valid but insufficiently broad certified fixture remains an explicit empirical FAIL, not a tool error or PASS")
	_expect(not FileAccess.file_exists(geometry_path), "Bronze dry-run writes no geometry")
	var imported: Dictionary = service.import_bronze({"bronze_export":export_path, "trusted_authority_ids":["trusted-solver-lab"], "geometry_out":geometry_path, "geometry_report_out":geometry_report_path})
	_expect(bool(imported.get("ok", false)), "trusted certified Bronze import writes derived outputs")
	_expect(FileAccess.file_exists(geometry_path) and FileAccess.file_exists(geometry_report_path), "Bronze geometry and report are separate derived files")
	_expect_equal(_read_text(export_path), export_before, "certified solver source export remains immutable")
	var untrusted: Dictionary = service.import_bronze({"bronze_export":export_path, "trusted_authority_ids":["other-lab"], "dry_run":true})
	_expect(String(untrusted.get("error", "")).begins_with("untrusted_certification_authority:"), "untrusted certification authority remains fail-closed")

func _operator_dataset(dataset_id: String, samples: Array) -> Dictionary:
	return {"schema_version":"phase12g-evidence-v1", "dataset_id":dataset_id, "collection_metadata":{"metadata_version":ReportServiceScript.COLLECTION_METADATA_VERSION, "source_id":"operator-source", "collection_owner":"study-operator", "cohort_policy_version":"phase12g-cohort-policy-v1"}, "samples":samples}

func _planning_sample(sample_id: String) -> Dictionary:
	return {"sample_id":sample_id, "sample_type":"planning_duration", "tester_id":"pseudo-operator-1", "captured_at_unix":1800000204, "cohort":ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, "contract_id":"C10", "duration_seconds":420.0, "ordinary_non_mastery":true, "rule_familiarity":true}

func _write_json(path: String, payload: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	_expect(file != null, "fixture opens: %s" % path)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ", true, true))
		file.close()

func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()

func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _clear_root() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		_remove_tree(absolute_root)
	DirAccess.make_dir_recursive_absolute(absolute_root)

func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child: String = path.path_join(name)
			if directory.current_is_dir(): _remove_tree(child)
			else: DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)

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
		print("phase12g_operator_package_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12g_operator_package_test_runner: %d failure(s)" % failures)
		quit(1)
