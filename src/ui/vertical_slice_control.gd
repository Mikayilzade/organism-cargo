class_name VerticalSliceControl
extends VBoxContainer

signal action_failed(error: String)

var _flow: VerticalSliceFlowCoordinator
var _context: Dictionary = {}
var _title_label: Label
var _detail_label: Label
var _primary_button: Button
var _secondary_button: Button

func _ready() -> void:
	_title_label = Label.new()
	_title_label.name = "StateTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_label)

	_detail_label = Label.new()
	_detail_label.name = "StateDetail"
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail_label)

	_primary_button = Button.new()
	_primary_button.name = "PrimaryAction"
	_primary_button.pressed.connect(_on_primary_pressed)
	add_child(_primary_button)

	_secondary_button = Button.new()
	_secondary_button.name = "SecondaryAction"
	_secondary_button.pressed.connect(_on_secondary_pressed)
	add_child(_secondary_button)

	sync_from_flow()

func configure(flow: VerticalSliceFlowCoordinator, context: Dictionary = {}) -> void:
	_flow = flow
	_context = context.duplicate(true)
	if is_node_ready():
		sync_from_flow()

func set_context(context: Dictionary) -> void:
	_context = context.duplicate(true)

func sync_from_flow() -> void:
	if _title_label == null:
		return
	if _flow == null:
		_title_label.text = "Organism Cargo"
		_detail_label.text = "Preparing deterministic cargo systems…"
		_primary_button.visible = false
		_secondary_button.visible = false
		return

	_primary_button.visible = true
	_secondary_button.visible = false
	match _flow.current_state():
		AppStateMachine.State.TITLE:
			_set_view("Organism Cargo", "Plan living cargo for what happens after Launch.", "Campaign")
		AppStateMachine.State.CAMPAIGN_MAP:
			_set_view("Campaign", "Vertical-slice contract route.", "Open Contract")
		AppStateMachine.State.CONTRACT_BRIEF:
			_set_view("Contract Brief", "Inspect delivery conditions before arranging cargo.", "Plan Cargo")
		AppStateMachine.State.PLANNING:
			_set_view("Planning", "Arrange the manifest, then verify structural legality.", "Review Launch")
		AppStateMachine.State.LAUNCH_CONFIRM:
			_set_view("Launch Confirmation", "Commit this arrangement? Transit forbids rearrangement.", "Launch")
			_secondary_button.visible = true
			_secondary_button.text = "Cancel"
		AppStateMachine.State.TRANSIT_PLAYBACK:
			_set_view("Transit", "Committed cargo is resolving deterministically.", "Resolve Transit")
		AppStateMachine.State.CAUSAL_REVIEW:
			_set_view("Causal Review", _review_summary(), "Retry from Last Launch")
		_:
			_set_view("Organism Cargo", "State %s" % str(_flow.current_state()), "Continue")

func activate_primary_action() -> Dictionary:
	if _flow == null:
		return _fail("flow_not_configured")
	var result: Dictionary = {"ok": false, "error": "unsupported_state"}
	match _flow.current_state():
		AppStateMachine.State.TITLE:
			result = _bool_result(_flow.enter_campaign_map(), "campaign_map_transition_failed")
		AppStateMachine.State.CAMPAIGN_MAP:
			result = _bool_result(_flow.select_contract(), "contract_brief_transition_failed")
		AppStateMachine.State.CONTRACT_BRIEF:
			result = _bool_result(_flow.begin_planning(), "planning_transition_failed")
		AppStateMachine.State.PLANNING:
			result = _flow.request_launch_confirm()
		AppStateMachine.State.LAUNCH_CONFIRM:
			result = _commit_from_context()
		AppStateMachine.State.TRANSIT_PLAYBACK:
			result = _complete_from_context()
		AppStateMachine.State.CAUSAL_REVIEW:
			result = _retry_from_context()
	if bool(result.get("ok", false)):
		sync_from_flow()
	return result

func activate_secondary_action() -> Dictionary:
	if _flow == null:
		return _fail("flow_not_configured")
	if _flow.current_state() != AppStateMachine.State.LAUNCH_CONFIRM:
		return _fail("unsupported_state")
	var result: Dictionary = _bool_result(_flow.cancel_launch_confirm(), "launch_cancel_failed")
	if bool(result.get("ok", false)):
		sync_from_flow()
	return result

func state_title() -> String:
	return "" if _title_label == null else _title_label.text

func primary_action_text() -> String:
	return "" if _primary_button == null else _primary_button.text

func _commit_from_context() -> Dictionary:
	var required := ["launch_request_token", "profile_uuid", "contract_id", "rules_version", "content_version", "contract_definition_checksum"]
	for key: String in required:
		if not _context.has(key):
			return _fail("missing_context:%s" % key)
	return _flow.commit_launch(
		String(_context["launch_request_token"]),
		String(_context["profile_uuid"]),
		String(_context["contract_id"]),
		String(_context["rules_version"]),
		String(_context["content_version"]),
		String(_context["contract_definition_checksum"]),
		String(_context.get("generator_version", ""))
	)

func _complete_from_context() -> Dictionary:
	if not _context.has("total_ticks") or not _context.has("simulation_defs") or not _context.has("mandatory_predicates"):
		return _fail("missing_transit_context")
	var predicates_value: Variant = _context["mandatory_predicates"]
	if not predicates_value is Array:
		return _fail("invalid_mandatory_predicates")
	return _flow.complete_transit(
		int(_context["total_ticks"]),
		_context["simulation_defs"],
		predicates_value
	)

func _retry_from_context() -> Dictionary:
	if not _context.has("retry_revision_id") or not _context.has("retry_structural_facts"):
		return _fail("missing_retry_context")
	return _flow.begin_retry(
		String(_context["retry_revision_id"]),
		_context["retry_structural_facts"]
	)

func _review_summary() -> String:
	var review: Dictionary = _flow.last_review()
	if review.is_empty():
		return "Inspect the completed run, then retry the committed baseline."
	var event_id := String(review.get("first_actionable_event_id", ""))
	if event_id.is_empty():
		return "Completed run is ready for review and targeted Retry."
	return "First actionable event: %s" % event_id

func _set_view(title: String, detail: String, primary_text: String) -> void:
	_title_label.text = title
	_detail_label.text = detail
	_primary_button.text = primary_text

func _on_primary_pressed() -> void:
	var result: Dictionary = activate_primary_action()
	if not bool(result.get("ok", false)):
		action_failed.emit(String(result.get("error", "unknown")))

func _on_secondary_pressed() -> void:
	var result: Dictionary = activate_secondary_action()
	if not bool(result.get("ok", false)):
		action_failed.emit(String(result.get("error", "unknown")))

static func _bool_result(ok: bool, error: String) -> Dictionary:
	return {"ok": ok, "error": "" if ok else error}

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
