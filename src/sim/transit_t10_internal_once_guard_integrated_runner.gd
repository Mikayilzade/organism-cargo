extends "res://src/sim/transit_t10_internal_reconsumption_integrated_runner.gd"

# Internal Phase-H effects are regenerated after next-tick consumer replay. Only
# records authored for the snapshot's own tick may be applied here. Lower T10
# layers can retain prior-tick record evidence while rebuilding carry/consumer
# authority; applying such a stale record again would execute a finite pulse a
# second time.
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

# FOOD_PULSE and CONTAMINATION_CLEANSE have an explicit next-tick consumer
# replay layer above the generic T10 effect application code. That replay starts
# from the previous rewritten end-of-tick organism runtime and therefore owns
# cross-tick propagation of satiety/contamination_load. Keeping the same delta in
# the generic additive organism carry applies the finite internal pulse once to
# the precomputed next-tick snapshot and then again when the consumer replay
# restores/reconsumes authoritative state (CLEANSE exposes this as 4 -> 1 -> 0;
# FOOD can hide it behind satiety clamping). Channel pulses still use the generic
# carry path and are deliberately untouched.
func _next_organism_carry(carry: Dictionary, instance_id: String, field_name: String, delta: int) -> void:
	if field_name in ["satiety", "contamination_load"]:
		return
	super._next_organism_carry(carry, instance_id, field_name, delta)
