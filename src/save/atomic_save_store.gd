class_name AtomicSaveStore
extends RefCounted

const SaveEnvelopeScript := preload("res://src/save/save_envelope.gd")

var root_dir: String

func _init(p_root_dir: String) -> void:
	root_dir = p_root_dir

func write(kind: StringName, payload: Dictionary) -> Dictionary:
	if not _is_supported_kind(kind):
		return {"ok": false, "error": "unsupported_kind"}
	var ensure_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_dir))
	if ensure_error != OK and ensure_error != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "mkdir_failed:%d" % ensure_error}

	var primary: String = _path(kind, ".sav")
	var temp: String = _path(kind, ".sav.tmp")
	var backup: String = _path(kind, ".sav.bak")
	var envelope: RefCounted = SaveEnvelopeScript.create(kind, payload)
	var serialized: String = envelope.serialize()

	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "temp_open_failed:%d" % FileAccess.get_open_error()}
	file.store_string(serialized)
	file.flush()
	file.close()

	var verify_text: String = FileAccess.get_file_as_string(temp)
	if SaveEnvelopeScript.parse_and_validate(verify_text, kind) == null:
		_remove_if_exists(temp)
		return {"ok": false, "error": "temp_verify_failed"}

	if FileAccess.file_exists(primary):
		_remove_if_exists(backup)
		var backup_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(primary),
			ProjectSettings.globalize_path(backup)
		)
		if backup_error != OK:
			_remove_if_exists(temp)
			return {"ok": false, "error": "backup_failed:%d" % backup_error}

	var install_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp),
		ProjectSettings.globalize_path(primary)
	)
	if install_error != OK:
		if FileAccess.file_exists(backup) and not FileAccess.file_exists(primary):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(primary))
		_remove_if_exists(temp)
		return {"ok": false, "error": "install_failed:%d" % install_error}

	return {"ok": true, "error": ""}

func load(kind: StringName) -> Dictionary:
	if not _is_supported_kind(kind):
		return {"ok": false, "error": "unsupported_kind", "source": "", "envelope": null}
	var primary_result: Dictionary = _load_path(_path(kind, ".sav"), kind)
	if primary_result["ok"]:
		primary_result["source"] = "primary"
		return primary_result
	var backup_result: Dictionary = _load_path(_path(kind, ".sav.bak"), kind)
	if backup_result["ok"]:
		backup_result["source"] = "backup"
		return backup_result
	return {"ok": false, "error": "no_valid_generation", "source": "", "envelope": null}

func paths_for(kind: StringName) -> Dictionary:
	return {
		"primary": _path(kind, ".sav"),
		"temp": _path(kind, ".sav.tmp"),
		"backup": _path(kind, ".sav.bak"),
	}

func _load_path(path: String, kind: StringName) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing", "envelope": null}
	var text: String = FileAccess.get_file_as_string(path)
	var envelope: RefCounted = SaveEnvelopeScript.parse_and_validate(text, kind)
	if envelope == null:
		return {"ok": false, "error": "invalid", "envelope": null}
	return {"ok": true, "error": "", "envelope": envelope}

func _path(kind: StringName, suffix: String) -> String:
	return root_dir.path_join(String(kind) + suffix)

static func _is_supported_kind(kind: StringName) -> bool:
	return kind == &"profile" or kind == &"session" or kind == &"settings"

static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
