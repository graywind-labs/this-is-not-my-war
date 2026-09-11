extends Node3D


const PLAN_PATH := "res://data/presentation/station_spatial_plan.json"

const COLOR_UNDERLAY := Color("#405842")
const COLOR_ROAD := Color("#76634f")
const COLOR_ENEMY_ROAD := Color("#73564a")
const COLOR_TRADE_ROAD := Color("#715f4b")
const COLOR_WALL := Color("#797b83")
const COLOR_PLAZA := Color("#766552")
const COLOR_LOT := Color(0.17, 0.22, 0.27, 0.68)
const COLOR_ENVELOPE := Color("#627384")
const COLOR_POSITION := Color("#f0c85e")
const COLOR_CIRCULATION := Color(0.20, 0.72, 0.82, 0.72)
const COLOR_LEVEL_2 := Color(0.94, 0.55, 0.20, 0.90)
const COLOR_LEVEL_3_PLUS := Color(0.68, 0.43, 0.88, 0.90)
const COLOR_PRESENTATION_FIXTURE := Color(0.64, 0.68, 0.70, 0.82)
const COLOR_ENTRY := Color("#71d1ce")
const COLOR_OLD := Color(0.95, 0.42, 0.29, 0.9)
const COLOR_ENEMY := Color("#bd4d45")
const COLOR_RALLY := Color("#5e88c8")
const COLOR_MERCHANT := Color("#d3a85c")
const COLOR_WATER := Color(0.13, 0.45, 0.67, 0.9)
const COLOR_RIDGE := Color("#77736c")
const COLOR_TREE_TRUNK := Color("#59432f")
const COLOR_TREE_CANOPY := Color("#365f3a")
const COLOR_FOG := Color(0.28, 0.34, 0.32, 0.16)

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var status_label: Label = $UI/SafeArea/Panel/Margin/VBox/StatusLabel
@onready var labels_root: Node3D = $Runtime/Labels
@onready var current_reference_root: Node3D = $Runtime/CurrentReference
@onready var nature_root: Node3D = $Runtime/Nature
@onready var max_level_layouts_root: Node3D = $Runtime/MaxLevelLayouts
@onready var enemy_stress: Node3D = $Runtime/EnemyStress
@onready var escape_stress: Node3D = $Runtime/EscapeStress

var _plan: Dictionary = {}
var _material_cache: Dictionary = {}
var _labels_visible := true
var _current_reference_visible := true
var _nature_visible := true
var _max_level_layouts_visible := true
var _ui_visible := true
var _last_camera_snapshot := ""
var _forest_instance_count := 0
var _terrain_tile_count := 0
var _building_name_label_count := 0


func _ready() -> void:
	_plan = _load_json(PLAN_PATH)
	if _plan.is_empty():
		push_error("StationSpatialSandbox could not load %s" % PLAN_PATH)
		status_label.text = "空间规划配置读取失败"
		return
	_build_sandbox()
	_apply_camera_plan()
	_update_status_label()


func _process(_delta: float) -> void:
	var camera_snapshot := "%.2f|%.2f|%.2f" % [
		camera_rig.global_position.x,
		camera_rig.global_position.z,
		camera.position.length()
	]
	if camera_snapshot != _last_camera_snapshot:
		_last_camera_snapshot = camera_snapshot
		_update_status_label()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_L:
			_labels_visible = not _labels_visible
			labels_root.visible = _labels_visible
		KEY_V:
			_current_reference_visible = not _current_reference_visible
			current_reference_root.visible = _current_reference_visible
		KEY_N:
			_nature_visible = not _nature_visible
			nature_root.visible = _nature_visible
		KEY_P:
			_max_level_layouts_visible = not _max_level_layouts_visible
			max_level_layouts_root.visible = _max_level_layouts_visible
		KEY_M:
			enemy_stress.toggle_simulation()
		KEY_0:
			enemy_stress.reset_simulation()
		KEY_X:
			escape_stress.toggle_simulation()
		KEY_9:
			escape_stress.reset_simulation()
		KEY_F:
			_focus_camera(_v2(_plan.camera.get("initial_focus", [0.0, 9.0])))
		KEY_B:
			_focus_camera(_get_lot_vector("blacksmith", "center"))
		KEY_E:
			_focus_camera(_get_enemy_stage_point("spawn") + Vector2(0.0, -35.0))
		KEY_R:
			var rear_route: Dictionary = _plan.get("rear_route", {})
			_focus_camera(_v2(rear_route.get("escape_completion", [-54.0, -305.0])) + Vector2(0.0, 55.0))
		KEY_H:
			_ui_visible = not _ui_visible
			$UI.visible = _ui_visible
		_:
			return
	_update_status_label()
	get_viewport().set_input_as_handled()


