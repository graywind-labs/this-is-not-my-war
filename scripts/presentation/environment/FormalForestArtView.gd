extends Node3D

const EXPECTED_SCHEMA := "environment_art_v1"
const ART_REVISION := "t0135_p7"
const STYLIZED_TREES := preload("res://scripts/presentation/environment/StylizedTreeMeshes.gd")

var _environment_config: Dictionary = {}
var _layout: Dictionary = {}
var _conifer_variants: Array[Array] = []
var _missing_assets: Array[String] = []
var _tree_counts := {"front": 0, "rear": 0, "side": 0, "near": 0, "mid": 0, "far": 0}
var _tree_variant_counts := {"slender_pine": 0, "layered_pine": 0, "broad_fir": 0}
var _bush_counts := {"front": 0, "rear": 0, "side": 0}
var _chunk_counts := {"front": 0, "rear": 0, "side": 0}
var _spawn_clear_tree_count := 0
var _spawn_screen_tree_count := 0
var _minimum_corridor_clearance := INF
var _minimum_station_clearance := INF
var _mountain_tree_count := 0
var _riverbank_tree_count := 0
var _station_density_counts := {"near": 0, "transition": 0, "far": 0}
var _approved_trees: RefCounted
var _approved_variant_counts: Dictionary = {}


func configure(environment_config: Dictionary, station_layout: Dictionary) -> void:
	_environment_config = environment_config.duplicate(true)
	_layout = station_layout.duplicate(true)
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_rebuild()


func get_debug_snapshot() -> Dictionary:
	var config := _forest_config()
	return {
		"approved_forest": {"enabled":_approved_trees!=null,"revision":"t0364_approved" if _approved_trees!=null else "","variant_counts":_approved_variant_counts.duplicate()},
		"tree_variant_counts_role": "legacy_source_sampling" if _approved_trees!=null else "visible_variants",
		"art_revision": ART_REVISION,
		"tree_counts": _tree_counts.duplicate(),
		"tree_variant_counts": _tree_variant_counts.duplicate(),
		"total_tree_count": int(_tree_counts["front"]) + int(_tree_counts["rear"]) + int(_tree_counts["side"]),
		"bush_counts": _bush_counts.duplicate(),
		"total_bush_count": int(_bush_counts["front"]) + int(_bush_counts["rear"]) + int(_bush_counts["side"]),
		"chunk_counts": _chunk_counts.duplicate(),
		"chunk_size": float(config.get("chunk_size", 0.0)),
		"front_bounds": _rect_from_array(config.get("front_bounds", [])),
		"rear_bounds": _rect_from_array(config.get("rear_bounds", [])),
		"side_bounds": _rect_from_array(config.get("side_bounds", [])),
		"spawn_clear_tree_count": _spawn_clear_tree_count,
		"spawn_screen_tree_count": _spawn_screen_tree_count,
		"minimum_corridor_clearance": _minimum_corridor_clearance if is_finite(_minimum_corridor_clearance) else 0.0,
		"minimum_station_clearance": _minimum_station_clearance if is_finite(_minimum_station_clearance) else 0.0,
		"mountain_tree_count": _mountain_tree_count,
		"riverbank_tree_count": _riverbank_tree_count,
		"station_density_counts": _station_density_counts.duplicate(),
		"mountain_tree_density_factor": float(config.get("mountain_tree_density", 0.18)),
		"missing_assets": _missing_assets.duplicate(),
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
	_conifer_variants.clear()
	_approved_trees = null
	_approved_variant_counts.clear()
	_missing_assets.clear()
	_tree_counts = {"front": 0, "rear": 0, "side": 0, "near": 0, "mid": 0, "far": 0}
	_tree_variant_counts = {"slender_pine": 0, "layered_pine": 0, "broad_fir": 0}
	_bush_counts = {"front": 0, "rear": 0, "side": 0}
	_chunk_counts = {"front": 0, "rear": 0, "side": 0}
	_spawn_clear_tree_count = 0
	_spawn_screen_tree_count = 0
	_minimum_corridor_clearance = INF
	_minimum_station_clearance = INF
	_mountain_tree_count = 0
	_riverbank_tree_count = 0
	_station_density_counts = {"near": 0, "transition": 0, "far": 0}
	if str(_environment_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		return
	var config := _forest_config()
	var approved_config: Dictionary = _environment_config.get("approved_forest",{})
	if bool(approved_config.get("enabled",false)):
		var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(approved_config.get("config_path","res://data/presentation/forest_art_trial.json"))))
		if settings is Dictionary and str(settings.get("schema_version",""))=="forest_art_trial_v1":
			_approved_trees = STYLIZED_TREES.new(settings)
			for variant_name in STYLIZED_TREES.VARIANT_NAMES:
				_approved_variant_counts[variant_name] = 0
		else:
			push_error("Approved forest style is invalid; retaining the original tree art")
	_build_conifer_variants()
	_build_forest_side("front", _rect_from_array(config.get("front_bounds", [])), config)
	_build_forest_side("rear", _rect_from_array(config.get("rear_bounds", [])), config)
	_build_forest_side("side", _rect_from_array(config.get("side_bounds", [])), config)
	set_meta("art_revision", ART_REVISION)
	set_meta("presentation_only", true)


