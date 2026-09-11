extends Control

const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MARKER_TEXT := "⭐"
const MARKER_TOOLTIP := "有可分配技能点"
const MARKER_SIZE := Vector2(34.0, 34.0)
const MARKER_WORLD_HEIGHT := 2.95
const SCREEN_MARGIN := 0.0
const MINIMUM_VIEWPORT_SIZE := Vector2(320.0, 180.0)
const RELEVANT_STATE_FIELDS: Array[String] = ["escaped"]

var _markers: Dictionary = {}
var _assignable_points: Dictionary = {}
var _debug_viewport_size_override := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var event_bus := get_node_or_null("/root/EventBus")
	if (
		event_bus != null
		and event_bus.has_signal("npc_state_changed")
		and not event_bus.npc_state_changed.is_connected(_on_npc_state_changed)
	):
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
	call_deferred("_refresh_all_markers")


func _process(_delta: float) -> void:
	_position_markers()


func _refresh_all_markers() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return
	for raw_npc_id in npc_system.get_npc_ids():
		_refresh_marker(str(raw_npc_id))
	_position_markers()


func _on_npc_state_changed(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system != null
		and npc_system.has_method("is_active_npc_state_change_relevant")
		and not npc_system.is_active_npc_state_change_relevant(npc_id, RELEVANT_STATE_FIELDS)
	):
		return
	_refresh_marker(npc_id)


func _refresh_marker(npc_id: String) -> void:
	if npc_id.is_empty():
		return
	var marker := _ensure_marker(npc_id)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if marker == null or npc_system == null:
		return
	var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
	var progression: Dictionary = (
		npc_system.get_npc_progression(npc_id)
		if npc_system.has_method("get_npc_progression")
		else npc.get("progression", {})
	)
	var stats: Dictionary = npc.get("stats", {}) if npc.get("stats", {}) is Dictionary else {}
	var states: Dictionary = npc.get("states", {}) if npc.get("states", {}) is Dictionary else {}
	var unspent_points := maxi(0, int(progression.get("unspent_skill_points", 0)))
	var has_available_attribute := (
		int(stats.get("strength", 0)) < 10
		or int(stats.get("intelligence", 0)) < 10
	)
	_assignable_points[npc_id] = (
		unspent_points
		if unspent_points > 0 and has_available_attribute and not bool(states.get("escaped", false))
		else 0
	)
	marker.tooltip_text = MARKER_TOOLTIP


func _ensure_marker(npc_id: String) -> Button:
	var existing := _markers.get(npc_id) as Button
	if is_instance_valid(existing):
		return existing
	var marker := Button.new()
	marker.name = "%sSkillPointAlert" % npc_id.to_pascal_case()
	marker.text = MARKER_TEXT
	marker.tooltip_text = MARKER_TOOLTIP
	marker.custom_minimum_size = MARKER_SIZE
	marker.size = MARKER_SIZE
	marker.focus_mode = Control.FOCUS_NONE
	marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	marker.add_theme_font_size_override("font_size", 24)
	marker.add_theme_color_override("font_color", Color(1.0, 0.79, 0.20, 1.0))
	marker.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.38, 1.0))
	marker.add_theme_color_override("font_pressed_color", Color(0.92, 0.62, 0.08, 1.0))
	marker.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.01, 0.95))
	marker.add_theme_constant_override("outline_size", 4)
	marker.add_theme_stylebox_override("normal", _make_marker_style(Color.TRANSPARENT))
	marker.add_theme_stylebox_override("hover", _make_marker_style(Color(0.28, 0.17, 0.02, 0.68)))
	marker.add_theme_stylebox_override("pressed", _make_marker_style(Color(0.18, 0.10, 0.01, 0.82)))
	marker.pressed.connect(_on_marker_pressed.bind(npc_id))
	marker.visible = false
	add_child(marker)
	_markers[npc_id] = marker
	_assignable_points[npc_id] = 0
	return marker


func _make_marker_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 17
	style.corner_radius_top_right = 17
	style.corner_radius_bottom_left = 17
	style.corner_radius_bottom_right = 17
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _position_markers() -> void:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var viewport_size := (
		_debug_viewport_size_override
		if _debug_viewport_size_override.x > 0.0 and _debug_viewport_size_override.y > 0.0
		else get_viewport_rect().size
	)
	var viewport_supported := (
		viewport_size.x >= MINIMUM_VIEWPORT_SIZE.x
		and viewport_size.y >= MINIMUM_VIEWPORT_SIZE.y
	)
	for raw_npc_id in _markers:
		var npc_id := str(raw_npc_id)
		var marker := _markers.get(npc_id) as Button
		if marker == null:
			continue
		var hidden_by_opaque_building := (
			npc_system != null
			and npc_system.has_method("_is_npc_hidden_by_opaque_building")
			and bool(npc_system.call("_is_npc_hidden_by_opaque_building", npc_id))
		)
		var world_position: Variant = (
			npc_system.get_npc_world_position(npc_id)
			if npc_system != null and npc_system.has_method("get_npc_world_position")
			else null
		)
		if (
			not viewport_supported
			or camera == null
			or hidden_by_opaque_building
			or not world_position is Vector3
			or camera.is_position_behind(world_position)
		):
			marker.visible = false
			continue
		var anchor_world_position := (world_position as Vector3) + Vector3.UP * MARKER_WORLD_HEIGHT
		var screen_center := camera.unproject_position(anchor_world_position)
		var on_screen := Rect2(Vector2.ZERO, viewport_size).has_point(screen_center)
		var top_left := screen_center - MARKER_SIZE * 0.5
		var max_position := Vector2(
			maxf(SCREEN_MARGIN, viewport_size.x - MARKER_SIZE.x - SCREEN_MARGIN),
			maxf(SCREEN_MARGIN, viewport_size.y - MARKER_SIZE.y - SCREEN_MARGIN)
		)
		marker.position = top_left.clamp(Vector2(SCREEN_MARGIN, SCREEN_MARGIN), max_position)
		marker.visible = int(_assignable_points.get(npc_id, 0)) > 0 and on_screen


func _on_marker_pressed(npc_id: String) -> void:
	if int(_assignable_points.get(npc_id, 0)) <= 0:
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_clicked"):
		event_bus.npc_clicked.emit(npc_id)
		get_viewport().set_input_as_handled()


func debug_get_marker_snapshot(npc_id: String) -> Dictionary:
	var marker := _markers.get(npc_id) as Button
	if marker == null:
		return {}
	return {
		"npc_id": npc_id,
		"assignable_points": int(_assignable_points.get(npc_id, 0)),
		"visible": marker.visible,
		"text": marker.text,
		"tooltip": marker.tooltip_text,
		"position": marker.position,
		"size": marker.size,
		"cursor_shape": marker.mouse_default_cursor_shape,
	}


func debug_press_marker(npc_id: String) -> void:
	_on_marker_pressed(npc_id)


func debug_set_viewport_size_override(viewport_size: Vector2) -> void:
	_debug_viewport_size_override = viewport_size
	_position_markers()