func get_validation_snapshot() -> Dictionary:
	var station: Dictionary = _plan.get("station", {})
	var terrain: Dictionary = _plan.get("terrain", {})
	var enemy_route: Dictionary = _plan.get("enemy_route", {})
	var camera_plan: Dictionary = _plan.get("camera", {})
	var interior_bounds := _rect_from_bounds(station.get("interior_bounds", []))
	var wall_bounds := _wall_segment_bounds(station.get("wall_segments", []))
	var current_reference: Dictionary = station.get("current_reference", {})
	var plaza: Dictionary = station.get("plaza", {})
	var lot_validation := _validate_lots()
	var road_validation := _validate_road_lot_clearance()
	var front_gate: Dictionary = station.get("front_gate", {})
	var spawn_center := _v2(enemy_route.get("spawn_zone_center", [0.0, 0.0]))
	var gate_center := _v2(front_gate.get("center", [0.0, 0.0]))
	var environment: Dictionary = _plan.get("environment", {})
	var rear_route: Dictionary = _plan.get("rear_route", {})
	var escape_completion := _v2(rear_route.get("escape_completion", [0.0, 0.0]))
	var back_gate := _v2(rear_route.get("back_gate", [0.0, 0.0]))
	var terrain_rect := Rect2(
		_v2(terrain.get("underlay_center", [0.0, 0.0])) - _v2(terrain.get("underlay_size", [0.0, 0.0])) * 0.5,
		_v2(terrain.get("underlay_size", [0.0, 0.0]))
	)
	var direction_errors := _validate_eight_direction_lots()
	var entrance_access_errors := _validate_lot_entrance_access()
	var main_reference_layout_errors := _validate_main_reference_layout()
	var capacity_layout_validation := _validate_capacity_layouts()
	var stress_footprint := _camera_ground_footprint(camera_plan)
	var enemy_stress_snapshot: Dictionary = enemy_stress.get_validation_snapshot()
	var escape_stress_snapshot: Dictionary = escape_stress.get_validation_snapshot()
	var enemy_route_lot_errors := _validate_enemy_route_lot_clearance()
	return {
		"schema_version": str(_plan.get("schema_version", "")),
		"config_loaded": not _plan.is_empty(),
		"lot_count": (_plan.get("building_lots", []) as Array).size(),
		"road_count": (_plan.get("roads", []) as Array).size(),
		"route_stage_count": (enemy_route.get("stages", []) as Array).size(),
		"lot_overlap_count": lot_validation.overlaps.size(),
		"lots_outside_count": lot_validation.outside.size(),
		"lot_overlaps": lot_validation.overlaps,
		"lots_outside": lot_validation.outside,
		"road_lot_overlap_count": road_validation.size(),
		"road_lot_overlaps": road_validation,
		"wall_size": wall_bounds.size,
		"interior_size": interior_bounds.size,
		"target_interior_area_m2": interior_bounds.size.x * interior_bounds.size.y,
		"current_area_m2": float(current_reference.get("area_m2", 0.0)),
		"area_multiplier": (interior_bounds.size.x * interior_bounds.size.y) / maxf(float(current_reference.get("area_m2", 1.0)), 1.0),
		"detail_size": _v2(terrain.get("detail_size", [0.0, 0.0])),
		"underlay_size": _v2(terrain.get("underlay_size", [0.0, 0.0])),
		"ground_color": str(terrain.get("continuous_ground_color", "")),
		"terrain_layer_count": $Runtime/Terrain.get_child_count(),
		"terrain_tile_count": _terrain_tile_count,
		"ground_surface_elevation_m": float(terrain.get("ground_surface_elevation_m", 0.0)),
		"river_surface_elevation_m": float(environment.get("river_surface_elevation_m", 0.0)),
		"station_above_river_m": float(terrain.get("ground_surface_elevation_m", 0.0)) - float(environment.get("river_surface_elevation_m", 0.0)),
		"enemy_spawn_to_front_gate_m": spawn_center.distance_to(gate_center),
		"enemy_spawn_edge_inset_m": _point_edge_inset(spawn_center, terrain_rect),
		"back_gate_to_escape_completion_m": back_gate.distance_to(escape_completion),
		"escape_completion_edge_inset_m": _point_edge_inset(escape_completion, terrain_rect),
		"camera_min_distance": float(camera_plan.get("min_distance", 0.0)),
		"camera_max_distance": float(camera_plan.get("max_distance", 0.0)),
		"camera_to_terrain_min_margin_m": _camera_to_terrain_min_margin(terrain_rect, camera_plan),
		"camera_21_9_ground_footprint_size": stress_footprint.size,
		"camera_21_9_to_terrain_min_margin_m": _camera_footprint_to_terrain_min_margin(terrain_rect, camera_plan, stress_footprint),
		"rotated_lot_count": _count_rotated_lots(),
		"eight_direction_lot_count": 12 - direction_errors.size(),
		"eight_direction_errors": direction_errors,
		"building_name_label_count": _building_name_label_count,
		"entrance_access_error_count": entrance_access_errors.size(),
		"entrance_access_errors": entrance_access_errors,
		"layout_reference": str(station.get("layout_reference", "")),
		"main_reference_layout_error_count": main_reference_layout_errors.size(),
		"main_reference_layout_errors": main_reference_layout_errors,
		"max_level_layout_count": int(capacity_layout_validation.get("layout_count", 0)),
		"max_level_position_rect_count": int(capacity_layout_validation.get("position_count", 0)),
		"authoritative_position_rect_count": int(capacity_layout_validation.get("authoritative_position_count", 0)),
		"stable_horse_anchor_count": int(capacity_layout_validation.get("stable_horse_anchor_count", 0)),
		"minimum_primary_aisle_width_m": float(capacity_layout_validation.get("minimum_primary_aisle_width_m", 0.0)),
		"capacity_layout_error_count": (capacity_layout_validation.get("errors", []) as Array).size(),
		"capacity_layout_errors": capacity_layout_validation.get("errors", []),
		"enemy_stress": enemy_stress_snapshot,
		"enemy_stress_count": int(enemy_stress_snapshot.get("enemy_count", 0)),
		"enemy_stress_configuration_error_count": int(enemy_stress_snapshot.get("configuration_error_count", 0)),
		"enemy_stress_stage_corridor_error_count": int(enemy_stress_snapshot.get("stage_corridor_error_count", 0)),
		"enemy_stress_spawn_inside_zone": bool(enemy_stress_snapshot.get("spawn_formation_inside_zone", false)),
		"enemy_spawn_outside_initial_view": _enemy_spawn_outside_initial_view(stress_footprint, camera_plan, enemy_route),
		"enemy_route_lot_clearance_error_count": enemy_route_lot_errors.size(),
		"enemy_route_lot_clearance_errors": enemy_route_lot_errors,
		"escape_stress": escape_stress_snapshot,
		"escape_stress_configuration_error_count": int(escape_stress_snapshot.get("configuration_error_count", 0)),
		"escape_stress_route_distance_m": float(escape_stress_snapshot.get("route_distance_m", 0.0)),
		"escape_five_round_window_available": bool(escape_stress_snapshot.get("five_round_window_available", false)),
		"escape_completion_requires_final_point": bool(escape_stress_snapshot.get("completion_requires_final_point", false)),
		"main_hall_center": _get_lot_vector("main_hall", "center"),
		"main_hall_lot_size": _get_lot_vector("main_hall", "lot_size"),
		"main_hall_envelope_size": _get_lot_vector("main_hall", "envelope_size"),
		"main_hall_graybox_height": float(_get_lot_value("main_hall", "graybox_height")),
		"plaza_patch_area_m2": _plaza_patch_area(plaza),
		"forest_instance_count": _forest_instance_count,
		"forest_scatter_bounds": _rect_from_bounds((_plan.get("environment", {}) as Dictionary).get("forest_scatter_bounds", [])),
		"workshop_orientation_direction": _get_lot_value("workshop", "orientation_direction"),
		"blacksmith_lot_size": _get_lot_vector("blacksmith", "lot_size"),
		"blacksmith_max_positions": int(_get_lot_value("blacksmith", "max_visual_positions")),
		"generated_mesh_count": $Runtime.find_children("*", "MeshInstance3D", true, false).size(),
		"generated_label_count": labels_root.get_child_count()
	}


func debug_focus_area(area_id: String) -> Dictionary:
	match area_id:
		"overview":
			_focus_camera(_v2(_plan.camera.get("initial_focus", [0.0, 9.0])))
		"blacksmith":
			_focus_camera(_get_lot_vector("blacksmith", "center"))
		"enemy_route":
			_focus_camera(_get_enemy_stage_point("spawn") + Vector2(0.0, -35.0))
		"rear_route":
			var rear_route: Dictionary = _plan.get("rear_route", {})
			_focus_camera(_v2(rear_route.get("escape_completion", [-54.0, -305.0])) + Vector2(0.0, 55.0))
		_:
			return {"ok": false, "reason": "unknown_area", "area_id": area_id}
	return {
		"ok": true,
		"area_id": area_id,
		"camera_rig_position": camera_rig.global_position,
		"camera_distance": camera.position.length()
	}


func _build_sandbox() -> void:
	_build_terrain()
	_build_roads_and_plaza()
	_build_walls_and_gates()
	_build_current_reference()
	_build_building_lots()
	_build_enemy_route()
	_build_rear_route()
	_build_natural_boundary()


func _build_terrain() -> void:
	var terrain: Dictionary = _plan.get("terrain", {})
	var ground_color := Color.from_string(str(terrain.get("continuous_ground_color", "#405842")), COLOR_UNDERLAY)
	var center := _v2(terrain.get("underlay_center", [0.0, 0.0]))
	var size := _v2(terrain.get("underlay_size", [0.0, 0.0]))
	var ground_surface := float(terrain.get("ground_surface_elevation_m", 0.0))
	var ground_depth := maxf(float(terrain.get("ground_depth_m", 2.4)), 0.3)
	var channel_center_x := float(terrain.get("river_channel_center_x", -97.0))
	var environment: Dictionary = _plan.get("environment", {})
	var channel_width := float(environment.get("river_channel_width", 30.0))
	var world_left := center.x - size.x * 0.5
	var world_right := center.x + size.x * 0.5
	var channel_left := channel_center_x - channel_width * 0.5
	var channel_right := channel_center_x + channel_width * 0.5
	var ground := Node3D.new()
	ground.name = "ContinuousDeepGrass"
	$Runtime/Terrain.add_child(ground)
	_add_box(ground, "WestGround", Vector3((world_left + channel_left) * 0.5, ground_surface - ground_depth * 0.5, center.y), Vector3(channel_left - world_left, ground_depth, size.y), ground_color)
	_add_box(ground, "EastGround", Vector3((channel_right + world_right) * 0.5, ground_surface - ground_depth * 0.5, center.y), Vector3(world_right - channel_right, ground_depth, size.y), ground_color)
	_terrain_tile_count = 2


