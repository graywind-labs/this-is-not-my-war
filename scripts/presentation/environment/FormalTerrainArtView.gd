extends Node3D

const EXPECTED_SCHEMA := "environment_art_v1"
const ART_REVISION := "t0135_p7"

const GROUND_SHADER_SOURCE := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec4 grass_dark : source_color = vec4(0.208, 0.298, 0.227, 1.0);
uniform vec4 grass_base : source_color = vec4(0.251, 0.345, 0.259, 1.0);
uniform vec4 grass_light : source_color = vec4(0.275, 0.373, 0.275, 1.0);

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
	float broad = value_noise(world_position.xz * 0.022);
	float secondary = value_noise(world_position.xz * 0.071 + vec2(14.2, -8.4));
	vec3 base = mix(grass_dark.rgb, grass_base.rgb, smoothstep(0.12, 0.64, broad));
	ALBEDO = mix(base, grass_light.rgb, smoothstep(0.62, 0.92, broad)) * mix(0.94, 1.025, secondary);
	ROUGHNESS = mix(0.91, 0.99, secondary);
}
"""

const WATER_SHADER_SOURCE := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform vec4 deep_color : source_color = vec4(0.055, 0.235, 0.330, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.105, 0.390, 0.505, 1.0);
uniform float flow_speed = 0.42;

varying vec3 world_position;

void vertex() {
	float wave_a = sin(VERTEX.z * 0.19 + TIME * flow_speed * 2.2);
	float wave_b = sin(VERTEX.x * 0.43 - TIME * flow_speed * 1.4);
	VERTEX.y += (wave_a + wave_b) * 0.025;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = sin(world_position.z * 0.085 - TIME * flow_speed * 3.2 + sin(world_position.x * 0.31));
	float ripple = smoothstep(0.55, 0.94, band * 0.5 + 0.5);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, 0.42 + ripple * 0.18);
	ROUGHNESS = mix(0.34, 0.19, ripple);
	SPECULAR = 0.58;
}
"""

var _environment_config: Dictionary = {}
var _layout: Dictionary = {}
var _profile: Array[Dictionary] = []
var _asset_scene_cache: Dictionary = {}
var _missing_assets: Array[String] = []
var _plateau_triangle_count := 0
var _bank_triangle_count := 0
var _water_triangle_count := 0
var _foam_triangle_count := 0
var _riverbank_rock_count := 0
var _minimum_valley_width := INF
var _maximum_valley_width := 0.0
var _minimum_water_width := INF
var _maximum_water_width := 0.0
var _mountain_profile: Array[Dictionary] = []
var _mountain_triangle_counts := {"near": 0, "mid": 0, "far": 0}
var _mountain_x_ranges := {"near": Vector2.ZERO, "mid": Vector2.ZERO, "far": Vector2.ZERO}
var _mountain_max_heights := {"near": 0.0, "mid": 0.0, "far": 0.0}
var _mountain_boulder_count := 0


func configure(environment_config: Dictionary, station_layout: Dictionary) -> void:
	_environment_config = environment_config.duplicate(true)
	_layout = station_layout.duplicate(true)
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_rebuild()


