class_name PersistenceReconciliationService
extends RefCounted

const MEDAL_ORDER := {"BRONZE": 0, "SILVER": 1, "GOLD": 2}
const LIFECYCLE_ORDER := {"COMMITTED": 0, "SIMULATED": 1, "REVIEWABLE": 2, "COMPLETION_APPLIED": 3}

func merge_profiles(left: Dictionary, right: Dictionary) -> Dictionary:
	var left_uuid: String = String(left.get("profile_uuid", "")).strip_edges()
	var right_uuid: String = String(right.get("profile_uuid", "")).strip_edges()
	if left_uuid.is_empty() or right_uuid.is_empty():
		return _failure("missing_profile_uuid")
	if left_uuid != right_uuid:
		return {
			"ok": false,
			"error": "profile_uuid_conflict",
			"resolution": "keep_separate",
			"profiles": [left.duplicate(true), right.duplicate(true)],
		}
	var left_schema: int = int(left.get("save_format_version", 1))
	var right_schema: int = int(right.get("save_format_version", 1))
	if left_schema != right_schema:
		return _failure("profile_schema_conflict")

	var merged: Dictionary = left.duplicate(true)
	merged["profile_uuid"] = left_uuid
	merged["save_format_version"] = left_schema
	for field: String in ["cleared_bronze_contract_ids", "documented_fact_ids", "applied_completion_ids", "permanent_unlock_flags", "applied_demo_import_ids"]:
		merged[field] = Array(_union_strings(left.get(field, []), right.get(field, [])))

	var medals_result: Dictionary = _merge_medals(left.get("best_medal_by_contract", {}), right.get("best_medal_by_contract", {}))
	if not bool(medals_result.get("ok", false)):
		return medals_result
	merged["best_medal_by_contract"] = medals_result["medals"]
	return {
		"ok": true,
		"error": "",
		"resolution": "merged_monotonic",
		"profile": merged,
		"challenge_mode_unlocked": "C16" in _normalized_strings(merged.get("cleared_bronze_contract_ids", [])),
	}

func resolve_active_session_conflict(left: Dictionary, right: Dictionary) -> Dictionary:
	var left_profile: String = String(left.get("profile_uuid", ""))
	var right_profile: String = String(right.get("profile_uuid", ""))
	if left_profile.is_empty() or right_profile.is_empty():
		return _failure("missing_session_profile_uuid")
	if left_profile != right_profile:
		return _retain_both("different_profile_uuid", left, right)
	var left_run: String = String(left.get("run_id", ""))
	var right_run: String = String(right.get("run_id", ""))
	var left_checksum: String = String(left.get("committed_input_checksum", ""))
	var right_checksum: String = String(right.get("committed_input_checksum", ""))
	if left_run.is_empty() or right_run.is_empty() or left_checksum.is_empty() or right_checksum.is_empty():
		return _retain_both("incomplete_session_identity", left, right)
	if left_run != right_run or left_checksum != right_checksum:
		return _retain_both("divergent_session_identity", left, right)

	var left_state: String = String(left.get("lifecycle_state", ""))
	var right_state: String = String(right.get("lifecycle_state", ""))
	if not LIFECYCLE_ORDER.has(left_state) or not LIFECYCLE_ORDER.has(right_state):
		return _retain_both("non_orderable_lifecycle", left, right)
	var left_rank: int = int(LIFECYCLE_ORDER[left_state])
	var right_rank: int = int(LIFECYCLE_ORDER[right_state])
	if left_rank == right_rank:
		return {
			"ok": true,
			"error": "",
			"resolution": "same_lineage_equal_lifecycle",
			"selected": left.duplicate(true),
			"retained": [left.duplicate(true), right.duplicate(true)],
		}
	return {
		"ok": true,
		"error": "",
		"resolution": "same_lineage_later_lifecycle",
		"selected": (left if left_rank > right_rank else right).duplicate(true),
		"retained": [left.duplicate(true), right.duplicate(true)],
	}