func _build_roads_and_plaza() -> void:
	var station: Dictionary = _plan.get("station", {})
	var plaza: Dictionary = station.get("plaza", {})
	var plaza_patches: Array = plaza.get("patches", [])
	for patch_index in plaza_patches.size():
		var patch: Dictionary = plaza_patches[patch_index]
		var patch_mesh := _add_flat_box(
			$Runtime/Roads,
			"JunctionPatch%02d" % patch_index,
			_v2(patch.get("center", [0.0, 0.0])),
			_v2(patch.get("size", [0.0, 0.0])),
			0.01 + float(patch_index) * 0.002,
			0.08,
			COLOR_PLAZA
		)
		patch_mesh.rotation.y = deg_to_rad(float(patch.get("rotation_degrees", 0.0)))
	var plaza_center := _v2(plaza.get("center", [0.0, 0.0]))
	_add_label("PlazaLabel", Vector3(plaza_center.x, 0.55, plaza_center.y), str(plaza.get("label", "驿路交汇")), Color("#e8ddbd"), 38)
	for raw_road in _plan.get("roads", []):
		var road: Dictionary = raw_road
		var kind := str(road.get("kind", "service"))
		var color := COLOR_ROAD
		if kind == "enemy":
			color = COLOR_ENEMY_ROAD
		elif kind == "trade":
			color = COLOR_TRADE_ROAD
		if road.has("from") and road.has("to"):
			_add_segment(
				$Runtime/Roads,
				_sanitize_name(str(road.get("id", "Road"))),
				_v2(road.get("from", [0.0, 0.0])),
				_v2(road.get("to", [0.0, 0.0])),
				float(road.get("width", 3.0)),
				0.06,
				color,
				0.03
			)
		else:
			var road_mesh := _add_flat_box(
				$Runtime/Roads,
				_sanitize_name(str(road.get("id", "Road"))),
				_v2(road.get("center", [0.0, 0.0])),
				_v2(road.get("size", [0.0, 0.0])),
				0.03,
				0.06,
				color
			)
			road_mesh.rotation.y = deg_to_rad(float(road.get("rotation_degrees", 0.0)))


func _build_walls_and_gates() -> void:
	var station: Dictionary = _plan.get("station", {})
	var thickness := float(station.get("wall_thickness", 1.2))
	var height := float(station.get("wall_height", 2.4))
	for raw_segment in station.get("wall_segments", []):
		var segment: Dictionary = raw_segment
		_add_segment(
			$Runtime/Walls,
			"Wall_%s" % str(segment.get("id", "segment")),
			_v2(segment.get("from", [0.0, 0.0])),
			_v2(segment.get("to", [0.0, 0.0])),
			thickness,
			height,
			COLOR_WALL,
			height * 0.5
		)
	var front_gate: Dictionary = station.get("front_gate", {})
	var front_center := _v2(front_gate.get("center", [0.0, 0.0]))
	var back_gate: Dictionary = station.get("back_gate", {})
	var back_center := _v2(back_gate.get("center", [0.0, 0.0]))
	_add_label("FrontGateLabel", Vector3(front_center.x, 3.2, front_center.y), "正门 %.1f m" % float(front_gate.get("clear_width", 6.0)), Color.WHITE, 38)
	_add_label("BackGateLabel", Vector3(back_center.x, 3.2, back_center.y), "后门 %.1f m" % float(back_gate.get("clear_width", 5.0)), Color.WHITE, 38)


func _add_wall_with_gap(parent: Node3D, prefix: String, min_x: float, max_x: float, z: float, gap_center_x: float, gap_width: float, thickness: float, height: float) -> void:
	var gap_min := gap_center_x - gap_width * 0.5
	var gap_max := gap_center_x + gap_width * 0.5
	if gap_min > min_x:
		_add_box(parent, prefix + "Left", Vector3((min_x + gap_min) * 0.5, height * 0.5, z), Vector3(gap_min - min_x, height, thickness), COLOR_WALL)
	if gap_max < max_x:
		_add_box(parent, prefix + "Right", Vector3((gap_max + max_x) * 0.5, height * 0.5, z), Vector3(max_x - gap_max, height, thickness), COLOR_WALL)


func _build_current_reference() -> void:
	var station: Dictionary = _plan.get("station", {})
	var reference: Dictionary = station.get("current_reference", {})
	var center := _v2(reference.get("center", [0.0, 0.0]))
	var size := _v2(reference.get("size", [0.0, 0.0]))
	_add_rect_outline(current_reference_root, "CurrentWallFootprint", center, size, 0.22, COLOR_OLD)
	_add_label(
		"CurrentReferenceLabel",
		Vector3(center.x, 1.1, center.y),
		"旧墙内 28 × 26 m / 728㎡",
		Color("#ff8066"),
		38
	)


func _build_building_lots() -> void:
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		var lot_id := str(lot.get("id", "unknown"))
		var center := _v2(lot.get("center", [0.0, 0.0]))
		var lot_size := _v2(lot.get("lot_size", [1.0, 1.0]))
		var envelope_size := _v2(lot.get("envelope_size", [1.0, 1.0]))
		var graybox_height := maxf(float(lot.get("graybox_height", 1.2)), 0.2)
		var rotation_degrees := float(lot.get("rotation_degrees", 0.0))
		var group := Node3D.new()
		group.name = _sanitize_name(lot_id)
		group.position = Vector3(center.x, 0.0, center.y)
		group.rotation.y = deg_to_rad(rotation_degrees)
		$Runtime/BuildingLots.add_child(group)

		_add_flat_box(group, "ReservedLot", Vector2.ZERO, lot_size, 0.08, 0.12, COLOR_LOT)
		_add_box(group, "MaxEnvelope", Vector3(0.0, 0.1 + graybox_height * 0.5, 0.0), Vector3(envelope_size.x, graybox_height, envelope_size.y), _lot_envelope_color(lot_id))
		_add_rect_outline(group, "LotBoundary", Vector2.ZERO, lot_size, 0.16, Color(0.88, 0.92, 0.94, 0.8))
		_add_entry_marker(group, Vector2.ZERO, envelope_size, str(lot.get("entry_facing", "+Z")))
		_build_max_level_layout_overlay(lot_id, center, rotation_degrees, graybox_height)

		var name_label := _add_label("BuildingName_%s" % lot_id, Vector3(center.x, maxf(4.2, graybox_height + 2.0), center.y), str(lot.get("label", lot_id)), Color("#fff2c6"), 20)
		name_label.fixed_size = true
		name_label.outline_size = 6
		_building_name_label_count += 1
		var label_text := "%s m · 朝向%s（%+.0f°）\n%s" % [
			_format_size(lot_size),
			str(lot.get("orientation_direction", "?")),
			rotation_degrees,
			str(lot.get("capacity_summary", ""))
		]
		_add_label(lot_id + "DetailLabel", Vector3(center.x, maxf(2.65, graybox_height + 0.5), center.y), label_text, Color.WHITE, 30)


func _add_entry_marker(parent: Node3D, center: Vector2, envelope_size: Vector2, facing: String) -> void:
	var direction := Vector2(0.0, 1.0)
	match facing:
		"-Z": direction = Vector2(0.0, -1.0)
		"+X": direction = Vector2(1.0, 0.0)
		"-X": direction = Vector2(-1.0, 0.0)
	var half_extent := envelope_size.y * 0.5 if absf(direction.y) > 0.5 else envelope_size.x * 0.5
	var marker_center := center + direction * (half_extent + 0.8)
	var marker := _add_box(parent, "Entry", Vector3(marker_center.x, 0.28, marker_center.y), Vector3(1.2, 0.45, 1.2), COLOR_ENTRY)
	marker.rotation.y = atan2(direction.x, direction.y)


func _build_max_level_layout_overlay(lot_id: String, center: Vector2, rotation_degrees: float, graybox_height: float) -> void:
	var layouts: Dictionary = _plan.get("max_level_layouts", {})
	var layout: Dictionary = layouts.get(lot_id, {})
	if layout.is_empty():
		return
	var group := Node3D.new()
	group.name = _sanitize_name(lot_id + "_MaxLevelLayout")
	group.position = Vector3(center.x, graybox_height + 0.22, center.y)
	group.rotation.y = deg_to_rad(rotation_degrees)
	max_level_layouts_root.add_child(group)
	for raw_lane in layout.get("circulation", []):
		var lane: Dictionary = raw_lane
		var lane_mesh := _add_flat_box(group, "Lane_" + str(lane.get("id", "unknown")), _v2(lane.get("center", [0.0, 0.0])), _v2(lane.get("size", [1.0, 1.0])), 0.02, 0.10, COLOR_CIRCULATION)
		lane_mesh.rotation.y = deg_to_rad(float(lane.get("rotation_degrees", 0.0)))
	for raw_position in layout.get("positions", []):
		var position: Dictionary = raw_position
		var color := _capacity_position_color(position)
		var footprint := _add_flat_box(group, "Footprint_" + str(position.get("id", "unknown")), _v2(position.get("center", [0.0, 0.0])), _v2(position.get("size", [1.0, 1.0])), 0.10, 0.16, color)
		footprint.rotation.y = deg_to_rad(float(position.get("rotation_degrees", 0.0)))
		var marker_center := _v2(position.get("center", [0.0, 0.0]))
		_add_cylinder(group, "Anchor_" + str(position.get("id", "unknown")), Vector3(marker_center.x, 0.28, marker_center.y), 0.18, 0.18, color.lightened(0.16))


