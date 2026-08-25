class_name Phase12GEmpiricalEvidenceStore
extends RefCounted

const EvaluatorScript := preload("res://src/validation/phase12g_empirical_evidence_evaluator.gd")

var _path: String
var _evaluator: Phase12GEmpiricalEvidenceEvaluator

func _init(path: String) -> void:
	_path = path
	_evaluator = EvaluatorScript.new()

func load_dataset() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return {"ok": true, "error": "", "dataset": {"schema_version": EvaluatorScript.SCHEMA_VERSION, "samples": []}}
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return _failure("open_read_failed")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _failure("dataset_json_not_dictionary")
	var dataset: Dictionary = parsed
	var validation: Dictionary = _evaluator.validate_dataset(dataset)
	if not bool(validation.get("ok", false)):
		return _failure("invalid_dataset:%s" % String(validation.get("error", "unknown")))
	return {"ok": true, "error": "", "dataset": dataset.duplicate(true)}

func append_sample(sample: Dictionary) -> Dictionary:
	var loaded: Dictionary = load_dataset()
	if not bool(loaded.get("ok", false)):
		return loaded
	var dataset: Dictionary = loaded["dataset"]
	var samples: Array = dataset.get("samples", [])
	samples.append(sample.duplicate(true))
	dataset["samples"] = samples
	var validation: Dictionary = _evaluator.validate_dataset(dataset)
	if not bool(validation.get("ok", false)):
		return _failure("sample_rejected:%s" % String(validation.get("error", "unknown")))
	var write_result: Dictionary = _atomic_write(dataset)
	if not bool(write_result.get("ok", false)):
		return write_result
	return {"ok": true, "error": "", "sample_count": samples.size(), "dataset": dataset.duplicate(true)}

func evaluate_current() -> Dictionary:
	var loaded: Dictionary = load_dataset()
	if not bool(loaded.get("ok", false)):
		return {"ok": false, "error": String(loaded.get("error", "load_failed")), "overall_status": "INVALID", "gates": {}}
	return _evaluator.evaluate(loaded["dataset"])

func _atomic_write(dataset: Dictionary) -> Dictionary:
	var absolute_path: String = ProjectSettings.globalize_path(_path)
	var directory: String = absolute_path.get_base_dir()
	if not directory.is_empty():
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			return _failure("mkdir_failed:%d" % mkdir_error)
	var temp_path := "%s.tmp" % absolute_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _failure("open_write_failed")
	file.store_string(JSON.stringify(dataset, "  ", true, true))
	file.flush()
	file.close()
	if FileAccess.file_exists(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _failure("replace_remove_failed:%d" % remove_error)
	var rename_error := DirAccess.rename_absolute(temp_path, absolute_path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _failure("rename_failed:%d" % rename_error)
	return {"ok": true, "error": ""}

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
