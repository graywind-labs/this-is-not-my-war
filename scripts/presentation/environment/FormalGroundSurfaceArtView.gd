extends Node3D

const EXPECTED_SCHEMA := "environment_art_v1"
const ART_REVISION := "t0135_p7"
const FORMAL_TERRAIN_VIEW_SCRIPT := preload("res://scripts/presentation/environment/FormalTerrainArtView.gd")
const STATION_DETAIL_VIEW_SCRIPT := preload("res://scripts/presentation/environment/FormalStationDetailArtView.gd")
const FORMAL_FOREST_VIEW_SCRIPT := preload("res://scripts/presentation/environment/FormalForestArtView.gd")
const ENVIRONMENT_SCATTER_VIEW_SCRIPT := preload("res://scripts/presentation/environment/FormalEnvironmentScatterView.gd")
const CELESTIAL_CYCLE_CONTROLLER_SCRIPT := preload("res://scripts/presentation/environment/CelestialCycleController.gd")

const GROUND_SHADER_SOURCE := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec4 grass_dark : source_color = vec4(0.208, 0.298, 0.227, 1.0);
uniform vec4 grass_base : source_color = vec4(0.251, 0.345, 0.259, 1.0);
uniform vec4 grass_light : source_color = vec4(0.275, 0.373, 0.275, 1.0);
uniform float noise_scale = 0.055;
uniform float noise_strength = 0.72;