func _capacity_position_color(position: Dictionary) -> Color:
	var authority := str(position.get("authority", ""))
	if authority == "presentation_fixture" or authority == "presentation_anchor":
		return COLOR_PRESENTATION_FIXTURE
	var required_level := int(position.get("required_level", 1))
	if required_level >= 3:
		return COLOR_LEVEL_3_PLUS
	if required_level == 2:
		return COLOR_LEVEL_2
	return COLOR_POSITION


func _build_enemy_route() -> void:
	var route: Dictionary = _plan.get("enemy_route", {})
	var spawn_center := _v2(route.get("spawn_zone_center", [0.0, 0.0]))
	var spawn_size := _v2(route.get("spawn_zone_size", [0.0, 0.0]))
	_add_flat_box($Runtime/Routes, "EnemySpawnZone", spawn_center, spawn_size, 0.09, 0.14, Color(0.5, 0.12, 0.12, 0.55))
	_add_rect_outline($Runtime/Routes, "EnemySpawnOutline", spawn_center, spawn_size, 0.2, COLOR_ENEMY)

	var stages: Array = route.get("stages", [])
	for index in stages.size():
		var stage: Dictionary = stages[index]
		var point := _v2(stage.get("point", [0.0, 0.0]))
		_add_cylinder($Runtime/Routes, "EnemyStage%02d" % index, Vector3(point.x, 0.35, point.y), 0.75, 0.35, COLOR_ENEMY)
		_add_label("EnemyStageLabel%02d" % index, Vector3(point.x, 1.15, point.y), str(stage.get("label", "")), Color("#ffd0c8"), 30)
		if index + 1 < stages.size():
			var next_point := _v2((stages[index + 1] as Dictionary).get("point", [0.0, 0.0]))
			_add_segment($Runtime/Routes, "EnemyRoute%02d" % index, point, next_point, 0.8, 0.12, COLOR_ENEMY)

	var rally_rows: Array = route.get("rally_rows", [])
	var rally_spacing := float(route.get("rally_spacing_x", 2.1))
	for row_index in rally_rows.size():
		var row: Array = rally_rows[row_index]
		if row.size() < 3:
			continue
		var row_center_x := float(row[0])
		var row_z := float(row[1])
		var row_count := int(row[2])
		for column in row_count:
			var x := row_center_x + (float(column) - float(row_count - 1) * 0.5) * rally_spacing
			_add_cylinder($Runtime/Routes, "Rally_%d_%d" % [row_index, column], Vector3(x, 0.28, row_z), 0.35, 0.2, COLOR_RALLY)


func _build_rear_route() -> void:
	var route: Dictionary = _plan.get("rear_route", {})
	var gate := _v2(route.get("back_gate", [0.0, 0.0]))
	var merchant_approach := _v2(route.get("merchant_approach", route.get("merchant_stop", [0.0, 0.0])))
	var merchant_stop := _v2(route.get("merchant_stop", [0.0, 0.0]))
	var escape_completion := _v2(route.get("escape_completion", [0.0, 0.0]))
	_add_segment($Runtime/Routes, "RearRouteToMerchant", gate, merchant_stop, 0.8, 0.14, COLOR_MERCHANT)
	_add_segment($Runtime/Routes, "MerchantStopToApproach", merchant_stop, merchant_approach, 0.8, 0.14, COLOR_MERCHANT)
	_add_segment($Runtime/Routes, "RearRouteToEscapeEdge", merchant_approach, escape_completion, 0.8, 0.14, COLOR_MERCHANT)
	_add_cylinder($Runtime/Routes, "MerchantStop", Vector3(merchant_stop.x, 0.35, merchant_stop.y), 0.8, 0.35, COLOR_MERCHANT)
	_add_label("MerchantStopLabel", Vector3(merchant_stop.x, 1.25, merchant_stop.y), "商人后门外停靠点", Color("#ffe2a6"), 31)
	_add_cylinder($Runtime/Routes, "EscapeCompletion", Vector3(escape_completion.x, 0.35, escape_completion.y), 0.9, 0.4, COLOR_ENEMY)
	_add_label("EscapeCompletionLabel", Vector3(escape_completion.x, 1.35, escape_completion.y), "到达地图边缘才判定逃离完成", Color("#ffd0c8"), 34)


func _build_natural_boundary() -> void:
	var environment: Dictionary = _plan.get("environment", {})
	var river_points: Array = environment.get("river_points", [])
	var river_width := float(environment.get("river_width", 8.0))
	var channel_width := float(environment.get("river_channel_width", river_width + 6.0))
	var river_surface := float(environment.get("river_surface_elevation_m", -1.2))
	for index in maxi(river_points.size() - 1, 0):
		var from_point := _v2(river_points[index])
		var to_point := _v2(river_points[index + 1])
		var delta := to_point - from_point
		var bank_normal := Vector2(-delta.y, delta.x).normalized()
		var bank_offset := bank_normal * (channel_width * 0.5 - 0.55)
		var bank_height := maxf(absf(river_surface), 0.8)
		_add_segment(nature_root, "RiverBed%02d" % index, from_point, to_point, channel_width, 0.16, Color("#394a48"), river_surface - 0.16)
		_add_segment(nature_root, "River%02d" % index, from_point, to_point, river_width, 0.12, COLOR_WATER, river_surface)
		_add_segment(nature_root, "RiverBankLeft%02d" % index, from_point + bank_offset, to_point + bank_offset, 1.1, bank_height, COLOR_RIDGE, river_surface * 0.5)
		_add_segment(nature_root, "RiverBankRight%02d" % index, from_point - bank_offset, to_point - bank_offset, 1.1, bank_height, COLOR_RIDGE, river_surface * 0.5)
		_add_rock_cluster(from_point + Vector2(5.5, 0.0), index)

	var ridge_bounds: Array = environment.get("east_ridge_bounds", [])
	if ridge_bounds.size() >= 4:
		var ridge_center := Vector2((float(ridge_bounds[0]) + float(ridge_bounds[1])) * 0.5, (float(ridge_bounds[2]) + float(ridge_bounds[3])) * 0.5)
		var ridge_size := Vector2(float(ridge_bounds[1]) - float(ridge_bounds[0]), float(ridge_bounds[3]) - float(ridge_bounds[2]))
		_add_flat_box(nature_root, "EastRidgeBase", ridge_center, ridge_size, -0.05, 0.55, Color("#62645d"))
		var ridge_row := 0
		var z := float(ridge_bounds[2])
		while z <= float(ridge_bounds[3]):
			var rock_x := float(ridge_bounds[0]) + ridge_size.x * (0.22 + 0.5 * _stable_noise(ridge_row, 19, 61))
			_add_rock(Vector2(rock_x, z), 3.2 + 1.8 * _stable_noise(ridge_row, 31, 79), 2.0 + 1.4 * _stable_noise(ridge_row, 47, 89))
			ridge_row += 1
			z += 18.0

	_build_extended_forest(environment)
	_build_boundary_fog(environment)
	_add_label("RiverLabel", Vector3(-81.0, 2.0, 12.0), "西侧低位河槽（河面 -1.2m / 驿站地坪 0m）", Color("#b8e6ff"), 34)
	_add_label("RidgeLabel", Vector3(126.0, 4.0, 12.0), "东侧岩脊 / 密林延伸至镜头外", Color.WHITE, 34)


