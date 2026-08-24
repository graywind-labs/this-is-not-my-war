extends Node3D

const ACTOR_MOTION_SCENE := preload("res://scenes/debug/ActorMotionBody.tscn")
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CELL_SIZE := 0.5
const MIN_X := -14.0
const MAX_X := 14.0
const MIN_Z := -9.0
const MAX_Z := 9.0

var _actors: Dictionary = {}
var _results: Dictionary = {}
var _configuration_errors: Array[String] = []
var _started := false
var _completed := false
var _elapsed_seconds := 0.0
var _route_pause_started := false
var _route_resume_started := false
var _route_pause_elapsed := 0.0
var _route_pause_position := Vector3.ZERO
var _pause_displacement := 0.0
var _maximum_route_lateral_deviation := 0.0
var _maximum_avoidance_lateral_deviation := 0.0
var _minimum_avoidance_clearance := INF
var _status_label: Label


func _ready() -> void:
	_build_environment()
	_build_navigation_region()
	_build_static_obstacles()
	_build_ui()
	_spawn_test_actors()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_start_test_routes()


func _physics_process(delta: float) -> void:
	if not _started or _completed:
		return
	_elapsed_seconds += delta
	_track_metrics(delta)
	_update_route_pause(delta)
	if _results.size() >= _actors.size():
		_completed = true
		_update_status_label()
	elif _elapsed_seconds > 12.0:
		for raw_actor_id in _actors.keys():
			var actor_id := str(raw_actor_id)
			if not _results.has(actor_id):
				_results[actor_id] = {"outcome": "timeout", "reason": "sandbox_timeout"}
		_completed = true
		_configuration_errors.append("sandbox_timeout")
		_update_status_label()
	elif int(_elapsed_seconds * 5.0) != int((_elapsed_seconds - delta) * 5.0):
		_update_status_label()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8:
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	elif event.keycode == KEY_R:
		get_tree().reload_current_scene()


func debug_get_sandbox_snapshot() -> Dictionary:
	var actor_snapshots: Dictionary = {}
	var authority_commit_count := 0
	for raw_actor_id in _actors.keys():
		var actor_id := str(raw_actor_id)
		var actor := _actors[actor_id] as ActorMotionBody
		if actor == null:
			continue
		actor_snapshots[actor_id] = actor.debug_get_motion_snapshot()
		authority_commit_count += int(actor.get_meta("authority_commit_count", 0))
	return {
		"started": _started,
		"completed": _completed,
		"elapsed_seconds": _elapsed_seconds,
		"actor_count": _actors.size(),
		"result_count": _results.size(),
		"results": _results.duplicate(true),
		"actors": actor_snapshots,
		"route_pause_started": _route_pause_started,
		"route_resume_started": _route_resume_started,
		"pause_displacement": _pause_displacement,
		"maximum_route_lateral_deviation": _maximum_route_lateral_deviation,
		"maximum_avoidance_lateral_deviation": _maximum_avoidance_lateral_deviation,
		"minimum_avoidance_clearance": _minimum_avoidance_clearance,
		"authority_commit_count": authority_commit_count,
		"navigation_region_count": find_children("*", "NavigationRegion3D", true, false).size(),
		"static_body_count": find_children("*", "StaticBody3D", true, false).size(),
		"configuration_errors": _configuration_errors.duplicate()
	}


func debug_get_actor(actor_id: String) -> ActorMotionBody:
	return _actors.get(actor_id) as ActorMotionBody


func _build_environment() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "GroundVisual"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(MAX_X - MIN_X, 0.08, MAX_Z - MIN_Z)
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, -0.06, 0.0)
	ground.material_override = _make_material(Color(0.13, 0.23, 0.18))
	add_child(ground)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	light.shadow_enabled = true
	light.light_energy = 1.2
	add_child(light)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 21.0, 19.0)
	camera.rotation_degrees = Vector3(-47.0, 0.0, 0.0)
	camera.fov = 58.0
	camera.current = true
	add_child(camera)


