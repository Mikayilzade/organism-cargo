extends SceneTree

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")
const PlanningLayoutReachabilityScript := preload("res://src/ui/planning_layout_reachability.gd")
const TransitReviewNavigationModelScript := preload("res://src/ui/transit_review_navigation_model.gd")
const AccessibleVerticalSliceControlScript := preload("res://src/ui/accessible_vertical_slice_control.gd")
const SemanticVerticalSliceInputScript := preload("res://src/ui/semantic_vertical_slice_input.gd")

var failures: int = 0

func _init() -> void:
	_test_remap_contract()
	_test_deck_layout_reachability()
	_test_rendered_deck_composition()
	_test_transit_review_navigation()
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

func _test_rendered_deck_composition() -> void:
	var reachability: PlanningLayoutReachability = PlanningLayoutReachabilityScript.new()
	var host := Control.new()
	host.name = "DeckRenderedHost"
	host.position = Vector2.ZERO
	host.size = Vector2(1280, 800)
	get_root().add_child(host)

	var controls := {
		&"hold": _rendered_control(host, "Hold", Rect2(24, 120, 720, 520)),
		&"launch": _rendered_control(host, "Launch", Rect2(1040, 720, 200, 56)),
		&"undo": _rendered_control(host, "Undo", Rect2(760, 720, 100, 56)),
		&"redo": _rendered_control(host, "Redo", Rect2(872, 720, 100, 56)),
		&"overlays": _rendered_control(host, "Overlays", Rect2(760, 24, 180, 56)),
		&"objectives": _rendered_control(host, "Objectives", Rect2(760, 96, 480, 180)),
		&"semantic_focus": _rendered_control(host, "SemanticFocus", Rect2(24, 24, 440, 56)),
		&"support_link": _rendered_control(host, "SupportLink", Rect2(760, 296, 480, 96)),
		&"brownout_priority": _rendered_control(host, "BrownoutPriority", Rect2(760, 408, 480, 96)),
	}
	var modal := _rendered_control(host, "LaunchConfirm", Rect2(390, 250, 500, 260))
	var default_result := reachability.evaluate_rendered(host, 100, controls, modal)
	_expect(bool(default_result.get("ok", false)), "real 1280x800 Control composition keeps mandatory planning widgets and launch modal inside the safe area")
	_expect_equal(int(default_result.get("rendered_controls_checked", 0)), 9, "rendered Deck probe checks every frozen mandatory planning control family")

	var reset := _rendered_control(host, "ViewReset", Rect2(1080, 648, 160, 48))
	controls[&"view_reset"] = reset
	var max_result := reachability.evaluate_rendered(host, 200, controls, modal)
	_expect(bool(max_result.get("ok", false)), "real 1280x800 Control composition remains reachable at 200 percent stress target")
	_expect_equal(String(max_result.get("layout_mode", "")), "drawers", "rendered maximum-scale composition uses drawer allowance")
	_expect(bool(max_result.get("bounded_hold_pan_reset_required", false)), "rendered maximum-scale path keeps an explicit view-reset affordance")

	var launch := controls[&"launch"] as Control
	launch.position = Vector2(1200, 770)
	var escaped := reachability.evaluate_rendered(host, 200, controls, modal)
	_expect(not bool(escaped.get("ok", true)), "rendered composition rejects a mandatory Launch control falling off-screen")
	_expect_equal(String(escaped.get("error", "")), "required_control_outside_safe_area:launch", "rendered off-screen failure names the exact mandatory control")
	launch.position = Vector2(1040, 720)

	reset.visible = false
	var missing_reset := reachability.evaluate_rendered(host, 200, controls, modal)
	_expect(not bool(missing_reset.get("ok", true)), "maximum-scale bounded pan cannot strand the player without reachable view reset")
	reset.visible = true

	modal.position = Vector2(1000, 700)
	var escaped_modal := reachability.evaluate_rendered(host, 100, controls, modal)
	_expect(not bool(escaped_modal.get("ok", true)), "rendered launch confirmation must fit fully within 1280x800 safe area")

	host.queue_free()

func _rendered_control(parent: Control, node_name: String, rect: Rect2) -> Control:
	var control := Button.new()
	control.name = node_name
	control.position = rect.position
	control.size = rect.size
	control.visible = true
	parent.add_child(control)
	return control

