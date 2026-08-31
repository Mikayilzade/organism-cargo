extends SceneTree

const InputActionCatalogScript := preload("res://src/ui/input_action_catalog.gd")
const PlanningFocusRouterScript := preload("res://src/ui/planning_focus_router.gd")
const PlanningSupportConfigModelScript := preload("res://src/ui/planning_support_config_model.gd")
const AccessibilitySettingsModelScript := preload("res://src/ui/accessibility_settings_model.gd")

var failures: int = 0

func _init() -> void:
	_test_required_input_catalog()
	_test_independent_default_device_paths()
	_test_planning_focus_router()
	_test_support_link_and_brownout_priority_model()
	_test_accessibility_shell_contract()
	_test_critical_signal_and_reduced_presentation_application()
	_finish()

func _test_required_input_catalog() -> void:
	_expect(InputActionCatalogScript.validate_required_actions(InputActionCatalogScript.REQUIRED_ACTIONS), "required semantic action catalog is complete and unique")
	_expect_equal(InputActionCatalogScript.PLANNING_FOCUS_REGIONS, [&"MANIFEST", &"HOLD", &"INSPECTOR", &"ROUTE", &"OBJECTIVES_SUPPORTS", &"TOOLBAR"], "planning focus regions match frozen UX contract")
	_expect(InputActionCatalogScript.validate_default_device_profile(InputActionCatalogScript.DEVICE_KEYBOARD), "keyboard default profile covers every required action")
	_expect(InputActionCatalogScript.validate_default_device_profile(InputActionCatalogScript.DEVICE_CONTROLLER), "controller default profile covers every required action")

func _test_independent_default_device_paths() -> void:
	InputActionCatalogScript.ensure_registered()
	for action: StringName in InputActionCatalogScript.REQUIRED_ACTIONS:
		_expect(InputMap.has_action(action), "%s is registered in InputMap" % String(action))
		var has_keyboard := false
		var has_controller := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				has_keyboard = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_controller = true
		_expect(has_keyboard, "%s has a keyboard binding without pointer emulation" % String(action))
		_expect(has_controller, "%s has a controller binding without virtual cursor dependence" % String(action))

func _test_planning_focus_router() -> void:
	var router: PlanningFocusRouter = PlanningFocusRouterScript.new()
	_expect(bool(router.configure_hold(3, 2).get("ok", false)), "focus router accepts authored hold dimensions")
	_expect(router.focus_visible(), "planning focus indicator is logically always visible")
	_expect_equal(router.current_region(), &"MANIFEST", "focus starts in manifest")
	_expect_equal(router.semantic_request(&"region_next").get("region"), &"HOLD", "region-next reaches hold")
	_expect_equal(router.semantic_request(&"navigate_right").get("focus"), [1, 0], "hold right navigation moves one logical grid cell")
	_expect_equal(router.semantic_request(&"navigate_down").get("focus"), [1, 1], "hold down navigation moves one logical grid cell")
	_expect_equal(router.semantic_request(&"navigate_down").get("focus"), [1, 1], "hold navigation clamps at authored boundary")
	_expect_equal(router.semantic_request(&"accept").get("command"), "ACCEPT", "accept is available from focused hold cell")
	_expect_equal(router.semantic_request(&"inspect").get("command"), "INSPECT", "inspect is a first-class semantic action")
	_expect_equal(router.semantic_request(&"rotate").get("command"), "ROTATE", "rotate is a first-class semantic action")
	_expect_equal(router.semantic_request(&"remove").get("command"), "REMOVE", "remove is a first-class semantic action")
	_expect_equal(router.semantic_request(&"launch_focus").get("command"), "FOCUS_LAUNCH", "launch has an explicit focus action instead of accidental activation")

	_expect(bool(router.enter_modal(&"INSPECTOR").get("ok", false)), "modal can trap focus in a valid region")
	var trapped := router.semantic_request(&"region_next")
	_expect(not bool(trapped.get("ok", true)), "region cycling cannot escape behind a modal")
	_expect_equal(String(trapped.get("error", "")), "modal_focus_trap", "modal focus trap reports its reason")
	_expect_equal(router.current_region(), &"INSPECTOR", "modal focus remains on the modal-owned region")
	_expect(bool(router.exit_modal().get("ok", false)), "modal focus can be released")
	_expect_equal(router.semantic_request(&"region_previous").get("region"), &"HOLD", "region-previous restores deterministic region navigation")