func _build_extended_forest(environment: Dictionary) -> void:
	var scatter_bounds := _rect_from_bounds(environment.get("forest_scatter_bounds", []))
	if scatter_bounds.size == Vector2.ZERO:
		return
	var spacing := maxf(float(environment.get("forest_grid_spacing_m", 9.5)), 5.0)
	var points: Array[Vector2] = []
	var row := 0
	var z := scatter_bounds.position.y
	while z <= scatter_bounds.end.y:
		var column := 0
		var x := scatter_bounds.position.x
		while x <= scatter_bounds.end.x:
			var jitter_x := (_stable_noise(column, row, 17) - 0.5) * spacing * 0.8
			var jitter_z := (_stable_noise(column, row, 43) - 0.5) * spacing * 0.8
			var point := Vector2(x + jitter_x, z + jitter_z)
			if _stable_noise(column, row, 113) > 0.13 and _is_valid_forest_point(point, environment):
				points.append(point)
			column += 1
			x += spacing
		row += 1
		z += spacing
	_forest_instance_count = points.size()
	_add_tree_multimeshes(points)

	var rock_index := 0
	var rock_stride := maxi(int(environment.get("rock_cluster_stride", 43)), 17)
	for point_index in range(0, points.size(), rock_stride):
		_add_rock_cluster(points[point_index] + Vector2(2.4, -1.7), rock_index)
		rock_index += 1


func _is_valid_forest_point(point: Vector2, environment: Dictionary) -> bool:
	var station: Dictionary = _plan.get("station", {})
	var interior_polygon := _polygon_from_raw(station.get("interior_polygon", []))
	if Geometry2D.is_point_in_polygon(point, interior_polygon):
		return false
	var wall_clearance := float(environment.get("tree_clearance_from_wall_m", 3.0))
	for raw_segment in station.get("wall_segments", []):
		var segment: Dictionary = raw_segment
		if _distance_to_segment(point, _v2(segment.get("from", [])), _v2(segment.get("to", []))) < wall_clearance:
			return false
	var road_clearance := float(environment.get("tree_clearance_from_road_m", 3.0))
	for raw_road in _plan.get("roads", []):
		var road: Dictionary = raw_road
		if not road.has("from") or not road.has("to"):
			continue
		if str(road.get("kind", "")) not in ["enemy", "trade"]:
			continue
		var clear_distance := float(road.get("width", 3.0)) * 0.5 + road_clearance
		if _distance_to_segment(point, _v2(road.get("from", [])), _v2(road.get("to", []))) < clear_distance:
			return false
	var river_width := float(environment.get("river_width", 9.0))
	var river_points: Array = environment.get("river_points", [])
	for index in maxi(river_points.size() - 1, 0):
		if _distance_to_segment(point, _v2(river_points[index]), _v2(river_points[index + 1])) < river_width * 0.5 + 1.5:
			return false
	return true


func _add_tree_multimeshes(points: Array[Vector2]) -> void:
	if points.is_empty():
		return
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.35
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 2.6
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.1
	canopy_mesh.bottom_radius = 2.0
	canopy_mesh.height = 4.2
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 2
	var trunk_multimesh := MultiMesh.new()
	trunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multimesh.mesh = trunk_mesh
	trunk_multimesh.instance_count = points.size()
	var canopy_multimesh := MultiMesh.new()
	canopy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multimesh.mesh = canopy_mesh
	canopy_multimesh.instance_count = points.size()
	for index in points.size():
		var point := points[index]
		var scale := 0.82 + _stable_noise(index, 7, 71) * 0.42
		var angle := _stable_noise(index, 11, 97) * TAU
		var basis := Basis(Vector3.UP, angle).scaled(Vector3(scale, scale, scale))
		trunk_multimesh.set_instance_transform(index, Transform3D(basis, Vector3(point.x, 1.3 * scale, point.y)))
		canopy_multimesh.set_instance_transform(index, Transform3D(basis, Vector3(point.x, 4.0 * scale, point.y)))
	var trunks := MultiMeshInstance3D.new()
	trunks.name = "ExtendedForestTrunks"
	trunks.multimesh = trunk_multimesh
	trunks.material_override = _material(COLOR_TREE_TRUNK)
	nature_root.add_child(trunks)
	var canopies := MultiMeshInstance3D.new()
	canopies.name = "ExtendedForestCanopies"
	canopies.multimesh = canopy_multimesh
	canopies.material_override = _material(COLOR_TREE_CANOPY)
	nature_root.add_child(canopies)


func _build_boundary_fog(environment: Dictionary) -> void:
	var rear := _rect_from_bounds(environment.get("rear_boundary_bounds", []))
	var front := _rect_from_bounds(environment.get("front_forest_bounds", []))
	_add_flat_box(nature_root, "RearFog", rear.position + rear.size * 0.5, rear.size, 0.45, 0.08, COLOR_FOG)
	_add_flat_box(nature_root, "FrontFog", front.position + front.size * 0.5, front.size, 0.45, 0.08, COLOR_FOG)


func _add_tree(point: Vector2, index: int) -> void:
	var group := Node3D.new()
	group.name = "Tree%03d" % index
	group.position = Vector3(point.x, 0.0, point.y)
	nature_root.add_child(group)
	_add_cylinder(group, "Trunk", Vector3(0.0, 1.3, 0.0), 0.35, 2.6, COLOR_TREE_TRUNK)
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.1
	canopy_mesh.bottom_radius = 2.0
	canopy_mesh.height = 4.2
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 2
	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	canopy.position = Vector3(0.0, 4.0, 0.0)
	canopy.mesh = canopy_mesh
	canopy.material_override = _material(COLOR_TREE_CANOPY)
	group.add_child(canopy)


func _add_rock_cluster(point: Vector2, index: int) -> void:
	_add_rock(point + Vector2(float(index % 2), 0.0), 2.8, 1.8)
	_add_rock(point + Vector2(2.1, 1.7), 1.9, 1.2)


