class_name SimulationInput
extends RefCounted

var content_version: String
var rules_version: String
var contract_id: StringName
var route_profile_id: StringName
var seed: int

func _init(
		p_content_version: String,
		p_rules_version: String,
		p_contract_id: StringName,
		p_route_profile_id: StringName,
		p_seed: int
) -> void:
	content_version = p_content_version
	rules_version = p_rules_version
	contract_id = p_contract_id
	route_profile_id = p_route_profile_id
	seed = p_seed
