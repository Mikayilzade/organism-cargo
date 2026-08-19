extends SceneTree

const AppBootstrapServiceScript := preload("res://src/app/app_bootstrap_service.gd")

const CORE_CONTENT_PATHS: Dictionary = {
	&"body_plans": "res://content/body_plans",
	&"campaign": "res://content/campaign",
	&"challenges": "res://content/challenges",
	&"contracts": "res://content/contracts",
	&"hazards": "res://content/hazards",
	&"holds": "res://content/holds",
	&"routes": "res://content/routes",
	&"species": "res://content/species",
	&"supports": "res://content/supports",
	&"traits": "res://content/traits",
}

func _init() -> void:
	var service = AppBootstrapServiceScript.new()
	var result: Dictionary = service.boot(CORE_CONTENT_PATHS)
	_assert_true(bool(result.get("ok", false)), "production core content paths must boot")
	_assert_equal(String(result.get("content_version", "")), "vertical-slice-1", "content version")
	_assert_true(service.content_ready(), "bootstrap service must own ready content")
	print("PASS shell_content_boot_test_runner")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error("ASSERT TRUE FAILED: %s" % message)
		quit(1)

func _assert_equal(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		push_error("ASSERT EQUAL FAILED: %s actual=%s expected=%s" % [message, actual, expected])
		quit(1)
