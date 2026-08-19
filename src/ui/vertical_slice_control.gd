class_name VerticalSliceControl
extends VBoxContainer

signal action_failed(error: String)

var _flow: VerticalSliceFlowCoordinator
var _context: Dictionary = {}
var _title_label: Label
var _detail_label: Label
var _planning_panel: VBoxContainer
var _manifest_row: HBoxContainer
var _hold_grid: GridContainer
var _planning_status_label: Label
var _primary_button: Button
var _secondary_button: Button

var _planning_contract_payload: Dictionary = {}
var _planning_hold_payload: Dictionary = {}
var _planning_species_by_id: Dictionary = {}
var _placements_by_instance: Dictionary = {}
var _selected_manifest_instance: String = ""
var _focused_cell: Vector2i = Vector2i.ZERO
var _planning_revision_sequence: int = 0
var _cell_buttons: Dictionary = {}
var _manifest_buttons: Dictionary = {}

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

	_planning_panel = VBoxContainer.new()
	_planning_panel.name = "PlanningPanel"
	add_child(_planning_panel)

	_manifest_row = HBoxContainer.new()
	_manifest_row.name = "ManifestRow"
	_planning_panel.add_child(_manifest_row)

	_hold_grid = GridContainer.new()
	_hold_grid.name = "HoldGrid"
	_planning_panel.add_child(_hold_grid)

	_planning_status_label = Label.new()
	_planning_status_label.name = "PlanningStatus"
	_planning_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_planning_panel.add_child(_planning_status_label)

	_primary_button = Button.new()
	_primary_button.name = "PrimaryAction"
	_primary_button.pressed.connect(_on_primary_pressed)
	add_child(_primary_button)

	_secondary_button = Button.new()
	_secondary_button.name = "SecondaryAction"
	_secondary_button.pressed.connect(_on_secondary_pressed)
	add_child(_secondary_button)

	_configure_planning_context()
	sync_from_flow()

func configure(flow: VerticalSliceFlowCoordinator, context: Dictionary = {}) -> void:
	_flow = flow
	_context = context.duplicate(true)
	_configure_planning_context()
	if is_node_ready():
		sync_from_flow()

func set_context(context: Dictionary) -> void:
	_context = context.duplicate(true)
	_configure_planning_context()
	if is_node_ready():
		sync_from_flow()

func sync_from_flow() -> void:
	if _title_label == null:
		return
	if _flow == null:
		_title_label.text = "Organism Cargo"
		_detail_label.text = "Preparing deterministic cargo systems…"
		_planning_panel.visible = false
		_primary_button.visible = false
		_secondary_button.visible = false
		return

	_primary_button.visible = true
	_secondary_button.visible = false
	_planning_panel.visible = _flow.current_state() == AppStateMachine.State.PLANNING and _planning_content_ready()
	match _flow.current_state():
		AppStateMachine.State.TITLE:
			_set_view("Organism Cargo", "Plan living cargo for what happens after Launch.", "Campaign")
		AppStateMachine.State.CAMPAIGN_MAP:
			_set_view("Campaign", "Vertical-slice contract route.", "Open Contract")
		AppStateMachine.State.CONTRACT_BRIEF:
			_set_view("Contract Brief", "Inspect delivery conditions before arranging cargo.", "Plan Cargo")
		AppStateMachine.State.PLANNING:
			_set_view("Planning", "Select a manifest specimen, focus a hold cell, and place it. Structural legality comes from the canonical planning resolver.", "Review Launch")
			_refresh_planning_widgets()
			_render_planning_status()
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
	elif _flow.current_state() == AppStateMachine.State.PLANNING:
		_render_planning_status()
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

func planning_select_manifest(instance_id: String) -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.PLANNING:
		return _fail("planning_not_active")
	if not _manifest_instance_ids().has(instance_id):
		return _fail("unknown_manifest_instance")
	_selected_manifest_instance = instance_id
	_refresh_planning_widgets()
	_render_planning_status()
	return {"ok": true, "error": "", "selected_instance_id": instance_id}

func planning_move_focus(delta_x: int, delta_y: int) -> Dictionary:
	if not _planning_content_ready():
		return _fail("planning_content_unavailable")
	var width: int = int(_planning_hold_payload.get("width", 0))
	var height: int = int(_planning_hold_payload.get("height", 0))
	_focused_cell.x = clampi(_focused_cell.x + delta_x, 0, width - 1)
	_focused_cell.y = clampi(_focused_cell.y + delta_y, 0, height - 1)
	_refresh_planning_widgets()
	return {"ok": true, "error": "", "focus": [_focused_cell.x, _focused_cell.y]}

func planning_activate_focused_cell() -> Dictionary:
	return planning_place_selected(_focused_cell.x, _focused_cell.y)

