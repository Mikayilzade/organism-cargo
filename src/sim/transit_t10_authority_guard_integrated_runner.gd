extends "res://src/sim/transit_t10_effect_integrated_runner.gd"

func _apply_channel_effect(
		snapshot: Dictionary,
		record: Dictionary,
		effect_kind: String,
		magnitude: int,
		carry: Dictionary,
		simulation_defs: Dictionary
) -> Dictionary:
	var channel: String = _channel_for_effect(effect_kind)
	var rules_key: String = _rules_key_for_channel(channel)
	if rules_key.is_empty():
		return _failure("invalid_t10_effect_channel:%s" % channel)
	if not simulation_defs.has(rules_key):
		return _skipped(snapshot, carry, record, "authority_unavailable")
	return super._apply_channel_effect(snapshot, record, effect_kind, magnitude, carry, simulation_defs)

func _rules_key_for_channel(channel: String) -> String:
	match channel:
		"heat": return "thermal_rules"
		"stress_field": return "stress_field_rules"
		"contamination": return "contamination_rules"
		_: return ""