func get_debug_snapshot() -> Dictionary:
	var terrain := _layout.get("terrain", {}) as Dictionary
	return {
		"art_revision": ART_REVISION,
		"profile_sample_count": _profile.size(),
		"plateau_triangle_count": _plateau_triangle_count,
		"bank_triangle_count": _bank_triangle_count,
		"water_triangle_count": _water_triangle_count,
		"foam_triangle_count": _foam_triangle_count,
		"riverbank_rock_count": _riverbank_rock_count,
		"missing_assets": _missing_assets.duplicate(),
		"minimum_valley_width": _minimum_valley_width if is_finite(_minimum_valley_width) else 0.0,
		"maximum_valley_width": _maximum_valley_width,
		"minimum_water_width": _minimum_water_width if is_finite(_minimum_water_width) else 0.0,
		"maximum_water_width": _maximum_water_width,
		"river_start_z": float(_profile[0].get("z", 0.0)) if not _profile.is_empty() else 0.0,
		"river_end_z": float(_profile[-1].get("z", 0.0)) if not _profile.is_empty() else 0.0,
		"mountain_profile_sample_count": _mountain_profile.size(),
		"mountain_start_z": float(_mountain_profile[0].get("z", 0.0)) if not _mountain_profile.is_empty() else 0.0,
		"mountain_end_z": float(_mountain_profile[-1].get("z", 0.0)) if not _mountain_profile.is_empty() else 0.0,
		"mountain_triangle_counts": _mountain_triangle_counts.duplicate(),
		"mountain_x_ranges": _mountain_x_ranges.duplicate(),
		"mountain_max_heights": _mountain_max_heights.duplicate(),
		"mountain_boulder_count": _mountain_boulder_count,
		"ground_surface_y": float(terrain.get("ground_surface_y", 0.0)),
		"water_surface_y": float(terrain.get("river_surface_y", -1.2)),
		"cross_water_ground_surface_count": 0,
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
	_profile.clear()
	_asset_scene_cache.clear()
	_missing_assets.clear()
	_plateau_triangle_count = 0
	_bank_triangle_count = 0
	_water_triangle_count = 0
	_foam_triangle_count = 0
	_riverbank_rock_count = 0
	_minimum_valley_width = INF
	_maximum_valley_width = 0.0
	_minimum_water_width = INF
	_maximum_water_width = 0.0
	_mountain_profile.clear()
	_mountain_triangle_counts = {"near": 0, "mid": 0, "far": 0}
	_mountain_x_ranges = {"near": Vector2.ZERO, "mid": Vector2.ZERO, "far": Vector2.ZERO}
	_mountain_max_heights = {"near": 0.0, "mid": 0.0, "far": 0.0}
	_mountain_boulder_count = 0
	if str(_environment_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		return
	var topology := _environment_config.get("terrain_topology", {}) as Dictionary
	for raw_sample in topology.get("river_profile", []):
		var values := raw_sample as Array
		if values.size() < 4:
			continue
		var sample := {
			"z": float(values[0]),
			"center_x": float(values[1]),
			"valley_width": float(values[2]),
			"water_width": float(values[3]),
			"water_offset": float(values[4]) if values.size() >= 5 else 0.0
		}
		_profile.append(sample)
		_minimum_valley_width = minf(_minimum_valley_width, float(sample["valley_width"]))
		_maximum_valley_width = maxf(_maximum_valley_width, float(sample["valley_width"]))
		_minimum_water_width = minf(_minimum_water_width, float(sample["water_width"]))
		_maximum_water_width = maxf(_maximum_water_width, float(sample["water_width"]))
	if _profile.size() < 2:
		return
	_build_terrain(topology)
	_build_east_mountain(topology.get("east_mountain", {}) as Dictionary)
	set_meta("art_revision", ART_REVISION)
	set_meta("presentation_only", true)


func _build_terrain(topology: Dictionary) -> void:
	var terrain := _layout.get("terrain", {}) as Dictionary
	var center := _v2(terrain.get("center", [0.0, 25.0]))
	var size := _v2(terrain.get("size", [700.0, 720.0]))
	var left_edge := center.x - size.x * 0.5
	var right_edge := center.x + size.x * 0.5
	var ground_y := float(terrain.get("ground_surface_y", 0.0))
	var water_y := float(terrain.get("river_surface_y", -1.2))
	var ground_material := _make_ground_material(topology)
	var bank_material := _make_vertex_material()
	var bed_material := _make_color_material(Color("#343c39"), 1.0)
	var water_material := _make_water_material(topology)
	var foam_material := _make_color_material(Color(0.49, 0.72, 0.75, 0.42), 0.42)
	var plateau_root := Node3D.new()
	plateau_root.name = "DisconnectedPlateaus"
	add_child(plateau_root)
	var west_plateau := _build_two_column_strip("WestPlateau", func(sample: Dictionary) -> Array:
		return [Vector3(left_edge, ground_y, float(sample["z"])), Vector3(_valley_edge(sample, -1.0), ground_y, float(sample["z"]))]
	, ground_material)
	var east_plateau := _build_two_column_strip("EastPlateau", func(sample: Dictionary) -> Array:
		return [Vector3(_valley_edge(sample, 1.0), ground_y, float(sample["z"])), Vector3(right_edge, ground_y, float(sample["z"]))]
	, ground_material)
	plateau_root.add_child(west_plateau)
	plateau_root.add_child(east_plateau)
	_plateau_triangle_count = (_profile.size() - 1) * 4

	var banks_root := Node3D.new()
	banks_root.name = "TerracedRiverBanks"
	add_child(banks_root)
	for raw_side in [-1.0, 1.0]:
		var side := float(raw_side)
		var bank := _build_bank("WestBank" if side < 0.0 else "EastBank", side, ground_y, water_y, topology, bank_material)
		banks_root.add_child(bank)
	_bank_triangle_count = (_profile.size() - 1) * 16

	var bed := _build_two_column_strip("RiverBed", func(sample: Dictionary) -> Array:
		var half_width := float(sample["water_width"]) * 0.5 + 1.8
		return [Vector3(_water_center(sample) - half_width, water_y - 0.22, float(sample["z"])), Vector3(_water_center(sample) + half_width, water_y - 0.22, float(sample["z"]))]
	, bed_material)
	bed.set_meta("low_river_bed", true)
	add_child(bed)

	var water := _build_two_column_strip("RiverWaterRibbon", func(sample: Dictionary) -> Array:
		var half_width := float(sample["water_width"]) * 0.5
		return [Vector3(_water_center(sample) - half_width, water_y, float(sample["z"])), Vector3(_water_center(sample) + half_width, water_y, float(sample["z"]))]
	, water_material)
	water.set_meta("animated_flow", true)
	water.set_meta("water_surface_y", water_y)
	add_child(water)
	_water_triangle_count = (_profile.size() - 1) * 2

	var foam_root := Node3D.new()
	foam_root.name = "SubtleBankFoam"
	add_child(foam_root)
	for raw_side in [-1.0, 1.0]:
		var side := float(raw_side)
		var foam := _build_two_column_strip("WestFoam" if side < 0.0 else "EastFoam", func(sample: Dictionary) -> Array:
			var edge := _water_center(sample) + float(sample["water_width"]) * 0.5 * side
			return [Vector3(edge, water_y + 0.035, float(sample["z"])), Vector3(edge + side * 0.22, water_y + 0.035, float(sample["z"]))]
		, foam_material)
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		foam_root.add_child(foam)
	_foam_triangle_count = (_profile.size() - 1) * 4
	_build_riverbank_rocks(topology, ground_y, water_y)


func _build_east_mountain(config: Dictionary) -> void:
	for raw_sample in config.get("profile", []):
		var values := raw_sample as Array
		if values.size() < 4:
			continue
		_mountain_profile.append({
			"z": float(values[0]),
			"near_height": float(values[1]),
			"mid_height": float(values[2]),
			"far_height": float(values[3]),
			"offset": float(values[4]) if values.size() >= 5 else 0.0
		})
	if _mountain_profile.size() < 2:
		return
	var root_node := Node3D.new()
	root_node.name = "EastThreeLayerMountain"
	root_node.set_meta("presentation_only", true)
	add_child(root_node)
	for layer_name in ["far", "mid", "near"]:
		var x_range := _v2(config.get("%s_x_range" % layer_name, [0.0, 0.0]))
		var palette := _color_palette(config.get("%s_palette" % layer_name, []), layer_name)
		var ridge := _build_mountain_layer(layer_name, x_range, palette)
		root_node.add_child(ridge)
		_mountain_x_ranges[layer_name] = x_range
	_build_mountain_boulders(root_node, config)


func _build_mountain_layer(layer_name: String, x_range: Vector2, palette: Array[Color]) -> MeshInstance3D:
	var rows: Array[Array] = []
	var height_key := "%s_height" % layer_name
	var max_height := 0.0
	var render_profile: Array[Dictionary] = []
	for sample_index in _mountain_profile.size():
		var source_sample := _mountain_profile[sample_index]
		render_profile.append(source_sample)
		if sample_index >= _mountain_profile.size() - 1:
			continue
		var next_sample := _mountain_profile[sample_index + 1]
		var midpoint_scale := 0.88 + float((sample_index * 7 + layer_name.length()) % 5) * 0.027
		render_profile.append({
			"z": (float(source_sample["z"]) + float(next_sample["z"])) * 0.5,
			"near_height": (float(source_sample["near_height"]) + float(next_sample["near_height"])) * 0.5 * midpoint_scale,
			"mid_height": (float(source_sample["mid_height"]) + float(next_sample["mid_height"])) * 0.5 * midpoint_scale,
			"far_height": (float(source_sample["far_height"]) + float(next_sample["far_height"])) * 0.5 * midpoint_scale,
			"offset": (float(source_sample["offset"]) + float(next_sample["offset"])) * 0.5 + sin(float(sample_index) * 2.17) * 2.2
		})
	for sample_index in render_profile.size():
		var sample := render_profile[sample_index]
		var height := float(sample[height_key])
		var offset := float(sample["offset"])
		max_height = maxf(max_height, height)
		var width := x_range.y - x_range.x
		var inner_a := x_range.x + width * 0.18 + offset * 0.18
		var inner_b := x_range.x + width * 0.37 + offset * 0.42
		var inner_c := x_range.x + width * 0.58 + offset * 0.63
		var inner_d := x_range.x + width * 0.78 + offset * 0.45
		var ridge_x := x_range.x + width * 0.94 + offset * 0.20
		var phase := float(sample_index) * 1.37 + (0.0 if layer_name == "near" else 0.7 if layer_name == "mid" else 1.4)
		rows.append([
			Vector3(x_range.x, 0.02, float(sample["z"])),
			Vector3(inner_a, height * (0.20 + sin(phase) * 0.028), float(sample["z"])),
			Vector3(inner_b, height * (0.43 + cos(phase * 0.73) * 0.042), float(sample["z"])),
			Vector3(inner_c, height * (0.67 + sin(phase * 0.61 + 0.8) * 0.050), float(sample["z"])),
			Vector3(inner_d, height * (0.86 + cos(phase * 0.89 - 0.4) * 0.035), float(sample["z"])),
			Vector3(ridge_x, height, float(sample["z"]))
		])
	_mountain_max_heights[layer_name] = max_height
	_mountain_triangle_counts[layer_name] = (rows.size() - 1) * (rows[0].size() - 1) * 2
	var mesh_instance := _mesh_from_colored_grid("%sMountainLayer" % layer_name.capitalize(), rows, palette)
	mesh_instance.set_meta("mountain_layer", layer_name)
	mesh_instance.set_meta("x_range", x_range)
	mesh_instance.set_meta("max_height", max_height)
	return mesh_instance


func _mesh_from_colored_grid(node_name: String, rows: Array[Array], palette: Array[Color]) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row_index in range(rows.size() - 1):
		var row := rows[row_index]
		var next_row := rows[row_index + 1]
		for column_index in range(row.size() - 1):
			var a := row[column_index] as Vector3
			var b := row[column_index + 1] as Vector3
			var c := next_row[column_index] as Vector3
			var d := next_row[column_index + 1] as Vector3
			_add_colored_triangle(surface, a, c, b, palette, column_index, row_index)
			_add_colored_triangle(surface, b, c, d, palette, column_index, row_index + 1)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, _make_vertex_material())
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.set_meta("presentation_only", true)
	return instance


func _add_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, palette: Array[Color], column_index: int, row_index: int) -> void:
	var base_color: Color = palette[mini(column_index, palette.size() - 1)]
	var shade := 0.91 + float((row_index * 3 + column_index * 5) % 5) * 0.035
	for vertex in [a, b, c]:
		surface.set_color(Color(base_color.r * shade, base_color.g * shade, base_color.b * shade, 1.0))
		surface.add_vertex(vertex)