func planning_place_selected(x: int, y: int) -> Dictionary:
	if _flow == null or _flow.current_state() != AppStateMachine.State.PLANNING:
		return _fail("planning_not_active")
	if _selected_manifest_instance.is_empty():
		return _fail("manifest_selection_required")
	var width: int = int(_planning_hold_payload.get("width", 0))
	var height: int = int(_planning_hold_payload.get("height", 0))
	if x < 0 or y < 0 or x >= width or y >= height:
		return _fail("cell_out_of_bounds")
	_focused_cell = Vector2i(x, y)
	_placements_by_instance[_selected_manifest_instance] = {
		"instance_id": _selected_manifest_instance,
		"anchor": [x, y],
		"orientation": 0,
	}
	var result: Dictionary = _apply_current_plan()
	_refresh_planning_widgets()
	_render_planning_status()
	return result

func planning_snapshot() -> Dictionary:
	return {
		"selected_instance_id": _selected_manifest_instance,
		"focus": [_focused_cell.x, _focused_cell.y],
		"placements": _ordered_placements(),
		"flow": {} if _flow == null else _flow.planning_snapshot(),
	}

func state_title() -> String:
	return "" if _title_label == null else _title_label.text

func primary_action_text() -> String:
	return "" if _primary_button == null else _primary_button.text

func _configure_planning_context() -> void:
	_planning_contract_payload = _dictionary_context("planning_contract_payload")
	_planning_hold_payload = _dictionary_context("planning_hold_payload")
	_planning_species_by_id = _dictionary_context("planning_species_by_id")
	_placements_by_instance.clear()
	_selected_manifest_instance = ""
	_focused_cell = Vector2i.ZERO
	_planning_revision_sequence = 0
	if is_node_ready():
		_rebuild_planning_widgets()

func _dictionary_context(key: String) -> Dictionary:
	var value: Variant = _context.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary.duplicate(true)

func _planning_content_ready() -> bool:
	return int(_planning_hold_payload.get("width", 0)) > 0 \
		and int(_planning_hold_payload.get("height", 0)) > 0 \
		and not _planning_contract_payload.is_empty() \
		and not _planning_species_by_id.is_empty()

func _rebuild_planning_widgets() -> void:
	if _manifest_row == null or _hold_grid == null:
		return
	_clear_children(_manifest_row)
	_clear_children(_hold_grid)
	_manifest_buttons.clear()
	_cell_buttons.clear()
	if not _planning_content_ready():
		return

	for instance_id: String in _manifest_instance_ids():
		var manifest_button: Button = Button.new()
		manifest_button.text = instance_id
		manifest_button.pressed.connect(_on_manifest_pressed.bind(instance_id))
		_manifest_row.add_child(manifest_button)
		_manifest_buttons[instance_id] = manifest_button

	var width: int = int(_planning_hold_payload.get("width", 0))
	var height: int = int(_planning_hold_payload.get("height", 0))
	_hold_grid.columns = width
	for y: int in range(height):
		for x: int in range(width):
			var cell_button: Button = Button.new()
			cell_button.custom_minimum_size = Vector2(84, 48)
			cell_button.pressed.connect(_on_cell_pressed.bind(x, y))
			_hold_grid.add_child(cell_button)
			_cell_buttons[_cell_key(x, y)] = cell_button
	_refresh_planning_widgets()

func _clear_children(node: Node) -> void:
	while node.get_child_count() > 0:
		var child: Node = node.get_child(0)
		node.remove_child(child)
		child.queue_free()

func _refresh_planning_widgets() -> void:
	if not _planning_content_ready():
		return
	for raw_instance_id: Variant in _manifest_buttons.keys():
		var instance_id: String = String(raw_instance_id)
		var button: Button = _manifest_buttons[raw_instance_id]
		var placed_marker: String = " ✓" if _placements_by_instance.has(instance_id) else ""
		var selected_marker: String = "> " if instance_id == _selected_manifest_instance else ""
		button.text = "%s%s%s" % [selected_marker, instance_id, placed_marker]

	var width: int = int(_planning_hold_payload.get("width", 0))
	var height: int = int(_planning_hold_payload.get("height", 0))
	for y: int in range(height):
		for x: int in range(width):
			var key: String = _cell_key(x, y)
			if not _cell_buttons.has(key):
				continue
			var cell_button: Button = _cell_buttons[key]
			var occupant: String = _occupant_at(x, y)
			var content: String = "—" if occupant.is_empty() else occupant
			if _is_blocked_cell(x, y):
				content = "BLOCKED" if occupant.is_empty() else "%s / BLOCKED" % occupant
			var focus_marker: String = ">" if _focused_cell == Vector2i(x, y) else " "
			cell_button.text = "%s[%d,%d] %s" % [focus_marker, x, y, content]

