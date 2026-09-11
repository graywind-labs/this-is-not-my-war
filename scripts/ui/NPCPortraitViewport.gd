extends PanelContainer

signal portrait_clicked(npc_id: String)

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const WORLD_STATIC_COLLISION_MASK := 1
const PORTRAIT_EXCLUDED_VISUAL_LAYER := 20
const MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER := 19
const PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER := 18
const VIEWPORT_SIZE := Vector2i(260, 480)
const CAMERA_DISTANCE := 3.9
const CAMERA_HEIGHT := 1.15
const CAMERA_FOCUS_HEIGHT := 0.92
const CAMERA_MIN_DISTANCE := 1.35
const CAMERA_WALL_MARGIN := 0.24
const CAMERA_FOLLOW_SPEED := 10.0
const EMOTION_BUBBLE_DEFAULT_HOLD_SECONDS := 5.0
const EMOTION_BUBBLE_DEFAULT_FADE_SECONDS := 0.75

var _target_npc_id := ""
var _target_enemy_id := ""
var _target_kind := "npc"
var _active := false
var _allow_escaped_portrait := false
var _camera_initialized := false
var _subviewport: SubViewport
var _camera: Camera3D
var _status_label: Label
var _emotion_bubble_root: Control
var _emotion_bubble_panel: PanelContainer
var _emotion_bubble_tail_border: Polygon2D
var _emotion_bubble_tail_fill: Polygon2D
var _emotion_bubble_label: Label
var _emotion_bubble_elapsed := 0.0
var _emotion_bubble_hold_seconds := EMOTION_BUBBLE_DEFAULT_HOLD_SECONDS
var _emotion_bubble_fade_seconds := EMOTION_BUBBLE_DEFAULT_FADE_SECONDS
var _emotion_bubble_presentation: Dictionary = {}
var _last_target_snapshot: Dictionary = {}
var _last_camera_front_dot := -1.0
var _last_obstruction_adjusted := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_view()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_dialogue_emotion_presented"):
		event_bus.npc_dialogue_emotion_presented.connect(_on_dialogue_emotion_presented)
	_set_rendering_enabled(false)
	set_process(false)


