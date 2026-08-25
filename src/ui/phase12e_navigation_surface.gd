class_name Phase12ENavigationSurface
extends VBoxContainer

signal action_completed(action: StringName, result: Dictionary)

const REVIEW_ACTIONS: Array[StringName] = [&"retry", &"reset_contract", &"return_to_map"]
const RECOVERY_ACTIONS: Array[StringName] = [&"restore_backup", &"create_new_profile"]
const CAMPAIGN_COMPLETE_ACTIONS: Array[StringName] = [&"return_to_map", &"codex", &"title"]

var _control: VerticalSliceControl
var _flow: VerticalSliceFlowCoordinator
var _context: Dictionary = {}
var _review_panel: VBoxContainer
var _review_title: Label
var _review_buttons: Array[Button] = []
var _selected_review_index: int = 0
var _codex_panel: VBoxContainer
var _codex_title: Label
var _codex_scroll: ScrollContainer
var _codex_text: RichTextLabel
var _recovery_panel: VBoxContainer
var _recovery_summary: Label
var _recovery_buttons: Array[Button] = []
var _selected_recovery_index: int = 0
var _campaign_complete_panel: VBoxContainer
var _campaign_complete_summary: Label
var _campaign_complete_buttons: Array[Button] = []
var _selected_campaign_complete_index: int = 0

func configure(control: VerticalSliceControl, flow: VerticalSliceFlowCoordinator, context: Dictionary) -> Dictionary:
	_control = control
	_flow = flow
	_context = context.duplicate(true)
	_build_once()
	sync_from_flow()
	return {"ok": true, "error": ""}

func sync_from_flow() -> void:
	if _flow == null:
		visible = false
		return
	visible = true
	var state: int = _flow.current_state()
	_review_panel.visible = state == AppStateMachine.State.CAUSAL_REVIEW
	_codex_panel.visible = state == AppStateMachine.State.CODEX
	_recovery_panel.visible = state == AppStateMachine.State.SAVE_RECOVERY
	_campaign_complete_panel.visible = state == AppStateMachine.State.CAMPAIGN_COMPLETE
	if _review_panel.visible:
		_refresh_review_focus()
	elif _codex_panel.visible:
		_render_codex()
	elif _recovery_panel.visible:
		_render_recovery()
	elif _campaign_complete_panel.visible:
		_render_campaign_complete()
	else:
		visible = false

func review_move(delta: int) -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.CAUSAL_REVIEW:
		return _fail("review_navigation_not_active")
	_selected_review_index = posmod(_selected_review_index + delta, REVIEW_ACTIONS.size())
	_refresh_review_focus()
	return {"ok": true, "error": "", "selected_action": REVIEW_ACTIONS[_selected_review_index]}

func review_activate_selected() -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.CAUSAL_REVIEW:
		return _fail("review_navigation_not_active")
	var action: StringName = REVIEW_ACTIONS[_selected_review_index]
	var result: Dictionary = _activate_review_action(action)
	if bool(result.get("ok", false)):
		sync_from_flow()
		action_completed.emit(action, result)
	return result

func recovery_move(delta: int) -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.SAVE_RECOVERY:
		return _fail("save_recovery_not_active")
	_selected_recovery_index = posmod(_selected_recovery_index + delta, RECOVERY_ACTIONS.size())
	_refresh_recovery_focus()
	return {"ok": true, "error": "", "selected_action": RECOVERY_ACTIONS[_selected_recovery_index]}

func recovery_activate_selected() -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.SAVE_RECOVERY:
		return _fail("save_recovery_not_active")
	var service: Object = _recovery_service()
	if service == null:
		return _fail("save_recovery_service_unavailable")
	var action: StringName = RECOVERY_ACTIONS[_selected_recovery_index]
	var value: Variant
	if action == &"restore_backup":
		value = service.call("restore_validated_backup", &"profile")
	else:
		value = service.call("create_new_profile", String(_context.get("profile_uuid", "local-profile")))
	if not value is Dictionary:
		return _fail("save_recovery_invalid_result")
	var result: Dictionary = value
	if not bool(result.get("ok", false)):
		return result
	var exit_result: Dictionary = _flow.finish_save_recovery()
	if not bool(exit_result.get("ok", false)):
		return exit_result
	result["state"] = _flow.current_state()
	sync_from_flow()
	action_completed.emit(action, result)
	return result

