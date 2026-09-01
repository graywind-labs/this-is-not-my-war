extends Node


const LAYOUT_PATH := "res://data/station_layout.json"
const PHYSICS_NAVIGATION_PATH := "res://data/physics_navigation.json"
const FIXTURE_LAYOUTS_PATH := "res://data/building_fixture_layouts.json"
const ENVIRONMENT_ART_PATH := "res://data/presentation/environment_art.json"
const EXPECTED_SCHEMA := "station_layout_v2"
const EXPECTED_PHYSICS_NAVIGATION_SCHEMA := "physics_navigation_v1"
const EXPECTED_FIXTURE_LAYOUTS_SCHEMA := "building_fixture_layout_v1"
const EXPECTED_ENVIRONMENT_ART_SCHEMA := "environment_art_v1"
const FORMAL_ROOT_NAME := "FormalStationLayout"
const BUILDING_NAME_FONT_SIZE := 38
const BUILDING_NAME_IDLE_DELAY_SECONDS := 0.55
const BUILDING_NAME_FADE_SPEED := 0.9
const BUILDING_NAME_REVEAL_SPEED := 7.5
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const WORLD_HEALTH_BAR := preload("res://scripts/world/WorldHealthBar3D.gd")
const STRATEGIC_WORLD_HEALTH_BUILDINGS := ["warehouse", "front_gate", "main_hall"]
const CAMERA_MOTION_EPSILON_SQUARED := 0.000001
const LEGACY_VISUAL_PATHS := [
	NodePath("Station/Ground"),
	NodePath("Station/Buildings"),
	NodePath("Station/Props"),
]
const AUTHORITY_WORKSTATION := "building_workstation"
const AUTHORITY_DEFENSE_SLOT := "defense_device_slot"
const FORMAL_BLACKSMITH_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalBlacksmithArtView.gd")
const FORMAL_WORKSHOP_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalWorkshopArtView.gd")
const FORMAL_CHAPEL_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalChapelArtView.gd")
const FORMAL_CLINIC_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalClinicArtView.gd")
const FORMAL_DINING_HALL_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalDiningHallArtView.gd")
const FORMAL_DORMITORY_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalDormitoryArtView.gd")
const FORMAL_TAVERN_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalTavernArtView.gd")
const FORMAL_GARDEN_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalGardenArtView.gd")
const FORMAL_TRAINING_GROUND_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalTrainingGroundArtView.gd")
const FORMAL_STABLE_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalStableArtView.gd")
const FORMAL_MAIN_HALL_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalMainHallArtView.gd")
const FORMAL_WAREHOUSE_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalWarehouseArtView.gd")
const FORMAL_FORTIFICATION_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalFortificationArtView.gd")
const FORMAL_ROAD_NETWORK_ART_VIEW_SCRIPT := preload("res://scripts/presentation/environment/FormalRoadNetworkArtView.gd")
const FORMAL_DORMITORY_LATRINE_ART_VIEW_SCRIPT := preload("res://scripts/presentation/environment/FormalDormitoryLatrineArtView.gd")
const FORMAL_ENVIRONMENT_ART_VIEW_SCENE := preload("res://scenes/environment/FormalEnvironmentArtView.tscn")
const NOTICE_BOARD_SCENE := preload("res://scenes/props/NoticeBoard.tscn")
const TAVERN_MUG_ASSET := "res://assets/3d/quaternius/props/tavern_mug.glb"
const GARDEN_CARROT_ASSET := "res://assets/3d/quaternius/props/garden_carrot.glb"
const STABLE_BUCKET_ASSET := "res://assets/3d/quaternius/props/bucket_wooden.glb"
const CHAPEL_BOOK_STAND_ASSET := "res://assets/3d/quaternius/props/chapel_book_stand.glb"
const CHAPEL_CANDLESTICK_ASSET := "res://assets/3d/quaternius/props/chapel_candlestick_triple.glb"
const CHAPEL_CHALICE_ASSET := "res://assets/3d/quaternius/props/chapel_chalice.glb"
const CHAPEL_BOOK_ASSET := "res://assets/3d/quaternius/props/chapel_book.glb"
const WORKSHOP_WORKBENCH_ASSET := "res://assets/3d/quaternius/props/workshop_workbench.glb"
const WORKSHOP_SHELF_ASSET := "res://assets/3d/quaternius/props/workshop_shelf.glb"
const WORKSHOP_ROPE_ASSET := "res://assets/3d/quaternius/props/workshop_rope.glb"
const WORKSHOP_CRATE_ASSET := "res://assets/3d/quaternius/props/crate_wooden.glb"
const MAIN_HALL_WALL_WINDOW_ASSET := "res://assets/3d/quaternius/buildings/main_hall_wall_window.glb"
const MAIN_HALL_WALL_DOOR_ASSET := "res://assets/3d/quaternius/buildings/main_hall_wall_door.glb"
const MAIN_HALL_ROOF_ASSET := "res://assets/3d/quaternius/buildings/main_hall_roof.glb"
const MAIN_HALL_STAIRS_ASSET := "res://assets/3d/quaternius/buildings/main_hall_stairs.glb"
const MAIN_HALL_SUPPORT_ASSET := "res://assets/3d/quaternius/buildings/main_hall_support.glb"
const MAIN_HALL_BANNER_ASSET := "res://assets/3d/quaternius/props/main_hall_banner.glb"
const MAIN_HALL_LANTERN_ASSET := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const MAIN_HALL_SHIELD_ASSET := "res://assets/3d/quaternius/props/shield_wooden.glb"
const WAREHOUSE_WALL_ASSET := "res://assets/3d/quaternius/buildings/warehouse_wall_woodgrid.glb"
const WAREHOUSE_ROOF_ASSET := "res://assets/3d/quaternius/buildings/warehouse_roof_wooden.glb"
const WAREHOUSE_SHELF_ASSET := "res://assets/3d/quaternius/props/warehouse_shelf_arch.glb"
const WAREHOUSE_BAG_ASSET := "res://assets/3d/quaternius/props/warehouse_bag.glb"
const WAREHOUSE_METAL_CRATE_ASSET := "res://assets/3d/quaternius/props/warehouse_metal_crate.glb"
const WAREHOUSE_APPLE_BARREL_ASSET := "res://assets/3d/quaternius/props/warehouse_apple_barrel.glb"
const WAREHOUSE_CHEST_ASSET := "res://assets/3d/quaternius/props/warehouse_chest.glb"
const WAREHOUSE_WAGON_ASSET := "res://assets/3d/quaternius/buildings/warehouse_wagon.glb"

@export var world_root_path := NodePath("../../WorldRoot")
@export var camera_rig_path := NodePath("../../CameraRig")
@export var camera_path := NodePath("../../CameraRig/Camera3D")

var _layout: Dictionary = {}
var _physics_navigation: Dictionary = {}
var _fixture_layouts: Dictionary = {}
var _environment_art: Dictionary = {}
var _formal_root: Node3D
var _preview_enabled := false
var _default_formal_world_enabled := false
var _legacy_compatibility_override := false
var _camera_restore: Dictionary = {}
var _material_cache: Dictionary = {}
var _configuration_errors: Array[String] = []
var _building_roots: Dictionary = {}
var _building_name_labels: Array[Label3D] = []
var _building_health_bars: Dictionary = {}
var _building_name_label_alpha := 1.0
var _camera_idle_seconds := 0.0
var _camera_sample_valid := false
var _last_camera_rig_position := Vector3.ZERO
var _last_camera_local_position := Vector3.ZERO
var _last_camera_rotation := Vector3.ZERO
var _last_camera_fov := 0.0
var _spatial_anchor_nodes: Dictionary = {}
var _npc_initial_anchor_nodes: Dictionary = {}
var _navigation_region: NavigationRegion3D
var _navigation_grid: AStarGrid2D
var _navigation_walkable_cells: Dictionary = {}
var _navigation_walkable_ids: Array[Vector2i] = []
var _navigation_grid_region := Rect2i()
var _production_navigation_bake_msec := 0
var _production_navigation_map: RID
var _building_navigation_links: Array[NavigationLink3D] = []
var _enemy_approach_navigation_region: NavigationRegion3D
var _enemy_front_gate_navigation_link: NavigationLink3D
var _enemy_approach_vertex_count := 0
var _enemy_approach_polygon_count := 0
var _rear_escape_navigation_region: NavigationRegion3D
var _rear_escape_navigation_link: NavigationLink3D
var _rear_escape_vertex_count := 0
var _rear_escape_polygon_count := 0
var _rear_escape_route_length := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layout = _load_json_dictionary(LAYOUT_PATH)
	_physics_navigation = _load_json_dictionary(PHYSICS_NAVIGATION_PATH)
	_fixture_layouts = _load_json_dictionary(FIXTURE_LAYOUTS_PATH)
	_environment_art = _load_json_dictionary(ENVIRONMENT_ART_PATH)
	_validate_config()
	if _configuration_errors.is_empty():
		_build_formal_layout()
		_default_formal_world_enabled = bool((_layout.get("migration", {}) as Dictionary).get("formal_layout_active", false))
		if _default_formal_world_enabled:
			call_deferred("_activate_default_formal_world")
	else:
		push_error("StationLayoutController config errors: %s" % str(_configuration_errors))


func _process(delta: float) -> void:
	_update_building_name_label_visibility(delta)
	_refresh_strategic_building_health_bars()


func _exit_tree() -> void:
	if _production_navigation_map.is_valid():
		NavigationServer3D.free_rid(_production_navigation_map)
		_production_navigation_map = RID()


func debug_set_preview_enabled(enabled: bool) -> Dictionary:
	if _formal_root == null or not _configuration_errors.is_empty():
		return get_validation_snapshot()
	if enabled == _preview_enabled:
		return get_validation_snapshot()
	if enabled:
		_enter_preview()
	else:
		_exit_preview()
	return get_validation_snapshot()


func set_runtime_formal_world_enabled(enabled: bool) -> Dictionary:
	# Once A5-P7 makes the formal world the gameplay baseline, individual action,
	# combat and merchant leases may release their ownership without hiding the map.
	if not enabled and _default_formal_world_enabled and not _legacy_compatibility_override:
		return get_validation_snapshot()
	return debug_set_preview_enabled(enabled)


func is_runtime_formal_world_enabled() -> bool:
	return _preview_enabled


func debug_get_building_name_label_snapshot() -> Dictionary:
	var labels: Array[Dictionary] = []
	for label in _building_name_labels:
		if not is_instance_valid(label):
			continue
		labels.append({
			"path": str(label.get_path()),
			"text": label.text,
			"font_size": label.font_size,
			"text_alpha": label.modulate.a,
			"outline_alpha": label.outline_modulate.a,
			"is_building_name": bool(label.get_meta("formal_building_name_label", false)),
		})
	return {
		"label_count": labels.size(),
		"labels": labels,
		"alpha": _building_name_label_alpha,
		"camera_idle_seconds": _camera_idle_seconds,
		"idle_delay_seconds": BUILDING_NAME_IDLE_DELAY_SECONDS,
		"fade_speed": BUILDING_NAME_FADE_SPEED,
		"reveal_speed": BUILDING_NAME_REVEAL_SPEED,
		"camera_sample_valid": _camera_sample_valid,
	}


func debug_get_strategic_building_health_bar_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for raw_building_id in _building_health_bars.keys():
		var building_id := str(raw_building_id)
		var bar := _building_health_bars.get(building_id) as WorldHealthBar3D
		if bar != null:
			result[building_id] = bar.get_debug_snapshot()
	return result


func is_default_formal_world_enabled() -> bool:
	return _default_formal_world_enabled and not _legacy_compatibility_override


func debug_set_legacy_compatibility_enabled(enabled: bool) -> Dictionary:
	_legacy_compatibility_override = enabled
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	if enabled:
		_set_legacy_visuals_enabled(true)
		_sync_defense_device_runtime_binding(false)
		if npc_system != null and npc_system.has_method("end_default_formal_world"):
			npc_system.end_default_formal_world("gm_legacy_compatibility")
		debug_set_preview_enabled(false)
	else:
		_set_legacy_visuals_enabled(false)
		debug_set_preview_enabled(true)
		force_sync_production_navigation()
		_sync_defense_device_runtime_binding(true)
		if npc_system != null and npc_system.has_method("begin_default_formal_world"):
			npc_system.begin_default_formal_world()
	var merchant_system := get_node_or_null("/root/Main/Systems/MerchantSystem")
	if merchant_system != null and merchant_system.has_method("refresh_default_world_route"):
		merchant_system.refresh_default_world_route()
	return get_validation_snapshot()


func _activate_default_formal_world() -> void:
	if not _default_formal_world_enabled or _legacy_compatibility_override:
		return
	_set_legacy_visuals_enabled(false)
	debug_set_preview_enabled(true)
	force_sync_production_navigation()
	_sync_defense_device_runtime_binding(true)
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	if npc_system != null and npc_system.has_method("begin_default_formal_world"):
		npc_system.begin_default_formal_world()
	var merchant_system := get_node_or_null("/root/Main/Systems/MerchantSystem")
	if merchant_system != null and merchant_system.has_method("refresh_default_world_route"):
		merchant_system.refresh_default_world_route()


func debug_get_layout_snapshot() -> Dictionary:
	return get_validation_snapshot()


func get_formal_world_origin() -> Vector3:
	return _formal_root.global_position if is_instance_valid(_formal_root) else Vector3.ZERO


func is_world_position_inside_station(world_position: Vector3) -> bool:
	if not is_instance_valid(_formal_root):
		return false
	var polygon := _get_station_interior_polygon()
	if polygon.size() < 3:
		return false
	var local_position := _formal_root.to_local(world_position)
	return Geometry2D.is_point_in_polygon(Vector2(local_position.x, local_position.z), polygon)


func get_front_gate_inside_avoidance_target() -> Dictionary:
	if not is_instance_valid(_formal_root) or not _production_navigation_map.is_valid():
		return {"ok": false, "reason": "station_navigation_unavailable"}
	var response := get_friendly_station_response_config()
	var reentry := response.get("outside_avoidance_reentry", {}) as Dictionary
	if str(reentry.get("schema", "")) != "front_gate_inside_reentry_v1":
		return {"ok": false, "reason": "outside_avoidance_reentry_config_missing"}
	var gate_id := str(reentry.get("gate_id", "front_gate"))
	var station := _layout.get("station", {}) as Dictionary
	var gate := station.get(gate_id, {}) as Dictionary
	var gate_root := _formal_root.get_node_or_null(
		"WallsAndGates/%s" % str(gate.get("id", gate_id)).to_pascal_case()
	) as Node3D
	if gate.is_empty() or gate_root == null:
		return {"ok": false, "reason": "front_gate_geometry_missing"}
	var inside_direction := gate_root.global_basis * Vector3.FORWARD
	inside_direction.y = 0.0
	if inside_direction.length_squared() <= 0.0001:
		return {"ok": false, "reason": "front_gate_inside_direction_invalid"}
	inside_direction = inside_direction.normalized()
	var inside_offset := maxf(0.5, float(reentry.get("inside_offset", 5.0)))
	var desired_position := gate_root.global_position + inside_direction * inside_offset
	var resolved_position := NavigationServer3D.map_get_closest_point(
		_production_navigation_map,
		desired_position
	)
	if not is_world_position_inside_station(resolved_position):
		return {
			"ok": false,
			"reason": "front_gate_inside_target_outside_station",
			"desired_position": desired_position,
			"position": resolved_position
		}
	if not get_building_area_overlap(resolved_position, 0.4).is_empty():
		return {
			"ok": false,
			"reason": "front_gate_inside_target_overlaps_entity",
			"desired_position": desired_position,
			"position": resolved_position
		}
	return {
		"ok": true,
		"schema": "front_gate_inside_avoidance_target_v1",
		"reason": "front_gate_inside_navigation_resolved",
		"gate_id": gate_id,
		"position": resolved_position,
		"desired_position": desired_position,
		"inside_direction": inside_direction,
		"inside_offset": inside_offset,
		"navigation_adjusted": resolved_position.distance_to(desired_position) > 0.05
	}


func resolve_station_avoidance_navigation_target(
	origin_world_position: Vector3,
	desired_world_position: Vector3,
	boundary_inset: float = 1.25
) -> Dictionary:
	if not is_instance_valid(_formal_root) or not _production_navigation_map.is_valid():
		return {"ok": false, "reason": "station_navigation_unavailable"}
	var polygon := _get_station_interior_polygon()
	if polygon.size() < 3:
		return {"ok": false, "reason": "station_interior_polygon_missing"}
	var origin_local_3d := _formal_root.to_local(origin_world_position)
	var desired_local_3d := _formal_root.to_local(desired_world_position)
	var origin_local := Vector2(origin_local_3d.x, origin_local_3d.z)
	var desired_local := Vector2(desired_local_3d.x, desired_local_3d.z)
	var safe_origin := origin_local
	if not Geometry2D.is_point_in_polygon(safe_origin, polygon):
		var closest_origin_boundary := _get_closest_point_on_polygon(safe_origin, polygon)
		var polygon_center := _get_polygon_average(polygon)
		var inward_from_boundary := polygon_center - closest_origin_boundary
		if inward_from_boundary.length_squared() <= 0.0001:
			inward_from_boundary = polygon_center - safe_origin
		safe_origin = closest_origin_boundary + inward_from_boundary.normalized() * maxf(0.1, boundary_inset)
	var boundary_limited := not Geometry2D.is_point_in_polygon(desired_local, polygon)
	var interior_candidate := desired_local
	if boundary_limited:
		var segment_direction := desired_local - safe_origin
		var closest_intersection: Variant = null
		var closest_intersection_distance := INF
		for index in range(polygon.size()):
			var edge_start := polygon[index]
			var edge_end := polygon[(index + 1) % polygon.size()]
			var intersection: Variant = Geometry2D.segment_intersects_segment(
				safe_origin,
				desired_local,
				edge_start,
				edge_end
			)
			if not intersection is Vector2:
				continue
			var intersection_point: Vector2 = intersection
			var intersection_distance := safe_origin.distance_to(intersection_point)
			if intersection_distance <= 0.001 or intersection_distance >= closest_intersection_distance:
				continue
			closest_intersection = intersection_point
			closest_intersection_distance = intersection_distance
		if closest_intersection is Vector2 and segment_direction.length_squared() > 0.0001:
			var inset_distance := minf(maxf(0.1, boundary_inset), maxf(0.1, closest_intersection_distance - 0.1))
			interior_candidate = closest_intersection - segment_direction.normalized() * inset_distance
		else:
			interior_candidate = safe_origin
	var origin_navigation := NavigationServer3D.map_get_closest_point(
		_production_navigation_map,
		origin_world_position
	)
	var resolved_position := origin_navigation
	var resolved := false
	var attempts := 0
	# The first sample preserves the full weighted flee direction. Later samples
	# only retreat toward the NPC when a building, wall edge, or disconnected
	# polygon makes that point unusable.
	for attempt in range(13):
		attempts = attempt + 1
		var blend := float(attempt) / 12.0
		var sample_local := interior_candidate.lerp(safe_origin, blend)
		var sample_world := _formal_root.to_global(Vector3(sample_local.x, origin_local_3d.y, sample_local.y))
		var snapped := NavigationServer3D.map_get_closest_point(_production_navigation_map, sample_world)
		if not is_world_position_inside_station(snapped):
			continue
		# The production NavigationMap can intentionally include enterable building
		# floors. Avoidance destinations are outdoor holding points, so reject every
		# authored solid envelope and keep sampling back toward the NPC until the
		# target sits beside the obstruction.
		if not get_building_area_overlap(snapped, 0.4).is_empty():
			continue
		var path := NavigationServer3D.map_get_path(
			_production_navigation_map,
			origin_navigation,
			snapped,
			true
		)
		if path.is_empty() and origin_navigation.distance_to(snapped) > 0.25:
			continue
		resolved_position = snapped
		resolved = true
		break
	if not resolved:
		return {
			"ok": false,
			"reason": "station_avoidance_navigation_target_unreachable",
			"desired_position": desired_world_position,
			"boundary_limited": boundary_limited,
			"attempts": attempts
		}
	return {
		"ok": true,
		"reason": "station_navigation_resolved",
		"position": resolved_position,
		"desired_position": desired_world_position,
		"boundary_limited": boundary_limited,
		"navigation_adjusted": Vector2(resolved_position.x, resolved_position.z).distance_to(
			Vector2(desired_world_position.x, desired_world_position.z)
		) > 0.05,
		"attempts": attempts
	}


func _get_station_interior_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var station := _layout.get("station", {}) as Dictionary
	for raw_point in station.get("interior_polygon", []):
		polygon.append(_v2(raw_point))
	return polygon


