extends SceneTree

var failures := 0

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
	var doc := _load_json("res://content/holds/launch_hold_geometry_batch_01.json")
	var defs: Array = doc.get("payload", {}).get("definitions", [])
	_expect(defs.size() == 4, "first hold geometry batch has H01-H04")
	var families := {"H01":[5,6,5,5,1,2],"H02":[5,6,5,5,1,2],"H03":[5,6,5,5,1,2],"H04":[5,6,6,6,2,2]}
	for raw: Variant in defs:
		var d: Dictionary = raw
		var id := String(d.get("id", ""))
		_expect(families.has(id), "%s is expected authored hold" % id)
		if not families.has(id): continue
		var lim: Array = families[id]
		var w := int(d.get("width", 0)); var h := int(d.get("height", 0))
		_expect(w >= lim[0] and w <= lim[1] and h >= lim[2] and h <= lim[3], "%s stays inside frozen family bounds" % id)
		var fixtures: Array = d.get("utility_fixtures", [])
		_expect(fixtures.size() >= lim[4] and fixtures.size() <= lim[5], "%s fixture count stays inside frozen family bounds" % id)
		var occupied := {}
		for raw_cell: Variant in d.get("blocked_cells", []):
			var cell: Array = raw_cell; _expect(_in_bounds(cell,w,h), "%s blocked cell in bounds" % id); occupied[str(cell)] = true
		for raw_fixture: Variant in fixtures:
			var cell: Array = raw_fixture.get("cell", []); _expect(_in_bounds(cell,w,h), "%s fixture cell in bounds" % id); _expect(not occupied.has(str(cell)), "%s fixture not on blocked cell" % id)

func _test_route_profiles() -> void:
	var doc := _load_json("res://content/routes/launch_route_profiles_batch_01.json")
	var defs: Array = doc.get("payload", {}).get("definitions", [])
	_expect(defs.size() == 6, "first route batch has R01-R06")
	var allowed := {"RH1":true,"RH2":true,"RH3":true,"RH4":true,"RH5":true,"RH6":true,"RH7":true}
	var effects := {"RH1":["heat_input"],"RH2":["contamination_source"],"RH3":["stress_field","wake_request"]}
	for raw: Variant in defs:
		var d: Dictionary = raw
		var id := String(d.get("id", "")); var duration := int(d.get("duration_ticks", 0)); var families: Array = d.get("hazard_family_ids", [])
		_expect(duration > 0 and duration <= 24, "%s duration stays <=24" % id)
		var max_families := 1 if String(d.get("tier", "")) in ["0-1","2"] else 2
		_expect(families.size() <= max_families, "%s tier family ceiling" % id)
		for family: Variant in families: _expect(allowed.has(String(family)), "%s hazard family resolves" % id)
		var last_end := -1
		for raw_event: Variant in d.get("events", []):
			var e: Dictionary = raw_event; var tick := int(e.get("tick", -1)); var span := int(e.get("duration_ticks", 0)); var family := String(e.get("family_id", "")); var effect := String(e.get("effect", ""))
			_expect(tick >= 0 and span > 0 and tick + span <= duration, "%s event stays inside route duration" % id)
			_expect(family in families, "%s event family declared by profile" % id)
			_expect(effects.has(family) and effect in effects[family], "%s event effect matches existing family grammar" % id)
			if String(d.get("tier", "")) == "2": _expect(tick >= last_end, "%s Tier-2 events do not overlap" % id)
			last_end = tick + span

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "open %s" % path); return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "parse %s" % path)
	return parsed if parsed is Dictionary else {}

func _in_bounds(cell: Array, width: int, height: int) -> bool:
	return cell.size() == 2 and int(cell[0]) >= 0 and int(cell[0]) < width and int(cell[1]) >= 0 and int(cell[1]) < height

func _expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: %s" % label)
