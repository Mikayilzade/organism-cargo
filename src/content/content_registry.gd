class_name ContentRegistry
extends RefCounted

const ContentLoaderScript := preload("res://src/content/content_loader.gd")

var _documents_by_kind: Dictionary = {}
var _content_version: String = ""

func load_families(family_paths: Dictionary) -> Dictionary:
	_documents_by_kind.clear()
	_content_version = ""
	var kinds: Array[StringName] = []
	for raw_kind: Variant in family_paths.keys():
		kinds.append(StringName(raw_kind))
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	for kind: StringName in kinds:
		var path: String = String(family_paths[kind])
		var loaded: Dictionary = ContentLoaderScript.load_directory(path, kind)
		if not loaded["ok"]:
			return {"ok": false, "error": "%s:%s" % [String(kind), loaded["error"]]}
		var by_id: Dictionary = loaded["documents"]
		var ids: Array[StringName] = []
		for raw_id: Variant in by_id.keys():
			ids.append(StringName(raw_id))
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		var ordered: Array[ContentDocument] = []
		for id: StringName in ids:
			var document: ContentDocument = by_id[id]
			if _content_version.is_empty():
				_content_version = document.content_version
			elif document.content_version != _content_version:
				return {"ok": false, "error": "content_version_mismatch:%s" % String(id)}
			ordered.append(document)
		_documents_by_kind[kind] = ordered
	return {"ok": true, "error": ""}

func has_kind(kind: StringName) -> bool:
	return _documents_by_kind.has(kind)

func ordered_documents(kind: StringName) -> Array[ContentDocument]:
	if not _documents_by_kind.has(kind):
		return []
	return (_documents_by_kind[kind] as Array[ContentDocument]).duplicate()

func content_version() -> String:
	return _content_version