func campaign_complete_move(delta: int) -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.CAMPAIGN_COMPLETE:
		return _fail("campaign_completion_not_active")
	_selected_campaign_complete_index = posmod(_selected_campaign_complete_index + delta, CAMPAIGN_COMPLETE_ACTIONS.size())
	_refresh_campaign_complete_focus()
	return {"ok": true, "error": "", "selected_action": CAMPAIGN_COMPLETE_ACTIONS[_selected_campaign_complete_index]}

func campaign_complete_activate_selected() -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.CAMPAIGN_COMPLETE:
		return _fail("campaign_completion_not_active")
	var action: StringName = CAMPAIGN_COMPLETE_ACTIONS[_selected_campaign_complete_index]
	var result: Dictionary
	match action:
		&"return_to_map":
			result = _flow.return_to_campaign_map()
		&"codex":
			result = open_codex()
		&"title":
			result = _flow.return_to_title()
		_:
			result = _fail("unknown_campaign_completion_action")
	if bool(result.get("ok", false)):
		sync_from_flow()
		action_completed.emit(action, result)
	return result

func open_codex() -> Dictionary:
	if _flow == null:
		return _fail("flow_not_configured")
	var result: Dictionary = _flow.open_codex()
	if bool(result.get("ok", false)):
		sync_from_flow()
	return result

func close_codex() -> Dictionary:
	if _flow == null:
		return _fail("flow_not_configured")
	var result: Dictionary = _flow.close_codex()
	if bool(result.get("ok", false)):
		sync_from_flow()
	return result

func codex_scroll(delta_pages: int) -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.CODEX:
		return _fail("codex_not_active")
	var step: float = maxf(80.0, _codex_scroll.size.y * 0.75)
	_codex_scroll.scroll_vertical = maxi(0, _codex_scroll.scroll_vertical + int(step) * delta_pages)
	return {"ok": true, "error": "", "scroll_vertical": _codex_scroll.scroll_vertical}

func selected_review_action() -> StringName:
	return REVIEW_ACTIONS[_selected_review_index]

func selected_recovery_action() -> StringName:
	return RECOVERY_ACTIONS[_selected_recovery_index]

func selected_campaign_complete_action() -> StringName:
	return CAMPAIGN_COMPLETE_ACTIONS[_selected_campaign_complete_index]

func codex_exact_text() -> String:
	return "" if _codex_text == null else _codex_text.text

func codex_scroll_container() -> ScrollContainer:
	return _codex_scroll

func recovery_summary_text() -> String:
	return "" if _recovery_summary == null else _recovery_summary.text

func campaign_complete_summary_text() -> String:
	return "" if _campaign_complete_summary == null else _campaign_complete_summary.text

func _activate_review_action(action: StringName) -> Dictionary:
	match action:
		&"retry":
			return _control.activate_primary_action()
		&"reset_contract":
			var result: Dictionary = _flow.reset_contract(
				String(_context.get("reset_revision_id", "ui-reset-contract")),
				_reset_contract_input(),
				_reset_structural_facts()
			)
			if bool(result.get("ok", false)):
				_control.set_context(_context)
			return result
		&"return_to_map":
			var map_result: Dictionary = _flow.return_to_campaign_map()
			if bool(map_result.get("ok", false)):
				_control.sync_from_flow()
			return map_result
	return _fail("unknown_review_action")

func _reset_contract_input() -> Dictionary:
	var provided: Variant = _context.get("reset_contract_input", null)
	if provided is Dictionary:
		return (provided as Dictionary).duplicate(true)
	var manifest_ids: Array[String] = []
	var contract_value: Variant = _context.get("planning_contract_payload", {})
	if contract_value is Dictionary:
		var manifest_value: Variant = (contract_value as Dictionary).get("manifest", [])
		if manifest_value is Array:
			for raw_entry: Variant in manifest_value:
				if raw_entry is Dictionary:
					var instance_id: String = String((raw_entry as Dictionary).get("instance_id", ""))
					if not instance_id.is_empty():
						manifest_ids.append(instance_id)
	return {"route_id": String(_context.get("planning_route_id", "route-slice")), "manifest_instance_ids": manifest_ids, "placements": [], "supports": [], "seed": int(_context.get("planning_seed", 101))}