func _get_closest_point_on_polygon(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var closest := point
	var closest_distance := INF
	for index in range(polygon.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(
			point,
			polygon[index],
			polygon[(index + 1) % polygon.size()]
		)
		var distance := point.distance_squared_to(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _get_polygon_average(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for point in polygon:
		total += point
	return total / float(polygon.size())


func get_friendly_station_response_config() -> Dictionary:
	var combat_spatial := _layout.get("combat_spatial", {}) as Dictionary
	return (combat_spatial.get("friendly_station_response", {}) as Dictionary).duplicate(true)


func migrate_legacy_formal_world_position(saved_position: Vector3) -> Vector3:
	var migration := _layout.get("migration", {}) as Dictionary
	var previous_offset := _v2(migration.get("previous_formal_world_offset", [0.0, 0.0]))
	if previous_offset.length_squared() <= 0.001:
		return saved_position
	var terrain := _layout.get("terrain", {}) as Dictionary
	var terrain_center := _v2(terrain.get("center", [0.0, 0.0]))
	var terrain_size := _v2(terrain.get("size", [700.0, 720.0]))
	var previous_local := Vector2(saved_position.x - previous_offset.x, saved_position.z - previous_offset.y)
	var margin := 32.0
	if (
		absf(previous_local.x - terrain_center.x) > terrain_size.x * 0.5 + margin
		or absf(previous_local.y - terrain_center.y) > terrain_size.y * 0.5 + margin
	):
		return saved_position
	var current_origin := get_formal_world_origin()
	return Vector3(
		current_origin.x + previous_local.x,
		saved_position.y,
		current_origin.z + previous_local.y
	)


func debug_get_spatial_reachability_snapshot() -> Dictionary:
	return _build_spatial_reachability_snapshot()


func debug_get_physics_navigation_snapshot() -> Dictionary:
	return _build_physics_navigation_snapshot()


func debug_get_production_navigation_snapshot() -> Dictionary:
	return _build_production_navigation_snapshot()


func get_production_navigation_map_rid() -> RID:
	return _production_navigation_map


func force_sync_production_navigation() -> Dictionary:
	if _production_navigation_map.is_valid():
		NavigationServer3D.map_force_update(_production_navigation_map)
	return _build_production_navigation_snapshot()


func get_actor_motion_profile(profile_id: String) -> Dictionary:
	var profiles := _physics_navigation.get("actor_profiles", {}) as Dictionary
	return (profiles.get(profile_id, {}) as Dictionary).duplicate(true)


func get_building_combat_geometry(building_id: String) -> Dictionary:
	if not is_instance_valid(_formal_root):
		return {}
	var station := _layout.get("station", {}) as Dictionary
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	if building_id in ["front_gate", "back_gate"]:
		var gate := station.get(building_id, {}) as Dictionary
		var gate_root := _formal_root.get_node_or_null(
			"WallsAndGates/%s" % str(gate.get("id", building_id)).to_pascal_case()
		) as Node3D
		if gate.is_empty() or gate_root == null:
			return {}
		var gate_right := gate_root.global_basis * Vector3.RIGHT
		var gate_forward := gate_root.global_basis * Vector3.BACK
		gate_right.y = 0.0
		gate_forward.y = 0.0
		if gate_right.length_squared() <= 0.0001 or gate_forward.length_squared() <= 0.0001:
			return {}
		var tower_collision := gate.get("tower_collision", {}) as Dictionary
		var tower_size := _v3(tower_collision.get(
			"size",
			[float(structural.get("gate_post_width", 1.2)), float(gate.get("height", 1.4)), 1.4]
		))
		return {
			"schema": "gate_combat_geometry_v1",
			"building_id": building_id,
			"center": gate_root.global_position,
			"size": Vector2(
				float(gate.get("clear_width", 0.0)) + tower_size.x * 2.0,
				maxf(1.4, tower_size.z)
			),
			"right_direction": gate_right.normalized(),
			"forward_direction": gate_forward.normalized(),
			"front_door_clear_width": maxf(0.0, float(gate.get("clear_width", 0.0))),
			"wall_thickness": maxf(1.4, tower_size.z),
		}
	if not _building_roots.has(building_id):
		return {}
	var building := _find_building_definition(building_id)
	var building_root := _building_roots.get(building_id) as Node3D
	if building.is_empty() or building_root == null:
		return {}
	var envelope := _v2(building.get("envelope_size", [0.0, 0.0]))
	if envelope.x <= 0.0 or envelope.y <= 0.0:
		return {}
	var right_direction := building_root.global_basis * Vector3.RIGHT
	# Layout-local positions store their second component on +Z (the authored
	# entrance/front side), while Godot's Vector3.FORWARD constant is -Z.
	var forward_direction := building_root.global_basis * Vector3.BACK
	right_direction.y = 0.0
	forward_direction.y = 0.0
	if right_direction.length_squared() <= 0.0001 or forward_direction.length_squared() <= 0.0001:
		return {}
	return {
		"schema": "oriented_building_combat_geometry_v1",
		"building_id": building_id,
		"center": building_root.global_position,
		"size": envelope,
		"right_direction": right_direction.normalized(),
		"forward_direction": forward_direction.normalized(),
		"front_door_clear_width": maxf(0.0, float(structural.get("building_door_clear_width", 1.4))),
		"wall_thickness": maxf(0.0, float(structural.get("wall_thickness", 0.4)))
	}


func get_building_area_overlap(world_center: Vector3, radius: float) -> Dictionary:
	if not is_instance_valid(_formal_root):
		return {}
	var checked_radius := maxf(0.0, radius)
	for raw_building in _layout.get("buildings", []):
		if not raw_building is Dictionary:
			continue
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var building_root := _building_roots.get(building_id, null) as Node3D
		if building_root == null:
			continue
		var envelope := _v2(building.get("envelope_size", [0.0, 0.0]))
		if _circle_overlaps_local_rectangle(
			building_root.to_local(world_center),
			checked_radius,
			envelope * 0.5
		):
			return {
				"building_id": building_id,
				"area_kind": "building_envelope",
				"center": building_root.global_position,
				"size": envelope,
			}

	var station := _layout.get("station", {}) as Dictionary
	var station_point_3d := _formal_root.to_local(world_center)
	var station_point := Vector2(station_point_3d.x, station_point_3d.z)
	for raw_outbuilding in _layout.get("service_outbuildings", []):
		if not raw_outbuilding is Dictionary:
			continue
		var outbuilding: Dictionary = raw_outbuilding
		var outbuilding_center := _v2(outbuilding.get("position", []))
		var outbuilding_basis := Basis(
			Vector3.UP,
			deg_to_rad(float(outbuilding.get("rotation_degrees", 0.0)))
		)
		var outbuilding_local := outbuilding_basis.inverse() * Vector3(
			station_point.x - outbuilding_center.x,
			0.0,
			station_point.y - outbuilding_center.y
		)
		var outbuilding_size := _v2(outbuilding.get("footprint", [0.0, 0.0]))
		if _circle_overlaps_local_rectangle(outbuilding_local, checked_radius, outbuilding_size * 0.5):
			return {
				"building_id": str(outbuilding.get("id", "")),
				"area_kind": "service_outbuilding_envelope",
				"center": _formal_root.to_global(Vector3(outbuilding_center.x, 0.0, outbuilding_center.y)),
				"size": outbuilding_size,
			}
	var wall_half_width := maxf(0.0, float(station.get("wall_thickness", 0.0))) * 0.5
	for raw_segment in station.get("wall_segments", []):
		if not raw_segment is Dictionary:
			continue
		var segment: Dictionary = raw_segment
		var point_a := _v2(segment.get("from", []))
		var point_b := _v2(segment.get("to", []))
		if station_point.distance_to(Geometry2D.get_closest_point_to_segment(station_point, point_a, point_b)) <= checked_radius + wall_half_width:
			return {
				"building_id": "wall",
				"area_kind": "wall_segment",
				"segment_id": str(segment.get("id", "")),
			}

	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	var gate_post_width := maxf(0.0, float(structural.get("gate_post_width", 1.2)))
	for gate_key in ["front_gate", "back_gate"]:
		var gate := station.get(gate_key, {}) as Dictionary
		if gate.is_empty():
			continue
		var gate_center := _v2(gate.get("center", []))
		var gate_basis := Basis(Vector3.UP, deg_to_rad(float(gate.get("rotation_degrees", 0.0))))
		var gate_local_3d := gate_basis.inverse() * Vector3(
			station_point.x - gate_center.x,
			0.0,
			station_point.y - gate_center.y
		)
		var gate_half_size := Vector2(
			float(gate.get("clear_width", 0.0)) * 0.5 + gate_post_width,
			0.7
		)
		if _circle_overlaps_local_rectangle(gate_local_3d, checked_radius, gate_half_size):
			return {
				"building_id": str(gate.get("id", gate_key)),
				"area_kind": "gate_envelope",
				"center": _formal_root.to_global(Vector3(gate_center.x, 0.0, gate_center.y)),
				"size": gate_half_size * 2.0,
			}
	return {}


func _circle_overlaps_local_rectangle(
	local_center: Vector3,
	radius: float,
	half_size: Vector2
) -> bool:
	var outside_x := maxf(absf(local_center.x) - maxf(0.0, half_size.x), 0.0)
	var outside_z := maxf(absf(local_center.z) - maxf(0.0, half_size.y), 0.0)
	return outside_x * outside_x + outside_z * outside_z <= radius * radius


func get_formal_wave_spawn_config() -> Dictionary:
	return (_physics_navigation.get("formal_wave_spawn", {}) as Dictionary).duplicate(true)


func get_friendly_rally_world_config() -> Dictionary:
	return _combat_area_config_to_world("friendly_rally", "center", "enemy_direction")


func get_gm_enemy_spawn_world_config() -> Dictionary:
	var result := _combat_area_config_to_world("gm_enemy_spawn", "formation_front_center", "travel_direction")
	var combat_spatial := _layout.get("combat_spatial", {}) as Dictionary
	var config := combat_spatial.get("gm_enemy_spawn", {}) as Dictionary
	if not result.is_empty():
		var area_center := _v2(config.get("area_center", []))
		result["area_center"] = _formal_root.to_global(Vector3(area_center.x, 0.0, area_center.y))
	return result


func _combat_area_config_to_world(config_key: String, position_key: String, direction_key: String) -> Dictionary:
	if _formal_root == null:
		return {}
	var combat_spatial := _layout.get("combat_spatial", {}) as Dictionary
	var config := (combat_spatial.get(config_key, {}) as Dictionary).duplicate(true)
	if config.is_empty():
		return {}
	var point := _v2(config.get(position_key, []))
	var direction_2d := _v2(config.get(direction_key, []))
	var world_direction := _formal_root.global_basis * Vector3(direction_2d.x, 0.0, direction_2d.y)
	world_direction.y = 0.0
	if world_direction.length_squared() > 0.0001:
		world_direction = world_direction.normalized()
	config[position_key] = _formal_root.to_global(Vector3(point.x, 0.0, point.y))
	config[direction_key] = world_direction
	return config


func get_enemy_route_world() -> Dictionary:
	if _formal_root == null:
		return {}
	var combat_spatial := _layout.get("combat_spatial", {}) as Dictionary
	var route := combat_spatial.get("enemy_route", {}) as Dictionary
	if route.is_empty():
		return {}
	var world_stages: Array[Dictionary] = []
	for raw_stage in route.get("stages", []):
		if not raw_stage is Dictionary:
			continue
		var stage := raw_stage as Dictionary
		var point := _v2(stage.get("point", []))
		world_stages.append({
			"id": str(stage.get("id", "")),
			"label": str(stage.get("label", "")),
			"position": _formal_root.to_global(Vector3(point.x, 0.0, point.y))
		})
	return {
		"route_source": "formal_station_layout",
		"spawn_zone_center": _formal_root.to_global(_station_point_to_vector3(route.get("spawn_zone_center", []))),
		"spawn_zone_size": _v2(route.get("spawn_zone_size", [])),
		"approach_half_width": float(route.get("approach_half_width", 0.0)),
		"pilot_stop_stage_id": str(route.get("pilot_stop_stage_id", "front_gate")),
		"stages": world_stages
	}


func get_formal_merchant_route_world() -> Dictionary:
	if _formal_root == null:
		return {}
	var rear_spatial := _layout.get("rear_spatial", {}) as Dictionary
	var route := rear_spatial.get("merchant_route", {}) as Dictionary
	if route.is_empty():
		return {}
	var world_points: Array[Vector3] = []
	for raw_point in route.get("path_points", []):
		world_points.append(_formal_root.to_global(_station_point_to_vector3(raw_point)))
	return {
		"route_source": "formal_station_layout",
		"coordinate_space": "formal_world",
		"path_policy": str(route.get("path_policy", "physical_polyline_navigation")),
		"corridor_half_width": float(route.get("corridor_half_width", 2.25)),
		"back_gate": _formal_root.to_global(_station_point_to_vector3(rear_spatial.get("back_gate", []))),
		"spawn": _formal_root.to_global(_station_point_to_vector3(route.get("spawn", []))),
		"dock": _formal_root.to_global(_station_point_to_vector3(route.get("dock", []))),
		"dock_root_clearance_to_back_gate_m": float(route.get("dock_root_clearance_to_back_gate_m", 0.0)),
		"path_points": world_points
	}


func get_formal_escape_route_world() -> Dictionary:
	if _formal_root == null:
		return {}
	var rear_spatial := _layout.get("rear_spatial", {}) as Dictionary
	var route := rear_spatial.get("escape_route", {}) as Dictionary
	if route.is_empty():
		return {}
	var world_points: Array[Vector3] = []
	for raw_point in route.get("path_points", []):
		world_points.append(_formal_root.to_global(_station_point_to_vector3(raw_point)))
	return {
		"route_source": "formal_station_layout",
		"coordinate_space": "formal_world",
		"path_policy": str(route.get("path_policy", "physical_polyline_navigation")),
		"corridor_half_width": float(route.get("corridor_half_width", 2.25)),
		"back_gate": _formal_root.to_global(_station_point_to_vector3(rear_spatial.get("back_gate", []))),
		"completion": _formal_root.to_global(_station_point_to_vector3(route.get("completion", []))),
		"path_points": world_points,
		"route_length": _rear_escape_route_length
	}


func get_formal_first_wave_navigation_config() -> Dictionary:
	return get_formal_wave_navigation_config(1)


func get_formal_wave_navigation_config(wave_number: int) -> Dictionary:
	var combat_spatial := _layout.get("combat_spatial", {}) as Dictionary
	if wave_number < 1 or wave_number > 5:
		return {}
	var config_key := "c3_p7_dynamic_assault"
	var config := (combat_spatial.get(config_key, {}) as Dictionary).duplicate(true)
	if config.is_empty():
		config_key = "c3_p6_second_wave" if wave_number == 2 else "c3_p5r_direct_assault"
		config = (combat_spatial.get(config_key, {}) as Dictionary).duplicate(true)
	config["wave_number"] = wave_number
	var world_slots: Dictionary = {}
	var slot_sets_world: Dictionary = {}
	for raw_building_id in (config.get("attack_slots", {}) as Dictionary).keys():
		var building_id := str(raw_building_id)
		var slot_config := (config.get("attack_slots", {}) as Dictionary).get(building_id, {}) as Dictionary
		world_slots[building_id] = _attack_slot_config_to_world(building_id, slot_config)
	for raw_building_id in (config.get("attack_slot_sets", {}) as Dictionary).keys():
		var building_id := str(raw_building_id)
		var building_sets := (config.get("attack_slot_sets", {}) as Dictionary).get(building_id, {}) as Dictionary
		var converted_sets: Dictionary = {}
		for raw_role_id in building_sets.keys():
			var role_id := str(raw_role_id)
			converted_sets[role_id] = _attack_slot_config_to_world(building_id, building_sets.get(role_id, {}) as Dictionary)
		slot_sets_world[building_id] = converted_sets
	config["attack_slots_world"] = world_slots
	config["attack_slot_sets_world"] = slot_sets_world
	config.erase("attack_slots")
	config.erase("attack_slot_sets")
	return config


func _attack_slot_config_to_world(building_id: String, slot_config: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var coordinate_space := str(slot_config.get("space", "station"))
	var building := _find_building_definition(building_id)
	for raw_point in slot_config.get("points", []):
		var station_point := _v2(raw_point)
		if coordinate_space == "building_local" and not building.is_empty():
			station_point = _building_local_to_station(building, raw_point)
		points.append(_formal_root.to_global(Vector3(station_point.x, 0.0, station_point.y)))
	return points


func get_building_spatial_route(building_id: String, position_id: String = "") -> Dictionary:
	if not _building_roots.has(building_id):
		return {}
	var spatial_contract: Dictionary = (_layout.get("building_spatial", {}) as Dictionary).get(building_id, {})
	var route: Dictionary = spatial_contract.get("entry_route", {})
	var building_root := _building_roots[building_id] as Node3D
	if route.is_empty() or building_root == null:
		return {}
	var target_local := _v2(route.get("interior", [0.0, 0.0]))
	var logical_target_local := target_local
	var target_fixture_id := ""
	var arrival_mode := "stand"
	var occupant_anchor_position: Variant = null
	var occupant_anchor_facing_direction: Variant = null
	var occupant_pose := ""
	var target_fixture_collision_size: Variant = null
	var target_fixture_right_direction: Variant = null
	var target_fixture_forward_direction: Variant = null
	var explicit_facing_degrees: Variant = null
	var target_desired_distance: Variant = null
	if not position_id.is_empty():
		var position_definition := _find_position_definition(building_id, position_id)
		if position_definition.is_empty():
			return {}
		logical_target_local = _v2(position_definition.get("center", [0.0, 0.0]))
		target_local = logical_target_local
		var fixture := _find_fixture_for_position(building_id, position_id)
		target_fixture_id = str(fixture.get("id", ""))
		if not fixture.is_empty():
			target_fixture_collision_size = _v3(fixture.get("collision_size", [0.0, 0.0, 0.0]))
			var fixture_basis := Basis(Vector3.UP, deg_to_rad(float(fixture.get("rotation_degrees", 0.0))))
			target_fixture_right_direction = (building_root.global_basis * (fixture_basis * Vector3.RIGHT)).normalized()
			target_fixture_forward_direction = (building_root.global_basis * (fixture_basis * Vector3.FORWARD)).normalized()
		var npc_stand: Dictionary = fixture.get("npc_stand", {})
		if not npc_stand.is_empty():
			target_local = _v2(npc_stand.get("center", logical_target_local))
			explicit_facing_degrees = npc_stand.get("facing_degrees", 0.0)
			if npc_stand.has("target_desired_distance"):
				target_desired_distance = float(npc_stand.get("target_desired_distance", 0.25))
			arrival_mode = str(fixture.get("arrival_mode", "stand"))
			var occupant_anchor := fixture.get("occupant_anchor", {}) as Dictionary
			if not occupant_anchor.is_empty():
				occupant_anchor_position = _building_local_to_global(
					building_root,
					occupant_anchor.get("center", logical_target_local),
					float(occupant_anchor.get("y", 0.0))
				)
				var occupant_facing_radians := deg_to_rad(float(occupant_anchor.get("facing_degrees", 0.0)))
				var occupant_facing_local := Vector3(
					sin(occupant_facing_radians),
					0.0,
					-cos(occupant_facing_radians)
				)
				occupant_anchor_facing_direction = (building_root.global_basis * occupant_facing_local).normalized()
				occupant_pose = str(occupant_anchor.get("pose", ""))
	var target_direction_local := Vector3(-target_local.x, 0.0, -target_local.y)
	if explicit_facing_degrees != null:
		var facing_radians := deg_to_rad(float(explicit_facing_degrees))
		target_direction_local = Vector3(sin(facing_radians), 0.0, -cos(facing_radians))
	if target_direction_local.length_squared() <= 0.0001:
		target_direction_local = Vector3(0.0, 0.0, -1.0)
	var target_facing := (building_root.global_basis * target_direction_local).normalized()
	var result := {
		"schema_version": EXPECTED_SCHEMA,
		"staged": not _default_formal_world_enabled,
		"live_default": _default_formal_world_enabled,
		"building_id": building_id,
		"position_id": position_id,
		"target_fixture_id": target_fixture_id,
		"arrival_mode": arrival_mode,
		"entry_outside_position": _building_local_to_global(building_root, route.get("entry_outside", [])),
		"door_outside_position": _building_local_to_global(building_root, route.get("door_outside", [])),
		"door_inside_position": _building_local_to_global(building_root, route.get("door_inside", [])),
		"interior_position": _building_local_to_global(building_root, route.get("interior", route.get("door_inside", []))),
		"interior_target_position": _building_local_to_global(building_root, target_local),
		"logical_position_center_position": _building_local_to_global(building_root, logical_target_local),
		"exit_outside_position": _building_local_to_global(building_root, route.get("exit_outside", [])),
		"interior_target_facing_direction": target_facing
	}
	if occupant_anchor_position != null:
		result["occupant_anchor_position"] = occupant_anchor_position
		result["occupant_anchor_facing_direction"] = occupant_anchor_facing_direction
		result["occupant_pose"] = occupant_pose
	if target_fixture_collision_size is Vector3:
		result["target_fixture_collision_size"] = target_fixture_collision_size
		result["target_fixture_right_direction"] = target_fixture_right_direction
		result["target_fixture_forward_direction"] = target_fixture_forward_direction
	if target_desired_distance != null:
		result["target_desired_distance"] = target_desired_distance
	return result


func get_enterable_building_at_world_position(world_position: Vector3) -> Dictionary:
	for raw_building in _layout.get("buildings", []):
		if not raw_building is Dictionary:
			continue
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		if is_world_position_inside_enterable_building(building_id, world_position):
			var building_root := _building_roots.get(building_id, null) as Node3D
			return {
				"schema": "enterable_building_containment_v1",
				"building_id": building_id,
				"world_position": world_position,
				"local_position": building_root.to_local(world_position) if building_root != null else Vector3.ZERO,
			}
	return {}


func is_world_position_inside_enterable_building(building_id: String, world_position: Vector3) -> bool:
	if not _building_roots.has(building_id):
		return false
	var building := _find_building_definition(building_id)
	var spatial_contract := (_layout.get("building_spatial", {}) as Dictionary).get(building_id, {}) as Dictionary
	var route := spatial_contract.get("entry_route", {}) as Dictionary
	var blocker_config := building.get("solid_interior_blocker", {}) as Dictionary
	if building.is_empty() or route.is_empty() or bool(blocker_config.get("enabled", false)):
		return false
	var building_root := _building_roots.get(building_id, null) as Node3D
	if building_root == null:
		return false
	var envelope := _v2(building.get("envelope_size", [0.0, 0.0]))
	if envelope.x <= 0.0 or envelope.y <= 0.0:
		return false
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	# The half-wall inset keeps a body just outside a doorway from being classified
	# as indoors while still including every authored door_inside point.
	var interior_inset := maxf(0.05, float(structural.get("wall_thickness", 0.4)) * 0.5)
	var interior_half := envelope * 0.5 - Vector2(interior_inset, interior_inset)
	if interior_half.x <= 0.0 or interior_half.y <= 0.0:
		return false
	var local_position := building_root.to_local(world_position)
	return (
		absf(local_position.x) <= interior_half.x
		and absf(local_position.z) <= interior_half.y
	)


func get_indoor_exit_navigation_prefix(
	world_origin: Vector3,
	final_world_target: Vector3,
	reached_tolerance: float = 0.45
) -> Dictionary:
	var origin_building := get_enterable_building_at_world_position(world_origin)
	if origin_building.is_empty():
		return {}
	var building_id := str(origin_building.get("building_id", ""))
	if is_world_position_inside_enterable_building(building_id, final_world_target):
		return {}
	var route := get_building_spatial_route(building_id)
	if route.is_empty():
		return {}
	var ordered_keys: Array[String] = [
		"interior_position",
		"door_inside_position",
		"door_outside_position",
		"entry_outside_position",
	]
	var ordered_ids: Array[String] = [
		"interior",
		"door_inside",
		"door_outside",
		"entry_outside",
	]
	var points: Array[Vector3] = []
	var point_ids: Array[String] = []
	var checked_tolerance := maxf(0.05, reached_tolerance)
	for index in range(ordered_keys.size()):
		var raw_point: Variant = route.get(ordered_keys[index])
		if not raw_point is Vector3:
			continue
		var point: Vector3 = raw_point
		if not points.is_empty() and _horizontal_world_distance(points.back(), point) <= 0.05:
			continue
		points.append(point)
		point_ids.append(ordered_ids[index])
	if points.is_empty():
		return {}
	# Exit routes are authored from the interior towards the exterior. Treat that
	# direction as monotonic progress: avoidance can push a body sideways past a
	# route point without ever bringing it within the point radius, and a later
	# request/rebuild must not send that body back into the building.
	var exit_forward_direction := Vector3.ZERO
	if points.size() >= 2:
		exit_forward_direction = points.back() - points.front()
		exit_forward_direction.y = 0.0
		if exit_forward_direction.length_squared() > 0.0001:
			exit_forward_direction = exit_forward_direction.normalized()
	var reached_point_index := -1
	var skipped_point_ids: Array[String] = []
	var pass_margin := maxf(0.08, checked_tolerance * 0.25)
	for index in range(points.size()):
		if _horizontal_world_distance(world_origin, points[index]) <= checked_tolerance:
			reached_point_index = index
			continue
		if exit_forward_direction.length_squared() <= 0.5:
			continue
		var outward_progress := world_origin - points[index]
		outward_progress.y = 0.0
		if outward_progress.dot(exit_forward_direction) >= pass_margin:
			reached_point_index = index
	for _index in range(reached_point_index + 1):
		skipped_point_ids.append(point_ids.front())
		points.pop_front()
		point_ids.pop_front()
	if points.is_empty():
		return {}
	return {
		"schema": "indoor_exit_navigation_prefix_v1",
		"building_id": building_id,
		"origin_position": world_origin,
		"final_target_position": final_world_target,
		"point_ids": point_ids,
		"points": points,
		"skipped_point_ids": skipped_point_ids,
		"exit_forward_direction": exit_forward_direction,
		"route_source": "formal_station_layout_reverse_entry",
	}


func _horizontal_world_distance(from_position: Vector3, to_position: Vector3) -> float:
	return Vector2(from_position.x, from_position.z).distance_to(Vector2(to_position.x, to_position.z))


func get_defense_device_slot_pose(building_id: String, position_id: String) -> Dictionary:
	if building_id == "wall":
		return _get_front_wall_defense_device_slot_pose(position_id)
	if not _building_roots.has(building_id):
		return {}
	var position_definition := _find_position_definition(building_id, position_id)
	if position_definition.is_empty() or str(position_definition.get("authority", "")) != AUTHORITY_DEFENSE_SLOT:
		return {}
	var fixture := _find_fixture_for_position(building_id, position_id)
	if fixture.is_empty() or str(fixture.get("kind", "")) != "main_hall_device_platform":
		return {}
	var building_root := _building_roots.get(building_id) as Node3D
	if building_root == null:
		return {}
	var center := _v2(position_definition.get("center", [0.0, 0.0]))
	var collision_size := _v3(fixture.get("collision_size", [0.0, 0.0, 0.0]))
	var fallback_anchor_y := float(fixture.get("collision_center_y", fixture.get("visual_y", 0.0))) + collision_size.y * 0.5
	var anchor_y := float(fixture.get("device_anchor_y", fallback_anchor_y))
	var local_facing_degrees := float(fixture.get("device_facing_degrees", 0.0))
	var facing_radians := deg_to_rad(local_facing_degrees)
	var local_facing := Vector3(sin(facing_radians), 0.0, cos(facing_radians))
	var world_facing := (building_root.global_basis * local_facing).normalized()
	var building_definition := _find_building_definition(building_id)
	var envelope := _v2(building_definition.get("envelope_size", [1.0, 1.0]))
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	var wall_thickness := float(structural.get("wall_thickness", 0.4))
	var wall_height := maxf(
		float(building_definition.get("height", 1.0)),
		float(structural.get("minimum_wall_height", 1.2))
	)
	var proxy_fixture_aim_position := _building_local_to_global(
		building_root,
		center,
		float(fixture.get("collision_center_y", anchor_y))
	)
	var platform_size := _v2(position_definition.get("size", [0.0, 0.0]))
	var proxy_hit_radius := maxf(0.75, minf(platform_size.x, platform_size.y) * 0.5 + 0.25)
	var longitudinal_sign := -1.0 if center.y < 0.0 else 1.0
	var lateral_sign := -1.0 if center.x < 0.0 else 1.0
	var primary_segment_id := "back_wall" if longitudinal_sign < 0.0 else ("front_left" if lateral_sign < 0.0 else "front_right")
	var side_segment_id := "left_wall" if lateral_sign < 0.0 else "right_wall"
	var host_proxy_regions: Array[Dictionary] = [
		_make_main_hall_host_proxy_region(
			building_root,
			building_id,
			position_id,
			str(fixture.get("id", "")),
			primary_segment_id,
			Vector2(center.x, longitudinal_sign * (envelope.y * 0.5 - wall_thickness * 0.5)),
			Vector3(0.0, 0.0, longitudinal_sign),
			wall_height,
			wall_thickness,
			proxy_hit_radius,
			proxy_fixture_aim_position
		),
		_make_main_hall_host_proxy_region(
			building_root,
			building_id,
			position_id,
			str(fixture.get("id", "")),
			side_segment_id,
			Vector2(lateral_sign * (envelope.x * 0.5 - wall_thickness * 0.5), center.y),
			Vector3(lateral_sign, 0.0, 0.0),
			wall_height,
			wall_thickness,
			proxy_hit_radius,
			proxy_fixture_aim_position
		)
	]
	var primary_proxy := host_proxy_regions[0]
	return {
		"schema_version": EXPECTED_SCHEMA,
		"building_id": building_id,
		"position_id": position_id,
		"fixture_id": str(fixture.get("id", "")),
		"position": _building_local_to_global(building_root, [center.x, center.y], anchor_y),
		"facing_direction": world_facing,
		"rotation_y_degrees": rad_to_deg(atan2(world_facing.x, world_facing.z)),
		"local_center": center,
		"platform_size": platform_size,
		"host_proxy_schema": "main_hall_corner_host_proxy_regions_v1",
		"host_proxy_regions": host_proxy_regions,
		"host_proxy_kind": str(primary_proxy.get("kind", "building_wall_segment")),
		"host_proxy_id": str(primary_proxy.get("id", "")),
		"host_proxy_building_segment_id": str(primary_proxy.get("building_segment_id", "")),
		"host_proxy_fixture_id": str(fixture.get("id", "")),
		"host_proxy_position": primary_proxy.get("position", Vector3.ZERO),
		"host_proxy_aim_position": primary_proxy.get("aim_position", Vector3.ZERO),
		"host_proxy_fixture_aim_position": proxy_fixture_aim_position,
		"host_proxy_outward_direction": primary_proxy.get("outward_direction", Vector3.FORWARD),
		"host_proxy_contact_radius": float(primary_proxy.get("contact_radius", wall_thickness * 0.5)),
		"host_proxy_hit_radius": float(primary_proxy.get("hit_radius", proxy_hit_radius)),
		"required_level": int(position_definition.get("required_level", 1)),
		"live_default": is_default_formal_world_enabled()
	}


func _make_main_hall_host_proxy_region(
	building_root: Node3D,
	building_id: String,
	position_id: String,
	fixture_id: String,
	building_segment_id: String,
	proxy_local: Vector2,
	local_outward: Vector3,
	wall_height: float,
	wall_thickness: float,
	hit_radius: float,
	fixture_aim_position: Vector3
) -> Dictionary:
	var proxy_position := _building_local_to_global(building_root, proxy_local, 0.0)
	var proxy_aim_position := _building_local_to_global(building_root, proxy_local, wall_height * 0.55)
	var outward_direction := (building_root.global_basis * local_outward).normalized()
	return {
		"kind": "building_wall_segment",
		"id": "%s:%s:%s" % [building_id, building_segment_id, position_id],
		"building_id": building_id,
		"slot_id": position_id,
		"building_segment_id": building_segment_id,
		"fixture_id": fixture_id,
		"position": proxy_position,
		"aim_position": proxy_aim_position,
		"fixture_aim_position": fixture_aim_position,
		"outward_direction": outward_direction,
		"contact_radius": wall_thickness * 0.5,
		"hit_radius": hit_radius,
		"strict_collision_identity": true
	}


func _get_front_wall_defense_device_slot_pose(position_id: String) -> Dictionary:
	if _formal_root == null:
		return {}
	var lateral_offsets := {
		"wall_slot_01": -7.6,
		"wall_slot_02": 7.6,
		"wall_slot_03": -13.0,
		"wall_slot_04": 13.0
	}
	if not lateral_offsets.has(position_id):
		return {}
	var station := _layout.get("station", {}) as Dictionary
	var gate := station.get("front_gate", {}) as Dictionary
	if gate.is_empty():
		return {}
	var lateral_offset := float(lateral_offsets.get(position_id, 0.0))
	var segment_id := "north_west_a" if lateral_offset < 0.0 else "north_east"
	var segment := _find_station_wall_segment(station, segment_id)
	if segment.is_empty():
		return {}
	var center := _v2(gate.get("center", [0.0, 0.0]))
	var point_a := _v2(segment.get("from", [0.0, 0.0]))
	var point_b := _v2(segment.get("to", [0.0, 0.0]))
	var near_point := point_a if point_a.distance_to(center) <= point_b.distance_to(center) else point_b
	var far_point := point_b if near_point == point_a else point_a
	var distance_from_gate_edge := maxf(0.0, absf(lateral_offset) - float(gate.get("clear_width", 6.0)) * 0.5)
	var station_point := near_point + (far_point - near_point).normalized() * distance_from_gate_edge
	var low_x_point := point_a if point_a.x <= point_b.x else point_b
	var high_x_point := point_b if point_a.x <= point_b.x else point_a
	var wall_tangent := (high_x_point - low_x_point).normalized()
	var anchor_height := float(gate.get("height", 3.2)) + 0.35
	var wall_height := float(station.get("wall_height", 2.4))
	var wall_thickness := float(station.get("wall_thickness", 1.2))
	var station_position := Vector3(station_point.x, anchor_height, station_point.y)
	var proxy_position := Vector3(station_point.x, 0.0, station_point.y)
	var proxy_aim_position := Vector3(station_point.x, wall_height * 0.55, station_point.y)
	var facing_direction := Vector3(-wall_tangent.y, 0.0, wall_tangent.x).normalized()
	return {
		"schema_version": EXPECTED_SCHEMA,
		"building_id": "wall",
		"position_id": position_id,
		"fixture_id": "front_wall_defense_walkway",
		"wall_segment_id": segment_id,
		"position": _formal_root.to_global(station_position),
		"host_proxy_kind": "wall_segment",
		"host_proxy_id": "wall:%s:%s" % [segment_id, position_id],
		"host_proxy_wall_segment_id": segment_id,
		"host_proxy_position": _formal_root.to_global(proxy_position),
		"host_proxy_aim_position": _formal_root.to_global(proxy_aim_position),
		"host_proxy_outward_direction": facing_direction,
		"host_proxy_contact_radius": wall_thickness * 0.5,
		"host_proxy_hit_radius": 2.05,
		"facing_direction": facing_direction,
		"rotation_y_degrees": rad_to_deg(atan2(facing_direction.x, facing_direction.z)),
		"live_default": is_default_formal_world_enabled()
	}


func _find_station_wall_segment(station: Dictionary, segment_id: String) -> Dictionary:
	for raw_segment in station.get("wall_segments", []):
		if raw_segment is Dictionary and str(raw_segment.get("id", "")) == segment_id:
			return raw_segment as Dictionary
	return {}


func _sync_defense_device_runtime_binding(use_formal_positions: bool) -> void:
	var device_system := get_node_or_null("/root/Main/Systems/DefenseDeviceSystem")
	if device_system == null:
		return
	if use_formal_positions and device_system.has_method("bind_formal_slot_positions"):
		device_system.bind_formal_slot_positions(self)
	elif not use_formal_positions and device_system.has_method("restore_configured_slot_positions"):
		device_system.restore_configured_slot_positions()


func get_public_location_world_position(location_id: String) -> Variant:
	var marker := _spatial_anchor_nodes.get("public:%s" % location_id) as Node3D
	return marker.global_position if marker != null else null


func get_building_exterior_service_slots(building_id: String, service_kind: String = "repair") -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if (
		_formal_root == null
		or not _production_navigation_map.is_valid()
	):
		return slots
	if building_id in ["wall", "front_gate", "back_gate"]:
		return _get_infrastructure_exterior_service_slots(building_id, service_kind)
	if not _building_roots.has(building_id):
		return slots
	var building := _find_building_definition(building_id)
	var building_root := _building_roots.get(building_id) as Node3D
	if building.is_empty() or building_root == null:
		return slots
	var envelope := _v2(building.get("envelope_size", [0.0, 0.0]))
	if envelope.x <= 0.0 or envelope.y <= 0.0:
		return slots
	# Two positions on each face keep helpers close to the damaged structure while
	# leaving door centres and the circulation path open.  Values are metres in the
	# same maximum-level envelope used by fixture collision and NavMesh baking.
	var clearance := 1.10
	var half_x := envelope.x * 0.5
	var half_z := envelope.y * 0.5
	var side_x := maxf(1.25, half_x * 0.52)
	var side_z := maxf(1.25, half_z * 0.52)
	var local_candidates: Array[Vector2] = [
		Vector2(-side_x, half_z + clearance),
		Vector2(side_x, half_z + clearance),
		Vector2(half_x + clearance, side_z),
		Vector2(half_x + clearance, -side_z),
		Vector2(side_x, -half_z - clearance),
		Vector2(-side_x, -half_z - clearance),
		Vector2(-half_x - clearance, -side_z),
		Vector2(-half_x - clearance, side_z),
	]
	for index in range(local_candidates.size()):
		var requested_position := _building_local_to_global(building_root, local_candidates[index])
		var snapped_position := NavigationServer3D.map_get_closest_point(
			_production_navigation_map,
			requested_position
		)
		var snap_error := Vector2(
			snapped_position.x - requested_position.x,
			snapped_position.z - requested_position.z
		).length()
		var navigation_sync_pending := snap_error > 0.85
		if navigation_sync_pending:
			# A formal session enables the Region and queries its slot in the same
			# frame. NavigationServer publishes that enable one physics frame later;
			# keep the audited envelope point and let the deferred route start snap it.
			snapped_position = requested_position
		var facing_direction := building_root.global_position - snapped_position
		facing_direction.y = 0.0
		if facing_direction.length_squared() <= 0.0001:
			continue
		slots.append({
			"slot_id": "%s_%s_%02d" % [building_id, service_kind, index + 1],
			"building_id": building_id,
			"service_kind": service_kind,
			"position": snapped_position,
			"requested_position": requested_position,
			"facing_direction": facing_direction.normalized(),
			"snap_error": snap_error,
			"navigation_sync_pending": navigation_sync_pending,
			"envelope_clearance": clearance,
		})
	return slots


func _get_infrastructure_exterior_service_slots(building_id: String, service_kind: String) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var station := _layout.get("station", {}) as Dictionary
	var station_candidates: Array[Dictionary] = []
	var station_center := _v2((station.get("plaza", {}) as Dictionary).get("center", [0.0, 10.0]))
	if building_id == "wall":
		var segments: Array = station.get("wall_segments", [])
		for raw_segment in segments:
			if not raw_segment is Dictionary:
				continue
			var segment: Dictionary = raw_segment
			var from_point := _v2(segment.get("from", []))
			var to_point := _v2(segment.get("to", []))
			if from_point.distance_to(to_point) < 12.0:
				continue
			var wall_point := from_point.lerp(to_point, 0.5)
			var inward := station_center - wall_point
			if inward.length_squared() <= 0.0001:
				continue
			inward = inward.normalized()
			station_candidates.append({
				"requested": wall_point + inward * 1.25,
				"facing": -inward,
			})
	else:
		var gate := station.get(building_id, {}) as Dictionary
		if gate.is_empty():
			return slots
		var gate_center := _v2(gate.get("center", []))
		var inward := station_center - gate_center
		if inward.length_squared() <= 0.0001:
			return slots
		inward = inward.normalized()
		var tangent := Vector2(-inward.y, inward.x)
		var half_clear_width := float(gate.get("clear_width", 5.0)) * 0.5
		for side in [-1.0, 1.0]:
			for extra_offset in [1.10, 2.45]:
				station_candidates.append({
					"requested": gate_center + tangent * side * (half_clear_width + extra_offset) + inward * 1.25,
					"facing": -inward,
				})
	for index in range(station_candidates.size()):
		var candidate: Dictionary = station_candidates[index]
		var requested_station := candidate.get("requested", Vector2.ZERO) as Vector2
		var requested_position := _formal_root.to_global(Vector3(requested_station.x, 0.0, requested_station.y))
		var snapped_position := NavigationServer3D.map_get_closest_point(_production_navigation_map, requested_position)
		var snap_error := Vector2(
			snapped_position.x - requested_position.x,
			snapped_position.z - requested_position.z
		).length()
		var navigation_sync_pending := snap_error > 0.85
		if navigation_sync_pending:
			snapped_position = requested_position
		var facing_2d := candidate.get("facing", Vector2.ZERO) as Vector2
		var facing_direction := (_formal_root.global_basis * Vector3(facing_2d.x, 0.0, facing_2d.y)).normalized()
		slots.append({
			"slot_id": "%s_%s_%02d" % [building_id, service_kind, index + 1],
			"building_id": building_id,
			"service_kind": service_kind,
			"position": snapped_position,
			"requested_position": requested_position,
			"facing_direction": facing_direction,
			"snap_error": snap_error,
			"navigation_sync_pending": navigation_sync_pending,
			"envelope_clearance": 1.25,
		})
	return slots


func get_npc_initial_world_position(npc_id: String) -> Variant:
	if not _npc_initial_anchor_nodes.has(npc_id):
		return null
	var anchor := _npc_initial_anchor_nodes[npc_id] as Node3D
	return anchor.global_position if anchor != null else null


func get_escape_exit_world_position() -> Variant:
	if _formal_root == null or not _production_navigation_map.is_valid():
		return null
	var route := get_formal_escape_route_world()
	var completion: Variant = route.get("completion")
	if not completion is Vector3:
		return null
	return NavigationServer3D.map_get_closest_point(_production_navigation_map, completion)


func get_navigation_path_local(from_position: Vector3, to_position: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if _navigation_grid == null or _navigation_walkable_ids.is_empty():
		return result
	var cell_size := float((_layout.get("navigation", {}) as Dictionary).get("cell_size", 1.0))
	var start_id := _nearest_walkable_cell(Vector2(from_position.x, from_position.z), cell_size)
	var end_id := _nearest_walkable_cell(Vector2(to_position.x, to_position.z), cell_size)
	if not _navigation_grid_region.has_point(start_id) or not _navigation_grid_region.has_point(end_id):
		return result
	var id_path: Array[Vector2i] = _navigation_grid.get_id_path(start_id, end_id)
	var navigation_height := float((_layout.get("navigation", {}) as Dictionary).get("navigation_height", 0.12))
	for cell_id in id_path:
		result.append(Vector3(
			(float(cell_id.x) + 0.5) * cell_size,
			navigation_height,
			(float(cell_id.y) + 0.5) * cell_size
		))
	return result


func get_validation_snapshot() -> Dictionary:
	var migration: Dictionary = _layout.get("migration", {})
	var terrain: Dictionary = _layout.get("terrain", {})
	var station: Dictionary = _layout.get("station", {})
	var camera_config: Dictionary = _layout.get("camera", {})
	var authority_counts := _get_authority_position_counts()
	var building_ids: Array[String] = []
	var building_node_names: Array[String] = []
	for raw_building in _layout.get("buildings", []):
		var building: Dictionary = raw_building
		building_ids.append(str(building.get("id", "")))
		building_node_names.append(str(building.get("node_name", "")))
	return {
		"config_loaded": not _layout.is_empty(),
		"schema_version": str(_layout.get("schema_version", "")),
		"migration_phase": str(migration.get("phase", "")),
		"formal_layout_active": bool(migration.get("formal_layout_active", false)),
		"default_formal_world_enabled": is_default_formal_world_enabled(),
		"legacy_compatibility_override": _legacy_compatibility_override,
		"preview_enabled": _preview_enabled,
		"preview_offset": _v2(migration.get("preview_offset", [0.0, 0.0])),
		"world_origin_mode": str(migration.get("world_origin_mode", "")),
		"formal_root_available": is_instance_valid(_formal_root),
		"formal_root_visible": _formal_root.visible if is_instance_valid(_formal_root) else false,
		"formal_root_position": (
			_formal_root.position if is_instance_valid(_formal_root) else Vector3.ZERO
		),
		"legacy_gameplay_root_unchanged": true,
		"legacy_visuals_hidden": _are_legacy_visuals_hidden(),
		"terrain_size": _v2(terrain.get("size", [0.0, 0.0])),
		"terrain_surface_y": float(terrain.get("ground_surface_y", 0.0)),
		"river_surface_y": float(terrain.get("river_surface_y", 0.0)),
		"natural_collision_schema": str((_layout.get("natural_collision", {}) as Dictionary).get("schema_version", "")),
		"natural_boundary_count": (((_layout.get("natural_collision", {}) as Dictionary).get("barriers", [])) as Array).size(),
		"building_count": building_ids.size(),
		"building_ids": building_ids,
		"building_node_names": building_node_names,
		"road_count": (_layout.get("roads", []) as Array).size(),
		"wall_segment_count": (station.get("wall_segments", []) as Array).size(),
		"gate_count": 2 if station.has("front_gate") and station.has("back_gate") else 0,
		"plaza_patch_count": (
			(station.get("plaza", {}) as Dictionary).get("patches", []) as Array
		).size(),
		"camera_min_distance": float(camera_config.get("min_distance", 0.0)),
		"camera_max_distance": float(camera_config.get("max_distance", 0.0)),
		"camera_initial_focus": _v2(camera_config.get("initial_focus", [0.0, 0.0])),
		"camera_x_limits": _v2(camera_config.get("x_limits", [0.0, 0.0])),
		"camera_z_limits": _v2(camera_config.get("z_limits", [0.0, 0.0])),
		"configuration_error_count": _configuration_errors.size(),
		"configuration_errors": _configuration_errors.duplicate(),
		"generated_mesh_count": (
			_formal_root.find_children("*", "MeshInstance3D", true, false).size()
			if is_instance_valid(_formal_root)
			else 0
		),
		"generated_label_count": (
			_formal_root.find_children("*", "Label3D", true, false).size()
			if is_instance_valid(_formal_root)
			else 0
		),
		"public_location_count": (_layout.get("public_locations", []) as Array).size(),
		"npc_initial_position_count": (_layout.get("npc_initial_positions", []) as Array).size(),
		"building_spatial_count": (_layout.get("building_spatial", {}) as Dictionary).size(),
		"building_workstation_position_count": int(authority_counts.get(AUTHORITY_WORKSTATION, 0)),
		"defense_slot_position_count": int(authority_counts.get(AUTHORITY_DEFENSE_SLOT, 0)),
		"authoritative_position_count": int(authority_counts.get("total", 0)),
		"navigation_region_count": (
			_formal_root.find_children("*", "NavigationRegion3D", true, false).size()
			if is_instance_valid(_formal_root)
			else 0
		),
		"navigation_enabled": _navigation_region.enabled if is_instance_valid(_navigation_region) else false,
		"enemy_approach_navigation_enabled": (
			_enemy_approach_navigation_region.enabled
			if is_instance_valid(_enemy_approach_navigation_region)
			else false
		),
		"enemy_approach_navigation_vertex_count": _enemy_approach_vertex_count,
		"enemy_approach_navigation_polygon_count": _enemy_approach_polygon_count,
		"enemy_route_stage_count": (((_layout.get("combat_spatial", {}) as Dictionary).get("enemy_route", {}) as Dictionary).get("stages", []) as Array).size(),
		"formal_merchant_route_point_count": (((_layout.get("rear_spatial", {}) as Dictionary).get("merchant_route", {}) as Dictionary).get("path_points", []) as Array).size(),
		"formal_merchant_route_world": get_formal_merchant_route_world(),
		"formal_escape_route_point_count": (((_layout.get("rear_spatial", {}) as Dictionary).get("escape_route", {}) as Dictionary).get("path_points", []) as Array).size(),
		"formal_escape_route_world": get_formal_escape_route_world(),
		"navigation_walkable_cell_count": _navigation_walkable_cells.size(),
		"production_navigation": _build_production_navigation_snapshot(),
		"spatial_anchor_count": _spatial_anchor_nodes.size(),
		"physics_navigation_schema": str(_physics_navigation.get("schema_version", "")),
		"fixture_layouts_schema": str(_fixture_layouts.get("schema_version", "")),
		"environment_art_schema": str(_environment_art.get("schema_version", "")),
		"environment_art_revision": str(_environment_art.get("art_revision", "")),
		"building_fixture_count": _get_fixture_count(),
		"fixture_workstation_stand_count": _get_fixture_workstation_stand_count(),
		"fixture_occupant_anchor_count": _get_fixture_occupant_anchor_count(),
		"fixture_horse_anchor_count": _get_fixture_horse_anchor_count(),
		"static_body_count": (
			_formal_root.find_children("*", "StaticBody3D", true, false).size()
			if is_instance_valid(_formal_root)
			else 0
		),
		"static_collision_shape_count": (
			_formal_root.find_children("*", "CollisionShape3D", true, false).size()
			if is_instance_valid(_formal_root)
			else 0
		),
		"building_door_clear_width": float(
			(_physics_navigation.get("structural_collision", {}) as Dictionary).get(
				"building_door_clear_width", 0.0
			)
		)
	}


func _validate_config() -> void:
	_configuration_errors.clear()
	if _layout.is_empty():
		_configuration_errors.append("layout_not_loaded")
		return
	if _physics_navigation.is_empty():
		_configuration_errors.append("physics_navigation_not_loaded")
		return
	if _fixture_layouts.is_empty():
		_configuration_errors.append("fixture_layouts_not_loaded")
		return
	if _environment_art.is_empty():
		_configuration_errors.append("environment_art_not_loaded")
		return
	if str(_layout.get("schema_version", "")) != EXPECTED_SCHEMA:
		_configuration_errors.append("unexpected_schema")
	if str(_physics_navigation.get("schema_version", "")) != EXPECTED_PHYSICS_NAVIGATION_SCHEMA:
		_configuration_errors.append("unexpected_physics_navigation_schema")
	if str(_fixture_layouts.get("schema_version", "")) != EXPECTED_FIXTURE_LAYOUTS_SCHEMA:
		_configuration_errors.append("unexpected_fixture_layouts_schema")
	if str(_environment_art.get("schema_version", "")) != EXPECTED_ENVIRONMENT_ART_SCHEMA:
		_configuration_errors.append("unexpected_environment_art_schema")
	var units: Dictionary = _layout.get("units", {})
	if not is_equal_approx(float(units.get("godot_units_per_meter", 0.0)), 1.0):
		_configuration_errors.append("units_must_be_one_meter")
	var migration: Dictionary = _layout.get("migration", {})
	var migration_phase := str(migration.get("phase", ""))
	if not ["c2_spatial_contract_staged", "a5_p7_default_formal_world"].has(migration_phase):
		_configuration_errors.append("unexpected_migration_phase")
	if migration_phase == "a5_p7_default_formal_world" and not bool(migration.get("formal_layout_active", false)):
		_configuration_errors.append("default_formal_world_must_be_active")
	if (_layout.get("buildings", []) as Array).size() != 12:
		_configuration_errors.append("expected_12_buildings")
	if (_layout.get("roads", []) as Array).size() != 42:
		_configuration_errors.append("expected_42_roads")
	var station: Dictionary = _layout.get("station", {})
	if (station.get("wall_segments", []) as Array).size() != 14:
		_configuration_errors.append("expected_14_wall_segments")
	var ids: Dictionary = {}
	var node_names: Dictionary = {}
	for raw_building in _layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var node_name := str(building.get("node_name", ""))
		if building_id.is_empty() or ids.has(building_id):
			_configuration_errors.append("invalid_or_duplicate_building_id:%s" % building_id)
		if node_name.is_empty() or node_names.has(node_name):
			_configuration_errors.append("invalid_or_duplicate_node_name:%s" % node_name)
		ids[building_id] = true
		node_names[node_name] = true
	var building_spatial: Dictionary = _layout.get("building_spatial", {})
	if building_spatial.size() != 12:
		_configuration_errors.append("expected_12_building_spatial_contracts")
	var all_position_ids: Dictionary = {}
	var workstation_count := 0
	var defense_slot_count := 0
	for raw_building_id in ids.keys():
		var building_id := str(raw_building_id)
		if not building_spatial.has(building_id):
			_configuration_errors.append("missing_building_spatial:%s" % building_id)
			continue
		var contract: Dictionary = building_spatial[building_id]
		var entry_route: Dictionary = contract.get("entry_route", {})
		for route_key in ["entry_outside", "door_outside", "door_inside", "interior", "exit_outside"]:
			if not _is_v2_array(entry_route.get(route_key, null)):
				_configuration_errors.append("invalid_entry_route:%s:%s" % [building_id, route_key])
		for raw_position in contract.get("positions", []):
			if not raw_position is Dictionary:
				_configuration_errors.append("invalid_position:%s" % building_id)
				continue
			var position: Dictionary = raw_position
			var position_id := str(position.get("id", ""))
			if position_id.is_empty() or all_position_ids.has(position_id):
				_configuration_errors.append("invalid_or_duplicate_position:%s" % position_id)
			all_position_ids[position_id] = true
			if not _is_v2_array(position.get("center", null)) or not _is_v2_array(position.get("size", null)):
				_configuration_errors.append("invalid_position_geometry:%s" % position_id)
			else:
				var center := _v2(position.get("center", []))
				var size := _v2(position.get("size", []))
				var building := _find_building_definition(building_id)
				var envelope := _v2(building.get("envelope_size", [0.0, 0.0]))
				if (
					size.x <= 0.0
					or size.y <= 0.0
					or absf(center.x) + size.x * 0.5 > envelope.x * 0.5 + 0.001
					or absf(center.y) + size.y * 0.5 > envelope.y * 0.5 + 0.001
				):
					_configuration_errors.append("position_outside_envelope:%s" % position_id)
			match str(position.get("authority", "")):
				AUTHORITY_WORKSTATION:
					workstation_count += 1
				AUTHORITY_DEFENSE_SLOT:
					defense_slot_count += 1
	if workstation_count != 61:
		_configuration_errors.append("expected_61_building_workstations")
	if defense_slot_count != 4:
		_configuration_errors.append("expected_4_defense_slots")
	if all_position_ids.size() != 65:
		_configuration_errors.append("expected_65_authoritative_positions")
	var npc_initial_positions: Array = _layout.get("npc_initial_positions", [])
	if npc_initial_positions.size() != 8:
		_configuration_errors.append("expected_8_npc_initial_positions")
	var npc_ids: Dictionary = {}
	for raw_initial in npc_initial_positions:
		var initial: Dictionary = raw_initial
		var npc_id := str(initial.get("npc_id", ""))
		if npc_id.is_empty() or npc_ids.has(npc_id) or not _is_v2_array(initial.get("position", null)):
			_configuration_errors.append("invalid_or_duplicate_npc_initial:%s" % npc_id)
		npc_ids[npc_id] = true
	var public_locations: Array = _layout.get("public_locations", [])
	if public_locations.size() != 2:
		_configuration_errors.append("expected_plaza_and_notice_board")
	var public_ids: Dictionary = {}
	for raw_location in public_locations:
		var location: Dictionary = raw_location
		public_ids[str(location.get("id", ""))] = true
	if not public_ids.has("plaza") or not public_ids.has("notice_board"):
		_configuration_errors.append("missing_public_location_id")
	var navigation: Dictionary = _layout.get("navigation", {})
	var grid_bounds: Variant = navigation.get("grid_bounds", [])
	var production_bounds: Variant = navigation.get("production_bounds", [])
	var grid_contract_valid := (
		float(navigation.get("cell_size", 0.0)) > 0.0
		and grid_bounds is Array
		and (grid_bounds as Array).size() >= 4
	)
	if not grid_contract_valid:
		_configuration_errors.append("invalid_navigation_contract")
	if (
		not grid_contract_valid
		or not production_bounds is Array
		or (production_bounds as Array).size() < 4
		or float((production_bounds as Array)[0]) > float((grid_bounds as Array)[0])
		or float((production_bounds as Array)[1]) < float((grid_bounds as Array)[1])
		or float((production_bounds as Array)[2]) > float((grid_bounds as Array)[2])
		or float((production_bounds as Array)[3]) < 344.0
		or str(navigation.get("enemy_exterior_mode", "")) != "shared_open_baked_space"
		or bool(navigation.get("roads_affect_navigation", true))
	):
		_configuration_errors.append("invalid_shared_production_navigation_contract")
	_validate_combat_spatial_config()
	_validate_rear_spatial_config()
	_validate_natural_collision_config()
	_validate_physics_navigation_config()
	_validate_fixture_layouts_config()


func _validate_rear_spatial_config() -> void:
	var rear_spatial := _layout.get("rear_spatial", {}) as Dictionary
	if str(rear_spatial.get("schema_version", "")) != "rear_spatial_v1":
		_configuration_errors.append("unexpected_rear_spatial_schema")
		return
	var merchant_route := rear_spatial.get("merchant_route", {}) as Dictionary
	var path_points := merchant_route.get("path_points", []) as Array
	if path_points.size() != 6:
		_configuration_errors.append("expected_6_merchant_route_points")
		return
	for raw_point in path_points:
		if not _is_v2_array(raw_point):
			_configuration_errors.append("invalid_merchant_route_point")
			return
	if _v2(path_points.front()).distance_to(_v2(merchant_route.get("spawn", []))) > 0.001:
		_configuration_errors.append("merchant_route_spawn_mismatch")
	if _v2(path_points.back()).distance_to(_v2(merchant_route.get("dock", []))) > 0.001:
		_configuration_errors.append("merchant_route_dock_mismatch")
	var dock_clearance := float(merchant_route.get("dock_root_clearance_to_back_gate_m", 0.0))
	var actual_dock_clearance := _v2(merchant_route.get("dock", [])).distance_to(_v2(rear_spatial.get("back_gate", [])))
	if dock_clearance < 6.5 or dock_clearance > 7.5 or absf(actual_dock_clearance - dock_clearance) > 0.05:
		_configuration_errors.append("merchant_route_dock_clearance_mismatch")
	if float(merchant_route.get("corridor_half_width", 0.0)) < 2.2:
		_configuration_errors.append("merchant_route_too_narrow")
	var escape_route := rear_spatial.get("escape_route", {}) as Dictionary
	var escape_points := escape_route.get("path_points", []) as Array
	if escape_points.size() != 6:
		_configuration_errors.append("expected_6_escape_route_points")
		return
	for raw_point in escape_points:
		if not _is_v2_array(raw_point):
			_configuration_errors.append("invalid_escape_route_point")
			return
	if _v2(escape_points.front()).distance_to(_v2(rear_spatial.get("back_gate", []))) > 0.001:
		_configuration_errors.append("escape_route_back_gate_mismatch")
	if _v2(escape_points.back()).distance_to(_v2(escape_route.get("completion", []))) > 0.001:
		_configuration_errors.append("escape_route_completion_mismatch")
	if float(escape_route.get("corridor_half_width", 0.0)) < 2.2:
		_configuration_errors.append("escape_route_too_narrow")


func _build_formal_layout() -> void:
	var world_root := get_node_or_null(world_root_path) as Node3D
	if world_root == null:
		_configuration_errors.append("world_root_missing")
		return
	var old_root := world_root.get_node_or_null(FORMAL_ROOT_NAME)
	if old_root != null:
		old_root.queue_free()
	_building_name_labels.clear()
	_building_name_label_alpha = 1.0
	_camera_idle_seconds = 0.0
	_camera_sample_valid = false
	_formal_root = Node3D.new()
	_formal_root.name = FORMAL_ROOT_NAME
	_formal_root.set_meta("layout_schema", EXPECTED_SCHEMA)
	_formal_root.set_meta("migration_phase", str((_layout.get("migration", {}) as Dictionary).get("phase", "")))
	world_root.add_child(_formal_root)
	var migration: Dictionary = _layout.get("migration", {})
	var offset := _v2(migration.get("preview_offset", [0.0, 0.0]))
	_formal_root.position = Vector3(offset.x, 0.0, offset.y)
	_build_terrain()
	_build_roads_and_plaza()
	_build_environment_art()
	_build_natural_boundaries()
	_build_walls_and_gates()
	_build_building_roots()
	_build_public_props()
	_build_spatial_contract()
	_build_enemy_approach_navigation()
	_build_rear_escape_navigation()
	_formal_root.visible = false


func _build_terrain() -> void:
	var terrain_root := Node3D.new()
	terrain_root.name = "Terrain"
	_formal_root.add_child(terrain_root)
	var terrain: Dictionary = _layout.get("terrain", {})
	var center := _v2(terrain.get("center", [0.0, 0.0]))
	var size := _v2(terrain.get("size", [0.0, 0.0]))
	var surface_y := float(terrain.get("ground_surface_y", 0.0))
	var depth := float(terrain.get("ground_depth", 2.4))
	var river_x := float(terrain.get("river_center_x", -97.0))
	var river_width := float(terrain.get("river_width", 30.0))
	var left_edge := center.x - size.x * 0.5
	var right_edge := center.x + size.x * 0.5
	var river_left := river_x - river_width * 0.5
	var river_right := river_x + river_width * 0.5
	var ground_color := _color(terrain.get("ground_color", "#405842"), Color("#405842"))
	var west_ground := _add_box(
		terrain_root,
		"WestGround",
		Vector3((left_edge + river_left) * 0.5, surface_y - depth * 0.5, center.y),
		Vector3(river_left - left_edge, depth, size.y),
		ground_color
	)
	var east_ground := _add_box(
		terrain_root,
		"EastGround",
		Vector3((river_right + right_edge) * 0.5, surface_y - depth * 0.5, center.y),
		Vector3(right_edge - river_right, depth, size.y),
		ground_color
	)
	var river_surface := _add_box(
		terrain_root,
		"RiverSurface",
		Vector3(river_x, float(terrain.get("river_surface_y", -1.2)), center.y),
		Vector3(river_width, 0.08, size.y),
		_color(terrain.get("river_color", "#2173ab"), Color("#2173ab"))
	)
	var terrain_topology := _environment_art.get("terrain_topology", {}) as Dictionary
	var legacy_visible := bool(terrain_topology.get("legacy_terrain_boxes_visible", true))
	for legacy_visual in [west_ground, east_ground, river_surface]:
		legacy_visual.visible = legacy_visible
		legacy_visual.set_meta("legacy_terrain_visual_suppressed", not legacy_visible)
	terrain_root.set_meta("formal_terrain_topology_active", not legacy_visible)
	_build_navigation_floor_collision(terrain_root, surface_y)


func _build_navigation_floor_collision(parent: Node3D, surface_y: float) -> void:
	var navigation: Dictionary = _layout.get("navigation", {})
	# The contract grid remains station-local, while the production NavMesh also
	# covers the exterior battlefield. Roads are presentation only: the broad
	# floor plus static collision geometry decides where actors may walk.
	var bounds: Array = navigation.get(
		"production_bounds",
		navigation.get("grid_bounds", [-58.0, 58.0, -50.0, 58.0])
	)
	var navigation_mesh: Dictionary = _physics_navigation.get("navigation_mesh", {})
	var depth := float(navigation_mesh.get("baking_floor_depth", 0.2))
	_add_static_box_collision(
		parent,
		"NavigationBakeFloor",
		Vector3(
			(float(bounds[0]) + float(bounds[1])) * 0.5,
			surface_y - depth * 0.5,
			(float(bounds[2]) + float(bounds[3])) * 0.5
		),
		Vector3(float(bounds[1]) - float(bounds[0]), depth, float(bounds[3]) - float(bounds[2])),
		"navigation_floor"
	)


func _build_roads_and_plaza() -> void:
	var roads_root := Node3D.new()
	roads_root.name = "Roads"
	_formal_root.add_child(roads_root)
	var formal_roads := FORMAL_ROAD_NETWORK_ART_VIEW_SCRIPT.new()
	formal_roads.name = "FormalRoadNetworkArt"
	formal_roads.configure(_layout.get("roads", []))
	roads_root.add_child(formal_roads)
	var plaza_root := Node3D.new()
	plaza_root.name = "Plaza"
	plaza_root.set_meta("legacy_patch_visuals_suppressed", true)
	plaza_root.set_meta("authority_geometry_unchanged", true)
	_formal_root.add_child(plaza_root)


func _build_environment_art() -> void:
	var environment_art := FORMAL_ENVIRONMENT_ART_VIEW_SCENE.instantiate() as Node3D
	if environment_art == null:
		_configuration_errors.append("formal_environment_art_scene_failed")
		return
	environment_art.name = "FormalEnvironmentArtView"
	environment_art.call("configure", _environment_art, _layout)
	_formal_root.add_child(environment_art)


func _build_public_props() -> void:
	var props_root := Node3D.new()
	props_root.name = "PublicProps"
	_formal_root.add_child(props_root)
	for raw_location in _layout.get("public_locations", []):
		var location := raw_location as Dictionary
		if str(location.get("id", "")) != "notice_board":
			continue
		var board := NOTICE_BOARD_SCENE.instantiate() as Node3D
		if board == null:
			_configuration_errors.append("formal_notice_board_scene_missing")
			return
		var point := _v2(location.get("position", [0.0, 0.0]))
		board.name = "NoticeBoard"
		board.position = Vector3(point.x, 0.08, point.y)
		board.rotation_degrees.y = float(location.get("facing_degrees", 0.0))
		board.set_meta("layout_id", "notice_board")
		board.set_meta("placement", str(location.get("placement", "main_hall_front_left")))
		board.set_meta("formal_public_prop", true)
		props_root.add_child(board)
	for raw_outbuilding in _layout.get("service_outbuildings", []):
		var outbuilding := raw_outbuilding as Dictionary
		if str(outbuilding.get("kind", "")) != "latrine":
			continue
		var latrine := FORMAL_DORMITORY_LATRINE_ART_VIEW_SCRIPT.new() as Node3D
		if latrine == null:
			_configuration_errors.append("formal_dormitory_latrine_script_missing")
			continue
		latrine.name = str(outbuilding.get("node_name", "DormitoryLatrine")).validate_node_name()
		var point := _v2(outbuilding.get("position", [-47.0, -10.0]))
		latrine.position = Vector3(point.x, 0.0, point.y)
		latrine.rotation_degrees.y = float(outbuilding.get("rotation_degrees", 90.0))
		latrine.call("configure", outbuilding)
		props_root.add_child(latrine)
		var collision_values := outbuilding.get("collision_size", [2.8, 3.2, 2.4]) as Array
		var collision_size := Vector3(
			float(collision_values[0]),
			float(collision_values[1]),
			float(collision_values[2])
		)
		var collision := _add_static_box_collision(
			latrine,
			"StaticCollision",
			Vector3(0.0, collision_size.y * 0.5, 0.0),
			collision_size,
			"service_outbuilding_latrine"
		)
		collision.set_meta("layout_id", str(outbuilding.get("id", "dormitory_latrine")))
		collision.set_meta("navigation_role", "solid_non_enterable_outbuilding")


func _build_natural_boundaries() -> void:
	var config := _layout.get("natural_collision", {}) as Dictionary
	var root := Node3D.new()
	root.name = "NaturalBoundaries"
	root.set_meta("schema_version", str(config.get("schema_version", "")))
	root.set_meta("simplified_compound_boundaries", bool(config.get("simplified_compound_boundaries", false)))
	_formal_root.add_child(root)
	for raw_barrier in config.get("barriers", []):
		var barrier := raw_barrier as Dictionary
		var barrier_id := str(barrier.get("id", "natural_barrier"))
		var kind := str(barrier.get("kind", "dense_forest"))
		var from_point := _v2(barrier.get("from", [0.0, 0.0]))
		var to_point := _v2(barrier.get("to", [0.0, 0.0]))
		var width := float(barrier.get("width", 1.0))
		var height := float(barrier.get("height", 2.0))
		var color := _color(barrier.get("color", "#263f31"), Color("#263f31"))
		var category := "natural_%s" % kind
		var body := _add_static_segment_collision(
			root,
			"%sCollision" % barrier_id.to_pascal_case(),
			from_point,
			to_point,
			width,
			height,
			category
		)
		body.set_meta("natural_barrier_id", barrier_id)
		body.set_meta("natural_kind", kind)
		body.set_meta("corridor", str(barrier.get("corridor", "")))
		body.set_meta("simplified_compound_boundary", true)
		match kind:
			"river_cliff":
				var topology := _environment_art.get("terrain_topology", {}) as Dictionary
				if bool(topology.get("legacy_river_cliff_visuals_visible", true)):
					_add_segment(root, "%sCliffFace" % barrier_id, from_point, to_point, width, height, color, height * 0.5)
					_add_segment(root, "%sRockLip" % barrier_id, from_point, to_point, width * 1.8, 0.35, Color("#777c7f"), height + 0.12)
				else:
					body.set_meta("legacy_river_cliff_visual_suppressed", true)
			"rock_ridge":
				var topology := _environment_art.get("terrain_topology", {}) as Dictionary
				if bool(topology.get("legacy_rock_ridge_visuals_visible", true)):
					_add_segment(root, "%sRidgeMass" % barrier_id, from_point, to_point, width, height * 0.72, color, height * 0.36)
					_add_segment(root, "%sRidgeCrown" % barrier_id, from_point, to_point, width * 0.62, height * 0.45, Color("#697076"), height * 0.82)
				else:
					body.set_meta("legacy_rock_ridge_visual_suppressed", true)
			"dense_forest":
				var topology := _environment_art.get("terrain_topology", {}) as Dictionary
				if bool(topology.get("legacy_dense_forest_understory_visible", true)):
					_add_segment(root, "%sUnderstory" % barrier_id, from_point, to_point, width, 0.65, color, 0.325)
				else:
					body.set_meta("legacy_dense_forest_understory_suppressed", true)
				if bool(topology.get("legacy_dense_forest_tree_visuals_visible", true)):
					_add_dense_forest_visuals(root, barrier_id, from_point, to_point, width, height)
				else:
					body.set_meta("legacy_dense_forest_tree_visuals_suppressed", true)


func _add_dense_forest_visuals(
	parent: Node3D,
	barrier_id: String,
	from_point: Vector2,
	to_point: Vector2,
	width: float,
	height: float
) -> void:
	var delta := to_point - from_point
	var length := delta.length()
	if length <= 0.001:
		return
	var direction := delta / length
	var perpendicular := Vector2(-direction.y, direction.x)
	var tree_count := clampi(int(round(length / 55.0)), 3, 8)
	for index in tree_count:
		var t := (float(index) + 0.5) / float(tree_count)
		var lateral := (-0.24 if index % 2 == 0 else 0.24) * width
		var point := from_point.lerp(to_point, t) + perpendicular * lateral
		var trunk_height := height * (0.62 + float(index % 3) * 0.06)
		_add_cylinder(
			parent,
			"%sTrunk%02d" % [barrier_id, index],
			Vector3(point.x, trunk_height * 0.5, point.y),
			0.42,
			trunk_height,
			Color("#3d3024")
		)
		_add_cylinder(
			parent,
			"%sCanopy%02d" % [barrier_id, index],
			Vector3(point.x, trunk_height + 1.35, point.y),
			1.65 + float(index % 2) * 0.25,
			2.7,
			Color("#294936")
		)


func _build_walls_and_gates() -> void:
	var walls_root := Node3D.new()
	walls_root.name = "WallsAndGates"
	_formal_root.add_child(walls_root)
	var station: Dictionary = _layout.get("station", {})
	var wall_color := _color(station.get("wall_color", "#797b83"), Color("#797b83"))
	for raw_segment in station.get("wall_segments", []):
		var segment: Dictionary = raw_segment
		var legacy_wall_visual := _add_segment(
			walls_root,
			"Wall_%s" % str(segment.get("id", "segment")),
			_v2(segment.get("from", [0.0, 0.0])),
			_v2(segment.get("to", [0.0, 0.0])),
			float(station.get("wall_thickness", 1.2)),
			float(station.get("wall_height", 2.4)),
			wall_color,
			float(station.get("wall_height", 2.4)) * 0.5
		)
		legacy_wall_visual.visible = false
		var wall_collision := _add_static_segment_collision(
			walls_root,
			"WallCollision_%s" % str(segment.get("id", "segment")),
			_v2(segment.get("from", [0.0, 0.0])),
			_v2(segment.get("to", [0.0, 0.0])),
			float(station.get("wall_thickness", 1.2)),
			float(station.get("wall_height", 2.4)),
			"station_wall"
		)
		wall_collision.set_meta("building_id", "wall")
		wall_collision.set_meta("wall_segment_id", str(segment.get("id", "")))
	_build_gate(walls_root, station.get("front_gate", {}))
	_build_gate(walls_root, station.get("back_gate", {}))
	_build_fortification_exterior_art(walls_root, station)


func _build_fortification_exterior_art(parent: Node3D, station: Dictionary) -> void:
	var art_root := FORMAL_FORTIFICATION_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.call("configure", station)
	art_root.name = "FortificationArt"
	parent.add_child(art_root)


func _build_gate(parent: Node3D, gate: Dictionary) -> void:
	var center := _v2(gate.get("center", [0.0, 0.0]))
	var width := float(gate.get("clear_width", 5.0))
	var height := float(gate.get("height", 2.8))
	var root := Node3D.new()
	root.name = str(gate.get("id", "Gate")).to_pascal_case()
	root.position = Vector3(center.x, 0.0, center.y)
	root.rotation_degrees.y = float(gate.get("rotation_degrees", 0.0))
	root.set_meta("layout_id", str(gate.get("id", "")))
	parent.add_child(root)
	var legacy_left_post := _add_box(root, "LeftPost", Vector3(-width * 0.5 - 0.6, height * 0.5, 0.0),
		Vector3(1.2, height, 1.4), Color("#4a3425"))
	var legacy_right_post := _add_box(root, "RightPost", Vector3(width * 0.5 + 0.6, height * 0.5, 0.0),
		Vector3(1.2, height, 1.4), Color("#4a3425"))
	var legacy_lintel := _add_box(root, "Lintel", Vector3(0.0, height, 0.0),
		Vector3(width + 2.4, 0.6, 1.4), Color("#4a3425"))
	legacy_left_post.visible = false
	legacy_right_post.visible = false
	legacy_lintel.visible = false
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	var post_width := float(structural.get("gate_post_width", 1.2))
	var tower_collision := gate.get("tower_collision", {}) as Dictionary
	var tower_size := _v3(tower_collision.get("size", [post_width, height, 1.4]))
	if tower_size.x <= 0.0 or tower_size.y <= 0.0 or tower_size.z <= 0.0:
		tower_size = Vector3(post_width, height, 1.4)
	var tower_center_y := float(tower_collision.get("center_y", tower_size.y * 0.5))
	var tower_center_x := width * 0.5 + tower_size.x * 0.5
	var left_collision := _add_static_box_collision(
		root,
		"LeftPostCollision",
		Vector3(-tower_center_x, tower_center_y, 0.0),
		tower_size,
		"gate_post"
	)
	var right_collision := _add_static_box_collision(
		root,
		"RightPostCollision",
		Vector3(tower_center_x, tower_center_y, 0.0),
		tower_size,
		"gate_post"
	)
	left_collision.set_meta("building_id", str(gate.get("id", "")))
	right_collision.set_meta("building_id", str(gate.get("id", "")))
	left_collision.set_meta("gate_structure_role", "side_tower_body" if not tower_collision.is_empty() else "gate_post")
	right_collision.set_meta("gate_structure_role", "side_tower_body" if not tower_collision.is_empty() else "gate_post")
	_add_label(root, "NameLabel", Vector3(0.0, height + 1.1, 0.0),
		str(gate.get("display_name", "城门")))


func _build_building_roots() -> void:
	_building_roots.clear()
	var buildings_root := Node3D.new()
	buildings_root.name = "BuildingRoots"
	_formal_root.add_child(buildings_root)
	for raw_building in _layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var center := _v2(building.get("center", [0.0, 0.0]))
		var envelope := _v2(building.get("envelope_size", [1.0, 1.0]))
		var lot := _v2(building.get("lot_size", envelope))
		var height := float(building.get("height", 1.0))
		var root := Node3D.new()
		root.name = str(building.get("node_name", building.get("id", "Building")))
		root.position = Vector3(center.x, 0.0, center.y)
		root.rotation_degrees.y = float(building.get("rotation_degrees", 0.0))
		root.set_meta("building_id", building_id)
		root.set_meta("orientation", str(building.get("orientation", "")))
		root.set_meta("migration_phase", str((_layout.get("migration", {}) as Dictionary).get("phase", "")))
		buildings_root.add_child(root)
		_building_roots[building_id] = root
		# Reserved lots are planning envelopes, not finished ground art.  Keep the
		# auditable size without rendering the dark rectangular greybox beneath
		# every completed building.
		var reserved_lot := Node3D.new()
		reserved_lot.name = "ReservedLot"
		reserved_lot.set_meta("lot_size", lot)
		reserved_lot.set_meta("planning_metadata_only", true)
		root.add_child(reserved_lot)
		var envelope_color := _color(building.get("color", "#697078"), Color("#697078"))
		if not _get_building_fixture_config(building_id).is_empty():
			envelope_color.a = 0.14
		var envelope_visual := _add_box(
			root,
			"Envelope",
			Vector3(0.0, height * 0.5, 0.0),
			Vector3(envelope.x, height, envelope.y),
			envelope_color
		)
		if building_id == "main_hall":
			envelope_visual.visible = false
			_build_main_hall_exterior_art(root, building)
		elif building_id == "warehouse":
			envelope_visual.visible = false
			_build_warehouse_exterior_art(root, building)
		elif building_id == "blacksmith":
			envelope_visual.visible = false
		elif building_id in ["workshop", "chapel", "clinic", "dining_hall", "dormitory", "tavern", "garden", "training_ground", "stable"]:
			envelope_visual.visible = false
		var label_y := 11.2 if building_id == "main_hall" else (7.2 if building_id == "chapel" else (6.4 if building_id in ["warehouse", "blacksmith", "workshop", "clinic", "dining_hall", "dormitory", "tavern"] else (4.2 if building_id in ["garden", "training_ground", "stable"] else height + 1.0)))
		_add_label(
			root,
			"NameLabel",
			Vector3(0.0, label_y, 0.0),
			str(building.get("display_name", "建筑"))
		)
		_build_building_static_collision(root, building)
		_build_building_fixtures(root, building)
		if building_id == "blacksmith":
			_build_blacksmith_exterior_art(root)
		elif building_id == "workshop":
			_build_workshop_exterior_art(root)
		elif building_id == "chapel":
			_build_chapel_exterior_art(root)
		elif building_id == "clinic":
			_build_clinic_exterior_art(root)
		elif building_id == "dining_hall":
			_build_dining_hall_exterior_art(root)
		elif building_id == "dormitory":
			_build_dormitory_exterior_art(root)
		elif building_id == "tavern":
			_build_tavern_exterior_art(root)
		elif building_id == "garden":
			_build_garden_exterior_art(root)
		elif building_id == "training_ground":
			_build_training_ground_exterior_art(root)
		elif building_id == "stable":
			_build_stable_exterior_art(root)


func _build_blacksmith_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_BLACKSMITH_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "BlacksmithArt"
	building_root.add_child(art_root)


func _build_workshop_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_WORKSHOP_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "WorkshopArt"
	building_root.add_child(art_root)


func _build_chapel_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_CHAPEL_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "ChapelArt"
	building_root.add_child(art_root)


func _build_clinic_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_CLINIC_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "ClinicArt"
	building_root.add_child(art_root)


func _build_dining_hall_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_DINING_HALL_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "DiningHallArt"
	building_root.add_child(art_root)


func _build_dormitory_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_DORMITORY_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "DormitoryArt"
	building_root.add_child(art_root)


func _build_tavern_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_TAVERN_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "TavernArt"
	building_root.add_child(art_root)


func _build_garden_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_GARDEN_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "GardenArt"
	building_root.add_child(art_root)


func _build_training_ground_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_TRAINING_GROUND_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "TrainingGroundArt"
	building_root.add_child(art_root)


func _build_stable_exterior_art(building_root: Node3D) -> void:
	var art_root := FORMAL_STABLE_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "StableArt"
	building_root.add_child(art_root)


func _build_main_hall_exterior_art(building_root: Node3D, _building: Dictionary) -> void:
	var art_root := FORMAL_MAIN_HALL_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "MainHallArt"
	building_root.add_child(art_root)


func _build_warehouse_exterior_art(building_root: Node3D, _building: Dictionary) -> void:
	var art_root := FORMAL_WAREHOUSE_ART_VIEW_SCRIPT.new() as BuildingArtView
	if art_root == null:
		return
	art_root.name = "WarehouseArt"
	building_root.add_child(art_root)


func _build_building_static_collision(building_root: Node3D, building: Dictionary) -> void:
	var envelope := _v2(building.get("envelope_size", [1.0, 1.0]))
	var building_id := str(building.get("id", ""))
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	var thickness := float(structural.get("wall_thickness", 0.4))
	var door_width := float(structural.get("building_door_clear_width", 1.4))
	var wall_height := maxf(
		float(building.get("height", 1.0)),
		float(structural.get("minimum_wall_height", 1.2))
	)
	var collision_root := Node3D.new()
	collision_root.name = "StaticCollision"
	collision_root.set_meta("building_id", str(building.get("id", "")))
	collision_root.set_meta("door_clear_width", door_width)
	collision_root.set_meta("fully_open_front", false)
	collision_root.set_meta("transparent_perimeter", building_id == "blacksmith")
	building_root.add_child(collision_root)
	var side_depth := maxf(0.1, envelope.y - thickness * 2.0)
	var side_center_z := 0.0
	var front_segment_width := maxf(0.1, (envelope.x - door_width) * 0.5)
	var front_center_offset := door_width * 0.5 + front_segment_width * 0.5
	var left_wall := _add_static_box_collision(
		collision_root,
		"LeftWall",
		Vector3(-envelope.x * 0.5 + thickness * 0.5, wall_height * 0.5, side_center_z),
		Vector3(thickness, wall_height, side_depth),
		"building_wall"
	)
	left_wall.set_meta("building_segment_id", "left_wall")
	var right_wall := _add_static_box_collision(
		collision_root,
		"RightWall",
		Vector3(envelope.x * 0.5 - thickness * 0.5, wall_height * 0.5, side_center_z),
		Vector3(thickness, wall_height, side_depth),
		"building_wall"
	)
	right_wall.set_meta("building_segment_id", "right_wall")
	var back_wall := _add_static_box_collision(
		collision_root,
		"BackWall",
		Vector3(0.0, wall_height * 0.5, -envelope.y * 0.5 + thickness * 0.5),
		Vector3(envelope.x, wall_height, thickness),
		"building_wall"
	)
	back_wall.set_meta("building_segment_id", "back_wall")
	var front_left := _add_static_box_collision(
		collision_root,
		"FrontLeft",
		Vector3(-front_center_offset, wall_height * 0.5, envelope.y * 0.5 - thickness * 0.5),
		Vector3(front_segment_width, wall_height, thickness),
		"building_wall"
	)
	front_left.set_meta("building_segment_id", "front_left")
	var front_right := _add_static_box_collision(
		collision_root,
		"FrontRight",
		Vector3(front_center_offset, wall_height * 0.5, envelope.y * 0.5 - thickness * 0.5),
		Vector3(front_segment_width, wall_height, thickness),
		"building_wall"
	)
	front_right.set_meta("building_segment_id", "front_right")
	var blocker_config := building.get("solid_interior_blocker", {}) as Dictionary
	if bool(blocker_config.get("enabled", false)):
		var maximum_inset := maxf(0.0, minf(envelope.x, envelope.y) * 0.5 - 0.1)
		var inset := clampf(float(blocker_config.get("inset", thickness * 0.5)), 0.0, maximum_inset)
		var blocker_size := Vector3(
			maxf(0.1, envelope.x - inset * 2.0),
			wall_height,
			maxf(0.1, envelope.y - inset * 2.0)
		)
		var interior_blocker := _add_static_box_collision(
			collision_root,
			"InteriorBlocker",
			Vector3(0.0, wall_height * 0.5, 0.0),
			blocker_size,
			"building_interior_blocker"
		)
		interior_blocker.set_meta("building_id", building_id)
		interior_blocker.set_meta("transparent_entity", true)
		interior_blocker.set_meta("blocks_navigation", true)


func _build_building_fixtures(building_root: Node3D, building: Dictionary) -> void:
	var building_id := str(building.get("id", ""))
	var fixture_config := _get_building_fixture_config(building_id)
	if fixture_config.is_empty():
		return
	var fixture_root := Node3D.new()
	fixture_root.name = "FixtureLayout"
	fixture_root.set_meta("schema_version", EXPECTED_FIXTURE_LAYOUTS_SCHEMA)
	fixture_root.set_meta("building_id", building_id)
	fixture_root.set_meta("maximum_level_collision_staging", true)
	building_root.add_child(fixture_root)
	var visuals_root := Node3D.new()
	visuals_root.name = "Visuals"
	fixture_root.add_child(visuals_root)
	var collision_root := Node3D.new()
	collision_root.name = "StaticCollision"
	fixture_root.add_child(collision_root)
	var stands_root := Node3D.new()
	stands_root.name = "NPCStands"
	fixture_root.add_child(stands_root)
	var occupant_anchors_root := Node3D.new()
	occupant_anchors_root.name = "OccupantAnchors"
	fixture_root.add_child(occupant_anchors_root)
	var horse_anchors_root := Node3D.new()
	horse_anchors_root.name = "HorseAnchors"
	fixture_root.add_child(horse_anchors_root)
	for raw_fixture in fixture_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var center := _v2(fixture.get("center", [0.0, 0.0]))
		var rotation_degrees := float(fixture.get("rotation_degrees", 0.0))
		var asset_path := str(fixture.get("asset_path", ""))
		if str(fixture.get("kind", "")) == "dining_table":
			_build_dining_table_fixture_visual(visuals_root, building_id, fixture)
		elif not asset_path.is_empty():
			var packed_scene := load(asset_path) as PackedScene
			if packed_scene != null:
				var visual := packed_scene.instantiate() as Node3D
				if visual != null:
					visual.name = fixture_id.to_pascal_case()
					visual.position = Vector3(center.x, float(fixture.get("visual_y", 0.0)), center.y)
					visual.rotation_degrees.y = rotation_degrees
					visual.scale = _v3(fixture.get("visual_scale", [1.0, 1.0, 1.0]))
					_set_fixture_metadata(visual, building_id, fixture)
					visuals_root.add_child(visual)
					_decorate_fixture_visual(visual, fixture)
		elif not str(fixture.get("primitive_visual", "")).is_empty():
			_build_primitive_fixture_visual(visuals_root, building_id, fixture)
		_build_fixture_collisions(collision_root, building_id, fixture)
		var npc_stand := fixture.get("npc_stand", {}) as Dictionary
		if not npc_stand.is_empty():
			_build_fixture_stand_marker(stands_root, building_id, fixture, npc_stand)
		var occupant_anchor := fixture.get("occupant_anchor", {}) as Dictionary
		if not occupant_anchor.is_empty():
			_build_fixture_occupant_anchor_marker(
				occupant_anchors_root,
				building_id,
				fixture,
				occupant_anchor
			)
		var horse_anchor := fixture.get("horse_anchor", {}) as Dictionary
		if not horse_anchor.is_empty():
			_build_fixture_horse_anchor_marker(
				horse_anchors_root,
				building_id,
				fixture,
				horse_anchor
			)


func _decorate_fixture_visual(visual: Node3D, fixture: Dictionary) -> void:
	match str(fixture.get("kind", "")):
		"anvil":
			_decorate_blacksmith_anvil(visual, fixture)
		"clinic_exam_table":
			_add_box(visual, "MedicalCloth", Vector3(0.0, 0.83, 0.0), Vector3(2.25, 0.035, 0.72), Color("#86a9a3"))
			_add_box(visual, "MedicineBottle", Vector3(0.72, 0.98, -0.12), Vector3(0.16, 0.28, 0.16), Color("#7c2638"))
			_add_box(visual, "BandageRoll", Vector3(-0.64, 0.91, 0.02), Vector3(0.34, 0.14, 0.14), Color("#d6d0bd"))
		"dining_cauldron_hearth":
			_add_box(visual, "StoneBase", Vector3(0.0, -0.04, 0.0), Vector3(1.42, 0.28, 1.2), Color("#55565d"))
			_add_box(visual, "CoalBed", Vector3(0.0, 0.08, 0.0), Vector3(0.82, 0.08, 0.72), Color("#191a1d"))
			var ember := _add_box(visual, "Ember", Vector3(0.0, 0.135, 0.0), Vector3(0.56, 0.045, 0.48), Color("#d9512a"))
			ember.visible = false
			ember.set_meta("dining_work_heat", true)
			ember.set_meta("workstation_id", str(fixture.get("workstation_id", "")))
		"tavern_fermentation_cask":
			_add_box(visual, "FermentationSeal", Vector3(0.0, 1.19, 0.0), Vector3(0.18, 0.28, 0.18), Color("#5b3826"))
			_add_box(visual, "Spigot", Vector3(0.0, 0.55, 0.43), Vector3(0.12, 0.12, 0.34), Color("#7d5635"))
			_add_box(visual, "CatchTray", Vector3(0.0, 0.12, 0.52), Vector3(0.58, 0.08, 0.34), Color("#50402f"))
		"tavern_empty_barrel_rack":
			_add_tavern_empty_barrels(visual, str(fixture.get("asset_path", "")))
		"tavern_mug_table":
			_add_tavern_mugs(visual)
		"garden_tool_rack":
			_add_garden_tools(visual)
		"training_weapon_rack":
			_add_training_rack_equipment(visual)
		"chapel_prayer_pew":
			_decorate_chapel_pew(visual, fixture)
		"workshop_engineering_bench", "workshop_tool_wall", "workshop_hoist", "workshop_measurement_table", "workshop_material_rack":
			_decorate_workshop_fixture_visual(visual, fixture)
		"main_hall_device_platform", "main_hall_wall_brace", "main_hall_roof_brace", "main_hall_tower_reinforcement":
			_decorate_main_hall_fixture_visual(visual, fixture)
		"warehouse_shelf", "warehouse_crate_stack", "warehouse_loading_pallet", "warehouse_high_rack", "warehouse_tall_storage":
			_decorate_warehouse_fixture_visual(visual, fixture)


func _decorate_blacksmith_anvil(visual: Node3D, fixture: Dictionary) -> void:
	# Imported anvil meshes contain only the iron head. A compact stump and stone
	# footing now carry it all the way to the floor instead of leaving it floating.
	_add_box(visual, "StoneFoot", Vector3(0.0, -0.285, 0.0), Vector3(0.94, 0.07, 0.82), Color("#4b4d52"))
	_add_cylinder(visual, "AnvilStump", Vector3(0.0, -0.14, 0.0), 0.42, 0.28, Color("#49372c"))
	_add_box(visual, "IronBinding", Vector3(0.0, -0.08, 0.0), Vector3(0.86, 0.08, 0.78), Color("#30343a"))
	var hot_metal := _add_box(visual, "HotMetal", Vector3(0.0, 0.59, 0.0), Vector3(0.58, 0.06, 0.10), Color("#e4682c"))
	hot_metal.visible = false
	hot_metal.set_meta("smithy_work_heat", true)
	hot_metal.set_meta("workstation_id", str(fixture.get("workstation_id", "")))


func _build_dining_table_fixture_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var center := _v2(fixture.get("center", [0.0, 0.0]))
	var table := Node3D.new()
	table.name = str(fixture.get("id", "DiningTable")).to_pascal_case()
	table.position = Vector3(center.x, 0.0, center.y)
	table.rotation_degrees.y = float(fixture.get("rotation_degrees", 0.0))
	_set_fixture_metadata(table, building_id, fixture)
	parent.add_child(table)
	var oak := Color("#725039")
	var oak_dark := Color("#463126")
	var iron := Color("#34383a")
	var linen := Color("#b9a47d")
	_add_box(table, "ThickOakTableTop", Vector3(0.0, 0.79, 0.0), Vector3(4.05, 0.18, 1.02), oak)
	_add_box(table, "TableApronFront", Vector3(0.0, 0.64, 0.43), Vector3(3.72, 0.18, 0.12), oak_dark)
	_add_box(table, "TableApronRear", Vector3(0.0, 0.64, -0.43), Vector3(3.72, 0.18, 0.12), oak_dark)
	for x in [-1.67, 1.67]:
		for z in [-0.34, 0.34]:
			_add_box(table, "TrestleLeg", Vector3(x, 0.4, z), Vector3(0.22, 0.72, 0.22), oak_dark)
		_add_box(table, "TrestleFoot", Vector3(x, 0.12, 0.0), Vector3(0.34, 0.16, 0.96), oak_dark)
	_add_box(table, "LongUnderBrace", Vector3(0.0, 0.33, 0.0), Vector3(3.42, 0.13, 0.13), oak_dark)
	for x in [-1.25, 0.0, 1.25]:
		_add_cylinder(table, "WoodenBowl", Vector3(x, 0.93, -0.12 if x == 0.0 else 0.1), 0.18, 0.1, linen)
		_add_sphere(table, "BreadLoaf", Vector3(x + 0.28, 0.96, 0.1 if x == 0.0 else -0.12), 0.13, Color("#a66c38"))
	for x in [-1.86, 1.86]:
		_add_cylinder(table, "IronCornerPin", Vector3(x, 0.9, 0.0), 0.035, 0.08, iron)


func _decorate_warehouse_fixture_visual(visual: Node3D, fixture: Dictionary) -> void:
	var fixture_id := str(fixture.get("id", ""))
	var kind := str(fixture.get("kind", ""))
	visual.set_meta("cargo_categories", fixture.get("cargo_categories", []))
	visual.set_meta("inventory_count_authority", false)
	match kind:
		"warehouse_shelf":
			for index in range(2):
				var z := -1.62 if index == 0 else 1.62
				_add_scene_prop(visual, "ShelfModule%02d" % (index + 2), WAREHOUSE_SHELF_ASSET, Vector3(0.0, 0.0, z), Vector3.ONE)
			if fixture_id.contains("west"):
				_add_scene_prop(visual, "FoodAppleBarrel", WAREHOUSE_APPLE_BARREL_ASSET, Vector3(0.0, 0.02, -0.86), Vector3.ONE * 0.72)
				_add_scene_prop(visual, "FoodSack", WAREHOUSE_BAG_ASSET, Vector3(0.0, 0.04, 0.82), Vector3.ONE * 0.84, Vector3(0.0, 18.0, 0.0))
			else:
				_add_scene_prop(visual, "IronCrate", WAREHOUSE_METAL_CRATE_ASSET, Vector3(0.0, 0.03, -0.82), Vector3.ONE * 0.72)
				_add_scene_prop(visual, "StoneCrate", WORKSHOP_CRATE_ASSET, Vector3(0.0, 0.03, 0.84), Vector3.ONE * 0.7, Vector3(0.0, -12.0, 0.0))
		"warehouse_crate_stack":
			for index in range(2):
				var x := -0.82 if index == 0 else 0.82
				var asset: String = WAREHOUSE_BAG_ASSET if fixture_id.contains("west") else WAREHOUSE_METAL_CRATE_ASSET
				_add_scene_prop(visual, "CargoStack%02d" % (index + 2), asset, Vector3(x, 0.03, 0.0), Vector3.ONE * (0.92 if fixture_id.contains("west") else 0.78), Vector3(0.0, float(index * 24 - 12), 0.0))
			if fixture_id.contains("west"):
				_add_scene_prop(visual, "FoodReserve", WAREHOUSE_APPLE_BARREL_ASSET, Vector3(0.0, 0.58, 0.0), Vector3.ONE * 0.62)
			else:
				_add_scene_prop(visual, "IronReserve", WORKSHOP_CRATE_ASSET, Vector3(0.0, 0.58, 0.0), Vector3.ONE * 0.62)
		"warehouse_loading_pallet":
			_add_scene_prop(visual, "LoadingSack", WAREHOUSE_BAG_ASSET, Vector3(-0.42, 1.0, -0.35), Vector3.ONE * 0.72, Vector3(0.0, -18.0, 0.0))
			_add_scene_prop(visual, "LoadingCrate", WORKSHOP_CRATE_ASSET, Vector3(0.42, 0.92, 0.15), Vector3.ONE * 0.58, Vector3(0.0, 12.0, 0.0))
		"warehouse_high_rack":
			_add_scene_prop(visual, "RearShelfModule", WAREHOUSE_SHELF_ASSET, Vector3(0.0, 0.0, 0.76), Vector3.ONE * 0.92, Vector3(0.0, 180.0, 0.0))
			_add_scene_prop(visual, "EquipmentChest", WAREHOUSE_CHEST_ASSET, Vector3(0.0, 0.04, -0.62), Vector3.ONE * 0.65)
			_add_scene_prop(visual, "HighFoodReserve", WAREHOUSE_BAG_ASSET, Vector3(0.0, 1.02, 0.35), Vector3.ONE * 0.68, Vector3(0.0, 20.0, 0.0))
		"warehouse_tall_storage":
			_add_scene_prop(visual, "UpperShelfModule", WAREHOUSE_SHELF_ASSET, Vector3(0.0, 1.36, 0.0), Vector3.ONE * 0.88)
			_add_scene_prop(visual, "SecuredChest", WAREHOUSE_CHEST_ASSET, Vector3(0.0, 0.02, 0.0), Vector3.ONE * 0.62)
			_add_scene_prop(visual, "EquipmentStand", "res://assets/3d/quaternius/props/weapon_stand.glb", Vector3(0.0, 1.32, 0.14), Vector3.ONE * 0.54, Vector3(0.0, 180.0, 0.0))


func _decorate_chapel_pew(visual: Node3D, fixture: Dictionary) -> void:
	var dark_wood := Color("#3f2d23")
	var warm_wood := Color("#674833")
	var prayer_cloth := Color("#4e4a66")
	var inner_x := 0.85 if str(fixture.get("pew_side", "left")) == "left" else -0.85
	_add_box(visual, "BackRail", Vector3(0.0, 0.76, 0.25), Vector3(2.68, 0.14, 0.14), dark_wood)
	_add_box(visual, "LeftBackPost", Vector3(-1.27, 0.54, 0.25), Vector3(0.13, 0.58, 0.14), dark_wood)
	_add_box(visual, "RightBackPost", Vector3(1.27, 0.54, 0.25), Vector3(0.13, 0.58, 0.14), dark_wood)
	_add_box(visual, "KneelingRail", Vector3(0.0, 0.20, -0.42), Vector3(2.55, 0.13, 0.16), warm_wood)
	_add_box(visual, "SeatMarkerCushion", Vector3(inner_x, 0.675, -0.02), Vector3(0.68, 0.05, 0.38), prayer_cloth)
	_add_box(visual, "PrayerBookRest", Vector3(inner_x, 0.69, 0.25), Vector3(0.52, 0.07, 0.16), warm_wood)
	_add_scene_prop(
		visual,
		"PrayerBook",
		CHAPEL_BOOK_ASSET,
		Vector3(inner_x, 0.745, 0.23),
		Vector3.ONE * 0.72,
		Vector3(-8.0, 0.0, 0.0)
	)


func _add_scene_prop(
	parent: Node3D,
	node_name: String,
	asset_path: String,
	position: Vector3,
	scale: Vector3 = Vector3.ONE,
	rotation_degrees: Vector3 = Vector3.ZERO
) -> Node3D:
	var packed_scene := load(asset_path) as PackedScene
	if packed_scene == null:
		return null
	var prop := packed_scene.instantiate() as Node3D
	if prop == null:
		return null
	prop.name = node_name
	prop.position = position
	prop.scale = scale
	prop.rotation_degrees = rotation_degrees
	parent.add_child(prop)
	return prop


func _tint_imported_scene(root_node: Node3D, tint: Color) -> void:
	if root_node == null:
		return
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw_mesh as MeshInstance3D)
	for mesh_instance in meshes:
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			var source_color := material.albedo_color
			material.albedo_color = Color(
				source_color.r * tint.r,
				source_color.g * tint.g,
				source_color.b * tint.b,
				source_color.a
			)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material.resource_local_to_scene = true
			mesh_instance.set_surface_override_material(surface_index, material)


func _add_tavern_empty_barrels(visual: Node3D, asset_path: String) -> void:
	var barrel_scene := load(asset_path) as PackedScene
	if barrel_scene == null:
		return
	var transforms := [
		{"position": Vector3(-0.47, 0.0, 0.28), "rotation": 12.0},
		{"position": Vector3(0.47, 0.0, 0.28), "rotation": -12.0}
	]
	for index in range(transforms.size()):
		var barrel := barrel_scene.instantiate() as Node3D
		if barrel == null:
			continue
		var item: Dictionary = transforms[index]
		barrel.name = "EmptyBarrel%02d" % (index + 2)
		barrel.position = item.get("position", Vector3.ZERO)
		barrel.rotation_degrees.y = float(item.get("rotation", 0.0))
		barrel.scale = Vector3.ONE * 0.9
		visual.add_child(barrel)
	_add_box(visual, "BarrelRackBase", Vector3(0.0, 0.08, 0.22), Vector3(1.72, 0.16, 1.22), Color("#443528"))


func _add_tavern_mugs(visual: Node3D) -> void:
	var mug_scene := load(TAVERN_MUG_ASSET) as PackedScene
	if mug_scene == null:
		return
	var positions := [
		Vector3(-0.72, 0.88, -0.08),
		Vector3(0.0, 0.88, 0.12),
		Vector3(0.68, 0.88, -0.12)
	]
	for index in range(positions.size()):
		var mug := mug_scene.instantiate() as Node3D
		if mug == null:
			continue
		mug.name = "TastingMug%02d" % (index + 1)
		mug.position = positions[index]
		mug.rotation_degrees.y = float(index * 35 - 25)
		mug.scale = Vector3.ONE * 1.15
		visual.add_child(mug)


func _build_primitive_fixture_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	match str(fixture.get("primitive_visual", "")):
		"hearth":
			_build_hearth_fixture_visual(parent, building_id, fixture)
		"garden_bed":
			_build_garden_bed_visual(parent, building_id, fixture)
		"garden_irrigation_channel":
			_build_garden_irrigation_visual(parent, building_id, fixture)
		"garden_compost_bin":
			_build_garden_compost_visual(parent, building_id, fixture)
		"garden_wheelbarrow":
			_build_garden_wheelbarrow_visual(parent, building_id, fixture)
		"garden_fence":
			_build_garden_fence_visual(parent, building_id, fixture)
		"training_command_post":
			_build_training_command_post_visual(parent, building_id, fixture)
		"training_archery_target":
			_build_training_archery_target_visual(parent, building_id, fixture)
		"training_sandbag_stack":
			_build_training_sandbag_visual(parent, building_id, fixture)
		"training_boundary_fence":
			_build_training_boundary_fence_visual(parent, building_id, fixture)
		"stable_open_bay":
			_build_stable_open_bay_visual(parent, building_id, fixture)
		"stable_feed_rack":
			_build_stable_feed_rack_visual(parent, building_id, fixture)
		"chapel_altar", "chapel_prayer_kneeler", "chapel_bell_rack", "chapel_stained_window", "chapel_buttress", "chapel_roof_truss":
			_build_chapel_fixture_visual(parent, building_id, fixture)
		"main_hall_device_platform", "main_hall_wall_brace", "main_hall_roof_brace", "main_hall_tower_reinforcement":
			_build_main_hall_fixture_visual(parent, building_id, fixture)
		"warehouse_shelf", "warehouse_crate_stack", "warehouse_loading_pallet", "warehouse_high_rack", "warehouse_tall_storage":
			_build_warehouse_fixture_visual(parent, building_id, fixture)


func _create_fixture_visual_root(parent: Node3D, building_id: String, fixture: Dictionary) -> Node3D:
	var center := _v2(fixture.get("center", [0.0, 0.0]))
	var visual := Node3D.new()
	visual.name = str(fixture.get("id", "Fixture")).to_pascal_case()
	visual.position = Vector3(center.x, float(fixture.get("visual_y", 0.0)), center.y)
	visual.rotation_degrees.y = float(fixture.get("rotation_degrees", 0.0))
	_set_fixture_metadata(visual, building_id, fixture)
	parent.add_child(visual)
	return visual


func _build_garden_bed_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var collision_size := _v3(fixture.get("collision_size", [3.0, 0.28, 3.0]))
	var border_thickness := float(fixture.get("border_thickness", 0.18))
	_add_box(
		visual,
		"CultivatedSoil",
		Vector3(0.0, 0.11, 0.0),
		Vector3(collision_size.x - 0.28, 0.22, collision_size.z - 0.28),
		Color("#4b3526")
	)
	_add_box(
		visual,
		"MoistTopsoil",
		Vector3(0.0, 0.235, -0.08),
		Vector3(collision_size.x - 0.48, 0.07, collision_size.z - 0.58),
		Color("#30251d")
	)
	var half_x := collision_size.x * 0.5
	var half_z := collision_size.z * 0.5
	var rail_color := Color("#66503a")
	_add_box(visual, "LeftEdging", Vector3(-half_x + border_thickness * 0.5, 0.18, 0.0), Vector3(border_thickness, 0.36, collision_size.z), rail_color)
	_add_box(visual, "RightEdging", Vector3(half_x - border_thickness * 0.5, 0.18, 0.0), Vector3(border_thickness, 0.36, collision_size.z), rail_color)
	_add_box(visual, "RearEdging", Vector3(0.0, 0.18, -half_z + border_thickness * 0.5), Vector3(collision_size.x - border_thickness * 2.0, 0.36, border_thickness), rail_color)
	var carrot_scene := load(GARDEN_CARROT_ASSET) as PackedScene
	if carrot_scene == null:
		return
	var crop_index := 0
	for local_z in [-0.82, -0.08, 0.66]:
		for local_x in [-0.82, 0.0, 0.82]:
			var carrot := carrot_scene.instantiate() as Node3D
			if carrot == null:
				continue
			crop_index += 1
			carrot.name = "Crop%02d" % crop_index
			carrot.position = Vector3(local_x, 0.26, local_z)
			carrot.rotation_degrees.y = float(crop_index * 37 % 360)
			carrot.scale = Vector3.ONE * 1.35
			visual.add_child(carrot)


func _build_garden_irrigation_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var size := _v3(fixture.get("collision_size", [0.5, 0.18, 3.5]))
	_add_box(visual, "StoneBed", Vector3(0.0, 0.05, 0.0), Vector3(size.x, 0.1, size.z), Color("#5b5b55"))
	_add_box(visual, "Water", Vector3(0.0, 0.115, 0.0), Vector3(size.x - 0.14, 0.03, size.z - 0.12), Color(0.16, 0.38, 0.48, 0.82))
	_add_box(visual, "LeftLip", Vector3(-size.x * 0.5, 0.16, 0.0), Vector3(0.12, 0.22, size.z), Color("#777063"))
	_add_box(visual, "RightLip", Vector3(size.x * 0.5, 0.16, 0.0), Vector3(0.12, 0.22, size.z), Color("#777063"))


func _build_garden_compost_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var wood := Color("#58432f")
	for x in [-0.58, 0.58]:
		_add_box(visual, "PostX%sA" % x, Vector3(x, 0.5, -0.58), Vector3(0.16, 1.0, 0.16), wood)
		_add_box(visual, "PostX%sB" % x, Vector3(x, 0.5, 0.58), Vector3(0.16, 1.0, 0.16), wood)
	for y in [0.2, 0.48, 0.76]:
		_add_box(visual, "RearSlat%s" % y, Vector3(0.0, y, -0.58), Vector3(1.24, 0.14, 0.12), wood)
		_add_box(visual, "LeftSlat%s" % y, Vector3(-0.58, y, 0.0), Vector3(0.12, 0.14, 1.24), wood)
		_add_box(visual, "RightSlat%s" % y, Vector3(0.58, y, 0.0), Vector3(0.12, 0.14, 1.24), wood)
	_add_box(visual, "Compost", Vector3(0.0, 0.42, 0.02), Vector3(0.96, 0.55, 0.98), Color("#3c3021"))
	_add_box(visual, "GreenCuttings", Vector3(0.0, 0.71, 0.02), Vector3(0.8, 0.08, 0.78), Color("#455f35"))


func _build_garden_wheelbarrow_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var wood := Color("#72533a")
	_add_box(visual, "Tray", Vector3(0.0, 0.55, -0.1), Vector3(1.05, 0.38, 1.15), wood)
	_add_box(visual, "SoilLoad", Vector3(0.0, 0.77, -0.08), Vector3(0.82, 0.12, 0.82), Color("#3f3023"))
	for x in [-0.38, 0.38]:
		var handle := _add_box(visual, "Handle%s" % x, Vector3(x, 0.43, 0.68), Vector3(0.12, 0.12, 1.35), Color("#5a422e"))
		handle.rotation_degrees.x = -8.0
	_add_box(visual, "Support", Vector3(0.0, 0.25, 0.35), Vector3(0.82, 0.12, 0.12), Color("#42352b"))
	var wheel := _add_cylinder(visual, "Wheel", Vector3(0.0, 0.28, -0.76), 0.32, 0.18, Color("#292b2d"))
	wheel.rotation_degrees.z = 90.0


func _build_garden_fence_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var wood := Color("#66503a")
	for x in [-1.48, 0.0, 1.48]:
		_add_box(visual, "Post%s" % x, Vector3(x, 0.52, 0.0), Vector3(0.18, 1.04, 0.18), wood)
	for y in [0.3, 0.68]:
		_add_box(visual, "Rail%s" % y, Vector3(0.0, y, 0.0), Vector3(3.1, 0.16, 0.14), Color("#74583e"))


func _add_garden_tools(visual: Node3D) -> void:
	var handle_color := Color("#73543a")
	var metal_color := Color("#6e7375")
	for index in range(3):
		var x := float(index - 1) * 0.38
		var handle := _add_box(visual, "ToolHandle%02d" % (index + 1), Vector3(x, 0.82, 0.08), Vector3(0.09, 1.35, 0.09), handle_color)
		handle.rotation_degrees.z = float(index - 1) * 5.0
		_add_box(visual, "ToolHead%02d" % (index + 1), Vector3(x, 0.16, 0.08), Vector3(0.34 if index < 2 else 0.18, 0.12, 0.2), metal_color)


func _build_training_command_post_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	_add_box(visual, "Post", Vector3(0.0, 1.0, 0.0), Vector3(0.18, 2.0, 0.18), Color("#66503a"))
	_add_box(visual, "Crossbar", Vector3(0.28, 1.72, 0.0), Vector3(0.72, 0.12, 0.12), Color("#74583e"))
	_add_box(visual, "CommandFlag", Vector3(0.48, 1.48, 0.0), Vector3(0.62, 0.4, 0.06), Color("#653442"))
	_add_box(visual, "Base", Vector3(0.0, 0.08, 0.0), Vector3(0.52, 0.16, 0.52), Color("#4b4035"))


func _build_training_archery_target_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var wood := Color("#634a34")
	_add_box(visual, "LeftLeg", Vector3(-0.42, 0.58, 0.0), Vector3(0.16, 1.16, 0.16), wood)
	_add_box(visual, "RightLeg", Vector3(0.42, 0.58, 0.0), Vector3(0.16, 1.16, 0.16), wood)
	_add_box(visual, "Crossbar", Vector3(0.0, 1.12, 0.0), Vector3(1.0, 0.14, 0.14), wood)
	var outer := _add_cylinder(visual, "TargetOuter", Vector3(0.0, 1.35, 0.0), 0.68, 0.18, Color("#d3c395"))
	outer.rotation_degrees.x = 90.0
	var middle := _add_cylinder(visual, "TargetMiddle", Vector3(0.0, 1.35, -0.105), 0.43, 0.04, Color("#8b3d3d"))
	middle.rotation_degrees.x = 90.0
	var bullseye := _add_cylinder(visual, "Bullseye", Vector3(0.0, 1.35, -0.13), 0.16, 0.03, Color("#d1aa45"))
	bullseye.rotation_degrees.x = 90.0


func _build_training_sandbag_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var sand := Color("#8b7654")
	for index in range(3):
		_add_box(visual, "LowerBag%02d" % (index + 1), Vector3(float(index - 1) * 0.5, 0.22, 0.0), Vector3(0.58, 0.38, 0.9), sand)
	for index in range(2):
		_add_box(visual, "UpperBag%02d" % (index + 1), Vector3(float(index) * 0.5 - 0.25, 0.55, 0.0), Vector3(0.58, 0.34, 0.82), Color("#9a835d"))


func _build_training_boundary_fence_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var wood := Color("#5f4934")
	for x in [-2.0, 0.0, 2.0]:
		_add_box(visual, "Post%s" % x, Vector3(x, 0.55, 0.0), Vector3(0.2, 1.1, 0.2), wood)
	for y in [0.32, 0.72]:
		_add_box(visual, "Rail%s" % y, Vector3(0.0, y, 0.0), Vector3(4.1, 0.16, 0.14), Color("#71563c"))


func _add_training_rack_equipment(visual: Node3D) -> void:
	for index in range(2):
		var x := float(index) * 0.34 - 0.17
		var angle := -12.0 + float(index) * 24.0
		var blade := _add_box(visual, "PracticeSword%02d" % (index + 1), Vector3(x, 0.82, 0.12), Vector3(0.1, 1.05, 0.08), Color("#777a78"))
		blade.rotation_degrees.z = angle
		var grip := _add_box(visual, "PracticeSwordGrip%02d" % (index + 1), Vector3(x, 0.27, 0.12), Vector3(0.13, 0.32, 0.11), Color("#5e432e"))
		grip.rotation_degrees.z = angle
	var shield := _add_cylinder(visual, "PracticeShield", Vector3(0.0, 0.68, -0.2), 0.42, 0.12, Color("#76563a"))
	shield.rotation_degrees.x = 90.0
	var boss := _add_cylinder(visual, "PracticeShieldBoss", Vector3(0.0, 0.68, -0.275), 0.13, 0.05, Color("#6f7270"))
	boss.rotation_degrees.x = 90.0


func _build_stable_open_bay_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var size := _v3(fixture.get("collision_size", [4.8, 1.15, 3.0]))
	var thickness := float(fixture.get("border_thickness", 0.18))
	var opening_side := str(fixture.get("opening_side", "right"))
	var outer_sign := -1.0 if opening_side == "right" else 1.0
	var wood_dark := Color("#4a3829")
	var wood_mid := Color("#6b4f35")
	var iron := Color("#52575b")
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var outer_x := outer_sign * (half_x - thickness * 0.5)
	for z in [-half_z + 0.08, 0.0, half_z - 0.08]:
		_add_box(visual, "OuterPost%s" % z, Vector3(outer_x, 0.62, z), Vector3(0.22, 1.24, 0.22), wood_dark)
	for y in [0.34, 0.82]:
		_add_box(visual, "OuterRail%s" % y, Vector3(outer_x, y, 0.0), Vector3(0.16, 0.16, size.z - 0.18), wood_mid)
	var divider_z := -half_z + thickness * 0.5
	for x in [-half_x + 0.08, 0.0, half_x - 0.08]:
		_add_box(visual, "DividerPost%s" % x, Vector3(x, 0.62, divider_z), Vector3(0.22, 1.24, 0.22), wood_dark)
	for y in [0.34, 0.82]:
		_add_box(visual, "DividerRail%s" % y, Vector3(0.0, y, divider_z), Vector3(size.x, 0.16, 0.16), wood_mid)
	if bool(fixture.get("close_far_end", false)):
		var far_z := half_z - thickness * 0.5
		for x in [-half_x + 0.08, 0.0, half_x - 0.08]:
			_add_box(visual, "FarPost%s" % x, Vector3(x, 0.62, far_z), Vector3(0.22, 1.24, 0.22), wood_dark)
		for y in [0.34, 0.82]:
			_add_box(visual, "FarRail%s" % y, Vector3(0.0, y, far_z), Vector3(size.x, 0.16, 0.16), wood_mid)
	var trough_x := outer_sign * 1.55
	_add_box(visual, "TroughBase", Vector3(trough_x, 0.18, 0.0), Vector3(1.0, 0.24, 1.9), wood_dark)
	for local_x in [-0.43, 0.43]:
		_add_box(visual, "TroughSide%s" % local_x, Vector3(trough_x + local_x, 0.46, 0.0), Vector3(0.14, 0.56, 1.9), wood_mid)
	for local_z in [-0.86, 0.86]:
		_add_box(visual, "TroughEnd%s" % local_z, Vector3(trough_x, 0.46, local_z), Vector3(0.86, 0.56, 0.14), wood_mid)
	_add_box(visual, "Feed", Vector3(trough_x, 0.38, 0.0), Vector3(0.66, 0.18, 1.55), Color("#9a7c45"))
	_add_box(visual, "TroughBand", Vector3(trough_x, 0.7, 0.0), Vector3(1.04, 0.08, 1.94), iron)


func _build_stable_feed_rack_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var wood := Color("#58422e")
	for x in [-0.98, 0.98]:
		_add_box(visual, "RackPost%s" % x, Vector3(x, 0.85, 0.0), Vector3(0.18, 1.7, 0.18), wood)
	for y in [0.2, 0.62, 1.12]:
		_add_box(visual, "RackShelf%s" % y, Vector3(0.0, y, 0.0), Vector3(2.15, 0.14, 0.58), Color("#6b5036"))
	for index in range(3):
		_add_box(visual, "HayBale%02d" % (index + 1), Vector3(float(index - 1) * 0.62, 0.42, 0.0), Vector3(0.56, 0.42, 0.48), Color("#a98749"))
	var bucket_scene := load(STABLE_BUCKET_ASSET) as PackedScene
	if bucket_scene != null:
		var bucket := bucket_scene.instantiate() as Node3D
		if bucket != null:
			bucket.name = "QuaterniusFeedBucket"
			bucket.position = Vector3(0.72, 0.68, -0.06)
			bucket.scale = Vector3.ONE * 0.9
		visual.add_child(bucket)


func _build_chapel_fixture_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var primitive := str(fixture.get("primitive_visual", ""))
	var size := _v3(fixture.get("collision_size", [1.0, 1.0, 1.0]))
	var stone := Color("#716f75")
	var pale_stone := Color("#9b9688")
	var dark_wood := Color("#4b3325")
	var prayer_cloth := Color("#56506f")
	match primitive:
		"chapel_altar":
			_add_box(visual, "AisleRunner", Vector3(0.0, 0.025, 5.0), Vector3(1.28, 0.05, 10.0), Color("#45475d"))
			_add_box(visual, "AisleRunnerLeftEdge", Vector3(-0.61, 0.055, 5.0), Vector3(0.06, 0.02, 10.0), Color("#8a744c"))
			_add_box(visual, "AisleRunnerRightEdge", Vector3(0.61, 0.055, 5.0), Vector3(0.06, 0.02, 10.0), Color("#8a744c"))
			_add_box(visual, "LowerDais", Vector3(0.0, 0.10, 0.02), Vector3(size.x, 0.20, size.z), stone)
			_add_box(visual, "UpperDais", Vector3(0.0, 0.24, -0.06), Vector3(size.x * 0.86, 0.16, size.z * 0.84), pale_stone)
			_add_box(visual, "AltarBody", Vector3(0.0, 0.57, -0.08), Vector3(size.x * 0.66, 0.62, size.z * 0.64), Color("#7f7b73"))
			for panel_x in [-0.58, 0.0, 0.58]:
				_add_box(visual, "CarvedFrontPanel%s" % panel_x, Vector3(panel_x, 0.58, 0.245), Vector3(0.42, 0.40, 0.045), Color("#5f5e62"))
			_add_box(visual, "AltarSlab", Vector3(0.0, 0.94, -0.08), Vector3(size.x * 0.76, 0.18, size.z * 0.78), pale_stone)
			_add_box(visual, "CrossStem", Vector3(0.0, 1.67, -0.33), Vector3(0.16, 1.25, 0.16), Color("#aa864c"))
			_add_box(visual, "CrossArm", Vector3(0.0, 1.83, -0.33), Vector3(0.76, 0.15, 0.16), Color("#aa864c"))
			_add_box(visual, "AltarCloth", Vector3(0.0, 0.76, 0.285), Vector3(size.x * 0.48, 0.52, 0.07), prayer_cloth)
			_add_scene_prop(visual, "LeftCandlestick", CHAPEL_CANDLESTICK_ASSET, Vector3(-0.68, 1.04, -0.06), Vector3.ONE * 0.72)
			_add_scene_prop(visual, "RightCandlestick", CHAPEL_CANDLESTICK_ASSET, Vector3(0.68, 1.04, -0.06), Vector3.ONE * 0.72)
			_add_scene_prop(visual, "Chalice", CHAPEL_CHALICE_ASSET, Vector3(0.0, 1.04, 0.02), Vector3.ONE * 0.9)
			_add_scene_prop(visual, "Lectern", CHAPEL_BOOK_STAND_ASSET, Vector3(-1.12, 0.30, 0.02), Vector3.ONE * 0.68, Vector3(0.0, -8.0, 0.0))
			_add_scene_prop(visual, "LecternBook", CHAPEL_BOOK_ASSET, Vector3(-1.12, 1.28, 0.0), Vector3.ONE * 0.86, Vector3(-20.0, -8.0, 0.0))
		"chapel_prayer_kneeler":
			_add_box(visual, "WoodenKneeler", Vector3(0.0, 0.20, 0.0), Vector3(size.x, 0.40, size.z), dark_wood)
			_add_box(visual, "PrayerCushion", Vector3(0.0, 0.46, -0.03), Vector3(size.x * 0.82, 0.16, size.z * 0.78), prayer_cloth)
			_add_box(visual, "BookRest", Vector3(0.0, 0.72, -0.24), Vector3(size.x, 0.12, 0.16), Color("#7b5736"))
		"chapel_bell_rack":
			_add_box(visual, "LeftBellPost", Vector3(-0.23, size.y * 0.48, 0.0), Vector3(0.18, size.y * 0.96, 0.24), dark_wood)
			_add_box(visual, "RightBellPost", Vector3(0.23, size.y * 0.48, 0.0), Vector3(0.18, size.y * 0.96, 0.24), dark_wood)
			_add_box(visual, "BellBeam", Vector3(0.0, size.y - 0.18, 0.0), Vector3(size.x, 0.24, 0.42), dark_wood)
			_add_cylinder(visual, "Bell", Vector3(0.0, size.y - 0.65, 0.0), 0.25, 0.48, Color("#a77b35"))
		"chapel_stained_window":
			var frame_thickness := 0.16
			_add_box(visual, "LeftWindowFrame", Vector3(-size.x * 0.5 + frame_thickness * 0.5, 0.0, 0.0), Vector3(frame_thickness, size.y, size.z), dark_wood)
			_add_box(visual, "RightWindowFrame", Vector3(size.x * 0.5 - frame_thickness * 0.5, 0.0, 0.0), Vector3(frame_thickness, size.y, size.z), dark_wood)
			_add_box(visual, "TopWindowFrame", Vector3(0.0, size.y * 0.5 - frame_thickness * 0.5, 0.0), Vector3(size.x, frame_thickness, size.z), dark_wood)
			_add_box(visual, "BottomWindowFrame", Vector3(0.0, -size.y * 0.5 + frame_thickness * 0.5, 0.0), Vector3(size.x, frame_thickness, size.z), dark_wood)
			_add_box(visual, "BluePane", Vector3(-0.72, 0.0, size.z * 0.12), Vector3(1.25, size.y - 0.32, 0.06), Color(0.25, 0.42, 0.58, 0.78))
			_add_box(visual, "WinePane", Vector3(0.72, 0.0, size.z * 0.12), Vector3(1.25, size.y - 0.32, 0.06), Color(0.48, 0.24, 0.34, 0.78))
			_add_box(visual, "WindowMullion", Vector3.ZERO, Vector3(0.14, size.y, size.z * 1.2), pale_stone)
		"chapel_buttress":
			_add_box(visual, "ButtressLower", Vector3(0.0, size.y * 0.25, 0.0), Vector3(size.x, size.y * 0.5, size.z), stone)
			_add_box(visual, "ButtressUpper", Vector3(0.0, size.y * 0.68, 0.0), Vector3(size.x * 0.8, size.y * 0.36, size.z * 0.7), pale_stone)
		"chapel_roof_truss":
			_add_box(visual, "RoofTieBeam", Vector3(0.0, 0.0, 0.0), Vector3(size.x, 0.16, 0.18), dark_wood)
			var left_brace := _add_box(visual, "LeftBrace", Vector3(-1.35, 0.30, 0.0), Vector3(2.2, 0.14, 0.14), dark_wood)
			left_brace.rotation_degrees.z = -18.0
			var right_brace := _add_box(visual, "RightBrace", Vector3(1.35, 0.30, 0.0), Vector3(2.2, 0.14, 0.14), dark_wood)
			right_brace.rotation_degrees.z = 18.0


func _decorate_workshop_fixture_visual(visual: Node3D, fixture: Dictionary) -> void:
	var primitive := str(fixture.get("kind", ""))
	var size := _v3(fixture.get("collision_size", [1.0, 1.0, 1.0]))
	var wood := Color("#67452d")
	var dark_wood := Color("#402f26")
	var iron := Color("#555d66")
	var brass := Color("#a47b3c")
	match primitive:
		"workshop_engineering_bench":
			var scale := _v3(fixture.get("visual_scale", [1.12, 1.0, 1.0]))
			_add_box(visual, "Vise", Vector3(-size.x * 0.28, size.y + 0.08, -size.z * 0.2), Vector3(0.42, 0.32, 0.32), iron)
			var role := str(fixture.get("workshop_role", "bowyer"))
			match role:
				"bowyer":
					var left_stave := _add_box(visual, "BowStaveLeft", Vector3(-0.38, 0.99, 0.08), Vector3(0.92, 0.08, 0.12), Color("#9a7042"))
					left_stave.rotation_degrees.y = -7.0
					var right_stave := _add_box(visual, "BowStaveRight", Vector3(0.38, 0.99, 0.08), Vector3(0.92, 0.08, 0.12), Color("#9a7042"))
					right_stave.rotation_degrees.y = 7.0
					_add_scene_prop(visual, "BowstringCoil", WORKSHOP_ROPE_ASSET, Vector3(0.73, 0.96, -0.18), Vector3.ONE * 0.62)
				"mechanism":
					_add_box(visual, "PartsTray", Vector3(0.18, 0.96, 0.05), Vector3(0.96, 0.06, 0.58), Color("#4b5158"))
					for index in range(3):
						var gear := _add_cylinder(visual, "MechanismGear%02d" % (index + 1), Vector3(-0.18 + index * 0.28, 1.02, 0.08), 0.16 - index * 0.02, 0.06, brass)
						gear.rotation_degrees.x = 90.0
				"siege_assembly":
					_add_box(visual, "BallistaStock", Vector3(0.0, 1.02, 0.0), Vector3(1.45, 0.13, 0.18), dark_wood)
					var left_arm := _add_box(visual, "BallistaLeftArm", Vector3(-0.57, 1.06, 0.0), Vector3(0.88, 0.11, 0.16), wood)
					left_arm.rotation_degrees.y = -28.0
					var right_arm := _add_box(visual, "BallistaRightArm", Vector3(0.57, 1.06, 0.0), Vector3(0.88, 0.11, 0.16), wood)
					right_arm.rotation_degrees.y = 28.0
					var winch := _add_cylinder(visual, "BallistaWinch", Vector3(0.0, 1.04, 0.26), 0.18, 0.5, iron)
					winch.rotation_degrees.z = 90.0
		"workshop_tool_wall":
			for x in [-1.48, 1.48]:
				_add_box(visual, "ToolWallPost%s" % x, Vector3(x, 0.9, 0.0), Vector3(0.16, 1.8, 0.18), dark_wood)
			for index in range(2):
				_add_scene_prop(visual, "QuaterniusShelf%02d" % (index + 1), str(fixture.get("asset_path", WORKSHOP_SHELF_ASSET)), Vector3(0.0, 0.6 + index * 0.78, 0.0), Vector3(2.25, 1.15, 1.15))
			for index in range(5):
				var tool := _add_box(visual, "HangingTool%02d" % (index + 1), Vector3(-1.0 + index * 0.5, 0.72 + (index % 2) * 0.48, 0.18), Vector3(0.09, 0.5, 0.08), iron)
				tool.rotation_degrees.z = -12.0 + index * 6.0
		"workshop_hoist":
			_add_box(visual, "HoistPostLeft", Vector3(-0.55, size.y * 0.5, 0.0), Vector3(0.22, size.y, 0.22), dark_wood)
			_add_box(visual, "HoistPostRight", Vector3(0.55, size.y * 0.5, 0.0), Vector3(0.22, size.y, 0.22), dark_wood)
			_add_box(visual, "HoistBeam", Vector3(0.0, size.y - 0.12, 0.0), Vector3(size.x, 0.24, 0.28), dark_wood)
			var pulley := _add_cylinder(visual, "Pulley", Vector3(0.0, size.y - 0.42, 0.0), 0.32, 0.16, iron)
			pulley.rotation_degrees.x = 90.0
			_add_box(visual, "HookChain", Vector3(0.0, size.y * 0.52, 0.0), Vector3(0.06, size.y * 0.72, 0.06), iron)
			_add_scene_prop(visual, "QuaterniusRopeCoil", str(fixture.get("asset_path", WORKSHOP_ROPE_ASSET)), Vector3(0.42, 0.18, 0.34), Vector3.ONE * 0.9)
			_add_box(visual, "LoadHook", Vector3(0.0, 0.48, 0.0), Vector3(0.28, 0.08, 0.12), iron)
		"workshop_measurement_table":
			var board := _add_box(visual, "DraftingBoard", Vector3(-0.1, 0.98, 0.0), Vector3(1.62, 0.06, 0.78), wood)
			board.rotation_degrees.x = -8.0
			var plan := _add_box(visual, "PlanSheet", Vector3(-0.1, 1.025, 0.02), Vector3(1.36, 0.025, 0.62), Color("#c5b991"))
			plan.rotation_degrees.x = -8.0
			_add_box(visual, "MeasuringRule", Vector3(0.22, 1.06, 0.03), Vector3(0.78, 0.035, 0.06), brass).rotation_degrees.y = 22.0
		"workshop_material_rack":
			for x in [-1.28, 1.28]:
				_add_box(visual, "RackPost%s" % x, Vector3(x, 0.8, 0.0), Vector3(0.16, 1.6, 0.18), dark_wood)
			for index in range(2):
				_add_scene_prop(visual, "QuaterniusMaterialShelf%02d" % (index + 1), str(fixture.get("asset_path", WORKSHOP_SHELF_ASSET)), Vector3(0.0, 0.58 + index * 0.58, 0.0), Vector3(2.2, 1.1, 1.35))
			_add_scene_prop(visual, "MaterialCrateLeft", WORKSHOP_CRATE_ASSET, Vector3(-0.72, 0.34, 0.05), Vector3.ONE * 0.48, Vector3(0.0, -8.0, 0.0))
			_add_scene_prop(visual, "MaterialCrateRight", WORKSHOP_CRATE_ASSET, Vector3(0.72, 0.34, 0.05), Vector3.ONE * 0.48, Vector3(0.0, 10.0, 0.0))
			for index in 4:
				var rod := _add_cylinder(visual, "MaterialRod%02d" % index, Vector3(-0.9 + index * 0.6, 1.12, 0.28), 0.06, 1.05, iron)
				rod.rotation_degrees.z = 90.0


func _decorate_main_hall_fixture_visual(visual: Node3D, fixture: Dictionary) -> void:
	var kind := str(fixture.get("kind", ""))
	if kind == "main_hall_device_platform" and str(fixture.get("asset_path", "")).ends_with("FormalMainHallDefensePlatformArtView.tscn"):
		# The formal scene owns the complete textured timber platform. Adding the
		# legacy stone frame here would cover it and recreate the rejected grey slab.
		return
	var stone := Color("#5b626d")
	var pale_stone := Color("#8c9197")
	var iron := Color("#363d47")
	var command_red := Color("#6e3540")
	match kind:
		"main_hall_device_platform":
			_add_box(visual, "PlatformFrame", Vector3(0.0, 0.16, 0.0), Vector3(2.0, 0.28, 2.0), stone)
			_add_box(visual, "RearParapet", Vector3(0.0, 0.62, -0.89), Vector3(1.96, 0.72, 0.18), pale_stone)
			_add_box(visual, "LeftParapet", Vector3(-0.89, 0.62, 0.0), Vector3(0.18, 0.72, 1.96), pale_stone)
			_add_box(visual, "RightParapet", Vector3(0.89, 0.62, 0.0), Vector3(0.18, 0.72, 1.96), pale_stone)
			_add_box(visual, "FrontLeftMerlon", Vector3(-0.64, 0.62, 0.89), Vector3(0.42, 0.72, 0.18), pale_stone)
			_add_box(visual, "FrontRightMerlon", Vector3(0.64, 0.62, 0.89), Vector3(0.42, 0.72, 0.18), pale_stone)
			_add_cylinder(visual, "DeviceMount", Vector3(0.0, 0.66, 0.0), 0.34, 0.44, iron)
			for index in range(4):
				var corner: Vector3 = [Vector3(-0.7, -0.08, -0.62), Vector3(0.7, -0.08, -0.62), Vector3(-0.7, -0.08, 0.62), Vector3(0.7, -0.08, 0.62)][index]
				_add_scene_prop(visual, "PlatformSupport%02d" % (index + 1), MAIN_HALL_SUPPORT_ASSET, corner, Vector3(0.72, 0.58, 0.48), Vector3(0.0, 90.0 if index % 2 == 0 else -90.0, 0.0))
		"main_hall_wall_brace":
			_add_box(visual, "ReinforcementCourse", Vector3(0.0, 0.55, 0.0), Vector3(6.0, 1.1, 0.34), stone)
			for index in range(4):
				var x := -2.4 + float(index) * 1.6
				_add_scene_prop(visual, "QuaterniusButtress%02d" % (index + 1), MAIN_HALL_SUPPORT_ASSET, Vector3(x, 0.0, 0.18), Vector3(1.05, 0.82, 0.62), Vector3(0.0, 90.0, -8.0 if x < 0.0 else 8.0))
		"main_hall_roof_brace":
			_add_box(visual, "RoofBraceCore", Vector3(0.0, 0.48, 0.0), Vector3(1.62, 0.86, 1.62), stone)
			for angle in [45.0, 135.0, 225.0, 315.0]:
				_add_scene_prop(visual, "RoofSupport%03d" % int(angle), MAIN_HALL_SUPPORT_ASSET, Vector3.ZERO, Vector3(0.72, 0.64, 0.58), Vector3(0.0, angle, 0.0))
			_add_cylinder(visual, "SignalMast", Vector3(0.0, 1.55, 0.0), 0.09, 2.4, iron)
			_add_cylinder(visual, "SignalBrazier", Vector3(0.0, 2.58, 0.0), 0.36, 0.28, command_red)
		"main_hall_tower_reinforcement":
			var imported_tower_roof := visual.get_node_or_null("Roof_Tower_RoundTiles") as Node3D
			if imported_tower_roof != null:
				# Fixture roots scale both the imported asset and added masonry. Raise the
				# native roof above the scaled tower body instead of leaving it buried inside.
				imported_tower_roof.position.y = 4.6
			_add_box(visual, "TowerMasonry", Vector3(0.0, 1.82, 0.0), Vector3(4.45, 4.4, 3.5), stone)
			_add_box(visual, "TowerArrowSlit", Vector3(0.0, 1.86, 1.82), Vector3(0.24, 0.72, 0.12), iron)
			_add_scene_prop(visual, "TowerBanner", MAIN_HALL_BANNER_ASSET, Vector3(-1.2, 3.6, 1.82), Vector3.ONE * 0.52, Vector3(0.0, 180.0, 0.0))


func _build_main_hall_fixture_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var primitive := str(fixture.get("primitive_visual", ""))
	var size := _v3(fixture.get("collision_size", [1.0, 1.0, 1.0]))
	var stone := Color("#676b72")
	var pale_stone := Color("#85868a")
	var iron := Color("#3f4650")
	var dark_wood := Color("#382e2b")
	var plaster := Color("#887d6c")
	var roof_tint := Color("#43556a")
	match primitive:
		"main_hall_device_platform":
			_add_box(visual, "PlatformSlab", Vector3(0.0, size.y * 0.5, 0.0), size, stone)
			_add_box(visual, "RearParapet", Vector3(0.0, 0.72, -size.z * 0.46), Vector3(size.x, 0.65, 0.24), pale_stone)
			_add_box(visual, "LeftParapet", Vector3(-size.x * 0.46, 0.72, 0.0), Vector3(0.24, 0.65, size.z), pale_stone)
			_add_box(visual, "RightParapet", Vector3(size.x * 0.46, 0.72, 0.0), Vector3(0.24, 0.65, size.z), pale_stone)
			_add_cylinder(visual, "DeviceMount", Vector3(0.0, 0.72, 0.0), 0.48, 0.42, iron)
		"main_hall_wall_brace":
			_add_box(visual, "BraceWall", Vector3(0.0, size.y * 0.5, 0.0), size, stone)
			for x in [-2.4, -0.8, 0.8, 2.4]:
				var brace := _add_box(visual, "Brace%s" % str(x), Vector3(x, size.y * 0.52, 0.22), Vector3(0.25, size.y * 1.1, 0.35), iron)
				brace.rotation_degrees.z = -12.0 if x < 0.0 else 12.0
		"main_hall_roof_brace":
			# Lv.4 communicates a better-equipped command post with one restrained
			# garrison pennant. Fire effects were rejected because their compact roof
			# silhouette read as a modern warning beacon from the isometric camera.
			var black_iron := iron.darkened(0.20)
			var flag_red := Color("#6e3540")
			var old_gold := Color("#aa884d")
			_add_box(visual, "RidgeMasonrySaddle", Vector3(0.0, 0.11, 0.0), Vector3(1.12, 0.22, 0.84), stone.darkened(0.08))
			_add_box(visual, "RidgeMasonryCap", Vector3(0.0, 0.27, 0.0), Vector3(0.94, 0.12, 0.72), pale_stone.darkened(0.12))
			_add_box(visual, "PennantIronFoot", Vector3(0.0, 0.39, 0.0), Vector3(0.34, 0.28, 0.34), black_iron)
			_add_box(visual, "PennantIronStrapEastWest", Vector3(0.0, 0.30, 0.0), Vector3(1.02, 0.07, 0.14), black_iron)
			_add_box(visual, "PennantIronStrapNorthSouth", Vector3(0.0, 0.30, 0.0), Vector3(0.14, 0.07, 0.76), black_iron)
			_add_cylinder(visual, "GarrisonPennantMast", Vector3(0.0, 1.08, 0.0), 0.055, 1.55, dark_wood)
			var finial := _add_sphere(visual, "GarrisonPennantFinial", Vector3(0.0, 1.88, 0.0), 0.09, old_gold.darkened(0.08))
			finial.scale = Vector3(0.72, 1.22, 0.72)
			_add_swallowtail_flag(visual, "GarrisonSwallowtailPennant", Vector3(0.045, 1.52, 0.0), Vector2(1.18, 0.68), flag_red)
			for face in [-1.0, 1.0]:
				var face_name := "Rear" if face < 0.0 else "Front"
				_add_box(visual, "PennantGoldVerticalMark%s" % face_name, Vector3(0.39, 1.52, face * 0.032), Vector3(0.075, 0.42, 0.025), old_gold)
				_add_box(visual, "PennantGoldHorizontalMark%s" % face_name, Vector3(0.39, 1.52, face * 0.032), Vector3(0.34, 0.075, 0.025), old_gold)
			for tie_y in [1.25, 1.78]:
				_add_cylinder(visual, "PennantRopeTie%s" % str(tie_y), Vector3(0.02, tie_y, 0.0), 0.073, 0.045, Color("#8d7b5b"))
			visual.set_meta("architectural_role", "ridge_mounted_garrison_pennant")
		"main_hall_tower_reinforcement":
			_add_box(visual, "CommandTowerSolidCore", Vector3(0.0, 1.16, 0.0), Vector3(4.4, 2.32, 3.0), plaster)
			for x in [-1.05, 1.05]:
				_add_scene_prop(visual, "CommandTowerFrontWall%s" % str(x), MAIN_HALL_WALL_WINDOW_ASSET, Vector3(x, 0.0, 1.53), Vector3(1.05, 0.72, 1.0), Vector3(0.0, 180.0, 0.0))
				_add_scene_prop(visual, "CommandTowerRearWall%s" % str(x), MAIN_HALL_WALL_WINDOW_ASSET, Vector3(x, 0.0, -1.53), Vector3(1.05, 0.72, 1.0))
			for side in [-1.0, 1.0]:
				_add_scene_prop(visual, "CommandTowerSideWall%s" % str(side), MAIN_HALL_WALL_WINDOW_ASSET, Vector3(side * 2.23, 0.0, 0.0), Vector3(1.5, 0.72, 1.0), Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0))
				for z in [-1.34, 1.34]:
					_add_box(visual, "CommandTowerCornerPost", Vector3(side * 2.08, 1.18, z), Vector3(0.18, 2.36, 0.18), dark_wood)
			_add_box(visual, "CommandTowerTimberBelt", Vector3(0.0, 2.08, 1.58), Vector3(4.34, 0.18, 0.16), dark_wood)
			var tower_roof := _add_scene_prop(visual, "CommandTowerRoof", MAIN_HALL_ROOF_ASSET, Vector3(0.0, 2.28, 0.0), Vector3(0.52, 0.20, 0.28))
			_tint_imported_scene(tower_roof, roof_tint)
			_add_scene_prop(visual, "CommandTowerBanner", MAIN_HALL_BANNER_ASSET, Vector3(-1.42, 1.15, 1.68), Vector3.ONE * 0.46, Vector3(0.0, 180.0, 0.0))
			visual.set_meta("architectural_role", "integrated_gatehouse_command_tower")


func _build_warehouse_fixture_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var visual := _create_fixture_visual_root(parent, building_id, fixture)
	var primitive := str(fixture.get("primitive_visual", ""))
	var size := _v3(fixture.get("collision_size", [1.0, 1.0, 1.0]))
	var wood := Color("#65462f")
	var dark_wood := Color("#443126")
	var sack := Color("#8c8065")
	match primitive:
		"warehouse_shelf", "warehouse_high_rack", "warehouse_tall_storage":
			_add_box(visual, "ShelfBack", Vector3(0.0, size.y * 0.5, 0.0), size, dark_wood)
			var shelf_count := 4 if primitive != "warehouse_shelf" else 3
			for index in shelf_count:
				var shelf_y := (float(index) + 0.5) * size.y / float(shelf_count)
				_add_box(visual, "Shelf%02d" % index, Vector3(0.0, shelf_y, size.z * 0.52), Vector3(size.x, 0.12, size.z * 1.1), wood)
				_add_box(visual, "Cargo%02d" % index, Vector3((0.24 if index % 2 == 0 else -0.24) * size.x, shelf_y + 0.16, size.z * 0.62), Vector3(size.x * 0.34, 0.28, size.z * 0.42), sack)
		"warehouse_crate_stack":
			for index in 4:
				var crate_x := (-0.28 if index % 2 == 0 else 0.28) * size.x
				var crate_y := 0.35 + float(index / 2) * 0.65
				_add_box(visual, "Crate%02d" % index, Vector3(crate_x, crate_y, 0.0), Vector3(size.x * 0.44, 0.62, size.z * 0.9), wood)
		"warehouse_loading_pallet":
			_add_box(visual, "Pallet", Vector3(0.0, 0.14, 0.0), Vector3(size.x, 0.28, size.z), dark_wood)
			_add_box(visual, "LoadingCrate", Vector3(-0.45, 0.58, 0.0), Vector3(size.x * 0.42, 0.72, size.z * 0.72), wood)
			_add_cylinder(visual, "LoadingBarrel", Vector3(0.55, 0.58, 0.0), 0.38, 0.9, Color("#745339"))


func _build_hearth_fixture_visual(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var center := _v2(fixture.get("center", [0.0, 0.0]))
	var hearth := Node3D.new()
	hearth.name = str(fixture.get("id", "SharedHearth")).to_pascal_case()
	hearth.position = Vector3(center.x, 0.0, center.y)
	hearth.rotation_degrees.y = float(fixture.get("rotation_degrees", 0.0))
	_set_fixture_metadata(hearth, building_id, fixture)
	parent.add_child(hearth)
	if building_id == "blacksmith":
		# FormalBlacksmithArtView owns the detailed masonry/hood/bellows model. Keep
		# this metadata root for fixture visibility and let collision stay authoritative.
		return
	_add_box(hearth, "StoneBase", Vector3(0.0, 0.28, 0.0), Vector3(2.4, 0.56, 0.9), Color("#55565d"))
	_add_box(hearth, "StoneBack", Vector3(0.0, 0.88, -0.31), Vector3(2.4, 1.18, 0.28), Color("#494a50"))
	_add_box(hearth, "IronLip", Vector3(0.0, 0.62, 0.31), Vector3(2.4, 0.18, 0.2), Color("#24262b"))
	_add_box(hearth, "CoalBed", Vector3(0.0, 0.61, 0.0), Vector3(1.72, 0.12, 0.52), Color("#191a1d"))
	var ember := _add_box(hearth, "Ember", Vector3(0.0, 0.69, 0.0), Vector3(1.18, 0.05, 0.32), Color("#d9512a"))
	ember.visible = false
	ember.set_meta("smithy_hearth_heat", true)


func _build_fixture_collisions(parent: Node3D, building_id: String, fixture: Dictionary) -> void:
	var fixture_id := str(fixture.get("id", "Fixture"))
	var center := _v2(fixture.get("center", [0.0, 0.0]))
	var rotation_degrees := float(fixture.get("rotation_degrees", 0.0))
	var collision_size := _v3(fixture.get("collision_size", [1.0, 1.0, 1.0]))
	var collision_center_y := float(fixture.get("collision_center_y", collision_size.y * 0.5))
	var parts := _get_fixture_collision_parts(fixture)
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		var offset := _v2(part.get("offset", [0.0, 0.0]))
		var rotated_offset := _rotate_fixture_local_offset(offset, rotation_degrees)
		var part_size := _v3(part.get("size", [1.0, 1.0, 1.0]))
		var part_center_y := float(part.get("center_y", collision_center_y))
		var part_name := str(part.get("name", "Body%02d" % (index + 1)))
		var collision := _add_static_box_collision(
			parent,
			"%s%sCollision" % [fixture_id.to_pascal_case(), part_name.to_pascal_case()],
			Vector3(center.x + rotated_offset.x, part_center_y, center.y + rotated_offset.y),
			part_size,
			"building_fixture"
		)
		collision.rotation_degrees.y = rotation_degrees
		collision.set_meta("collision_component", part_name)
		_set_fixture_metadata(collision, building_id, fixture)


func _get_fixture_collision_parts(fixture: Dictionary) -> Array[Dictionary]:
	var size := _v3(fixture.get("collision_size", [1.0, 1.0, 1.0]))
	var collision_mode := str(fixture.get("collision_mode", "solid_box"))
	if collision_mode == "stable_open_bay":
		var thickness := clampf(float(fixture.get("border_thickness", 0.18)), 0.08, minf(size.x, size.z) * 0.2)
		var opening_side := str(fixture.get("opening_side", "right"))
		var outer_sign := -1.0 if opening_side == "right" else 1.0
		var parts: Array[Dictionary] = [
			{
				"name": "OuterFence",
				"offset": [outer_sign * (size.x * 0.5 - thickness * 0.5), 0.0],
				"size": [thickness, size.y, size.z - thickness],
				"center_y": size.y * 0.5
			},
			{
				"name": "NearDivider",
				"offset": [0.0, -size.z * 0.5 + thickness * 0.5],
				"size": [size.x, size.y, thickness],
				"center_y": size.y * 0.5
			},
			{
				"name": "FeedTrough",
				"offset": [outer_sign * 1.55, 0.0],
				"size": [1.0, 0.7, 1.9],
				"center_y": 0.35
			}
		]
		if bool(fixture.get("close_far_end", false)):
			parts.append({
				"name": "FarDivider",
				"offset": [0.0, size.z * 0.5 - thickness * 0.5],
				"size": [size.x, size.y, thickness],
				"center_y": size.y * 0.5
			})
		return parts
	if collision_mode != "garden_u_border":
		return [{"name": "Body", "offset": [0.0, 0.0], "size": [size.x, size.y, size.z]}]
	var thickness := clampf(float(fixture.get("border_thickness", 0.18)), 0.05, minf(size.x, size.z) * 0.25)
	var side_length := size.z - thickness
	return [
		{
			"name": "LeftBorder",
			"offset": [-size.x * 0.5 + thickness * 0.5, thickness * 0.5],
			"size": [thickness, size.y, side_length]
		},
		{
			"name": "RightBorder",
			"offset": [size.x * 0.5 - thickness * 0.5, thickness * 0.5],
			"size": [thickness, size.y, side_length]
		},
		{
			"name": "RearBorder",
			"offset": [0.0, -size.z * 0.5 + thickness * 0.5],
			"size": [size.x, size.y, thickness]
		}
	]


func _rotate_fixture_local_offset(offset: Vector2, rotation_degrees: float) -> Vector2:
	var angle := deg_to_rad(rotation_degrees)
	return Vector2(
		offset.x * cos(angle) + offset.y * sin(angle),
		-offset.x * sin(angle) + offset.y * cos(angle)
	)


func _build_fixture_stand_marker(
	parent: Node3D,
	building_id: String,
	fixture: Dictionary,
	npc_stand: Dictionary
) -> void:
	var center := _v2(npc_stand.get("center", [0.0, 0.0]))
	var facing_degrees := float(npc_stand.get("facing_degrees", 0.0))
	var marker := Marker3D.new()
	marker.name = "%sStand" % str(fixture.get("workstation_id", "Workstation")).to_pascal_case()
	marker.position = Vector3(center.x, 0.0, center.y)
	marker.set_meta("building_id", building_id)
	marker.set_meta("fixture_id", str(fixture.get("id", "")))
	marker.set_meta("workstation_id", str(fixture.get("workstation_id", "")))
	marker.set_meta("required_level", int(fixture.get("required_level", 1)))
	marker.set_meta("assigned_npc_id", str(fixture.get("assigned_npc_id", "")))
	marker.set_meta("facing_degrees", facing_degrees)
	marker.set_meta("clearance_radius", float(npc_stand.get("clearance_radius", 0.0)))
	var action_clearance_size := _v2(npc_stand.get("action_clearance_size", [0.0, 0.0]))
	marker.set_meta("action_clearance_size", action_clearance_size)
	parent.add_child(marker)
	if action_clearance_size.x > 0.0 and action_clearance_size.y > 0.0:
		var half_x := action_clearance_size.x * 0.5
		var half_z := action_clearance_size.y * 0.5
		var outline_color := Color(0.8, 0.52, 0.18, 0.42)
		_add_box(marker, "ActionClearanceLeft", Vector3(-half_x, 0.045, 0.0), Vector3(0.06, 0.035, action_clearance_size.y), outline_color)
		_add_box(marker, "ActionClearanceRight", Vector3(half_x, 0.045, 0.0), Vector3(0.06, 0.035, action_clearance_size.y), outline_color)
		_add_box(marker, "ActionClearanceRear", Vector3(0.0, 0.045, -half_z), Vector3(action_clearance_size.x, 0.035, 0.06), outline_color)
		_add_box(marker, "ActionClearanceFront", Vector3(0.0, 0.045, half_z), Vector3(action_clearance_size.x, 0.035, 0.06), outline_color)
	_add_box(marker, "StandFootprint", Vector3(0.0, 0.09, 0.0), Vector3(0.58, 0.06, 0.58), Color(0.96, 0.72, 0.18, 0.72))
	var facing_radians := deg_to_rad(facing_degrees)
	var direction := _add_box(
		marker,
		"FacingDirection",
		Vector3(sin(facing_radians) * 0.39, 0.13, -cos(facing_radians) * 0.39),
		Vector3(0.12, 0.08, 0.62),
		Color(1.0, 0.9, 0.35, 0.9)
	)
	direction.rotation_degrees.y = -facing_degrees
	_add_label(
		marker,
		"StandLabel",
		Vector3(0.0, 0.42, 0.0),
		"%s 站位" % str(fixture.get("workstation_id", ""))
	)


func _build_fixture_occupant_anchor_marker(
	parent: Node3D,
	building_id: String,
	fixture: Dictionary,
	occupant_anchor: Dictionary
) -> void:
	var center := _v2(occupant_anchor.get("center", [0.0, 0.0]))
	var marker := Marker3D.new()
	marker.name = "%sOccupantAnchor" % str(fixture.get("workstation_id", "Workstation")).to_pascal_case()
	marker.position = Vector3(center.x, float(occupant_anchor.get("y", 0.0)), center.y)
	marker.set_meta("building_id", building_id)
	marker.set_meta("fixture_id", str(fixture.get("id", "")))
	marker.set_meta("workstation_id", str(fixture.get("workstation_id", "")))
	marker.set_meta("facing_degrees", float(occupant_anchor.get("facing_degrees", 0.0)))
	marker.set_meta("occupant_pose", str(occupant_anchor.get("pose", "")))
	parent.add_child(marker)
	var footprint_size := _v2(occupant_anchor.get("footprint_size", [0.45, 1.05]))
	_add_box(
		marker,
		"OccupantFootprint",
		Vector3(0.0, 0.025, 0.0),
		Vector3(footprint_size.x, 0.04, footprint_size.y),
		Color(0.64, 0.36, 0.88, 0.58)
	)
	var default_anchor_label := (
		"患者锚点"
		if str(fixture.get("kind", "")) == "clinic_bed"
		else "占用锚点"
	)
	_add_label(
		marker,
		"OccupantLabel",
		Vector3(0.0, 0.48, 0.0),
		"%s %s" % [
			str(fixture.get("workstation_id", "")),
			str(occupant_anchor.get("label", default_anchor_label))
		]
	)


func _build_fixture_horse_anchor_marker(
	parent: Node3D,
	building_id: String,
	fixture: Dictionary,
	horse_anchor: Dictionary
) -> void:
	var center := _v2(horse_anchor.get("center", [0.0, 0.0]))
	var anchor_id := str(horse_anchor.get("id", "horse_anchor"))
	var marker := Marker3D.new()
	marker.name = "%sHorseAnchor" % anchor_id.to_pascal_case()
	marker.position = Vector3(center.x, 0.0, center.y)
	marker.set_meta("building_id", building_id)
	marker.set_meta("fixture_id", str(fixture.get("id", "")))
	marker.set_meta("workstation_id", str(fixture.get("workstation_id", "")))
	marker.set_meta("horse_anchor_id", anchor_id)
	marker.set_meta("facing_degrees", float(horse_anchor.get("facing_degrees", 0.0)))
	marker.set_meta("pickup_center", _v2(horse_anchor.get("pickup_center", horse_anchor.get("center", [0.0, 0.0]))))
	var footprint_size := _v2(horse_anchor.get("footprint_size", [1.3, 2.1]))
	marker.set_meta("footprint_size", footprint_size)
	parent.add_child(marker)
	var half_x := footprint_size.x * 0.5
	var half_z := footprint_size.y * 0.5
	var outline_color := Color(0.24, 0.68, 0.62, 0.58)
	_add_box(marker, "HorseClearanceLeft", Vector3(-half_x, 0.055, 0.0), Vector3(0.06, 0.04, footprint_size.y), outline_color)
	_add_box(marker, "HorseClearanceRight", Vector3(half_x, 0.055, 0.0), Vector3(0.06, 0.04, footprint_size.y), outline_color)
	_add_box(marker, "HorseClearanceRear", Vector3(0.0, 0.055, -half_z), Vector3(footprint_size.x, 0.04, 0.06), outline_color)
	_add_box(marker, "HorseClearanceFront", Vector3(0.0, 0.055, half_z), Vector3(footprint_size.x, 0.04, 0.06), outline_color)
	_add_label(marker, "HorseAnchorLabel", Vector3(0.0, 0.36, 0.0), "%s 马位" % anchor_id)


func _set_fixture_metadata(node: Node, building_id: String, fixture: Dictionary) -> void:
	node.set_meta("building_id", building_id)
	node.set_meta("fixture_id", str(fixture.get("id", "")))
	node.set_meta("fixture_kind", str(fixture.get("kind", "")))
	node.set_meta("required_level", int(fixture.get("required_level", 1)))
	node.set_meta("workstation_id", str(fixture.get("workstation_id", "")))
	node.set_meta("spatial_position_id", str(fixture.get("spatial_position_id", "")))
	node.set_meta("assigned_npc_id", str(fixture.get("assigned_npc_id", "")))
	node.set_meta("asset_path", str(fixture.get("asset_path", "")))


func _add_static_segment_collision(
	parent: Node3D,
	node_name: String,
	from_point: Vector2,
	to_point: Vector2,
	width: float,
	height: float,
	category: String
) -> StaticBody3D:
	var delta := to_point - from_point
	var middle := (from_point + to_point) * 0.5
	var body := _add_static_box_collision(
		parent,
		node_name,
		Vector3(middle.x, height * 0.5, middle.y),
		Vector3(width, height, delta.length()),
		category
	)
	body.rotation.y = atan2(delta.x, delta.y)
	return body


func _add_static_box_collision(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	size: Vector3,
	category: String
) -> StaticBody3D:
	var layers := _physics_navigation.get("collision_layers", {}) as Dictionary
	var world_static: Dictionary = layers.get("world_static", {})
	var actor_body: Dictionary = layers.get("actor_body", {})
	var body := StaticBody3D.new()
	body.name = node_name.validate_node_name()
	body.position = center
	body.collision_layer = int(world_static.get("bitmask", 1))
	body.collision_mask = int(actor_body.get("bitmask", 2))
	body.set_meta("collision_category", category)
	parent.add_child(body)
	var navigation_mesh: Dictionary = _physics_navigation.get("navigation_mesh", {})
	var source_group_name := str(navigation_mesh.get("source_group_name", "formal_navigation_source"))
	if not source_group_name.is_empty():
		body.add_to_group(source_group_name, true)
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = box
	body.add_child(shape)
	return body


func _build_spatial_contract() -> void:
	_spatial_anchor_nodes.clear()
	_npc_initial_anchor_nodes.clear()
	var contract_root := Node3D.new()
	contract_root.name = "SpatialContract"
	contract_root.visible = false
	contract_root.set_meta("schema_version", EXPECTED_SCHEMA)
	contract_root.set_meta("debug_visuals_hidden_in_gameplay", true)
	contract_root.set_meta("staged", not _default_formal_world_enabled)
	_formal_root.add_child(contract_root)

	var public_root := Node3D.new()
	public_root.name = "PublicLocations"
	contract_root.add_child(public_root)
	for raw_location in _layout.get("public_locations", []):
		var location: Dictionary = raw_location
		var location_id := str(location.get("id", ""))
		var position_2d := _v2(location.get("position", [0.0, 0.0]))
		var marker := _add_anchor_marker(
			public_root,
			location_id.to_pascal_case(),
			Vector3(position_2d.x, 0.0, position_2d.y),
			Vector2(float(location.get("radius", 1.0)) * 2.0, float(location.get("radius", 1.0)) * 2.0),
			0.18,
			Color(0.92, 0.76, 0.24, 0.42)
		)
		marker.set_meta("location_id", location_id)
		marker.set_meta("display_name", str(location.get("display_name", location_id)))
		_spatial_anchor_nodes["public:%s" % location_id] = marker

	var npc_root := Node3D.new()
	npc_root.name = "NPCInitialPositions"
	contract_root.add_child(npc_root)
	for raw_initial in _layout.get("npc_initial_positions", []):
		var initial: Dictionary = raw_initial
		var npc_id := str(initial.get("npc_id", ""))
		var position_2d := _v2(initial.get("position", [0.0, 0.0]))
		var marker := _add_anchor_marker(
			npc_root,
			npc_id.to_pascal_case(),
			Vector3(position_2d.x, 0.0, position_2d.y),
			Vector2(0.55, 0.55),
			0.28,
			Color(0.30, 0.78, 0.96, 0.85)
		)
		marker.set_meta("npc_id", npc_id)
		_npc_initial_anchor_nodes[npc_id] = marker
		_spatial_anchor_nodes["npc:%s" % npc_id] = marker

	var spatial_contracts: Dictionary = _layout.get("building_spatial", {})
	for raw_building_id in spatial_contracts.keys():
		var building_id := str(raw_building_id)
		var building_root := _building_roots.get(building_id) as Node3D
		if building_root == null:
			continue
		var building_definition := _find_building_definition(building_id)
		var height := float(building_definition.get("height", 1.0))
		var anchors_root := Node3D.new()
		anchors_root.name = "SpatialAnchors"
		anchors_root.visible = false
		anchors_root.set_meta("debug_visuals_hidden_in_gameplay", true)
		building_root.add_child(anchors_root)
		var spatial: Dictionary = spatial_contracts[building_id]
		var route: Dictionary = spatial.get("entry_route", {})
		var route_root := Node3D.new()
		route_root.name = "EntryRoute"
		anchors_root.add_child(route_root)
		for route_key in ["entry_outside", "door_outside", "door_inside", "interior", "exit_outside"]:
			var route_position := _v2(route.get(route_key, [0.0, 0.0]))
			var marker := _add_anchor_marker(
				route_root,
				str(route_key).to_pascal_case(),
				Vector3(route_position.x, 0.0, route_position.y),
				Vector2(0.42, 0.42),
				height + 0.22,
				Color(0.34, 0.92, 0.62, 0.9)
			)
			marker.set_meta("building_id", building_id)
			marker.set_meta("route_phase", route_key)
			_spatial_anchor_nodes["route:%s:%s" % [building_id, route_key]] = marker
		var positions_root := Node3D.new()
		positions_root.name = "AuthoritativePositions"
		anchors_root.add_child(positions_root)
		for raw_position in spatial.get("positions", []):
			var position: Dictionary = raw_position
			var position_id := str(position.get("id", ""))
			var center := _v2(position.get("center", [0.0, 0.0]))
			var size := _v2(position.get("size", [1.0, 1.0]))
			var marker := _add_anchor_marker(
				positions_root,
				position_id.to_pascal_case(),
				Vector3(center.x, 0.0, center.y),
				size,
				height + 0.16,
				_color_for_authority(str(position.get("authority", "")))
			)
			for meta_key in ["id", "type", "authority", "required_level", "layer"]:
				if position.has(meta_key):
					marker.set_meta(meta_key, position[meta_key])
			marker.set_meta("building_id", building_id)
			_spatial_anchor_nodes["position:%s:%s" % [building_id, position_id]] = marker

	_build_navigation_contract(contract_root)


func _build_navigation_contract(contract_root: Node3D) -> void:
	_navigation_walkable_cells.clear()
	_navigation_walkable_ids.clear()
	var navigation: Dictionary = _layout.get("navigation", {})
	var cell_size := float(navigation.get("cell_size", 1.0))
	var bounds: Array = navigation.get("grid_bounds", [-58.0, 58.0, -50.0, 58.0])
	var min_x := int(floor(float(bounds[0]) / cell_size))
	var max_x := int(ceil(float(bounds[1]) / cell_size))
	var min_z := int(floor(float(bounds[2]) / cell_size))
	var max_z := int(ceil(float(bounds[3]) / cell_size))
	_navigation_grid_region = Rect2i(min_x, min_z, max_x - min_x, max_z - min_z)
	_navigation_grid = AStarGrid2D.new()
	_navigation_grid.region = _navigation_grid_region
	_navigation_grid.cell_size = Vector2(cell_size, cell_size)
	_navigation_grid.offset = Vector2(cell_size * 0.5, cell_size * 0.5)
	_navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation_grid.jumping_enabled = false
	_navigation_grid.update()

	for grid_x in range(min_x, max_x):
		for grid_z in range(min_z, max_z):
			var cell_id := Vector2i(grid_x, grid_z)
			var center := Vector2(
				(float(grid_x) + 0.5) * cell_size,
				(float(grid_z) + 0.5) * cell_size
			)
			if _is_navigation_point_walkable(center):
				_navigation_walkable_cells[_cell_key(cell_id)] = true
				_navigation_walkable_ids.append(cell_id)
			else:
				_navigation_grid.set_point_solid(cell_id, true)

	var production_bounds: Array = navigation.get("production_bounds", bounds)
	var production_mesh := _create_production_navigation_mesh(production_bounds)
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "StationNavigation"
	_navigation_region.navigation_mesh = production_mesh
	_navigation_region.use_edge_connections = true
	_navigation_region.enabled = bool(navigation.get("enabled_by_default", false))
	_navigation_region.set_meta("staged", not _default_formal_world_enabled)
	_navigation_region.set_meta("navigation_kind", "production_static_collider_bake")
	_navigation_region.set_meta("contract_walkable_cell_count", _navigation_walkable_cells.size())
	if _production_navigation_map.is_valid():
		NavigationServer3D.free_rid(_production_navigation_map)
	_production_navigation_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_production_navigation_map, production_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(_production_navigation_map, production_mesh.cell_height)
	NavigationServer3D.map_set_active(_production_navigation_map, true)
	_navigation_region.set_navigation_map(_production_navigation_map)
	contract_root.add_child(_navigation_region)
	var bake_started := Time.get_ticks_msec()
	_navigation_region.bake_navigation_mesh(false)
	_production_navigation_bake_msec = Time.get_ticks_msec() - bake_started
	_navigation_region.set_meta("bake_msec", _production_navigation_bake_msec)
	_navigation_region.set_meta("polygon_count", production_mesh.get_polygon_count())
	_build_building_navigation_links(contract_root)


func _build_enemy_approach_navigation() -> void:
	_enemy_approach_vertex_count = 0
	_enemy_approach_polygon_count = 0
	var combat_spatial := _layout.get("combat_spatial", {}) as Dictionary
	var route := combat_spatial.get("enemy_route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	var stop_stage_id := str(route.get("pilot_stop_stage_id", "front_gate"))
	var navigation := _layout.get("navigation", {}) as Dictionary
	if str(navigation.get("enemy_exterior_mode", "")) == "shared_open_baked_space":
		# T0200: enemy routes and roads are presentation/spawn staging data, never
		# navigation authority. The production collider bake now owns the whole
		# exterior battlefield, so a locked tower/NPC target can be approached
		# directly instead of being forced through the front-gate corridor.
		_enemy_approach_navigation_region = null
		_build_enemy_front_gate_navigation_link(
			stages,
			_formal_root.get_node_or_null("SpatialContract") as Node3D
		)
		return
	var cross_sections := route.get("navigation_cross_sections", []) as Array
	if cross_sections.size() < 2 or not _production_navigation_map.is_valid():
		return

	var navigation_height := float((_layout.get("navigation", {}) as Dictionary).get("navigation_height", 0.12))
	var vertices: Array[Vector3] = []
	for raw_section in cross_sections:
		if not raw_section is Dictionary:
			continue
		var section := raw_section as Dictionary
		var z := float(section.get("z", 0.0))
		vertices.append(Vector3(float(section.get("x_min", 0.0)), navigation_height, z))
		vertices.append(Vector3(float(section.get("x_max", 0.0)), navigation_height, z))
	if vertices.size() < 4:
		return

	var navigation_mesh := NavigationMesh.new()
	var nav_config := _physics_navigation.get("navigation_mesh", {}) as Dictionary
	navigation_mesh.agent_radius = float(nav_config.get("agent_radius", 0.35))
	navigation_mesh.agent_height = float(nav_config.get("agent_height", 1.8))
	navigation_mesh.agent_max_climb = float(nav_config.get("agent_max_climb", 0.3))
	navigation_mesh.agent_max_slope = float(nav_config.get("agent_max_slope_degrees", 45.0))
	navigation_mesh.set_vertices(PackedVector3Array(vertices))
	for index in range(vertices.size() / 2 - 1):
		navigation_mesh.add_polygon(PackedInt32Array([
			index * 2,
			(index + 1) * 2,
			(index + 1) * 2 + 1,
			index * 2 + 1
		]))

	_enemy_approach_navigation_region = NavigationRegion3D.new()
	_enemy_approach_navigation_region.name = "EnemyApproachNavigation"
	_enemy_approach_navigation_region.navigation_mesh = navigation_mesh
	_enemy_approach_navigation_region.use_edge_connections = true
	_enemy_approach_navigation_region.enabled = bool((_layout.get("navigation", {}) as Dictionary).get("enabled_by_default", false))
	_enemy_approach_navigation_region.set_navigation_map(_production_navigation_map)
	_enemy_approach_navigation_region.set_meta("staged", not _default_formal_world_enabled)
	_enemy_approach_navigation_region.set_meta("navigation_kind", "enemy_approach_open_corridor")
	_enemy_approach_navigation_region.set_meta("roads_affect_navigation", false)
	_enemy_approach_navigation_region.set_meta("pilot_stop_stage_id", stop_stage_id)
	var spatial_contract := _formal_root.get_node_or_null("SpatialContract") as Node3D
	if spatial_contract != null:
		spatial_contract.add_child(_enemy_approach_navigation_region)
	else:
		_formal_root.add_child(_enemy_approach_navigation_region)
	_build_enemy_front_gate_navigation_link(stages, spatial_contract if spatial_contract != null else _formal_root)
	_enemy_approach_vertex_count = vertices.size()
	_enemy_approach_polygon_count = navigation_mesh.get_polygon_count()


func _build_rear_escape_navigation() -> void:
	_rear_escape_vertex_count = 0
	_rear_escape_polygon_count = 0
	_rear_escape_route_length = 0.0
	var rear_spatial := _layout.get("rear_spatial", {}) as Dictionary
	var route := rear_spatial.get("escape_route", {}) as Dictionary
	var raw_points := route.get("path_points", []) as Array
	if raw_points.size() < 2 or not _production_navigation_map.is_valid():
		return
	var navigation_height := float((_layout.get("navigation", {}) as Dictionary).get("navigation_height", 0.12))
	var route_points: Array[Vector3] = []
	for raw_point in raw_points:
		var point := _station_point_to_vector3(raw_point)
		point.y = navigation_height
		route_points.append(point)
	if route_points.size() < 2:
		return
	for index in range(1, route_points.size()):
		_rear_escape_route_length += route_points[index - 1].distance_to(route_points[index])
	var half_width := maxf(2.2, float(route.get("corridor_half_width", 2.25)))
	var vertices := _build_polyline_strip_vertices(route_points, half_width, navigation_height)
	var navigation_mesh := NavigationMesh.new()
	var nav_config := _physics_navigation.get("navigation_mesh", {}) as Dictionary
	navigation_mesh.agent_radius = float(nav_config.get("agent_radius", 0.35))
	navigation_mesh.agent_height = float(nav_config.get("agent_height", 1.8))
	navigation_mesh.agent_max_climb = float(nav_config.get("agent_max_climb", 0.3))
	navigation_mesh.agent_max_slope = float(nav_config.get("agent_max_slope_degrees", 45.0))
	navigation_mesh.set_vertices(vertices)
	for index in range(route_points.size() - 1):
		var first := index * 2
		var following := (index + 1) * 2
		navigation_mesh.add_polygon(PackedInt32Array([first, following, following + 1, first + 1]))
	_rear_escape_navigation_region = NavigationRegion3D.new()
	_rear_escape_navigation_region.name = "RearEscapeNavigation"
	_rear_escape_navigation_region.navigation_mesh = navigation_mesh
	_rear_escape_navigation_region.use_edge_connections = true
	_rear_escape_navigation_region.enabled = bool((_layout.get("navigation", {}) as Dictionary).get("enabled_by_default", false))
	_rear_escape_navigation_region.set_navigation_map(_production_navigation_map)
	_rear_escape_navigation_region.set_meta("staged", not _default_formal_world_enabled)
	_rear_escape_navigation_region.set_meta("navigation_kind", "rear_escape_open_corridor")
	_rear_escape_navigation_region.set_meta("roads_affect_navigation", false)
	_rear_escape_navigation_region.set_meta("authority", "escape_physical_route")
	_rear_escape_navigation_region.set_meta("route_length", _rear_escape_route_length)
	var spatial_contract := _formal_root.get_node_or_null("SpatialContract") as Node3D
	if spatial_contract != null:
		spatial_contract.add_child(_rear_escape_navigation_region)
	else:
		_formal_root.add_child(_rear_escape_navigation_region)
	_build_rear_escape_navigation_link(
		route_points,
		spatial_contract if spatial_contract != null else _formal_root,
		navigation_height
	)
	_rear_escape_vertex_count = vertices.size()
	_rear_escape_polygon_count = navigation_mesh.get_polygon_count()


func _build_rear_escape_navigation_link(
	route_points: Array[Vector3],
	parent: Node3D,
	navigation_height: float
) -> void:
	_rear_escape_navigation_link = null
	if route_points.size() < 2:
		return
	var rear_direction := (route_points[1] - route_points[0]).normalized()
	var link := NavigationLink3D.new()
	link.name = "RearEscapeGateLink"
	# The collider-baked station island and the hand-authored rear strip overlap
	# at the open gate but remain separate NavigationServer regions. This short,
	# outbound-only link gives the agent an explicit physical crossing instead of
	# teleporting it to the rear route.
	link.start_position = Vector3(route_points[0].x, navigation_height, route_points[0].z + 3.0)
	link.end_position = route_points[0] + rear_direction * 8.0
	link.end_position.y = navigation_height
	link.bidirectional = false
	link.enter_cost = 0.1
	link.travel_cost = 1.0
	link.enabled = bool((_layout.get("navigation", {}) as Dictionary).get("enabled_by_default", false))
	link.set_navigation_map(_production_navigation_map)
	link.set_meta("route_phase", "rear_gate_escape")
	link.set_meta("staged", not _default_formal_world_enabled)
	parent.add_child(link)
	_rear_escape_navigation_link = link


func _build_polyline_strip_vertices(
	points: Array[Vector3],
	half_width: float,
	height: float
) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for index in range(points.size()):
		var current := Vector2(points[index].x, points[index].z)
		var previous := Vector2(points[maxi(index - 1, 0)].x, points[maxi(index - 1, 0)].z)
		var following := Vector2(points[mini(index + 1, points.size() - 1)].x, points[mini(index + 1, points.size() - 1)].z)
		var incoming := (current - previous).normalized() if index > 0 else (following - current).normalized()
		var outgoing := (following - current).normalized() if index < points.size() - 1 else incoming
		var incoming_normal := Vector2(-incoming.y, incoming.x)
		var outgoing_normal := Vector2(-outgoing.y, outgoing.x)
		var miter := (incoming_normal + outgoing_normal).normalized()
		if miter.length_squared() <= 0.001:
			miter = outgoing_normal
		var denominator := maxf(0.5, absf(miter.dot(outgoing_normal)))
		var side := miter * minf(half_width / denominator, half_width * 1.5)
		vertices.append(Vector3(current.x + side.x, height, current.y + side.y))
		vertices.append(Vector3(current.x - side.x, height, current.y - side.y))
	return vertices


func _build_enemy_front_gate_navigation_link(stages: Array, parent: Node3D) -> void:
	_enemy_front_gate_navigation_link = null
	var front_gate_point := Vector2.ZERO
	var gate_turn_point := Vector2.ZERO
	var found_front_gate := false
	var found_gate_turn := false
	for raw_stage in stages:
		if not raw_stage is Dictionary:
			continue
		var stage := raw_stage as Dictionary
		match str(stage.get("id", "")):
			"front_gate":
				front_gate_point = _v2(stage.get("point", []))
				found_front_gate = true
			"gate_turn":
				gate_turn_point = _v2(stage.get("point", []))
				found_gate_turn = true
	if not found_front_gate or not found_gate_turn:
		return
	var navigation_height := float((_layout.get("navigation", {}) as Dictionary).get("navigation_height", 0.12))
	var link := NavigationLink3D.new()
	link.name = "EnemyFrontGateLink"
	link.start_position = Vector3(front_gate_point.x, navigation_height, front_gate_point.y)
	link.end_position = Vector3(gate_turn_point.x, navigation_height, gate_turn_point.y)
	# The same physical gate crossing serves enemy ingress after the gate falls and
	# friendly alarm responders moving out to the configured rally ground.
	link.bidirectional = true
	link.enter_cost = 0.1
	link.travel_cost = 1.0
	link.enabled = bool((_layout.get("navigation", {}) as Dictionary).get("enabled_by_default", false))
	link.set_navigation_map(_production_navigation_map)
	link.set_meta("route_phase", "front_gate_breach")
	link.set_meta("supports_friendly_rally", true)
	link.set_meta("staged", not _default_formal_world_enabled)
	parent.add_child(link)
	_enemy_front_gate_navigation_link = link


func _build_building_navigation_links(contract_root: Node3D) -> void:
	_building_navigation_links.clear()
	var spatial_contracts: Dictionary = _layout.get("building_spatial", {})
	var links_root := Node3D.new()
	links_root.name = "BuildingDoorLinks"
	contract_root.add_child(links_root)
	var navigation_height := float((_layout.get("navigation", {}) as Dictionary).get("navigation_height", 0.12))
	for raw_building in _layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var blocker_config := building.get("solid_interior_blocker", {}) as Dictionary
		if bool(blocker_config.get("enabled", false)) and bool(blocker_config.get("blocks_navigation_link", true)):
			continue
		var route: Dictionary = (spatial_contracts.get(building_id, {}) as Dictionary).get("entry_route", {})
		var outside := _building_local_to_station(building, route.get("door_outside", []))
		var inside := _building_local_to_station(building, route.get("door_inside", []))
		var link := NavigationLink3D.new()
		link.name = "%sDoorLink" % str(building.get("node_name", building_id))
		link.start_position = Vector3(outside.x, navigation_height, outside.y)
		link.end_position = Vector3(inside.x, navigation_height, inside.y)
		link.bidirectional = true
		link.enter_cost = 0.1
		link.travel_cost = 1.0
		link.enabled = bool((_layout.get("navigation", {}) as Dictionary).get("enabled_by_default", false))
		link.set_meta("building_id", building_id)
		link.set_meta("route_phase", "door_crossing")
		link.set_meta("staged", not _default_formal_world_enabled)
		link.set_navigation_map(_production_navigation_map)
		links_root.add_child(link)
		_building_navigation_links.append(link)


func _create_production_navigation_mesh(bounds: Array) -> NavigationMesh:
	var config: Dictionary = _physics_navigation.get("navigation_mesh", {})
	var result := NavigationMesh.new()
	result.cell_size = float(config.get("production_cell_size", 0.25))
	result.cell_height = float(config.get("production_cell_height", 0.1))
	result.agent_radius = float(config.get("baked_agent_radius", config.get("agent_radius", 0.35)))
	result.agent_height = float(config.get("agent_height", 1.8))
	result.agent_max_climb = float(config.get("agent_max_climb", 0.3))
	result.agent_max_slope = float(config.get("agent_max_slope_degrees", 45.0))
	result.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	result.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	result.geometry_source_group_name = StringName(str(config.get("source_group_name", "formal_navigation_source")))
	result.geometry_collision_mask = int(
		((_physics_navigation.get("collision_layers", {}) as Dictionary).get("world_static", {}) as Dictionary).get(
			"bitmask", 1
		)
	)
	var margin := float(config.get("baking_aabb_margin", 2.0))
	var height_min := float(config.get("baking_height_min", -1.0))
	var height_max := float(config.get("baking_height_max", 6.0))
	result.filter_baking_aabb = AABB(
		Vector3(float(bounds[0]) - margin, height_min, float(bounds[2]) - margin),
		Vector3(
			float(bounds[1]) - float(bounds[0]) + margin * 2.0,
			height_max - height_min,
			float(bounds[3]) - float(bounds[2]) + margin * 2.0
		)
	)
	result.border_size = result.agent_radius
	return result


func _is_navigation_point_walkable(point: Vector2) -> bool:
	var station: Dictionary = _layout.get("station", {})
	var polygon := PackedVector2Array()
	for raw_point in station.get("interior_polygon", []):
		polygon.append(_v2(raw_point))
	if polygon.size() < 3 or not Geometry2D.is_point_in_polygon(point, polygon):
		return false
	for raw_building in _layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_state := _classify_building_navigation_point(point, building)
		if building_state > 0:
			return true
		if building_state < 0:
			return false
	# Roads and plaza patches are presentation decals.  Open station ground is
	# equally traversable; only physical structures and the station boundary
	# constrain pathfinding.
	return true


func _classify_building_navigation_point(point: Vector2, building: Dictionary) -> int:
	var local := _station_to_building_local(building, point)
	var envelope := _v2(building.get("envelope_size", [1.0, 1.0]))
	var half_size := envelope * 0.5
	if absf(local.x) > half_size.x or absf(local.y) > half_size.y:
		return 0
	var blocker_config := building.get("solid_interior_blocker", {}) as Dictionary
	if bool(blocker_config.get("enabled", false)):
		return -1
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	var navigation := _layout.get("navigation", {}) as Dictionary
	var shell_depth := maxf(
		float(structural.get("wall_thickness", 0.4)) + float(navigation.get("agent_radius", 0.35)),
		float(navigation.get("cell_size", 1.0)) * 0.65
	)
	var cell_size := float(navigation.get("cell_size", 0.5))
	var door_half_width := (
		float(structural.get("building_door_clear_width", 1.4)) * 0.5
		+ cell_size * 0.71
	)
	var in_doorway := (
		absf(local.x) <= door_half_width
		and local.y >= half_size.y - shell_depth - cell_size * 1.5
	)
	if in_doorway:
		return 1
	var inner_half := half_size - Vector2(shell_depth, shell_depth)
	if inner_half.x > 0.0 and inner_half.y > 0.0 and absf(local.x) <= inner_half.x and absf(local.y) <= inner_half.y:
		return 1
	return -1


func _build_spatial_reachability_snapshot() -> Dictionary:
	var plaza_position := Vector3.ZERO
	var plaza_anchor := _spatial_anchor_nodes.get("public:plaza") as Node3D
	if plaza_anchor != null:
		plaza_position = plaza_anchor.position
	var targets: Dictionary = {}
	for raw_location in _layout.get("public_locations", []):
		var location: Dictionary = raw_location
		var point := _v2(location.get("position", [0.0, 0.0]))
		targets["public:%s" % str(location.get("id", ""))] = Vector3(point.x, 0.0, point.y)
	for raw_initial in _layout.get("npc_initial_positions", []):
		var initial: Dictionary = raw_initial
		var point := _v2(initial.get("position", [0.0, 0.0]))
		targets["npc:%s" % str(initial.get("npc_id", ""))] = Vector3(point.x, 0.0, point.y)
	var spatial_contracts: Dictionary = _layout.get("building_spatial", {})
	for raw_building in _layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var spatial: Dictionary = spatial_contracts.get(building_id, {})
		var route: Dictionary = spatial.get("entry_route", {})
		for route_key in ["entry_outside", "door_inside", "interior", "exit_outside"]:
			var station_point := _building_local_to_station(building, route.get(route_key, []))
			targets["route:%s:%s" % [building_id, route_key]] = Vector3(station_point.x, 0.0, station_point.y)
		for raw_position in spatial.get("positions", []):
			var position: Dictionary = raw_position
			var position_id := str(position.get("id", ""))
			var target_local: Variant = position.get("center", [])
			var fixture := _find_fixture_for_position(building_id, position_id)
			var npc_stand := fixture.get("npc_stand", {}) as Dictionary
			if not npc_stand.is_empty():
				target_local = npc_stand.get("center", target_local)
			var station_point := _building_local_to_station(building, target_local)
			targets["position:%s:%s" % [building_id, position_id]] = Vector3(
				station_point.x, 0.0, station_point.y
			)
	var unreachable: Array[String] = []
	var minimum_path_points := 999999
	for target_id in targets.keys():
		var path := get_navigation_path_local(plaza_position, targets[target_id])
		if path.is_empty():
			unreachable.append(str(target_id))
		else:
			minimum_path_points = mini(minimum_path_points, path.size())
	return {
		"target_count": targets.size(),
		"reachable_count": targets.size() - unreachable.size(),
		"unreachable_count": unreachable.size(),
		"unreachable_targets": unreachable,
		"minimum_path_point_count": 0 if minimum_path_points == 999999 else minimum_path_points,
		"walkable_cell_count": _navigation_walkable_cells.size()
	}


func _enter_preview() -> void:
	var camera_rig := get_node_or_null(camera_rig_path) as Node3D
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera_rig == null or camera == null:
		_configuration_errors.append("preview_camera_missing")
		return
	_camera_restore = {
		"rig_position": camera_rig.global_position,
		"camera_position": camera.position,
		"camera_rotation": camera.rotation_degrees,
		"camera_fov": camera.fov,
		"min_distance": camera_rig.get("min_zoom_distance"),
		"max_distance": camera_rig.get("max_zoom_distance"),
		"x_limits": camera_rig.get("x_limits"),
		"z_limits": camera_rig.get("z_limits")
	}
	var migration: Dictionary = _layout.get("migration", {})
	var config: Dictionary = _layout.get("camera", {})
	var offset := _v2(migration.get("preview_offset", [0.0, 0.0]))
	var focus := _v2(config.get("initial_focus", [0.0, 0.0]))
	var distance := float(config.get("initial_distance", 70.0))
	var pitch_degrees := absf(float(config.get("pitch_degrees", -55.0)))
	var pitch := deg_to_rad(pitch_degrees)
	camera_rig.set("min_zoom_distance", float(config.get("min_distance", 20.0)))
	camera_rig.set("max_zoom_distance", float(config.get("max_distance", 70.0)))
	camera_rig.set("x_limits", _v2(config.get("x_limits", [-150.0, 150.0])) + Vector2(offset.x, offset.x))
	camera_rig.set("z_limits", _v2(config.get("z_limits", [-215.0, 240.0])) + Vector2(offset.y, offset.y))
	camera_rig.global_position = Vector3(offset.x + focus.x, 0.0, offset.y + focus.y)
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation_degrees = Vector3(-pitch_degrees, 0.0, 0.0)
	camera.fov = float(config.get("vertical_fov_degrees", 62.0))
	_formal_root.visible = true
	if _default_formal_world_enabled and not _legacy_compatibility_override:
		_set_legacy_visuals_enabled(false)
	if is_instance_valid(_navigation_region):
		_navigation_region.enabled = true
	if is_instance_valid(_enemy_approach_navigation_region):
		_enemy_approach_navigation_region.enabled = true
	if is_instance_valid(_rear_escape_navigation_region):
		_rear_escape_navigation_region.enabled = true
	if is_instance_valid(_rear_escape_navigation_link):
		_rear_escape_navigation_link.enabled = true
	if is_instance_valid(_enemy_front_gate_navigation_link):
		_enemy_front_gate_navigation_link.enabled = true
	for link in _building_navigation_links:
		if is_instance_valid(link):
			link.enabled = true
	_preview_enabled = true


func _exit_preview() -> void:
	var camera_rig := get_node_or_null(camera_rig_path) as Node3D
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera_rig != null and camera != null and not _camera_restore.is_empty():
		camera_rig.global_position = _camera_restore.get("rig_position", Vector3.ZERO)
		camera.position = _camera_restore.get("camera_position", Vector3.ZERO)
		camera.rotation_degrees = _camera_restore.get("camera_rotation", Vector3.ZERO)
		camera.fov = float(_camera_restore.get("camera_fov", 75.0))
		camera_rig.set("min_zoom_distance", _camera_restore.get("min_distance"))
		camera_rig.set("max_zoom_distance", _camera_restore.get("max_distance"))
		camera_rig.set("x_limits", _camera_restore.get("x_limits"))
		camera_rig.set("z_limits", _camera_restore.get("z_limits"))
	_camera_restore.clear()
	if is_instance_valid(_formal_root):
		_formal_root.visible = false
	if _legacy_compatibility_override or not _default_formal_world_enabled:
		_set_legacy_visuals_enabled(true)
	if is_instance_valid(_navigation_region):
		_navigation_region.enabled = false
	if is_instance_valid(_enemy_approach_navigation_region):
		_enemy_approach_navigation_region.enabled = false
	if is_instance_valid(_rear_escape_navigation_region):
		_rear_escape_navigation_region.enabled = false
	if is_instance_valid(_rear_escape_navigation_link):
		_rear_escape_navigation_link.enabled = false
	if is_instance_valid(_enemy_front_gate_navigation_link):
		_enemy_front_gate_navigation_link.enabled = false
	for link in _building_navigation_links:
		if is_instance_valid(link):
			link.enabled = false
	_preview_enabled = false


func _set_legacy_visuals_enabled(enabled: bool) -> void:
	var world_root := get_node_or_null(world_root_path) as Node3D
	if world_root == null:
		return
	for path in LEGACY_VISUAL_PATHS:
		var visual := world_root.get_node_or_null(path) as Node3D
		if visual != null:
			visual.visible = enabled
			_set_legacy_collision_branch_enabled(visual, enabled)


func _set_legacy_collision_branch_enabled(branch: Node, enabled: bool) -> void:
	var collision_objects: Array[Node] = []
	if branch is CollisionObject3D:
		collision_objects.append(branch)
	collision_objects.append_array(branch.find_children("*", "CollisionObject3D", true, false))
	for raw_object in collision_objects:
		var collision_object := raw_object as CollisionObject3D
		if collision_object == null:
			continue
		if not collision_object.has_meta("formal_origin_restore_collision_layer"):
			collision_object.set_meta("formal_origin_restore_collision_layer", collision_object.collision_layer)
			collision_object.set_meta("formal_origin_restore_collision_mask", collision_object.collision_mask)
		if enabled:
			collision_object.collision_layer = int(collision_object.get_meta("formal_origin_restore_collision_layer", 0))
			collision_object.collision_mask = int(collision_object.get_meta("formal_origin_restore_collision_mask", 0))
		else:
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0


func _are_legacy_visuals_hidden() -> bool:
	var world_root := get_node_or_null(world_root_path) as Node3D
	if world_root == null:
		return false
	for path in LEGACY_VISUAL_PATHS:
		var visual := world_root.get_node_or_null(path) as Node3D
		if visual != null and visual.visible:
			return false
	return true


func _add_anchor_marker(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	visual_size: Vector2,
	visual_y: float,
	color: Color
) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name.validate_node_name()
	marker.position = position
	parent.add_child(marker)
	_add_box(
		marker,
		"ContractFootprint",
		Vector3(0.0, visual_y, 0.0),
		Vector3(maxf(0.08, visual_size.x), 0.08, maxf(0.08, visual_size.y)),
		color
	)
	return marker


func _color_for_authority(authority: String) -> Color:
	if authority == AUTHORITY_DEFENSE_SLOT:
		return Color(0.96, 0.36, 0.24, 0.42)
	return Color(0.26, 0.72, 0.96, 0.36)


func _find_building_definition(building_id: String) -> Dictionary:
	for raw_building in _layout.get("buildings", []):
		var building: Dictionary = raw_building
		if str(building.get("id", "")) == building_id:
			return building
	return {}


func _find_position_definition(building_id: String, position_id: String) -> Dictionary:
	var spatial: Dictionary = (_layout.get("building_spatial", {}) as Dictionary).get(building_id, {})
	for raw_position in spatial.get("positions", []):
		var position: Dictionary = raw_position
		if str(position.get("id", "")) == position_id:
			return position
	return {}


func _get_building_fixture_config(building_id: String) -> Dictionary:
	return ((_fixture_layouts.get("buildings", {}) as Dictionary).get(building_id, {}) as Dictionary)


func _find_fixture_for_position(building_id: String, position_id: String) -> Dictionary:
	var fixture_config := _get_building_fixture_config(building_id)
	for raw_fixture in fixture_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		if (
			str(fixture.get("workstation_id", "")) == position_id
			or str(fixture.get("spatial_position_id", "")) == position_id
		):
			return fixture
	return {}


func _get_fixture_count() -> int:
	var result := 0
	for raw_building in (_fixture_layouts.get("buildings", {}) as Dictionary).values():
		var building: Dictionary = raw_building
		result += (building.get("fixtures", []) as Array).size()
	return result


func _get_fixture_workstation_stand_count() -> int:
	var result := 0
	for raw_building in (_fixture_layouts.get("buildings", {}) as Dictionary).values():
		var building: Dictionary = raw_building
		for raw_fixture in building.get("fixtures", []):
			var fixture: Dictionary = raw_fixture
			if not str(fixture.get("workstation_id", "")).is_empty() and not (fixture.get("npc_stand", {}) as Dictionary).is_empty():
				result += 1
	return result


func _get_fixture_occupant_anchor_count() -> int:
	var result := 0
	for raw_building in (_fixture_layouts.get("buildings", {}) as Dictionary).values():
		var building: Dictionary = raw_building
		for raw_fixture in building.get("fixtures", []):
			var fixture: Dictionary = raw_fixture
			if not (fixture.get("occupant_anchor", {}) as Dictionary).is_empty():
				result += 1
	return result


func _get_fixture_horse_anchor_count() -> int:
	var result := 0
	for raw_building in (_fixture_layouts.get("buildings", {}) as Dictionary).values():
		var building: Dictionary = raw_building
		for raw_fixture in building.get("fixtures", []):
			var fixture: Dictionary = raw_fixture
			if not (fixture.get("horse_anchor", {}) as Dictionary).is_empty():
				result += 1
	return result


func _building_local_to_global(building_root: Node3D, local_value: Variant, local_y: float = 0.0) -> Vector3:
	var local := _v2(local_value)
	return building_root.to_global(Vector3(local.x, local_y, local.y))


func _station_point_to_vector3(value: Variant, y: float = 0.0) -> Vector3:
	var point := _v2(value)
	return Vector3(point.x, y, point.y)


func _building_local_to_station(building: Dictionary, local_value: Variant) -> Vector2:
	var local := _v2(local_value)
	var center := _v2(building.get("center", [0.0, 0.0]))
	var angle := deg_to_rad(float(building.get("rotation_degrees", 0.0)))
	return center + Vector2(
		local.x * cos(angle) + local.y * sin(angle),
		-local.x * sin(angle) + local.y * cos(angle)
	)


func _station_to_building_local(building: Dictionary, station_point: Vector2) -> Vector2:
	var center := _v2(building.get("center", [0.0, 0.0]))
	var delta := station_point - center
	var angle := deg_to_rad(float(building.get("rotation_degrees", 0.0)))
	return Vector2(
		delta.x * cos(angle) - delta.y * sin(angle),
		delta.x * sin(angle) + delta.y * cos(angle)
	)


func _point_in_rotated_rect(
	point: Vector2,
	center: Vector2,
	size: Vector2,
	rotation_degrees: float,
	clearance: float = 0.0
) -> bool:
	var delta := point - center
	var angle := deg_to_rad(rotation_degrees)
	var local := Vector2(
		delta.x * cos(angle) - delta.y * sin(angle),
		delta.x * sin(angle) + delta.y * cos(angle)
	)
	var half_size := size * 0.5 - Vector2(clearance, clearance)
	return half_size.x > 0.0 and half_size.y > 0.0 and absf(local.x) <= half_size.x and absf(local.y) <= half_size.y


func _point_overlaps_fixture(
	point: Vector2,
	center: Vector2,
	size: Vector2,
	rotation_degrees: float,
	clearance: float
) -> bool:
	var delta := point - center
	var angle := deg_to_rad(rotation_degrees)
	var local := Vector2(
		delta.x * cos(angle) - delta.y * sin(angle),
		delta.x * sin(angle) + delta.y * cos(angle)
	)
	var inflated_half_size := size * 0.5 + Vector2(clearance, clearance)
	return absf(local.x) <= inflated_half_size.x and absf(local.y) <= inflated_half_size.y


func _point_overlaps_fixture_collision(point: Vector2, fixture: Dictionary, clearance: float) -> bool:
	var center := _v2(fixture.get("center", [0.0, 0.0]))
	var rotation_degrees := float(fixture.get("rotation_degrees", 0.0))
	for part in _get_fixture_collision_parts(fixture):
		var part_offset := _v2(part.get("offset", [0.0, 0.0]))
		var part_center := center + _rotate_fixture_local_offset(part_offset, rotation_degrees)
		var part_size_3d := _v3(part.get("size", [1.0, 1.0, 1.0]))
		if _point_overlaps_fixture(
			point,
			part_center,
			Vector2(part_size_3d.x, part_size_3d.z),
			rotation_degrees,
			clearance
		):
			return true
	return false


func _get_or_add_navigation_vertex(
	vertex_indices: Dictionary,
	vertices: Array[Vector3],
	grid_x: int,
	grid_z: int,
	cell_size: float,
	navigation_height: float
) -> int:
	var key := "%d:%d" % [grid_x, grid_z]
	if vertex_indices.has(key):
		return int(vertex_indices[key])
	var index := vertices.size()
	vertices.append(Vector3(float(grid_x) * cell_size, navigation_height, float(grid_z) * cell_size))
	vertex_indices[key] = index
	return index


func _nearest_walkable_cell(point: Vector2, cell_size: float) -> Vector2i:
	var direct := Vector2i(int(floor(point.x / cell_size)), int(floor(point.y / cell_size)))
	if _navigation_walkable_cells.has(_cell_key(direct)):
		return direct
	var best := Vector2i(999999, 999999)
	var best_distance := INF
	for cell_id in _navigation_walkable_ids:
		var center := Vector2(
			(float(cell_id.x) + 0.5) * cell_size,
			(float(cell_id.y) + 0.5) * cell_size
		)
		var distance := point.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best = cell_id
	return best


func _cell_key(cell_id: Vector2i) -> String:
	return "%d:%d" % [cell_id.x, cell_id.y]


func _get_authority_position_counts() -> Dictionary:
	var counts := {
		AUTHORITY_WORKSTATION: 0,
		AUTHORITY_DEFENSE_SLOT: 0,
		"total": 0
	}
	var contracts: Dictionary = _layout.get("building_spatial", {})
	for raw_building_id in contracts.keys():
		var contract: Dictionary = contracts[raw_building_id]
		for raw_position in contract.get("positions", []):
			var position: Dictionary = raw_position
			var authority := str(position.get("authority", ""))
			if counts.has(authority):
				counts[authority] = int(counts[authority]) + 1
				counts["total"] = int(counts["total"]) + 1
	return counts


func _validate_combat_spatial_config() -> void:
	var combat_spatial := _layout.get("combat_spatial", {}) as Dictionary
	var friendly_response := combat_spatial.get("friendly_station_response", {}) as Dictionary
	var proactive_strategies: Variant = friendly_response.get("proactive_strategy_ids", [])
	var avoidance_reentry := friendly_response.get("outside_avoidance_reentry", {}) as Dictionary
	if (
		str(friendly_response.get("schema_version", "")) != "friendly_station_response_v4"
		or float(friendly_response.get("normal_contact_range", 0.0)) <= 0.0
		or str(friendly_response.get("combat_targeting_schema", "")) != "friendly_enemy_presence_lock_v1"
		or float(friendly_response.get("combat_target_detection_range", 0.0)) <= 0.0
		or str(friendly_response.get("inside_station_target_scope", "")) != "entire_station"
		or str(friendly_response.get("avoidance_policy_schema", "")) != "weighted_enemy_repulsion_v1"
		or float(friendly_response.get("avoidance_detection_range_margin", 0.0)) <= 0.0
		or str(friendly_response.get("avoidance_weight_formula", "")) != "inverse_distance_power"
		or float(friendly_response.get("avoidance_weight_exponent", 0.0)) <= 0.0
		or float(friendly_response.get("avoidance_min_weight_distance", 0.0)) <= 0.0
		or float(friendly_response.get("avoidance_boundary_inset", 0.0)) <= 0.0
		or str(friendly_response.get("keep_distance_retreat_policy_schema", "")) != "weighted_close_threat_retreat_v1"
		or float(friendly_response.get("keep_distance_retreat_trigger_range_ratio", 0.0)) <= 0.0
		or float(friendly_response.get("keep_distance_retreat_trigger_range_ratio", 0.0)) >= 1.0
		or float(friendly_response.get("keep_distance_retreat_segment_range_ratio", 0.0)) <= 0.0
		or float(friendly_response.get("keep_distance_retreat_arrival_tolerance", 0.0)) <= 0.0
		or str(avoidance_reentry.get("schema", "")) != "front_gate_inside_reentry_v1"
		or str(avoidance_reentry.get("gate_id", "")) != "front_gate"
		or float(avoidance_reentry.get("inside_offset", 0.0)) <= 0.0
		or float(friendly_response.get("avoidance_min_safe_distance", 0.0)) <= 0.0
		or float(friendly_response.get("avoidance_ranged_safe_margin", 0.0)) <= 0.0
		or not proactive_strategies is Array
		or (proactive_strategies as Array).is_empty()
	):
		_configuration_errors.append("invalid_friendly_station_response_contract")
	var route := combat_spatial.get("enemy_route", {}) as Dictionary
	if route.is_empty():
		_configuration_errors.append("enemy_route_missing")
		return
	if (
		not _is_v2_array(route.get("spawn_zone_center", null))
		or not _is_v2_array(route.get("spawn_zone_size", null))
		or float(route.get("approach_half_width", 0.0)) < 2.0
	):
		_configuration_errors.append("invalid_enemy_route_geometry")
	var stages := route.get("stages", []) as Array
	var stage_ids: Dictionary = {}
	var ordered_ids: Array[String] = []
	for raw_stage in stages:
		if not raw_stage is Dictionary:
			_configuration_errors.append("invalid_enemy_route_stage")
			continue
		var stage := raw_stage as Dictionary
		var stage_id := str(stage.get("id", ""))
		if stage_id.is_empty() or stage_ids.has(stage_id) or not _is_v2_array(stage.get("point", null)):
			_configuration_errors.append("invalid_or_duplicate_enemy_route_stage:%s" % stage_id)
			continue
		stage_ids[stage_id] = true
		ordered_ids.append(stage_id)
	var required_order: Array[String] = [
		"spawn", "reveal", "approach_mid", "contact", "front_gate",
		"gate_turn", "north_junction", "plaza_junction", "warehouse", "main_hall"
	]
	if ordered_ids != required_order:
		_configuration_errors.append("enemy_route_stage_order_mismatch")
	var stop_stage_id := str(route.get("pilot_stop_stage_id", ""))
	if stop_stage_id != "front_gate" or not stage_ids.has(stop_stage_id):
		_configuration_errors.append("invalid_enemy_pilot_stop_stage")
	var friendly_rally := combat_spatial.get("friendly_rally", {}) as Dictionary
	if (
		str(friendly_rally.get("schema_version", "")) != "friendly_rally_v1"
		or not _is_v2_array(friendly_rally.get("center", null))
		or not _is_v2_array(friendly_rally.get("area_size", null))
		or not _is_v2_array(friendly_rally.get("enemy_direction", null))
		or float(friendly_rally.get("line_spacing", 0.0)) <= 0.0
		or float(friendly_rally.get("line_row_spacing", 0.0)) <= 0.0
		or int(friendly_rally.get("max_line_columns", 0)) <= 0
		or float(friendly_rally.get("cavalry_lateral_offset", 0.0)) <= 0.0
		or float(friendly_rally.get("cavalry_depth_spacing", 0.0)) <= 0.0
	):
		_configuration_errors.append("invalid_friendly_rally_contract")
	var gm_enemy_spawn := combat_spatial.get("gm_enemy_spawn", {}) as Dictionary
	if (
		str(gm_enemy_spawn.get("schema_version", "")) != "gm_enemy_spawn_v1"
		or not _is_v2_array(gm_enemy_spawn.get("formation_front_center", null))
		or not _is_v2_array(gm_enemy_spawn.get("area_center", null))
		or not _is_v2_array(gm_enemy_spawn.get("area_size", null))
		or not _is_v2_array(gm_enemy_spawn.get("travel_direction", null))
		or int(gm_enemy_spawn.get("columns", 0)) <= 0
	):
		_configuration_errors.append("invalid_gm_enemy_spawn_contract")


func _validate_natural_collision_config() -> void:
	var config := _layout.get("natural_collision", {}) as Dictionary
	if str(config.get("schema_version", "")) != "natural_collision_v1":
		_configuration_errors.append("unexpected_natural_collision_schema")
	if not bool(config.get("simplified_compound_boundaries", false)):
		_configuration_errors.append("natural_collision_must_be_compound")
	var barriers := config.get("barriers", []) as Array
	if barriers.size() != 24:
		_configuration_errors.append("expected_24_natural_barriers")
	var ids: Dictionary = {}
	var terrain := _layout.get("terrain", {}) as Dictionary
	var terrain_center := _v2(terrain.get("center", [0.0, 0.0]))
	var terrain_size := _v2(terrain.get("size", [0.0, 0.0]))
	var terrain_min := terrain_center - terrain_size * 0.5
	var terrain_max := terrain_center + terrain_size * 0.5
	for raw_barrier in barriers:
		if not raw_barrier is Dictionary:
			_configuration_errors.append("invalid_natural_barrier")
			continue
		var barrier := raw_barrier as Dictionary
		var barrier_id := str(barrier.get("id", ""))
		if barrier_id.is_empty() or ids.has(barrier_id):
			_configuration_errors.append("invalid_or_duplicate_natural_barrier:%s" % barrier_id)
		ids[barrier_id] = true
		var kind := str(barrier.get("kind", ""))
		if kind not in ["river_cliff", "rock_ridge", "dense_forest"]:
			_configuration_errors.append("invalid_natural_barrier_kind:%s" % barrier_id)
		if not _is_v2_array(barrier.get("from", null)) or not _is_v2_array(barrier.get("to", null)):
			_configuration_errors.append("invalid_natural_barrier_geometry:%s" % barrier_id)
			continue
		var from_point := _v2(barrier.get("from", []))
		var to_point := _v2(barrier.get("to", []))
		var width := float(barrier.get("width", 0.0))
		var height := float(barrier.get("height", 0.0))
		if from_point.distance_to(to_point) <= 1.0 or width <= 0.0 or height < 1.8:
			_configuration_errors.append("invalid_natural_barrier_dimensions:%s" % barrier_id)
		if (
			from_point.x < terrain_min.x or from_point.x > terrain_max.x
			or from_point.y < terrain_min.y or from_point.y > terrain_max.y
			or to_point.x < terrain_min.x or to_point.x > terrain_max.x
			or to_point.y < terrain_min.y or to_point.y > terrain_max.y
		):
			_configuration_errors.append("natural_barrier_outside_terrain:%s" % barrier_id)
		for raw_road in _layout.get("roads", []):
			var road := raw_road as Dictionary
			var road_from := _v2(road.get("from", []))
			var road_to := _v2(road.get("to", []))
			var required_clearance := width * 0.5 + float(road.get("width", 0.0)) * 0.5 + 0.25
			if _segment_distance_2d(from_point, to_point, road_from, road_to) < required_clearance:
				_configuration_errors.append("natural_barrier_overlaps_road:%s:%s" % [barrier_id, str(road.get("id", ""))])


func _segment_distance_2d(a_from: Vector2, a_to: Vector2, b_from: Vector2, b_to: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a_from, a_to, b_from, b_to) != null:
		return 0.0
	return minf(
		minf(
			a_from.distance_to(Geometry2D.get_closest_point_to_segment(a_from, b_from, b_to)),
			a_to.distance_to(Geometry2D.get_closest_point_to_segment(a_to, b_from, b_to))
		),
		minf(
			b_from.distance_to(Geometry2D.get_closest_point_to_segment(b_from, a_from, a_to)),
			b_to.distance_to(Geometry2D.get_closest_point_to_segment(b_to, a_from, a_to))
		)
	)


func _validate_physics_navigation_config() -> void:
	var units := _physics_navigation.get("units", {}) as Dictionary
	if not is_equal_approx(float(units.get("godot_units_per_meter", 0.0)), 1.0):
		_configuration_errors.append("physics_units_must_be_one_meter")
	var layers := _physics_navigation.get("collision_layers", {}) as Dictionary
	var required_layers := {
		"world_static": 1,
		"actor_body": 2,
		"interaction": 4
	}
	for layer_id in required_layers.keys():
		var layer: Dictionary = layers.get(layer_id, {})
		if int(layer.get("bitmask", 0)) != int(required_layers[layer_id]):
			_configuration_errors.append("invalid_collision_layer:%s" % layer_id)
	var profiles := _physics_navigation.get("actor_profiles", {}) as Dictionary
	for profile_id in ["npc", "enemy_foot", "enemy_mounted"]:
		var profile: Dictionary = profiles.get(profile_id, {})
		if float(profile.get("radius", 0.0)) <= 0.0 or float(profile.get("height", 0.0)) <= float(profile.get("radius", 0.0)) * 2.0:
			_configuration_errors.append("invalid_actor_profile:%s" % profile_id)
	var formal_wave_spawn := _physics_navigation.get("formal_wave_spawn", {}) as Dictionary
	if (
		int(formal_wave_spawn.get("columns", 0)) <= 0
		or float(formal_wave_spawn.get("minimum_spacing", 0.0)) <= 0.0
		or float(formal_wave_spawn.get("minimum_capsule_clearance", -1.0)) < 0.0
		or int(formal_wave_spawn.get("ai_updates_per_frame", 0)) <= 0
		or int(formal_wave_spawn.get("contact_update_interval_frames", 0)) <= 0
		or int(formal_wave_spawn.get("avoidance_update_interval_frames", 0)) <= 0
	):
		_configuration_errors.append("invalid_formal_wave_spawn_contract")
	var npc_profile: Dictionary = profiles.get("npc", {})
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	if float(structural.get("wall_thickness", 0.0)) <= 0.0:
		_configuration_errors.append("invalid_structural_wall_thickness")
	if float(structural.get("building_door_clear_width", 0.0)) < float(npc_profile.get("radius", 0.0)) * 2.0 + 0.2:
		_configuration_errors.append("building_door_too_narrow_for_npc")
	var nav_mesh := _physics_navigation.get("navigation_mesh", {}) as Dictionary
	if (
		float(nav_mesh.get("production_cell_size", 0.0)) <= 0.0
		or float(nav_mesh.get("production_cell_size", 1.0)) > float(nav_mesh.get("agent_radius", 0.0))
		or not is_equal_approx(float(nav_mesh.get("agent_radius", 0.0)), float(npc_profile.get("radius", 0.0)))
	):
		_configuration_errors.append("invalid_navigation_mesh_profile")
	var baked_agent_radius := float(nav_mesh.get("baked_agent_radius", 0.0))
	var production_cell_size := float(nav_mesh.get("production_cell_size", 0.0))
	if (
		baked_agent_radius < float(nav_mesh.get("agent_radius", 0.0))
		or production_cell_size <= 0.0
		or not is_equal_approx(fmod(baked_agent_radius, production_cell_size), 0.0)
	):
		_configuration_errors.append("invalid_voxel_aligned_agent_radius")
	if (
		str(nav_mesh.get("source_geometry_mode", "")) != "static_colliders"
		or str(nav_mesh.get("source_group_name", "")).is_empty()
		or float(nav_mesh.get("baking_floor_depth", 0.0)) <= 0.0
		or float(nav_mesh.get("baking_height_max", 0.0)) <= float(nav_mesh.get("baking_height_min", 0.0))
	):
		_configuration_errors.append("invalid_navigation_bake_source")
	var agent := _physics_navigation.get("navigation_agent", {}) as Dictionary
	if (
		not bool(agent.get("avoidance_enabled", false))
		or int(agent.get("max_neighbors", 0)) <= 0
		or float(agent.get("avoidance_radius_padding", -1.0)) < 0.0
	):
		_configuration_errors.append("navigation_avoidance_must_be_enabled")
	var recovery := _physics_navigation.get("stuck_recovery", {}) as Dictionary
	if int(recovery.get("maximum_repaths_per_target", 0)) <= 0 or float(recovery.get("fail_after_seconds", 0.0)) <= 0.0:
		_configuration_errors.append("invalid_stuck_recovery_contract")


func _validate_fixture_layouts_config() -> void:
	var units := _fixture_layouts.get("units", {}) as Dictionary
	if not is_equal_approx(float(units.get("godot_units_per_meter", 0.0)), 1.0):
		_configuration_errors.append("fixture_units_must_be_one_meter")
	var fixture_buildings := _fixture_layouts.get("buildings", {}) as Dictionary
	for required_building_id in [
		"blacksmith", "clinic", "dormitory", "dining_hall", "tavern", "garden",
		"training_ground", "stable", "chapel", "workshop", "main_hall", "warehouse"
	]:
		if not fixture_buildings.has(required_building_id):
			_configuration_errors.append("missing_building_fixture_contract:%s" % required_building_id)
	if fixture_buildings.is_empty():
		return
	var fixture_ids: Dictionary = {}
	var actor_profiles := _physics_navigation.get("actor_profiles", {}) as Dictionary
	var npc_profile := actor_profiles.get("npc", {}) as Dictionary
	var npc_radius := float(npc_profile.get("radius", 0.35))
	var npc_height := float(npc_profile.get("height", 1.6))
	for raw_building_id in fixture_buildings.keys():
		var building_id := str(raw_building_id)
		var building := _find_building_definition(building_id)
		if building.is_empty():
			_configuration_errors.append("fixture_building_missing:%s" % building_id)
			continue
		var building_fixtures: Dictionary = fixture_buildings[raw_building_id]
		var maximum_level := int(building_fixtures.get("maximum_level", 0))
		var envelope := _v2(building.get("envelope_size", [0.0, 0.0]))
		var fixtures := building_fixtures.get("fixtures", []) as Array
		var mapped_positions: Dictionary = {}
		var horse_anchor_ids: Dictionary = {}
		for raw_fixture in fixtures:
			if not raw_fixture is Dictionary:
				_configuration_errors.append("invalid_fixture:%s" % building_id)
				continue
			var fixture: Dictionary = raw_fixture
			var fixture_id := str(fixture.get("id", ""))
			if fixture_id.is_empty() or fixture_ids.has(fixture_id):
				_configuration_errors.append("invalid_or_duplicate_fixture:%s" % fixture_id)
			fixture_ids[fixture_id] = true
			if not _is_v2_array(fixture.get("center", null)) or not _is_v3_array(fixture.get("collision_size", null)):
				_configuration_errors.append("invalid_fixture_geometry:%s" % fixture_id)
				continue
			var center := _v2(fixture.get("center", []))
			var collision_size := _v3(fixture.get("collision_size", []))
			var rotation_radians := deg_to_rad(float(fixture.get("rotation_degrees", 0.0)))
			var rotated_half_extent := Vector2(
				absf(cos(rotation_radians)) * collision_size.x * 0.5
					+ absf(sin(rotation_radians)) * collision_size.z * 0.5,
				absf(sin(rotation_radians)) * collision_size.x * 0.5
					+ absf(cos(rotation_radians)) * collision_size.z * 0.5
			)
			if (
				collision_size.x <= 0.0
				or collision_size.y <= 0.0
				or collision_size.z <= 0.0
				or absf(center.x) + rotated_half_extent.x > envelope.x * 0.5 + 0.001
				or absf(center.y) + rotated_half_extent.y > envelope.y * 0.5 + 0.001
			):
				_configuration_errors.append("fixture_outside_envelope:%s" % fixture_id)
			var required_level := int(fixture.get("required_level", 0))
			if required_level < 1 or required_level > maximum_level:
				_configuration_errors.append("invalid_fixture_required_level:%s" % fixture_id)
			var asset_path := str(fixture.get("asset_path", ""))
			var primitive_visual := str(fixture.get("primitive_visual", ""))
			if asset_path.is_empty() == primitive_visual.is_empty():
				_configuration_errors.append("fixture_visual_source_must_be_unique:%s" % fixture_id)
			elif not asset_path.is_empty() and not ResourceLoader.exists(asset_path):
				_configuration_errors.append("fixture_asset_missing:%s" % fixture_id)
			var collision_mode := str(fixture.get("collision_mode", "solid_box"))
			if collision_mode not in ["solid_box", "garden_u_border", "stable_open_bay"]:
				_configuration_errors.append("invalid_fixture_collision_mode:%s" % fixture_id)
			elif collision_mode == "garden_u_border":
				var border_thickness := float(fixture.get("border_thickness", 0.0))
				if border_thickness <= 0.0 or border_thickness * 2.0 >= minf(collision_size.x, collision_size.z):
					_configuration_errors.append("invalid_fixture_border_thickness:%s" % fixture_id)
			elif collision_mode == "stable_open_bay":
				var border_thickness := float(fixture.get("border_thickness", 0.0))
				if border_thickness <= 0.0 or border_thickness * 2.0 >= minf(collision_size.x, collision_size.z):
					_configuration_errors.append("invalid_fixture_border_thickness:%s" % fixture_id)
				if str(fixture.get("opening_side", "")) not in ["left", "right"]:
					_configuration_errors.append("invalid_stable_bay_opening:%s" % fixture_id)
			var arrival_mode := str(fixture.get("arrival_mode", "stand"))
			if arrival_mode not in ["stand", "mount_after_arrival"]:
				_configuration_errors.append("invalid_fixture_arrival_mode:%s" % fixture_id)
			var occupant_anchor := fixture.get("occupant_anchor", {}) as Dictionary
			if arrival_mode == "mount_after_arrival" and occupant_anchor.is_empty():
				_configuration_errors.append("fixture_occupant_anchor_missing:%s" % fixture_id)
			if not occupant_anchor.is_empty():
				if not _is_v2_array(occupant_anchor.get("center", null)):
					_configuration_errors.append("invalid_fixture_occupant_anchor:%s" % fixture_id)
				else:
					var anchor_center := _v2(occupant_anchor.get("center", []))
					if not _point_in_rotated_rect(
						anchor_center,
						center,
						Vector2(collision_size.x, collision_size.z),
						float(fixture.get("rotation_degrees", 0.0))
					):
						_configuration_errors.append("fixture_occupant_anchor_outside_collision:%s" % fixture_id)
					var collision_top := float(fixture.get("collision_center_y", collision_size.y * 0.5)) + collision_size.y * 0.5
					if float(occupant_anchor.get("y", -1.0)) < collision_top - 0.001:
						_configuration_errors.append("fixture_occupant_anchor_below_surface:%s" % fixture_id)
					if str(occupant_anchor.get("pose", "")).is_empty():
						_configuration_errors.append("fixture_occupant_pose_missing:%s" % fixture_id)
				if occupant_anchor.has("footprint_size"):
					if not _is_v2_array(occupant_anchor.get("footprint_size", null)):
						_configuration_errors.append("invalid_fixture_occupant_footprint:%s" % fixture_id)
					else:
						var footprint_size := _v2(occupant_anchor.get("footprint_size", []))
						if footprint_size.x <= 0.0 or footprint_size.y <= 0.0:
							_configuration_errors.append("invalid_fixture_occupant_footprint:%s" % fixture_id)
			var horse_anchor := fixture.get("horse_anchor", {}) as Dictionary
			if not horse_anchor.is_empty():
				var horse_anchor_id := str(horse_anchor.get("id", ""))
				if horse_anchor_id.is_empty() or horse_anchor_ids.has(horse_anchor_id):
					_configuration_errors.append("invalid_or_duplicate_horse_anchor:%s" % horse_anchor_id)
				horse_anchor_ids[horse_anchor_id] = fixture_id
				if not _is_v2_array(horse_anchor.get("center", null)) or not _is_v2_array(horse_anchor.get("footprint_size", null)):
					_configuration_errors.append("invalid_fixture_horse_anchor:%s" % fixture_id)
				else:
					var anchor_center := _v2(horse_anchor.get("center", []))
					var footprint_size := _v2(horse_anchor.get("footprint_size", []))
					var pickup_center_valid := _is_v2_array(horse_anchor.get("pickup_center", null))
					if building_id == "stable" and not pickup_center_valid:
						_configuration_errors.append("stable_horse_pickup_center_missing:%s" % fixture_id)
					elif pickup_center_valid:
						var pickup_center := _v2(horse_anchor.get("pickup_center", []))
						var pickup_distance := pickup_center.distance_to(anchor_center)
						var opening_side := str(fixture.get("opening_side", ""))
						var pickup_on_open_side := (
							pickup_center.x > anchor_center.x
							if opening_side == "right"
							else pickup_center.x < anchor_center.x
						)
						if pickup_distance < 1.2 or pickup_distance > 2.3 or not pickup_on_open_side:
							_configuration_errors.append("invalid_stable_horse_pickup_center:%s" % fixture_id)
					if footprint_size.x < 1.3 or footprint_size.y < 2.1:
						_configuration_errors.append("fixture_horse_anchor_too_small:%s" % fixture_id)
					if not _point_in_rotated_rect(anchor_center, center, Vector2(collision_size.x, collision_size.z), float(fixture.get("rotation_degrees", 0.0))):
						_configuration_errors.append("fixture_horse_anchor_outside_bay:%s" % fixture_id)
		for raw_fixture in fixtures:
			if not raw_fixture is Dictionary:
				continue
			var fixture: Dictionary = raw_fixture
			var fixture_id := str(fixture.get("id", ""))
			var workstation_id := str(fixture.get("workstation_id", ""))
			var spatial_position_id := str(fixture.get("spatial_position_id", ""))
			if not workstation_id.is_empty() and not spatial_position_id.is_empty():
				_configuration_errors.append("fixture_position_source_must_be_unique:%s" % fixture_id)
				continue
			var position_id := workstation_id if not workstation_id.is_empty() else spatial_position_id
			if position_id.is_empty():
				continue
			var position_key := "%s:%s" % [building_id, position_id]
			if mapped_positions.has(position_key):
				_configuration_errors.append("duplicate_fixture_position:%s" % position_id)
			mapped_positions[position_key] = fixture_id
			var position := _find_position_definition(building_id, position_id)
			if position.is_empty():
				_configuration_errors.append("fixture_position_missing:%s" % position_id)
				continue
			var position_authority := str(position.get("authority", ""))
			if not spatial_position_id.is_empty():
				if position_authority != AUTHORITY_DEFENSE_SLOT:
					_configuration_errors.append("fixture_spatial_position_not_defense_slot:%s" % position_id)
				if not (fixture.get("npc_stand", {}) as Dictionary).is_empty():
					_configuration_errors.append("defense_slot_must_not_have_npc_stand:%s" % position_id)
				continue
			if position_authority != AUTHORITY_WORKSTATION:
				_configuration_errors.append("fixture_workstation_authority_mismatch:%s" % position_id)
			var npc_stand := fixture.get("npc_stand", {}) as Dictionary
			if not _is_v2_array(npc_stand.get("center", null)):
				_configuration_errors.append("fixture_workstation_stand_missing:%s" % position_id)
				continue
			var stand_center := _v2(npc_stand.get("center", []))
			var clearance_radius := float(npc_stand.get("clearance_radius", 0.0))
			if clearance_radius < npc_radius:
				_configuration_errors.append("fixture_stand_clearance_too_small:%s" % position_id)
			var action_clearance_size := _v2(npc_stand.get("action_clearance_size", [0.0, 0.0]))
			if building_id == "training_ground":
				if action_clearance_size.x < 3.0 or action_clearance_size.y < 3.0:
					_configuration_errors.append("training_action_clearance_too_small:%s" % position_id)
				elif (
					stand_center.distance_to(_v2(position.get("center", []))) > 0.001
					or action_clearance_size.x > _v2(position.get("size", [])).x + 0.001
					or action_clearance_size.y > _v2(position.get("size", [])).y + 0.001
				):
					_configuration_errors.append("training_action_clearance_outside_workstation:%s" % position_id)
			var stand_scope := str(npc_stand.get("scope", "workstation"))
			if stand_scope == "workstation":
				if not _point_in_rotated_rect(
					stand_center,
					_v2(position.get("center", [])),
					_v2(position.get("size", [])),
					0.0,
					clearance_radius
				):
					_configuration_errors.append("fixture_stand_outside_workstation:%s" % position_id)
			elif stand_scope == "building":
				if not _point_in_rotated_rect(stand_center, Vector2.ZERO, envelope, 0.0, clearance_radius):
					_configuration_errors.append("fixture_stand_outside_building:%s" % position_id)
			else:
				_configuration_errors.append("invalid_fixture_stand_scope:%s" % position_id)
			for raw_other_fixture in fixtures:
				if not raw_other_fixture is Dictionary:
					continue
				var other_fixture: Dictionary = raw_other_fixture
				var other_size := _v3(other_fixture.get("collision_size", [0.0, 0.0, 0.0]))
				var other_bottom := float(other_fixture.get("collision_center_y", other_size.y * 0.5)) - other_size.y * 0.5
				if other_bottom >= npc_height + 0.05:
					continue
				if _point_overlaps_fixture_collision(stand_center, other_fixture, clearance_radius):
					_configuration_errors.append(
						"fixture_stand_overlaps_collision:%s:%s" % [position_id, str(other_fixture.get("id", ""))]
					)
		var spatial_contract: Dictionary = (_layout.get("building_spatial", {}) as Dictionary).get(building_id, {})
		for raw_position in spatial_contract.get("positions", []):
			var position: Dictionary = raw_position
			var position_id := str(position.get("id", ""))
			if not mapped_positions.has("%s:%s" % [building_id, position_id]):
				_configuration_errors.append("building_position_fixture_missing:%s:%s" % [building_id, position_id])
		if mapped_positions.size() != (spatial_contract.get("positions", []) as Array).size():
			_configuration_errors.append("fixture_position_count_mismatch:%s" % building_id)
		if building_id == "stable" and horse_anchor_ids.size() != 8:
			_configuration_errors.append("stable_horse_anchor_count_mismatch:%s" % horse_anchor_ids.size())


func _build_physics_navigation_snapshot() -> Dictionary:
	var category_counts: Dictionary = {}
	if is_instance_valid(_formal_root):
		for raw_body in _formal_root.find_children("*", "StaticBody3D", true, false):
			var body := raw_body as StaticBody3D
			var category := str(body.get_meta("collision_category", "unknown"))
			category_counts[category] = int(category_counts.get(category, 0)) + 1
	var layers := _physics_navigation.get("collision_layers", {}) as Dictionary
	var profiles := _physics_navigation.get("actor_profiles", {}) as Dictionary
	var formal_wave_spawn := _physics_navigation.get("formal_wave_spawn", {}) as Dictionary
	var structural := _physics_navigation.get("structural_collision", {}) as Dictionary
	var navigation_mesh := _physics_navigation.get("navigation_mesh", {}) as Dictionary
	var navigation_agent := _physics_navigation.get("navigation_agent", {}) as Dictionary
	var natural_boundary_count := 0
	for raw_category in category_counts.keys():
		if str(raw_category).begins_with("natural_"):
			natural_boundary_count += int(category_counts.get(raw_category, 0))
	return {
		"schema_version": str(_physics_navigation.get("schema_version", "")),
		"configuration_error_count": _configuration_errors.size(),
		"world_static_layer": int((layers.get("world_static", {}) as Dictionary).get("bitmask", 0)),
		"actor_body_layer": int((layers.get("actor_body", {}) as Dictionary).get("bitmask", 0)),
		"interaction_layer": int((layers.get("interaction", {}) as Dictionary).get("bitmask", 0)),
		"npc_profile": (profiles.get("npc", {}) as Dictionary).duplicate(true),
		"enemy_foot_profile": (profiles.get("enemy_foot", {}) as Dictionary).duplicate(true),
		"enemy_mounted_profile": (profiles.get("enemy_mounted", {}) as Dictionary).duplicate(true),
		"formal_wave_spawn": formal_wave_spawn.duplicate(true),
		"wall_thickness": float(structural.get("wall_thickness", 0.0)),
		"collision_margin": float(structural.get("collision_margin", 0.0)),
		"building_door_clear_width": float(structural.get("building_door_clear_width", 0.0)),
		"production_cell_size": float(navigation_mesh.get("production_cell_size", 0.0)),
		"avoidance_enabled": bool(navigation_agent.get("avoidance_enabled", false)),
		"avoidance_radius_padding": float(navigation_agent.get("avoidance_radius_padding", 0.0)),
		"avoidance_max_neighbors": int(navigation_agent.get("max_neighbors", 0)),
		"static_body_count": (
			_formal_root.find_children("*", "StaticBody3D", true, false).size()
			if is_instance_valid(_formal_root)
			else 0
		),
		"collision_shape_count": (
			_formal_root.find_children("*", "CollisionShape3D", true, false).size()
			if is_instance_valid(_formal_root)
			else 0
		),
		"collision_category_counts": category_counts,
		"building_shell_count": int(category_counts.get("building_wall", 0)),
		"building_interior_blocker_count": int(category_counts.get("building_interior_blocker", 0)),
		"station_wall_count": int(category_counts.get("station_wall", 0)),
		"gate_post_count": int(category_counts.get("gate_post", 0)),
		"building_fixture_count": int(category_counts.get("building_fixture", 0)),
		"natural_boundary_count": natural_boundary_count,
		"natural_collision_schema": str((_layout.get("natural_collision", {}) as Dictionary).get("schema_version", "")),
		"fixture_layouts_schema": str(_fixture_layouts.get("schema_version", "")),
		"fixture_workstation_stand_count": _get_fixture_workstation_stand_count(),
		"fixture_occupant_anchor_count": _get_fixture_occupant_anchor_count(),
		"fixture_horse_anchor_count": _get_fixture_horse_anchor_count(),
		"building_count": _building_roots.size(),
		"navigation_walkable_cell_count": _navigation_walkable_cells.size(),
		"navigation_enabled": _navigation_region.enabled if is_instance_valid(_navigation_region) else false,
		"production_navigation": _build_production_navigation_snapshot(),
		"live_actor_bodies_migrated": _default_formal_world_enabled,
		"staged": not _default_formal_world_enabled
	}


func _build_production_navigation_snapshot() -> Dictionary:
	var config: Dictionary = _physics_navigation.get("navigation_mesh", {})
	var mesh: NavigationMesh = (
		_navigation_region.navigation_mesh
		if is_instance_valid(_navigation_region)
		else null
	)
	return {
		"available": mesh != null,
		"navigation_kind": (
			str(_navigation_region.get_meta("navigation_kind", ""))
			if is_instance_valid(_navigation_region)
			else ""
		),
		"source_geometry_mode": str(config.get("source_geometry_mode", "")),
		"source_group_name": str(config.get("source_group_name", "")),
		"source_static_body_count": get_tree().get_nodes_in_group(
			str(config.get("source_group_name", "formal_navigation_source"))
		).size(),
		"cell_size": mesh.cell_size if mesh != null else 0.0,
		"cell_height": mesh.cell_height if mesh != null else 0.0,
		"requested_agent_radius": float(config.get("agent_radius", 0.0)),
		"agent_radius": mesh.agent_radius if mesh != null else 0.0,
		"agent_height": mesh.agent_height if mesh != null else 0.0,
		"geometry_parsed_geometry_type": mesh.geometry_parsed_geometry_type if mesh != null else -1,
		"geometry_source_geometry_mode": mesh.geometry_source_geometry_mode if mesh != null else -1,
		"geometry_collision_mask": mesh.geometry_collision_mask if mesh != null else 0,
		"vertex_count": mesh.get_vertices().size() if mesh != null else 0,
		"polygon_count": mesh.get_polygon_count() if mesh != null else 0,
		"bake_msec": _production_navigation_bake_msec,
		"building_door_link_count": _building_navigation_links.size(),
		"enabled_building_door_link_count": _count_enabled_building_navigation_links(),
		"contract_grid_cell_size": float((_layout.get("navigation", {}) as Dictionary).get("cell_size", 0.0)),
		"contract_walkable_cell_count": _navigation_walkable_cells.size(),
		"production_bounds": (_layout.get("navigation", {}) as Dictionary).get("production_bounds", []),
		"enemy_exterior_mode": str((_layout.get("navigation", {}) as Dictionary).get("enemy_exterior_mode", "")),
		"roads_affect_navigation": bool((_layout.get("navigation", {}) as Dictionary).get("roads_affect_navigation", true)),
		"enabled": _navigation_region.enabled if is_instance_valid(_navigation_region) else false,
		"enemy_approach_region_available": is_instance_valid(_enemy_approach_navigation_region),
		"enemy_approach_region_enabled": (
			_enemy_approach_navigation_region.enabled
			if is_instance_valid(_enemy_approach_navigation_region)
			else false
		),
		"enemy_approach_vertex_count": _enemy_approach_vertex_count,
		"enemy_approach_polygon_count": _enemy_approach_polygon_count,
		"rear_escape_region_available": is_instance_valid(_rear_escape_navigation_region),
		"rear_escape_region_enabled": (
			_rear_escape_navigation_region.enabled
			if is_instance_valid(_rear_escape_navigation_region)
			else false
		),
		"rear_escape_vertex_count": _rear_escape_vertex_count,
		"rear_escape_polygon_count": _rear_escape_polygon_count,
		"rear_escape_route_length": _rear_escape_route_length,
		"rear_escape_link_available": is_instance_valid(_rear_escape_navigation_link),
		"rear_escape_link_enabled": (
			_rear_escape_navigation_link.enabled
			if is_instance_valid(_rear_escape_navigation_link)
			else false
		),
		"dedicated_navigation_map": _production_navigation_map.is_valid(),
		"staged": not _default_formal_world_enabled,
		"live_default": _default_formal_world_enabled
	}


func _count_enabled_building_navigation_links() -> int:
	var result := 0
	for link in _building_navigation_links:
		if is_instance_valid(link) and link.enabled:
			result += 1
	return result


func _is_v2_array(value: Variant) -> bool:
	return value is Array and value.size() >= 2


func _is_v3_array(value: Variant) -> bool:
	return value is Array and value.size() >= 3


func _add_segment(
	parent: Node3D,
	node_name: String,
	from_point: Vector2,
	to_point: Vector2,
	width: float,
	height: float,
	color: Color,
	y: float
) -> MeshInstance3D:
	var delta := to_point - from_point
	var middle := (from_point + to_point) * 0.5
	var instance := _add_box(
		parent,
		node_name,
		Vector3(middle.x, y, middle.y),
		Vector3(width, height, delta.length()),
		color
	)
	instance.rotation.y = atan2(delta.x, delta.y)
	return instance


func _add_box(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	size: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name.validate_node_name()
	instance.position = center
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if color.a >= 0.99
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(instance)
	return instance


func _add_swallowtail_flag(
	parent: Node3D,
	node_name: String,
	origin: Vector3,
	size: Vector2,
	color: Color
) -> MeshInstance3D:
	var half_height := size.y * 0.5
	var inner_x := size.x * 0.72
	var vertices := PackedVector3Array([
		Vector3(0.0, half_height, 0.0),
		Vector3(inner_x, half_height, 0.025),
		Vector3(size.x, half_height * 0.84, -0.025),
		Vector3(inner_x, 0.0, 0.045),
		Vector3(size.x, -half_height * 0.84, -0.025),
		Vector3(inner_x, -half_height, 0.025),
		Vector3(0.0, -half_height, 0.0)
	])
	var normals := PackedVector3Array()
	for _index in vertices.size():
		normals.append(Vector3(0.0, 0.0, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([
		0, 1, 5,
		0, 5, 6,
		1, 2, 3,
		3, 4, 5
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var cloth_material := _material(color).duplicate() as StandardMaterial3D
	cloth_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, cloth_material)
	var instance := MeshInstance3D.new()
	instance.name = node_name.validate_node_name()
	instance.position = origin
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_cylinder(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	radius: float,
	height: float,
	color: Color
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name.validate_node_name()
	instance.position = center
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_sphere(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	radius: float,
	color: Color
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.name = node_name.validate_node_name()
	instance.position = center
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _add_label(parent: Node3D, node_name: String, position: Vector3, text: String) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.position = position
	label.text = text
	label.pixel_size = 0.016
	label.font_size = 32
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	if node_name == "NameLabel":
		label.font_size = BUILDING_NAME_FONT_SIZE
		label.set_meta("formal_building_name_label", true)
		_building_name_labels.append(label)
		_apply_building_name_label_alpha_to(label, _building_name_label_alpha)
		var building_id := str(parent.get_meta("building_id", parent.get_meta("layout_id", "")))
		if building_id in STRATEGIC_WORLD_HEALTH_BUILDINGS:
			_ensure_strategic_building_health_bar(parent, label, building_id)
	return label


func _ensure_strategic_building_health_bar(parent: Node3D, label: Label3D, building_id: String) -> void:
	if _building_health_bars.has(building_id):
		return
	var bar := WORLD_HEALTH_BAR.new() as WorldHealthBar3D
	bar.name = "WorldHealthBar"
	bar.position = label.position + Vector3(0.0, 0.58, 0.0)
	parent.add_child(bar)
	bar.configure_size(2.4, 0.18)
	bar.visible = false
	_building_health_bars[building_id] = bar


func _refresh_strategic_building_health_bars() -> void:
	if _building_health_bars.is_empty():
		return
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var wartime := combat_system != null and combat_system.has_method("get_active_enemy_count") and int(combat_system.get_active_enemy_count()) > 0
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	for raw_building_id in _building_health_bars.keys():
		var building_id := str(raw_building_id)
		var bar := _building_health_bars.get(building_id) as WorldHealthBar3D
		if bar == null:
			continue
		var building: Dictionary = building_system.get_building(building_id) if building_system != null and building_system.has_method("get_building") else {}
		bar.set_health(
			int(building.get("hp", 0)),
			int(building.get("max_hp", 1)),
			wartime and not building.is_empty()
		)


func _update_building_name_label_visibility(delta: float) -> void:
	if _building_name_labels.is_empty():
		return
	var camera_rig := get_node_or_null(camera_rig_path) as Node3D
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera_rig == null or camera == null:
		_set_building_name_label_alpha(1.0)
		return
	var camera_moved := (
		not _camera_sample_valid
		or camera_rig.global_position.distance_squared_to(_last_camera_rig_position) > CAMERA_MOTION_EPSILON_SQUARED
		or camera.position.distance_squared_to(_last_camera_local_position) > CAMERA_MOTION_EPSILON_SQUARED
		or camera.rotation.distance_squared_to(_last_camera_rotation) > CAMERA_MOTION_EPSILON_SQUARED
		or not is_equal_approx(camera.fov, _last_camera_fov)
	)
	_last_camera_rig_position = camera_rig.global_position
	_last_camera_local_position = camera.position
	_last_camera_rotation = camera.rotation
	_last_camera_fov = camera.fov
	_camera_sample_valid = true
	if camera_moved:
		_camera_idle_seconds = 0.0
	else:
		_camera_idle_seconds += maxf(0.0, delta)
	var target_alpha := 0.0 if _camera_idle_seconds >= BUILDING_NAME_IDLE_DELAY_SECONDS else 1.0
	var speed := BUILDING_NAME_REVEAL_SPEED if target_alpha > _building_name_label_alpha else BUILDING_NAME_FADE_SPEED
	_set_building_name_label_alpha(move_toward(
		_building_name_label_alpha,
		target_alpha,
		speed * maxf(0.0, delta)
	))


func _set_building_name_label_alpha(alpha: float) -> void:
	_building_name_label_alpha = clampf(alpha, 0.0, 1.0)
	for label in _building_name_labels:
		if is_instance_valid(label):
			_apply_building_name_label_alpha_to(label, _building_name_label_alpha)


func _apply_building_name_label_alpha_to(label: Label3D, alpha: float) -> void:
	var text_color := label.modulate
	text_color.a = alpha
	label.modulate = text_color
	var outline_color := label.outline_modulate
	outline_color.a = alpha
	label.outline_modulate = outline_color


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_cache[key] = material
	return material


func _color(value: Variant, fallback: Color) -> Color:
	return Color.from_string(str(value), fallback)


func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		return Vector2(value.x, value.z)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