func _build_forest_side(side: String, bounds: Rect2, config: Dictionary) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var side_root := Node3D.new()
	side_root.name = "%sDenseForest" % side.capitalize()
	side_root.set_meta("forest_side", side)
	add_child(side_root)
	var chunk_size := float(config.get("chunk_size", 40.0))
	var x_chunks := ceili(bounds.size.x / chunk_size)
	var z_chunks := ceili(bounds.size.y / chunk_size)
	var tree_range := _v2(config.get("trees_per_chunk", [18.0, 25.0]))
	var bush_range := _v2(config.get("bushes_per_chunk", [10.0, 16.0]))
	var side_seed_offset := 0 if side == "front" else 100000 if side == "rear" else 200000
	var tree_seed := int(config.get("tree_seed", 13525)) + side_seed_offset
	var bush_seed := int(config.get("bush_seed", 13526)) + side_seed_offset
	for chunk_z in z_chunks:
		for chunk_x in x_chunks:
			var chunk_min := bounds.position + Vector2(float(chunk_x) * chunk_size, float(chunk_z) * chunk_size)
			var chunk_max := Vector2(minf(chunk_min.x + chunk_size, bounds.end.x), minf(chunk_min.y + chunk_size, bounds.end.y))
			var center := (chunk_min + chunk_max) * 0.5
			var chunk := Node3D.new()
			chunk.name = "%sChunk_%02d_%02d" % [side.capitalize(), chunk_x, chunk_z]
			chunk.position = Vector3(center.x, 0.0, center.y)
			chunk.set_meta("forest_chunk", true)
			chunk.set_meta("forest_side", side)
			side_root.add_child(chunk)
			var tree_rng := RandomNumberGenerator.new()
			tree_rng.seed = tree_seed + chunk_z * 4099 + chunk_x * 131
			var target_tree_count := int(round(float(tree_rng.randi_range(int(tree_range.x), int(tree_range.y))) * _chunk_density_multiplier(center, config, true)))
			var tree_points := _generate_points(side, chunk_min, chunk_max, target_tree_count, tree_rng, config, true)
			var bush_rng := RandomNumberGenerator.new()
			bush_rng.seed = bush_seed + chunk_z * 8191 + chunk_x * 193
			var target_bush_count := int(round(float(bush_rng.randi_range(int(bush_range.x), int(bush_range.y))) * _chunk_density_multiplier(center, config, false)))
			var bush_points := _generate_points(side, chunk_min, chunk_max, target_bush_count, bush_rng, config, false)
			if tree_points.is_empty() and bush_points.is_empty():
				chunk.queue_free()
				continue
			_build_tree_multimeshes(chunk, center, side, tree_points, tree_rng, config, chunk_size)
			_build_bush_multimesh(chunk, center, side, bush_points, bush_rng, config, chunk_size)
			_chunk_counts[side] = int(_chunk_counts[side]) + 1


func _generate_points(side: String, chunk_min: Vector2, chunk_max: Vector2, target_count: int, rng: RandomNumberGenerator, config: Dictionary, is_tree: bool) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var minimum_spacing := 3.25 if is_tree else 1.15
	var attempts := target_count * 12
	for _attempt in attempts:
		if result.size() >= target_count:
			break
		var point := Vector2(rng.randf_range(chunk_min.x, chunk_max.x), rng.randf_range(chunk_min.y, chunk_max.y))
		if not _is_forest_point_allowed(side, point, config, is_tree):
			continue
		var too_close := false
		for existing in result:
			if point.distance_squared_to(existing) < minimum_spacing * minimum_spacing:
				too_close = true
				break
		if not too_close:
			result.append(point)
	return result