func _build_mountain_boulders(root_node: Node3D, config: Dictionary) -> void:
	var assets := config.get("boulder_assets", []) as Array
	if assets.is_empty():
		return
	var boulder_root := Node3D.new()
	boulder_root.name = "MountainBoulderBreakup"
	boulder_root.set_meta("presentation_only", true)
	root_node.add_child(boulder_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("boulder_seed", 13524))
	for sample_index in range(1, _mountain_profile.size() - 1):
		var sample := _mountain_profile[sample_index]
		for layer_name in ["near", "mid"]:
			var x_range := _mountain_x_ranges.get(layer_name, Vector2.ZERO) as Vector2
			var height := float(sample["%s_height" % layer_name])
			var count := 2 if layer_name == "near" else 1
			for rock_index in count:
				var slope_t := rng.randf_range(0.25, 0.78)
				var rock := _instantiate_asset(str(assets[rng.randi_range(0, assets.size() - 1)]))
				if rock == null:
					continue
				rock.name = "%sBoulder%02d_%d" % [layer_name.capitalize(), sample_index, rock_index]
				rock.position = Vector3(
					lerpf(x_range.x, x_range.y, slope_t) + rng.randf_range(-2.2, 2.2),
					height * lerpf(0.18, 0.68, slope_t),
					float(sample["z"]) + rng.randf_range(-13.0, 13.0)
				)
				var scale_value := rng.randf_range(7.0, 13.5) if layer_name == "near" else rng.randf_range(10.0, 17.0)
				rock.scale = Vector3(scale_value * rng.randf_range(0.75, 1.25), scale_value, scale_value * rng.randf_range(0.72, 1.18))
				rock.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-9.0, 9.0))
				rock.set_meta("mountain_breakup", layer_name)
				boulder_root.add_child(rock)
				_mountain_boulder_count += 1


