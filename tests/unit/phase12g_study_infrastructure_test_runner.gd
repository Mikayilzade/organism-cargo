extends SceneTree

const InfrastructureScript := preload("res://src/validation/phase12g_study_infrastructure.gd")
const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")

var failures: int = 0

func _init() -> void:
    _test_deterministic_multifile_merge_and_provenance()
    _test_cross_file_duplicate_rejected_and_sources_unchanged()
    _test_session_manifest_contract_and_minimization()
    _test_certified_bronze_adapter_fail_closed()
    _finish()

func _test_deterministic_multifile_merge_and_provenance() -> void:
    var infrastructure: Phase12GStudyInfrastructure = InfrastructureScript.new()
    var dataset_a: Dictionary = _operator_dataset(
        "study-a",
        "source-a",
        [_sample("plan-a", "planning_duration", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, {
            "contract_id":"C10",
            "duration_seconds":420.0,
            "ordinary_non_mastery":true,
            "rule_familiarity":true,
        })]
    )
    var dataset_b: Dictionary = _operator_dataset(
        "study-b",
        "source-b",
        [
            _sample("demo-b", "demo_identity", ReportServiceScript.COHORT_DEMO, {
                "response_text":"transit behavior matters",
                "classification":"TRANSIT_BEHAVIOR",
            }),
            _sample("retry-b", "failed_review_retry", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, {
                "contract_id":"C09",
                "causal_explanation":"heat exposure",
                "intended_revision":"move specimen away from hot zone",
                "blind_shuffle":false,
            }),
        ]
    )

    var first: Dictionary = infrastructure.merge_operator_datasets([dataset_b, dataset_a], ["b.json", "a.json"])
    var second: Dictionary = infrastructure.merge_operator_datasets([dataset_a, dataset_b], ["a.json", "b.json"])
    _expect(bool(first.get("ok", false)), "multi-source operator evidence merges")
    _expect(bool(second.get("ok", false)), "reversed source order also merges")
    _expect_equal(first.get("aggregate_checksum"), second.get("aggregate_checksum"), "aggregate checksum is independent of input file order")
    var first_dataset: Dictionary = first.get("dataset", {})
    var merged_samples: Array = first_dataset.get("samples", [])
    _expect_equal(merged_samples.size(), 3, "all source samples are preserved in aggregate")
    _expect_equal(String((merged_samples[0] as Dictionary).get("sample_id", "")), "demo-b", "aggregate samples use stable sample-id order")
    for raw_sample: Variant in merged_samples:
        var sample: Dictionary = raw_sample
        var provenance_value: Variant = sample.get("source_provenance", null)
        _expect(provenance_value is Dictionary, "every merged sample carries source provenance")
        if provenance_value is Dictionary:
            var provenance: Dictionary = provenance_value
            _expect(not String(provenance.get("dataset_id", "")).is_empty(), "provenance identifies source dataset")
            _expect(not String(provenance.get("dataset_checksum", "")).is_empty(), "provenance pins source dataset checksum")
    var report: Dictionary = first.get("report", {})
    _expect(bool(report.get("ok", false)), "single aggregate report evaluates")
    _expect_equal(report.get("source_sample_count"), 3, "aggregate report sees all merged samples")
    var source_manifest: Array = first.get("source_manifest", [])
    _expect_equal(source_manifest.size(), 2, "aggregate exposes deterministic source manifest")
    _expect_equal(String((source_manifest[0] as Dictionary).get("dataset_id", "")), "study-a", "source manifest is sorted deterministically")

func _test_cross_file_duplicate_rejected_and_sources_unchanged() -> void:
    var infrastructure: Phase12GStudyInfrastructure = InfrastructureScript.new()
    var dataset_a: Dictionary = _operator_dataset(
        "file-study-a",
        "file-source-a",
        [_sample("duplicate-sample", "planning_duration", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, {
            "contract_id":"C11",
            "duration_seconds":360.0,
            "ordinary_non_mastery":true,
            "rule_familiarity":true,
        })]
    )
    var dataset_b: Dictionary = _operator_dataset(
        "file-study-b",
        "file-source-b",
        [_sample("unique-b", "demo_identity", ReportServiceScript.COHORT_DEMO, {
            "response_text":"transit",
            "classification":"TRANSIT_BEHAVIOR",
        })]
    )
    var path_a: String = "user://phase12g_merge/source-a.json"
    var path_b: String = "user://phase12g_merge/source-b.json"
    _write_fixture(path_a, dataset_a)
    _write_fixture(path_b, dataset_b)
    var before_a: String = _read_text(path_a)
    var before_b: String = _read_text(path_b)
    var merged: Dictionary = infrastructure.merge_operator_files([path_b, path_a])
    _expect(bool(merged.get("ok", false)), "file-backed multi-source merge succeeds")
    _expect_equal(_read_text(path_a), before_a, "merge does not modify first raw source file")
    _expect_equal(_read_text(path_b), before_b, "merge does not modify second raw source file")

    var duplicate_b: Dictionary = dataset_b.duplicate(true)
    duplicate_b["samples"] = [_sample("duplicate-sample", "demo_identity", ReportServiceScript.COHORT_DEMO, {
        "response_text":"transit",
        "classification":"TRANSIT_BEHAVIOR",
    })]
    var rejected: Dictionary = infrastructure.merge_operator_datasets([dataset_a, duplicate_b], ["a", "b"])
    _expect(not bool(rejected.get("ok", true)), "duplicate sample IDs across separate studies fail closed")
    _expect_equal(rejected.get("error"), "duplicate_sample_id_across_sources:duplicate-sample", "cross-source duplicate has deterministic diagnostic")

    var wrong_policy: Dictionary = dataset_b.duplicate(true)
    var metadata: Dictionary = (wrong_policy.get("collection_metadata", {}) as Dictionary).duplicate(true)
    metadata["cohort_policy_version"] = "other-policy"
    wrong_policy["collection_metadata"] = metadata
    var policy_rejected: Dictionary = infrastructure.merge_operator_datasets([dataset_a, wrong_policy])
    _expect_equal(policy_rejected.get("error"), "cohort_policy_version_mismatch", "incompatible cohort policies cannot be silently combined")

