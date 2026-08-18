extends SceneTree

const ContentDocumentScript := preload("res://src/content/content_document.gd")
const SaveEnvelopeScript := preload("res://src/save/save_envelope.gd")
const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")

var failures: int = 0

func _initialize() -> void:
	_test_content_document()
	_test_save_envelope()
	_test_input_catalog()
	if failures == 0:
		print("BOUNDARY TESTS PASS")
		quit(0)
	else:
		push_error("BOUNDARY TESTS FAIL: %d" % failures)
		quit(1)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _expect_true(actual: bool, label: String) -> void:
	_expect_equal(actual, true, label)

func _expect_null(actual: Variant, label: String) -> void:
	_expect_equal(actual, null, label)

func _test_content_document() -> void:
	var good_json := '{"schema_version":1,"content_version":"c0","kind":"species","id":"species_test","payload":{"mass":3}}'
	var document: ContentDocument = ContentDocumentScript.parse_utf8_json(good_json, &"species")
	_expect_true(document != null, "valid content parses")
	if document != null:
		_expect_equal(document.id, &"species_test", "content id")
		_expect_equal(document.content_version, "c0", "content version")
	_expect_null(ContentDocumentScript.parse_utf8_json(good_json, &"support"), "wrong content kind rejected")
	_expect_null(ContentDocumentScript.parse_utf8_json('{"schema_version":0,"content_version":"c0","kind":"species","id":"x","payload":{}}'), "old schema rejected")
	_expect_null(ContentDocumentScript.parse_utf8_json('{"schema_version":1,"content_version":"","kind":"species","id":"x","payload":{}}'), "empty version rejected")

func _test_save_envelope() -> void:
	var payload: Dictionary = {"profile_uuid": "p1", "bronze": ["C01"]}
	var envelope: SaveEnvelope = SaveEnvelopeScript.create(&"profile", payload)
	var serialized: String = envelope.serialize()
	var parsed: SaveEnvelope = SaveEnvelopeScript.parse_and_validate(serialized, &"profile")
	_expect_true(parsed != null, "save envelope round trip")
	if parsed != null:
		_expect_equal(parsed.payload["profile_uuid"], "p1", "save payload retained")
	_expect_null(SaveEnvelopeScript.parse_and_validate(serialized, &"session"), "save kind separation")
	var tampered: String = serialized.replace("C01", "C02")
	_expect_null(SaveEnvelopeScript.parse_and_validate(tampered, &"profile"), "tampered save rejected")

func _test_input_catalog() -> void:
	var actions: Array[StringName] = InputActionCatalogScript.REQUIRED_ACTIONS.duplicate()
	_expect_true(InputActionCatalogScript.validate_required_actions(actions), "required semantic actions complete")
	actions.erase(&"rotate")
	_expect_equal(InputActionCatalogScript.validate_required_actions(actions), false, "missing remappable action rejected")
	_expect_true(InputActionCatalogScript.is_valid_focus_region(&"HOLD"), "hold focus region exists")
	_expect_equal(InputActionCatalogScript.is_valid_focus_region(&"UNKNOWN"), false, "unknown focus region rejected")
