extends Node3D
## Approved river appearance shared by production and the independent review.
const CONFIG_PATH := "res://data/presentation/river_art_trial.json"
const WATER_SHADER := preload("res://shaders/environment/river_art_trial.gdshader")
const BANK_SHADER := preload("res://shaders/environment/riverbank_art_trial.gdshader")
var _style: Dictionary = {}
var _environment: Node3D
var _terrain: Node3D
var _water: MeshInstance3D
var _water_original: Mesh
var _water_candidate: Mesh
var _water_material := ShaderMaterial.new()
var _bank_material := ShaderMaterial.new()
var _rock_material := StandardMaterial3D.new()
var _rock_nodes: Array[MeshInstance3D] = []
var _shore_rocks := Node3D.new()
var _shoals := Node3D.new()
var _shore_noise := FastNoiseLite.new()
var _shore_rows: Array[Vector3] = []
var _footprints: Array[Vector4] = []
var _original: Dictionary = {}
var _geometry: Dictionary = {}
var _candidate := true
var _motion := true
var _flow_time := 0.0

func configure(environment: Node3D, settings: Dictionary) -> void:
	_environment = environment
	_style = settings.duplicate(true)
	assert(_style.get("schema_version", "") == "river_art_trial_v1")
	set_meta("presentation_only", true)
	_terrain = _environment.get_node("FullMapTerrainTopology")
	_water = _terrain.get_node("RiverWaterRibbon")
	_water_original = _water.mesh
	_water_material.shader = WATER_SHADER
	_water_material.set_shader_parameter("environment_origin", _environment.global_position)
	for key in ["deep_color", "shallow_color", "foam_color"]:
		_water_material.set_shader_parameter(key, Color(str(_style.get(key, "#30535a"))))
	for key in ["flow_speed", "ripple_strength"]:
		_water_material.set_shader_parameter(key, float(_style.get(key, 0.2)))
	_bank_material.shader = BANK_SHADER
	_bank_material.set_shader_parameter("environment_origin", _environment.global_position)
	var ground := _read("res://data/presentation/ground_art_trial.json")
	for key in ["grass_dark", "grass_light", "soil_dark", "soil_light"]:
		_bank_material.set_shader_parameter(key, Color(str(ground.get(key, "#38452c"))))
	for key in ["wet_color", "gravel_color"]:
		_bank_material.set_shader_parameter(key, Color(str(_style.get(key, "#54584c"))))
	_bank_material.set_shader_parameter("water_height", float(_water.get_meta("water_surface_y", -1.2)))
	_rock_material.albedo_color = Color(str(_style.get("rock_color", "#62665a")))
	_rock_material.roughness = 1.0
	for branch in ["TerracedRiverBanks", "RiverbankRockBreakup"]:
		for node: MeshInstance3D in _terrain.get_node(branch).find_children("*", "MeshInstance3D", true, false):
			if branch == "RiverbankRockBreakup":
				_rock_nodes.append(node)
			_original[node] = node.material_override
			_geometry[node] = {"mesh": node.mesh, "vertices": hash(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]), "transform": node.transform}
	_build_water_uv()
	_build_shore_rocks()
	_build_natural_shoreline()
	set_enabled(true)

func _process(delta: float) -> void:
	if _motion:
		_flow_time += delta
	_water_material.set_shader_parameter("flow_time", _flow_time)

func _build_water_uv() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: PackedVector3Array = _water_original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var profile: Array = _terrain._profile
	for vertex in vertices:
		var river_sample: Dictionary = profile[0]
		for sample_point: Dictionary in profile:
			if is_equal_approx(float(sample_point.z), vertex.z):
				river_sample = sample_point
				break
		var width := float(river_sample.water_width)
		var center: float = _terrain._water_center(river_sample)
		var cross_stream := (vertex.x-center)/width+0.5
		assert(cross_stream >= -0.0001 and cross_stream <= 1.0001)
		surface.set_uv(Vector2(cross_stream, vertex.z))
		surface.set_uv2(Vector2(width, 0.0))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
	_water_candidate = surface.commit()

