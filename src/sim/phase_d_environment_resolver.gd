class_name PhaseDEnvironmentResolver
extends RefCounted

const H05VentCycleKernelScript := preload("res://src/sim/h05_vent_cycle_kernel.gd")
const ThermalResponseKernelScript := preload("res://src/sim/thermal_response_kernel.gd")
const ContaminationEnvironmentKernelScript := preload("res://src/sim/contamination_environment_kernel.gd")
const StressFieldEnvironmentKernelScript := preload("res://src/sim/stress_field_environment_kernel.gd")

const CHANNEL_ORDER := ["heat", "stress_field", "contamination"]

func resolve_phase_d(
		tick: int,
		cell_order: PackedStringArray,
		active_hazards: PackedStringArray,
		hazards_by_id: Dictionary,
		generated_by_channel: Dictionary,
		rules_by_channel: Dictionary
) -> Dictionary:
	var base_vent_result: Dictionary = _base_vent_authority(cell_order, generated_by_channel, rules_by_channel)
	if not bool(base_vent_result.get("ok", false)):
		return _failure(String(base_vent_result.get("error", "invalid_phase_d_rules")))

	var h05_kernel: H05VentCycleKernel = H05VentCycleKernelScript.new()
	var base_vent_by_channel: Dictionary = base_vent_result["vent_by_channel"]
	var h05_result: Dictionary = h05_kernel.resolve_phase_d(
		tick, cell_order, active_hazards, hazards_by_id, base_vent_by_channel
	)
	if not bool(h05_result.get("ok", false)):
		return _failure("h05:%s" % String(h05_result.get("error", "unknown")))

	var effective_vent_by_channel: Dictionary = h05_result["vent_by_channel"]
	var effective_rules: Dictionary = {}
	var environment: Dictionary = {}

	if generated_by_channel.has("heat"):
		var generated_heat: Dictionary = generated_by_channel["heat"]
		var source_heat_rules: Dictionary = rules_by_channel["heat"]
		var heat_rules: Dictionary = source_heat_rules.duplicate(true)
		var effective_heat_vent: Dictionary = effective_vent_by_channel["heat"]
		heat_rules["vent_by_cell"] = effective_heat_vent.duplicate(true)
		var heat_result: Dictionary = ThermalResponseKernelScript.new().propagate_heat(generated_heat, cell_order, heat_rules)
		if not bool(heat_result.get("ok", false)):
			return _failure("heat:%s" % String(heat_result.get("error", "unknown")))
		effective_rules["heat"] = heat_rules
		environment["heat"] = heat_result["heat_by_cell"]

	if generated_by_channel.has("stress_field"):
		var generated_stress: Dictionary = generated_by_channel["stress_field"]
		var source_stress_rules: Dictionary = rules_by_channel["stress_field"]
		var stress_rules: Dictionary = source_stress_rules.duplicate(true)
		var effective_stress_decay: Dictionary = effective_vent_by_channel["stress_field"]
		stress_rules["decay_by_cell"] = effective_stress_decay.duplicate(true)
		var stress_result: Dictionary = StressFieldEnvironmentKernelScript.new().propagate_phase_d(generated_stress, cell_order, stress_rules)
		if not bool(stress_result.get("ok", false)):
			return _failure("stress_field:%s" % String(stress_result.get("error", "unknown")))
		effective_rules["stress_field"] = stress_rules
		environment["stress_field"] = stress_result["stress_field_by_cell"]

	if generated_by_channel.has("contamination"):
		var generated_contamination: Dictionary = generated_by_channel["contamination"]
		var source_contamination_rules: Dictionary = rules_by_channel["contamination"]
		var contamination_rules: Dictionary = source_contamination_rules.duplicate(true)
		var effective_contamination_vent: Dictionary = effective_vent_by_channel["contamination"]
		contamination_rules["vent_by_cell"] = effective_contamination_vent.duplicate(true)
		var contamination_result: Dictionary = ContaminationEnvironmentKernelScript.new().propagate_phase_d(generated_contamination, cell_order, contamination_rules)
		if not bool(contamination_result.get("ok", false)):
			return _failure("contamination:%s" % String(contamination_result.get("error", "unknown")))
		effective_rules["contamination"] = contamination_rules
		environment["contamination"] = contamination_result["contamination_by_cell"]

	var h05_events: Array = h05_result["events"]
	var authority_payload: String = String(h05_result["authority_payload"]) + "|environment=" + _serialize_environment(environment, cell_order)
	return {
		"ok": true,
		"error": "",
		"environment_by_channel": environment,
		"effective_rules_by_channel": effective_rules,
		"effective_vent_by_channel": effective_vent_by_channel,
		"h05_events": h05_events.duplicate(true),
		"h05_authority_payload": String(h05_result["authority_payload"]),
		"h05_authority_checksum": String(h05_result["authority_checksum"]),
		"authority_payload": authority_payload,
		"authority_checksum": authority_payload.sha256_text(),
	}

func _base_vent_authority(
		cell_order: PackedStringArray,
		generated_by_channel: Dictionary,
		rules_by_channel: Dictionary
) -> Dictionary:
	if generated_by_channel.is_empty():
		return _failure("missing_phase_d_channels")
	var vent_by_channel: Dictionary = {}
	var channel_keys: Array = generated_by_channel.keys()
	channel_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String(left) < String(right)
	)
	for raw_channel: Variant in channel_keys:
		var channel: String = String(raw_channel)
		if not channel in CHANNEL_ORDER:
			return _failure("invalid_phase_d_channel:%s" % channel)
		var generated_value: Variant = generated_by_channel[raw_channel]
		if not generated_value is Dictionary:
			return _failure("invalid_phase_d_field:%s" % channel)
		var rules_value: Variant = rules_by_channel.get(channel, null)
		if not rules_value is Dictionary:
			return _failure("missing_phase_d_rules:%s" % channel)
		var rules: Dictionary = rules_value
		var field_name: String = "decay_by_cell" if channel == "stress_field" else "vent_by_cell"
		var authored_value: Variant = rules.get(field_name, {})
		if not authored_value is Dictionary:
			return _failure("invalid_phase_d_vent_map:%s" % channel)
		var authored: Dictionary = authored_value
		var normalized: Dictionary = {}
		for cell_key: String in cell_order:
			var amount: int = int(authored.get(cell_key, 0))
			if amount < 0:
				return _failure("negative_phase_d_vent:%s:%s" % [channel, cell_key])
			normalized[cell_key] = amount
		vent_by_channel[channel] = normalized
	return {"ok": true, "error": "", "vent_by_channel": vent_by_channel}

func _serialize_environment(environment: Dictionary, cell_order: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for channel: String in CHANNEL_ORDER:
		if not environment.has(channel):
			continue
		var field: Dictionary = environment[channel]
		for cell_key: String in cell_order:
			parts.append("%s:%s:%d" % [channel, cell_key, int(field.get(cell_key, 0))])
	return ",".join(parts)

func _failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"environment_by_channel": {},
		"effective_rules_by_channel": {},
		"effective_vent_by_channel": {},
		"h05_events": [],
		"h05_authority_payload": "",
		"h05_authority_checksum": "",
		"authority_payload": "",
		"authority_checksum": "",
	}
