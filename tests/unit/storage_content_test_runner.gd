extends SceneTree

const ContentLoaderScript := preload("res://src/content/content_loader.gd")
const AtomicSaveStoreScript := preload("res://src/save/atomic_save_store.gd")

var failures: int = 0
var test_root: String = "user://organism_cargo_storage_tests"

func _initialize() -> void:
	_reset_test_root()
	_test_file_backed_content_loading()
	_test_duplicate_content_id_rejected()
	_test_atomic_save_and_backup_recovery()
	_test_settings_isolation()
	_reset_test_root()
	if failures == 0:
		print("STORAGE CONTENT TESTS PASS")
		quit(0)
	else:
		push_error("STORAGE CONTENT TESTS FAIL: %d" % failures)
		quit(1)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _expect_true(actual: bool, label: String) -> void:
	_expect_equal(actual, true, label)

func _test_file_backed_content_loading() -> void:
	var result: Dictionary = ContentLoaderScript.load_directory("res://tests/fixtures/content_bootstrap", &"species")
	_expect_true(result["ok"], "bootstrap fixture directory loads")
	if result["ok"]:
		var documents: Dictionary = result["documents"]
		_expect_equal(documents.size(), 2, "two bootstrap documents loaded")
		_expect_true(documents.has(&"species_bootstrap_a"), "stable id A indexed")
		_expect_true(documents.has(&"species_bootstrap_b"), "stable id B indexed")

func _test_duplicate_content_id_rejected() -> void:
	var duplicate_dir: String = test_root.path_join("duplicate_content")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(duplicate_dir))
	var shared_id_json: String = '{"schema_version":1,"content_version":"bootstrap-c0","kind":"species","id":"same_id","payload":{}}'
	_write_raw(duplicate_dir.path_join("a.json"), shared_id_json)
	_write_raw(duplicate_dir.path_join("b.json"), shared_id_json)
	var result: Dictionary = ContentLoaderScript.load_directory(duplicate_dir, &"species")
	_expect_equal(result["ok"], false, "duplicate id rejected")
	_expect_equal(result["error"], "duplicate_id:same_id", "duplicate id diagnostic")

func _test_atomic_save_and_backup_recovery() -> void:
	var store: RefCounted = AtomicSaveStoreScript.new(test_root.path_join("saves"))
	var first: Dictionary = store.write(&"profile", {"profile_uuid": "p1", "bronze": ["C01"]})
	_expect_true(first["ok"], "first profile generation written")
	var second: Dictionary = store.write(&"profile", {"profile_uuid": "p1", "bronze": ["C01", "C02"]})
	_expect_true(second["ok"], "second profile generation written")
	var loaded: Dictionary = store.load(&"profile")
	_expect_true(loaded["ok"], "primary profile loads")
	if loaded["ok"]:
		_expect_equal(loaded["source"], "primary", "primary preferred")
		_expect_equal(loaded["envelope"].payload["bronze"].size(), 2, "newest primary payload")

	var paths: Dictionary = store.paths_for(&"profile")
	var primary_text: String = FileAccess.get_file_as_string(paths["primary"])
	_write_raw(paths["primary"], primary_text.replace("C02", "BROKEN"))
	var recovered: Dictionary = store.load(&"profile")
	_expect_true(recovered["ok"], "backup recovered after tamper")
	if recovered["ok"]:
		_expect_equal(recovered["source"], "backup", "backup source selected")
		_expect_equal(recovered["envelope"].payload["bronze"].size(), 1, "backup preserves previous generation")

func _test_settings_isolation() -> void:
	var store: RefCounted = AtomicSaveStoreScript.new(test_root.path_join("isolation"))
	_expect_true(store.write(&"profile", {"profile_uuid": "p2", "bronze": []})["ok"], "profile written for isolation")
	_expect_true(store.write(&"settings", {"ui_scale": 125})["ok"], "settings written separately")
	var settings_paths: Dictionary = store.paths_for(&"settings")
	var settings_text: String = FileAccess.get_file_as_string(settings_paths["primary"])
	_write_raw(settings_paths["primary"], settings_text.replace("125", "999"))
	var broken_settings: Dictionary = store.load(&"settings")
	var intact_profile: Dictionary = store.load(&"profile")
	_expect_equal(broken_settings["ok"], false, "tampered settings rejected independently")
	_expect_true(intact_profile["ok"], "profile remains loadable after settings corruption")

func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("failed to open test file: %s" % path)
		return
	file.store_string(text)
	file.flush()
	file.close()

func _reset_test_root() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(test_root)
	if DirAccess.dir_exists_absolute(absolute_root):
		_remove_tree(absolute_root)
	DirAccess.make_dir_recursive_absolute(absolute_root)

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for child: String in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