func set_enabled(enabled: bool) -> void:
	_candidate = enabled
	_water.mesh = _water_candidate if enabled else _water_original
	_water.material_override = _water_material if enabled else null
	_terrain.get_node("SubtleBankFoam").visible = not enabled
	_shore_rocks.visible = enabled
	_shoals.visible = enabled
	for node: MeshInstance3D in _original:
		node.material_override = (_rock_material if _rock_nodes.has(node) else _bank_material) if enabled else _original[node]

func _river_at(z: float) -> Vector2:
	var profile: Array = _terrain._profile
	for i in range(profile.size()-1):
		var a: Dictionary = profile[i]
		var b: Dictionary = profile[i+1]
		if z >= float(a.z) and z <= float(b.z):
			var t := inverse_lerp(float(a.z), float(b.z), z)
			return Vector2(lerpf(_terrain._water_center(a), _terrain._water_center(b), t), lerpf(float(a.water_width), float(b.water_width), t))
	assert(false, "Shore rocks must stay within the original river profile")
	return Vector2.ZERO

func _build_shore_rocks() -> void:
	_shore_rocks.name = "CandidateWaterlineRocks"
	_shore_rocks.set_meta("presentation_only", true)
	add_child(_shore_rocks)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_style.get("shore_rock_seed", 366))
	var radius_range: Array = _style.get("shore_rock_radius", [0.85, 1.65])
	var water_y := float(_water.get_meta("water_surface_y", -1.2))
	for group: Array in _style.get("shore_rock_groups", []):
		for piece in 3:
			var z := float(group[0]) + piece*1.9 + rng.randf_range(-0.5,0.5)
			var river := _river_at(z)
			var side := float(group[1])
			var radius := rng.randf_range(radius_range[0],radius_range[1]) * (1.0-piece*0.19)
			var center := Vector2(river.x+side*(river.y*0.5+rng.randf_range(-0.4,0.2)),z)
			var radii := Vector2(radius, radius*rng.randf_range(0.72,1.05))
			var rise := rng.randf_range(0.6,1.15)*(1.0-piece*0.16)
			var bottom: Array[Vector3] = []
			var shoulder: Array[Vector3] = []
			var cap: Array[Vector3] = []
			for corner in 7:
				var angle := float(corner)*TAU/7.0
				var offset := Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
				bottom.append(Vector3(center.x+offset.x*0.90,water_y-0.40,center.y+offset.y*0.90))
				shoulder.append(Vector3(center.x+offset.x,water_y+0.12,center.y+offset.y))
				cap.append(Vector3(center.x+offset.x*0.60,water_y+rise*rng.randf_range(0.85,1.0),center.y+offset.y*0.60))
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var peak := Vector3(center.x,water_y+rise,center.y)
			for corner in 7:
				var next := (corner+1)%7
				_face(surface,peak,cap[corner],cap[next])
				_face(surface,cap[corner],shoulder[corner],shoulder[next])
				_face(surface,cap[corner],shoulder[next],cap[next])
				_face(surface,shoulder[corner],bottom[corner],bottom[next])
				_face(surface,shoulder[corner],bottom[next],shoulder[next])
			var rock := MeshInstance3D.new()
			rock.name = "WaterlineRock%02d" % _footprints.size()
			rock.mesh = surface.commit()
			rock.material_override = _rock_material
			_shore_rocks.add_child(rock)
			_footprints.append(Vector4(center.x,center.y,radii.x*0.96,radii.y*0.96))
	assert(_footprints.size() <= 32)
	_water_material.set_shader_parameter("rock_count", _footprints.size())
	var parameters := _footprints.duplicate()
	parameters.resize(32)
	_water_material.set_shader_parameter("rock_footprints", parameters)
	_water_material.set_shader_parameter("foam_strength", float(_style.get("foam_strength",0.78)))

