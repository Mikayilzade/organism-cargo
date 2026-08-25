class_name AppStateMachine
extends RefCounted

enum State {
	BOOT,
	FIRST_RUN_PREFLIGHT,
	TITLE,
	CAMPAIGN_MAP,
	CONTRACT_BRIEF,
	PLANNING,
	LAUNCH_CONFIRM,
	TRANSIT_PLAYBACK,
	CAUSAL_REVIEW,
	RESULTS,
	CHALLENGE_SELECT,
	CODEX,
	SETTINGS,
	CAMPAIGN_COMPLETE,
	SAVE_RECOVERY,
	FATAL_CONTENT_ERROR,
}

var _state: State = State.BOOT
var _codex_return_state: State = State.TITLE

func current_state() -> State:
	return _state

func can_transition(next_state: State) -> bool:
	if next_state == _state:
		return false
	match _state:
		State.BOOT:
			return next_state in [State.FIRST_RUN_PREFLIGHT, State.TITLE, State.SAVE_RECOVERY, State.FATAL_CONTENT_ERROR]
		State.FIRST_RUN_PREFLIGHT:
			return next_state in [State.TITLE, State.SETTINGS, State.FATAL_CONTENT_ERROR]
		State.TITLE:
			return next_state in [State.CAMPAIGN_MAP, State.CHALLENGE_SELECT, State.CODEX, State.SETTINGS, State.SAVE_RECOVERY]
		State.CAMPAIGN_MAP:
			return next_state in [State.CONTRACT_BRIEF, State.CHALLENGE_SELECT, State.CODEX, State.SETTINGS, State.TITLE, State.CAMPAIGN_COMPLETE]
		State.CONTRACT_BRIEF:
			return next_state in [State.PLANNING, State.CAMPAIGN_MAP, State.CODEX, State.SETTINGS]
		State.PLANNING:
			return next_state in [State.LAUNCH_CONFIRM, State.CAMPAIGN_MAP, State.CODEX, State.SETTINGS]
		State.LAUNCH_CONFIRM:
			return next_state in [State.PLANNING, State.TRANSIT_PLAYBACK]
		State.TRANSIT_PLAYBACK:
			return next_state == State.CAUSAL_REVIEW
		State.CAUSAL_REVIEW:
			return next_state in [State.RESULTS, State.PLANNING, State.CAMPAIGN_MAP, State.CODEX]
		State.RESULTS:
			return next_state in [State.CAMPAIGN_MAP, State.CAMPAIGN_COMPLETE, State.PLANNING, State.CHALLENGE_SELECT, State.CODEX]
		State.CHALLENGE_SELECT:
			return next_state in [State.CONTRACT_BRIEF, State.TITLE, State.CAMPAIGN_MAP, State.CODEX, State.SETTINGS]
		State.CODEX:
			return next_state in [State.TITLE, State.CAMPAIGN_MAP, State.CONTRACT_BRIEF, State.PLANNING, State.CAUSAL_REVIEW, State.RESULTS, State.CHALLENGE_SELECT, State.CAMPAIGN_COMPLETE, State.SETTINGS]
		State.SETTINGS:
			return false
		State.CAMPAIGN_COMPLETE:
			return next_state in [State.CAMPAIGN_MAP, State.TITLE, State.CODEX]
		State.SAVE_RECOVERY:
			return next_state in [State.TITLE, State.FATAL_CONTENT_ERROR]
		State.FATAL_CONTENT_ERROR:
			return false
	return false

func transition_to(next_state: State) -> bool:
	if not can_transition(next_state):
		return false
	_state = next_state
	return true

func enter_codex() -> bool:
	if _state == State.CODEX:
		return false
	if not can_transition(State.CODEX):
		return false
	_codex_return_state = _state
	_state = State.CODEX
	return true

func exit_codex() -> bool:
	if _state != State.CODEX:
		return false
	if not can_transition(_codex_return_state):
		return false
	_state = _codex_return_state
	return true

func codex_return_state() -> State:
	return _codex_return_state

func accept_completed_transit(transit_result: Dictionary) -> bool:
	if _state != State.TRANSIT_PLAYBACK:
		return false
	if not bool(transit_result.get("ok", false)) or not bool(transit_result.get("completed", false)):
		return false
	var delivery_value: Variant = transit_result.get("delivery_result", null)
	if not delivery_value is Dictionary:
		return false
	var delivery: Dictionary = delivery_value
	if not bool(delivery.get("ok", false)) or not delivery.has("success"):
		return false
	if String(transit_result.get("next_state", "")) != "CAUSAL_REVIEW":
		return false
	return transition_to(State.CAUSAL_REVIEW)

func force_boot_for_tests() -> void:
	_state = State.BOOT
	_codex_return_state = State.TITLE
