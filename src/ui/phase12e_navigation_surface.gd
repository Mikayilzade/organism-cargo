class_name Phase12ENavigationSurface
extends VBoxContainer

signal action_completed(action: StringName, result: Dictionary)

const REVIEW_ACTIONS: Array[StringName] = [&"retry", &"reset_contract", &"return_to_map"]

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
	if _review_panel.visible:
		_refresh_review_focus()
	elif _codex_panel.visible:
		_render_codex()
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
	var result: Dictionary = _activate_review_action(REVIEW_ACTIONS[_selected_review_index])
	if bool(result.get("ok", false)):
		sync_from_flow()
		action_completed.emit(REVIEW_ACTIONS[_selected_review_index], result)
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

func codex_exact_text() -> String:
	return "" if _codex_text == null else _codex_text.text

func codex_scroll_container() -> ScrollContainer:
	return _codex_scroll

func _activate_review_action(action: StringName) -> Dictionary:
	match action:
		&"retry":
			var retry: Dictionary = _control.activate_primary_action()
			return retry
		&"reset_contract":
			var reset_input: Dictionary = _reset_contract_input()
			var reset_facts: Dictionary = _reset_structural_facts()
			var result: Dictionary = _flow.reset_contract(
				String(_context.get("reset_revision_id", "ui-reset-contract")),
				reset_input,
				reset_facts
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
	return {
		"route_id": String(_context.get("planning_route_id", "route-slice")),
		"manifest_instance_ids": manifest_ids,
		"placements": [],
		"supports": [],
		"seed": int(_context.get("planning_seed", 101)),
	}

func _reset_structural_facts() -> Dictionary:
	var provided: Variant = _context.get("reset_structural_facts", null)
	if provided is Dictionary:
		return (provided as Dictionary).duplicate(true)
	return {
		"mandatory_manifest_placed": false,
		"overlap_free": true,
		"blocked_free": true,
		"in_bounds": true,
		"orientations_valid": true,
		"zones_valid": true,
		"fixtures_valid": true,
		"links_valid": true,
		"support_resources_valid": true,
		"structural_prerequisites_met": false,
	}

func _build_once() -> void:
	if _review_panel != null:
		return
	name = "Phase12ENavigationSurface"
	_review_panel = VBoxContainer.new()
	_review_panel.name = "ReviewExitPanel"
	add_child(_review_panel)
	_review_title = Label.new()
	_review_title.text = "POST-RUN ACTIONS — Left/Right selects • Accept activates"
	_review_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_review_panel.add_child(_review_title)
	for spec: Dictionary in [
		{"id": &"retry", "text": "Retry from last launch"},
		{"id": &"reset_contract", "text": "Reset contract"},
		{"id": &"return_to_map", "text": "Return to map"},
	]:
		var button: Button = Button.new()
		button.name = String(spec["id"]).to_pascal_case()
		button.text = String(spec["text"])
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_review_button_pressed.bind(spec["id"]))
		_review_panel.add_child(button)
		_review_buttons.append(button)

	_codex_panel = VBoxContainer.new()
	_codex_panel.name = "CodexPanel"
	add_child(_codex_panel)
	_codex_title = Label.new()
	_codex_title.text = "CODEX — exact documented rules • Up/Down scroll • Cancel returns"
	_codex_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_codex_panel.add_child(_codex_title)
	_codex_scroll = ScrollContainer.new()
	_codex_scroll.name = "CodexScroll"
	_codex_scroll.custom_minimum_size = Vector2(320, 220)
	_codex_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_panel.add_child(_codex_scroll)
	_codex_text = RichTextLabel.new()
	_codex_text.name = "CodexExactRules"
	_codex_text.fit_content = true
	_codex_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_codex_text.custom_minimum_size = Vector2(280, 0)
	_codex_scroll.add_child(_codex_text)

func _render_codex() -> void:
	if _codex_text == null:
		return
	var species_value: Variant = _context.get("planning_species_by_id", {})
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Exact rule data is shown without ellipsis; the container scrolls instead of clipping arithmetic.")
	if species_value is Dictionary:
		var species: Dictionary = species_value
		var ids: Array = species.keys()
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for raw_id: Variant in ids:
			lines.append("\n[%s]" % String(raw_id))
			lines.append(JSON.stringify(species[raw_id], "  ", true, true))
	if lines.size() == 1:
		lines.append("\nNo documented species rules are available in this context.")
	_codex_text.text = "\n".join(lines)

func _refresh_review_focus() -> void:
	for index: int in range(_review_buttons.size()):
		var button: Button = _review_buttons[index]
		var base: String = ["Retry from last launch", "Reset contract", "Return to map"][index]
		button.text = ("> " if index == _selected_review_index else "  ") + base
	if not _review_buttons.is_empty():
		_review_buttons[_selected_review_index].grab_focus()

func _on_review_button_pressed(action: StringName) -> void:
	var index: int = REVIEW_ACTIONS.find(action)
	if index >= 0:
		_selected_review_index = index
		review_activate_selected()

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
