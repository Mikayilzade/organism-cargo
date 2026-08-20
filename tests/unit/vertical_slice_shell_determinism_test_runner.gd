extends SceneTree

const ShellScript := preload("res://src/app/shell.gd")
const SHELL_SAVE_ROOT := "user://organism_cargo"

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_shell_session()
	var first: Dictionary = await _run_lifecycle("first")
	_clear_shell_session()
	var second: Dictionary = await _run_lifecycle("second")
	_clear_shell_session()

	_expect(bool(first.get("ok", false)), "first isolated shell lifecycle completes")
	_expect(bool(second.get("ok", false)), "second isolated shell lifecycle completes")
	if bool(first.get("ok", false)) and bool(second.get("ok", false)):
		_expect(first["canonical_input"] == second["canonical_input"], "equivalent player-built inputs canonicalize identically")
		_expect(String(first["committed_input_checksum"]) == String(second["committed_input_checksum"]), "committed input checksum reproduces across isolated launches")
		_expect(first["tick_checksums"] == second["tick_checksums"], "authoritative transit tick checksum sequence reproduces")
		_expect(String(first["completion_checksum"]) == String(second["completion_checksum"]), "authoritative completion checksum reproduces")
		_expect(String(first["review_checksum"]) == String(second["review_checksum"]), "Causal Review checksum reproduces")
		_expect(String(first["run_id"]) != String(second["run_id"]), "isolated launches keep distinct run identities")

	if failures == 0:
		print("vertical_slice_shell_determinism_test_runner: PASS")
		quit(0)
	else:
		push_error("vertical_slice_shell_determinism_test_runner: %d failure(s)" % failures)
		quit(1)

func _run_lifecycle(label: String) -> Dictionary:
	var shell := ShellScript.new()
	root.add_child(shell)
	await process_frame

	var control: VerticalSliceControl = shell.slice_control()
	var flow: VerticalSliceFlowCoordinator = shell.flow_controller()
	if control == null or flow == null:
		push_error("FAIL: %s shell composition unavailable" % label)
		failures += 1
		_dispose_shell(shell)
		return {"ok": false}

	var steps_ok: bool = true
	steps_ok = steps_ok and bool(control.activate_primary_action().get("ok", false))
	steps_ok = steps_ok and bool(control.activate_primary_action().get("ok", false))
	steps_ok = steps_ok and bool(control.activate_primary_action().get("ok", false))
	steps_ok = steps_ok and bool(control.planning_select_manifest("specimen-a").get("ok", false))
	steps_ok = steps_ok and bool(control.planning_activate_focused_cell().get("ok", false))
	steps_ok = steps_ok and bool(control.planning_select_manifest("specimen-b").get("ok", false))
	steps_ok = steps_ok and bool(control.planning_move_focus(1, 1).get("ok", false))
	steps_ok = steps_ok and bool(control.planning_activate_focused_cell().get("ok", false))
	if not steps_ok:
		push_error("FAIL: %s player-built planning path" % label)
		failures += 1
		_dispose_shell(shell)
		return {"ok": false}

	var planning: Dictionary = flow.planning_snapshot()
	if not bool(planning.get("structural_legal", false)):
		push_error("FAIL: %s structural legality" % label)
		failures += 1
		_dispose_shell(shell)
		return {"ok": false}
	var canonical_input: Dictionary = planning.get("canonical_input", {}).duplicate(true)

	var confirm: Dictionary = control.activate_primary_action()
	if not bool(confirm.get("ok", false)):
		push_error("FAIL: %s launch confirmation" % label)
		failures += 1
		_dispose_shell(shell)
		return {"ok": false}
	var launch: Dictionary = control.activate_primary_action()
	if not bool(launch.get("ok", false)):
		push_error("FAIL: %s durable launch" % label)
		failures += 1
		_dispose_shell(shell)
		return {"ok": false}
	var committed_run_value: Variant = launch.get("committed_run", null)
	if not committed_run_value is Dictionary:
		push_error("FAIL: %s committed run missing" % label)
		failures += 1
		_dispose_shell(shell)
		return {"ok": false}
	var committed_run: Dictionary = committed_run_value

	var transit: Dictionary = control.activate_primary_action()
	if not bool(transit.get("ok", false)):
		push_error("FAIL: %s deterministic transit completion" % label)
		failures += 1
		_dispose_shell(shell)
		return {"ok": false}
	var completed: Dictionary = flow.last_completed_result()
	var review: Dictionary = flow.last_review()
	var tick_checksums: PackedStringArray = completed.get("tick_checksums", PackedStringArray())
	var result: Dictionary = {
		"ok": true,
		"canonical_input": canonical_input,
		"run_id": String(committed_run.get("run_id", "")),
		"committed_input_checksum": String(committed_run.get("committed_input_checksum", "")),
		"tick_checksums": tick_checksums.duplicate(),
		"completion_checksum": String(completed.get("completion_checksum", "")),
		"review_checksum": String(review.get("review_checksum", "")),
	}
	_dispose_shell(shell)
	await process_frame
	return result

func _dispose_shell(shell: Control) -> void:
	if is_instance_valid(shell):
		shell.queue_free()

func _clear_shell_session() -> void:
	_remove_if_exists(SHELL_SAVE_ROOT.path_join("session.sav"))
	_remove_if_exists(SHELL_SAVE_ROOT.path_join("session.sav.bak"))
	_remove_if_exists(SHELL_SAVE_ROOT.path_join("session.sav.tmp"))

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)
