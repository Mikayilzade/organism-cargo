class_name TransitReconstructionService
extends RefCounted

const DeliveryCompletionRunnerScript := preload("res://src/sim/delivery_completion_runner.gd")

var _save_store: AtomicSaveStore

func _init(p_save_store: AtomicSaveStore) -> void:
	_save_store = p_save_store

func resume_current(compatibility: Dictionary) -> Dictionary:
	var loaded: Dictionary = _save_store.load(&"session")
	if not bool(loaded.get("ok", false)):
		return _failure("session_load_failed:%s" % String(loaded.get("error", "unknown")))
	var envelope: SaveEnvelope = loaded["envelope"]
	var payload: Dictionary = envelope.payload.duplicate(true)
	var record_value: Variant = payload.get("committed_run", null)
	if not record_value is Dictionary:
		return _failure("missing_committed_run")
	var record: Dictionary = record_value
	var reconstructed: Dictionary = reconstruct_record(record, compatibility)
	if not bool(reconstructed.get("ok", false)):
		var recovery_class: String = String(reconstructed.get("recovery_class", ""))
		if recovery_class == "C":
			var mismatch_record: Dictionary = record.duplicate(true)
			mismatch_record["lifecycle_state"] = "RECONSTRUCTION_MISMATCH"
			var diagnostics_value: Variant = reconstructed.get("diagnostics", {})
			var diagnostics: Dictionary = diagnostics_value if diagnostics_value is Dictionary else {}
			mismatch_record["reconstruction_diagnostics"] = diagnostics.duplicate(true)
			payload["committed_run"] = mismatch_record
			var mismatch_write: Dictionary = _save_store.write(&"session", payload)
			if not bool(mismatch_write.get("ok", false)):
				return _failure("mismatch_persist_failed:%s" % String(mismatch_write.get("error", "unknown")))
		elif recovery_class == "D":
			var baseline_value: Variant = record.get("canonical_committed_input", {})
			var planning_baseline: Dictionary = {}
			if baseline_value is Dictionary:
				var baseline_dictionary: Dictionary = baseline_value
				planning_baseline = baseline_dictionary.duplicate(true)
			var invalidated_record: Dictionary = record.duplicate(true)
			invalidated_record["lifecycle_state"] = "ABANDONED/INVALIDATED"
			invalidated_record["compatibility_recovery_reason"] = String(reconstructed.get("error", "missing_compatibility_package"))
			invalidated_record["planning_baseline"] = planning_baseline.duplicate(true)
			invalidated_record["restart_under_current_version_required"] = true
			invalidated_record.erase("reconstruction_diagnostics")
			payload["committed_run"] = invalidated_record
			var invalidated_write: Dictionary = _save_store.write(&"session", payload)
			if not bool(invalidated_write.get("ok", false)):
				return _failure("compatibility_invalidation_persist_failed:%s" % String(invalidated_write.get("error", "unknown")))
			reconstructed["record"] = invalidated_record.duplicate(true)
			reconstructed["planning_baseline"] = planning_baseline.duplicate(true)
			reconstructed["restart_required"] = true
			reconstructed["recovery_action"] = "restart_from_committed_layout_under_current_version"
		return reconstructed

	var verified_record: Dictionary = record.duplicate(true)
	verified_record["tick_checksums"] = Array(reconstructed["tick_checksums"])
	verified_record["final_result_checksum"] = String(reconstructed["final_result_checksum"])
	verified_record["last_presented_tick_cursor"] = int(reconstructed["presentation_cursor"])
	verified_record["reconstruction_verified"] = true
	if String(verified_record.get("lifecycle_state", "")) == "COMMITTED":
		verified_record["lifecycle_state"] = "SIMULATED"
	verified_record.erase("reconstruction_diagnostics")
	payload["committed_run"] = verified_record
	var write_result: Dictionary = _save_store.write(&"session", payload)
	if not bool(write_result.get("ok", false)):
		return _failure("session_reconstruction_persist_failed:%s" % String(write_result.get("error", "unknown")))
	reconstructed["record"] = verified_record.duplicate(true)
	return reconstructed

