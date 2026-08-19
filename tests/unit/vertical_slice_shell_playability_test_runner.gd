extends SceneTree

const ShellScript := preload("res://src/app/shell.gd")

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell := ShellScript.new()
	root.add_child(shell)
	await process_frame

	var control: VerticalSliceControl = shell.slice_control()
	var flow: VerticalSliceFlowCoordinator = shell.flow_controller()
	_expect(control != null, "persistent shell owns the player-facing vertical slice control")
	_expect(flow != null, "persistent shell owns the vertical slice flow coordinator")
	if control == null or flow == null:
		_finish(shell)
		return

	_expect(flow.current_state() == AppStateMachine.State.TITLE, "production shell boots into Title")
	_expect(bool(control.activate_primary_action().get("ok", false)), "Title -> Campaign Map through shell control")
	_expect(bool(control.activate_primary_action().get("ok", false)), "Campaign Map -> Contract Brief through shell control")
	_expect(bool(control.activate_primary_action().get("ok", false)), "Contract Brief -> Planning through shell control")
	_expect(flow.current_state() == AppStateMachine.State.PLANNING, "shell reaches Planning without test-only plan injection")

	_expect(bool(control.planning_select_manifest("specimen-a").get("ok", false)), "select specimen-a from production manifest")
	_expect(bool(control.planning_activate_focused_cell().get("ok", false)), "place specimen-a at focused [0,0]")
	_expect(bool(control.planning_select_manifest("specimen-b").get("ok", false)), "select specimen-b from production manifest")
	_expect(bool(control.planning_move_focus(1, 1).get("ok", false)), "move logical focus to [1,1]")
	_expect(bool(control.planning_activate_focused_cell().get("ok", false)), "place specimen-b through production planning surface")

	var planning_snapshot: Dictionary = flow.planning_snapshot()
	_expect(bool(planning_snapshot.get("structural_legal", false)), "player-built shell plan is structurally legal through canonical resolver")
	_expect(bool(control.activate_primary_action().get("ok", false)), "Planning -> Launch Confirmation")
	_expect(flow.current_state() == AppStateMachine.State.LAUNCH_CONFIRM, "Launch remains a deliberate confirmation state")
	_expect(bool(control.activate_primary_action().get("ok", false)), "confirmed Launch durably enters Transit")
	_expect(flow.current_state() == AppStateMachine.State.TRANSIT_PLAYBACK, "shell owns deterministic Transit playback")
	_expect(bool(control.activate_primary_action().get("ok", false)), "Transit resolves into Causal Review")
	_expect(flow.current_state() == AppStateMachine.State.CAUSAL_REVIEW, "shell reaches Causal Review")

	var review_snapshot: Dictionary = flow.review_snapshot()
	_expect(bool(review_snapshot.get("ok", false)), "Causal Review evidence is available through shell-owned flow")
	_expect(bool(control.activate_primary_action().get("ok", false)), "targeted Retry returns from Causal Review")
	_expect(flow.current_state() == AppStateMachine.State.PLANNING, "targeted Retry returns to Planning")

	var retry_snapshot: Dictionary = flow.planning_snapshot()
	_expect(bool(retry_snapshot.get("ok", false)), "targeted Retry restores a planning revision")
	_finish(shell)

func _finish(shell: Control) -> void:
	if is_instance_valid(shell):
		shell.queue_free()
	if failures == 0:
		print("vertical_slice_shell_playability_test_runner: PASS")
		quit(0)
	else:
		push_error("vertical_slice_shell_playability_test_runner: %d failure(s)" % failures)
		quit(1)

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)