func _build_view() -> void:
	var margin := MarginContainer.new()
	margin.name = "PortraitMargin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var view_frame := PanelContainer.new()
	view_frame.name = "PortraitFrame"
	view_frame.custom_minimum_size = Vector2(150.0, 220.0)
	view_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(view_frame)

	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "PortraitViewportContainer"
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_frame.add_child(viewport_container)

	_subviewport = SubViewport.new()
	_subviewport.name = "PortraitSubViewport"
	_subviewport.size = VIEWPORT_SIZE
	_subviewport.own_world_3d = false
	_subviewport.transparent_bg = false
	_subviewport.msaa_3d = Viewport.MSAA_2X
	viewport_container.add_child(_subviewport)
	var main_viewport := get_viewport()
	if main_viewport != null:
		_subviewport.world_3d = main_viewport.world_3d

	_camera = Camera3D.new()
	_camera.name = "PortraitCamera"
	_camera.current = true
	_camera.fov = 40.0
	_camera.near = 0.08
	_camera.far = 180.0
	_camera.set_cull_mask_value(PORTRAIT_EXCLUDED_VISUAL_LAYER, false)
	_camera.set_cull_mask_value(MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER, false)
	_camera.set_cull_mask_value(PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER, true)
	_subviewport.add_child(_camera)

	var status_overlay := CenterContainer.new()
	status_overlay.name = "PortraitStatusOverlay"
	status_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_frame.add_child(status_overlay)
	_status_label = Label.new()
	_status_label.name = "PortraitStatusLabel"
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(120.0, 0.0)
	status_overlay.add_child(_status_label)

	var emotion_overlay := Control.new()
	emotion_overlay.name = "PortraitEmotionOverlay"
	emotion_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emotion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_frame.add_child(emotion_overlay)
	_emotion_bubble_root = Control.new()
	_emotion_bubble_root.name = "PortraitEmotionBubbleRoot"
	_emotion_bubble_root.position = Vector2(12.0, 14.0)
	_emotion_bubble_root.size = Vector2(100.0, 82.0)
	_emotion_bubble_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emotion_overlay.add_child(_emotion_bubble_root)

	_emotion_bubble_tail_border = Polygon2D.new()
	_emotion_bubble_tail_border.name = "ComicTailBorder"
	_emotion_bubble_tail_border.polygon = PackedVector2Array([
		Vector2(34.0, 57.0),
		Vector2(46.0, 57.0),
		Vector2(55.0, 70.0),
	])
	_emotion_bubble_tail_border.color = Color(0.34, 0.25, 0.13, 0.90)
	_emotion_bubble_root.add_child(_emotion_bubble_tail_border)

	_emotion_bubble_tail_fill = Polygon2D.new()
	_emotion_bubble_tail_fill.name = "ComicTailFill"
	_emotion_bubble_tail_fill.polygon = PackedVector2Array([
		Vector2(37.0, 59.0),
		Vector2(43.0, 59.0),
		Vector2(52.0, 67.0),
	])
	_emotion_bubble_tail_fill.color = Color(1.0, 0.97, 0.86, 0.96)
	_emotion_bubble_root.add_child(_emotion_bubble_tail_fill)

	_emotion_bubble_panel = PanelContainer.new()
	_emotion_bubble_panel.name = "PortraitEmotionBubble"
	_emotion_bubble_panel.position = Vector2.ZERO
	_emotion_bubble_panel.size = Vector2(80.0, 58.0)
	_emotion_bubble_panel.custom_minimum_size = Vector2(80.0, 58.0)
	_emotion_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(1.0, 0.97, 0.86, 0.96)
	bubble_style.border_color = Color(0.34, 0.25, 0.13, 0.9)
	bubble_style.set_border_width_all(2)
	bubble_style.set_corner_radius_all(18)
	bubble_style.content_margin_left = 12.0
	bubble_style.content_margin_top = 8.0
	bubble_style.content_margin_right = 12.0
	bubble_style.content_margin_bottom = 8.0
	_emotion_bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	_emotion_bubble_root.add_child(_emotion_bubble_panel)
	_emotion_bubble_label = Label.new()
	_emotion_bubble_label.name = "Emoji"
	_emotion_bubble_label.text = "…"
	_emotion_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emotion_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_emotion_bubble_label.add_theme_font_size_override("font_size", 34)
	_emotion_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emotion_bubble_panel.add_child(_emotion_bubble_label)
	_emotion_bubble_root.visible = false
	_emotion_bubble_panel.visible = false

	var click_button := Button.new()
	click_button.name = "PortraitClickButton"
	click_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_button.flat = true
	click_button.focus_mode = Control.FOCUS_NONE
	click_button.tooltip_text = "空闲时点击人物可让其向你示意"
	click_button.accessibility_name = "NPC 人物小窗"
	click_button.pressed.connect(_on_portrait_pressed)
	view_frame.add_child(click_button)


func _on_portrait_pressed() -> void:
	if not _active or _target_kind != "npc" or _target_npc_id.is_empty():
		return
	portrait_clicked.emit(_target_npc_id)

func show_npc(npc_id: String, allow_escaped_portrait: bool = false) -> void:
	var clean_id := npc_id.strip_edges()
	if clean_id.is_empty():
		hide_preview()
		return
	if _target_kind != "npc" or _target_npc_id != clean_id:
		_camera_initialized = false
		_clear_emotion_bubble()
	_target_kind = "npc"
	_target_npc_id = clean_id
	_target_enemy_id = ""
	_allow_escaped_portrait = allow_escaped_portrait
	_active = true
	_status_label.text = ""
	_status_label.visible = true
	_set_rendering_enabled(true)
	set_process(true)
	_update_camera(0.0)


func show_enemy(enemy_id: String) -> void:
	var clean_id := enemy_id.strip_edges()
	if clean_id.is_empty():
		hide_preview()
		return
	if _target_kind != "enemy" or _target_enemy_id != clean_id:
		_camera_initialized = false
		_clear_emotion_bubble()
	_target_kind = "enemy"
	_target_npc_id = ""
	_target_enemy_id = clean_id
	_allow_escaped_portrait = false
	_active = true
	_status_label.text = ""
	_status_label.visible = true
	_clear_emotion_bubble()
	_set_rendering_enabled(true)
	set_process(true)
	_update_camera(0.0)