func _build_bank(node_name: String, side: float, ground_y: float, water_y: float, topology: Dictionary, material: Material) -> MeshInstance3D:
	var shoulder_drop := float(topology.get("bank_shoulder_drop", 0.42))
	var water_edge_drop := float(topology.get("water_edge_drop", 0.08))
	var columns: Array[Array] = []
	for sample_index in _profile.size():
		var sample := _profile[sample_index]
		var valley_edge := _valley_edge(sample, side)
		var water_edge := _water_center(sample) + float(sample["water_width"]) * 0.5 * side
		var phase := float(sample_index) * 1.71 + side * 0.83
		var upper_t := 0.26 + sin(phase) * 0.045
		var shoulder_t := 0.57 + sin(phase * 0.73 + 1.4) * 0.055
		var wet_t := 0.82 + sin(phase * 1.13 - 0.6) * 0.035
		var upper_slope := lerpf(valley_edge, water_edge, upper_t)
		var shoulder := lerpf(valley_edge, water_edge, shoulder_t)
		var wet_shelf := lerpf(valley_edge, water_edge, wet_t)
		var vertical_jitter := sin(phase * 0.91) * 0.055
		columns.append([
			Vector3(valley_edge, ground_y, float(sample["z"])),
			Vector3(upper_slope, ground_y - 0.12 + vertical_jitter, float(sample["z"])),
			Vector3(shoulder, ground_y - shoulder_drop - vertical_jitter, float(sample["z"])),
			Vector3(wet_shelf, water_y + 0.28 + vertical_jitter * 0.5, float(sample["z"])),
			Vector3(water_edge, water_y + water_edge_drop, float(sample["z"]))
		])
	return _mesh_from_grid(node_name, columns, material, true)