func _reset_structural_facts() -> Dictionary:
	var provided: Variant = _context.get("reset_structural_facts", null)
	if provided is Dictionary:
		return (provided as Dictionary).duplicate(true)
	return {"mandatory_manifest_placed": false, "overlap_free": true, "blocked_free": true, "in_bounds": true, "orientations_valid": true, "zones_valid": true, "fixtures_valid": true, "links_valid": true, "support_resources_valid": true, "structural_prerequisites_met": false}

func _build_once() -> void:
	if _review_panel != null:
		return
	name = "Phase12ENavigationSurface"
	_build_review_panel()
	_build_codex_panel()
	_build_recovery_panel()
	_build_campaign_complete_panel()

func _build_review_panel() -> void:
	_review_panel = VBoxContainer.new(); _review_panel.name = "ReviewExitPanel"; add_child(_review_panel)
	_review_title = Label.new(); _review_title.text = "POST-RUN ACTIONS — Left/Right selects • Accept activates"; _review_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _review_panel.add_child(_review_title)
	for spec: Dictionary in [{"id": &"retry", "text": "Retry from last launch"}, {"id": &"reset_contract", "text": "Reset contract"}, {"id": &"return_to_map", "text": "Return to map"}]:
		var button: Button = Button.new(); button.name = String(spec["id"]).to_pascal_case(); button.text = String(spec["text"]); button.focus_mode = Control.FOCUS_ALL; button.pressed.connect(_on_review_button_pressed.bind(spec["id"])); _review_panel.add_child(button); _review_buttons.append(button)

func _build_codex_panel() -> void:
	_codex_panel = VBoxContainer.new(); _codex_panel.name = "CodexPanel"; add_child(_codex_panel)
	_codex_title = Label.new(); _codex_title.text = "CODEX — exact documented rules • Up/Down scroll • Cancel returns"; _codex_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _codex_panel.add_child(_codex_title)
	_codex_scroll = ScrollContainer.new(); _codex_scroll.name = "CodexScroll"; _codex_scroll.custom_minimum_size = Vector2(320, 220); _codex_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; _codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _codex_panel.add_child(_codex_scroll)
	_codex_text = RichTextLabel.new(); _codex_text.name = "CodexExactRules"; _codex_text.fit_content = true; _codex_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _codex_text.custom_minimum_size = Vector2(280, 0); _codex_scroll.add_child(_codex_text)

func _build_recovery_panel() -> void:
	_recovery_panel = VBoxContainer.new(); _recovery_panel.name = "SaveRecoveryPanel"; add_child(_recovery_panel)
	_recovery_summary = Label.new(); _recovery_summary.name = "SaveRecoverySummary"; _recovery_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _recovery_panel.add_child(_recovery_summary)
	for spec: Dictionary in [{"id": &"restore_backup", "text": "Restore validated backup"}, {"id": &"create_new_profile", "text": "Create new profile"}]:
		var button: Button = Button.new(); button.name = String(spec["id"]).to_pascal_case(); button.text = String(spec["text"]); button.focus_mode = Control.FOCUS_ALL; button.pressed.connect(_on_recovery_button_pressed.bind(spec["id"])); _recovery_panel.add_child(button); _recovery_buttons.append(button)

func _build_campaign_complete_panel() -> void:
	_campaign_complete_panel = VBoxContainer.new(); _campaign_complete_panel.name = "CampaignCompletePanel"; add_child(_campaign_complete_panel)
	_campaign_complete_summary = Label.new(); _campaign_complete_summary.name = "CampaignCompleteSummary"; _campaign_complete_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _campaign_complete_panel.add_child(_campaign_complete_summary)
	for spec: Dictionary in [{"id": &"return_to_map", "text": "Return to campaign map"}, {"id": &"codex", "text": "Open Codex"}, {"id": &"title", "text": "Return to title"}]:
		var button: Button = Button.new(); button.name = String(spec["id"]).to_pascal_case(); button.text = String(spec["text"]); button.focus_mode = Control.FOCUS_ALL; button.pressed.connect(_on_campaign_complete_button_pressed.bind(spec["id"])); _campaign_complete_panel.add_child(button); _campaign_complete_buttons.append(button)

