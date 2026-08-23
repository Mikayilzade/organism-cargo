extends "res://src/sim/transit_t10_internal_reconsumption_integrated_runner.gd"

# Internal Phase-H effects are regenerated after next-tick consumer replay. Only
# records authored for the snapshot's own tick may be applied here. Lower T10
# layers can retain prior-tick record evidence while rebuilding carry/consumer
# authority; applying such a stale record again would execute a finite pulse a
# second time (most visibly CONTAMINATION_CLEANSE: 4 -> 1 -> 0).
func _reapply_current_internal_phase_h(snapshot: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var tick: int = int(snapshot.get("tick", 0))
	if tick <= 0:
		return _failure("invalid_t10_internal_reapply_tick")
	var records_value: Variant = snapshot.get("t10_effect_records", [])
	if not records_value is Array:
		return _failure("invalid_t10_internal_effect_records")
	var current_records: Array = []
	for raw_record: Variant in records_value:
		if not raw_record is Dictionary:
			return _failure("invalid_t10_internal_effect_record")
		var record: Dictionary = raw_record
		var effect_kind: String = String(record.get("kind", ""))
		if effect_kind in [FOOD_EFFECT_KIND, CLEANSE_EFFECT_KIND] and int(record.get("tick", 0)) != tick:
			continue
		current_records.append(record.duplicate(true))
	var scoped_snapshot: Dictionary = snapshot.duplicate(true)
	scoped_snapshot["t10_effect_records"] = current_records
	return super._reapply_current_internal_phase_h(scoped_snapshot, simulation_defs)
