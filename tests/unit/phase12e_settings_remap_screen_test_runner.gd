extends SceneTree

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")
const SettingsRemapScreenScript := preload("res://src/ui/settings_remap_screen.gd")

var failures: int = 0

func _init() -> void:
	var screen: SettingsRemapScreen = SettingsRemapScreenScript.new(InputRemapModelScript.new())
	root.add_child(screen)
	await process_frame
	_test_rendered_keyboard(screen)
	_test_dynamic_device_switch(screen)
	_test_conflict_explanation(screen)
	_test_contextual_reuse_and_reset(screen)
	_test_same_device_recovery(screen)
	screen.queue_free()
	await process_frame
	_finish()

func _test_rendered_keyboard(screen: SettingsRemapScreen) -> void:
	var snapshot: Dictionary = screen.rendered_snapshot()
	_expect_equal(String(snapshot.get("active_device", "")), "keyboard", "settings screen defaults to keyboard")
	_expect(String(snapshot.get("device_title", "")).contains("[KB]"), "keyboard glyph marker is rendered with text")
	var rows: Dictionary = snapshot.get("rows", {})
	_expect(rows.size() == InputActionCatalogScript.REQUIRED_ACTIONS.size(), "all required remappable semantic actions render")
	_expect(String(rows.get("accept", "")).contains("Accept"), "action text remains visible beside glyph/binding")
	_expect(String(rows.get("accept", "")).contains("Enter"), "keyboard physical binding text is visible")
	_expect(bool(snapshot.get("keyboard_focusable", false)), "keyboard device tab is keyboard/controller focusable")
	_expect(bool(snapshot.get("controller_focusable", false)), "controller device tab is keyboard/controller focusable")
	_expect(bool(snapshot.get("reset_focusable", false)), "reset button is keyboard/controller focusable")

func _test_dynamic_device_switch(screen: SettingsRemapScreen) -> void:
	var switched: Dictionary = screen.note_input_source(InputActionCatalogScript.DEVICE_CONTROLLER)
	_expect(bool(switched.get("ok", false)), "last input source can switch settings presentation to controller")
	var snapshot: Dictionary = screen.rendered_snapshot()
	_expect_equal(String(snapshot.get("active_device", "")), "controller", "controller becomes active rendered profile")
	_expect(String(snapshot.get("device_title", "")).contains("[PAD]"), "controller glyph marker is rendered")
	var rows: Dictionary = snapshot.get("rows", {})
	_expect(String(rows.get("accept", "")).contains("South / A"), "controller glyph text updates dynamically")

func _test_conflict_explanation(screen: SettingsRemapScreen) -> void:
	screen.set_active_device(InputActionCatalogScript.DEVICE_KEYBOARD)
	var conflict: Dictionary = screen.propose_binding(&"cancel", screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"accept"))
	_expect(not bool(conflict.get("ok", true)), "overlapping conflict is blocked before save")
	_expect(String(screen.rendered_snapshot().get("feedback", "")).contains("Conflict:"), "rendered UI explains conflict")
	_expect(String(screen.rendered_snapshot().get("feedback", "")).contains("Accept"), "conflict explanation identifies the action")

func _test_contextual_reuse_and_reset(screen: SettingsRemapScreen) -> void:
	var launch_binding: String = screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"launch_focus")
	var reused: Dictionary = screen.propose_binding(&"pause_playback", launch_binding)
	_expect(bool(reused.get("ok", false)), "mutually exclusive binding reuse remains allowed")
	_expect(String(screen.rendered_snapshot().get("feedback", "")).contains("mutually exclusive"), "allowed contextual reuse is explicitly explained")
	_expect(bool(screen.reset_active_device().get("ok", false)), "active device can reset independently")
	_expect_equal(screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"pause_playback"), "Space", "keyboard defaults restore")
	screen.set_active_device(InputActionCatalogScript.DEVICE_CONTROLLER)
	_expect(bool(screen.reset_active_device().get("ok", false)), "controller resets independently")
	_expect_equal(screen.model().binding(InputActionCatalogScript.DEVICE_CONTROLLER, &"accept"), "South / A", "controller defaults restore")

func _test_same_device_recovery(screen: SettingsRemapScreen) -> void:
	for device: StringName in [InputActionCatalogScript.DEVICE_KEYBOARD, InputActionCatalogScript.DEVICE_CONTROLLER]:
		screen.set_active_device(device)
		var recovery: Dictionary = screen.recovery_snapshot()
		_expect(bool(recovery.get("recoverable", false)), "%s keeps Accept/Cancel recovery" % String(device))
		_expect(not bool(recovery.get("other_device_required", true)), "%s recovery never requires another device" % String(device))
		_expect(String(screen.rendered_snapshot().get("recovery", "")).contains("ready"), "%s renders recovery readiness" % String(device))

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
		print("phase12e_settings_remap_screen_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12e_settings_remap_screen_test_runner: %d failure(s)" % failures)
		quit(1)