func _build_navigation_region() -> void:
	var vertices: Array[Vector3] = []
	var vertex_indices: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	var min_grid_x := int(floor(MIN_X / CELL_SIZE))
	var max_grid_x := int(ceil(MAX_X / CELL_SIZE))
	var min_grid_z := int(floor(MIN_Z / CELL_SIZE))
	var max_grid_z := int(ceil(MAX_Z / CELL_SIZE))
	for grid_x in range(min_grid_x, max_grid_x):
		for grid_z in range(min_grid_z, max_grid_z):
			var center := Vector2(
				(float(grid_x) + 0.5) * CELL_SIZE,
				(float(grid_z) + 0.5) * CELL_SIZE
			)
			if absf(center.x) < 2.2 and absf(center.y) < 2.2:
				continue
			var v00 := _get_or_add_nav_vertex(vertex_indices, vertices, grid_x, grid_z)
			var v01 := _get_or_add_nav_vertex(vertex_indices, vertices, grid_x, grid_z + 1)
			var v11 := _get_or_add_nav_vertex(vertex_indices, vertices, grid_x + 1, grid_z + 1)
			var v10 := _get_or_add_nav_vertex(vertex_indices, vertices, grid_x + 1, grid_z)
			polygons.append(PackedInt32Array([v00, v01, v11, v10]))
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.35
	navigation_mesh.set_vertices(PackedVector3Array(vertices))
	for polygon in polygons:
		navigation_mesh.add_polygon(polygon)
	var region := NavigationRegion3D.new()
	region.name = "SandboxNavigation"
	region.navigation_mesh = navigation_mesh
	region.use_edge_connections = true
	add_child(region)


func _build_static_obstacles() -> void:
	_add_static_box(
		"NavigationObstacle",
		Vector3(0.0, 1.0, 0.0),
		Vector3(3.4, 2.0, 3.4),
		Color(0.28, 0.31, 0.36)
	)
	_add_static_box(
		"PhysicalOnlyStuckWall",
		Vector3(0.0, 1.0, 6.0),
		Vector3(0.5, 2.0, 3.8),
		Color(0.52, 0.24, 0.22)
	)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(520.0, 174.0)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "T0129C-A2 运动沙盒：正在等待 NavigationServer 同步…"
	_status_label.add_theme_font_size_override("font_size", 17)
	margin.add_child(_status_label)


func _spawn_test_actors() -> void:
	_spawn_actor("route", Vector3(-10.0, 0.0, 0.0), Color(0.22, 0.72, 0.96))
	_spawn_actor("avoid_left", Vector3(-9.0, 0.0, -6.15), Color(0.96, 0.72, 0.22), 0.50)
	_spawn_actor("avoid_right", Vector3(9.0, 0.0, -5.85), Color(0.82, 0.38, 0.88), 0.48)
	_spawn_actor(
		"stuck",
		Vector3(-5.0, 0.0, 6.0),
		Color(0.92, 0.28, 0.22),
		0.44,
		{
			"stuck_recovery": {
				"sample_seconds": 0.25,
				"minimum_progress": 0.05,
				"repath_after_samples": 2,
				"fail_after_seconds": 2.6,
				"maximum_repaths_per_target": 2
			}
		}
	)
	_spawn_actor("unreachable", Vector3(-10.0, 0.0, 3.5), Color(0.34, 0.86, 0.52), 0.42)


func _spawn_actor(
	actor_id: String,
	start_position: Vector3,
	color: Color,
	avoidance_priority: float = 0.5,
	runtime_overrides: Dictionary = {}
) -> ActorMotionBody:
	var actor := ACTOR_MOTION_SCENE.instantiate() as ActorMotionBody
	actor.name = actor_id.to_pascal_case()
	actor.avoidance_priority_override = avoidance_priority
	actor.position = start_position
	actor.set_meta("actor_id", actor_id)
	actor.set_meta("authority_commit_count", 0)
	add_child(actor)
	if not runtime_overrides.is_empty():
		actor.configure_profile("npc", runtime_overrides)
	var label := actor.get_node_or_null("DebugLabel") as Label3D
	if label != null:
		label.text = actor_id
	var mesh := actor.get_node_or_null("ActorMesh") as MeshInstance3D
	if mesh != null:
		mesh.material_override = _make_material(color)
	actor.motion_arrived.connect(func(_request_id: String, _target: Vector3) -> void:
		_record_result(actor_id, "arrived", "arrived")
	)
	actor.motion_failed.connect(func(_request_id: String, reason: String) -> void:
		_record_result(actor_id, "failed", reason)
	)
	actor.motion_cancelled.connect(func(_request_id: String, reason: String) -> void:
		_record_result(actor_id, "cancelled", reason)
	)
	_actors[actor_id] = actor
	return actor