func migrate_profile_in_store(store: AtomicSaveStore, target_version: int, migration_steps: Dictionary) -> Dictionary:
	var loaded: Dictionary = store.load(&"profile")
	if not bool(loaded.get("ok", false)):
		return _failure("migration_source_load_failed")
	var envelope: SaveEnvelope = loaded["envelope"]
	var source: Dictionary = envelope.payload.duplicate(true)
	var source_version: int = int(source.get("save_format_version", 1))
	if target_version < source_version:
		return _failure("migration_downgrade_forbidden")
	if target_version == source_version:
		return {"ok": true, "error": "", "no_op": true, "profile": source, "source_recovery": source.duplicate(true)}

	# Create a validated same-payload generation first. AtomicSaveStore retains the pre-migration
	# source as .bak, so any failed in-memory step leaves a recoverable on-disk source generation.
	var preserve: Dictionary = store.write(&"profile", source)
	if not bool(preserve.get("ok", false)):
		return _failure("migration_source_preservation_failed")
	var working: Dictionary = source.duplicate(true)
	var version: int = source_version
	while version < target_version:
		var key: String = "%d->%d" % [version, version + 1]
		var step_value: Variant = migration_steps.get(key, null)
		if not step_value is Callable or not (step_value as Callable).is_valid():
			return _migration_failure("missing_migration_step:%s" % key, source)
		var step_result_value: Variant = (step_value as Callable).call(working.duplicate(true))
		if not step_result_value is Dictionary:
			return _migration_failure("invalid_migration_result:%s" % key, source)
		var step_result: Dictionary = step_result_value
		if not bool(step_result.get("ok", false)):
			return _migration_failure("migration_step_failed:%s:%s" % [key, String(step_result.get("error", "unknown"))], source)
		var migrated_value: Variant = step_result.get("profile", null)
		if not migrated_value is Dictionary:
			return _migration_failure("migration_step_missing_profile:%s" % key, source)
		var migrated: Dictionary = migrated_value
		migrated["save_format_version"] = version + 1
		if String(migrated.get("profile_uuid", "")) != String(source.get("profile_uuid", "")):
			return _migration_failure("migration_profile_uuid_changed:%s" % key, source)
		if not _permanent_progress_is_superset(migrated, working):
			return _migration_failure("migration_progress_rollback:%s" % key, source)
		working = migrated.duplicate(true)
		version += 1

	var install: Dictionary = store.write(&"profile", working)
	if not bool(install.get("ok", false)):
		return _migration_failure("migration_target_install_failed", source)
	return {"ok": true, "error": "", "no_op": false, "profile": working, "source_recovery": source.duplicate(true)}

func validate_legacy_challenge_identity(identity: Dictionary, supported_packages: Array) -> Dictionary:
	for field: String in ["template_id", "generator_version", "rules_version", "content_version"]:
		if String(identity.get(field, "")).strip_edges().is_empty():
			return {"ok": false, "error": "malformed_challenge_identity:%s" % field, "construct_gameplay": false}
	if not identity.has("seed"):
		return {"ok": false, "error": "malformed_challenge_identity:seed", "construct_gameplay": false}
	for raw_package: Variant in supported_packages:
		if not raw_package is Dictionary:
			continue
		var package: Dictionary = raw_package
		if String(package.get("generator_version", "")) == String(identity["generator_version"]) \
			and String(package.get("rules_version", "")) == String(identity["rules_version"]) \
			and String(package.get("content_version", "")) == String(identity["content_version"]):
			return {"ok": true, "error": "", "construct_gameplay": true, "identity": identity.duplicate(true)}
	return {"ok": false, "error": "legacy_challenge_version", "construct_gameplay": false, "identity": identity.duplicate(true)}

func apply_demo_import(target_profile: Dictionary, demo_profile: Dictionary, mapping_document: Dictionary, import_schema_version: String) -> Dictionary:
	var target_uuid: String = String(target_profile.get("profile_uuid", "")).strip_edges()
	var demo_uuid: String = String(demo_profile.get("profile_uuid", "")).strip_edges()
	var demo_revision: String = String(demo_profile.get("demo_profile_revision", "")).strip_edges()
	if target_uuid.is_empty() or demo_uuid.is_empty() or demo_revision.is_empty() or import_schema_version.strip_edges().is_empty():
		return _failure("invalid_demo_import_identity")
	var payload_value: Variant = mapping_document.get("payload", {})
	if not payload_value is Dictionary:
		return _failure("invalid_demo_mapping_payload")
	var payload: Dictionary = payload_value
	var transfer_value: Variant = payload.get("transfer", {})
	if not transfer_value is Dictionary:
		return _failure("invalid_demo_transfer_mapping")
	var transfer: Dictionary = transfer_value
	if not bool(transfer.get("monotonic", false)) or not bool(transfer.get("idempotent", false)) or bool(transfer.get("mechanical_power", true)):
		return _failure("unsafe_demo_transfer_contract")
	var mapping_value: Variant = transfer.get("bronze_mapping", {})
	if not mapping_value is Dictionary:
		return _failure("invalid_demo_bronze_mapping")
	var bronze_mapping: Dictionary = mapping_value

	var import_id: String = "\u001f".join(PackedStringArray([target_uuid, demo_uuid, demo_revision, import_schema_version])).sha256_text()
	var existing_imports: PackedStringArray = _normalized_strings(target_profile.get("applied_demo_import_ids", []))
	if import_id in existing_imports:
		return {
			"ok": true, "error": "", "duplicate": true, "import_id": import_id,
			"profile": target_profile.duplicate(true),
			"challenge_mode_unlocked": "C16" in _normalized_strings(target_profile.get("cleared_bronze_contract_ids", [])),
		}

	var merged: Dictionary = target_profile.duplicate(true)
	var target_bronze: PackedStringArray = _normalized_strings(merged.get("cleared_bronze_contract_ids", []))
	var demo_bronze: PackedStringArray = _normalized_strings(demo_profile.get("cleared_bronze_contract_ids", []))
	for demo_contract: String in demo_bronze:
		if not bronze_mapping.has(demo_contract):
			continue
		var campaign_contract: String = String(bronze_mapping[demo_contract])
		if not _valid_demo_bronze_mapping(demo_contract, campaign_contract):
			return _failure("invalid_demo_bronze_boundary:%s:%s" % [demo_contract, campaign_contract])
		if not campaign_contract in target_bronze:
			target_bronze.append(campaign_contract)
	target_bronze.sort()
	merged["cleared_bronze_contract_ids"] = Array(target_bronze)
	merged["documented_fact_ids"] = Array(_union_strings(merged.get("documented_fact_ids", []), demo_profile.get("documented_fact_ids", [])))
	if bool(transfer.get("settings", false)) and demo_profile.get("settings", null) is Dictionary:
		merged["settings"] = (demo_profile["settings"] as Dictionary).duplicate(true)
	existing_imports.append(import_id)
	existing_imports.sort()
	merged["applied_demo_import_ids"] = Array(existing_imports)
	# Deliberately do not copy demo supports, inventory, unlock counters, or any other mechanical-power field.
	return {
		"ok": true,
		"error": "",
		"duplicate": false,
		"import_id": import_id,
		"profile": merged,
		"challenge_mode_unlocked": "C16" in target_bronze,
	}

