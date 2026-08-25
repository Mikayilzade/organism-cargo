extends SceneTree

const PackageServiceScript := preload("res://src/validation/phase12g_study_package_service.gd")
const InfrastructureScript := preload("res://src/validation/phase12g_study_infrastructure.gd")
const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")

var failures: int = 0

func _init() -> void:
	_test_binding_merge_and_build_identity()
	_test_binding_tamper_and_manifest_registry_fail_closed()
	_test_deterministic_audit_missing_evidence()
	_finish()

func _test_binding_merge_and_build_identity() -> void:
	var package: Phase12GStudyPackageService = PackageServiceScript.new()
	var infra: Phase12GStudyInfrastructure = InfrastructureScript.new()
	var manifest_a: Dictionary = _manifest(infra, "session-a", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, ["planning_duration", "failed_review_retry"])
	var manifest_b: Dictionary = _manifest(infra, "session-b", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, ["failed_review_retry"])
	var dataset_a: Dictionary = _dataset("dataset-a", [_sample("plan-a", "planning_duration", {"contract_id":"C10", "duration_seconds":420.0, "ordinary_non_mastery":true, "rule_familiarity":true})])
	var dataset_b: Dictionary = _dataset("dataset-b", [_sample("retry-b", "failed_review_retry", {"contract_id":"C10", "causal_explanation":"heat exposure", "intended_revision":"move away from heat", "blind_shuffle":false})])
	var bound_a: Dictionary = package.bind_dataset_to_session(dataset_a, manifest_a)
	var bound_b: Dictionary = package.bind_dataset_to_session(dataset_b, manifest_b)
	_expect(bool(bound_a.get("ok", false)), "first dataset binds to pre-collection session manifest")
	_expect(bool(bound_b.get("ok", false)), "second dataset binds to pre-collection session manifest")
	var registry: Dictionary = {String(manifest_a["manifest_checksum"]):manifest_a, String(manifest_b["manifest_checksum"]):manifest_b}
	var merged: Dictionary = package.merge_bound_datasets([bound_b["dataset"], bound_a["dataset"]], registry)
	_expect(bool(merged.get("ok", false)), "bound studies with identical build identity merge")
	var identity: Dictionary = merged.get("build_identity", {})
	_expect_equal(identity.get("prototype_build_id"), "build-203", "aggregate pins prototype build")
	_expect_equal(identity.get("rules_version"), "rules-r1", "aggregate pins rules version")
	_expect_equal(identity.get("content_version"), "content-v1", "aggregate pins content version")
	var aggregate: Dictionary = merged.get("dataset", {})
	var metadata: Dictionary = aggregate.get("collection_metadata", {})
	_expect_equal((metadata.get("session_manifest_checksums", []) as Array).size(), 2, "aggregate retains both session manifest checksums")

	var other_manifest_result: Dictionary = infra.create_session_manifest("session-other", "build-other", "rules-r1", "content-v1", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, ["failed_review_retry"], ["C10"], 1800000001)
	var other_manifest: Dictionary = other_manifest_result.get("manifest", {})
	var other_bound: Dictionary = package.bind_dataset_to_session(_dataset("dataset-other", [_sample("retry-other", "failed_review_retry", {"contract_id":"C10", "causal_explanation":"stress", "intended_revision":"change adjacency", "blind_shuffle":false})]), other_manifest)
	var incompatible_registry: Dictionary = registry.duplicate(true)
	incompatible_registry[String(other_manifest.get("manifest_checksum", ""))] = other_manifest
	var rejected: Dictionary = package.merge_bound_datasets([bound_a["dataset"], other_bound["dataset"]], incompatible_registry)
	_expect_equal(rejected.get("error"), "incompatible_build_identity", "different pre-collection builds cannot be silently merged")

