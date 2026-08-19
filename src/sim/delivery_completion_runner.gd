class_name DeliveryCompletionRunner
extends RefCounted

const TransitSliceRunnerScript := preload("res://src/sim/transit_slice_runner.gd")
const DeliveryPredicateEvaluatorScript := preload("res://src/sim/delivery_predicate_evaluator.gd")

func simulate_and_complete(
		committed_run: Dictionary,
		total_ticks: int,
		simulation_defs: Dictionary,
		mandatory_predicates: Array
) -> Dictionary:
	var transit_runner: TransitSliceRunner = TransitSliceRunnerScript.new()
	var transit_result: Dictionary = transit_runner.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(transit_result.get("ok", false)):
		return transit_result
	if not bool(transit_result.get("completed", false)):
		return {"ok": false, "error": "transit_not_complete"}
	var snapshots: Array = transit_result.get("end_tick_snapshots", [])
	if snapshots.is_empty():
		return {"ok": false, "error": "missing_final_snapshot"}
	var final_snapshot_value: Variant = snapshots[snapshots.size() - 1]
	if not final_snapshot_value is Dictionary:
		return {"ok": false, "error": "invalid_final_snapshot"}
	var final_snapshot: Dictionary = final_snapshot_value
	var final_organisms: Array = final_snapshot.get("organisms", [])
	var evaluator: DeliveryPredicateEvaluator = DeliveryPredicateEvaluatorScript.new()
	var delivery_result: Dictionary = evaluator.evaluate(mandatory_predicates, final_organisms)
	if not bool(delivery_result.get("ok", false)):
		return {"ok": false, "error": "phase_i:%s" % String(delivery_result.get("error", "delivery_evaluation_failed"))}

	var completed: Dictionary = transit_result.duplicate(true)
	completed["delivery_result"] = delivery_result
	completed["completion_checksum"] = _completion_checksum(transit_result, delivery_result)
	completed["next_state"] = "CAUSAL_REVIEW"
	return completed

func _completion_checksum(transit_result: Dictionary, delivery_result: Dictionary) -> String:
	var tick_checksums: PackedStringArray = transit_result.get("tick_checksums", PackedStringArray())
	var parts: PackedStringArray = PackedStringArray()
	parts.append("final_tick=" + str(int(transit_result.get("final_tick", 0))))
	parts.append("delivery_success=" + ("1" if bool(delivery_result.get("success", false)) else "0"))
	if not tick_checksums.is_empty():
		parts.append("final_tick_checksum=" + tick_checksums[tick_checksums.size() - 1])
	var predicate_results: Array = delivery_result.get("predicate_results", [])
	for raw_result: Variant in predicate_results:
		var result: Dictionary = raw_result
		parts.append("predicate=%s:%s:%s:%s:%s:%s" % [
			String(result.get("id", "")),
			String(result.get("instance_id", "")),
			String(result.get("kind", "")),
			str(result.get("required", null)),
			str(result.get("observed", null)),
			"1" if bool(result.get("passed", false)) else "0",
		])
	return "|".join(parts).sha256_text()