func _is_forest_point_allowed(side: String, point: Vector2, config: Dictionary, is_tree: bool) -> bool:
	var river_exclusion := _v2(config.get("river_exclusion_x", [-122.0, -73.0]))
	if point.x >= river_exclusion.x and point.x <= river_exclusion.y:
		return false
	var clearance := float(config.get("corridor_clearance", 5.2)) + (0.0 if is_tree else -1.15)
	var route_distance := _distance_to_route_for_side(point, side, config)
	if route_distance < clearance:
		return false
	var station_distance := _distance_to_station_polygon(point)
	if station_distance < float(config.get("station_clearance", 8.0)):
		return false
	if side == "front":
		var spawn_center := _v2(config.get("spawn_clear_center", [2.0, 335.0]))
		var spawn_size := _v2(config.get("spawn_clear_size", [28.0, 18.0]))
		var spawn_rect := Rect2(spawn_center - spawn_size * 0.5, spawn_size)
		if spawn_rect.grow(1.0 if is_tree else 0.2).has_point(point):
			return false
	if is_tree:
		_minimum_corridor_clearance = minf(_minimum_corridor_clearance, route_distance)
		_minimum_station_clearance = minf(_minimum_station_clearance, station_distance)
	return true


func _build_tree_multimeshes(chunk: Node3D, chunk_center: Vector2, side: String, points: Array[Vector2], rng: RandomNumberGenerator, config: Dictionary, chunk_size: float) -> void:
	if points.is_empty():
		return
	var scale_range := _v2(config.get("tree_scale_range", [0.88, 1.34]))
	var variant_placements: Array[Array] = [[], [], []]
	var variant_names := ["slender_pine", "layered_pine", "broad_fir"]
	var approved_groups: Array = [[],[],[],[],[],[]]
	var species_rng: RandomNumberGenerator = _approved_trees.make_species_rng(chunk_center) if _approved_trees!=null else null
	for point in points:
		var station_distance := _distance_to_station_polygon(point)
		var tier := _density_tier(station_distance)
		var scale_value := rng.randf_range(scale_range.x, scale_range.y)
		if tier == "far":
			scale_value += float(config.get("far_tree_scale_bonus", 0.16))
		var non_uniform := Vector3(scale_value * rng.randf_range(0.88, 1.12), scale_value * rng.randf_range(0.94, 1.12), scale_value * rng.randf_range(0.88, 1.12))
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(non_uniform)
		var placement := Transform3D(basis, Vector3(point.x - chunk_center.x, _terrain_height(point), point.y - chunk_center.y))
		var variant_index := rng.randi_range(0, 2)
		variant_placements[variant_index].append(placement)
		if _approved_trees!=null:
			var approved_variant: int = _approved_trees.choose_variant(point,species_rng)
			approved_groups[approved_variant].append(placement)
			_approved_variant_counts[STYLIZED_TREES.VARIANT_NAMES[approved_variant]] += 1
		var variant_name := str(variant_names[variant_index])
		_tree_variant_counts[variant_name] = int(_tree_variant_counts[variant_name]) + 1
		_tree_counts[side] = int(_tree_counts[side]) + 1
		_tree_counts[tier] = int(_tree_counts[tier]) + 1
		if station_distance < 35.0:
			_station_density_counts["near"] = int(_station_density_counts["near"]) + 1
		elif station_distance < 100.0:
			_station_density_counts["transition"] = int(_station_density_counts["transition"]) + 1
		else:
			_station_density_counts["far"] = int(_station_density_counts["far"]) + 1
		if point.x >= 120.0:
			_mountain_tree_count += 1
		var river_exclusion := _v2(config.get("river_exclusion_x", [-122.0, -73.0]))
		var riverbank_width := float(config.get("riverbank_sparse_width", 24.0))
		if absf(point.x - river_exclusion.x) <= riverbank_width or absf(point.x - river_exclusion.y) <= riverbank_width:
			_riverbank_tree_count += 1
		if side == "front":
			var spawn_center := _v2(config.get("spawn_clear_center", [2.0, 335.0]))
			var spawn_size := _v2(config.get("spawn_clear_size", [28.0, 18.0]))
			if Rect2(spawn_center - spawn_size * 0.5, spawn_size).has_point(point):
				_spawn_clear_tree_count += 1
			var route_distance := _distance_to_polyline(point, _route_points(config.get("front_route", [])))
			if point.y >= float(config.get("stable_reveal_z", 225.0)) and route_distance <= 18.0:
				_spawn_screen_tree_count += 1
	if _approved_trees!=null:
		# Retain the original near-forest shadow budget; the meshes themselves are shared.
		var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _density_tier(_distance_to_station_polygon(chunk_center))=="near" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_approved_trees.build_multimeshes(chunk,approved_groups,shadows)
		return
	for variant_index in _conifer_variants.size():
		_add_tree_part_multimeshes(chunk, variant_placements[variant_index], _conifer_variants[variant_index], str(variant_names[variant_index]).to_pascal_case(), side, chunk_size)


