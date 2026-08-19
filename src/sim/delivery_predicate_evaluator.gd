class_name DeliveryPredicateEvaluator
extends RefCounted

const STRESS_AT_MOST := "STRESS_AT_MOST"
const PRIMARY_STATE_IS := "PRIMARY_STATE_IS"

func evaluate(predicates: Array, organisms: Array) -> Dictionary:
	if predicates.is_empty():
		return _failure("missing_mandatory_predicates")
	var organisms_by_id: Dictionary = {}
	for raw_organism: Variant in organisms:
		if not raw_organism is Dictionary:
			return _failure("invalid_final_organism")
		var organism: Dictionary = raw_organism
		var instance_id: String = String(organism.get("instance_id", ""))
		if instance_id.is_empty() or organisms_by_id.has(instance_id):
			return _failure("invalid_final_organism")
		organisms_by_id[instance_id] = organism

	var seen_predicates: Dictionary = {}
	var predicate_results: Array = []
	var success: bool = true
	for raw_predicate: Variant in predicates:
		if not raw_predicate is Dictionary:
			return _failure("invalid_mandatory_predicate")
		var predicate: Dictionary = raw_predicate
		var predicate_id: String = String(predicate.get("id", ""))
		var instance_id: String = String(predicate.get("instance_id", ""))
		var kind: String = String(predicate.get("kind", ""))
		if predicate_id.is_empty() or seen_predicates.has(predicate_id):
			return _failure("invalid_mandatory_predicate_id")
		seen_predicates[predicate_id] = true
		if instance_id.is_empty() or not organisms_by_id.has(instance_id):
			return _failure("unknown_mandatory_instance:%s" % instance_id)
		var organism: Dictionary = organisms_by_id[instance_id]
		var passed: bool = false
		var observed: Variant = null
		var required: Variant = null
		match kind:
			STRESS_AT_MOST:
				if not predicate.has("value"):
					return _failure("missing_predicate_value:%s" % predicate_id)
				observed = int(organism.get("stress", 0))
				required = int(predicate["value"])
				passed = int(observed) <= int(required)
			PRIMARY_STATE_IS:
				if not predicate.has("value"):
					return _failure("missing_predicate_value:%s" % predicate_id)
				observed = String(organism.get("primary_state", ""))
				required = String(predicate["value"])
				if String(required).is_empty():
					return _failure("invalid_predicate_value:%s" % predicate_id)
				passed = String(observed) == String(required)
			_:
				return _failure("unsupported_mandatory_predicate:%s" % kind)
		predicate_results.append({
			"id": predicate_id,
			"instance_id": instance_id,
			"kind": kind,
			"required": required,
			"observed": observed,
			"passed": passed,
		})
		if not passed:
			success = false

	return {
		"ok": true,
		"success": success,
		"predicate_results": predicate_results,
	}

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"success": false,
		"predicate_results": [],
	}