func _render_codex() -> void:
	if _codex_text == null:
		return
	var species_value: Variant = _context.get("planning_species_by_id", {})
	var lines: PackedStringArray = PackedStringArray(["Exact rule data is shown without ellipsis; the container scrolls instead of clipping arithmetic."])
	if species_value is Dictionary:
		var ids: Array = (species_value as Dictionary).keys(); ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for raw_id: Variant in ids:
			lines.append("\n[%s]" % String(raw_id)); lines.append(JSON.stringify((species_value as Dictionary)[raw_id], "  ", true, true))
	if lines.size() == 1:
		lines.append("\nNo documented species rules are available in this context.")
	_codex_text.text = "\n".join(lines)

func _render_recovery() -> void:
	var assessment: Dictionary = _recovery_assessment()
	var can_restore: bool = bool(assessment.get("can_restore_backup", false))
	_recovery_summary.text = "SAVE RECOVERY — Primary save is not usable. Only validated generations may be restored. Corrupt generations are retained as diagnostics before replacement; progress is never guessed.\nBackup: %s • New profile: available" % ("validated" if can_restore else "not validated")
	if _recovery_buttons.size() >= 2:
		_recovery_buttons[0].disabled = not can_restore
		if not can_restore and _selected_recovery_index == 0:
			_selected_recovery_index = 1
	_refresh_recovery_focus()

func _render_campaign_complete() -> void:
	var cleared: int = int(_context.get("campaign_completed_contract_count", 48))
	var total: int = int(_context.get("campaign_total_contract_count", 48))
	var medal_summary: String = String(_context.get("campaign_medal_summary", "Best medals remain available on every completed node."))
	var challenge_summary: String = String(_context.get("campaign_challenge_summary", "Generated/mastery Challenges remain available under the frozen progression gates."))
	_campaign_complete_summary.text = "CAMPAIGN COMPLETE\nAll authored deliveries remain replayable from the map.\nCompleted: %d / %d\n%s\n%s\nNo forced New Game+; progression remains monotonic." % [cleared, total, medal_summary, challenge_summary]
	_refresh_campaign_complete_focus()

func _refresh_review_focus() -> void:
	for index: int in range(_review_buttons.size()):
		var base: String = ["Retry from last launch", "Reset contract", "Return to map"][index]; _review_buttons[index].text = ("> " if index == _selected_review_index else "  ") + base
	if not _review_buttons.is_empty(): _review_buttons[_selected_review_index].grab_focus()

func _refresh_recovery_focus() -> void:
	for index: int in range(_recovery_buttons.size()):
		var base: String = ["Restore validated backup", "Create new profile"][index]; _recovery_buttons[index].text = ("> " if index == _selected_recovery_index else "  ") + base
	if not _recovery_buttons.is_empty() and not _recovery_buttons[_selected_recovery_index].disabled: _recovery_buttons[_selected_recovery_index].grab_focus()

func _refresh_campaign_complete_focus() -> void:
	for index: int in range(_campaign_complete_buttons.size()):
		var base: String = ["Return to campaign map", "Open Codex", "Return to title"][index]; _campaign_complete_buttons[index].text = ("> " if index == _selected_campaign_complete_index else "  ") + base
	if not _campaign_complete_buttons.is_empty(): _campaign_complete_buttons[_selected_campaign_complete_index].grab_focus()

func _recovery_service() -> Object:
	var value: Variant = _context.get("save_recovery_service", null)
	return value if value is Object else null

func _recovery_assessment() -> Dictionary:
	var service: Object = _recovery_service()
	if service == null or not service.has_method("assess"):
		return {}
	var value: Variant = service.call("assess", &"profile")
	return value if value is Dictionary else {}

func _on_review_button_pressed(action: StringName) -> void:
	var index: int = REVIEW_ACTIONS.find(action)
	if index >= 0: _selected_review_index = index; review_activate_selected()

func _on_recovery_button_pressed(action: StringName) -> void:
	var index: int = RECOVERY_ACTIONS.find(action)
	if index >= 0: _selected_recovery_index = index; recovery_activate_selected()

func _on_campaign_complete_button_pressed(action: StringName) -> void:
	var index: int = CAMPAIGN_COMPLETE_ACTIONS.find(action)
	if index >= 0: _selected_campaign_complete_index = index; campaign_complete_activate_selected()

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
