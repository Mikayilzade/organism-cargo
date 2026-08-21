extends "res://src/sim/transit_contamination_integrated_runner.gd"

const T07FeedingKernelScript := preload("res://src/sim/t07_feeding_kernel.gd")

func simulate(committed_run: Dictionary, total_ticks: int, simulation_defs: Dictionary = {}) -> Dictionary:
	var base_result: Dictionary = super.simulate(committed_run, total_ticks, simulation_defs)
	if not bool(base_result.get("ok", false)):
		return base_result

	var producers_value: Variant = simulation_defs.get("t07_producer_definitions", [])
	var consumers_value: Variant = simulation_defs.get("t07_consumer_definitions", [])
	if not producers_value is Array:
		return _failure("invalid_t07_producer_definitions")
	if not consumers_value is Array:
		return _failure("invalid_t07_consumer_definitions")
	var producers: Array = producers_value
	var consumers: Array = consumers_value
	if producers.is_empty() and consumers.is_empty():
		return base_result
	if producers.is_empty() or consumers.is_empty():
		return _failure("incomplete_t07_feeding_definitions")

	var t06_value: Variant = simulation_defs.get("t06_definitions", [])
	if not t06_value is Array:
		return _failure("invalid_t06_definitions")
	var t06_definitions: Array = t06_value
	if not t06_definitions.is_empty():
		# T06 and T07 both allocate resources in Phase E and commit satiety in
		# Phase F from the same pre-F snapshot. The existing base runner owns T06,
		# so combining them in a post-pass would silently change same-tick headroom.
		# Fail closed until both are composed inside one authoritative Phase-E/F pass.
		return _failure("t07_t06_shared_phase_f_composition_not_implemented")

	var snapshots_value: Variant = base_result.get("end_tick_snapshots", [])
	if not snapshots_value is Array:
		return _failure("invalid_end_tick_snapshots")
	var snapshots: Array = snapshots_value
	if snapshots.is_empty():
		return base_result

	var organism_definitions_value: Variant = simulation_defs.get("organism_definitions", null)
	if not organism_definitions_value is Dictionary:
		return _failure("missing_organism_definitions_for_t07")
	var organism_definitions: Dictionary = organism_definitions_value

	var consumer_ids_result: Dictionary = _t07_consumer_ids(consumers)
	if not bool(consumer_ids_result.get("ok", false)):
		return consumer_ids_result
	var consumer_ids: PackedStringArray = consumer_ids_result["consumer_ids"]

	var kernel: T07FeedingKernel = T07FeedingKernelScript.new()
	var integrated_snapshots: Array = []
	var integrated_checksums: PackedStringArray = PackedStringArray()
	var all_events: Array = []
	var all_allocations: Array = []
	var persisted_runtime: Array = []

	var base_checksums_value: Variant = base_result.get("tick_checksums", PackedStringArray())
	if not (base_checksums_value is Array or base_checksums_value is PackedStringArray):
		return _failure("invalid_base_tick_checksums")
	var base_checksums: PackedStringArray = PackedStringArray()
	for raw_checksum: Variant in base_checksums_value:
		base_checksums.append(String(raw_checksum))
	if base_checksums.size() != snapshots.size():
		return _failure("base_tick_checksum_count_mismatch")

	for index: int in range(snapshots.size()):
		var raw_snapshot: Variant = snapshots[index]
		if not raw_snapshot is Dictionary:
			return _failure("invalid_end_tick_snapshot")
		var source_snapshot: Dictionary = raw_snapshot
		var snapshot: Dictionary = source_snapshot.duplicate(true)
		var tick: int = int(snapshot.get("tick", index + 1))
		var runtime_value: Variant = snapshot.get("organism_runtime", [])
		if not runtime_value is Array:
			return _failure("invalid_organism_runtime_snapshot")
		var current_runtime: Array = runtime_value
		if current_runtime.is_empty():
			return _failure("missing_organism_runtime_for_t07")

		if index == 0:
			var initialized: Dictionary = _initialize_t07_satiety(current_runtime, organism_definitions, consumers)
			if not bool(initialized.get("ok", false)):
				return initialized
			persisted_runtime = initialized["organisms"]
		else:
			var merged: Dictionary = _merge_persisted_t07_satiety(current_runtime, persisted_runtime, consumer_ids)
			if not bool(merged.get("ok", false)):
				return merged
			persisted_runtime = merged["organisms"]

		var resolved: Dictionary = kernel.resolve_tick(tick, persisted_runtime, producers, consumers)
		if not bool(resolved.get("ok", false)):
			return _failure("phase_e_f_t07:%s" % String(resolved.get("error", "unknown")))
		var next_runtime_value: Variant = resolved.get("organisms", [])
		var events_value: Variant = resolved.get("events", [])
		var allocations_value: Variant = resolved.get("allocations", [])
		if not next_runtime_value is Array:
			return _failure("invalid_t07_runtime_result")
		if not events_value is Array:
			return _failure("invalid_t07_events")
		if not allocations_value is Array:
			return _failure("invalid_t07_allocations")
		persisted_runtime = next_runtime_value
		var tick_events: Array = events_value
		var tick_allocations: Array = allocations_value
		for raw_event: Variant in tick_events:
			if not raw_event is Dictionary:
				return _failure("invalid_t07_event")
			var event: Dictionary = raw_event
			all_events.append(event.duplicate(true))
		for raw_allocation: Variant in tick_allocations:
			if not raw_allocation is Dictionary:
				return _failure("invalid_t07_allocation")
			var allocation: Dictionary = raw_allocation
			var with_tick: Dictionary = allocation.duplicate(true)
			with_tick["tick"] = tick
			all_allocations.append(with_tick)

		snapshot["organism_runtime"] = persisted_runtime.duplicate(true)
		snapshot["t07_allocations"] = tick_allocations.duplicate(true)
		snapshot["t07_events"] = tick_events.duplicate(true)
		integrated_snapshots.append(snapshot)
		var checksum_material: String = "%s|t07=%s" % [
			String(base_checksums[index]),
			_serialize_t07_tick(persisted_runtime, tick_events),
		]
		integrated_checksums.append(checksum_material.sha256_text())

	base_result["end_tick_snapshots"] = integrated_snapshots
	base_result["tick_checksums"] = integrated_checksums
	base_result["t07_events"] = all_events
	base_result["t07_allocations"] = all_allocations
	base_result["final_organism_runtime"] = persisted_runtime.duplicate(true)
	return base_result