func _test_binding_tamper_and_manifest_registry_fail_closed() -> void:
	var package: Phase12GStudyPackageService = PackageServiceScript.new()
	var infra: Phase12GStudyInfrastructure = InfrastructureScript.new()
	var manifest: Dictionary = _manifest(infra, "session-tamper", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, ["planning_duration"])
	var bound_result: Dictionary = package.bind_dataset_to_session(_dataset("dataset-tamper", [_sample("plan-t", "planning_duration", {"contract_id":"C10", "duration_seconds":300.0, "ordinary_non_mastery":true, "rule_familiarity":true})]), manifest)
	var bound: Dictionary = bound_result.get("dataset", {})
	var registry: Dictionary = {String(manifest["manifest_checksum"]):manifest}
	_expect(bool(package.validate_bound_dataset(bound, registry).get("ok", false)), "valid bound dataset resolves manifest checksum")
	var missing_registry: Dictionary = package.validate_bound_dataset(bound, {})
	_expect(String(missing_registry.get("error", "")).begins_with("unknown_session_manifest:"), "missing manifest registry entry fails closed")
	var tampered: Dictionary = bound.duplicate(true)
	var metadata: Dictionary = (tampered.get("collection_metadata", {}) as Dictionary).duplicate(true)
	var binding: Dictionary = (metadata.get("session_binding", {}) as Dictionary).duplicate(true)
	binding["content_version"] = "content-tampered"
	metadata["session_binding"] = binding
	tampered["collection_metadata"] = metadata
	_expect_equal(package.validate_bound_dataset(tampered, registry).get("error"), "session_binding_content_version_mismatch", "binding identity tamper is detected")
	var wrong_cohort_dataset: Dictionary = _dataset("dataset-cohort", [_sample("demo-x", "demo_identity", {"response_text":"transit", "classification":"TRANSIT_BEHAVIOR"})])
	var wrong_bind: Dictionary = package.bind_dataset_to_session(wrong_cohort_dataset, manifest)
	_expect_equal(wrong_bind.get("error"), "dataset:sample_0:demo_identity_requires_demo_cohort", "dataset cohort/type policy is validated before binding")

func _test_deterministic_audit_missing_evidence() -> void:
	var package: Phase12GStudyPackageService = PackageServiceScript.new()
	var infra: Phase12GStudyInfrastructure = InfrastructureScript.new()
	var manifest: Dictionary = _manifest(infra, "session-audit", ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY, ["planning_duration"])
	var bound_result: Dictionary = package.bind_dataset_to_session(_dataset("dataset-audit", [_sample("plan-audit", "planning_duration", {"contract_id":"C10", "duration_seconds":350.0, "ordinary_non_mastery":true, "rule_familiarity":true})]), manifest)
	var registry: Dictionary = {String(manifest["manifest_checksum"]):manifest}
	var first: Dictionary = package.audit_package([bound_result["dataset"]], registry)
	var second: Dictionary = package.audit_package([bound_result["dataset"]], registry)
	_expect_equal(first.get("audit_checksum"), second.get("audit_checksum"), "study-package audit is deterministic")
	_expect(bool(first.get("eligible_for_gate_evaluation", false)), "valid bound evidence is eligible for gate evaluation")
	_expect(not bool(first.get("human_evidence_complete", true)), "partial study package does not claim human evidence complete")
	var missing: Array = first.get("missing_evidence_classes", [])
	_expect(missing.has("demo_identity"), "audit explicitly reports missing demo identity evidence")
	_expect(missing.has("species_decision"), "audit explicitly reports missing species distinctness evidence")
	_expect_equal(first.get("certified_bronze_state"), "NOT_SUPPLIED", "missing certified Bronze corpus is explicit and never PASS")

func _manifest(infra: Phase12GStudyInfrastructure, session_id: String, cohort: String, types: Array) -> Dictionary:
	var result: Dictionary = infra.create_session_manifest(session_id, "build-203", "rules-r1", "content-v1", cohort, types, ["C10"], 1800000000)
	_expect(bool(result.get("ok", false)), "fixture manifest is valid")
	return result.get("manifest", {})

func _dataset(dataset_id: String, samples: Array) -> Dictionary:
	return {"schema_version":"phase12g-evidence-v1", "dataset_id":dataset_id, "collection_metadata":{"metadata_version":ReportServiceScript.COLLECTION_METADATA_VERSION, "source_id":"operator-source", "collection_owner":"study-operator", "cohort_policy_version":"phase12g-cohort-policy-v1"}, "samples":samples}

func _sample(sample_id: String, sample_type: String, fields: Dictionary) -> Dictionary:
	var sample: Dictionary = {"sample_id":sample_id, "sample_type":sample_type, "tester_id":"pseudo-1", "captured_at_unix":1800000000, "cohort":ReportServiceScript.COHORT_POST_ONBOARDING_ORDINARY}
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

func _finish() -> void:
	if failures == 0:
		print("phase12g_study_package_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12g_study_package_test_runner: %d failure(s)" % failures)
		quit(1)
