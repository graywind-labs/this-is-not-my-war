extends Node3D

const EXPECTED_SCHEMA := "environment_art_v1"
const ART_REVISION := "t0135_p7"

var _environment_config: Dictionary = {}
var _layout: Dictionary = {}
var _zone_points: Dictionary = {}
var _zone_counts: Dictionary = {}
var _patch_counts: Dictionary = {}
var _river_channel_intrusions := 0
var _road_core_intrusions := 0
var _building_lot_intrusions := 0
var _plaza_intrusions := 0
var _minimum_formal_route_clearance := INF


func configure(environment_config: Dictionary, station_layout: Dictionary) -> void:
	_environment_config = environment_config.duplicate(true)
	_layout = station_layout.duplicate(true)
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_rebuild()


func get_debug_snapshot() -> Dictionary:
	var total_instances := 0
	for zone_counts in _zone_counts.values():
		for count in (zone_counts as Dictionary).values():
			total_instances += int(count)
	var total_patches := 0
	for count in _patch_counts.values():
		total_patches += int(count)
	return {
		"art_revision": ART_REVISION,
		"zone_counts": _zone_counts.duplicate(true),
		"patch_counts": _patch_counts.duplicate(true),
		"total_instance_count": total_instances,
		"total_patch_count": total_patches,
		"river_channel_intrusions": _river_channel_intrusions,
		"road_core_intrusions": _road_core_intrusions,
		"building_lot_intrusions": _building_lot_intrusions,
		"plaza_intrusions": _plaza_intrusions,
		"minimum_formal_route_clearance": _minimum_formal_route_clearance if is_finite(_minimum_formal_route_clearance) else 0.0,
		"has_collision": find_children("*", "CollisionShape3D", true, false).size() > 0,
		"has_static_body": find_children("*", "StaticBody3D", true, false).size() > 0,
		"has_navigation_region": find_children("*", "NavigationRegion3D", true, false).size() > 0,
		"has_interaction_area": find_children("*", "Area3D", true, false).size() > 0,
		"authority_role": "presentation_only"
	}


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_zone_points.clear()
	_zone_counts.clear()
	_patch_counts.clear()
	_river_channel_intrusions = 0
	_road_core_intrusions = 0
	_building_lot_intrusions = 0
	_plaza_intrusions = 0
	_minimum_formal_route_clearance = INF
	if str(_environment_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		return
	var config := _scatter_config()
	if config.is_empty():
		return
	for zone in ["riverbank", "mountain_foot", "forest_understory", "road_edge", "station_open"]:
		_zone_points[zone] = {"grass": [], "fern": [], "shrub": [], "rock": []}
		_zone_counts[zone] = {"grass": 0, "fern": 0, "shrub": 0, "rock": 0}
		_patch_counts[zone] = 0
	_generate_riverbank(config)
	_generate_mountain_foot(config)
	_generate_forest_understory(config)
	_generate_road_edges(config)
	_generate_station_open(config)
	_build_zone_multimeshes(config)
	_build_ground_transitions(config)
	set_meta("art_revision", ART_REVISION)
	set_meta("presentation_only", true)


func _generate_riverbank(config: Dictionary) -> void:
	var profile := ((_environment_config.get("terrain_topology", {}) as Dictionary).get("river_profile", []) as Array)
	if profile.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("riverbank_seed", 13531))
	var step_count := int(config.get("riverbank_steps_per_segment", 7))
	for segment_index in range(profile.size() - 1):
		var a := profile[segment_index] as Array
		var b := profile[segment_index + 1] as Array
		for step_index in step_count:
			var t := (float(step_index) + rng.randf_range(0.12, 0.88)) / float(step_count)
			var z := lerpf(float(a[0]), float(b[0]), t)
			var center_x := lerpf(float(a[1]), float(b[1]), t)
			var valley_width := lerpf(float(a[2]), float(b[2]), t)
			for side in [-1.0, 1.0]:
				var side_value := float(side)
				var edge_x: float = center_x + side_value * valley_width * 0.5
				var close_point := Vector2(edge_x + side_value * rng.randf_range(0.85, 2.75), z + rng.randf_range(-1.8, 1.8))
				_add_point("riverbank", "grass", close_point, rng.randf_range(0.88, 1.42), rng.randf_range(0.0, TAU), config)
				if rng.randf() < 0.74:
					_add_point("riverbank", "fern", close_point + Vector2(side_value * rng.randf_range(1.1, 3.8), rng.randf_range(-2.5, 2.5)), rng.randf_range(0.78, 1.28), rng.randf_range(0.0, TAU), config)
				if rng.randf() < 0.42:
					_add_point("riverbank", "shrub", Vector2(edge_x + side_value * rng.randf_range(4.0, 9.5), z + rng.randf_range(-3.0, 3.0)), rng.randf_range(0.66, 1.15), rng.randf_range(0.0, TAU), config)
				if rng.randf() < 0.62:
					_add_point("riverbank", "rock", Vector2(edge_x + side_value * rng.randf_range(0.9, 7.0), z + rng.randf_range(-2.6, 2.6)), rng.randf_range(0.60, 1.55), rng.randf_range(0.0, TAU), config)