func _merge_medals(left_value: Variant, right_value: Variant) -> Dictionary:
	if not left_value is Dictionary or not right_value is Dictionary:
		return _failure("invalid_profile_best_medals")
	var merged: Dictionary = {}
	for source_value: Variant in [left_value, right_value]:
		var source: Dictionary = source_value
		for raw_contract: Variant in source.keys():
			var contract: String = String(raw_contract)
			var medal: String = String(source[raw_contract])
			if not MEDAL_ORDER.has(medal):
				return _failure("invalid_profile_medal:%s:%s" % [contract, medal])
			var existing: String = String(merged.get(contract, ""))
			if existing.is_empty() or int(MEDAL_ORDER[medal]) > int(MEDAL_ORDER[existing]):
				merged[contract] = medal
	return {"ok": true, "error": "", "medals": merged}

func _permanent_progress_is_superset(candidate: Dictionary, baseline: Dictionary) -> bool:
	for field: String in ["cleared_bronze_contract_ids", "documented_fact_ids", "applied_completion_ids", "permanent_unlock_flags", "applied_demo_import_ids"]:
		var candidate_values: PackedStringArray = _normalized_strings(candidate.get(field, []))
		for value: String in _normalized_strings(baseline.get(field, [])):
			if not value in candidate_values:
				return false
	var medals_result: Dictionary = _merge_medals(baseline.get("best_medal_by_contract", {}), candidate.get("best_medal_by_contract", {}))
	if not bool(medals_result.get("ok", false)):
		return false
	var expected: Dictionary = medals_result["medals"]
	var candidate_medals: Dictionary = candidate.get("best_medal_by_contract", {}) if candidate.get("best_medal_by_contract", {}) is Dictionary else {}
	for contract: Variant in expected.keys():
		if String(candidate_medals.get(contract, "")) != String(expected[contract]):
			return false
	return true

func _valid_demo_bronze_mapping(demo_contract: String, campaign_contract: String) -> bool:
	if demo_contract.length() != 3 or campaign_contract.length() != 3:
		return false
	if not demo_contract.begins_with("D") or not campaign_contract.begins_with("C"):
		return false
	var demo_number: int = int(demo_contract.substr(1))
	var campaign_number: int = int(campaign_contract.substr(1))
	return demo_number >= 1 and demo_number <= 8 and campaign_number == demo_number

func _union_strings(left: Variant, right: Variant) -> PackedStringArray:
	var result: PackedStringArray = _normalized_strings(left)
	for value: String in _normalized_strings(right):
		if not value in result:
			result.append(value)
	result.sort()
	return result

func _normalized_strings(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not (value is Array or value is PackedStringArray):
		return result
	var seen: Dictionary = {}
	for raw: Variant in value:
		var text: String = String(raw).strip_edges()
		if text.is_empty() or seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	result.sort()
	return result

func _retain_both(reason: String, left: Dictionary, right: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"resolution": "retain_both_require_choice",
		"reason": reason,
		"retained": [left.duplicate(true), right.duplicate(true)],
	}

func _migration_failure(error: String, source: Dictionary) -> Dictionary:
	return {"ok": false, "error": error, "installed": false, "source_recovery": source.duplicate(true)}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
