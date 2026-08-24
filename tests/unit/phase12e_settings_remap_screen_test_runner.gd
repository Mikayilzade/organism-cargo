extends SceneTree

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const InputRemapModelScript := preload("res://src/ui/input_remap_model.gd")
const InputBindingsStoreScript := preload("res://src/ui/input_bindings_store.gd")
const SettingsRemapScreenScript := preload("res://src/ui/settings_remap_screen.gd")
const TEST_BINDINGS_PATH := "user://phase12e_input_bindings_test.json"

var failures: int = 0

func _init() -> void:
	_remove_test_bindings()
	InputActionCatalogScript.ensure_registered()
	var store := InputBindingsStoreScript.new(TEST_BINDINGS_PATH)
	var screen: SettingsRemapScreen = SettingsRemapScreenScript.new(InputRemapModelScript.new(), store); root.add_child(screen); await process_frame
	_test_rendered_keyboard(screen); _test_dynamic_device_switch(screen); _test_conflict_explanation(screen); _test_contextual_reuse_and_reset(screen); _test_same_device_recovery(screen); _test_physical_capture_and_input_map(screen); _test_durable_device_local_round_trip(screen, store)
	screen.queue_free(); await process_frame
	_remove_test_bindings(); InputActionCatalogScript.reset_device_in_input_map(InputActionCatalogScript.DEVICE_KEYBOARD); InputActionCatalogScript.reset_device_in_input_map(InputActionCatalogScript.DEVICE_CONTROLLER)
	await _test_persistent_shell_route(); _finish()

func _test_rendered_keyboard(screen: SettingsRemapScreen) -> void:
	var snapshot: Dictionary = screen.rendered_snapshot(); _expect_equal(String(snapshot.get("active_device", "")), "keyboard", "settings screen defaults to keyboard")
	_expect(String(snapshot.get("device_title", "")).contains("[KB]"), "keyboard glyph marker is rendered with text")
	var rows: Dictionary = snapshot.get("rows", {}); _expect(rows.size() == InputActionCatalogScript.REQUIRED_ACTIONS.size(), "all required remappable semantic actions render")
	_expect(String(rows.get("accept", "")).contains("Accept"), "action text remains visible beside glyph/binding"); _expect(String(rows.get("accept", "")).contains("Enter"), "keyboard physical binding text is visible")
	_expect(bool(snapshot.get("keyboard_focusable", false)), "keyboard device tab is focusable"); _expect(bool(snapshot.get("controller_focusable", false)), "controller device tab is focusable"); _expect(bool(snapshot.get("reset_focusable", false)), "reset button is focusable"); _expect(bool(snapshot.get("close_focusable", false)), "close button is focusable"); _expect(bool(snapshot.get("device_local_persistence", false)), "rendered Settings reports device-local persistence path")

func _test_dynamic_device_switch(screen: SettingsRemapScreen) -> void:
	var joy := InputEventJoypadButton.new(); joy.button_index = 3
	var switched: Dictionary = screen.note_input_event(joy); _expect(bool(switched.get("ok", false)), "physical controller event switches settings presentation")
	var snapshot: Dictionary = screen.rendered_snapshot(); _expect_equal(String(snapshot.get("active_device", "")), "controller", "controller becomes active rendered profile")
	_expect(String(snapshot.get("device_title", "")).contains("[PAD]"), "controller glyph marker is rendered"); _expect(String((snapshot.get("rows", {}) as Dictionary).get("accept", "")).contains("South / A"), "controller text updates dynamically")

func _test_conflict_explanation(screen: SettingsRemapScreen) -> void:
	screen.set_active_device(InputActionCatalogScript.DEVICE_KEYBOARD)
	var previous_cancel := screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"cancel")
	var conflict: Dictionary = screen.propose_binding(&"cancel", screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"accept"))
	_expect(not bool(conflict.get("ok", true)), "overlapping conflict is blocked before save"); _expect_equal(screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"cancel"), previous_cancel, "rejected recovery conflict cannot mutate live binding")
	_expect(String(screen.rendered_snapshot().get("feedback", "")).contains("Conflict:"), "rendered UI explains conflict"); _expect(String(screen.rendered_snapshot().get("feedback", "")).contains("Accept"), "conflict explanation identifies the action")