func _render_planning_status() -> void:
	if _planning_status_label == null:
		return
	if not _planning_content_ready():
		_planning_status_label.text = "Planning content unavailable."
		return
	if _flow == null:
		_planning_status_label.text = "Planning flow unavailable."
		return
	var snapshot: Dictionary = _flow.planning_snapshot()
	if not bool(snapshot.get("ok", false)):
		var selection_text: String = "none" if _selected_manifest_instance.is_empty() else _selected_manifest_instance
		_planning_status_label.text = "Selected: %s. Place both mandatory specimens before Launch review." % selection_text
		return
	if bool(snapshot.get("structural_legal", false)):
		_planning_status_label.text = "Structural validation: LEGAL. Review Launch when ready."
		return
	var reasons_value: Variant = snapshot.get("reasons", [])
	var reasons: Array = []
	if typeof(reasons_value) == TYPE_ARRAY:
		reasons = reasons_value
	_planning_status_label.text = "Structural validation: BLOCKED — %s" % ", ".join(reasons)

func _apply_current_plan() -> Dictionary:
	planning_revision_sequence += 1
	var canonical_input: Dictionary = {
		"route_id": String(_context.get("planning_route_id", "route-slice")),
		"manifest_instance_ids": _manifest_instance_ids(),
		"placements": _ordered_placements(),
		"supports": [],
		"seed": int(_context.get("planning_seed", 101)),
	}
	return _flow.apply_plan_from_content(
		"ui-plan-%d" % planning_revision_sequence,
		canonical_input,
		_planning_contract_payload,
		_planning_hold_payload,
		_planning_species_by_id
	)

func _manifest_instance_ids() -> Array[String]:
	var ids: Array[String] = []
	var manifest_value: Variant = _planning_contract_payload.get("manifest", [])
	if typeof(manifest_value) != TYPE_ARRAY:
		return ids
	var manifest: Array = manifest_value
	for raw_entry: Variant in manifest:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var instance_id: String = String(entry.get("instance_id", ""))
		if not instance_id.is_empty():
			ids.append(instance_id)
	return ids

func _ordered_placements() -> Array:
	var placements: Array = []
	for instance_id: String in _manifest_instance_ids():
		if _placements_by_instance.has(instance_id):
			var placement_value: Variant = _placements_by_instance[instance_id]
			if typeof(placement_value) == TYPE_DICTIONARY:
				var placement: Dictionary = placement_value
				placements.append(placement.duplicate(true))
	return placements

func _occupant_at(x: int, y: int) -> String:
	for raw_instance_id: Variant in _placements_by_instance.keys():
		var placement_value: Variant = _placements_by_instance[raw_instance_id]
		if typeof(placement_value) != TYPE_DICTIONARY:
			continue
		var placement: Dictionary = placement_value
		var anchor_value: Variant = placement.get("anchor", [])
		if typeof(anchor_value) != TYPE_ARRAY:
			continue
		var anchor: Array = anchor_value
		if anchor.size() == 2 and int(anchor[0]) == x and int(anchor[1]) == y:
			return String(raw_instance_id)
	return ""

func _is_blocked_cell(x: int, y: int) -> bool:
	var blocked_value: Variant = _planning_hold_payload.get("blocked_cells", [])
	if typeof(blocked_value) != TYPE_ARRAY:
		return false
	var blocked: Array = blocked_value
	for raw_cell: Variant in blocked:
		if typeof(raw_cell) != TYPE_ARRAY:
			continue
		var cell: Array = raw_cell
		if cell.size() == 2 and int(cell[0]) == x and int(cell[1]) == y:
			return true
	return false

func _commit_from_context() -> Dictionary:
	var required: Array[String] = ["launch_request_token", "profile_uuid", "contract_id", "rules_version", "content_version", "contract_definition_checksum"]
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
	var event_id: String = String(review.get("first_actionable_event_id", ""))
	if event_id.is_empty():
		return "Completed run is ready for review and targeted Retry."
	return "First actionable event: %s" % event_id

func _set_view(title: String, detail: String, primary_text: String) -> void:
	_title_label.text = title
	_detail_label.text = detail
	_primary_button.text = primary_text

func _on_manifest_pressed(instance_id: String) -> void:
	var result: Dictionary = planning_select_manifest(instance_id)
	if not bool(result.get("ok", false)):
		action_failed.emit(String(result.get("error", "unknown")))

func _on_cell_pressed(x: int, y: int) -> void:
	var result: Dictionary = planning_place_selected(x, y)
	if not bool(result.get("ok", false)):
		action_failed.emit(String(result.get("error", "unknown")))

func _on_primary_pressed() -> void:
	var result: Dictionary = activate_primary_action()
	if not bool(result.get("ok", false)):
		action_failed.emit(String(result.get("error", "unknown")))

func _on_secondary_pressed() -> void:
	var result: Dictionary = activate_secondary_action()
	if not bool(result.get("ok", false)):
		action_failed.emit(String(result.get("error", "unknown")))

static func _cell_key(x: int, y: int) -> String:
	return "%d:%d" % [x, y]

static func _bool_result(ok: bool, error: String) -> Dictionary:
	return {"ok": ok, "error": "" if ok else error}

static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
