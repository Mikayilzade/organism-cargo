extends SceneTree

const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")
const AppBootstrapServiceScript := preload("res://src/app/app_bootstrap_service.gd")

var failures: int = 0

func _init() -> void:
	_test_registry_order_and_family_validation()
	_test_app_state_ownership()
	_test_bootstrap_composition_root()
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

func _test_bootstrap_composition_root() -> void:
	var family_paths: Dictionary = _build_core_content_fixture()
	if family_paths.size() != AppBootstrapService.REQUIRED_CORE_FAMILIES.size():
		_expect_true(false, "core bootstrap fixture created")
		return

	var service: AppBootstrapService = AppBootstrapServiceScript.new()
	var booted: Dictionary = service.boot(family_paths)
	_expect_true(booted["ok"], "bootstrap accepts complete core content")
	_expect_true(service.content_ready(), "bootstrap exposes content only after validation")
	_expect_equal(service.state_machine().current_state(), AppStateMachine.State.TITLE, "validated bootstrap reaches title")
	_expect_equal(String(booted["content_version"]), "bootstrap-core-c0", "bootstrap exposes coherent content version")
	for kind: StringName in AppBootstrapService.REQUIRED_CORE_FAMILIES:
		_expect_true(service.content_registry().has_kind(kind), "bootstrap registry contains %s" % String(kind))

	var first_run_service: AppBootstrapService = AppBootstrapServiceScript.new()
	var first_run: Dictionary = first_run_service.boot(family_paths, true)
	_expect_true(first_run["ok"], "first-run bootstrap accepts complete core content")
	_expect_equal(first_run_service.state_machine().current_state(), AppStateMachine.State.FIRST_RUN_PREFLIGHT, "first-run bootstrap reaches preflight")

	var incomplete_paths: Dictionary = family_paths.duplicate()
	incomplete_paths.erase(&"contracts")
	var rejected_service: AppBootstrapService = AppBootstrapServiceScript.new()
	var rejected: Dictionary = rejected_service.boot(incomplete_paths)
	_expect_true(not rejected["ok"], "bootstrap rejects missing required family")
	_expect_true(not rejected_service.content_ready(), "failed bootstrap never exposes content")
	_expect_equal(rejected_service.state_machine().current_state(), AppStateMachine.State.FATAL_CONTENT_ERROR, "failed content validation reaches fatal state")
	_expect_equal(rejected_service.boot_error(), "missing_family:contracts", "bootstrap records exact fatal content reason")

func _build_core_content_fixture() -> Dictionary:
	var family_paths: Dictionary = {}
	var root: String = "user://composition_core_fixture"
	for kind: StringName in AppBootstrapService.REQUIRED_CORE_FAMILIES:
		var directory_path: String = root.path_join(String(kind))
		var absolute_path: String = ProjectSettings.globalize_path(directory_path)
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
		if directory_error != OK:
			push_error("fixture directory creation failed for %s: %s" % [String(kind), error_string(directory_error)])
			return {}
		var file_path: String = directory_path.path_join("%s_bootstrap.json" % String(kind))
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			push_error("fixture file creation failed for %s" % String(kind))
			return {}
		file.store_string(JSON.stringify({
			"schema_version": 1,
			"content_version": "bootstrap-core-c0",
			"kind": String(kind),
			"id": "%s_bootstrap" % String(kind),
			"payload": {},
		}))
		file.close()
		family_paths[kind] = directory_path
	return family_paths

func _expect_true(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("FAIL: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
