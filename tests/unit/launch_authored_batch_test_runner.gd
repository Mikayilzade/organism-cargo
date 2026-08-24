extends SceneTree

var failures: int = 0

func _init() -> void:
	_test_hold_geometry()
	_test_route_profiles()
	if failures == 0:
		print("launch_authored_batch_test_runner: PASS")
		quit(0)
	else:
		push_error("launch_authored_batch_test_runner: %d failure(s)" % failures)
		quit(1)

func _test_hold_geometry() -> void:
	var doc: Dictionary = _load_json("res://content/holds/launch_hold_geometry_batch_01.json")
	var defs: Array = _array(_dict(doc.get("payload", {})).get("definitions", []))
	_expect(defs.size() == 4, "first hold geometry batch has H01-H04")

	var limits: Dictionary = {
		"H01": [5, 6, 5, 5, 1, 2],
		"H02": [5, 6, 5, 5, 1, 2],
		"H03": [5, 6, 5, 5, 1, 2],
		"H04": [5, 6, 6, 6, 2, 2],
	}
	var seen_ids: Dictionary = {}

	for raw_definition: Variant in defs:
		var definition: Dictionary = _dict(raw_definition)
		var hold_id: String = String(definition.get("id", ""))
		_expect(limits.has(hold_id), "%s is expected authored hold" % hold_id)
		_expect(not seen_ids.has(hold_id), "%s appears once" % hold_id)
		seen_ids[hold_id] = true
		if not limits.has(hold_id):
			continue

		var limit: Array = _array(limits[hold_id])
		var width: int = int(definition.get("width", 0))
		var height: int = int(definition.get("height", 0))
		_expect(
			width >= int(limit[0]) and width <= int(limit[1]) and height >= int(limit[2]) and height <= int(limit[3]),
			"%s stays inside frozen family bounds" % hold_id
		)

		var fixtures: Array = _array(definition.get("utility_fixtures", []))
		_expect(
			fixtures.size() >= int(limit[4]) and fixtures.size() <= int(limit[5]),
			"%s fixture count stays inside frozen family bounds" % hold_id
		)

		var blocked: Dictionary = {}
		for raw_cell: Variant in _array(definition.get("blocked_cells", [])):
			var blocked_cell: Array = _array(raw_cell)
			_expect(_in_bounds(blocked_cell, width, height), "%s blocked cell in bounds" % hold_id)
			blocked[_cell_key(blocked_cell)] = true

		var fixture_cells: Dictionary = {}
		for raw_fixture: Variant in fixtures:
			var fixture: Dictionary = _dict(raw_fixture)
			var fixture_cell: Array = _array(fixture.get("cell", []))
			var key: String = _cell_key(fixture_cell)
			_expect(_in_bounds(fixture_cell, width, height), "%s fixture cell in bounds" % hold_id)
			_expect(not blocked.has(key), "%s fixture not on blocked cell" % hold_id)
			_expect(not fixture_cells.has(key), "%s fixture cells are unique" % hold_id)
			fixture_cells[key] = true

func _test_route_profiles() -> void:
	var doc: Dictionary = _load_json("res://content/routes/launch_route_profiles_batch_01.json")
	var defs: Array = _array(_dict(doc.get("payload", {})).get("definitions", []))
	_expect(defs.size() == 6, "first route batch has R01-R06")

	var allowed_families: Dictionary = {
		"RH1": true,
		"RH2": true,
		"RH3": true,
		"RH4": true,
		"RH5": true,
		"RH6": true,
		"RH7": true,
	}
	var allowed_effects: Dictionary = {
		"RH1": ["heat_input"],
		"RH2": ["contamination_source"],
		"RH3": ["stress_field", "wake_request"],
	}
	var seen_ids: Dictionary = {}

	for raw_definition: Variant in defs:
		var definition: Dictionary = _dict(raw_definition)
		var route_id: String = String(definition.get("id", ""))
		var tier: String = String(definition.get("tier", ""))
		var duration: int = int(definition.get("duration_ticks", 0))
		var families: Array = _array(definition.get("hazard_family_ids", []))
		var events: Array = _array(definition.get("events", []))

		_expect(not seen_ids.has(route_id), "%s appears once" % route_id)
		seen_ids[route_id] = true
		_expect(duration > 0 and duration <= 24, "%s duration stays <=24" % route_id)

		var max_families: int = 2
		if tier == "0-1" or tier == "2":
			max_families = 1
		_expect(families.size() <= max_families, "%s tier family ceiling" % route_id)

		var declared_families: Dictionary = {}
		for raw_family: Variant in families:
			var family_id: String = String(raw_family)
			_expect(allowed_families.has(family_id), "%s hazard family resolves" % route_id)
			_expect(not declared_families.has(family_id), "%s hazard family declared once" % route_id)
			declared_families[family_id] = true

		var previous_end: int = -1
		for raw_event: Variant in events:
			var event: Dictionary = _dict(raw_event)
			var tick: int = int(event.get("tick", -1))
			var span: int = int(event.get("duration_ticks", 0))
			var family_id: String = String(event.get("family_id", ""))
			var effect_id: String = String(event.get("effect", ""))
			_expect(tick >= 0 and span > 0 and tick + span <= duration, "%s event stays inside route duration" % route_id)
			_expect(declared_families.has(family_id), "%s event family declared by profile" % route_id)

			var family_effects: Array = _array(allowed_effects.get(family_id, []))
			_expect(not family_effects.is_empty(), "%s event family has frozen effect grammar" % route_id)
			_expect(family_effects.has(effect_id), "%s event effect matches existing family grammar" % route_id)

			if tier == "2":
				_expect(tick >= previous_end, "%s Tier-2 events do not overlap" % route_id)
			previous_end = tick + span

func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "parse %s" % path)
	return _dict(parsed)

func _array(value: Variant) -> Array:
	return value if value is Array else []

func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _cell_key(cell: Array) -> String:
	if cell.size() != 2:
		return "invalid"
	return "%d,%d" % [int(cell[0]), int(cell[1])]

func _in_bounds(cell: Array, width: int, height: int) -> bool:
	return cell.size() == 2 and int(cell[0]) >= 0 and int(cell[0]) < width and int(cell[1]) >= 0 and int(cell[1]) < height

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)