func reconstruct_record(record: Dictionary, compatibility: Dictionary) -> Dictionary:
	var lifecycle: String = String(record.get("lifecycle_state", ""))
	if lifecycle not in ["COMMITTED", "SIMULATED", "REVIEWABLE", "COMPLETION_APPLIED"]:
		return _failure("invalid_reconstruction_lifecycle:%s" % lifecycle)
	var run_id: String = String(record.get("run_id", ""))
	if run_id.is_empty():
		return _failure("missing_run_id")
	var committed_value: Variant = record.get("canonical_committed_input", null)
	if not committed_value is Dictionary:
		return _failure("missing_canonical_committed_input")
	var committed_input: Dictionary = committed_value
	var expected_input_checksum: String = String(record.get("committed_input_checksum", ""))
	if expected_input_checksum.is_empty():
		return _failure("missing_committed_input_checksum")
	var actual_input_checksum: String = JSON.stringify(committed_input, "", true, true).sha256_text()
	if actual_input_checksum != expected_input_checksum:
		return _mismatch("committed_input_checksum", [expected_input_checksum], [actual_input_checksum])

	var compatibility_result: Dictionary = _validate_compatibility(record, compatibility)
	if not bool(compatibility_result.get("ok", false)):
		return compatibility_result
	var total_ticks: int = int(compatibility["total_ticks"])
	var simulation_defs: Dictionary = compatibility["simulation_defs"]
	var mandatory_predicates: Array = compatibility["mandatory_predicates"]

	var runner: DeliveryCompletionRunner = DeliveryCompletionRunnerScript.new()
	var simulation: Dictionary = runner.simulate_and_complete(record, total_ticks, simulation_defs, mandatory_predicates)
	if not bool(simulation.get("ok", false)):
		return _failure("reconstruction_simulation_failed:%s" % String(simulation.get("error", "unknown")))
	var trace_result: Dictionary = _normalized_trace(simulation.get("tick_checksums", PackedStringArray()))
	if not bool(trace_result.get("ok", false)):
		return trace_result
	var reconstructed_trace: PackedStringArray = trace_result["trace"]
	var stored_value: Variant = record.get("tick_checksums", null)
	if stored_value != null:
		var stored_result: Dictionary = _normalized_trace(stored_value)
		if not bool(stored_result.get("ok", false)):
			return stored_result
		var stored_trace: PackedStringArray = stored_result["trace"]
		if stored_trace != reconstructed_trace:
			return _mismatch("tick_checksum_sequence", Array(stored_trace), Array(reconstructed_trace))

	var final_result_checksum: String = String(simulation.get("completion_checksum", ""))
	if final_result_checksum.is_empty():
		return _failure("missing_reconstructed_final_result_checksum")
	var stored_final: String = String(record.get("final_result_checksum", ""))
	if not stored_final.is_empty() and stored_final != final_result_checksum:
		return _mismatch("final_result_checksum", [stored_final], [final_result_checksum])

	var final_tick: int = int(simulation.get("final_tick", total_ticks))
	var cursor: int = int(record.get("last_presented_tick_cursor", 0))
	var cursor_reset: bool = cursor < 0 or cursor > final_tick
	if cursor_reset:
		cursor = final_tick if lifecycle in ["REVIEWABLE", "COMPLETION_APPLIED"] else 0
	return {
		"ok": true,
		"error": "",
		"recovery_class": "A" if cursor_reset else "NONE",
		"run_id": run_id,
		"tick_checksums": reconstructed_trace,
		"final_result_checksum": final_result_checksum,
		"presentation_cursor": cursor,
		"presentation_cursor_reset": cursor_reset,
		"simulation_result": simulation,
	}

func _validate_compatibility(record: Dictionary, compatibility: Dictionary) -> Dictionary:
	for key: String in ["rules_version", "content_version", "contract_definition_checksum"]:
		if String(compatibility.get(key, "")).is_empty():
			return _failure("missing_compatibility:%s" % key, "D")
	if String(record.get("rules_version", "")) != String(compatibility["rules_version"]):
		return _failure("compatibility_rules_version_mismatch", "D")
	if String(record.get("content_version", "")) != String(compatibility["content_version"]):
		return _failure("compatibility_content_version_mismatch", "D")
	if String(record.get("expected_contract_definition_checksum", "")) != String(compatibility["contract_definition_checksum"]):
		return _failure("compatibility_contract_checksum_mismatch", "D")
	if int(compatibility.get("total_ticks", 0)) <= 0:
		return _failure("invalid_compatibility_total_ticks")
	if not compatibility.get("simulation_defs", null) is Dictionary:
		return _failure("missing_compatibility_simulation_defs")
	if not compatibility.get("mandatory_predicates", null) is Array:
		return _failure("missing_compatibility_mandatory_predicates")
	return {"ok": true, "error": ""}

func _normalized_trace(value: Variant) -> Dictionary:
	if not (value is Array or value is PackedStringArray):
		return _failure("invalid_tick_checksum_sequence")
	var trace: PackedStringArray = PackedStringArray()
	for raw: Variant in value:
		var checksum: String = String(raw)
		if checksum.is_empty():
			return _failure("invalid_tick_checksum")
		trace.append(checksum)
	return {"ok": true, "error": "", "trace": trace}

func _mismatch(kind: String, stored: Array, reconstructed: Array) -> Dictionary:
	return {
		"ok": false,
		"error": "authoritative_reconstruction_mismatch:%s" % kind,
		"recovery_class": "C",
		"diagnostics": {
			"kind": kind,
			"stored": stored.duplicate(true),
			"reconstructed": reconstructed.duplicate(true),
		},
	}

func _failure(error: String, recovery_class: String = "") -> Dictionary:
	return {"ok": false, "error": error, "recovery_class": recovery_class}
