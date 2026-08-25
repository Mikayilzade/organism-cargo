class_name Phase12EPreflightMatrixAcceptance
extends RefCounted

const AccessibilitySettingsModelScript := preload("res://src/ui/accessibility_settings_model.gd")
const AccessibilityPreflightScreenScript := preload("res://src/ui/accessibility_preflight_screen.gd")
const PlanningLayoutReachabilityScript := preload("res://src/ui/planning_layout_reachability.gd")
const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")

var _failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	var model: AccessibilitySettingsModel = AccessibilitySettingsModelScript.new()
	var screen: AccessibilityPreflightScreen = AccessibilityPreflightScreenScript.new(model)
	screen.size = Vector2(1280, 800)
	tree.root.add_child(screen)
	screen.configure(true)
	await tree.process_frame

	var initial := screen.rendered_snapshot()
	_expect(bool(initial.get("all_rows_focusable", false)), "every preflight field is keyboard/controller focusable")
	_expect_equal((initial.get("deck_safe_area_target", []) as Array), [1280, 800], "preflight declares Deck 1280x800 acceptance target")
	_expect_equal(model.first_run_preflight_fields(), [&"ui_scale_percent", &"reduced_flashing", &"reduced_motion", &"master_volume_percent", &"non_speech_captions", &"input_method"], "preflight exposes the full frozen field set")
	_expect(not bool(screen.dispatch(&"cancel").get("ok", true)), "first-run preflight cannot be silently skipped with Cancel")

	# Drive the screen entirely through the same semantic actions used by keyboard/controller/Deck.
	_expect(bool(screen.dispatch(&"navigate_right").get("ok", false)), "UI scale can be adjusted semantically")
	_expect(bool(screen.dispatch(&"navigate_right").get("ok", false)), "UI scale reaches 150 semantically")
	_expect(bool(screen.dispatch(&"navigate_right").get("ok", false)), "UI scale reaches 175 semantically")
	_expect(bool(screen.dispatch(&"navigate_right").get("ok", false)), "UI scale reaches 200 semantically")
	_expect_equal(int(model.snapshot().get("ui_scale_percent", 0)), 200, "maximum 200 percent scale is selectable before gameplay")
	_expect(bool(screen.dispatch(&"navigate_down").get("ok", false)), "focus reaches Reduced Flashing")
	_expect(bool(screen.dispatch(&"accept").get("ok", false)), "Reduced Flashing toggles with Accept")
	_expect(bool(screen.dispatch(&"navigate_down").get("ok", false)), "focus reaches Reduced Motion")
	_expect(bool(screen.dispatch(&"accept").get("ok", false)), "Reduced Motion toggles with Accept")
	_expect(bool(screen.dispatch(&"navigate_down").get("ok", false)), "focus reaches volume")
	for unused: int in range(4):
		_expect(bool(screen.dispatch(&"navigate_left").get("ok", false)), "volume can be lowered without pointer")
	_expect_equal(int(model.snapshot().get("master_volume_percent", -1)), 0, "no-audio profile is selectable before gameplay")
	_expect(bool(screen.dispatch(&"navigate_down").get("ok", false)), "focus reaches non-speech captions")
	_expect(bool(screen.dispatch(&"navigate_down").get("ok", false)), "focus reaches input method")
	for unused: int in range(4):
		_expect(bool(screen.dispatch(&"navigate_right").get("ok", false)), "input method cycles without pointer")
	_expect_equal(model.snapshot().get("input_method"), &"steam_deck", "Steam Deck can be chosen in first-run preflight")
	_expect(bool(screen.dispatch(&"navigate_down").get("ok", false)), "focus reaches Continue")
	_expect_equal(screen.focused_row(), &"continue", "Continue is a deterministic focus target")

	var max_profile := model.snapshot()
	_expect(bool(max_profile.get("reduced_motion", false)), "matrix profile keeps Reduced Motion on")
	_expect(bool(max_profile.get("reduced_flashing", false)), "matrix profile keeps Reduced Flashing on")
	_expect_equal(int(max_profile.get("master_volume_percent", -1)), 0, "matrix profile keeps audio at zero")

	var reachability: PlanningLayoutReachability = PlanningLayoutReachabilityScript.new()
	var model_reach := reachability.evaluate(Vector2i(1280, 800), 200, PlanningLayoutReachabilityScript.REQUIRED_REGIONS.duplicate(), true, true)
	_expect(bool(model_reach.get("ok", false)), "200 percent Deck planning contract remains in drawer-mode reachability envelope")
	_expect_equal(String(model_reach.get("layout_mode", "")), "drawers", "maximum scale uses drawer-safe layout contract")
	_expect(bool(model_reach.get("bounded_hold_pan_reset_required", false)), "maximum-scale hold requires bounded pan/reset rather than hidden cells")

	for device: StringName in [InputActionCatalogScript.DEVICE_KEYBOARD, InputActionCatalogScript.DEVICE_CONTROLLER]:
		_expect(InputActionCatalogScript.validate_default_device_profile(device), "%s independently covers every required semantic action" % String(device))
	var deck := model.deck_acceptance_profile()
	_expect(not bool(deck.get("touch_required", true)), "Deck touch is not required")
	_expect(not bool(deck.get("trackpad_required", true)), "Deck trackpad is not required")
	_expect(bool(deck.get("mandatory_controls_must_remain_reachable", false)), "Deck maximum-scale contract keeps mandatory controls reachable")

	# Settings-mode access remains cancelable after the first-run gate has been completed.
	screen.configure(false)
	_expect(bool(screen.dispatch(&"cancel").get("ok", false)), "later Accessibility Settings can close semantically")

	screen.queue_free()
	await tree.process_frame
	return _failures.duplicate()

func _expect(value: bool, label: String) -> void:
	if not value:
		_failures.append(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
