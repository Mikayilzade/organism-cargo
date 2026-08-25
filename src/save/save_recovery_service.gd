class_name SaveRecoveryService
extends RefCounted

const SaveEnvelopeScript := preload("res://src/save/save_envelope.gd")

var _store: AtomicSaveStore

func _init(store: AtomicSaveStore) -> void:
	_store = store

func assess(kind: StringName = &"profile") -> Dictionary:
	if _store == null:
		return _fail("store_not_configured")
	var paths: Dictionary = _store.paths_for(kind)
	var primary: Dictionary = _inspect_path(String(paths.get("primary", "")), kind)
	var backup: Dictionary = _inspect_path(String(paths.get("backup", "")), kind)
	var any_exists: bool = bool(primary.get("exists", false)) or bool(backup.get("exists", false))
	var status: StringName = &"fresh"
	if bool(primary.get("valid", false)):
		status = &"valid_primary"
	elif bool(backup.get("valid", false)):
		status = &"backup_available"
	elif any_exists:
		status = &"recovery_required"
	return {
		"ok": true,
		"error": "",
		"kind": kind,
		"status": status,
		"recovery_required": status in [&"backup_available", &"recovery_required"],
		"primary": primary,
		"backup": backup,
		"can_restore_backup": bool(backup.get("valid", false)),
		"can_create_new_profile": kind == &"profile",
	}

func restore_validated_backup(kind: StringName = &"profile") -> Dictionary:
	var assessment: Dictionary = assess(kind)
	if not bool(assessment.get("ok", false)):
		return assessment
	if not bool(assessment.get("can_restore_backup", false)):
		return _fail("validated_backup_unavailable")
	var paths: Dictionary = _store.paths_for(kind)
	var primary_path: String = String(paths.get("primary", ""))
	var backup_path: String = String(paths.get("backup", ""))
	var backup_text: String = FileAccess.get_file_as_string(backup_path)
	if SaveEnvelopeScript.parse_and_validate(backup_text, kind) == null:
		return _fail("backup_became_invalid")

	var diagnostics: Array[String] = []
	if FileAccess.file_exists(primary_path):
		var preserved: Dictionary = _preserve_diagnostic(primary_path, kind, "primary")
		if not bool(preserved.get("ok", false)):
			return preserved
		diagnostics.append(String(preserved.get("path", "")))

	var restore_temp: String = primary_path + ".restore.tmp"
	var written: Dictionary = _write_text_verified(restore_temp, backup_text, kind)
	if not bool(written.get("ok", false)):
		return written
	if FileAccess.file_exists(primary_path):
		var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(primary_path))
		if remove_error != OK:
			_remove_if_exists(restore_temp)
			return _fail("primary_remove_failed:%d" % remove_error)
	var install_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(restore_temp),
		ProjectSettings.globalize_path(primary_path)
	)
	if install_error != OK:
		_remove_if_exists(restore_temp)
		return _fail("restore_install_failed:%d" % install_error)
	var verified: Dictionary = _inspect_path(primary_path, kind)
	if not bool(verified.get("valid", false)):
		return _fail("restored_primary_invalid")
	return {
		"ok": true,
		"error": "",
		"action": &"restore_backup",
		"source": "backup",
		"diagnostic_paths": diagnostics,
		"primary_valid": true,
	}

func create_new_profile(profile_uuid: String) -> Dictionary:
	if profile_uuid.strip_edges().is_empty():
		return _fail("missing_profile_uuid")
	var assessment: Dictionary = assess(&"profile")
	if not bool(assessment.get("ok", false)):
		return assessment
	var paths: Dictionary = _store.paths_for(&"profile")
	var diagnostics: Array[String] = []
	for spec: Dictionary in [
		{"label": "primary", "path": String(paths.get("primary", ""))},
		{"label": "backup", "path": String(paths.get("backup", ""))},
	]:
		var path: String = String(spec["path"])
		if not FileAccess.file_exists(path):
			continue
		var preserved: Dictionary = _preserve_diagnostic(path, &"profile", String(spec["label"]))
		if not bool(preserved.get("ok", false)):
			return preserved
		diagnostics.append(String(preserved.get("path", "")))

	var payload: Dictionary = {
		"profile_uuid": profile_uuid,
		"bronze_cleared_contracts": [],
		"best_medals": {},
		"documented_facts": [],
		"applied_completion_ids": [],
	}
	var write_result: Dictionary = _store.write(&"profile", payload)
	if not bool(write_result.get("ok", false)):
		return _fail("new_profile_write_failed:%s" % String(write_result.get("error", "unknown")))
	var loaded: Dictionary = _store.load(&"profile")
	if not bool(loaded.get("ok", false)) or String(loaded.get("source", "")) != "primary":
		return _fail("new_profile_validation_failed")
	var envelope: SaveEnvelope = loaded["envelope"]
	if envelope.payload != payload:
		return _fail("new_profile_payload_mismatch")
	return {
		"ok": true,
		"error": "",
		"action": &"create_new_profile",
		"profile_uuid": profile_uuid,
		"diagnostic_paths": diagnostics,
		"profile": payload.duplicate(true),
	}

func _inspect_path(path: String, kind: StringName) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"exists": false, "valid": false, "path": path, "checksum": ""}
	var text: String = FileAccess.get_file_as_string(path)
	return {
		"exists": true,
		"valid": SaveEnvelopeScript.parse_and_validate(text, kind) != null,
		"path": path,
		"checksum": text.sha256_text(),
	}

func _preserve_diagnostic(path: String, kind: StringName, label: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var checksum: String = text.sha256_text()
	var diagnostic_path: String = "%s.corrupt.%s.%s" % [path, label, checksum.substr(0, 12)]
	if FileAccess.file_exists(diagnostic_path):
		var existing: String = FileAccess.get_file_as_string(diagnostic_path)
		if existing == text:
			return {"ok": true, "error": "", "path": diagnostic_path}
		return _fail("diagnostic_collision")
	var file: FileAccess = FileAccess.open(diagnostic_path, FileAccess.WRITE)
	if file == null:
		return _fail("diagnostic_open_failed:%d" % FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(diagnostic_path) != text:
		return _fail("diagnostic_verify_failed")
	return {"ok": true, "error": "", "path": diagnostic_path}

func _write_text_verified(path: String, text: String, kind: StringName) -> Dictionary:
	_remove_if_exists(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("recovery_temp_open_failed:%d" % FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	file.close()
	var verify_text: String = FileAccess.get_file_as_string(path)
	if SaveEnvelopeScript.parse_and_validate(verify_text, kind) == null:
		_remove_if_exists(path)
		return _fail("recovery_temp_verify_failed")
	return {"ok": true, "error": ""}

static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