func _test_contextual_reuse_and_reset(screen: SettingsRemapScreen) -> void:
	var launch_binding: String = screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"launch_focus"); var reused: Dictionary = screen.propose_binding(&"pause_playback", launch_binding)
	_expect(bool(reused.get("ok", false)), "mutually exclusive binding reuse remains allowed"); _expect(String(screen.rendered_snapshot().get("feedback", "")).contains("mutually exclusive"), "allowed contextual reuse is explicitly explained")
	_expect(bool(screen.reset_active_device().get("ok", false)), "active device can reset independently"); _expect_equal(screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"pause_playback"), "Space", "keyboard defaults restore")
	screen.set_active_device(InputActionCatalogScript.DEVICE_CONTROLLER); _expect(bool(screen.reset_active_device().get("ok", false)), "controller resets independently"); _expect_equal(screen.model().binding(InputActionCatalogScript.DEVICE_CONTROLLER, &"accept"), "South / A", "controller defaults restore")

func _test_same_device_recovery(screen: SettingsRemapScreen) -> void:
	for device: StringName in [InputActionCatalogScript.DEVICE_KEYBOARD, InputActionCatalogScript.DEVICE_CONTROLLER]:
		screen.set_active_device(device); var recovery: Dictionary = screen.recovery_snapshot(); _expect(bool(recovery.get("recoverable", false)), "%s keeps Accept/Cancel recovery" % String(device)); _expect(not bool(recovery.get("other_device_required", true)), "%s recovery never requires another device" % String(device)); _expect(String(screen.rendered_snapshot().get("recovery", "")).contains("ready"), "%s renders recovery readiness" % String(device))

func _test_physical_capture_and_input_map(screen: SettingsRemapScreen) -> void:
	screen.set_active_device(InputActionCatalogScript.DEVICE_KEYBOARD); _expect(bool(screen.begin_capture(&"inspect").get("ok", false)), "keyboard row enters physical capture")
	var key := InputEventKey.new(); key.physical_keycode = KEY_K
	var captured := screen.capture_event(key); _expect(bool(captured.get("ok", false)), "keyboard physical event is accepted and durably saved"); _expect(bool(captured.get("durable", false)), "keyboard capture reports durable settings persistence"); _expect_equal(screen.model().binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"inspect"), "K", "captured keyboard label is persisted in model"); _expect(_input_map_has_key(&"inspect", KEY_K), "captured keyboard event is applied to live InputMap"); _expect(_input_map_has_controller(&"inspect"), "keyboard remap preserves controller binding")
	_expect(bool(screen.reset_active_device().get("ok", false)), "keyboard physical reset succeeds"); _expect(_input_map_has_key(&"inspect", KEY_I), "keyboard reset restores live InputMap default")
	screen.set_active_device(InputActionCatalogScript.DEVICE_CONTROLLER); screen.begin_capture(&"inspect"); var button := InputEventJoypadButton.new(); button.button_index = 5
	captured = screen.capture_event(button); _expect(bool(captured.get("ok", false)), "controller physical event is accepted without mouse and durably saved"); _expect(_input_map_has_button(&"inspect", 5), "captured controller event is applied to live InputMap"); _expect(_input_map_has_keyboard(&"inspect"), "controller remap preserves keyboard binding")
	_expect(bool(screen.reset_active_device().get("ok", false)), "controller physical reset succeeds"); _expect(_input_map_has_button(&"inspect", 3), "controller reset restores live InputMap default")

