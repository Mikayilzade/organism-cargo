extends SceneTree

const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var evidence_path := ""
	var json_out := ""
	var text_out := ""
	for arg: String in args:
		if arg.begins_with("--evidence="):
			evidence_path = arg.trim_prefix("--evidence=")
		elif arg.begins_with("--json-out="):
			json_out = arg.trim_prefix("--json-out=")
		elif arg.begins_with("--text-out="):
			text_out = arg.trim_prefix("--text-out=")
	if evidence_path.is_empty():
		push_error("Usage: -- --evidence=<path> [--json-out=<path> --text-out=<path>]")
		quit(2)
		return
	var service: Phase12GEvidenceReportService = ReportServiceScript.new()
	var loaded: Dictionary = service.load_external_json(evidence_path)
	if not bool(loaded.get("ok", false)):
		push_error("Evidence import failed: %s" % String(loaded.get("error", "unknown")))
		quit(2)
		return
	var report: Dictionary = service.evaluate_operator_dataset(loaded["dataset"])
	print(service.human_readable_report(report))
	if not bool(report.get("ok", false)):
		quit(2)
		return
	if not json_out.is_empty() or not text_out.is_empty():
		if json_out.is_empty() or text_out.is_empty():
			push_error("Both --json-out and --text-out are required when writing reports.")
			quit(2)
			return
		var written: Dictionary = service.write_report_files(report, json_out, text_out)
		if not bool(written.get("ok", false)):
			push_error("Report write failed: %s" % String(written.get("error", "unknown")))
			quit(2)
			return
	quit(0)
