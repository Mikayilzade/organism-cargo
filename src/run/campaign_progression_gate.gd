class_name CampaignProgressionGate
extends RefCounted

var _definitions_by_id: Dictionary = {}
var _ordered_ids: Array[String] = []

func configure(campaign_graph: Dictionary) -> Dictionary:
	_definitions_by_id.clear()
	_ordered_ids.clear()
	var payload_value: Variant = campaign_graph.get("payload", campaign_graph)
	if not payload_value is Dictionary:
		return _failure("invalid_campaign_graph")
	var payload: Dictionary = payload_value
	var definitions_value: Variant = payload.get("definitions", [])
	if not definitions_value is Array:
		return _failure("missing_campaign_definitions")
	var definitions: Array = definitions_value
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			return _failure("invalid_campaign_definition")
		var definition: Dictionary = raw_definition
		var contract_id: String = String(definition.get("id", "")).strip_edges()
		if contract_id.is_empty() or _definitions_by_id.has(contract_id):
			return _failure("invalid_campaign_contract_id:%s" % contract_id)
		var prerequisites_value: Variant = definition.get("prerequisites", [])
		if not prerequisites_value is Array:
			return _failure("invalid_campaign_prerequisites:%s" % contract_id)
		var prerequisites: Array = prerequisites_value
		var normalized_prerequisites: Array[String] = []
		var seen_prerequisites: Dictionary = {}
		for raw_prerequisite: Variant in prerequisites:
			var prerequisite_id: String = String(raw_prerequisite).strip_edges()
			if prerequisite_id.is_empty() or prerequisite_id == contract_id or seen_prerequisites.has(prerequisite_id):
				return _failure("invalid_campaign_prerequisite:%s" % contract_id)
			seen_prerequisites[prerequisite_id] = true
			normalized_prerequisites.append(prerequisite_id)
		var normalized: Dictionary = definition.duplicate(true)
		normalized["prerequisites"] = normalized_prerequisites
		_definitions_by_id[contract_id] = normalized
		_ordered_ids.append(contract_id)
	for contract_id: String in _ordered_ids:
		var definition: Dictionary = _definitions_by_id[contract_id]
		var prerequisites: Array = definition["prerequisites"]
		for raw_prerequisite: Variant in prerequisites:
			var prerequisite_id: String = String(raw_prerequisite)
			if not _definitions_by_id.has(prerequisite_id):
				return _failure("unknown_campaign_prerequisite:%s:%s" % [contract_id, prerequisite_id])
	return {"ok": true, "error": "", "contract_count": _ordered_ids.size()}

func validate_profile(profile: Dictionary) -> Dictionary:
	if _definitions_by_id.is_empty():
		return _failure("campaign_gate_not_configured")
	var bronze_result: Dictionary = _bronze_set(profile)
	if not bool(bronze_result.get("ok", false)):
		return bronze_result
	var bronze: Dictionary = bronze_result["bronze"]
	for raw_contract_id: Variant in bronze.keys():
		var contract_id: String = String(raw_contract_id)
		if not _definitions_by_id.has(contract_id):
			return _failure("unknown_bronze_contract:%s" % contract_id)
		var definition: Dictionary = _definitions_by_id[contract_id]
		var prerequisites: Array = definition.get("prerequisites", [])
		for raw_prerequisite: Variant in prerequisites:
			var prerequisite_id: String = String(raw_prerequisite)
			if not bronze.has(prerequisite_id):
				return _failure("impossible_bronze_profile:%s_missing_%s" % [contract_id, prerequisite_id])
	return {"ok": true, "error": "", "bronze": bronze}

func can_select_contract(contract_id: String, profile: Dictionary) -> Dictionary:
	var normalized_id: String = contract_id.strip_edges()
	if normalized_id.is_empty() or not _definitions_by_id.has(normalized_id):
		return _failure("unknown_campaign_contract:%s" % normalized_id)
	var profile_result: Dictionary = validate_profile(profile)
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var bronze: Dictionary = profile_result["bronze"]
	var definition: Dictionary = _definitions_by_id[normalized_id]
	var prerequisites: Array = definition.get("prerequisites", [])
	for raw_prerequisite: Variant in prerequisites:
		var prerequisite_id: String = String(raw_prerequisite)
		if not bronze.has(prerequisite_id):
			return _failure("campaign_contract_locked:%s_missing_%s" % [normalized_id, prerequisite_id])
	return {"ok": true, "error": "", "contract_id": normalized_id, "already_bronze": bronze.has(normalized_id)}

func challenge_mode_unlocked(profile: Dictionary) -> Dictionary:
	var profile_result: Dictionary = validate_profile(profile)
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var bronze: Dictionary = profile_result["bronze"]
	return {"ok": true, "error": "", "unlocked": bronze.has("C16")}

func campaign_complete_available(profile: Dictionary) -> Dictionary:
	var profile_result: Dictionary = validate_profile(profile)
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var bronze: Dictionary = profile_result["bronze"]
	return {"ok": true, "error": "", "available": bronze.has("C48")}

func available_contract_ids(profile: Dictionary) -> Dictionary:
	var profile_result: Dictionary = validate_profile(profile)
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var available: Array[String] = []
	for contract_id: String in _ordered_ids:
		var selection: Dictionary = can_select_contract(contract_id, profile)
		if bool(selection.get("ok", false)):
			available.append(contract_id)
	return {"ok": true, "error": "", "contract_ids": available}

func _bronze_set(profile: Dictionary) -> Dictionary:
	var bronze_value: Variant = profile.get("cleared_bronze_contract_ids", [])
	if not (bronze_value is Array or bronze_value is PackedStringArray):
		return _failure("invalid_bronze_contract_ids")
	var bronze: Dictionary = {}
	for raw_contract_id: Variant in bronze_value:
		var contract_id: String = String(raw_contract_id).strip_edges()
		if contract_id.is_empty() or bronze.has(contract_id):
			return _failure("invalid_bronze_contract_ids")
		bronze[contract_id] = true
	return {"ok": true, "error": "", "bronze": bronze}

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