func _t07_consumer_ids(consumers: Array) -> Dictionary:
	var ids: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for raw_consumer: Variant in consumers:
		if not raw_consumer is Dictionary:
			return _failure("invalid_t07_consumer_definition")
		var consumer: Dictionary = raw_consumer
		var instance_id: String = String(consumer.get("instance_id", ""))
		if instance_id.is_empty() or seen.has(instance_id):
			return _failure("invalid_t07_consumer_instance:%s" % instance_id)
		seen[instance_id] = true
		ids.append(instance_id)
	ids.sort()
	return {"ok": true, "error": "", "consumer_ids": ids}

func _initialize_t07_satiety(runtime: Array, organism_definitions: Dictionary, consumers: Array) -> Dictionary:
	var satiety_by_id: Dictionary = {}
	for raw_consumer: Variant in consumers:
		if not raw_consumer is Dictionary:
			return _failure("invalid_t07_consumer_definition")
		var consumer: Dictionary = raw_consumer
		var instance_id: String = String(consumer.get("instance_id", ""))
		if instance_id.is_empty() or satiety_by_id.has(instance_id):
			return _failure("invalid_t07_consumer_instance:%s" % instance_id)
		if not organism_definitions.has(instance_id) or not organism_definitions[instance_id] is Dictionary:
			return _failure("missing_organism_definition:%s" % instance_id)
		var authored: Dictionary = organism_definitions[instance_id]
		if not authored.has("initial_satiety"):
			return _failure("missing_initial_satiety:%s" % instance_id)
		var initial_satiety: int = int(authored["initial_satiety"])
		var satiety_max: int = int(consumer.get("satiety_max", 0))
		if initial_satiety < 0 or satiety_max <= 0 or initial_satiety > satiety_max:
			return _failure("invalid_initial_satiety:%s" % instance_id)
		satiety_by_id[instance_id] = initial_satiety

	var next: Array = runtime.duplicate(true)
	var seen_runtime: Dictionary = {}
	for index: int in range(next.size()):
		if not next[index] is Dictionary:
			return _failure("invalid_organism_runtime")
		var organism: Dictionary = next[index]
		var instance_id: String = String(organism.get("instance_id", ""))
		if satiety_by_id.has(instance_id):
			organism["satiety"] = int(satiety_by_id[instance_id])
			seen_runtime[instance_id] = true
			next[index] = organism
	for raw_id: Variant in satiety_by_id.keys():
		var required_id: String = String(raw_id)
		if not seen_runtime.has(required_id):
			return _failure("missing_organism_runtime:%s" % required_id)
	return {"ok": true, "error": "", "organisms": next}

func _merge_persisted_t07_satiety(current_runtime: Array, previous_runtime: Array, consumer_ids: PackedStringArray) -> Dictionary:
	var previous_satiety_by_id: Dictionary = {}
	for raw_previous: Variant in previous_runtime:
		if not raw_previous is Dictionary:
			return _failure("invalid_previous_t07_runtime")
		var previous: Dictionary = raw_previous
		var instance_id: String = String(previous.get("instance_id", ""))
		if instance_id in consumer_ids:
			if not previous.has("satiety"):
				return _failure("missing_previous_t07_satiety:%s" % instance_id)
			previous_satiety_by_id[instance_id] = int(previous["satiety"])

	var merged: Array = current_runtime.duplicate(true)
	var matched: Dictionary = {}
	for index: int in range(merged.size()):
		if not merged[index] is Dictionary:
			return _failure("invalid_current_t07_runtime")
		var current: Dictionary = merged[index]
		var instance_id: String = String(current.get("instance_id", ""))
		if previous_satiety_by_id.has(instance_id):
			current["satiety"] = int(previous_satiety_by_id[instance_id])
			matched[instance_id] = true
			merged[index] = current
	if matched.size() != consumer_ids.size():
		return _failure("t07_runtime_identity_mismatch")
	return {"ok": true, "error": "", "organisms": merged}

func _serialize_t07_tick(runtime: Array, events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw_runtime: Variant in runtime:
		if raw_runtime is Dictionary:
			var organism: Dictionary = raw_runtime
			if organism.has("satiety"):
				parts.append("org:%s:%d" % [String(organism.get("instance_id", "")), int(organism["satiety"])])
	for raw_event: Variant in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var parents_value: Variant = event.get("parent_event_ids", PackedStringArray())
		var parents: PackedStringArray = PackedStringArray()
		if parents_value is Array or parents_value is PackedStringArray:
			for raw_parent: Variant in parents_value:
				parents.append(String(raw_parent))
		parents.sort()
		parts.append("event:%s:%s:%s:%s:%s:%d:%d:%d:%s" % [
			String(event.get("event_id", "")),
			String(event.get("phase", "")),
			String(event.get("kind", "")),
			String(event.get("producer_id", "")),
			String(event.get("consumer_id", "")),
			int(event.get("food_units", 0)),
			int(event.get("satiety_delta", 0)),
			int(event.get("satiety_after", 0)),
			",".join(parents),
		])
	return ";".join(parts)
