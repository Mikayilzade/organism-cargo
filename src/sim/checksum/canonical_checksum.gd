class_name CanonicalChecksum
extends RefCounted

static func serialize_bootstrap_state(
		rules_version: String,
		content_version: String,
		tick: int,
		ordered_entity_ids: Array[StringName],
		ordered_values: Array[int]
) -> String:
	assert(ordered_entity_ids.size() == ordered_values.size())
	var parts: PackedStringArray = PackedStringArray()
	parts.append("rules=" + rules_version)
	parts.append("content=" + content_version)
	parts.append("tick=" + str(tick))
	for index: int in range(ordered_entity_ids.size()):
		parts.append(str(ordered_entity_ids[index]) + "=" + str(ordered_values[index]))
	return "|".join(parts)

static func sha256(serialized_state: String) -> String:
	return serialized_state.sha256_text()