func hide_preview() -> void:
	_active = false
	_target_npc_id = ""
	_target_enemy_id = ""
	_target_kind = "npc"
	_allow_escaped_portrait = false
	_camera_initialized = false
	_last_target_snapshot.clear()
	_last_camera_front_dot = -1.0
	_last_obstruction_adjusted = false
	_status_label.text = ""
	_status_label.visible = true
	_set_rendering_enabled(false)
	set_process(false)


func _set_rendering_enabled(enabled: bool) -> void:
	if _subviewport == null:
		return
	_subviewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	)


func _process(delta: float) -> void:
	_update_camera(delta)
	_advance_emotion_bubble(delta)


func _on_dialogue_emotion_presented(npc_id: String, presentation: Dictionary) -> void:
	if not _active or _target_kind != "npc" or npc_id != _target_npc_id:
		return
	_emotion_bubble_presentation = presentation.duplicate(true)
	_emotion_bubble_hold_seconds = maxf(0.0, float(presentation.get("hold_seconds", EMOTION_BUBBLE_DEFAULT_HOLD_SECONDS)))
	_emotion_bubble_fade_seconds = maxf(0.01, float(presentation.get("fade_seconds", EMOTION_BUBBLE_DEFAULT_FADE_SECONDS)))
	_emotion_bubble_elapsed = 0.0
	_emotion_bubble_label.text = str(presentation.get("emoji", "…"))
	_emotion_bubble_root.modulate = Color.WHITE
	_emotion_bubble_root.visible = true
	_emotion_bubble_panel.visible = true


func _advance_emotion_bubble(delta: float) -> void:
	if _emotion_bubble_root == null or not _emotion_bubble_root.visible:
		return
	_emotion_bubble_elapsed += maxf(0.0, delta)
	if _emotion_bubble_elapsed <= _emotion_bubble_hold_seconds:
		return
	var fade_progress := (_emotion_bubble_elapsed - _emotion_bubble_hold_seconds) / _emotion_bubble_fade_seconds
	if fade_progress >= 1.0:
		_emotion_bubble_root.visible = false
		_emotion_bubble_panel.visible = false
		_emotion_bubble_root.modulate.a = 0.0
		return
	_emotion_bubble_root.modulate.a = 1.0 - fade_progress


func _clear_emotion_bubble() -> void:
	_emotion_bubble_elapsed = 0.0
	_emotion_bubble_presentation.clear()
	if _emotion_bubble_root != null:
		_emotion_bubble_root.visible = false
		_emotion_bubble_root.modulate = Color.WHITE
	if _emotion_bubble_panel != null:
		_emotion_bubble_panel.visible = false


func _update_camera(delta: float) -> void:
	if not _active or _camera == null or _subviewport == null:
		return
	var snapshot := _get_target_snapshot()
	if snapshot.is_empty():
		_show_unavailable("实时镜头暂不可用")
		return
	var target_visible := bool(snapshot.get("visible", false)) or (_target_kind == "npc" and _allow_escaped_portrait)
	if snapshot.is_empty() or not bool(snapshot.get("valid", false)) or not target_visible:
		_show_unavailable("目标当前不在可见场景中")
		return
	_last_target_snapshot = snapshot.duplicate(true)
	_status_label.visible = false

	var base_position: Vector3 = snapshot.get("world_position", Vector3.ZERO)
	var forward: Vector3 = snapshot.get("visual_forward", Vector3(0.0, 0.0, -1.0))
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var focus_height := float(snapshot.get("focus_height", CAMERA_FOCUS_HEIGHT))
	var camera_height := float(snapshot.get("camera_height", CAMERA_HEIGHT))
	var focus_position := base_position + Vector3.UP * focus_height
	var desired_position := base_position + forward * CAMERA_DISTANCE + Vector3.UP * camera_height
	desired_position = _resolve_camera_obstruction(focus_position, desired_position)

	if not _camera_initialized or delta <= 0.0:
		_camera.global_position = desired_position
		_camera_initialized = true
	else:
		var blend := 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta)
		_camera.global_position = _camera.global_position.lerp(desired_position, blend)
	_camera.look_at(focus_position, Vector3.UP)
	var npc_to_camera := _camera.global_position - base_position
	npc_to_camera.y = 0.0
	_last_camera_front_dot = (
		forward.dot(npc_to_camera.normalized())
		if npc_to_camera.length_squared() > 0.0001
		else -1.0
	)