func _test_session_manifest_contract_and_minimization() -> void:
    var infrastructure: Phase12GStudyInfrastructure = InfrastructureScript.new()
    var result: Dictionary = infrastructure.create_session_manifest(
        "session-001",
        "build-7eaa37f",
        "rules-r1",
        "content-v1",
        ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY,
        ["review_usability", "planning_duration", "planning_duration"],
        ["C11", "C09", "C11"],
        1800000000
    )
    _expect(bool(result.get("ok", false)), "pre-collection study manifest can be created")
    var manifest: Dictionary = result.get("manifest", {})
    _expect(bool(infrastructure.validate_session_manifest(manifest).get("ok", false)), "session manifest validates against its checksum")
    _expect_equal(manifest.get("declared_sample_types"), ["planning_duration", "review_usability"], "declared sample types normalize deterministically")
    _expect_equal(manifest.get("declared_contract_ids"), ["C09", "C11"], "declared contracts normalize deterministically")
    var minimization: Dictionary = manifest.get("data_minimization", {})
    _expect(not bool(minimization.get("collect_real_name", true)), "manifest forbids real-name collection")
    _expect(not bool(minimization.get("collect_email", true)), "manifest forbids email collection")
    _expect(not bool(minimization.get("collect_device_serial", true)), "manifest forbids device-serial collection")
    var written: Dictionary = infrastructure.write_session_manifest(manifest, "user://phase12g_manifest/session-001.json")
    _expect(bool(written.get("ok", false)), "validated session manifest exports before collection")
    _expect(FileAccess.file_exists("user://phase12g_manifest/session-001.json"), "session manifest export is durable")

    var tampered: Dictionary = manifest.duplicate(true)
    tampered["content_version"] = "different-content"
    var tamper_result: Dictionary = infrastructure.validate_session_manifest(tampered)
    _expect_equal(tamper_result.get("error"), "session_manifest_checksum_mismatch", "post-creation build/content tampering is detected")

    var invalid_cohort: Dictionary = infrastructure.create_session_manifest(
        "session-bad", "build", "rules", "content", "UNDECLARED_COHORT",
        ["planning_duration"], [], 1800000000
    )
    _expect_equal(invalid_cohort.get("error"), "invalid_cohort", "unknown study cohort fails closed")
    var invalid_type: Dictionary = infrastructure.create_session_manifest(
        "session-bad-type", "build", "rules", "content", ReportServiceScript.COHORT_DEMO,
        ["invented_metric"], [], 1800000000
    )
    _expect(String(invalid_type.get("error", "")).begins_with("unknown_sample_type:"), "manifest cannot invent empirical metric kinds")