func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for v in [a,b,c]:
		surface.set_normal(normal)
		surface.add_vertex(v)

func _shore_inset(z: float, side: float, width: float) -> float:
	# Independent banks: broad gravel tongues, smaller scallops, scoured rock pockets.
	var lane := 97.0 if side > 0.0 else -173.0
	var broad := _shore_noise.get_noise_2d(z * 0.048, lane) * 0.5 + 0.5
	var detail := _shore_noise.get_noise_2d(z * 0.23, lane + 41.0) * 0.5 + 0.5
	var inset := 0.18 + pow(broad, 1.3) * float(_style.get("shoreline_max_inset", 2.2)) + detail * 0.48
	for footprint in _footprints:
		var river := _river_at(footprint.y)
		if signf(footprint.x - river.x) == side:
			inset *= lerpf(0.06, 1.0, smoothstep(footprint.w + 0.35, footprint.w + 3.2, absf(z - footprint.y)))
	return minf(inset, width * 0.25)

func _bank_height(p: Vector2, vertices: PackedVector3Array) -> float:
	# Seat the join on the actual original triangles, including their diagonal split.
	for i in range(0, vertices.size(), 3):
		var a := Vector2(vertices[i].x, vertices[i].z)
		var b := Vector2(vertices[i + 1].x, vertices[i + 1].z)
		var c := Vector2(vertices[i + 2].x, vertices[i + 2].z)
		var divisor := (b - a).cross(c - a)
		if absf(divisor) < 0.000001:
			continue
		var u := (p - a).cross(c - a) / divisor
		var v := (b - a).cross(p - a) / divisor
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			return vertices[i].y * (1.0 - u - v) + vertices[i + 1].y * u + vertices[i + 2].y * v
	assert(false, "The new shore must join the original bank")
	return 0.0

func _build_natural_shoreline() -> void:
	_shoals.name = "NaturalShorelineShoals"
	_shoals.set_meta("presentation_only", true)
	add_child(_shoals)
	_shore_noise.seed = int(_style.get("shoreline_seed", 3661))
	_shore_noise.frequency = 1.0
	var profile: Array = _terrain._profile
	var water_y := float(_water.get_meta("water_surface_y", -1.2))
	var row_z: Array[float] = []
	for i in range(profile.size() - 1):
		var start := float(profile[i].z)
		var end := float(profile[i + 1].z)
		var steps := ceili((end - start) / float(_style.get("shoreline_step", 1.2)))
		for step in steps:
			row_z.append(lerpf(start, end, float(step) / steps))
	row_z.append(float(profile[-1].z))
	for side: float in [-1.0, 1.0]:
		var bank: MeshInstance3D = _terrain.get_node("TerracedRiverBanks/" + ("WestBank" if side < 0.0 else "EastBank"))
		var original_vertices: PackedVector3Array = bank.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var rows: Array[Array] = []
		for z in row_z:
			var river := _river_at(z)
			var edge := river.x + side * river.y * 0.5
			var inset := _shore_inset(z, side, river.y)
			var outer := edge + side * 0.65
			var outer_y := _bank_height(Vector2(outer, z), original_vertices)
			rows.append([
				Vector3(outer, outer_y + 0.008, z),
				Vector3(edge, water_y + 0.082, z),
				Vector3(edge - side * inset, water_y, z),
				Vector3(edge - side * (inset + 0.24), water_y - 0.16, z)
			])
			_shore_rows.append(Vector3(z, side, inset))
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(rows.size() - 1):
			for column in 3:
				_shore_face(surface, rows[i][column], rows[i + 1][column], rows[i][column + 1])
				_shore_face(surface, rows[i][column + 1], rows[i + 1][column], rows[i + 1][column + 1])
		var shoal := MeshInstance3D.new()
		shoal.name = "WestShallows" if side < 0.0 else "EastShallows"
		shoal.mesh = surface.commit()
		shoal.material_override = _bank_material
		shoal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shoals.add_child(shoal)
	# A tiny lookup keeps shallow water shading attached to the static new waterline.
	var lookup := Image.create(2048, 1, false, Image.FORMAT_RGF)
	for i in lookup.get_width():
		var z := lerpf(float(profile[0].z), float(profile[-1].z), float(i) / (lookup.get_width() - 1))
		var river := _river_at(z)
		lookup.set_pixel(i, 0, Color(_shore_inset(z, -1.0, river.y), _shore_inset(z, 1.0, river.y), 0.0, 1.0))
	_water_material.set_shader_parameter("shoreline_lookup", ImageTexture.create_from_image(lookup))
	_water_material.set_shader_parameter("shoreline_z_range", Vector2(float(profile[0].z), float(profile[-1].z)))