func _add_rock(point: Vector2, radius: float, height: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var instance := MeshInstance3D.new()
	instance.name = "Rock%03d" % nature_root.get_child_count()
	instance.position = Vector3(point.x, height * 0.5, point.y)
	instance.scale = Vector3(1.0, height / maxf(radius * 2.0, 0.01), 0.75)
	instance.mesh = mesh
	instance.material_override = _material(COLOR_RIDGE)
	nature_root.add_child(instance)


func _apply_camera_plan() -> void:
	var camera_plan: Dictionary = _plan.get("camera", {})
	var initial_distance := float(camera_plan.get("initial_distance", 64.0))
	var pitch := deg_to_rad(absf(float(camera_plan.get("pitch_degrees", -55.0))))
	camera_rig.set("min_zoom_distance", float(camera_plan.get("min_distance", 20.0)))
	camera_rig.set("max_zoom_distance", float(camera_plan.get("max_distance", 64.0)))
	camera_rig.set("x_limits", _v2(camera_plan.get("x_limits", [-58.0, 58.0])))
	camera_rig.set("z_limits", _v2(camera_plan.get("z_limits", [-55.0, 82.0])))
	camera.position = Vector3(0.0, sin(pitch) * initial_distance, cos(pitch) * initial_distance)
	camera.rotation_degrees = Vector3(-absf(float(camera_plan.get("pitch_degrees", -55.0))), 0.0, 0.0)
	_focus_camera(_v2(camera_plan.get("initial_focus", [0.0, 9.0])))


func _focus_camera(target: Vector2) -> void:
	camera_rig.global_position = Vector3(target.x, 0.0, target.y)


func _update_status_label() -> void:
	if _plan.is_empty():
		return
	var snapshot := get_validation_snapshot()
	status_label.text = (
		"不规则围墙包络 %.0f × %.0f m = %.0f㎡（旧 %.0f㎡，%.1fx）  |  八方向建筑 %d/%d · 道路冲突 %d · 林木 %d\n"
		+ "镜头 %.1f m @ (%.1f, %.1f)  |  最高容量 %d位 / 误差%d  |  48敌：%s %.0f%%  |  逃离：%s %.0f%%\n"
		+ "M/0 敌军行军/重置  |  X/9 逃离/重置  |  P最高容量 %s"
	) % [
		float(snapshot.interior_size.x),
		float(snapshot.interior_size.y),
		float(snapshot.target_interior_area_m2),
		float(snapshot.current_area_m2),
		float(snapshot.area_multiplier),
		int(snapshot.eight_direction_lot_count),
		int(snapshot.lot_count),
		int(snapshot.road_lot_overlap_count),
		int(snapshot.forest_instance_count),
		camera.position.length(),
		camera_rig.global_position.x,
		camera_rig.global_position.z,
		int(snapshot.max_level_position_rect_count),
		int(snapshot.capacity_layout_error_count),
		"完成" if bool(snapshot.enemy_stress.get("completed", false)) else ("行军" if bool(snapshot.enemy_stress.get("running", false)) else "待命"),
		100.0 * float(snapshot.enemy_stress.get("elapsed_seconds", 0.0)) / maxf(float(snapshot.enemy_stress.get("total_route_duration_seconds", 1.0)), 0.001),
		"完成" if bool(snapshot.escape_stress.get("completed", false)) else ("逃离中" if bool(snapshot.escape_stress.get("running", false)) else "待命"),
		100.0 * float(snapshot.escape_stress.get("progress", 0.0)),
		"开" if _max_level_layouts_visible else "关"
	]


func _validate_lots() -> Dictionary:
	var station: Dictionary = _plan.get("station", {})
	var interior_polygon := _polygon_from_raw(station.get("interior_polygon", []))
	var lots: Array = _plan.get("building_lots", [])
	var overlaps: Array[String] = []
	var outside: Array[String] = []
	for index in lots.size():
		var lot: Dictionary = lots[index]
		var lot_polygon := _lot_polygon(lot)
		for corner in lot_polygon:
			if not Geometry2D.is_point_in_polygon(corner, interior_polygon):
				outside.append(str(lot.get("id", "unknown")))
				break
		for other_index in range(index + 1, lots.size()):
			var other: Dictionary = lots[other_index]
			if _polygons_overlap_sat(lot_polygon, _lot_polygon(other)):
				overlaps.append("%s/%s" % [lot.get("id", "unknown"), other.get("id", "unknown")])
	return {"overlaps": overlaps, "outside": outside}


func _validate_road_lot_clearance() -> Array[String]:
	var conflicts: Array[String] = []
	for raw_road in _plan.get("roads", []):
		var road: Dictionary = raw_road
		var road_polygon := _road_polygon(road)
		for raw_lot in _plan.get("building_lots", []):
			var lot: Dictionary = raw_lot
			var served_lots: Array = road.get("serves", [])
			if str(lot.get("id", "")) in served_lots:
				continue
			if _polygons_overlap_sat(road_polygon, _lot_polygon(lot)):
				conflicts.append("%s/%s" % [road.get("id", "road"), lot.get("id", "lot")])
	return conflicts


func _validate_enemy_route_lot_clearance() -> Array[String]:
	var errors: Array[String] = []
	var stress: Dictionary = _plan.get("enemy_stress_test", {})
	var stages: Array = stress.get("stage_formations", [])
	for stage_index in maxi(stages.size() - 1, 0):
		var from_stage: Dictionary = stages[stage_index]
		var to_stage: Dictionary = stages[stage_index + 1]
		var from_point := _v2(from_stage.get("point", [0.0, 0.0]))
		var to_point := _v2(to_stage.get("point", [0.0, 0.0]))
		var corridor_width := maxf(
			float(from_stage.get("corridor_width", 0.0)),
			float(to_stage.get("corridor_width", 0.0))
		)
		var corridor := _oriented_rect_polygon(
			(from_point + to_point) * 0.5,
			Vector2(corridor_width, from_point.distance_to(to_point)),
			atan2((to_point - from_point).x, (to_point - from_point).y)
		)
		var allowed_lots := [str(from_stage.get("stage_id", "")), str(to_stage.get("stage_id", ""))]
		for raw_lot in _plan.get("building_lots", []):
			var lot: Dictionary = raw_lot
			var lot_id := str(lot.get("id", ""))
			if lot_id in allowed_lots:
				continue
			if _polygons_overlap_sat(corridor, _lot_polygon(lot)):
				errors.append("%s_to_%s/%s" % [from_stage.get("stage_id", "stage"), to_stage.get("stage_id", "stage"), lot_id])
	return errors


func _enemy_spawn_outside_initial_view(footprint: Rect2, camera_plan: Dictionary, enemy_route: Dictionary) -> bool:
	var focus := _v2(camera_plan.get("initial_focus", [0.0, 0.0]))
	var view_rect := Rect2(focus + footprint.position, footprint.size)
	var spawn_center := _v2(enemy_route.get("spawn_zone_center", [0.0, 0.0]))
	var spawn_size := _v2(enemy_route.get("spawn_zone_size", [0.0, 0.0]))
	var spawn_rect := Rect2(spawn_center - spawn_size * 0.5, spawn_size)
	return not view_rect.intersects(spawn_rect, true)


func _lot_rect(lot: Dictionary) -> Rect2:
	var center := _v2(lot.get("center", [0.0, 0.0]))
	var size := _v2(lot.get("lot_size", [0.0, 0.0]))
	return Rect2(center - size * 0.5, size)


func _lot_polygon(lot: Dictionary) -> PackedVector2Array:
	return _oriented_rect_polygon(
		_v2(lot.get("center", [0.0, 0.0])),
		_v2(lot.get("lot_size", [0.0, 0.0])),
		deg_to_rad(float(lot.get("rotation_degrees", 0.0)))
	)


func _road_polygon(road: Dictionary) -> PackedVector2Array:
	if road.has("from") and road.has("to"):
		var from_point := _v2(road.get("from", [0.0, 0.0]))
		var to_point := _v2(road.get("to", [0.0, 0.0]))
		var delta := to_point - from_point
		return _oriented_rect_polygon(
			(from_point + to_point) * 0.5,
			Vector2(float(road.get("width", 3.0)), delta.length()),
			atan2(delta.x, delta.y)
		)
	return _oriented_rect_polygon(
		_v2(road.get("center", [0.0, 0.0])),
		_v2(road.get("size", [0.0, 0.0])),
		deg_to_rad(float(road.get("rotation_degrees", 0.0)))
	)


func _oriented_rect_polygon(center: Vector2, size: Vector2, yaw: float) -> PackedVector2Array:
	var half := size * 0.5
	var polygon := PackedVector2Array()
	for local_point in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		polygon.append(center + _rotate_plan_vector(local_point, yaw))
	return polygon


func _polygons_overlap_sat(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() < 3 or second.size() < 3:
		return false
	for polygon in [first, second]:
		for index in polygon.size():
			var edge: Vector2 = polygon[(index + 1) % polygon.size()] - polygon[index]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var first_range := _project_polygon(first, axis)
			var second_range := _project_polygon(second, axis)
			if first_range.y <= second_range.x + 0.01 or second_range.y <= first_range.x + 0.01:
				return false
	return true


func _project_polygon(polygon: PackedVector2Array, axis: Vector2) -> Vector2:
	var minimum := polygon[0].dot(axis)
	var maximum := minimum
	for index in range(1, polygon.size()):
		var projection := polygon[index].dot(axis)
		minimum = minf(minimum, projection)
		maximum = maxf(maximum, projection)
	return Vector2(minimum, maximum)


func _rotate_plan_vector(local_point: Vector2, yaw: float) -> Vector2:
	var cosine := cos(yaw)
	var sine := sin(yaw)
	return Vector2(local_point.x * cosine + local_point.y * sine, -local_point.x * sine + local_point.y * cosine)


func _polygon_from_raw(raw_points: Variant) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if not raw_points is Array:
		return polygon
	for raw_point in raw_points:
		polygon.append(_v2(raw_point))
	return polygon


func _wall_segment_bounds(raw_segments: Variant) -> Rect2:
	if not raw_segments is Array or raw_segments.is_empty():
		return Rect2()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for raw_segment in raw_segments:
		var segment: Dictionary = raw_segment
		for point in [_v2(segment.get("from", [])), _v2(segment.get("to", []))]:
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _count_rotated_lots() -> int:
	var count := 0
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		if absf(float(lot.get("rotation_degrees", 0.0))) >= 1.0:
			count += 1
	return count


func _validate_eight_direction_lots() -> Array[String]:
	var errors: Array[String] = []
	var direction_names := ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		var angle := fposmod(float(lot.get("rotation_degrees", 0.0)), 360.0)
		var direction_index := posmod(roundi(angle / 45.0), 8)
		var snapped_angle := float(direction_index) * 45.0
		var angle_error := minf(absf(angle - snapped_angle), absf(angle - snapped_angle - 360.0))
		var lot_id := str(lot.get("id", "unknown"))
		if angle_error > 0.01:
			errors.append("%s_angle" % lot_id)
			continue
		if str(lot.get("orientation_direction", "")) != str(direction_names[direction_index]):
			errors.append("%s_direction" % lot_id)
		if str(lot.get("entry_facing", "")) != "+Z":
			errors.append("%s_front" % lot_id)
	return errors


func _validate_lot_entrance_access() -> Array[String]:
	var errors: Array[String] = []
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		var lot_id := str(lot.get("id", "unknown"))
		var envelope_size := _v2(lot.get("envelope_size", [0.0, 0.0]))
		var local_entry := Vector2(0.0, envelope_size.y * 0.5 + 0.8)
		var entry_point := _v2(lot.get("center", [0.0, 0.0])) + _rotate_plan_vector(local_entry, deg_to_rad(float(lot.get("rotation_degrees", 0.0))))
		var best_distance := INF
		for raw_road in _plan.get("roads", []):
			var road: Dictionary = raw_road
			if lot_id not in (road.get("serves", []) as Array):
				continue
			best_distance = minf(best_distance, entry_point.distance_to(_v2(road.get("from", [0.0, 0.0]))))
			best_distance = minf(best_distance, entry_point.distance_to(_v2(road.get("to", [0.0, 0.0]))))
		if best_distance > 2.5:
			errors.append("%s:%.2f" % [lot_id, best_distance])
	return errors


func _validate_main_reference_layout() -> Array[String]:
	var errors: Array[String] = []
	var centers: Dictionary = {}
	var main_hall_area := 0.0
	var main_hall_height := 0.0
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		var lot_id := str(lot.get("id", ""))
		var center := _v2(lot.get("center", [0.0, 0.0]))
		centers[lot_id] = center
		if lot_id == "main_hall":
			var main_size := _v2(lot.get("lot_size", [0.0, 0.0]))
			main_hall_area = main_size.x * main_size.y
			main_hall_height = float(lot.get("graybox_height", 0.0))
	if main_hall_area <= 0.0 or main_hall_height <= 0.0:
		errors.append("main_hall_missing")
		return errors
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		if str(lot.get("id", "")) == "main_hall":
			continue
		var lot_size := _v2(lot.get("lot_size", [0.0, 0.0]))
		if lot_size.x * lot_size.y >= main_hall_area:
			errors.append("main_hall_not_largest_lot")
		if float(lot.get("graybox_height", 1.2)) >= main_hall_height:
			errors.append("main_hall_not_tallest_graybox")

	# Main.tscn 构图母版：主厅居中偏后；后排生产/公共建筑展开，
	# 宿舍与食堂分居两翼；生活生产地块在前场左右分布。
	var hall: Vector2 = centers.get("main_hall", Vector2(INF, INF))
	var plaza := _v2(((_plan.get("station", {}) as Dictionary).get("plaza", {}) as Dictionary).get("center", [0.0, 0.0]))
	if absf(hall.x) > 3.0 or hall.y >= plaza.y or hall.distance_to(plaza) > 20.0:
		errors.append("main_hall_not_central_rear_anchor")
	for rear_id in ["workshop", "chapel", "clinic", "stable"]:
		var rear_center: Vector2 = centers.get(rear_id, Vector2(INF, INF))
		if rear_center.y >= hall.y:
			errors.append("%s_not_rear_of_main_hall" % rear_id)
	var dormitory: Vector2 = centers.get("dormitory", Vector2(INF, INF))
	var dining_hall: Vector2 = centers.get("dining_hall", Vector2(INF, INF))
	if dormitory.x >= hall.x or dining_hall.x <= hall.x:
		errors.append("mid_flanks_reversed")
	var garden: Vector2 = centers.get("garden", Vector2(INF, INF))
	var tavern: Vector2 = centers.get("tavern", Vector2(INF, INF))
	if garden.x >= hall.x or tavern.x >= hall.x or garden.y <= hall.y or tavern.y <= garden.y:
		errors.append("left_front_cluster_mismatch")
	var training: Vector2 = centers.get("training_ground", Vector2(INF, INF))
	var blacksmith: Vector2 = centers.get("blacksmith", Vector2(INF, INF))
	var warehouse: Vector2 = centers.get("warehouse", Vector2(INF, INF))
	if training.x >= hall.x or training.y <= plaza.y:
		errors.append("training_ground_not_front_left")
	if blacksmith.x <= hall.x or blacksmith.y <= plaza.y:
		errors.append("blacksmith_not_front_right")
	if warehouse.x <= hall.x or warehouse.y <= plaza.y:
		errors.append("warehouse_not_right_front")
	return errors


func _validate_capacity_layouts() -> Dictionary:
	var errors: Array[String] = []
	var layouts: Dictionary = _plan.get("max_level_layouts", {})
	var lot_by_id: Dictionary = {}
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		lot_by_id[str(lot.get("id", ""))] = lot
	if layouts.size() != lot_by_id.size():
		errors.append("layout_count_%d_expected_%d" % [layouts.size(), lot_by_id.size()])
	var position_count := 0
	var authoritative_position_count := 0
	var stable_horse_anchor_count := 0
	var minimum_primary_aisle_width := INF
	for raw_lot_id in lot_by_id.keys():
		var lot_id := str(raw_lot_id)
		var lot: Dictionary = lot_by_id.get(lot_id, {})
		var layout: Dictionary = layouts.get(lot_id, {})
		if layout.is_empty():
			errors.append("%s_layout_missing" % lot_id)
			continue
		var bounds_size := _v2(layout.get("bounds_size", [0.0, 0.0]))
		var envelope_size := _v2(lot.get("envelope_size", [0.0, 0.0]))
		if not bounds_size.is_equal_approx(envelope_size):
			errors.append("%s_bounds_mismatch" % lot_id)
		var edge_clearance := maxf(float(layout.get("edge_clearance_m", 0.0)), 0.0)
		var usable_half := bounds_size * 0.5 - Vector2.ONE * edge_clearance
		var lanes: Array = layout.get("circulation", [])
		var positions: Array = layout.get("positions", [])
		position_count += positions.size()
		var primary_reaches_entry := false
		for raw_lane in lanes:
			var lane: Dictionary = raw_lane
			if not _capacity_item_inside(lane, usable_half):
				errors.append("%s/%s_outside" % [lot_id, lane.get("id", "lane")])
			if str(lane.get("kind", "")) == "primary":
				var lane_size := _v2(lane.get("size", [0.0, 0.0]))
				minimum_primary_aisle_width = minf(minimum_primary_aisle_width, minf(lane_size.x, lane_size.y))
				var lane_center := _v2(lane.get("center", [0.0, 0.0]))
				if lane_center.y + lane_size.y * 0.5 >= usable_half.y - 0.35 and absf(lane_center.x) <= lane_size.x * 0.5:
					primary_reaches_entry = true
		if not primary_reaches_entry:
			errors.append("%s_primary_aisle_not_at_entry" % lot_id)
		for raw_position in positions:
			var position: Dictionary = raw_position
			if not _capacity_item_inside(position, usable_half):
				errors.append("%s/%s_outside" % [lot_id, position.get("id", "position")])
			var authority := str(position.get("authority", ""))
			if authority == "building_workstation" or authority == "defense_device_slot":
				authoritative_position_count += 1
			if lot_id == "stable" and bool(position.get("horse_anchor_capable", false)):
				stable_horse_anchor_count += 1
		for position_index in positions.size():
			var position: Dictionary = positions[position_index]
			var position_layer := str(position.get("layer", "ground"))
			var position_polygon := _capacity_item_polygon(position)
			for other_index in range(position_index + 1, positions.size()):
				var other: Dictionary = positions[other_index]
				if str(other.get("layer", "ground")) == position_layer and _polygons_overlap_sat(position_polygon, _capacity_item_polygon(other)):
					errors.append("%s/%s_overlaps_%s" % [lot_id, position.get("id", "position"), other.get("id", "position")])
			for raw_lane in lanes:
				var lane: Dictionary = raw_lane
				if str(lane.get("layer", "ground")) == position_layer and _polygons_overlap_sat(position_polygon, _capacity_item_polygon(lane)):
					errors.append("%s/%s_blocks_%s" % [lot_id, position.get("id", "position"), lane.get("id", "lane")])
	if minimum_primary_aisle_width == INF:
		minimum_primary_aisle_width = 0.0
	return {
		"errors": errors,
		"layout_count": layouts.size(),
		"position_count": position_count,
		"authoritative_position_count": authoritative_position_count,
		"stable_horse_anchor_count": stable_horse_anchor_count,
		"minimum_primary_aisle_width_m": minimum_primary_aisle_width
	}


func _capacity_item_inside(item: Dictionary, usable_half: Vector2) -> bool:
	for corner in _capacity_item_polygon(item):
		if absf(corner.x) > usable_half.x + 0.01 or absf(corner.y) > usable_half.y + 0.01:
			return false
	return true


func _capacity_item_polygon(item: Dictionary) -> PackedVector2Array:
	return _oriented_rect_polygon(
		_v2(item.get("center", [0.0, 0.0])),
		_v2(item.get("size", [0.0, 0.0])),
		deg_to_rad(float(item.get("rotation_degrees", 0.0)))
	)


func _plaza_patch_area(plaza: Dictionary) -> float:
	var area := 0.0
	for raw_patch in plaza.get("patches", []):
		var patch: Dictionary = raw_patch
		var size := _v2(patch.get("size", [0.0, 0.0]))
		area += size.x * size.y
	return area


func _distance_to_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment := to_point - from_point
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(from_point)
	var amount := clampf((point - from_point).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(from_point + segment * amount)


func _point_edge_inset(point: Vector2, bounds: Rect2) -> float:
	return minf(
		minf(point.x - bounds.position.x, bounds.end.x - point.x),
		minf(point.y - bounds.position.y, bounds.end.y - point.y)
	)


func _camera_to_terrain_min_margin(terrain_rect: Rect2, camera_plan: Dictionary) -> float:
	var x_limits := _v2(camera_plan.get("x_limits", [0.0, 0.0]))
	var z_limits := _v2(camera_plan.get("z_limits", [0.0, 0.0]))
	return minf(
		minf(x_limits.x - terrain_rect.position.x, terrain_rect.end.x - x_limits.y),
		minf(z_limits.x - terrain_rect.position.y, terrain_rect.end.y - z_limits.y)
	)


func _camera_ground_footprint(camera_plan: Dictionary) -> Rect2:
	var distance := float(camera_plan.get("max_distance", 70.0))
	var pitch := deg_to_rad(absf(float(camera_plan.get("pitch_degrees", -55.0))))
	var vertical_fov := deg_to_rad(float(camera_plan.get("vertical_fov_degrees", 62.0)))
	var aspect := float(camera_plan.get("stress_aspect_ratio", 21.0 / 9.0))
	var half_y := tan(vertical_fov * 0.5)
	var half_x := half_y * aspect
	var camera_height := sin(pitch) * distance
	var camera_z := cos(pitch) * distance
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for raw_local_x in [-half_x, half_x]:
		for raw_local_y in [-half_y, half_y]:
			var local_x := float(raw_local_x)
			var local_y := float(raw_local_y)
			var world_y: float = local_y * cos(pitch) - sin(pitch)
			var world_z: float = -local_y * sin(pitch) - cos(pitch)
			if world_y >= -0.001:
				continue
			var distance_to_ground: float = -camera_height / world_y
			var point := Vector2(local_x * distance_to_ground, camera_z + world_z * distance_to_ground)
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
	if minimum.x == INF:
		return Rect2()
	return Rect2(minimum, maximum - minimum)


func _camera_footprint_to_terrain_min_margin(terrain_rect: Rect2, camera_plan: Dictionary, footprint: Rect2) -> float:
	var x_limits := _v2(camera_plan.get("x_limits", [0.0, 0.0]))
	var z_limits := _v2(camera_plan.get("z_limits", [0.0, 0.0]))
	return minf(
		minf(
			x_limits.x + footprint.position.x - terrain_rect.position.x,
			terrain_rect.end.x - (x_limits.y + footprint.end.x)
		),
		minf(
			z_limits.x + footprint.position.y - terrain_rect.position.y,
			terrain_rect.end.y - (z_limits.y + footprint.end.y)
		)
	)


func _stable_noise(first: int, second: int, salt: int) -> float:
	var value := sin(float(first * 127 + second * 311 + salt * 74)) * 43758.5453
	return value - floor(value)


func _rect_from_bounds(raw_bounds: Variant) -> Rect2:
	var bounds: Array = raw_bounds if raw_bounds is Array else []
	if bounds.size() < 4:
		return Rect2()
	return Rect2(
		Vector2(float(bounds[0]), float(bounds[2])),
		Vector2(float(bounds[1]) - float(bounds[0]), float(bounds[3]) - float(bounds[2]))
	)


func _rect_contains_rect(container: Rect2, child: Rect2) -> bool:
	return (
		child.position.x >= container.position.x
		and child.position.y >= container.position.y
		and child.end.x <= container.end.x
		and child.end.y <= container.end.y
	)


func _get_lot_value(lot_id: String, key: String) -> Variant:
	for raw_lot in _plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		if str(lot.get("id", "")) == lot_id:
			return lot.get(key)
	return null


func _get_lot_vector(lot_id: String, key: String) -> Vector2:
	return _v2(_get_lot_value(lot_id, key))


func _get_enemy_stage_point(stage_id: String) -> Vector2:
	var enemy_route: Dictionary = _plan.get("enemy_route", {})
	for raw_stage in enemy_route.get("stages", []):
		var stage: Dictionary = raw_stage
		if str(stage.get("id", "")) == stage_id:
			return _v2(stage.get("point", [0.0, 0.0]))
	return _v2(enemy_route.get("spawn_zone_center", [0.0, 0.0]))


func _add_flat_box(parent: Node3D, node_name: String, center: Vector2, size: Vector2, y: float, height: float, color: Color) -> MeshInstance3D:
	return _add_box(parent, node_name, Vector3(center.x, y, center.y), Vector3(size.x, height, size.y), color)


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = _sanitize_name(node_name)
	instance.position = center
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if color.a >= 0.99 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = _sanitize_name(node_name)
	instance.position = center
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_segment(parent: Node3D, node_name: String, from_point: Vector2, to_point: Vector2, width: float, height: float, color: Color, y: float = 0.13) -> MeshInstance3D:
	var delta := to_point - from_point
	var middle := (from_point + to_point) * 0.5
	var instance := _add_box(parent, node_name, Vector3(middle.x, y, middle.y), Vector3(width, height, delta.length()), color)
	instance.rotation.y = atan2(delta.x, delta.y)
	return instance


func _add_rect_outline(parent: Node3D, prefix: String, center: Vector2, size: Vector2, thickness: float, color: Color) -> void:
	_add_box(parent, prefix + "North", Vector3(center.x, 0.22, center.y + size.y * 0.5), Vector3(size.x, 0.2, thickness), color)
	_add_box(parent, prefix + "South", Vector3(center.x, 0.22, center.y - size.y * 0.5), Vector3(size.x, 0.2, thickness), color)
	_add_box(parent, prefix + "West", Vector3(center.x - size.x * 0.5, 0.22, center.y), Vector3(thickness, 0.2, size.y), color)
	_add_box(parent, prefix + "East", Vector3(center.x + size.x * 0.5, 0.22, center.y), Vector3(thickness, 0.2, size.y), color)


func _add_label(node_name: String, world_position: Vector3, label_text: String, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = _sanitize_name(node_name)
	label.position = world_position
	label.text = label_text
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	labels_root.add_child(label)
	return label


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = material
	return material


func _lot_envelope_color(lot_id: String) -> Color:
	if lot_id in ["blacksmith", "workshop", "warehouse"]:
		return Color("#536b78")
	if lot_id in ["garden", "stable", "training_ground"]:
		return Color("#65774f")
	if lot_id == "main_hall":
		return Color("#8b7152")
	return COLOR_ENVELOPE


func _format_size(size: Vector2) -> String:
	return "%.0f × %.0f" % [size.x, size.y]


func _v2(raw_value: Variant) -> Vector2:
	if raw_value is Vector2:
		return raw_value
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	return Vector2.ZERO


func _sanitize_name(raw_name: String) -> String:
	return raw_name.replace(" ", "_").replace("/", "_").replace("-", "_")


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
