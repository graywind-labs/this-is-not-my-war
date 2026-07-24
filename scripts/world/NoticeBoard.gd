extends Node3D

const CLICK_AREA_NAME := "NoticeBoardClickArea"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const PICK_RAY_LENGTH := 1000.0
const PREVIEW_LENGTH := 18
const CLICK_SHAPE_SIZE := Vector3(2.2, 3.0, 0.9)

var _label: Label3D


func _ready() -> void:
	_label = get_node_or_null("VisualRoot/NoticeBoardLabel") as Label3D
	_ensure_click_area()
	_refresh_notice_preview()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("location_info_changed"):
		if not event_bus.location_info_changed.is_connected(_on_location_info_changed):
			event_bus.location_info_changed.connect(_on_location_info_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _is_notice_board_at_screen_position(mouse_event.position):
		return
	_activate_notice_board()
	get_viewport().set_input_as_handled()


func debug_activate() -> bool:
	_activate_notice_board()
	return true


func _on_location_info_changed(location_id: String) -> void:
	if location_id == "plaza":
		_refresh_notice_preview()


func _activate_notice_board() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("notice_board_clicked"):
		event_bus.notice_board_clicked.emit()


func _refresh_notice_preview() -> void:
	if _label == null:
		return
	var notice := ""
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("get_location_snapshot"):
		var plaza: Dictionary = memory_system.get_location_snapshot("plaza")
		notice = str(plaza.get("current_notice", "")).strip_edges()
	if notice.is_empty():
		_label.text = "公告牌\n（点击发布）"
		return
	var preview := notice
	if preview.length() > PREVIEW_LENGTH:
		preview = preview.substr(0, PREVIEW_LENGTH) + "…"
	_label.text = "公告牌\n%s" % preview


func _ensure_click_area() -> void:
	var click_area := get_node_or_null(CLICK_AREA_NAME) as Area3D
	if click_area == null:
		click_area = Area3D.new()
		click_area.name = CLICK_AREA_NAME
		add_child(click_area)
	var collision_shape := click_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		click_area.add_child(collision_shape)
	if collision_shape.shape == null:
		var shape := BoxShape3D.new()
		shape.size = CLICK_SHAPE_SIZE
		collision_shape.shape = shape
	click_area.set_meta("notice_board_hotspot", true)
	click_area.input_ray_pickable = true


func _is_notice_board_at_screen_position(screen_position: Vector2) -> bool:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null or get_viewport().world_3d == null:
		return false
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider := result.get("collider") as Node
	while collider != null:
		if bool(collider.get_meta("notice_board_hotspot", false)):
			return true
		collider = collider.get_parent()
	return false
