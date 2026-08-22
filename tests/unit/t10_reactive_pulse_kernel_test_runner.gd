extends SceneTree

const T10ReactivePulseKernelScript := preload("res://src/sim/t10_reactive_pulse_kernel.gd")

var failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_test_once_per_run_guard()
	_test_once_per_episode_guard()
	_test_max_trigger_guard()
	_test_reordered_input_is_deterministic()
	_test_recursive_same_tick_definition_rejected()
	_test_missing_guard_rejected()
	if failures.is_empty():
		print("T10 Reactive Pulse finite-trigger guard contract tests: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("T10 Reactive Pulse finite-trigger guard contract tests: FAIL (%d)" % failures.size())
	quit(1)

func _test_once_per_run_guard() -> void:
	var kernel: T10ReactivePulseKernel = T10ReactivePulseKernelScript.new()
	var definition: Dictionary = _definition("pulse-a", "PANICKED_ENTRY", "once_per_run", {"kind": "HEAT_PULSE", "magnitude": 5})
	var first: Dictionary = kernel.resolve_phase_h(2, [_trigger("e1", "PANICKED_ENTRY", "org-a")], [definition])
	_expect(bool(first.get("ok", false)), "once-per-run T10 should resolve")
	if not bool(first.get("ok", false)):
		return
	_expect((first["events"] as Array).size() == 1, "first legal once-per-run trigger should fire")
	_expect((first["effects"] as Array).size() == 1, "T10 pulse should emit authored effect evidence")
	if (first["events"] as Array).size() == 1:
		var event: Dictionary = first["events"][0]
		_expect(String(event["parent_event_ids"][0]) == "e1", "T10 pulse must retain its material trigger parent")
	var second: Dictionary = kernel.resolve_phase_h(3, [_trigger("e2", "PANICKED_ENTRY", "org-a")], [definition], first["state"])
	_expect(bool(second.get("ok", false)), "repeated once-per-run evaluation should resolve")
	if bool(second.get("ok", false)):
		_expect((second["events"] as Array).is_empty(), "once-per-run guard must suppress later matching triggers")

func _test_once_per_episode_guard() -> void:
	var kernel: T10ReactivePulseKernel = T10ReactivePulseKernelScript.new()
	var definition: Dictionary = _definition("pulse-b", "WAKE", "once_per_episode", {"kind": "CONTAMINATION_CLEANSE", "magnitude": 4})
	var same_episode: Array = [
		_trigger("wake-2", "WAKE", "org-a", "sleep-1"),
		_trigger("wake-1", "WAKE", "org-a", "sleep-1"),
	]
	var first: Dictionary = kernel.resolve_phase_h(4, same_episode, [definition])
	_expect(bool(first.get("ok", false)), "once-per-episode T10 should resolve")
	if not bool(first.get("ok", false)):
		return
	_expect((first["events"] as Array).size() == 1, "same episode may fire T10 only once")
	var second: Dictionary = kernel.resolve_phase_h(7, [_trigger("wake-3", "WAKE", "org-a", "sleep-2")], [definition], first["state"])
	_expect(bool(second.get("ok", false)), "new episode T10 should resolve")
	if bool(second.get("ok", false)):
		_expect((second["events"] as Array).size() == 1, "new episode must permit a new bounded T10 pulse")

func _test_max_trigger_guard() -> void:
	var kernel: T10ReactivePulseKernel = T10ReactivePulseKernelScript.new()
	var definition: Dictionary = _definition("pulse-c", "RECOVERY", "max_triggers_per_run", {"kind": "FOOD_PULSE", "magnitude": 4})
	definition["max_triggers_per_run"] = 2
	var result: Dictionary = kernel.resolve_phase_h(5, [
		_trigger("r3", "RECOVERY", "org-a"),
		_trigger("r1", "RECOVERY", "org-a"),
		_trigger("r2", "RECOVERY", "org-a"),
	], [definition])
	_expect(bool(result.get("ok", false)), "finite max-trigger T10 should resolve")
	if bool(result.get("ok", false)):
		_expect((result["events"] as Array).size() == 2, "explicit finite max must cap same-run T10 pulses")
		var state: Dictionary = result["state"]
		var counts: Dictionary = state["trigger_count_by_key"]
		_expect(int(counts.get("org-a|pulse-c", 0)) == 2, "T10 runtime state must persist exact trigger count")

func _test_reordered_input_is_deterministic() -> void:
	var kernel: T10ReactivePulseKernel = T10ReactivePulseKernelScript.new()
	var a: Dictionary = _definition("pulse-a", "PANICKED_ENTRY", "once_per_run", {"kind": "HEAT_PULSE", "magnitude": 5})
	var b: Dictionary = _definition("pulse-b", "WAKE", "once_per_run", {"kind": "CONTAMINATION_CLEANSE", "magnitude": 4})
	var triggers_a: Array = [_trigger("z", "WAKE", "org-a"), _trigger("a", "PANICKED_ENTRY", "org-a")]
	var triggers_b: Array = [_trigger("a", "PANICKED_ENTRY", "org-a"), _trigger("z", "WAKE", "org-a")]
	var first: Dictionary = kernel.resolve_phase_h(6, triggers_a, [b, a])
	var second: Dictionary = kernel.resolve_phase_h(6, triggers_b, [a, b])
	_expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "determinism fixtures should resolve")
	if bool(first.get("ok", false)) and bool(second.get("ok", false)):
		_expect(String(first["authority_payload"]) == String(second["authority_payload"]), "T10 authority must ignore input ordering")
		_expect(String(first["authority_checksum"]) == String(second["authority_checksum"]), "T10 checksum must be deterministic")

func _test_recursive_same_tick_definition_rejected() -> void:
	var kernel: T10ReactivePulseKernel = T10ReactivePulseKernelScript.new()
	var definition: Dictionary = _definition("pulse-loop", "PANICKED_ENTRY", "once_per_run", {"kind": "PANICKED_ENTRY", "target_instance_id": "org-a"})
	var result: Dictionary = kernel.validate_definitions([definition])
	_expect(not bool(result.get("ok", true)), "direct same-source same-tick recursive T10 definition must be rejected")
	_expect(String(result.get("error", "")).begins_with("recursive_same_tick_t10_trigger:"), "recursive rejection must be typed")

func _test_missing_guard_rejected() -> void:
	var kernel: T10ReactivePulseKernel = T10ReactivePulseKernelScript.new()
	var definition: Dictionary = _definition("pulse-invalid", "WAKE", "once_per_run", {"kind": "HEAT_PULSE", "magnitude": 4})
	definition.erase("trigger_guard")
	var result: Dictionary = kernel.validate_definitions([definition])
	_expect(not bool(result.get("ok", true)), "every T10 definition must declare one finite guard")
	_expect(String(result.get("error", "")).begins_with("invalid_t10_trigger_guard:"), "missing T10 guard should have typed rejection")

func _definition(trait_id: String, trigger_kind: String, guard: String, effect: Dictionary) -> Dictionary:
	return {
		"source_instance_id": "org-a",
		"trait_id": trait_id,
		"trigger_event_kind": trigger_kind,
		"trigger_guard": guard,
		"effects": [effect],
	}

func _trigger(event_id: String, kind: String, instance_id: String, episode_id: String = "") -> Dictionary:
	var event: Dictionary = {"event_id": event_id, "kind": kind, "instance_id": instance_id}
	if not episode_id.is_empty():
		event["episode_id"] = episode_id
	return event

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("FAIL: %s" % message)
