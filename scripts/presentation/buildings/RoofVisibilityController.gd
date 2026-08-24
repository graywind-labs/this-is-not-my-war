class_name RoofVisibilityController
extends Node

signal roof_visibility_changed(camera_distance: float, zoom_normalized: float, view_snapshots: Array)


@export var camera_path: NodePath
@export var source_near_distance := 18.0
@export var source_far_distance := 42.0
@export_range(0.001, 1.0, 0.001) var update_epsilon := 0.01

var _camera: Camera3D
var _views: Array[Node] = []
var _last_camera_distance := -1.0
var _last_zoom_normalized := 0.0


func _ready() -> void:
	add_to_group("roof_visibility_controller")
	_resolve_camera()
	call_deferred("_discover_views")


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_resolve_camera()
	if _camera == null:
		return
	_prune_views()
	var camera_distance := _camera.position.length()
	if absf(camera_distance - _last_camera_distance) < update_epsilon:
		return
	_apply_camera_distance(camera_distance)


func register_view(view: Node) -> void:
	if view == null or not view.has_method("apply_roof_camera_distance"):
		return
	if not _views.has(view):
		_views.append(view)
	if _last_camera_distance >= 0.0:
		view.call("apply_roof_camera_distance", _last_camera_distance, _last_zoom_normalized)


func unregister_view(view: Node) -> void:
	_views.erase(view)


func debug_get_snapshot() -> Dictionary:
	_prune_views()
	var view_snapshots := _collect_view_snapshots()
	return {
		"camera_available": _camera != null and is_instance_valid(_camera),
		"camera_distance": _last_camera_distance,
		"zoom_normalized": _last_zoom_normalized,
		"source_near_distance": source_near_distance,
		"source_far_distance": source_far_distance,
		"registered_view_count": _views.size(),
		"views": view_snapshots
	}


func debug_apply_distance(camera_distance: float) -> Dictionary:
	_apply_camera_distance(maxf(camera_distance, 0.0))
	return debug_get_snapshot()


func _resolve_camera() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D


func _discover_views() -> void:
	for view in get_tree().get_nodes_in_group("building_art_view"):
		register_view(view)
	if _camera != null:
		_apply_camera_distance(_camera.position.length())


func _apply_camera_distance(camera_distance: float) -> void:
	_last_camera_distance = camera_distance
	_last_zoom_normalized = clampf(
		inverse_lerp(source_near_distance, source_far_distance, camera_distance),
		0.0,
		1.0
	)
	for view in _views:
		view.call("apply_roof_camera_distance", camera_distance, _last_zoom_normalized)
	roof_visibility_changed.emit(_last_camera_distance, _last_zoom_normalized, _collect_view_snapshots())


func _prune_views() -> void:
	for index in range(_views.size() - 1, -1, -1):
		if not is_instance_valid(_views[index]) or not _views[index].is_inside_tree():
			_views.remove_at(index)


func _collect_view_snapshots() -> Array:
	var snapshots: Array[Dictionary] = []
	for view in _views:
		if view.has_method("get_roof_visibility_snapshot"):
			snapshots.append(view.call("get_roof_visibility_snapshot"))
	return snapshots