func _generate_mountain_foot(config: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("mountain_foot_seed", 13532))
	var bounds := _rect_from_array(config.get("mountain_foot_bounds", [108.0, 188.0, -375.0, 415.0]))
	var target := int(config.get("mountain_foot_target", 720))
	var accepted := 0
	for _attempt in target * 12:
		if accepted >= target:
			break
		var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not _point_allowed_outside_station(point, config, 4.8):
			continue
		var roll := rng.randf()
		var kind := "rock" if roll < 0.26 else "shrub" if roll < 0.53 else "fern" if roll < 0.79 else "grass"
		_add_point("mountain_foot", kind, point, rng.randf_range(0.68, 1.55), rng.randf_range(0.0, TAU), config)
		accepted += 1


func _generate_forest_understory(config: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("forest_understory_seed", 13533))
	var bounds := _rect_from_array(config.get("full_map_bounds", [-350.0, 350.0, -390.0, 420.0]))
	var target := int(config.get("forest_understory_target", 2450))
	var accepted := 0
	for _attempt in target * 15:
		if accepted >= target:
			break
		var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not _point_allowed_outside_station(point, config, 5.0):
			continue
		var station_distance := _distance_to_station_polygon(point)
		var acceptance := clampf(inverse_lerp(8.0, 125.0, station_distance), 0.22, 1.0)
		if rng.randf() > acceptance:
			continue
		var roll := rng.randf()
		var kind := "fern" if roll < 0.38 else "grass" if roll < 0.66 else "shrub" if roll < 0.91 else "rock"
		_add_point("forest_understory", kind, point, rng.randf_range(0.62, 1.34), rng.randf_range(0.0, TAU), config)
		accepted += 1


func _generate_road_edges(config: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("road_edge_seed", 13534))
	for raw_road in _layout.get("roads", []):
		var road := raw_road as Dictionary
		var start := _v2(road.get("from", [0.0, 0.0]))
		var finish := _v2(road.get("to", [0.0, 0.0]))
		var delta := finish - start
		var length := delta.length()
		if length <= 0.01:
			continue
		var direction := delta / length
		var normal := Vector2(-direction.y, direction.x)
		var samples := maxi(1, int(floor(length / float(config.get("road_edge_spacing", 4.2)))))
		var width := float(road.get("width", 3.0))
		for sample_index in samples:
			var t := (float(sample_index) + rng.randf_range(0.16, 0.84)) / float(samples)
			for side in [-1.0, 1.0]:
				if rng.randf() > 0.72:
					continue
				var point: Vector2 = start + delta * t + direction * rng.randf_range(-0.8, 0.8) + normal * float(side) * (width * 0.5 + rng.randf_range(0.75, 1.85))
				if _point_overlaps_building_lot(point, 0.85) or _point_overlaps_public_clearance(point):
					continue
				if str(road.get("kind", "")) in ["main", "service"] and not _point_in_station(point):
					continue
				var kind := "rock" if rng.randf() < 0.16 else "fern" if rng.randf() < 0.27 else "grass"
				_add_point("road_edge", kind, point, rng.randf_range(0.50, 0.98), rng.randf_range(0.0, TAU), config)


