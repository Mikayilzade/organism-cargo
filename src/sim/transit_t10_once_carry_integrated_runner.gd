extends "res://src/sim/transit_t10_contamination_channel_authority_integrated_runner.gd"

# T10 Phase-H deltas are one-boundary carry only. The previous integration layer
# retained already-consumed deltas in carry and could reapply a once-per-run pulse
# again on tick 3+. This wrapper consumes the previous carry before processing the
# current tick's new Phase-H records, so only newly-created deltas survive.
func integrate_effects(base_result: Dictionary, simulation_defs: Dictionary = {}) -> Dictionary:
	var prepared: Dictionary = _ensure_dormant_contamination_authority(base_result, simulation_defs)
	if not bool(prepared.get("ok", false)):
		return prepared
	var snapshots_value: Variant = prepared.get("end_tick_snapshots", [])
	var checksums_value: Variant = prepared.get("tick_checksums", PackedStringArray())
	if not snapshots_value is Array:
		return _failure("invalid_end_tick_snapshots")
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return _failure("invalid_tick_checksums")
	var snapshots: Array = snapshots_value
	var base_checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return _failure("t10_effect_tick_checksum_count_mismatch")

	var carry: Dictionary = _empty_t10_carry()
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_application_events: Array = []

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_end_tick_snapshot")
		var snapshot: Dictionary = (raw_snapshot as Dictionary).duplicate(true)
		var carry_result: Dictionary = _apply_carry(snapshot, carry, simulation_defs)
		if not bool(carry_result.get("ok", false)):
			return carry_result
		snapshot = carry_result["snapshot"]

		# The incoming carry has now crossed its one allowed next-tick boundary.
		# Current-tick records build a fresh carry for the following tick only.
		var fresh_carry: Dictionary = _empty_t10_carry()
		var records_value: Variant = snapshot.get("t10_effect_records", [])
		if not records_value is Array:
			return _failure("invalid_t10_effect_records")
		var applied_result: Dictionary = _apply_effect_records(snapshot, records_value as Array, fresh_carry, simulation_defs)
		if not bool(applied_result.get("ok", false)):
			return applied_result
		snapshot = applied_result["snapshot"]
		carry = applied_result["carry"]
		var application_events: Array = applied_result["events"]
		snapshot["t10_effect_application_events"] = application_events.duplicate(true)
		snapshot["t10_effect_carry_state"] = carry.duplicate(true)
		integrated_snapshots.append(snapshot)
		for raw_event: Variant in application_events:
			if raw_event is Dictionary:
				all_application_events.append((raw_event as Dictionary).duplicate(true))
		var checksum_material: String = "%s|t10_effect_apply=%s|t10_effect_carry=%s" % [
			String(base_checksums[index]),
			_serialize_application_events(application_events),
			_serialize_carry(carry),
		]
		integrated_checksums.append(checksum_material.sha256_text())

	var result: Dictionary = prepared.duplicate(true)
	result["end_tick_snapshots"] = integrated_snapshots
	result["tick_checksums"] = integrated_checksums
	result["t10_effect_application_events"] = all_application_events
	result["t10_effect_carry_state"] = carry.duplicate(true)

	# This override intentionally replaces the inherited effect-application loop so
	# it can reset carry after consumption. Re-run the already validated inherited
	# consumer passes explicitly, in their original order, instead of calling
	# super.integrate_effects() and reintroducing the stale-carry bug.
	var stress_reconsumed: Dictionary = _reconsume_stress_field_carry(result)
	if not bool(stress_reconsumed.get("ok", false)):
		return stress_reconsumed
	var heat_reconsumed: Dictionary = _reconsume_heat_carry(stress_reconsumed)
	if not bool(heat_reconsumed.get("ok", false)):
		return heat_reconsumed
	return _reconsume_contamination_carry(heat_reconsumed, simulation_defs)

func _empty_t10_carry() -> Dictionary:
	return {
		"channel_delta_by_name": {},
		"organism_delta_by_id": {},
	}
