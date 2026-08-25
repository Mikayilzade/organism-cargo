class_name AccessibilityPreflightScreen
extends Control

signal completed(settings: Dictionary)
signal close_requested()

const AccessibilitySettingsModelScript := preload("res://src/ui/accessibility_settings_model.gd")

const ROWS: Array[StringName] = [
	&"ui_scale_percent",
	&"reduced_flashing",
	&"reduced_motion",
	&"master_volume_percent",
	&"non_speech_captions",
	&"input_method",
	&"continue",
]
const INPUT_METHODS: Array[StringName] = [&"auto", &"keyboard_mouse", &"keyboard_only", &"controller", &"steam_deck"]

var _model: AccessibilitySettingsModel
var _first_run: bool = true
var _row_index: int = 0
var _rows: Dictionary = {}
var _title: Label
var _summary: Label
var _root: VBoxContainer
var _scroll: ScrollContainer

func _init(model: AccessibilitySettingsModel = null) -> void:
	_model = model if model != null else AccessibilitySettingsModelScript.new()

func _ready() -> void:
	if _root == null:
		_build()
	_apply_runtime_scale()
	_refresh()

func configure(first_run: bool) -> void:
	_first_run = first_run
	_row_index = 0
	if _root != null:
		_apply_runtime_scale()
		_refresh()

func settings_snapshot() -> Dictionary:
	return _model.snapshot()

func focused_row() -> StringName:
	return ROWS[_row_index]

func focus_entry() -> void:
	_focus_current()

func runtime_scale_factor() -> float:
	var window := get_window()
	return 1.0 if window == null else window.content_scale_factor

func has_vertical_scroll_path() -> bool:
	return _scroll != null and _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED

func focused_row_within_scroll_view() -> bool:
	if _scroll == null:
		return false
	var button: Button = _rows.get(focused_row(), null)
	if button == null:
		return false
	return _scroll.get_global_rect().intersects(button.get_global_rect())

func dispatch(action: StringName) -> Dictionary:
	match action:
		&"navigate_up", &"region_previous", &"panel_previous":
			_row_index = posmod(_row_index - 1, ROWS.size())
			_refresh()
			return _ok()
		&"navigate_down", &"region_next", &"panel_next":
			_row_index = posmod(_row_index + 1, ROWS.size())
			_refresh()
			return _ok()
		&"navigate_left":
			return _adjust(-1)
		&"navigate_right":
			return _adjust(1)
		&"accept":
			return _activate()
		&"cancel":
			if _first_run:
				return {"ok": false, "error": "first_run_preflight_required"}
			close_requested.emit()
			return _ok()
	return {"ok": false, "error": "unsupported_preflight_action"}

func rendered_snapshot() -> Dictionary:
	var row_text: Dictionary = {}
	for key: StringName in ROWS:
		var button: Button = _rows.get(key, null)
		row_text[String(key)] = "" if button == null else button.text
	return {
		"first_run": _first_run,
		"focused_row": focused_row(),
		"settings": _model.snapshot(),
		"rows": row_text,
		"all_rows_focusable": _all_rows_focusable(),
		"wrap_enabled": true,
		"semantic_only_operable": true,
		"deck_safe_area_target": [1280, 800],
		"runtime_scale_factor": runtime_scale_factor(),
		"vertical_scroll_path": has_vertical_scroll_path(),
		"focused_row_within_scroll_view": focused_row_within_scroll_view(),
	}

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.name = "AccessibilityPreflightScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)
	_root = VBoxContainer.new()
	_root.name = "AccessibilityPreflightRows"
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_root)
	_title = Label.new()
	_title.text = "Accessibility preflight"
	_title.add_theme_font_size_override("font_size", 28)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_title)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_summary)
	for key: StringName in ROWS:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_row_pressed.bind(key))
		_rows[key] = button
		_root.add_child(button)

func _on_row_pressed(key: StringName) -> void:
	_row_index = ROWS.find(key)
	_activate()

func _adjust(direction: int) -> Dictionary:
	var key := focused_row()
	var snapshot := _model.snapshot()
	match key:
		&"ui_scale_percent":
			var value := clampi(int(snapshot["ui_scale_percent"]) + 25 * direction, 100, 200)
			return _apply({"ui_scale_percent": value})
		&"master_volume_percent":
			var volume := clampi(int(snapshot["master_volume_percent"]) + 25 * direction, 0, 100)
			return _apply({"master_volume_percent": volume})
		&"input_method":
			var current := INPUT_METHODS.find(StringName(snapshot["input_method"]))
			return _apply({"input_method": INPUT_METHODS[posmod(current + direction, INPUT_METHODS.size())]})
		&"reduced_flashing":
			return _apply({"reduced_flashing": not bool(snapshot["reduced_flashing"])})
		&"reduced_motion":
			return _apply({"reduced_motion": not bool(snapshot["reduced_motion"])})
		&"non_speech_captions":
			return _apply({"non_speech_captions": not bool(snapshot["non_speech_captions"])})
	return {"ok": false, "error": "row_not_adjustable"}

func _activate() -> Dictionary:
	var key := focused_row()
	if key == &"continue":
		completed.emit(_model.snapshot())
		return _ok()
	if key in [&"reduced_flashing", &"reduced_motion", &"non_speech_captions"]:
		return _adjust(1)
	return _adjust(1)

func _apply(patch: Dictionary) -> Dictionary:
	var result := _model.apply_patch(patch)
	if bool(result.get("ok", false)):
		_apply_runtime_scale()
		_refresh()
	return result

func _apply_runtime_scale() -> void:
	var window := get_window()
	if window == null:
		return
	var percent: int = clampi(int(_model.snapshot().get("ui_scale_percent", 100)), 100, 200)
	window.content_scale_factor = float(percent) / 100.0

func _refresh() -> void:
	if _root == null:
		return
	var s := _model.snapshot()
	_title.text = "First-run accessibility preflight" if _first_run else "Accessibility settings"
	_summary.text = "All required fields are reachable with keyboard/controller/Deck semantic navigation. Left/Right changes values; Accept toggles or continues. Settings remain available later."
	(_rows[&"ui_scale_percent"] as Button).text = "UI scale: %d%%" % int(s["ui_scale_percent"])
	(_rows[&"reduced_flashing"] as Button).text = "Reduced Flashing: %s" % ("ON" if bool(s["reduced_flashing"]) else "OFF")
	(_rows[&"reduced_motion"] as Button).text = "Reduced Motion: %s" % ("ON" if bool(s["reduced_motion"]) else "OFF")
	(_rows[&"master_volume_percent"] as Button).text = "Master volume: %d%%" % int(s["master_volume_percent"])
	(_rows[&"non_speech_captions"] as Button).text = "Non-speech captions: %s" % ("ON" if bool(s["non_speech_captions"]) else "OFF")
	(_rows[&"input_method"] as Button).text = "Input method: %s" % String(s["input_method"]).replace("_", " ").capitalize()
	(_rows[&"continue"] as Button).text = "Continue" if _first_run else "Save and close"
	_focus_current()

func _focus_current() -> void:
	var button: Button = _rows.get(focused_row(), null)
	if button != null:
		button.grab_focus()
		if _scroll != null:
			_scroll.ensure_control_visible(button)

func _all_rows_focusable() -> bool:
	for key: StringName in ROWS:
		var button: Button = _rows.get(key, null)
		if button == null or button.focus_mode != Control.FOCUS_ALL:
			return false
	return true

func _ok() -> Dictionary:
	return {"ok": true, "error": "", "settings": _model.snapshot(), "focused_row": focused_row()}