func _add_tree_part_multimeshes(chunk: Node3D, placements: Array, mesh_parts: Array, prefix: String, side: String, chunk_size: float) -> void:
	if placements.is_empty():
		return
	for part_index in mesh_parts.size():
		var part := mesh_parts[part_index] as Dictionary
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = part["mesh"] as Mesh
		multimesh.instance_count = placements.size()
		var source_transform := part["transform"] as Transform3D
		for index in placements.size():
			multimesh.set_instance_transform(index, placements[index] * source_transform)
		var instance := MultiMeshInstance3D.new()
		instance.name = "%sTreePart%02d" % [prefix, part_index]
		instance.multimesh = multimesh
		instance.custom_aabb = AABB(Vector3(-chunk_size * 0.6, -1.0, -chunk_size * 0.6), Vector3(chunk_size * 1.2, 52.0, chunk_size * 1.2))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _density_tier(_distance_to_station_polygon(Vector2(chunk.position.x, chunk.position.z))) == "near" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.set_meta("presentation_only", true)
		chunk.add_child(instance)


func _build_bush_multimesh(chunk: Node3D, chunk_center: Vector2, side: String, points: Array[Vector2], rng: RandomNumberGenerator, config: Dictionary, chunk_size: float) -> void:
	if points.is_empty():
		return
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.72
	bush_mesh.height = 1.15
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_string(str(config.get("bush_color", "#1f552d")), Color("#1f552d"))
	material.roughness = 0.98
	bush_mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = bush_mesh
	multimesh.instance_count = points.size()
	for index in points.size():
		var point := points[index]
		var scale_value := rng.randf_range(0.72, 1.48)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(scale_value * rng.randf_range(0.82, 1.25), scale_value, scale_value * rng.randf_range(0.82, 1.25)))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(point.x - chunk_center.x, _terrain_height(point) + 0.42, point.y - chunk_center.y)))
		_bush_counts[side] = int(_bush_counts[side]) + 1
	var instance := MultiMeshInstance3D.new()
	instance.name = "ForestUndergrowth"
	instance.multimesh = multimesh
	instance.custom_aabb = AABB(Vector3(-chunk_size * 0.6, 0.0, -chunk_size * 0.6), Vector3(chunk_size * 1.2, 40.0, chunk_size * 1.2))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("presentation_only", true)
	chunk.add_child(instance)


func _build_conifer_variants() -> void:
	_conifer_variants.append(_make_conifer_variant(3.9, 0.19, 0.31, [
		[1.72, 2.55, 3.25], [1.38, 2.38, 4.60], [1.02, 2.18, 5.82], [0.66, 1.82, 6.92]
	], ["#234b36", "#2c573d", "#356247", "#3e6b4d"]))
	_conifer_variants.append(_make_conifer_variant(3.8, 0.20, 0.34, [
		[2.35, 3.40, 3.40], [1.82, 3.00, 5.05], [1.30, 2.55, 6.42]
	], ["#1f472f", "#28563a", "#315f3f"]))
	_conifer_variants.append(_make_conifer_variant(3.5, 0.22, 0.38, [
		[2.72, 3.20, 3.18], [2.12, 2.90, 4.72], [1.52, 2.55, 6.02]
	], ["#294f38", "#335c40", "#3c6848"]))


func _make_conifer_variant(trunk_height: float, top_radius: float, bottom_radius: float, cone_specs: Array, colors: Array) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var bark_material := StandardMaterial3D.new()
	bark_material.albedo_color = Color("#4b3428")
	bark_material.roughness = 0.98
	var trunk := CylinderMesh.new()
	trunk.top_radius = top_radius
	trunk.bottom_radius = bottom_radius
	trunk.height = trunk_height
	trunk.radial_segments = 7
	trunk.material = bark_material
	parts.append({"mesh": trunk, "transform": Transform3D(Basis.IDENTITY, Vector3(0.0, trunk_height * 0.5, 0.0))})
	for index in cone_specs.size():
		var spec := cone_specs[index] as Array
		var foliage_material := StandardMaterial3D.new()
		foliage_material.albedo_color = Color.from_string(str(colors[mini(index, colors.size() - 1)]), Color("#315f3f"))
		foliage_material.roughness = 0.98
		var cone := CylinderMesh.new()
		cone.top_radius = 0.07
		cone.bottom_radius = float(spec[0])
		cone.height = float(spec[1])
		cone.radial_segments = 8
		cone.material = foliage_material
		parts.append({"mesh": cone, "transform": Transform3D(Basis.IDENTITY, Vector3(0.0, float(spec[2]), 0.0))})
	return parts


