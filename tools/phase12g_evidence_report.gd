extends SceneTree

const ReportServiceScript := preload("res://src/validation/phase12g_evidence_report_service.gd")
const StudyInfrastructureScript := preload("res://src/validation/phase12g_study_infrastructure.gd")

func _init() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var evidence_paths: Array[String] = []
    var json_out: String = ""
    var text_out: String = ""
    for arg: String in args:
        if arg.begins_with("--evidence="):
            var path: String = arg.trim_prefix("--evidence=").strip_edges()
            if not path.is_empty():
                evidence_paths.append(path)
        elif arg.begins_with("--json-out="):
            json_out = arg.trim_prefix("--json-out=")
        elif arg.begins_with("--text-out="):
            text_out = arg.trim_prefix("--text-out=")
    if evidence_paths.is_empty():
        push_error("Usage: -- --evidence=<path> [--evidence=<path> ...] [--json-out=<path> --text-out=<path>]")
        quit(2)
        return

    var service: Phase12GEvidenceReportService = ReportServiceScript.new()
    var report: Dictionary = {}
    if evidence_paths.size() == 1:
        var loaded: Dictionary = service.load_external_json(evidence_paths[0])
        if not bool(loaded.get("ok", false)):
            push_error("Evidence import failed: %s" % String(loaded.get("error", "unknown")))
            quit(2)
            return
        report = service.evaluate_operator_dataset(loaded["dataset"])
    else:
        var infrastructure: Phase12GStudyInfrastructure = StudyInfrastructureScript.new()
        var merged: Dictionary = infrastructure.merge_operator_files(evidence_paths)
        if not bool(merged.get("ok", false)):
            push_error("Evidence merge failed: %s" % String(merged.get("error", "unknown")))
            quit(2)
            return
        report = (merged.get("report", {}) as Dictionary).duplicate(true)
        report["aggregate_checksum"] = String(merged.get("aggregate_checksum", ""))
        report["source_manifest"] = (merged.get("source_manifest", []) as Array).duplicate(true)

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
