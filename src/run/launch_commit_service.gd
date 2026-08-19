class_name LaunchCommitService
extends RefCounted

const AppStateMachineScript := preload("res://src/state/app_state_machine.gd")

var _state_machine: AppStateMachine
var _save_store: AtomicSaveStore
var _run_id_factory: Callable

func _init(p_state_machine: AppStateMachine, p_save_store: AtomicSaveStore, p_run_id_factory: Callable = Callable()) -> void:
	_state_machine = p_state_machine
	_save_store = p_save_store
	_run_id_factory = p_run_id_factory

func request_launch(
		launch_request_token: String,
		planning_revision_id: String,
		structural_legal: bool,
		profile_uuid: String,
		contract_id: String,
		canonical_input: Dictionary,
		rules_version: String,
		content_version: String,
		expected_contract_definition_checksum: String,
		generator_version: String = ""
) -> Dictionary:
	var existing: Dictionary = _existing_committed_run(planning_revision_id)
	if existing["found"]:
		return {"ok": true, "duplicate": true, "run_id": existing["run_id"], "error": ""}

	if _state_machine.current_state() != AppStateMachineScript.State.LAUNCH_CONFIRM:
		return _failure("invalid_state")
	if not structural_legal:
		return _failure("structural_illegal")
	if launch_request_token.strip_edges().is_empty():
		return _failure("missing_launch_request_token")
	if planning_revision_id.strip_edges().is_empty():
		return _failure("missing_planning_revision_id")
	if profile_uuid.strip_edges().is_empty():
		return _failure("missing_profile_uuid")
	if contract_id.strip_edges().is_empty():
		return _failure("missing_contract_id")
	if rules_version.strip_edges().is_empty() or content_version.strip_edges().is_empty():
		return _failure("missing_compatibility_version")
	if expected_contract_definition_checksum.strip_edges().is_empty():
		return _failure("missing_contract_definition_checksum")

	var committed_input: Dictionary = canonical_input.duplicate(true)
	committed_input["contract_id"] = contract_id
	committed_input["rules_version"] = rules_version
	committed_input["content_version"] = content_version
	committed_input["generator_version"] = generator_version
	committed_input["expected_contract_definition_checksum"] = expected_contract_definition_checksum
	var committed_input_serialized: String = JSON.stringify(committed_input, "", true, true)
	var committed_input_checksum: String = committed_input_serialized.sha256_text()
	var run_id: String = _allocate_run_id()
	if run_id.is_empty():
		return _failure("run_id_allocation_failed")

	var record: Dictionary = {
		"profile_uuid": profile_uuid,
		"run_id": run_id,
		"contract_id": contract_id,
		"planning_revision_id": planning_revision_id,
		"launch_request_token": launch_request_token,
		"canonical_committed_input": committed_input,
		"committed_input_checksum": committed_input_checksum,
		"rules_version": rules_version,
		"content_version": content_version,
		"generator_version": generator_version,
		"expected_contract_definition_checksum": expected_contract_definition_checksum,
		"launch_timestamp_unix": int(Time.get_unix_time_from_system()),
		"lifecycle_state": "COMMITTED",
	}
	var write_result: Dictionary = _save_store.write(&"session", {"committed_run": record})
	if not write_result["ok"]:
		return _failure("session_commit_failed:%s" % String(write_result["error"]))

	if not _state_machine.transition_to(AppStateMachineScript.State.TRANSIT_PLAYBACK):
		return _failure("post_commit_transition_failed")
	return {"ok": true, "duplicate": false, "run_id": run_id, "error": ""}

func _existing_committed_run(planning_revision_id: String) -> Dictionary:
	if planning_revision_id.strip_edges().is_empty():
		return {"found": false, "run_id": ""}
	var loaded: Dictionary = _save_store.load(&"session")
	if not loaded["ok"]:
		return {"found": false, "run_id": ""}
	var envelope: SaveEnvelope = loaded["envelope"]
	if not envelope.payload.has("committed_run") or not envelope.payload["committed_run"] is Dictionary:
		return {"found": false, "run_id": ""}
	var record: Dictionary = envelope.payload["committed_run"]
	if String(record.get("planning_revision_id", "")) != planning_revision_id:
		return {"found": false, "run_id": ""}
	var lifecycle_state: String = String(record.get("lifecycle_state", ""))
	if lifecycle_state not in ["COMMITTED", "SIMULATED", "REVIEWABLE", "COMPLETION_APPLIED"]:
		return {"found": false, "run_id": ""}
	var run_id: String = String(record.get("run_id", ""))
	if run_id.is_empty():
		return {"found": false, "run_id": ""}
	return {"found": true, "run_id": run_id}

func _allocate_run_id() -> String:
	if _run_id_factory.is_valid():
		return String(_run_id_factory.call())
	var crypto: Crypto = Crypto.new()
	var random_bytes: PackedByteArray = crypto.generate_random_bytes(16)
	if random_bytes.size() != 16:
		return ""
	return random_bytes.hex_encode()

static func _failure(error: String) -> Dictionary:
	return {"ok": false, "duplicate": false, "run_id": "", "error": error}