varying vec3 world_position;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 fraction = fract(value);
	vec2 smooth_fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_fraction.x), mix(c, d, smooth_fraction.x), smooth_fraction.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float broad = value_noise(world_position.xz * noise_scale);
	float secondary = value_noise(world_position.xz * noise_scale * 0.47 + vec2(19.3, -7.1));
	float micro = value_noise(world_position.xz * 0.19 + vec2(-4.7, 12.8));
	float blend_value = clamp(mix(broad, secondary, 0.32) * noise_strength + (1.0 - noise_strength) * 0.5, 0.0, 1.0);
	vec3 lower = mix(grass_dark.rgb, grass_base.rgb, smoothstep(0.12, 0.58, blend_value));
	ALBEDO = mix(lower, grass_light.rgb, smoothstep(0.56, 0.92, blend_value)) * mix(0.94, 1.035, micro);
	ROUGHNESS = mix(0.90, 0.99, mix(secondary, micro, 0.35));
}
"""

var _environment_config: Dictionary = {}
var _layout: Dictionary = {}
var _materials: Dictionary = {}
var _asset_scene_cache: Dictionary = {}
var _missing_assets: Array[String] = []
var _ground_polygon_vertex_count := 0
var _ground_triangle_count := 0
var _plaza_triangle_count := 0
var _door_wear_count := 0
var _drainage_strip_count := 0
var _pebble_count := 0
var _debris_cluster_count := 0
var _vegetation_count := 0
var _vegetation_cluster_count := 0
var _terrain_view: Node3D
var _station_detail_view: Node3D
var _forest_view: Node3D
var _scatter_view: Node3D
var _celestial_cycle_controller: Node3D


func configure(environment_config: Dictionary, station_layout: Dictionary) -> void:
	_environment_config = environment_config.duplicate(true)
	_layout = station_layout.duplicate(true)
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_rebuild()


func get_debug_snapshot() -> Dictionary:
	var ground_config := _ground_config()
	var plaza_config := ground_config.get("plaza", {}) as Dictionary
	var public_plaza := _find_public_plaza()
	var detail_snapshot: Dictionary = _station_detail_view.call("get_debug_snapshot") if is_instance_valid(_station_detail_view) else {}
	var terrain_snapshot: Dictionary = _terrain_view.call("get_debug_snapshot") if is_instance_valid(_terrain_view) else {}
	var forest_snapshot: Dictionary = _forest_view.call("get_debug_snapshot") if is_instance_valid(_forest_view) else {}
	var scatter_snapshot: Dictionary = _scatter_view.call("get_debug_snapshot") if is_instance_valid(_scatter_view) else {}
	var celestial_snapshot: Dictionary = _celestial_cycle_controller.call("get_debug_snapshot") if is_instance_valid(_celestial_cycle_controller) else {}
	var combined_missing_assets := _missing_assets.duplicate()
	for missing_asset in detail_snapshot.get("missing_assets", []):
		if not combined_missing_assets.has(str(missing_asset)):
			combined_missing_assets.append(str(missing_asset))
	return {
		"schema_version": str(_environment_config.get("schema_version", "")),
		"art_revision": ART_REVISION,
		"ground_polygon_vertex_count": _ground_polygon_vertex_count,
		"ground_triangle_count": _ground_triangle_count,
		"plaza_triangle_count": _plaza_triangle_count,
		"plaza_visual_size": _v2(plaza_config.get("visual_size", [0.0, 0.0])),
		"plaza_center_clear_size": _v2(plaza_config.get("center_clear_size", [0.0, 0.0])),
		"plaza_authority_center": _v2(public_plaza.get("position", [0.0, 0.0])),
		"plaza_authority_radius": float(public_plaza.get("radius", 0.0)),
		"legacy_plaza_box_count": find_children("Patch*", "MeshInstance3D", true, false).size(),
		"door_wear_count": _door_wear_count,
		"drainage_strip_count": _drainage_strip_count,
		"pebble_count": _pebble_count,
		"debris_cluster_count": _debris_cluster_count,
		"vegetation_count": _vegetation_count,
		"vegetation_cluster_count": _vegetation_cluster_count,
		"station_detail_cluster_count": int(detail_snapshot.get("cluster_count", 0)),
		"station_detail_prop_count": int(detail_snapshot.get("prop_count", 0)),
		"terrain_topology": terrain_snapshot,
		"forest": forest_snapshot,
		"natural_scatter": scatter_snapshot,
		"celestial_cycle": celestial_snapshot,
		"plaza_topology": "road_network_junction_no_separate_marker",
		"door_wear_topology": "road_shoulders_only_no_independent_patches",
		"debris_distribution": "scattered_non_enclosing_clusters",
		"missing_assets": combined_missing_assets,
		"asset_sources": _detail_asset_paths(),
		"has_collision": find_children("*", "CollisionShape3D", true, false).size() > 0,
		"has_static_body": find_children("*", "StaticBody3D", true, false).size() > 0,
		"has_navigation_region": find_children("*", "NavigationRegion3D", true, false).size() > 0,
		"has_interaction_area": find_children("*", "Area3D", true, false).size() > 0,
		"roads_affect_navigation": false,
		"authority_role": "presentation_only"
	}


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_materials.clear()
	_asset_scene_cache.clear()
	_missing_assets.clear()
	_ground_polygon_vertex_count = 0
	_ground_triangle_count = 0
	_plaza_triangle_count = 0
	_door_wear_count = 0
	_drainage_strip_count = 0
	_pebble_count = 0
	_debris_cluster_count = 0
	_vegetation_count = 0
	_vegetation_cluster_count = 0
	_terrain_view = null
	_station_detail_view = null
	_forest_view = null
	_scatter_view = null
	_celestial_cycle_controller = null
	if str(_environment_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		return
	_build_materials()
	_terrain_view = FORMAL_TERRAIN_VIEW_SCRIPT.new() as Node3D
	_terrain_view.name = "FullMapTerrainTopology"
	_terrain_view.call("configure", _environment_config, _layout)
	add_child(_terrain_view)
	_forest_view = FORMAL_FOREST_VIEW_SCRIPT.new() as Node3D
	_forest_view.name = "FullMapDenseForest"
	_forest_view.call("configure", _environment_config, _layout)
	add_child(_forest_view)
	_scatter_view = ENVIRONMENT_SCATTER_VIEW_SCRIPT.new() as Node3D
	_scatter_view.name = "FullMapNaturalScatter"
	_scatter_view.call("configure", _environment_config, _layout)
	add_child(_scatter_view)
	var surface_root := Node3D.new()
	surface_root.name = "GroundSurface"
	add_child(surface_root)
	_build_station_grass_surface(surface_root)
	_build_plaza_surface(surface_root)
	_build_door_wear(surface_root)
	_build_drainage(surface_root)
	_build_embedded_details(surface_root)
	_station_detail_view = STATION_DETAIL_VIEW_SCRIPT.new() as Node3D
	_station_detail_view.name = "StationLifeDetails"
	_station_detail_view.call("configure", _environment_config, _layout)
	add_child(_station_detail_view)
	_celestial_cycle_controller = CELESTIAL_CYCLE_CONTROLLER_SCRIPT.new() as Node3D
	_celestial_cycle_controller.name = "CelestialCycleController"
	_celestial_cycle_controller.call("configure", _environment_config)
	add_child(_celestial_cycle_controller)
	set_meta("art_revision", ART_REVISION)
	set_meta("presentation_only", true)
	set_meta("roads_affect_navigation", false)


func _build_materials() -> void:
	var palette := (_ground_config().get("palette", {}) as Dictionary)
	var ground_shader := Shader.new()
	ground_shader.code = GROUND_SHADER_SOURCE
	var ground_material := ShaderMaterial.new()
	ground_material.shader = ground_shader
	ground_material.set_shader_parameter("grass_dark", _color(palette.get("grass_dark", "#354c3a"), Color("#354c3a")))
	ground_material.set_shader_parameter("grass_base", _color(palette.get("grass_base", "#405842"), Color("#405842")))
	ground_material.set_shader_parameter("grass_light", _color(palette.get("grass_light", "#465f46"), Color("#465f46")))
	ground_material.set_shader_parameter("noise_scale", float(_ground_config().get("macro_noise_scale", 0.055)))
	ground_material.set_shader_parameter("noise_strength", float(_ground_config().get("macro_noise_strength", 0.72)))
	_materials["ground"] = ground_material
	var decal_material := StandardMaterial3D.new()
	decal_material.vertex_color_use_as_albedo = true
	decal_material.vertex_color_is_srgb = true
	decal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	decal_material.roughness = 0.98
	decal_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	decal_material.render_priority = 1
	_materials["decal"] = decal_material
	var drainage := _ground_config().get("drainage", {}) as Dictionary
	_materials["wet"] = _make_transparent_material(
		_color(palette.get("wet", "#39443b"), Color("#39443b")),
		float(drainage.get("alpha", 0.38))
	)
	_materials["grass_common"] = _make_detail_material(Color("#718469"))
	_materials["grass_wispy"] = _make_detail_material(Color("#64785e"))
	_materials["clover"] = _make_detail_material(Color("#788b6e"))
	_materials["pebble"] = _make_detail_material(Color("#6b6b64"))


func _build_station_grass_surface(parent: Node3D) -> void:
	var polygon := _station_polygon()
	if polygon.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	var surface_y := float(_ground_config().get("surface_y", 0.012))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for point in polygon:
		vertices.append(Vector3(point.x, surface_y, point.y))
		normals.append(Vector3.UP)
		uvs.append(point * 0.05)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _materials["ground"])
	var instance := MeshInstance3D.new()
	instance.name = "StationDeepGrassVariation"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("ground_macro_variation", true)
	instance.set_meta("collision_free_decal", true)
	parent.add_child(instance)
	_ground_polygon_vertex_count = vertices.size()
	_ground_triangle_count = indices.size() / 3


func _build_plaza_surface(parent: Node3D) -> void:
	# A frontier-station plaza is the widened meeting of several roads, not a
	# separately outlined courtyard.  The accepted road view already supplies
	# continuous shoulders, ruts and junction fills, so no emblem-like ground
	# patch is rendered here.
	parent.set_meta("plaza_uses_road_network_junction", true)
	parent.set_meta("plaza_authority_center_unchanged", true)


func _build_door_wear(parent: Node3D) -> void:
	# Roads already terminate at the real entry routes.  Independent decals at
	# every threshold read as copied symbols, so entrance wear is intentionally
	# absorbed by the road shoulders instead of creating a second ground shape.
	parent.set_meta("door_wear_merged_into_roads", true)


func _build_drainage(parent: Node3D) -> void:
	var drainage := _ground_config().get("drainage", {}) as Dictionary
	var surface_y := float(drainage.get("surface_y", 0.073))
	var width := float(drainage.get("width", 0.22))
	for path_index in (drainage.get("paths", []) as Array).size():
		var raw_path := (drainage.get("paths", []) as Array)[path_index] as Array
		var points: Array[Vector2] = []
		for raw_point in raw_path:
			points.append(_v2(raw_point))
		if points.size() < 2:
			continue
		var strip := _make_polyline_strip("Drainage%02d" % (path_index + 1), points, width, surface_y, _materials["wet"])
		strip.set_meta("visual_drainage_only", true)
		parent.add_child(strip)
		_drainage_strip_count += 1


func _build_embedded_details(parent: Node3D) -> void:
	var details := _ground_config().get("embedded_details", {}) as Dictionary
	_build_pebble_scatter(parent, details)
	_build_vegetation_scatter(parent, details)


func _build_pebble_scatter(parent: Node3D, details: Dictionary) -> void:
	var assets := details.get("pebble_assets", []) as Array
	if assets.is_empty():
		return
	var polygon := _station_polygon()
	if polygon.size() < 3:
		return
	var bounds := _polygon_bounds(polygon)
	var target_clusters := maxi(0, int(details.get("debris_cluster_count", 8)))
	var stones_per_cluster := _v2(details.get("stones_per_debris_cluster", [3, 5]))
	var radius_range := _v2(details.get("debris_radius_range", [0.18, 0.95]))
	var scale_range := _v2(details.get("pebble_scale_range", [0.28, 0.62]))
	var road_clearance := float(details.get("road_clearance", 1.15))
	var lot_clearance := float(details.get("building_lot_clearance", 0.75))
	var plaza_clearance := float(details.get("plaza_center_clear_radius", 7.4))
	var min_spacing := float(details.get("debris_min_spacing", 5.0))
	var plaza_center := _v2(((_layout.get("station", {}) as Dictionary).get("plaza", {}) as Dictionary).get("center", [0.0, 10.0]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(details.get("debris_seed", 13522))
	var accepted_centers: Array[Vector2] = []
	var attempts := 0
	while accepted_centers.size() < target_clusters and attempts < target_clusters * 180:
		attempts += 1
		var candidate := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not Geometry2D.is_point_in_polygon(candidate, polygon):
			continue
		if candidate.distance_to(plaza_center) < plaza_clearance:
			continue
		if _point_overlaps_any_building_lot(candidate, lot_clearance) or _point_overlaps_any_road(candidate, road_clearance):
			continue
		var spaced := true
		for existing in accepted_centers:
			if candidate.distance_to(existing) < min_spacing:
				spaced = false
				break
		if not spaced:
			continue
		accepted_centers.append(candidate)
		var cluster_index := accepted_centers.size()
		var stone_count := rng.randi_range(int(minf(stones_per_cluster.x, stones_per_cluster.y)), int(maxf(stones_per_cluster.x, stones_per_cluster.y)))
		for stone_index in stone_count:
			var angle := rng.randf_range(0.0, TAU)
			var radius := rng.randf_range(minf(radius_range.x, radius_range.y), maxf(radius_range.x, radius_range.y))
			var stone_position := candidate + Vector2(cos(angle), sin(angle)) * radius
			if not Geometry2D.is_point_in_polygon(stone_position, polygon):
				continue
			if _point_overlaps_any_building_lot(stone_position, lot_clearance) or _point_overlaps_any_road(stone_position, road_clearance):
				continue
			var asset_path := str(assets[rng.randi_range(0, assets.size() - 1)])
			var detail := _instantiate_detail(asset_path)
			if detail == null:
				continue
			detail.name = "GroundDebrisCluster%02dPebble%02d" % [cluster_index, stone_index + 1]
			detail.position = Vector3(stone_position.x, 0.068, stone_position.y)
			var scale_value := rng.randf_range(minf(scale_range.x, scale_range.y), maxf(scale_range.x, scale_range.y))
			detail.scale = Vector3(scale_value, scale_value, scale_value)
			detail.rotation_degrees.y = rng.randf_range(0.0, 360.0)
			detail.set_meta("embedded_ground_debris", true)
			detail.set_meta("non_enclosing_cluster", cluster_index)
			parent.add_child(detail)
			_pebble_count += 1
	_debris_cluster_count = accepted_centers.size()


func _build_vegetation_scatter(parent: Node3D, details: Dictionary) -> void:
	var assets := details.get("vegetation_assets", []) as Array
	if assets.is_empty():
		return
	var polygon := _station_polygon()
	if polygon.size() < 3:
		return
	var bounds := _polygon_bounds(polygon)
	var cluster_count := maxi(0, int(details.get("vegetation_cluster_count", 18)))
	var tufts_per_cluster := _v2(details.get("tufts_per_cluster", [2, 4]))
	var cluster_radius_range := _v2(details.get("cluster_radius_range", [0.25, 0.85]))
	var scale_range := _v2(details.get("vegetation_scale_range", [0.24, 0.40]))
	var road_clearance := float(details.get("road_clearance", 1.15))
	var lot_clearance := float(details.get("building_lot_clearance", 0.75))
	var plaza_clearance := float(details.get("plaza_center_clear_radius", 7.4))
	var min_spacing := float(details.get("min_spacing", 2.4))
	var plaza_center := _v2(((_layout.get("station", {}) as Dictionary).get("plaza", {}) as Dictionary).get("center", [0.0, 10.0]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(details.get("vegetation_seed", 13521))
	var accepted_centers: Array[Vector2] = []
	var attempts := 0
	while accepted_centers.size() < cluster_count and attempts < cluster_count * 120:
		attempts += 1
		var candidate := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		if not Geometry2D.is_point_in_polygon(candidate, polygon):
			continue
		if candidate.distance_to(plaza_center) < plaza_clearance:
			continue
		if _point_overlaps_any_building_lot(candidate, lot_clearance):
			continue
		if _point_overlaps_any_road(candidate, road_clearance):
			continue
		var spaced := true
		for existing in accepted_centers:
			if candidate.distance_to(existing) < min_spacing:
				spaced = false
				break
		if not spaced:
			continue
		accepted_centers.append(candidate)
		var tuft_count := rng.randi_range(int(minf(tufts_per_cluster.x, tufts_per_cluster.y)), int(maxf(tufts_per_cluster.x, tufts_per_cluster.y)))
		for tuft_index in tuft_count:
			var angle := rng.randf_range(0.0, TAU)
			var radius := rng.randf_range(minf(cluster_radius_range.x, cluster_radius_range.y), maxf(cluster_radius_range.x, cluster_radius_range.y))
			var tuft_position := candidate + Vector2(cos(angle), sin(angle)) * radius
			if not Geometry2D.is_point_in_polygon(tuft_position, polygon):
				continue
			if _point_overlaps_any_building_lot(tuft_position, lot_clearance) or _point_overlaps_any_road(tuft_position, road_clearance):
				continue
			var asset_path := str(assets[rng.randi_range(0, assets.size() - 1)])
			var detail := _instantiate_detail(asset_path)
			if detail == null:
				continue
			detail.name = "GroundVegetationCluster%02dTuft%02d" % [accepted_centers.size(), tuft_index + 1]
			detail.position = Vector3(tuft_position.x, 0.018, tuft_position.y)
			var scale_value := rng.randf_range(minf(scale_range.x, scale_range.y), maxf(scale_range.x, scale_range.y))
			detail.scale = Vector3(scale_value, scale_value, scale_value)
			detail.rotation_degrees.y = rng.randf_range(0.0, 360.0)
			detail.set_meta("ground_edge_vegetation", true)
			detail.set_meta("vegetation_cluster", accepted_centers.size())
			parent.add_child(detail)
			_vegetation_count += 1
	_vegetation_cluster_count = accepted_centers.size()


func _make_polyline_strip(node_name: String, points: Array[Vector2], width: float, surface_y: float, material: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in points.size():
		var tangent: Vector2
		if index == 0:
			tangent = (points[1] - points[0]).normalized()
		elif index == points.size() - 1:
			tangent = (points[index] - points[index - 1]).normalized()
		else:
			tangent = (points[index + 1] - points[index - 1]).normalized()
		var side := Vector2(-tangent.y, tangent.x) * width * 0.5
		vertices.append(Vector3((points[index] + side).x, surface_y, (points[index] + side).y))
		vertices.append(Vector3((points[index] - side).x, surface_y, (points[index] - side).y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	var indices := PackedInt32Array()
	for index in range(points.size() - 1):
		var base := index * 2
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	return _mesh_instance_from_arrays(node_name, vertices, normals, indices, PackedColorArray(), material)


func _mesh_instance_from_arrays(node_name: String, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, colors: PackedColorArray, material: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("presentation_only", true)
	return instance


func _instantiate_detail(asset_path: String) -> Node3D:
	var packed: PackedScene = _asset_scene_cache.get(asset_path) as PackedScene
	if packed == null:
		packed = load(asset_path) as PackedScene
		if packed == null:
			if not _missing_assets.has(asset_path):
				_missing_assets.append(asset_path)
			return null
		_asset_scene_cache[asset_path] = packed
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.set_meta("source_asset", asset_path)
	instance.set_meta("presentation_only", true)
	for body in instance.find_children("*", "CollisionObject3D", true, false):
		var parent := body.get_parent()
		if parent != null:
			parent.remove_child(body)
		body.queue_free()
	for mesh in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if asset_path.contains("grass_common"):
			_tint_imported_detail_material(mesh_instance, Color("#718469"), _materials["grass_common"], true)
		elif asset_path.contains("grass_wispy"):
			_tint_imported_detail_material(mesh_instance, Color("#64785e"), _materials["grass_wispy"], true)
		elif asset_path.contains("clover"):
			_tint_imported_detail_material(mesh_instance, Color("#788b6e"), _materials["clover"], false)
		elif asset_path.contains("pebble_"):
			_tint_imported_detail_material(mesh_instance, Color("#6b6b64"), _materials["pebble"], false)
	return instance


func _tint_imported_detail_material(mesh_instance: MeshInstance3D, tint: Color, fallback: Material, use_alpha_scissor: bool) -> void:
	var source := mesh_instance.get_active_material(0) as BaseMaterial3D
	if source == null:
		mesh_instance.material_override = fallback
		return
	var material := source.duplicate() as BaseMaterial3D
	material.albedo_color = tint
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.96
	if use_alpha_scissor:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.48
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material


func _point_overlaps_any_building_lot(point: Vector2, clearance: float) -> bool:
	for raw_building in _layout.get("buildings", []):
		var building := raw_building as Dictionary
		var local := _station_to_building_local(building, point)
		var lot_size := _v2(building.get("lot_size", [0.0, 0.0]))
		if absf(local.x) <= lot_size.x * 0.5 + clearance and absf(local.y) <= lot_size.y * 0.5 + clearance:
			return true
	return false


func _point_overlaps_any_road(point: Vector2, clearance: float) -> bool:
	for raw_road in _layout.get("roads", []):
		var road := raw_road as Dictionary
		var distance := _distance_to_segment(point, _v2(road.get("from", [0.0, 0.0])), _v2(road.get("to", [0.0, 0.0])))
		if distance <= float(road.get("width", 3.0)) * 0.5 + clearance:
			return true
	return false


func _distance_to_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var delta := to_point - from_point
	if delta.length_squared() < 0.0001:
		return point.distance_to(from_point)
	var t := clampf((point - from_point).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(from_point + delta * t)


func _station_polygon() -> PackedVector2Array:
	var result := PackedVector2Array()
	var station := _layout.get("station", {}) as Dictionary
	for raw_point in station.get("interior_polygon", []):
		result.append(_v2(raw_point))
	return result


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _find_public_plaza() -> Dictionary:
	for raw_location in _layout.get("public_locations", []):
		var location := raw_location as Dictionary
		if str(location.get("id", "")) == "plaza":
			return location
	return {}


func _detail_asset_paths() -> Array[String]:
	var result: Array[String] = []
	var details := _ground_config().get("embedded_details", {}) as Dictionary
	for key in ["pebble_assets", "vegetation_assets"]:
		for raw_path in details.get(key, []):
			result.append(str(raw_path))
	return result


func _ground_config() -> Dictionary:
	return _environment_config.get("station_ground", {}) as Dictionary


func _make_transparent_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	color.a = alpha
	material.albedo_color = color
	material.roughness = 0.98
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


func _make_detail_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


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


func _stable_hash(value: String) -> int:
	var result := 2166136261
	for codepoint in value.to_utf8_buffer():
		result = int((result ^ int(codepoint)) * 16777619) & 0x7fffffff
	return result


func _unit_noise(seed_value: int, index: int, salt: int) -> float:
	var value := int(seed_value * 1103515245 + index * 12345 + salt * 2654435761) & 0x7fffffff
	return float(value % 10000) / 9999.0


func _signed_noise(seed_value: int, index: int, salt: int) -> float:
	return _unit_noise(seed_value, index, salt) * 2.0 - 1.0


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
