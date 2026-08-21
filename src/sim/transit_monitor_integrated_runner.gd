extends "res://src/sim/transit_contamination_integrated_runner.gd"

const S06MonitorBeaconKernelScript := preload("res://src/sim/s06_monitor_beacon_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result

	var revelations_value: Variant = simulation_defs.get("s06_revelations", [])
	if not revelations_value is Array:
		return {"ok": false, "error": "invalid_s06_revelations"}
	var revelations: Array = revelations_value
	if revelations.is_empty():
		return base_result

	if not committed_run.has("canonical_committed_input") or not committed_run["canonical_committed_input"] is Dictionary:
		return {"ok": false, "error": "missing_committed_input"}
	var committed_input: Dictionary = committed_run["canonical_committed_input"]
	var supports_value: Variant = committed_input.get("supports", [])
	if not supports_value is Array:
		return {"ok": false, "error": "invalid_committed_supports"}
	var committed_supports: Array = supports_value
	var support_definitions_value: Variant = simulation_defs.get("support_definitions_by_id", {})
	if not support_definitions_value is Dictionary:
		return {"ok": false, "error": "invalid_support_definitions"}
	var support_definitions_by_id: Dictionary = support_definitions_value

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return {"ok": false, "error": "invalid_end_tick_snapshots"}
	var snapshots: Array = snapshots_value
	var checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (checksums_value is Array or checksums_value is PackedStringArray):
		return {"ok": false, "error": "invalid_base_tick_checksums"}
	var base_checksums: Array = []
	for raw_checksum: Variant in checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return {"ok": false, "error": "base_tick_checksum_count_mismatch"}

	var kernel: S06MonitorBeaconKernel = S06MonitorBeaconKernelScript.new()
	var revealed_fact_ids: Dictionary = {}
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_events: Array = []

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return {"ok": false, "error": "invalid_end_tick_snapshot"}
		var snapshot_source: Dictionary = raw_snapshot
		var snapshot: Dictionary = snapshot_source.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var eligible_value: Variant = snapshot.get("same_tick_effect_eligible_support_ids", PackedStringArray())
		if not (eligible_value is Array or eligible_value is PackedStringArray):
			return {"ok": false, "error": "invalid_same_tick_effect_eligible_support_ids"}
		var eligible: PackedStringArray = PackedStringArray()
		for raw_id: Variant in eligible_value:
			eligible.append(String(raw_id))
		eligible.sort()
		var resolved: Dictionary = kernel.resolve_tick(
			tick,
			committed_supports,
			support_definitions_by_id,
			eligible,
			revelations,
			snapshot,
			revealed_fact_ids
		)
		if not bool(resolved.get("ok", false)):
			return {"ok": false, "error": "s06:%s" % String(resolved.get("error", "unknown"))}
		revealed_fact_ids = resolved["revealed_fact_ids"]
		var tick_events_value: Variant = resolved.get("events", [])
		if not tick_events_value is Array:
			return {"ok": false, "error": "invalid_s06_information_events"}
		var tick_events: Array = tick_events_value
		for raw_event: Variant in tick_events:
			if not raw_event is Dictionary:
				return {"ok": false, "error": "invalid_s06_information_event"}
			var event: Dictionary = raw_event
			all_events.append(event.duplicate(true))
		snapshot["s06_information_events"] = tick_events.duplicate(true)
		snapshot["s06_revealed_fact_ids"] = revealed_fact_ids.duplicate(true)
		integrated_snapshots.append(snapshot)
		integrated_checksums.append((String(base_checksums[index]) + "|s06=" + _serialize_s06_events(tick_events, revealed_fact_ids)).sha256_text())

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["s06_information_events"] = all_events
	base_result["s06_revealed_fact_ids"] = revealed_fact_ids.duplicate(true)
	return base_result

func _serialize_s06_events(events: Array, revealed_fact_ids: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		parts.append("%s:%s:%s:%s:%s:%s:%s" % [
			String(event.get("event_id", "")),
			String(event.get("kind", "")),
			String(event.get("support_instance_id", "")),
			String(event.get("revelation_id", "")),
			String(event.get("fact_id", "")),
			String(event.get("channel", "")),
			_encode_scalar(event.get("value", "")),
		])
	var revealed_ids: Array = revealed_fact_ids.keys()
	revealed_ids.sort()
	var revealed_parts: PackedStringArray = PackedStringArray()
	for raw_id: Variant in revealed_ids:
		revealed_parts.append(String(raw_id))
	return ";".join(parts) + "|revealed=" + ",".join(revealed_parts)

func _encode_scalar(value: Variant) -> String:
	var value_type: int = typeof(value)
	if value_type == TYPE_BOOL:
		return "b:%d" % (1 if bool(value) else 0)
	if value_type == TYPE_INT:
		return "i:%d" % int(value)
	return "s:" + String(value).replace("|", "%7C").replace(";", "%3B")