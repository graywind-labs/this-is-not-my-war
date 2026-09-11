class_name HorsePortraitViewport
extends PanelContainer


const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const WORLD_STATIC_COLLISION_MASK := 1
const PORTRAIT_EXCLUDED_VISUAL_LAYER := 20
const MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER := 19
const PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER := 18
const VIEWPORT_SIZE := Vector2i(260, 480)
const CAMERA_DISTANCE := 5.5
const CAMERA_HEIGHT := 0.92
const CAMERA_FOCUS_HEIGHT := 0.68
const CAMERA_MIN_DISTANCE := 1.35
const CAMERA_WALL_MARGIN := 0.24
const CAMERA_FOLLOW_SPEED := 10.0

var _target_horse_id := ""
var _active := false
var _camera_initialized := false
var _subviewport: SubViewport
var _camera: Camera3D
var _status_label: Label
var _last_target_snapshot: Dictionary = {}
var _last_obstruction_adjusted := false
var _last_focus_position := Vector3.ZERO
var _last_camera_front_dot := 0.0


func _ready() -> void:
	name = "HorsePortraitView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_view()
	_set_rendering_enabled(false)
	set_process(false)


func _build_view() -> void:
	var margin := MarginContainer.new()
	margin.name = "PortraitMargin"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
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
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(120.0, 0.0)
	status_overlay.add_child(_status_label)


func show_horse(horse_id: String) -> void:
	var clean_id := horse_id.strip_edges()
	if clean_id.is_empty():
		hide_preview()
		return
	if _target_horse_id != clean_id:
		_camera_initialized = false
	_target_horse_id = clean_id
	_active = true
	_set_rendering_enabled(true)
	set_process(true)
	_update_camera(0.0)


func hide_preview() -> void:
	_active = false
	_target_horse_id = ""
	_camera_initialized = false
	_last_target_snapshot.clear()
	_last_obstruction_adjusted = false
	_last_focus_position = Vector3.ZERO
	_last_camera_front_dot = 0.0
	if _status_label != null:
		_status_label.text = ""
		_status_label.visible = true
	_set_rendering_enabled(false)
	set_process(false)


func _set_rendering_enabled(enabled: bool) -> void:
	if _subviewport != null:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if not _active or _camera == null or _subviewport == null:
		return
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("get_horse_presentation_snapshot"):
		_show_unavailable("实时镜头暂不可用")
		return
	var snapshot: Dictionary = horse_system.get_horse_presentation_snapshot(_target_horse_id)
	if snapshot.is_empty() or not bool(snapshot.get("valid", false)) or not bool(snapshot.get("visible", false)):
		_show_unavailable("该马当前不在可见场景中")
		return
	_last_target_snapshot = snapshot.duplicate(true)
	_status_label.visible = false
	var base_position: Vector3 = snapshot.get("world_position", Vector3.ZERO)
	var forward: Vector3 = snapshot.get("portrait_camera_direction", snapshot.get("visual_forward", Vector3(0.0, 0.0, -1.0)))
	forward.y = 0.0
	forward = Vector3(0.0, 0.0, -1.0) if forward.length_squared() <= 0.0001 else forward.normalized()
	var focus_position: Vector3 = snapshot.get("focus_world_position", base_position + Vector3.UP * float(snapshot.get("focus_height", CAMERA_FOCUS_HEIGHT)))
	var camera_anchor_position: Vector3 = snapshot.get("camera_anchor_position", base_position)
	var camera_distance := float(snapshot.get("camera_distance", CAMERA_DISTANCE))
	var desired_position := camera_anchor_position + forward * camera_distance + Vector3.UP * float(snapshot.get("camera_height", CAMERA_HEIGHT))
	# Stable stall rails sit between every horse and the public aisle. Applying the
	# NPC wall-shortening rule to those rails pushes the camera inside the horse.
	# Keep the same shared-world follow camera, but retain the authored aisle shot
	# while the horse is in its own stall; moving horses still use full obstruction.
	if str(snapshot.get("source_location", "")) == "stable":
		_last_obstruction_adjusted = false
	else:
		desired_position = _resolve_camera_obstruction(focus_position, desired_position)
	if not _camera_initialized or delta <= 0.0:
		_camera.global_position = desired_position
		_camera_initialized = true
	else:
		_camera.global_position = _camera.global_position.lerp(desired_position, 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta))
	_camera.look_at(focus_position, Vector3.UP)
	_last_focus_position = focus_position
	var camera_to_focus := focus_position - _camera.global_position
	_last_camera_front_dot = camera_to_focus.normalized().dot(-forward) if camera_to_focus.length_squared() > 0.0001 else 0.0


func _resolve_camera_obstruction(focus_position: Vector3, desired_position: Vector3) -> Vector3:
	_last_obstruction_adjusted = false
	var world := _subviewport.world_3d
	if world == null:
		return desired_position
	var ray_vector := desired_position - focus_position
	var ray_length := ray_vector.length()
	if ray_length <= CAMERA_MIN_DISTANCE:
		return desired_position
	var query := PhysicsRayQueryParameters3D.create(focus_position, desired_position, WORLD_STATIC_COLLISION_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return desired_position
	var hit_position: Vector3 = result.get("position", desired_position)
	var safe_distance := maxf(CAMERA_MIN_DISTANCE, focus_position.distance_to(hit_position) - CAMERA_WALL_MARGIN)
	_last_obstruction_adjusted = true
	return focus_position + ray_vector.normalized() * minf(safe_distance, ray_length)


func _show_unavailable(message: String) -> void:
	_status_label.text = message
	_status_label.visible = true
	_last_target_snapshot.clear()
	_last_focus_position = Vector3.ZERO
	_last_camera_front_dot = 0.0


func debug_get_snapshot() -> Dictionary:
	var main_viewport := get_viewport()
	return {
		"active": _active,
		"target_horse_id": _target_horse_id,
		"rendering_enabled": _subviewport != null and _subviewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"shares_main_world": _subviewport != null and main_viewport != null and _subviewport.world_3d == main_viewport.world_3d,
		"viewport_size": _subviewport.size if _subviewport != null else Vector2i.ZERO,
		"camera_position": _camera.global_position if _camera != null else Vector3.ZERO,
		"configured_camera_distance": CAMERA_DISTANCE,
		"hides_main_fading_shells": _camera != null and not _camera.get_cull_mask_value(MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER),
		"shows_portrait_opaque_shells": _camera != null and _camera.get_cull_mask_value(PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER),
		"obstruction_adjusted": _last_obstruction_adjusted,
		"focus_position": _last_focus_position,
		"camera_front_dot": _last_camera_front_dot,
		"target_snapshot": _last_target_snapshot.duplicate(true),
		"frame_global_rect": get_global_rect(),
		"status_visible": _status_label != null and _status_label.visible,
	}
