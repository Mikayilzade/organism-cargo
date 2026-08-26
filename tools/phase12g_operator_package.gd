extends SceneTree

const OperatorServiceScript := preload("res://src/validation/phase12g_operator_package_service.gd")

func _init() -> void:
	var service: Phase12GOperatorPackageService = OperatorServiceScript.new()
	var parsed: Dictionary = service.options_from_args(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		push_error("Phase 12G operator tool arguments invalid: %s" % String(parsed.get("error", "unknown")))
		_print_usage()
		quit(2)
		return
	var options_value: Variant = parsed.get("options", {})
	if not options_value is Dictionary:
		push_error("Phase 12G operator tool internal options invalid")
		quit(2)
		return
	var result: Dictionary = service.execute(options_value as Dictionary)
	if not bool(result.get("ok", false)):
		push_error("Phase 12G operator tool failed: %s" % String(result.get("error", "unknown")))
		quit(2)
		return
	_print_result(result)
	quit(0)

func _print_result(result: Dictionary) -> void:
	var mode: String = String(result.get("mode", ""))
	print("PHASE 12G OPERATOR PACKAGE TOOL")
	print("Mode: %s%s" % [mode, " (DRY RUN)" if bool(result.get("dry_run", false)) else ""])
	match mode:
		"manifest-create", "manifest-validate":
			var session_id: String = String(result.get("session_id", ""))
			if session_id.is_empty():
				var manifest_value: Variant = result.get("manifest", {})
				if manifest_value is Dictionary:
					session_id = String((manifest_value as Dictionary).get("session_id", ""))
			print("Session: %s" % session_id)
			print("Manifest checksum: %s" % String(result.get("manifest_checksum", "")))
		"bind":
			var binding_value: Variant = result.get("session_binding", {})
			var binding: Dictionary = binding_value if binding_value is Dictionary else {}
			print("Bound session: %s" % String(binding.get("session_id", "")))
			print("Bound manifest: %s" % String(binding.get("manifest_checksum", "")))
		"package":
			print("Empirical overall: %s" % String(result.get("overall_status", "INCOMPLETE")))
			print("Certified Bronze: %s" % String(result.get("certified_bronze_state", "NOT_SUPPLIED")))
			var audit_value: Variant = result.get("audit", {})
			var audit: Dictionary = audit_value if audit_value is Dictionary else {}
			var missing_value: Variant = audit.get("missing_evidence_classes", [])
			var missing: Array = missing_value if missing_value is Array else []
			print("Missing evidence: %s" % ", ".join(missing))
		"bronze-import":
			print("Certification authority: %s" % String(result.get("certification_authority", "")))
			print("Geometry overall: %s" % String(result.get("overall_status", "INSUFFICIENT_EVIDENCE")))

func _print_usage() -> void:
	print("Usage: godot --headless --path . --script tools/phase12g_operator_package.gd -- --mode=<mode> [options]")
	print("Modes:")
	print("  manifest-create --session-id=... --prototype-build-id=... --rules-version=... --content-version=... --cohort=... --sample-type=... [--contract-id=...] --manifest-out=... [--created-at-unix=...] [--dry-run]")
	print("  manifest-validate --manifest=...")
	print("  bind --manifest=... --evidence=... --bound-out=... [--dry-run]")
	print("  package --manifest=... [--manifest=...] --evidence=... [--evidence=...] [--bronze-geometry=...] --aggregate-out=... --audit-out=... --report-json-out=... --report-text-out=... [--dry-run]")
	print("  bronze-import --bronze-export=... --trusted-authority=... [--trusted-authority=...] --geometry-out=... --geometry-report-out=... [--dry-run]")
	print("Dry-run validates/evaluates without derived writes. INCOMPLETE, FAIL, and INSUFFICIENT_EVIDENCE are evidence states, not tool errors; invalid/untrusted input exits 2.")
