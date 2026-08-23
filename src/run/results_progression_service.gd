class_name ResultsProgressionService
extends RefCounted

const MEDAL_ORDER := {"BRONZE": 0, "SILVER": 1, "GOLD": 2}

var _save_store: AtomicSaveStore

func _init(p_save_store: AtomicSaveStore) -> void:
	_save_store = p_save_store

func apply_authoritative_result(
		record: Dictionary,
		authoritative_result: Dictionary,
		medal: String = "BRONZE",
		documented_fact_ids: Array = []
) -> Dictionary:
	var validation: Dictionary = _validate_application(record, authoritative_result, medal, documented_fact_ids)
	if not bool(validation.get("ok", false)):
		return validation
	var delivery_value: Variant = authoritative_result.get("delivery_result", null)
	if not delivery_value is Dictionary:
		return _failure("missing_delivery_result")
	var delivery_result: Dictionary = delivery_value
	if not bool(delivery_result.get("success", false)):
		return {
			"ok": true,
			"error": "",
			"applied": false,
			"duplicate": false,
			"completion_id": "",
			"profile_state": {},
		}

	var completion_id: String = _completion_id(record, String(authoritative_result["completion_checksum"]))
	var profile_result: Dictionary = _load_or_create_profile(String(record["profile_uuid"]))
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var profile: Dictionary = profile_result["profile"]
	var applied_ids: PackedStringArray = _normalized_strings(profile.get("applied_completion_ids", []))
	var duplicate: bool = completion_id in applied_ids
	if not duplicate:
		var bronze: PackedStringArray = _normalized_strings(profile.get("cleared_bronze_contract_ids", []))
		var contract_id: String = String(record["contract_id"])
		if not contract_id in bronze:
			bronze.append(contract_id)
			bronze.sort()
		profile["cleared_bronze_contract_ids"] = Array(bronze)

		var best_value: Variant = profile.get("best_medal_by_contract", {})
		if not best_value is Dictionary:
			return _failure("invalid_profile_best_medals")
		var best_medals: Dictionary = (best_value as Dictionary).duplicate(true)
		var existing_medal: String = String(best_medals.get(contract_id, ""))
		if existing_medal.is_empty() or int(MEDAL_ORDER.get(medal, -1)) > int(MEDAL_ORDER.get(existing_medal, -1)):
			best_medals[contract_id] = medal
		profile["best_medal_by_contract"] = best_medals

		var facts: PackedStringArray = _normalized_strings(profile.get("documented_fact_ids", []))
		var validated_facts_value: Variant = validation.get("documented_fact_ids", PackedStringArray())
		if not (validated_facts_value is Array or validated_facts_value is PackedStringArray):
			return _failure("invalid_validated_documented_fact_ids")
		for raw_fact: Variant in validated_facts_value:
			var fact_id: String = String(raw_fact)
			if not fact_id in facts:
				facts.append(fact_id)
		facts.sort()
		profile["documented_fact_ids"] = Array(facts)

		applied_ids.append(completion_id)
		applied_ids.sort()
		profile["applied_completion_ids"] = Array(applied_ids)
		var profile_write: Dictionary = _save_store.write(&"profile", profile)
		if not bool(profile_write.get("ok", false)):
			return _failure("profile_apply_failed:%s" % String(profile_write.get("error", "unknown")))

	var session_repair: Dictionary = _mark_session_applied(record, completion_id, String(authoritative_result["completion_checksum"]))
	if not bool(session_repair.get("ok", false)):
		return {
			"ok": false,
			"error": String(session_repair.get("error", "session_apply_failed")),
			"applied": not duplicate,
			"duplicate": duplicate,
			"completion_id": completion_id,
			"profile_state": profile.duplicate(true),
			"profile_durable": true,
		}
	return {
		"ok": true,
		"error": "",
		"applied": not duplicate,
		"duplicate": duplicate,
		"completion_id": completion_id,
		"profile_state": profile.duplicate(true),
		"profile_durable": true,
	}