func _test_support_link_and_brownout_priority_model() -> void:
	var model: PlanningSupportConfigModel = PlanningSupportConfigModelScript.new()
	var configured := model.configure([
		{"id": "S01", "name": "Cooler", "requires_power": true},
		{"id": "S02", "name": "Filter", "requires_power": true},
		{"id": "S03", "name": "Baffle", "requires_power": false},
	], ["cargo-a", "cargo-b", "cell-2,1"])
	_expect(bool(configured.get("ok", false)), "support configuration accepts an ordered source/target set")
	var snapshot: Dictionary = model.snapshot()
	_expect_equal(snapshot.get("selected_support_id"), "S01", "ordered support focus starts at first source")
	_expect_equal(snapshot.get("selected_target_id"), "cargo-a", "ordered target focus starts at first target")
	_expect_equal(snapshot.get("power_priority"), ["S01", "S02"], "powered support priority follows authored order")

	_expect(bool(model.command(&"navigate_right").get("ok", false)), "support target is keyboard/controller navigable")
	_expect_equal(model.snapshot().get("selected_target_id"), "cargo-b", "right navigation advances one logical target")
	_expect(bool(model.command(&"accept").get("ok", false)), "Accept creates a visible source-target link")
	_expect_equal(model.snapshot().get("links"), [{"source": "S01", "target": "cargo-b"}], "source-target link is explicit and ordered")

	_expect(bool(model.command(&"overlay_next").get("ok", false)), "powered support can move later in Brownout priority without pointer interaction")
	_expect_equal(model.snapshot().get("power_priority"), ["S02", "S01"], "Brownout power priority reorders deterministically")
	_expect(bool(model.command(&"navigate_down").get("ok", false)), "support source list advances discretely")
	_expect_equal(model.snapshot().get("selected_support_id"), "S02", "second support becomes selected source")
	_expect(bool(model.command(&"overlay_previous").get("ok", false)), "selected powered support can move earlier in priority")
	_expect_equal(model.snapshot().get("power_priority"), ["S02", "S01"], "already-highest priority clamps without corruption")

	_expect(bool(model.command(&"navigate_down").get("ok", false)), "non-powered support remains reachable in same ordered list")
	var rejected := model.command(&"overlay_next")
	_expect(not bool(rejected.get("ok", true)), "non-powered support cannot be inserted into Brownout order")
	_expect_equal(String(rejected.get("error", "")), "selected_support_not_powered", "non-powered priority rejection is explicit")
	_expect(String(model.snapshot().get("instructions", "")).contains("Accept link/unlink"), "support interaction exposes non-glyph text instructions")

func _test_accessibility_shell_contract() -> void:
	var settings: AccessibilitySettingsModel = AccessibilitySettingsModelScript.new()
	_expect_equal(settings.first_run_preflight_fields(), [&"ui_scale_percent", &"reduced_flashing", &"reduced_motion", &"master_volume_percent", &"non_speech_captions", &"input_method"], "first-run preflight exposes every frozen high-impact setting")
	var deck := settings.deck_acceptance_profile()
	_expect_equal(deck.get("resolution"), [1280, 800], "Steam Deck acceptance target is 1280x800")
	_expect(int(deck.get("maximum_ui_scale_percent", 0)) >= 200, "maximum UI scale meets the 200 percent stress target")
	_expect(not bool(deck.get("touch_required", true)), "Deck touch screen is not required")
	_expect(not bool(deck.get("trackpad_required", true)), "Deck trackpad is not required")
	_expect(bool(deck.get("mandatory_controls_must_remain_reachable", false)), "Deck profile keeps mandatory controls reachable")

	var applied := settings.apply_patch({
		"ui_scale_percent": 200,
		"reduced_motion": true,
		"reduced_flashing": true,
		"master_volume_percent": 0,
		"non_speech_captions": true,
		"input_method": "steam_deck",
	})
	_expect(bool(applied.get("ok", false)), "maximum-scale no-audio reduced-presentation Deck profile is accepted")
	var snapshot := settings.snapshot()
	_expect_equal(snapshot.get("ui_scale_percent"), 200, "maximum UI scale persists in model")
	_expect(bool(snapshot.get("reduced_motion", false)), "reduced motion persists in model")
	_expect(bool(snapshot.get("reduced_flashing", false)), "reduced flashing persists in model")
	_expect_equal(snapshot.get("master_volume_percent"), 0, "master audio can be zero")
	_expect_equal(snapshot.get("input_method"), &"steam_deck", "Steam Deck input method can be selected without pointer requirement")

	var safety := settings.presentation_safety_policy()
	_expect(bool(safety.get("simulation_authority_unchanged", false)), "accessibility presentation cannot alter simulation authority")
	_expect(bool(safety.get("audio_cues_require_visual_equivalent", false)), "no-audio path requires visual equivalents")
	_expect(bool(safety.get("critical_states_require_non_color_signal", false)), "critical state language is not color-only")
	_expect(bool(safety.get("rule_text_must_wrap_or_scroll", false)), "rule text remains accessible instead of truncated")

	var invalid_scale := settings.apply_patch({"ui_scale_percent": 201})
	_expect(not bool(invalid_scale.get("ok", true)), "unsupported UI scale is rejected rather than silently hiding controls")