func _start_test_routes() -> void:
	_started = true
	(_actors["route"] as ActorMotionBody).request_motion(Vector3(10.0, 0.0, 0.0), "route")
	(_actors["avoid_left"] as ActorMotionBody).request_motion(Vector3(9.0, 0.0, -6.15), "avoid_left")
	(_actors["avoid_right"] as ActorMotionBody).request_motion(Vector3(-9.0, 0.0, -5.85), "avoid_right")
	(_actors["stuck"] as ActorMotionBody).request_motion(Vector3(5.0, 0.0, 6.0), "stuck")
	(_actors["unreachable"] as ActorMotionBody).request_motion(Vector3(20.0, 0.0, 3.5), "unreachable")
	_update_status_label()


func _track_metrics(_delta: float) -> void:
	var route := _actors.get("route") as ActorMotionBody
	if route != null:
		_maximum_route_lateral_deviation = maxf(_maximum_route_lateral_deviation, absf(route.position.z))
	var left := _actors.get("avoid_left") as ActorMotionBody
	var right := _actors.get("avoid_right") as ActorMotionBody
	if left != null and right != null:
		_minimum_avoidance_clearance = minf(
			_minimum_avoidance_clearance,
			Vector2(left.position.x, left.position.z).distance_to(Vector2(right.position.x, right.position.z))
		)
		_maximum_avoidance_lateral_deviation = maxf(
			_maximum_avoidance_lateral_deviation,
			maxf(absf(left.position.z + 6.15), absf(right.position.z + 5.85))
		)


func _update_route_pause(delta: float) -> void:
	var route := _actors.get("route") as ActorMotionBody
	if route == null or _results.has("route"):
		return
	if not _route_pause_started and _elapsed_seconds >= 0.55:
		_route_pause_started = true
		_route_pause_position = route.global_position
		route.set_motion_paused(true)
		return
	if _route_pause_started and not _route_resume_started:
		_route_pause_elapsed += delta
		_pause_displacement = maxf(_pause_displacement, route.global_position.distance_to(_route_pause_position))
		if _route_pause_elapsed >= 0.45:
			_route_resume_started = true
			route.set_motion_paused(false)


func _record_result(actor_id: String, outcome: String, reason: String) -> void:
	if _results.has(actor_id):
		return
	_results[actor_id] = {
		"outcome": outcome,
		"reason": reason,
		"position": (_actors[actor_id] as ActorMotionBody).global_position
	}
	_update_status_label()


func _update_status_label() -> void:
	if _status_label == null:
		return
	var lines := PackedStringArray([
		"T0129C-A2 独立实体运动沙盒",
		"蓝：绕建筑  黄/紫：2.4m 对向会车  红：卡死恢复  绿：不可达",
		"结果 %d/%d ｜ 最小会车间距 %.2fm ｜ 绕障侧移 %.2fm ｜ 暂停位移 %.3fm" % [
			_results.size(),
			_actors.size(),
			0.0 if is_inf(_minimum_avoidance_clearance) else _minimum_avoidance_clearance,
			_maximum_route_lateral_deviation,
			_pause_displacement
		],
		"%s ｜ R 重跑 ｜ F8 返回 Main" % ("验收运行完成" if _completed else "运行中…")
	])
	_status_label.text = "\n".join(lines)


func _add_static_box(node_name: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)
	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = box
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color)
	body.add_child(mesh_instance)
	return body


func _get_or_add_nav_vertex(
	vertex_indices: Dictionary,
	vertices: Array[Vector3],
	grid_x: int,
	grid_z: int
) -> int:
	var key := "%d:%d" % [grid_x, grid_z]
	if vertex_indices.has(key):
		return int(vertex_indices[key])
	var index := vertices.size()
	vertices.append(Vector3(float(grid_x) * CELL_SIZE, 0.05, float(grid_z) * CELL_SIZE))
	vertex_indices[key] = index
	return index


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material