func _test_transit_review_navigation() -> void:
	var navigator: TransitReviewNavigationModel = TransitReviewNavigationModelScript.new()
	var transit_context: Dictionary = {
		"planning_hold_payload": {"width": 3, "height": 2},
		"planning_contract_payload": {
			"manifest": [
				{"instance_id": "specimen-b"},
				{"instance_id": "specimen-a"},
			],
		},
	}
	_expect(bool(navigator.configure_transit(transit_context).get("ok", false)), "transit navigation configures from existing hold/manifest context")
	_expect_equal(float(navigator.transit_snapshot().get("speed", 0.0)), 1.0, "transit begins at canonical presentation speed 1x")
	_expect(not bool(navigator.transit_command(&"tick_step").get("ok", true)), "tick-step cannot run while presentation is playing")
	_expect(bool(navigator.transit_command(&"pause_playback").get("ok", false)), "pause/play semantic action is available")
	_expect(bool(navigator.transit_command(&"tick_step").get("ok", false)), "paused transit accepts one-tick presentation step request")
	_expect_equal(int(navigator.transit_snapshot().get("step_requests", 0)), 1, "tick-step request is counted independently of simulation authority")
	_expect(bool(navigator.transit_command(&"speed_up").get("ok", false)), "transit speed-up is semantic and bounded")
	_expect_equal(float(navigator.transit_snapshot().get("speed", 0.0)), 2.0, "speed-up moves from 1x to 2x")
	_expect(bool(navigator.transit_command(&"navigate_right").get("ok", false)), "cell inspection focus moves by logical cell")
	_expect_equal(navigator.transit_inspection().get("cell", []), [1, 0], "cell inspection exposes logical focused cell")
	_expect(bool(navigator.transit_command(&"region_next").get("ok", false)), "transit can switch discrete inspection focus mode")
	_expect_equal(String(navigator.transit_inspection().get("entity_id", "")), "specimen-a", "entity inspection is deterministic and pointer-free")

	var root_event: Dictionary = {"event_id": "t000001:h:H01", "tick": 1, "kind": "HAZARD_ACTIVE", "parent_event_ids": PackedStringArray()}
	var response_event: Dictionary = {"event_id": "t000001:o:specimen-a", "tick": 1, "kind": "ORGANISM_RESPONSE", "parent_event_ids": PackedStringArray(["t000001:h:H01"])}
	var failed_event: Dictionary = {"event_id": "result:p:P01", "tick": 4, "kind": "MANDATORY_PREDICATE", "passed": false, "parent_event_ids": PackedStringArray(["t000001:o:specimen-a"])}
	var review: Dictionary = {"ok": true, "events": [root_event, response_event, failed_event], "objective_events": [failed_event], "first_actionable_event_id": "t000001:o:specimen-a"}
	_expect(bool(navigator.configure_review(review).get("ok", false)), "review navigation configures from authoritative evidence")
	_expect_equal(String(navigator.review_snapshot().get("event_id", "")), "t000001:o:specimen-a", "review opens on first actionable event")
	_expect(bool(navigator.review_command(&"jump_failed_predicate").get("ok", false)), "failed-predicate jump is one semantic action")
	_expect_equal(String(navigator.review_snapshot().get("event_id", "")), "result:p:P01", "failed-predicate jump selects failed objective evidence")
	_expect(bool(navigator.review_command(&"jump_root_cause").get("ok", false)), "root-cause jump traverses frozen cause ancestry")
	_expect_equal(String(navigator.review_snapshot().get("event_id", "")), "t000001:h:H01", "root-cause jump reaches ancestry root deterministically")
	_expect(bool(navigator.review_command(&"compare_start_final").get("ok", false)), "start/final compare toggle is semantic")
	_expect(bool(navigator.review_snapshot().get("compare_start_final", false)), "compare state is presentation-only and visible")
	_expect(bool(navigator.review_command(&"panel_next").get("ok", false)), "review panels cycle without pointer input")
	_expect_equal(String(navigator.review_snapshot().get("panel", "")), "INSPECTOR", "review panel cycling follows deterministic order")

func _test_runtime_classes_load() -> void:
	var control: AccessibleVerticalSliceControl = AccessibleVerticalSliceControlScript.new()
	var semantic: SemanticVerticalSliceInput = SemanticVerticalSliceInputScript.new()
	var navigator: TransitReviewNavigationModel = TransitReviewNavigationModelScript.new()
	_expect(control != null, "accessible player-facing control class loads")
	_expect(semantic != null, "semantic player-facing input controller class loads")
	_expect(navigator != null, "transit/review semantic navigation class loads")
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