func _build_two_column_strip(node_name: String, row_builder: Callable, material: Material) -> MeshInstance3D:
	var rows: Array[Array] = []
	for sample in _profile:
		rows.append(row_builder.call(sample) as Array)
	return _mesh_from_grid(node_name, rows, material, false)


func _mesh_from_grid(node_name: String, rows: Array[Array], material: Material, use_bank_colors: bool) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row_index in range(rows.size() - 1):
		var row := rows[row_index]
		var next_row := rows[row_index + 1]
		for column_index in range(row.size() - 1):
			var a := row[column_index] as Vector3
			var b := row[column_index + 1] as Vector3
			var c := next_row[column_index] as Vector3
			var d := next_row[column_index + 1] as Vector3
			_add_triangle(surface, a, c, b, column_index, row_index, use_bank_colors)
			_add_triangle(surface, b, c, d, column_index, row_index, use_bank_colors)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.set_meta("presentation_only", true)
	return instance


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, column_index: int, row_index: int, use_bank_colors: bool) -> void:
	for vertex in [a, b, c]:
		if use_bank_colors:
			var palette := [Color("#404b3b"), Color("#5a5142"), Color("#625746"), Color("#454946")]
			var base_color: Color = palette[mini(column_index, palette.size() - 1)]
			var shade := 0.94 + float((row_index + column_index * 2) % 4) * 0.025
			surface.set_color(Color(base_color.r * shade, base_color.g * shade, base_color.b * shade, 1.0))
		surface.add_vertex(vertex)


