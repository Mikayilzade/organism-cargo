extends SceneTree

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")
const PlanningLayoutReachabilityScript := preload("res://src/ui/planning_layout_reachability.gd")
const AccessibleVerticalSliceControlScript := preload("res://src/ui/accessible_vertical_slice_control.gd")
const SemanticVerticalSliceInputScript := preload("res://src/ui/semantic_vertical_slice_input.gd")

var failures: int = 0

func _init() -> void:
	_test_remap_contract()
	_test_deck_layout_reachability()
	_test_runtime_classes_load()
	_finish()

func _test_remap_contract() -> void:
	var model: InputRemapModel = InputRemapModelScript.new()
	var keyboard_recovery: Dictionary = model.recovery_contract(InputActionCatalogScript.DEVICE_KEYBOARD)
	var controller_recovery: Dictionary = model.recovery_contract(InputActionCatalogScript.DEVICE_CONTROLLER)
	_expect(bool(keyboard_recovery.get("recoverable", false)), "keyboard remap screen always has Accept/Cancel recovery")
	_expect(bool(controller_recovery.get("recoverable", false)), "controller remap screen always has Accept/Cancel recovery")
	_expect(not bool(keyboard_recovery.get("other_device_required", true)), "keyboard recovery does not require controller")
	_expect(not bool(controller_recovery.get("other_device_required", true)), "controller recovery does not require keyboard/mouse")

	var conflict: Dictionary = model.propose_binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"cancel", model.binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"accept"))
	_expect(not bool(conflict.get("ok", true)), "overlapping-context binding conflict is rejected")
	_expect_equal(String(conflict.get("error", "")), "binding_conflict", "binding conflict reports exact reason")

	var contextual: Dictionary = model.propose_binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"pause_playback", model.binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"launch_focus"))
	_expect(bool(contextual.get("ok", false)), "mutually exclusive planning/transit reuse is allowed")
	_expect(bool(contextual.get("explanation_required", false)), "mutually exclusive reuse requires UI explanation")
	_expect(bool(model.reset_device(InputActionCatalogScript.DEVICE_KEYBOARD).get("ok", false)), "keyboard has independent reset-to-default")
	_expect(bool(model.reset_device(InputActionCatalogScript.DEVICE_CONTROLLER).get("ok", false)), "controller has independent reset-to-default")

func _test_deck_layout_reachability() -> void:
	var reachability: PlanningLayoutReachability = PlanningLayoutReachabilityScript.new()
	var regions: Array[StringName] = [&"MANIFEST", &"HOLD", &"OBJECTIVES_SUPPORTS", &"TOOLBAR"]
	var deck_default: Dictionary = reachability.evaluate(Vector2i(1280, 800), 100, regions, true, true)
	_expect(bool(deck_default.get("ok", false)), "Deck 1280x800 default-scale planning regions remain reachable")
	_expect(bool(deck_default.get("hold_full_default_visibility_required", false)), "default Deck layout keeps full normal hold visible")
	var deck_max: Dictionary = reachability.evaluate(Vector2i(1280, 800), 200, regions, true, true)
	_expect(bool(deck_max.get("ok", false)), "Deck 1280x800 200 percent scale keeps mandatory path reachable")
	_expect_equal(String(deck_max.get("layout_mode", "")), "drawers", "maximum scale permits drawer composition")
	_expect(bool(deck_max.get("bounded_hold_pan_reset_required", false)), "maximum scale records bounded pan/reset requirement")
	var missing_toolbar: Array[StringName] = [&"MANIFEST", &"HOLD", &"OBJECTIVES_SUPPORTS"]
	_expect(not bool(reachability.evaluate(Vector2i(1280, 800), 200, missing_toolbar, true, true).get("ok", true)), "mandatory toolbar cannot fall off-screen")
	_expect(not bool(reachability.evaluate(Vector2i(1280, 800), 200, regions, false, true).get("ok", true)), "launch confirmation modal must fit safe area")
	_expect(not bool(reachability.evaluate(Vector2i(1280, 800), 200, regions, true, false).get("ok", true)), "visible focus indicator is mandatory")

func _test_runtime_classes_load() -> void:
	var control: AccessibleVerticalSliceControl = AccessibleVerticalSliceControlScript.new()
	var semantic: SemanticVerticalSliceInput = SemanticVerticalSliceInputScript.new()
	_expect(control != null, "accessible player-facing control class loads")
	_expect(semantic != null, "semantic player-facing input controller class loads")
	control.free()
	semantic.free()

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _finish() -> void:
	if failures == 0:
		print("phase12e_semantic_remap_layout_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12e_semantic_remap_layout_test_runner: %d failure(s)" % failures)
		quit(1)