func _validate_application(record: Dictionary, result: Dictionary, medal: String, fact_ids: Array) -> Dictionary:
	for field: String in ["profile_uuid", "run_id", "contract_id", "rules_version", "content_version"]:
		if String(record.get(field, "")).strip_edges().is_empty():
			return _failure("missing_completion_record_field:%s" % field)
	if not result.get("delivery_result", null) is Dictionary:
		return _failure("missing_delivery_result")
	if String(result.get("completion_checksum", "")).is_empty():
		return _failure("missing_completion_checksum")
	if medal not in MEDAL_ORDER:
		return _failure("invalid_medal:%s" % medal)
	var normalized_facts: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_fact: Variant in fact_ids:
		var fact_id: String = String(raw_fact).strip_edges()
		if fact_id.is_empty() or seen.has(fact_id):
			return _failure("invalid_documented_fact_ids")
		seen[fact_id] = true
		normalized_facts.append(fact_id)
	normalized_facts.sort()
	return {"ok": true, "error": "", "documented_fact_ids": normalized_facts}

func _completion_id(record: Dictionary, result_checksum: String) -> String:
	var parts: PackedStringArray = PackedStringArray([
		String(record["profile_uuid"]),
		String(record["run_id"]),
		String(record["contract_id"]),
		result_checksum,
		String(record["rules_version"]),
		String(record["content_version"]),
	])
	return "\u001f".join(parts).sha256_text()

func _load_or_create_profile(profile_uuid: String) -> Dictionary:
	var loaded: Dictionary = _save_store.load(&"profile")
	if bool(loaded.get("ok", false)):
		var envelope: SaveEnvelope = loaded["envelope"]
		var profile: Dictionary = envelope.payload.duplicate(true)
		if String(profile.get("profile_uuid", "")) != profile_uuid:
			return _failure("profile_uuid_mismatch")
		return {"ok": true, "error": "", "profile": profile}
	return {
		"ok": true,
		"error": "",
		"profile": {
			"profile_uuid": profile_uuid,
			"cleared_bronze_contract_ids": [],
			"best_medal_by_contract": {},
			"documented_fact_ids": [],
			"applied_completion_ids": [],
		},
	}

func _mark_session_applied(record: Dictionary, completion_id: String, final_checksum: String) -> Dictionary:
	var loaded: Dictionary = _save_store.load(&"session")
	if not bool(loaded.get("ok", false)):
		return _failure("session_load_failed:%s" % String(loaded.get("error", "unknown")))
	var envelope: SaveEnvelope = loaded["envelope"]
	var payload: Dictionary = envelope.payload.duplicate(true)
	var persisted_value: Variant = payload.get("committed_run", null)
	if not persisted_value is Dictionary:
		return _failure("missing_committed_run")
	var persisted: Dictionary = persisted_value
	if String(persisted.get("run_id", "")) != String(record["run_id"]):
		return _failure("session_run_id_mismatch")
	if String(persisted.get("profile_uuid", "")) != String(record["profile_uuid"]):
		return _failure("session_profile_uuid_mismatch")
	persisted["completion_id"] = completion_id
	persisted["final_result_checksum"] = final_checksum
	persisted["lifecycle_state"] = "COMPLETION_APPLIED"
	payload["committed_run"] = persisted
	var write_result: Dictionary = _save_store.write(&"session", payload)
	if not bool(write_result.get("ok", false)):
		return _failure("session_completion_persist_failed:%s" % String(write_result.get("error", "unknown")))
	return {"ok": true, "error": ""}

func _normalized_strings(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not (value is Array or value is PackedStringArray):
		return result
	var seen: Dictionary = {}
	for raw: Variant in value:
		var text: String = String(raw)
		if text.is_empty() or seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	result.sort()
	return result

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error, "applied": false, "duplicate": false, "completion_id": "", "profile_state": {}}