func _generate_station_open(config: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("station_open_seed", 13535))
	var bounds := _polygon_bounds(_station_polygon())
	var target := int(config.get("station_open_target", 190))
	var accepted := 0
	for _attempt in target * 24:
		if accepted >= target:
			break
		var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not _point_in_station(point):
			continue
		if _point_overlaps_building_lot(point, 1.15) or _point_overlaps_any_road(point, 1.40) or _point_overlaps_public_clearance(point):
			continue
		var kind := "rock" if rng.randf() < 0.12 else "fern" if rng.randf() < 0.28 else "grass"
		_add_point("station_open", kind, point, rng.randf_range(0.42, 0.86), rng.randf_range(0.0, TAU), config)
		accepted += 1


func _add_point(zone: String, kind: String, point: Vector2, scale_value: float, rotation: float, config: Dictionary) -> void:
	if not _zone_points.has(zone):
		return
	# Scatter is visual density, never a replacement for a readable road or a
	# building apron. This final shared guard also catches road intersections
	# that a source-road offset alone cannot see.
	if _point_overlaps_any_road(point, 0.15) or _point_overlaps_building_lot(point, 0.0) or _point_overlaps_public_clearance(point):
		return
	var entry := {
		"point": point,
		"height": _terrain_height(point),
		"scale": scale_value,
		"rotation": rotation,
		"stretch": 0.78 + _unit_noise(point, 74) * 0.50
	}
	((_zone_points[zone] as Dictionary)[kind] as Array).append(entry)
	(_zone_counts[zone] as Dictionary)[kind] = int((_zone_counts[zone] as Dictionary)[kind]) + 1
	_audit_point(zone, point, config)


func _audit_point(zone: String, point: Vector2, config: Dictionary) -> void:
	var river_edges := _river_edges_at(point.y)
	if river_edges.size() >= 4 and point.x > float(river_edges[0]) and point.x < float(river_edges[3]):
		_river_channel_intrusions += 1
	if _point_overlaps_any_road(point, 0.15):
		_road_core_intrusions += 1
	if _point_overlaps_building_lot(point, 0.0):
		_building_lot_intrusions += 1
	var plaza := _public_location("plaza")
	if not plaza.is_empty() and point.distance_to(_v2(plaza.get("position", [0.0, 10.0]))) < float(plaza.get("radius", 4.0)) + 2.4:
		_plaza_intrusions += 1
	if zone in ["riverbank", "mountain_foot", "forest_understory"]:
		_minimum_formal_route_clearance = minf(_minimum_formal_route_clearance, _distance_to_formal_routes(point, config))