func _test_durable_device_local_round_trip(screen: SettingsRemapScreen, store: Variant) -> void:
	screen.set_active_device(InputActionCatalogScript.DEVICE_KEYBOARD); screen.begin_capture(&"inspect"); var key := InputEventKey.new(); key.physical_keycode = KEY_K; _expect(bool(screen.capture_event(key).get("ok", false)), "keyboard custom binding checkpoint saves")
	screen.set_active_device(InputActionCatalogScript.DEVICE_CONTROLLER); screen.begin_capture(&"inspect"); var button := InputEventJoypadButton.new(); button.button_index = 5; _expect(bool(screen.capture_event(button).get("ok", false)), "controller custom binding checkpoint saves")
	InputActionCatalogScript.reset_device_in_input_map(InputActionCatalogScript.DEVICE_KEYBOARD); InputActionCatalogScript.reset_device_in_input_map(InputActionCatalogScript.DEVICE_CONTROLLER)
	var restored_model: InputRemapModel = InputRemapModelScript.new(); var restored: Dictionary = store.load_into(restored_model)
	_expect(bool(restored.get("ok", false)) and not bool(restored.get("recovered", false)), "fresh Settings startup restores valid device-local bindings")
	_expect_equal(restored_model.binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"inspect"), "K", "saved keyboard binding restores into model"); _expect(_input_map_has_key(&"inspect", KEY_K), "saved keyboard binding restores into InputMap")
	_expect_equal(restored_model.binding(InputActionCatalogScript.DEVICE_CONTROLLER, &"inspect"), "Controller Button 5", "saved controller binding restores into model"); _expect(_input_map_has_button(&"inspect", 5), "saved controller binding restores into InputMap")
	# Per-device reset must not erase the other device's durable custom profile.
	screen.set_active_device(InputActionCatalogScript.DEVICE_KEYBOARD); _expect(bool(screen.reset_active_device().get("ok", false)), "keyboard reset persists independently")
	InputActionCatalogScript.reset_device_in_input_map(InputActionCatalogScript.DEVICE_KEYBOARD); InputActionCatalogScript.reset_device_in_input_map(InputActionCatalogScript.DEVICE_CONTROLLER)
	var reset_model: InputRemapModel = InputRemapModelScript.new(); var reset_loaded: Dictionary = store.load_into(reset_model); _expect(bool(reset_loaded.get("ok", false)), "independent reset file reloads")
	_expect_equal(reset_model.binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"inspect"), "I", "keyboard durable reset returns only keyboard to default"); _expect_equal(reset_model.binding(InputActionCatalogScript.DEVICE_CONTROLLER, &"inspect"), "Controller Button 5", "keyboard reset preserves controller durable customization"); _expect(_input_map_has_button(&"inspect", 5), "controller InputMap customization survives keyboard reset")
	# Corrupt settings recover to settings defaults only and are rewritten as a valid local settings payload.
	var corrupt_file := FileAccess.open(TEST_BINDINGS_PATH, FileAccess.WRITE); corrupt_file.store_string("{broken settings"); corrupt_file = null
	var corrupt_model: InputRemapModel = InputRemapModelScript.new(); var recovered: Dictionary = store.load_into(corrupt_model)
	_expect(bool(recovered.get("recovered", false)), "corrupt device-local settings enter explicit settings-only recovery"); _expect_equal(String(recovered.get("error", "")), "settings_corrupt", "corrupt settings recovery reason is explicit")
	_expect_equal(corrupt_model.binding(InputActionCatalogScript.DEVICE_KEYBOARD, &"inspect"), "I", "settings corruption resets keyboard defaults"); _expect_equal(corrupt_model.binding(InputActionCatalogScript.DEVICE_CONTROLLER, &"inspect"), "North / Y", "settings corruption resets controller defaults"); _expect(_input_map_has_key(&"inspect", KEY_I) and _input_map_has_button(&"inspect", 3), "settings corruption restores both InputMap defaults without campaign/profile coupling")

func _test_persistent_shell_route() -> void:
	var packed: PackedScene = load("res://scenes/shell/shell.tscn"); var shell: Control = packed.instantiate(); root.add_child(shell); await process_frame
	var settings: SettingsRemapScreen = shell.settings_screen(); _expect(settings != null, "persistent shell owns Settings/remap screen"); _expect(shell.settings_button() != null and shell.settings_button().focus_mode == Control.FOCUS_ALL, "persistent Settings entry is keyboard/controller focusable")
	shell.open_settings(); _expect(settings.visible, "persistent shell can open Settings path"); _expect(shell.slice_control() == null or not shell.slice_control().visible, "planning presentation is hidden behind Settings")
	shell.close_settings(); _expect(not settings.visible, "Settings can close without pointer-only action"); _expect(shell.slice_control() == null or shell.slice_control().visible, "planning presentation restores after Settings")
	shell.queue_free(); await process_frame

func _input_map_has_key(action: StringName, keycode: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode: return true
	return false
func _input_map_has_button(action: StringName, index: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == index: return true
	return false
func _input_map_has_keyboard(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey: return true
	return false
func _input_map_has_controller(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion: return true
	return false
func _remove_test_bindings() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_BINDINGS_PATH)
	if FileAccess.file_exists(TEST_BINDINGS_PATH): DirAccess.remove_absolute(absolute)
	if FileAccess.file_exists(TEST_BINDINGS_PATH + ".tmp"): DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BINDINGS_PATH + ".tmp"))

func _expect(value: bool, label: String) -> void:
	if not value: failures += 1; push_error("FAIL: %s" % label)
func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected: failures += 1; push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
func _finish() -> void:
	if failures == 0: print("phase12e_settings_remap_screen_test_runner: PASS"); quit(0)
	else: push_error("phase12e_settings_remap_screen_test_runner: %d failure(s)" % failures); quit(1)
