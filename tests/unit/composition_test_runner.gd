extends SceneTree

const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")

var failures: int = 0

func _init() -> void:
	_test_registry_order_and_family_validation()
	_test_app_state_ownership()
	if failures == 0:
		print("composition_test_runner: PASS")
		quit(0)
	else:
		push_error("composition_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_registry_order_and_family_validation() -> void:
	var registry: ContentRegistry = ContentRegistryScript.new()
	var loaded: Dictionary = registry.load_families({&"species": "res://tests/fixtures/content_bootstrap"})
	_expect_true(loaded["ok"], "registry loads expected family")
	_expect_equal(registry.content_version(), "bootstrap-c0", "registry content version")
	var ordered: Array[ContentDocument] = registry.ordered_documents(&"species")
	_expect_equal(ordered.size(), 2, "registry document count")
	if ordered.size() == 2:
		_expect_equal(String(ordered[0].id), "species_bootstrap_a", "registry stable first id")
		_expect_equal(String(ordered[1].id), "species_bootstrap_b", "registry stable second id")

	var wrong_family_registry: ContentRegistry = ContentRegistryScript.new()
	var rejected: Dictionary = wrong_family_registry.load_families({&"support": "res://tests/fixtures/content_bootstrap"})
	_expect_true(not rejected["ok"], "registry rejects wrong content family")

func _test_app_state_ownership() -> void:
	var state_machine: AppStateMachine = AppStateMachineScript.new()
	_expect_equal(state_machine.current_state(), AppStateMachine.State.BOOT, "state machine starts at boot")
	_expect_true(not state_machine.transition_to(AppStateMachine.State.PLANNING), "illegal boot to planning rejected")
	_expect_true(state_machine.transition_to(AppStateMachine.State.TITLE), "boot to title allowed")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CAMPAIGN_MAP), "title to campaign map allowed")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CONTRACT_BRIEF), "campaign map to brief allowed")
	_expect_true(state_machine.transition_to(AppStateMachine.State.PLANNING), "brief to planning allowed")
	_expect_true(state_machine.transition_to(AppStateMachine.State.LAUNCH_CONFIRM), "planning to launch confirm allowed")
	_expect_true(state_machine.transition_to(AppStateMachine.State.TRANSIT_PLAYBACK), "launch confirm to transit allowed")
	_expect_true(not state_machine.transition_to(AppStateMachine.State.RESULTS), "transit cannot bypass causal review")
	_expect_true(state_machine.transition_to(AppStateMachine.State.CAUSAL_REVIEW), "transit to causal review allowed")
	_expect_true(state_machine.transition_to(AppStateMachine.State.RESULTS), "causal review to results allowed")

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
