class_name SaveEnvelope
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 1

var schema_version: int
var kind: StringName
var payload: Dictionary
var payload_checksum: String

func _init(p_schema_version: int, p_kind: StringName, p_payload: Dictionary, p_payload_checksum: String) -> void:
	schema_version = p_schema_version
	kind = p_kind
	payload = p_payload.duplicate(true)
	payload_checksum = p_payload_checksum

static func create(p_kind: StringName, p_payload: Dictionary) -> SaveEnvelope:
	var canonical_payload: String = JSON.stringify(p_payload, "", true, true)
	return SaveEnvelope.new(
		CURRENT_SCHEMA_VERSION,
		p_kind,
		p_payload,
		_sha256(canonical_payload)
	)

func serialize() -> String:
	var root: Dictionary = {
		"schema_version": schema_version,
		"kind": String(kind),
		"payload": payload,
		"payload_checksum": payload_checksum,
	}
	return JSON.stringify(root, "", true, true)

static func parse_and_validate(text: String, expected_kind: StringName = &"") -> SaveEnvelope:
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return null
	var root: Dictionary = parsed
	if not root.has("schema_version") or typeof(root["schema_version"]) != TYPE_INT:
		return null
	if not root.has("kind") or typeof(root["kind"]) != TYPE_STRING:
		return null
	if not root.has("payload") or typeof(root["payload"]) != TYPE_DICTIONARY:
		return null
	if not root.has("payload_checksum") or typeof(root["payload_checksum"]) != TYPE_STRING:
		return null
	var parsed_schema: int = root["schema_version"]
	var parsed_kind: StringName = StringName(root["kind"])
	var parsed_payload: Dictionary = root["payload"]
	var parsed_checksum: String = root["payload_checksum"]
	if parsed_schema != CURRENT_SCHEMA_VERSION:
		return null
	if String(parsed_kind).strip_edges().is_empty():
		return null
	if expected_kind != &"" and parsed_kind != expected_kind:
		return null
	var canonical_payload: String = JSON.stringify(parsed_payload, "", true, true)
	if not _constant_time_equal(parsed_checksum, _sha256(canonical_payload)):
		return null
	return SaveEnvelope.new(parsed_schema, parsed_kind, parsed_payload, parsed_checksum)

static func _sha256(text: String) -> String:
	var context := HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(text.to_utf8_buffer())
	if update_error != OK:
		return ""
	return context.finish().hex_encode()

static func _constant_time_equal(a: String, b: String) -> bool:
	var a_bytes: PackedByteArray = a.to_utf8_buffer()
	var b_bytes: PackedByteArray = b.to_utf8_buffer()
	if a_bytes.size() != b_bytes.size():
		return false
	var diff: int = 0
	for index: int in range(a_bytes.size()):
		diff |= a_bytes[index] ^ b_bytes[index]
	return diff == 0