func _build_zone_multimeshes(config: Dictionary) -> void:
	var palettes := config.get("zone_palettes", {}) as Dictionary
	for zone in _zone_points.keys():
		var zone_root := Node3D.new()
		zone_root.name = str(zone).to_pascal_case()
		zone_root.set_meta("scatter_zone", zone)
		add_child(zone_root)
		var palette := palettes.get(zone, {}) as Dictionary
		for kind in ["grass", "fern", "shrub", "rock"]:
			var points := (_zone_points[zone] as Dictionary)[kind] as Array
			if points.is_empty():
				continue
			var color := Color.from_string(str(palette.get(kind, _fallback_color(kind))), Color(_fallback_color(kind)))
			var mesh := _make_scatter_mesh(kind, color)
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh
			multimesh.instance_count = points.size()
			for index in points.size():
				var entry := points[index] as Dictionary
				var point := entry["point"] as Vector2
				var scale_value := float(entry["scale"])
				var stretch := float(entry["stretch"])
				var height_scale := stretch if kind in ["grass", "fern"] else 0.82 + stretch * 0.20
				var horizontal_scale := 0.72 + stretch * 0.24
				var basis := Basis.from_euler(Vector3(0.0, float(entry["rotation"]), 0.0)).scaled(Vector3(scale_value * horizontal_scale, scale_value * height_scale, scale_value * (1.12 - horizontal_scale * 0.18)))
				multimesh.set_instance_transform(index, Transform3D(basis, Vector3(point.x, float(entry["height"]) + 0.025, point.y)))
			var instance := MultiMeshInstance3D.new()
			instance.name = "%sScatter" % kind.capitalize()
			instance.multimesh = multimesh
			instance.custom_aabb = AABB(Vector3(-390.0, -3.0, -430.0), Vector3(780.0, 58.0, 900.0))
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind in ["grass", "fern"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			instance.set_meta("presentation_only", true)
			zone_root.add_child(instance)


func _make_scatter_mesh(kind: String, color: Color) -> Mesh:
	if kind == "shrub":
		var shrub := SphereMesh.new()
		shrub.radius = 0.62
		shrub.height = 1.05
		shrub.radial_segments = 7
		shrub.rings = 4
		shrub.material = _opaque_material(color)
		return shrub
	if kind == "rock":
		return _make_rock_mesh(color)
	return _make_fern_mesh(color) if kind == "fern" else _make_grass_mesh(color)


func _make_grass_mesh(color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := _opaque_material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for blade_index in 7:
		var angle := float(blade_index) * 2.39996
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var right := Vector3(-direction.z, 0.0, direction.x)
		var center := direction * (0.04 + float(blade_index % 3) * 0.055)
		var half_width := 0.055 + float(blade_index % 2) * 0.018
		var blade_height := 0.46 + float((blade_index * 3) % 5) * 0.075
		var blade_color := color.lightened(float(blade_index % 3) * 0.025)
		_add_colored_triangle(surface, center - right * half_width, center + right * half_width, center + direction * 0.16 + Vector3.UP * blade_height, blade_color)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _make_fern_mesh(color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := _opaque_material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for arm_index in 5:
		var angle := float(arm_index) * TAU / 5.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x)
		var start := direction * 0.05 + Vector3.UP * 0.12
		var finish := direction * 0.64 + Vector3.UP * 0.48
		for leaf_index in 3:
			var t := 0.22 + float(leaf_index) * 0.24
			var center := start.lerp(finish, t)
			var width := 0.22 * (1.0 - t * 0.48)
			var leaf_color := color.lightened(float(leaf_index) * 0.035)
			_add_colored_triangle(surface, center - side * width, center + direction * 0.24 + Vector3.UP * 0.05, center + side * width, leaf_color)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _make_rock_mesh(color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_count := 7
	var bottom: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for index in ring_count:
		var angle := float(index) * TAU / float(ring_count)
		var wobble := 0.86 + float((index * 5) % 4) * 0.075
		bottom.append(Vector3(cos(angle) * 0.58 * wobble, 0.02, sin(angle) * 0.50 * wobble))
		upper.append(Vector3(cos(angle) * 0.42 * wobble, 0.43 + float(index % 3) * 0.035, sin(angle) * 0.36 * wobble))
	for index in ring_count:
		var next := (index + 1) % ring_count
		var face_color := color.lightened(float(index % 3) * 0.035)
		_add_colored_triangle(surface, bottom[index], bottom[next], upper[index], face_color)
		_add_colored_triangle(surface, upper[index], bottom[next], upper[next], face_color)
		_add_colored_triangle(surface, upper[index], upper[next], Vector3(0.02, 0.57, -0.03), face_color.lightened(0.04))
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, _vertex_color_material())
	return mesh


func _build_ground_transitions(config: Dictionary) -> void:
	var transition_root := Node3D.new()
	transition_root.name = "GroundTransitions"
	transition_root.set_meta("presentation_only", true)
	add_child(transition_root)
	_build_river_wet_ribbons(transition_root, config)
	_build_mountain_moss_patches(transition_root, config)
	_build_road_edge_patches(transition_root, config)


func _build_river_wet_ribbons(parent: Node3D, config: Dictionary) -> void:
	var profile := ((_environment_config.get("terrain_topology", {}) as Dictionary).get("river_profile", []) as Array)
	if profile.size() < 2:
		return
	var material := _transparent_vertex_material()
	var color := Color.from_string(str(config.get("river_wet_color", "#364a3f")), Color("#364a3f"))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for index in range(profile.size() - 1):
			var a := profile[index] as Array
			var b := profile[index + 1] as Array
			var edge_a := Vector2(float(a[1]) + side * float(a[2]) * 0.5, float(a[0]))
			var edge_b := Vector2(float(b[1]) + side * float(b[2]) * 0.5, float(b[0]))
			var inner_a := edge_a + Vector2(side * 0.30, 0.0)
			var inner_b := edge_b + Vector2(side * 0.30, 0.0)
			var outer_a := edge_a + Vector2(side * 4.2, 0.0)
			var outer_b := edge_b + Vector2(side * 4.2, 0.0)
			_add_transition_triangle(surface, inner_a, inner_b, outer_a, color, color.darkened(0.05), 0.30, 0.0, 0.044)
			_add_transition_triangle(surface, outer_a, inner_b, outer_b, color.darkened(0.05), color, 0.0, 0.30, 0.044)
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "RiverbankWetTransition"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("presentation_only", true)
	parent.add_child(instance)
	_patch_counts["riverbank"] = (profile.size() - 1) * 2


func _build_mountain_moss_patches(parent: Node3D, config: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("transition_patch_seed", 13536))
	var centers: Array[Dictionary] = []
	for index in 25:
		centers.append({
			"point": Vector2(rng.randf_range(112.0, 123.0), -360.0 + float(index) * 30.0 + rng.randf_range(-7.0, 7.0)),
			"radius": Vector2(rng.randf_range(3.0, 6.8), rng.randf_range(6.0, 13.0)),
			"rotation": rng.randf_range(-0.32, 0.32)
		})
	var mesh := _make_irregular_patch_mesh(centers, Color.from_string(str(config.get("mountain_moss_color", "#405447")), Color("#405447")), 0.24)
	var instance := MeshInstance3D.new()
	instance.name = "MountainFootMossTransition"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("presentation_only", true)
	parent.add_child(instance)
	_patch_counts["mountain_foot"] = centers.size()


func _build_road_edge_patches(parent: Node3D, config: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("transition_patch_seed", 13536)) + 101
	var centers: Array[Dictionary] = []
	for raw_road in _layout.get("roads", []):
		var road := raw_road as Dictionary
		if str(road.get("kind", "")) not in ["main", "service"]:
			continue
		if rng.randf() > 0.48:
			continue
		var start := _v2(road.get("from", [0.0, 0.0]))
		var finish := _v2(road.get("to", [0.0, 0.0]))
		var delta := finish - start
		if delta.length() <= 0.01:
			continue
		var direction := delta.normalized()
		var normal := Vector2(-direction.y, direction.x)
		var center := start.lerp(finish, rng.randf_range(0.25, 0.75)) + normal * (-1.0 if rng.randf() < 0.5 else 1.0) * (float(road.get("width", 3.0)) * 0.5 + 0.7)
		if _point_overlaps_building_lot(center, 0.4) or _point_overlaps_public_clearance(center):
			continue
		centers.append({"point": center, "radius": Vector2(rng.randf_range(1.0, 2.0), rng.randf_range(1.8, 3.5)), "rotation": atan2(direction.y, direction.x)})
	var mesh := _make_irregular_patch_mesh(centers, Color.from_string(str(config.get("road_soil_color", "#554d40")), Color("#554d40")), 0.18)
	var instance := MeshInstance3D.new()
	instance.name = "RoadShoulderSoilTransition"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("presentation_only", true)
	parent.add_child(instance)
	_patch_counts["road_edge"] = centers.size()


func _make_irregular_patch_mesh(centers: Array[Dictionary], color: Color, center_alpha: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for patch_index in centers.size():
		var patch := centers[patch_index]
		var center := patch["point"] as Vector2
		var radius := patch["radius"] as Vector2
		var rotation := float(patch["rotation"])
		var edge_points: Array[Vector2] = []
		for index in 9:
			var angle := float(index) * TAU / 9.0 + rotation
			var wobble := 0.74 + _unit_noise(center, patch_index * 17 + index) * 0.38
			edge_points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * wobble)
		for index in 9:
			var a := edge_points[index]
			var b := edge_points[(index + 1) % 9]
			surface.set_color(Color(color.r, color.g, color.b, center_alpha))
			surface.add_vertex(Vector3(center.x, _terrain_height(center) + 0.046, center.y))
			for edge in [a, b]:
				surface.set_color(Color(color.r, color.g, color.b, 0.0))
				surface.add_vertex(Vector3(edge.x, _terrain_height(edge) + 0.045, edge.y))
	var mesh := surface.commit()
	mesh.surface_set_material(0, _transparent_vertex_material())
	return mesh


func _point_allowed_outside_station(point: Vector2, config: Dictionary, route_clearance: float) -> bool:
	if _distance_to_station_polygon(point) < float(config.get("station_outer_clearance", 4.0)):
		return false
	var edges := _river_edges_at(point.y)
	if edges.size() >= 4 and point.x > float(edges[0]) - 0.4 and point.x < float(edges[3]) + 0.4:
		return false
	if _distance_to_formal_routes(point, config) < route_clearance:
		return false
	return true


func _distance_to_formal_routes(point: Vector2, config: Dictionary) -> float:
	var minimum := INF
	var forest := ((_environment_config.get("terrain_topology", {}) as Dictionary).get("forest", {}) as Dictionary)
	for key in ["front_route", "rear_route"]:
		var route: Array[Vector2] = []
		for raw_point in forest.get(key, []):
			route.append(_v2(raw_point))
		for index in range(route.size() - 1):
			minimum = minf(minimum, _distance_to_segment(point, route[index], route[index + 1]))
	return minimum


func _river_edges_at(z: float) -> Array:
	var profile := ((_environment_config.get("terrain_topology", {}) as Dictionary).get("river_profile", []) as Array)
	if profile.size() < 2:
		return []
	var a := profile[0] as Array
	var b := profile[-1] as Array
	for index in range(profile.size() - 1):
		var candidate_a := profile[index] as Array
		var candidate_b := profile[index + 1] as Array
		if z >= float(candidate_a[0]) and z <= float(candidate_b[0]):
			a = candidate_a
			b = candidate_b
			break
	var t := inverse_lerp(float(a[0]), float(b[0]), clampf(z, float(a[0]), float(b[0])))
	var center := lerpf(float(a[1]), float(b[1]), t)
	var valley_width := lerpf(float(a[2]), float(b[2]), t)
	var water_width := lerpf(float(a[3]), float(b[3]), t)
	var water_center := center + lerpf(float(a[4]) if a.size() >= 5 else 0.0, float(b[4]) if b.size() >= 5 else 0.0, t)
	return [center - valley_width * 0.5, water_center - water_width * 0.5, water_center + water_width * 0.5, center + valley_width * 0.5]


func _terrain_height(point: Vector2) -> float:
	if point.x < 120.0:
		return 0.0
	var mountain := ((_environment_config.get("terrain_topology", {}) as Dictionary).get("east_mountain", {}) as Dictionary)
	var profile := mountain.get("profile", []) as Array
	if profile.size() < 2:
		return 0.0
	var sample_a := profile[0] as Array
	var sample_b := profile[-1] as Array
	for index in range(profile.size() - 1):
		var candidate_a := profile[index] as Array
		var candidate_b := profile[index + 1] as Array
		if point.y >= float(candidate_a[0]) and point.y <= float(candidate_b[0]):
			sample_a = candidate_a
			sample_b = candidate_b
			break
	var z_t := inverse_lerp(float(sample_a[0]), float(sample_b[0]), clampf(point.y, float(sample_a[0]), float(sample_b[0])))
	var result := 0.0
	for layer_spec in [["near_x_range", 1], ["mid_x_range", 2], ["far_x_range", 3]]:
		var x_range := _v2(mountain.get(str(layer_spec[0]), [0.0, 0.0]))
		if point.x < x_range.x or point.x > x_range.y:
			continue
		var height := lerpf(float(sample_a[int(layer_spec[1])]), float(sample_b[int(layer_spec[1])]), z_t)
		result = maxf(result, height * smoothstep(0.0, 0.94, inverse_lerp(x_range.x, x_range.y, point.x)))
	return result


func _point_overlaps_building_lot(point: Vector2, clearance: float) -> bool:
	for raw_building in _layout.get("buildings", []):
		var building := raw_building as Dictionary
		var center := _v2(building.get("center", [0.0, 0.0]))
		var local := (point - center).rotated(-deg_to_rad(float(building.get("rotation_degrees", 0.0))))
		var size := _v2(building.get("lot_size", [0.0, 0.0])) * 0.5 + Vector2.ONE * clearance
		if absf(local.x) <= size.x and absf(local.y) <= size.y:
			return true
	return false


func _point_overlaps_any_road(point: Vector2, clearance: float) -> bool:
	for raw_road in _layout.get("roads", []):
		var road := raw_road as Dictionary
		if _distance_to_segment(point, _v2(road.get("from", [0.0, 0.0])), _v2(road.get("to", [0.0, 0.0]))) <= float(road.get("width", 3.0)) * 0.5 + clearance:
			return true
	return false


func _point_overlaps_public_clearance(point: Vector2) -> bool:
	for raw_location in _layout.get("public_locations", []):
		var location := raw_location as Dictionary
		var extra := 3.4 if str(location.get("id", "")) == "plaza" else 1.0
		if point.distance_to(_v2(location.get("position", [0.0, 0.0]))) <= float(location.get("radius", 0.0)) + extra:
			return true
	return false


func _public_location(location_id: String) -> Dictionary:
	for raw_location in _layout.get("public_locations", []):
		var location := raw_location as Dictionary
		if str(location.get("id", "")) == location_id:
			return location
	return {}


func _station_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var station := _layout.get("station", {}) as Dictionary
	for raw_point in station.get("interior_polygon", []):
		polygon.append(_v2(raw_point))
	return polygon


func _point_in_station(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _station_polygon())


func _distance_to_station_polygon(point: Vector2) -> float:
	var polygon := _station_polygon()
	if polygon.is_empty():
		return INF
	if Geometry2D.is_point_in_polygon(point, polygon):
		return 0.0
	var minimum := INF
	for index in polygon.size():
		minimum = minf(minimum, _distance_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()]))
	return minimum


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var delta := finish - start
	if delta.length_squared() <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(start + delta * t)