func _test_certified_bronze_adapter_fail_closed() -> void:
    var infrastructure: Phase12GStudyInfrastructure = InfrastructureScript.new()
    var external_export: Dictionary = {
        "format_version": InfrastructureScript.BRONZE_EXPORT_VERSION,
        "export_metadata": {
            "corpus_id":"solver-corpus-001",
            "solver_version":"solver-4.2",
            "content_version":"content-v1",
            "authority_id":"trusted-solver-lab",
            "certification_status":InfrastructureScript.CERTIFICATION_STATUS,
            "checksum_method":InfrastructureScript.BRONZE_CHECKSUM_METHOD,
            "authoritative_corpus":true,
        },
        "solutions":[
            {
                "solution_id":"bronze-001",
                "contract_id":"C09",
                "chapter":2,
                "campaign_order":9,
                "normalized_role_to_zone":"PROTECTOR@A|SOOTHER@B",
                "high_isolation_status":"INFERIOR",
                "certified_bronze":true,
                "primary_family":true,
                "isolation_ratio":0.35,
                "beneficial_relation_count":2,
            }
        ],
    }
    var metadata: Dictionary = (external_export["export_metadata"] as Dictionary).duplicate(true)
    metadata["export_checksum"] = infrastructure.bronze_export_checksum(external_export)
    external_export["export_metadata"] = metadata

    var ingested: Dictionary = infrastructure.ingest_certified_bronze_export(external_export, ["trusted-solver-lab"])
    _expect(bool(ingested.get("ok", false)), "trusted checksummed certified Bronze export is accepted")
    var geometry_dataset: Dictionary = ingested.get("geometry_dataset", {})
    var corpus_metadata: Dictionary = geometry_dataset.get("corpus_metadata", {})
    _expect_equal(corpus_metadata.get("certification_authority"), "trusted-solver-lab", "adapter preserves certification authority")
    _expect_equal(corpus_metadata.get("source_export_checksum"), metadata.get("export_checksum"), "adapter preserves verified source checksum")
    _expect_equal((geometry_dataset.get("solutions", []) as Array).size(), 1, "adapter passes certified solutions to geometry schema")
    var geometry_report: Dictionary = ingested.get("geometry_report", {})
    _expect_equal(geometry_report.get("authoritative_corpus"), true, "trusted adapter output is authoritative to geometry evaluator")
    _expect(geometry_report.get("overall_status") != "PASS", "single synthetic solution cannot accidentally close full geometry obligations")

    var tampered: Dictionary = external_export.duplicate(true)
    var tampered_solutions: Array = (tampered.get("solutions", []) as Array).duplicate(true)
    var changed_solution: Dictionary = (tampered_solutions[0] as Dictionary).duplicate(true)
    changed_solution["isolation_ratio"] = 0.99
    tampered_solutions[0] = changed_solution
    tampered["solutions"] = tampered_solutions
    var checksum_rejected: Dictionary = infrastructure.ingest_certified_bronze_export(tampered, ["trusted-solver-lab"])
    _expect_equal(checksum_rejected.get("error"), "bronze_export_checksum_mismatch", "tampered solver export fails checksum verification")

    var untrusted: Dictionary = infrastructure.ingest_certified_bronze_export(external_export, ["different-authority"])
    _expect(String(untrusted.get("error", "")).begins_with("untrusted_certification_authority:"), "unknown certification authority is rejected")

    var non_authoritative: Dictionary = external_export.duplicate(true)
    var non_authoritative_metadata: Dictionary = (non_authoritative.get("export_metadata", {}) as Dictionary).duplicate(true)
    non_authoritative_metadata["authoritative_corpus"] = false
    non_authoritative_metadata.erase("export_checksum")
    non_authoritative["export_metadata"] = non_authoritative_metadata
    non_authoritative_metadata["export_checksum"] = infrastructure.bronze_export_checksum(non_authoritative)
    non_authoritative["export_metadata"] = non_authoritative_metadata
    var authority_rejected: Dictionary = infrastructure.ingest_certified_bronze_export(non_authoritative, ["trusted-solver-lab"])
    _expect_equal(authority_rejected.get("error"), "bronze_export_not_authoritative", "non-authoritative external corpus cannot enter production geometry path")

    var unversioned: Dictionary = external_export.duplicate(true)
    unversioned.erase("format_version")
    var version_rejected: Dictionary = infrastructure.ingest_certified_bronze_export(unversioned, ["trusted-solver-lab"])
    _expect_equal(version_rejected.get("error"), "unsupported_bronze_export_version", "unversioned solver export fails closed")

func _operator_dataset(dataset_id: String, source_id: String, samples: Array) -> Dictionary:
    return {
        "schema_version":"phase12g-evidence-v1",
        "dataset_id":dataset_id,
        "collection_metadata":{
            "metadata_version":ReportServiceScript.COLLECTION_METADATA_VERSION,
            "source_id":source_id,
            "collection_owner":"study-operator",
            "cohort_policy_version":"phase12g-cohort-policy-v1",
        },
        "samples":samples,
    }

func _sample(id: String, type: String, cohort: String, fields: Dictionary) -> Dictionary:
    var sample: Dictionary = {
        "sample_id":id,
        "sample_type":type,
        "tester_id":"tester-pseudonym",
        "captured_at_unix":1800000000,
        "cohort":cohort,
    }
    sample.merge(fields, true)
    return sample

func _write_fixture(path: String, payload: Dictionary) -> void:
    var absolute_path: String = ProjectSettings.globalize_path(path)
    var directory: String = absolute_path.get_base_dir()
    if not directory.is_empty():
        DirAccess.make_dir_recursive_absolute(directory)
    var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
    _expect(file != null, "fixture output opens")
    if file != null:
        file.store_string(JSON.stringify(payload, "  ", true, true))
        file.close()

func _read_text(path: String) -> String:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    return file.get_as_text()

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
        print("phase12g_study_infrastructure_test_runner: PASS")
        quit(0)
    else:
        push_error("phase12g_study_infrastructure_test_runner: %d failure(s)" % failures)
        quit(1)