func _shore_face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (c - a).cross(b - a).y < 0.0:
		_face(surface, a, c, b)
	else:
		_face(surface, a, b, c)

func verify_geometry_contract() -> Dictionary:
	var original_vertices: PackedVector3Array = _water_original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(original_vertices == _water_candidate.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	for node: MeshInstance3D in _geometry:
		assert(node.mesh == _geometry[node].mesh and node.transform == _geometry[node].transform)
		assert(hash(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]) == _geometry[node].vertices)
	assert(find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(find_children("*", "NavigationRegion3D", true, false).is_empty())
	var forest: Dictionary = _environment.get_node("FullMapDenseForest").get_debug_snapshot()
	assert(forest.total_tree_count == 7393)
	for footprint in _footprints:
		var river := _river_at(footprint.y)
		assert(absf(absf(footprint.x-river.x)-river.y*0.5) <= 0.41)
		assert(absf(footprint.x-river.x)-footprint.z > river.y*0.20, "Keep the central channel open")
	assert(_footprints.size() == _shore_rocks.get_child_count())
	var water_y := float(_water.get_meta("water_surface_y", -1.2))
	for rock: MeshInstance3D in _shore_rocks.get_children():
		var bounds := rock.mesh.get_aabb()
		assert(bounds.position.y < water_y-0.2 and bounds.end.y > water_y)
	assert(int(_water_material.get_shader_parameter("rock_count")) == _footprints.size())
	assert(_shoals.get_child_count() == 2 and _shore_rows.size() > 1000)
	var minimum_inset := INF
	var maximum_inset := 0.0
	for row in _shore_rows:
		var river := _river_at(row.x)
		assert(row.z >= 0.0 and row.z <= river.y * 0.25 + 0.001, "Keep at least half the water channel open")
		minimum_inset = minf(minimum_inset, row.z)
		maximum_inset = maxf(maximum_inset, row.z)
	assert(maximum_inset - minimum_inset > 1.0, "Shoreline must have visible width variation")
	for shoal: MeshInstance3D in _shoals.get_children():
		for normal: Vector3 in shoal.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
			assert(normal.y > 0.0, "Both shallow banks must face upward")
	return {"original_water_vertices": original_vertices.size(), "water_positions_unchanged": true, "bank_and_rock_meshes_unchanged": _geometry.size(), "waterline_rocks": _footprints.size(), "foam_footprints": _footprints.size(), "shoreline_rows": _shore_rows.size(), "shoreline_inset_range": [minimum_inset, maximum_inset], "flow_speed": _style.get("flow_speed", 2.8), "trees": forest.total_tree_count, "collision": false, "navigation": false, "enabled": _candidate}

func _read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Dictionary, "Invalid art configuration: " + path)
	return value



func get_debug_snapshot() -> Dictionary:
	return {"enabled": _candidate, "waterline_rocks": _footprints.size(), "foam_footprints": _footprints.size(), "bank_and_rock_meshes": _geometry.size(), "shoreline_rows": _shore_rows.size(), "flow_speed": _style.get("flow_speed", 2.8), "flow_time": _flow_time, "authority_role": "presentation_only"}
