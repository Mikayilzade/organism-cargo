class_name ContentDocument
extends RefCounted

const MIN_SCHEMA_VERSION: int = 1

var schema_version: int
var content_version: String
var kind: StringName
var id: StringName
var payload: Dictionary

func _init(
	p_schema_version: int,
	p_content_version: String,
	p_kind: StringName,
	p_id: StringName,
	p_payload: Dictionary
) -> void:
	schema_version = p_schema_version
	content_version = p_content_version
	kind = p_kind
	id = p_id
	payload = p_payload.duplicate(true)

static func parse_utf8_json(text: String, expected_kind: StringName = &"") -> ContentDocument:
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return null
	var root: Dictionary = parsed
	if not _has_exact_header_types(root):
		return null
	var parsed_schema: int = root["schema_version"]
	var parsed_content_version: String = root["content_version"]
	var parsed_kind: StringName = StringName(root["kind"])
	var parsed_id: StringName = StringName(root["id"])
	var parsed_payload: Dictionary = root["payload"]
	if parsed_schema < MIN_SCHEMA_VERSION:
		return null
	if parsed_content_version.strip_edges().is_empty():
		return null
	if String(parsed_kind).strip_edges().is_empty() or String(parsed_id).strip_edges().is_empty():
		return null
	if expected_kind != &"" and parsed_kind != expected_kind:
		return null
	return ContentDocument.new(
		parsed_schema,
		parsed_content_version,
		parsed_kind,
		parsed_id,
		parsed_payload
	)

static func _has_exact_header_types(root: Dictionary) -> bool:
	if not root.has("schema_version") or typeof(root["schema_version"]) != TYPE_INT:
		return false
	if not root.has("content_version") or typeof(root["content_version"]) != TYPE_STRING:
		return false
	if not root.has("kind") or typeof(root["kind"]) != TYPE_STRING:
		return false
	if not root.has("id") or typeof(root["id"]) != TYPE_STRING:
		return false
	if not root.has("payload") or typeof(root["payload"]) != TYPE_DICTIONARY:
		return false
	return true