func _get_target_snapshot() -> Dictionary:
	if _target_kind == "enemy":
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		if combat_system == null or not combat_system.has_method("get_enemy_portrait_snapshot"):
			return {}
		return combat_system.get_enemy_portrait_snapshot(_target_enemy_id)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_portrait_snapshot"):
		return {}
	return npc_system.get_npc_portrait_snapshot(_target_npc_id)


func _resolve_camera_obstruction(focus_position: Vector3, desired_position: Vector3) -> Vector3:
	_last_obstruction_adjusted = false
	var world := _subviewport.world_3d
	if world == null:
		return desired_position
	var ray_vector := desired_position - focus_position
	var ray_length := ray_vector.length()
	if ray_length <= CAMERA_MIN_DISTANCE:
		return desired_position
	var query := PhysicsRayQueryParameters3D.create(
		focus_position,
		desired_position,
		WORLD_STATIC_COLLISION_MASK
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return desired_position
	var hit_position: Vector3 = result.get("position", desired_position)
	var safe_distance := maxf(
		CAMERA_MIN_DISTANCE,
		focus_position.distance_to(hit_position) - CAMERA_WALL_MARGIN
	)
	_last_obstruction_adjusted = true
	return focus_position + ray_vector.normalized() * minf(safe_distance, ray_length)


func _show_unavailable(message: String) -> void:
	_status_label.text = message
	_status_label.visible = true
	_last_target_snapshot.clear()
	_last_camera_front_dot = -1.0


func debug_get_snapshot() -> Dictionary:
	var main_viewport := get_viewport()
	return {
		"active": _active,
		"target_kind": _target_kind,
		"target_npc_id": _target_npc_id,
		"target_enemy_id": _target_enemy_id,
		"allow_escaped_portrait": _allow_escaped_portrait,
		"rendering_enabled": _subviewport != null and _subviewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"shares_main_world": _subviewport != null and main_viewport != null and _subviewport.world_3d == main_viewport.world_3d,
		"viewport_size": _subviewport.size if _subviewport != null else Vector2i.ZERO,
		"camera_position": _camera.global_position if _camera != null else Vector3.ZERO,
		"configured_camera_distance": CAMERA_DISTANCE,
		"hides_main_fading_shells": _camera != null and not _camera.get_cull_mask_value(MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER),
		"shows_portrait_opaque_shells": _camera != null and _camera.get_cull_mask_value(PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER),
		"camera_front_dot": _last_camera_front_dot,
		"obstruction_adjusted": _last_obstruction_adjusted,
		"target_snapshot": _last_target_snapshot.duplicate(true),
		"frame_global_rect": get_global_rect(),
		"status_visible": _status_label != null and _status_label.visible,
		"emotion_bubble": {
			"visible": _emotion_bubble_root != null and _emotion_bubble_root.visible,
			"emoji": _emotion_bubble_label.text if _emotion_bubble_label != null else "",
			"elapsed_seconds": _emotion_bubble_elapsed,
			"hold_seconds": _emotion_bubble_hold_seconds,
			"fade_seconds": _emotion_bubble_fade_seconds,
			"layout": "upper_left_comic_pointer",
			"root_position": _emotion_bubble_root.position if _emotion_bubble_root != null else Vector2.ZERO,
			"panel_size": _emotion_bubble_panel.size if _emotion_bubble_panel != null else Vector2.ZERO,
			"tail_origin": Vector2(40.0, 57.0),
			"tail_tip": Vector2(55.0, 70.0),
			"tail_span": Vector2(21.0, 13.0),
			"tail_compact": true,
			"tail_origin_bottom_center": true,
			"tail_leaves_head_gap": true,
			"tail_points_down_right": true,
			"presentation": _emotion_bubble_presentation.duplicate(true)
		},
		"has_title_label": find_child("PortraitTitle", true, false) != null,
		"has_location_label": find_child("PortraitLocationLabel", true, false) != null,
	}
