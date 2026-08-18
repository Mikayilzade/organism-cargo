class_name ContentLoader
extends RefCounted

const ContentDocumentScript := preload("res://src/content/content_document.gd")

static func load_directory(path: String, expected_kind: StringName = &"") -> Dictionary:
	var directory := DirAccess.open(path)
	if directory == null:
		return {"ok": false, "error": "directory_unavailable", "documents": {}}

	var filenames: PackedStringArray = directory.get_files()
	filenames.sort()
	var documents: Dictionary = {}
	for filename: String in filenames:
		if filename.get_extension().to_lower() != "json":
			continue
		var full_path: String = path.path_join(filename)
		var text: String = FileAccess.get_file_as_string(full_path)
		if text.is_empty() and FileAccess.get_open_error() != OK:
			return {"ok": false, "error": "read_failed:%s" % filename, "documents": {}}
		var document: RefCounted = ContentDocumentScript.parse_utf8_json(text, expected_kind)
		if document == null:
			return {"ok": false, "error": "invalid_document:%s" % filename, "documents": {}}
		var stable_id: StringName = document.id
		if documents.has(stable_id):
			return {"ok": false, "error": "duplicate_id:%s" % String(stable_id), "documents": {}}
		documents[stable_id] = document

	return {"ok": true, "error": "", "documents": documents}
