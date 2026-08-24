extends PanelContainer

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const WORLD_STATIC_COLLISION_MASK := 1
const PORTRAIT_EXCLUDED_VISUAL_LAYER := 20
const VIEWPORT_SIZE := Vector2i(260, 480)
const CAMERA_DISTANCE := 3.9
const CAMERA_HEIGHT := 1.15
const CAMERA_FOCUS_HEIGHT := 0.92
const CAMERA_MIN_DISTANCE := 1.35
const CAMERA_WALL_MARGIN := 0.24
const CAMERA_FOLLOW_SPEED := 10.0

var _target_npc_id := ""
var _active := false
var _camera_initialized := false
var _subviewport: SubViewport
var _camera: Camera3D
var _status_label: Label
var _last_target_snapshot: Dictionary = {}
var _last_camera_front_dot := -1.0
var _last_obstruction_adjusted := false


func _ready() -> void:
	name = "NPCPortraitView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_view()
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

func show_npc(npc_id: String) -> void:
	var clean_id := npc_id.strip_edges()
	if clean_id.is_empty():
		hide_preview()
		return
	if _target_npc_id != clean_id:
		_camera_initialized = false
	_target_npc_id = clean_id
	_active = true
	_status_label.text = ""
	_status_label.visible = true
	_set_rendering_enabled(true)
	set_process(true)
	_update_camera(0.0)


func hide_preview() -> void:
	_active = false
	_target_npc_id = ""
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


func _update_camera(delta: float) -> void:
	if not _active or _camera == null or _subviewport == null:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_portrait_snapshot"):
		_show_unavailable("实时镜头暂不可用")
		return
	var snapshot: Dictionary = npc_system.get_npc_portrait_snapshot(_target_npc_id)
	if snapshot.is_empty() or not bool(snapshot.get("valid", false)) or not bool(snapshot.get("visible", false)):
		_show_unavailable("该 NPC 当前不在可见场景中")
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
		"target_npc_id": _target_npc_id,
		"rendering_enabled": _subviewport != null and _subviewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"shares_main_world": _subviewport != null and main_viewport != null and _subviewport.world_3d == main_viewport.world_3d,
		"viewport_size": _subviewport.size if _subviewport != null else Vector2i.ZERO,
		"camera_position": _camera.global_position if _camera != null else Vector3.ZERO,
		"configured_camera_distance": CAMERA_DISTANCE,
		"camera_front_dot": _last_camera_front_dot,
		"obstruction_adjusted": _last_obstruction_adjusted,
		"target_snapshot": _last_target_snapshot.duplicate(true),
		"frame_global_rect": get_global_rect(),
		"status_visible": _status_label != null and _status_label.visible,
		"has_title_label": find_child("PortraitTitle", true, false) != null,
		"has_location_label": find_child("PortraitLocationLabel", true, false) != null,
	}