func _test_critical_signal_and_reduced_presentation_application() -> void:
	var settings: AccessibilitySettingsModel = AccessibilitySettingsModelScript.new()
	var applied := settings.apply_patch({
		"reduced_motion": true,
		"reduced_flashing": true,
		"master_volume_percent": 0,
		"non_speech_captions": false,
	})
	_expect(bool(applied.get("ok", false)), "reduced no-audio presentation profile applies")

	for kind: StringName in AccessibilitySettingsModelScript.CRITICAL_SIGNAL_KINDS:
		var signal_data := settings.critical_signal(kind, "Transit")
		_expect(bool(signal_data.get("ok", false)), "%s critical signal is representable" % String(kind))
		_expect(bool(signal_data.get("caption_visible", false)), "%s remains caption-visible when audio is unavailable" % String(kind))
		_expect(not String(signal_data.get("text_label", "")).is_empty(), "%s exposes a text label" % String(kind))
		_expect(not String(signal_data.get("icon", "")).is_empty(), "%s exposes a non-color icon" % String(kind))
		_expect(not String(signal_data.get("pattern", "")).is_empty(), "%s exposes a non-color pattern" % String(kind))
		_expect(not String(signal_data.get("shape", "")).is_empty(), "%s exposes a non-color shape" % String(kind))
		_expect_equal(signal_data.get("motion_mode"), "snap_fade", "%s uses reduced-motion snap/fade presentation" % String(kind))
		_expect_equal(signal_data.get("overlay_motion"), "static_pattern", "%s removes scrolling/particle dependence" % String(kind))
		_expect_equal(signal_data.get("flash_mode"), "persistent_outline", "%s uses reduced-flashing persistent emphasis" % String(kind))
		_expect(not bool(signal_data.get("full_screen_flash", true)), "%s never requires a full-screen flash" % String(kind))
		_expect(not bool(signal_data.get("authoritative_simulation_changed", true)), "%s presentation does not change simulation authority" % String(kind))

	var heat := settings.critical_signal(&"hazard_onset", "Heat Surge", "route segment active", &"heat")
	_expect_equal(heat.get("icon"), "heat", "heat channel uses frozen heat icon")
	_expect_equal(heat.get("pattern"), "thermal_lines", "heat channel uses frozen thermal-line pattern")
	_expect(String(heat.get("caption", "")).contains("Heat Surge — hazard started"), "hazard caption identifies source explicitly")

	var stress := settings.critical_signal(&"alarm_panic", "Ember Pod", "panic threshold crossed", &"stress")
	_expect_equal(stress.get("icon"), "stress", "stress channel uses frozen stress icon")
	_expect_equal(stress.get("pattern"), "jagged_ripple", "stress channel uses frozen ripple/jagged pattern")
	_expect(not bool(stress.get("camera_shake", true)), "Reduced Motion disables alarm camera shake")

	var contamination := settings.critical_signal(&"state_transition", "Cargo B", "contaminated", &"contamination")
	_expect_equal(contamination.get("icon"), "contamination", "contamination channel uses frozen contamination icon")
	_expect_equal(contamination.get("pattern"), "particulate_mottle", "contamination channel uses frozen particulate/mottled pattern")

	var brownout := settings.critical_signal(&"brownout_power_loss", "Cooler", "priority shed")
	_expect_equal(brownout.get("icon"), "slashed_power", "Brownout uses explicit slashed-power symbol")
	_expect(String(brownout.get("caption", "")).contains("Cooler — power lost"), "Brownout caption identifies affected support")

	var failure := settings.critical_signal(&"predicate_failure", "Objective M1", "temperature exceeded")
	_expect_equal(failure.get("text_label"), "FAILURE", "mandatory predicate failure is labeled in text")
	_expect(String(failure.get("caption", "")).contains("Objective M1 — mandatory objective failed"), "failure caption names the predicate source")

	var completion := settings.critical_signal(&"transit_completion", "Route", "review ready")
	_expect_equal(completion.get("text_label"), "TRANSIT COMPLETE", "transit completion is explicit without audio")
	_expect(not bool(completion.get("audio_available", true)), "no-audio profile never depends on completion sound")

	var invalid := settings.critical_signal(&"not_a_real_signal", "System")
	_expect(not bool(invalid.get("ok", true)), "unknown presentation signal is rejected explicitly")
	_expect_equal(String(invalid.get("error", "")), "unknown_critical_signal", "unknown signal rejection is deterministic")

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
		print("phase12e_input_accessibility_test_runner: PASS")
		quit(0)
	else:
		push_error("phase12e_input_accessibility_test_runner: %d failure(s)" % failures)
		quit(1)
