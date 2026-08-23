extends "res://src/sim/transit_t10_contamination_t09_reconsumption_integrated_runner.gd"

# T10 CONTAMINATION_PULSE can be the first/only contamination producer in a run.
# The lower transit layer historically enabled the contamination channel only when
# an H03/S02/T05/T06 authority was already present, which left no Phase-D field or
# contamination-response evidence for the next-tick T10 reconsumption path.
# Keep that generic lower-layer policy intact and establish channel authority only
# at the T10 production composition boundary when canonical contamination rules are
# explicitly supplied.
func _prepare_power_authority(committed_input: Dictionary, simulation_defs: Dictionary) -> Dictionary:
	var authority: Dictionary = super._prepare_power_authority(committed_input, simulation_defs)
	if not bool(authority.get("ok", false)):
		return authority
	if bool(authority.get("contamination_enabled", false)):
		return authority
	var rules_value: Variant = simulation_defs.get("contamination_rules", null)
	if not rules_value is Dictionary:
		return authority
	var next: Dictionary = authority.duplicate(true)
	next["contamination_enabled"] = true
	next["contamination_rules"] = (rules_value as Dictionary).duplicate(true)
	return next