func _build_riverbank_rocks(topology: Dictionary, ground_y: float, water_y: float) -> void:
	var assets := topology.get("riverbank_rock_assets", []) as Array
	if assets.is_empty():
		return
	var root_node := Node3D.new()
	root_node.name = "RiverbankRockBreakup"
	root_node.set_meta("presentation_only", true)
	add_child(root_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(topology.get("riverbank_rock_seed", 13523))
	for sample_index in range(1, _profile.size() - 1):
		var sample := _profile[sample_index]
		for raw_side in [-1.0, 1.0]:
			var side := float(raw_side)
			var valley_edge := _valley_edge(sample, side)
			var water_edge := _water_center(sample) + float(sample["water_width"]) * 0.5 * side
			var slope_t := rng.randf_range(0.30, 0.72)
			var rock_x := lerpf(valley_edge, water_edge, slope_t) + rng.randf_range(-0.35, 0.35)
			var rock_y := lerpf(ground_y - 0.12, water_y + 0.28, inverse_lerp(0.28, 0.82, slope_t))
			var asset_path := str(assets[rng.randi_range(0, assets.size() - 1)])
			var rock := _instantiate_asset(asset_path)
			if rock == null:
				continue
			rock.name = "RiverbankRock%02d%s" % [sample_index, "W" if side < 0.0 else "E"]
			rock.position = Vector3(rock_x, rock_y, float(sample["z"]) + rng.randf_range(-6.5, 6.5))
			var scale_value := rng.randf_range(4.0, 8.5)
			rock.scale = Vector3(scale_value * rng.randf_range(0.82, 1.18), scale_value, scale_value * rng.randf_range(0.82, 1.18))
			rock.rotation_degrees.y = rng.randf_range(0.0, 360.0)
			rock.set_meta("riverbank_breakup", true)
			root_node.add_child(rock)
			_riverbank_rock_count += 1
			if sample_index % 3 == 0:
				var companion := _instantiate_asset(str(assets[rng.randi_range(0, assets.size() - 1)]))
				if companion != null:
					companion.name = "%sCompanion" % rock.name
					companion.position = rock.position + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.8, 1.8))
					var companion_scale := rng.randf_range(2.2, 4.8)
					companion.scale = Vector3.ONE * companion_scale
					companion.rotation_degrees.y = rng.randf_range(0.0, 360.0)
					companion.set_meta("riverbank_breakup", true)
					root_node.add_child(companion)
					_riverbank_rock_count += 1


func _instantiate_asset(asset_path: String) -> Node3D:
	var packed := _asset_scene_cache.get(asset_path) as PackedScene
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
		var body_parent := body.get_parent()
		if body_parent != null:
			body_parent.remove_child(body)
		body.queue_free()
	for mesh in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var rock_material := StandardMaterial3D.new()
		rock_material.albedo_color = Color("#555954")
		rock_material.roughness = 0.96
		mesh_instance.material_override = rock_material
	return instance


func _valley_edge(sample: Dictionary, side: float) -> float:
	return float(sample["center_x"]) + float(sample["valley_width"]) * 0.5 * side


func _water_center(sample: Dictionary) -> float:
	return float(sample["center_x"]) + float(sample.get("water_offset", 0.0))


func _make_ground_material(topology: Dictionary) -> ShaderMaterial:
	var palette := ((_environment_config.get("station_ground", {}) as Dictionary).get("palette", {}) as Dictionary)
	var shader := Shader.new()
	shader.code = GROUND_SHADER_SOURCE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grass_dark", Color.from_string(str(palette.get("grass_dark", "#354c3a")), Color("#354c3a")))
	material.set_shader_parameter("grass_base", Color.from_string(str(palette.get("grass_base", "#405842")), Color("#405842")))
	material.set_shader_parameter("grass_light", Color.from_string(str(palette.get("grass_light", "#465f46")), Color("#465f46")))
	return material


func _make_water_material(topology: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = WATER_SHADER_SOURCE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("deep_color", Color.from_string(str(topology.get("water_deep_color", "#0e3c54")), Color("#0e3c54")))
	material.set_shader_parameter("shallow_color", Color.from_string(str(topology.get("water_shallow_color", "#1b647f")), Color("#1b647f")))
	material.set_shader_parameter("flow_speed", float(topology.get("flow_speed", 0.42)))
	return material


func _make_vertex_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.98
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_color_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	color.a = alpha
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _color_palette(raw_palette: Variant, layer_name: String) -> Array[Color]:
	var result: Array[Color] = []
	if raw_palette is Array:
		for raw_color in raw_palette:
			result.append(Color.from_string(str(raw_color), Color("#555954")))
	if result.is_empty():
		var fallback := Color("#555954") if layer_name == "near" else Color("#424a47")
		result = [fallback, fallback.lightened(0.08), fallback.darkened(0.08), fallback]
	while result.size() < 4:
		result.append(result[-1])
	return result


func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