func _density_tier(station_distance: float) -> String:
	if station_distance < 70.0:
		return "near"
	if station_distance < 180.0:
		return "mid"
	return "far"


func _chunk_density_multiplier(center: Vector2, config: Dictionary, is_tree: bool) -> float:
	var station_clearance := float(config.get("station_clearance", 8.0))
	var station_distance := _distance_to_station_polygon(center)
	if station_distance < station_clearance:
		return 0.0
	var raw_bands := config.get("station_density_bands", [24.0, 52.0, 95.0]) as Array
	var raw_levels := config.get("station_density_levels", [0.10, 0.30, 0.62, 1.0]) as Array
	var bands := [float(raw_bands[0]), float(raw_bands[1]), float(raw_bands[2])]
	var levels := [float(raw_levels[0]), float(raw_levels[1]), float(raw_levels[2]), float(raw_levels[3])]
	var factor: float = levels[3]
	if station_distance < bands[0]:
		factor = lerpf(levels[0] * 0.5, levels[0], smoothstep(station_clearance, bands[0], station_distance))
	elif station_distance < bands[1]:
		factor = lerpf(levels[0], levels[1], smoothstep(bands[0], bands[1], station_distance))
	elif station_distance < bands[2]:
		factor = lerpf(levels[1], levels[2], smoothstep(bands[1], bands[2], station_distance))
	else:
		factor = lerpf(levels[2], levels[3], smoothstep(bands[2], bands[2] + 90.0, station_distance))
	var river_exclusion := _v2(config.get("river_exclusion_x", [-122.0, -73.0]))
	var riverbank_width := float(config.get("riverbank_sparse_width", 24.0))
	if absf(center.x - river_exclusion.x) <= riverbank_width or absf(center.x - river_exclusion.y) <= riverbank_width:
		factor *= float(config.get("riverbank_density", 0.26))
	if center.x >= 120.0:
		factor *= float(config.get("mountain_tree_density", 0.18)) if is_tree else float(config.get("mountain_bush_density", 0.14))
	return clampf(factor, 0.0, 1.0)


func _distance_to_station_polygon(point: Vector2) -> float:
	var polygon := PackedVector2Array()
	var station := _layout.get("station", {}) as Dictionary
	for raw_point in station.get("interior_polygon", []):
		polygon.append(_v2(raw_point))
	if polygon.size() < 3:
		return point.distance_to(Vector2.ZERO)
	if Geometry2D.is_point_in_polygon(point, polygon):
		return 0.0
	var result := INF
	for index in polygon.size():
		result = minf(result, _distance_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()]))
	return result


func _distance_to_route_for_side(point: Vector2, side: String, config: Dictionary) -> float:
	if side == "front":
		return _distance_to_polyline(point, _route_points(config.get("front_route", [])))
	if side == "rear":
		return _distance_to_polyline(point, _route_points(config.get("rear_route", [])))
	return minf(
		_distance_to_polyline(point, _route_points(config.get("front_route", []))),
		_distance_to_polyline(point, _route_points(config.get("rear_route", [])))
	)


func _distance_to_polyline(point: Vector2, route: Array[Vector2]) -> float:
	if route.size() < 2:
		return INF
	var result := INF
	for index in range(route.size() - 1):
		result = minf(result, _distance_to_segment(point, route[index], route[index + 1]))
	return result


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var delta := finish - start
	if delta.length_squared() <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(start + delta * t)


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
		var slope_t := inverse_lerp(x_range.x, x_range.y, point.x)
		result = maxf(result, height * smoothstep(0.0, 0.94, slope_t))
	return result


func _route_points(raw_route: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if raw_route is Array:
		for raw_point in raw_route:
			result.append(_v2(raw_point))
	return result


func _forest_config() -> Dictionary:
	return ((_environment_config.get("terrain_topology", {}) as Dictionary).get("forest", {}) as Dictionary)


func _rect_from_array(value: Variant) -> Rect2:
	if value is Array and value.size() >= 4:
		return Rect2(float(value[0]), float(value[2]), float(value[1]) - float(value[0]), float(value[3]) - float(value[2]))
	return Rect2()


func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
