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
			return next_state in [State.PLANNING, State.CAMPAIGN_MAP, State.SETTINGS]
		State.PLANNING:
			return next_state in [State.LAUNCH_CONFIRM, State.CAMPAIGN_MAP, State.SETTINGS]
		State.LAUNCH_CONFIRM:
			return next_state in [State.PLANNING, State.TRANSIT_PLAYBACK]
		State.TRANSIT_PLAYBACK:
			return next_state == State.CAUSAL_REVIEW
		State.CAUSAL_REVIEW:
			return next_state in [State.RESULTS, State.PLANNING]
		State.RESULTS:
			return next_state in [State.CAMPAIGN_MAP, State.CAMPAIGN_COMPLETE, State.PLANNING, State.CHALLENGE_SELECT]
		State.CHALLENGE_SELECT:
			return next_state in [State.CONTRACT_BRIEF, State.TITLE, State.CAMPAIGN_MAP, State.SETTINGS]
		State.CODEX:
			return next_state in [State.TITLE, State.CAMPAIGN_MAP, State.SETTINGS]
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

func force_boot_for_tests() -> void:
	_state = State.BOOT
