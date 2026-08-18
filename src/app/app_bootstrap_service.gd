class_name AppBootstrapService
extends RefCounted

const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")

const REQUIRED_CORE_FAMILIES: Array[StringName] = [
	&"body_plans",
	&"campaign",
	&"challenges",
	&"contracts",
	&"hazards",
	&"holds",
	&"routes",
	&"species",
	&"supports",
	&"traits",
]

var _registry: ContentRegistry = ContentRegistryScript.new()
var _state_machine: AppStateMachine = AppStateMachineScript.new()
var _content_ready: bool = false
var _boot_error: String = ""

func boot(family_paths: Dictionary, first_run: bool = false) -> Dictionary:
	if _state_machine.current_state() != AppStateMachine.State.BOOT:
		return {"ok": false, "error": "boot_already_resolved"}

	var validated: Dictionary = _validated_family_paths(family_paths)
	if not validated["ok"]:
		return _fail_boot(String(validated["error"]))

	var load_result: Dictionary = _registry.load_families(validated["paths"])
	if not load_result["ok"]:
		return _fail_boot("content_load:%s" % String(load_result["error"]))

	for kind: StringName in REQUIRED_CORE_FAMILIES:
		if _registry.ordered_documents(kind).is_empty():
			return _fail_boot("empty_family:%s" % String(kind))

	_content_ready = true
	_boot_error = ""
	var next_state: AppStateMachine.State = (
		AppStateMachine.State.FIRST_RUN_PREFLIGHT if first_run else AppStateMachine.State.TITLE
	)
	if not _state_machine.transition_to(next_state):
		_content_ready = false
		return _fail_boot("boot_transition_rejected")
	return {"ok": true, "error": "", "content_version": _registry.content_version()}

func content_ready() -> bool:
	return _content_ready

func boot_error() -> String:
	return _boot_error

func content_registry() -> ContentRegistry:
	return _registry

func state_machine() -> AppStateMachine:
	return _state_machine

func _validated_family_paths(family_paths: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for kind: StringName in REQUIRED_CORE_FAMILIES:
		if not family_paths.has(kind):
			return {"ok": false, "error": "missing_family:%s" % String(kind), "paths": {}}
		var raw_path: Variant = family_paths[kind]
		if typeof(raw_path) != TYPE_STRING:
			return {"ok": false, "error": "invalid_path_type:%s" % String(kind), "paths": {}}
		var path: String = raw_path
		if path.strip_edges().is_empty():
			return {"ok": false, "error": "empty_path:%s" % String(kind), "paths": {}}
		normalized[kind] = path
	return {"ok": true, "error": "", "paths": normalized}

func _fail_boot(error: String) -> Dictionary:
	_content_ready = false
	_boot_error = error
	if _state_machine.current_state() == AppStateMachine.State.BOOT:
		_state_machine.transition_to(AppStateMachine.State.FATAL_CONTENT_ERROR)
	return {"ok": false, "error": error}