func _add_colored_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_add_colored_triangle(surface, a, b, c, color)
	_add_colored_triangle(surface, a, c, d, color.lightened(0.035))


func _add_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)


func _add_transition_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, color_a: Color, color_c: Color, alpha_a: float, alpha_c: float, y: float) -> void:
	for entry in [[a, color_a, alpha_a], [b, color_a, alpha_a], [c, color_c, alpha_c]]:
		var point := entry[0] as Vector2
		var color := entry[1] as Color
		surface.set_color(Color(color.r, color.g, color.b, float(entry[2])))
		surface.add_vertex(Vector3(point.x, y, point.y))


func _opaque_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.98
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material


func _vertex_color_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.98
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _transparent_vertex_material() -> StandardMaterial3D:
	var material := _vertex_color_material()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.render_priority = 1
	return material


func _fallback_color(kind: String) -> String:
	return {"grass": "#587052", "fern": "#466247", "shrub": "#38533f", "rock": "#626761"}.get(kind, "#587052")


func _scatter_config() -> Dictionary:
	return _environment_config.get("natural_scatter", {}) as Dictionary


func _rect_from_array(value: Variant) -> Rect2:
	if value is Array and value.size() >= 4:
		return Rect2(float(value[0]), float(value[2]), float(value[1]) - float(value[0]), float(value[3]) - float(value[2]))
	return Rect2()


func _unit_noise(point: Vector2, salt: int) -> float:
	return fposmod(sin(point.x * 12.9898 + point.y * 78.233 + float(salt) * 19.19) * 43758.5453, 1.0)


func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
