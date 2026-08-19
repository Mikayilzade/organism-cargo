class_name TransitSliceRunner
extends RefCounted

const PHASE_ORDER := PackedStringArray(["A", "B", "C", "D", "E", "F", "G", "H", "I"])

func simulate(committed_run: Dictionary, total_ticks: int) -> Dictionary:
	if total_ticks <= 0:
		return {"ok": false, "error": "invalid_total_ticks"}
	if not committed_run.has("canonical_committed_input"):
		return {"ok": false, "error": "missing_committed_input"}
	var committed_input: Dictionary = committed_run["canonical_committed_input"]
	var supports: Array = committed_input.get("supports", [])
	if not supports.is_empty():
		return {"ok": false, "error": "slice_supports_not_implemented"}
	var canonical_placements: PackedStringArray = _canonical_placements(committed_input)
	if canonical_placements.is_empty():
		return {"ok": false, "error": "missing_placements"}

	var phase_trace: PackedStringArray = PackedStringArray()
	var tick_checksums: PackedStringArray = PackedStringArray()
	for tick: int in range(1, total_ticks + 1):
		for phase: String in PHASE_ORDER:
			phase_trace.append("%d:%s" % [tick, phase])
		var snapshot: String = _serialize_tick(
			committed_run,
			committed_input,
			canonical_placements,
			tick
		)
		tick_checksums.append(snapshot.sha256_text())

	return {
		"ok": true,
		"tick_checksums": tick_checksums,
		"phase_trace": phase_trace,
		"final_tick": total_ticks,
		"completed": true,
	}

func _canonical_placements(committed_input: Dictionary) -> PackedStringArray:
	var placements: Array = committed_input.get("placements", [])
	var encoded: PackedStringArray = PackedStringArray()
	for raw: Variant in placements:
		if not raw is Dictionary:
			return PackedStringArray()
		var placement: Dictionary = raw
		var instance_id: String = String(placement.get("instance_id", ""))
		var anchor: Array = placement.get("anchor", [])
		if instance_id.is_empty() or anchor.size() != 2:
			return PackedStringArray()
		encoded.append("%s@%s,%s:%s" % [
			instance_id,
			str(int(anchor[0])),
			str(int(anchor[1])),
			str(int(placement.get("orientation", 0))),
		])
	encoded.sort()
	return encoded

func _serialize_tick(
		committed_run: Dictionary,
		committed_input: Dictionary,
		canonical_placements: PackedStringArray,
		tick: int
) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("rules=" + String(committed_run.get("rules_version", "")))
	parts.append("content=" + String(committed_run.get("content_version", "")))
	parts.append("route=" + String(committed_input.get("route_id", "")))
	parts.append("seed=" + str(int(committed_input.get("seed", 0))))
	parts.append("tick=" + str(tick))
	parts.append("phases=" + ",".join(PHASE_ORDER))
	for placement: String in canonical_placements:
		parts.append("placement=" + placement)
	return "|".join(parts)
