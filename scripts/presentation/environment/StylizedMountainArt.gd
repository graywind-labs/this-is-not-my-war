extends Node3D
## Approved high-cliff presentation shared by production and the independent review.
const ROCK_SHADER := preload("res://shaders/environment/mountain_art_trial.gdshader")
const CONFIG_PATH := "res://data/presentation/mountain_art_trial.json"
var _style: Dictionary = {}
var _environment: Node3D
var _mountain: Node3D
var _original: Dictionary = {}
var _geometry: Dictionary = {}
var _material := ShaderMaterial.new()
var _outcrops := Node3D.new()
var _cliffs := Node3D.new()
var _lifted_instances: Array[Dictionary] = []
var _peak_heights: Dictionary = {}
var _surfaces: Array[MeshInstance3D] = []
var _rock_bases: Array[Vector3] = []
var _candidate := true

func configure(environment: Node3D, settings: Dictionary) -> void:
	_environment = environment
	_style = settings.duplicate(true)
	assert(_style.get("schema_version", "") == "mountain_art_trial_v1")
	set_meta("presentation_only", true)
	_mountain = _environment.get_node("FullMapTerrainTopology/EastThreeLayerMountain")
	_material.shader = ROCK_SHADER
	_material.set_shader_parameter("environment_origin", _environment.global_position)
	var ground_style := _read("res://data/presentation/ground_art_trial.json")
	for key in ["grass_dark", "grass_light", "soil_dark", "soil_light"]:
		_material.set_shader_parameter(key, Color(str(ground_style.get(key, "#38452c"))))
	for key in ["rock_dark", "rock_light", "earth", "moss"]:
		_material.set_shader_parameter(key, Color(str(_style.get(key, "#66685a"))))
	for key in ["strata_spacing", "strata_strength", "foot_height"]:
		_material.set_shader_parameter(key, float(_style.get(key, 1.0)))
	for node: MeshInstance3D in _mountain.find_children("*", "MeshInstance3D", true, false):
		_original[node] = node.material_override
		_geometry[node] = {"mesh": node.mesh, "transform": node.transform, "vertices": hash(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])}
		if node.has_meta("mountain_layer"):
			_surfaces.append(node)
	_build_cliffs()
	_lift_mountain_scatter()
	_outcrops.name = "CandidateOutcrops"
	_outcrops.set_meta("presentation_only", true)
	add_child(_outcrops)
	_build_outcrops()
	set_enabled(true)

func set_enabled(enabled: bool) -> void:
	_candidate = enabled
	_outcrops.visible = enabled
	_mountain.visible = not enabled
	_cliffs.visible = enabled
	for entry in _lifted_instances:
		entry.node.multimesh.set_instance_transform(entry.index, entry.candidate if enabled else entry.original)

func _read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Dictionary, "Invalid art configuration: " + path)
	return value


func _build_cliffs() -> void:
	_cliffs.name = "CandidateCliffMountain"
	_cliffs.set_meta("presentation_only", true)
	add_child(_cliffs)
	var candidate_surfaces: Array[MeshInstance3D] = []
	for source in _surfaces:
		var layer := str(source.get_meta("mountain_layer"))
		var gain := float(_style.get("mountain_height_multipliers", {}).get(layer, 3.0))
		var x_range: Vector2 = source.get_meta("x_range")
		var vertices: PackedVector3Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var peak := 0.0
		for i in vertices.size():
			var v := vertices[i]
			var t := clampf((v.x - x_range.x) / (x_range.y - x_range.x), 0.0, 1.0)
			# Keep the foot; compress the climb into a steep middle face and a high shelf.
			var wall := smoothstep(0.18, 0.38, t)
			var amplification := lerpf(0.44, 1.73, wall)
			amplification = lerpf(amplification, 1.0, smoothstep(0.39, 0.94, t))
			v.y = 0.02 + (v.y - 0.02) * gain * amplification
			vertices[i] = v
			peak = maxf(peak, v.y)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0, vertices.size(), 3):
			_face(surface, vertices[i], vertices[i + 1], vertices[i + 2])
		var instance := MeshInstance3D.new()
		instance.name = layer.capitalize() + "CliffLayer"
		instance.mesh = surface.commit()
		instance.material_override = _material
		_cliffs.add_child(instance)
		candidate_surfaces.append(instance)
		_peak_heights[layer] = snappedf(peak, 0.1)
	_surfaces = candidate_surfaces
	# Reuse the existing rock assets, seated on the candidate surface in this preview only.
	for source: MeshInstance3D in _original:
		if source.has_meta("mountain_layer"):
			continue
		var local_position := _environment.to_local(source.global_position)
		var position_on_map := Vector2(local_position.x, local_position.z)
		var height := _height_at(position_on_map)
		if not is_finite(height):
			continue
		var rock := MeshInstance3D.new()
		rock.mesh = source.mesh
		rock.material_override = _material
		rock.transform = _environment.global_transform.affine_inverse() * source.global_transform
		rock.position.y = height - source.mesh.get_aabb().position.y * source.global_basis.get_scale().y - 0.3
		_cliffs.add_child(rock)


func _lift_mountain_scatter() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for node: MultiMeshInstance3D in _environment.find_children("*", "MultiMeshInstance3D", true, false):
		for index in node.multimesh.instance_count:
			var original := node.multimesh.get_instance_transform(index)
			var world_point := _environment.to_local(node.to_global(original.origin))
			if world_point.x < 120.0:
				continue
			var height := _height_at(Vector2(world_point.x, world_point.z))
			if not is_finite(height):
				continue
			var candidate := original
			world_point.y = height
			candidate.origin = node.to_local(_environment.to_global(world_point))
			_lifted_instances.append({"node": node, "index": index, "original": original, "candidate": candidate})


func _height_at(point: Vector2) -> float:
	var height := -INF
	for node in _surfaces:
		var arrays := node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(0, vertices.size(), 3):
			var a := vertices[i]
			var b := vertices[i + 1]
			var c := vertices[i + 2]
			var v0 := Vector2(b.x - a.x, b.z - a.z)
			var v1 := Vector2(c.x - a.x, c.z - a.z)
			var v2 := point - Vector2(a.x, a.z)
			var denominator := v0.cross(v1)
			if absf(denominator) < 0.00001:
				continue
			var u := v2.cross(v1) / denominator
			var v := v0.cross(v2) / denominator
			if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
				height = maxf(height, a.y + (b.y - a.y) * u + (c.y - a.y) * v)
	return height


func _build_outcrops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_style.get("seed", 365))
	for center_values: Array in _style.get("outcrop_centers", []):
		var center := Vector2(center_values[0], center_values[1])
		var widths: Array = _style.get("outcrop_width", [3.8, 6.2])
		var heights: Array = _style.get("outcrop_height", [4.5, 7.5])
		var group_rise := rng.randf_range(heights[0], heights[1])
		for piece in 3:
			var point := center + Vector2(-piece * 3.8, rng.randf_range(-2.5, 2.5))
			var width := rng.randf_range(widths[0], widths[1]) * (1.0 - piece * 0.18)
			var rise: float = group_rise * [1.0, 0.54, 0.24][piece]
			var base: Array[Vector3] = []
			var top: Array[Vector3] = []
			for corner in 7:
				var angle := float(corner) * TAU / 7.0
				var p := point + Vector2(cos(angle) * width, sin(angle) * width * 0.7)
				var h := _height_at(p)
				assert(is_finite(h), "Outcrop escaped the existing mountain surface")
				base.append(Vector3(p.x, h - 0.12, p.y))
				_rock_bases.append(Vector3(p.x, h - 0.12, p.y))
				var inset := point.lerp(p, rng.randf_range(0.68, 0.86))
				top.append(Vector3(inset.x, _height_at(inset) + rise * rng.randf_range(0.88, 1.0), inset.y))
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var crown := Vector3(point.x, _height_at(point) + rise * 1.02, point.y)
			for corner in 7:
				var next := (corner + 1) % 7
				_face(surface, crown, top[corner], top[next])
				_face(surface, top[corner], base[corner], base[next])
				_face(surface, top[corner], base[next], top[next])
			var instance := MeshInstance3D.new()
			instance.name = "EmbeddedSlab%02d" % _outcrops.get_child_count()
			instance.mesh = surface.commit()
			instance.material_override = _material
			_outcrops.add_child(instance)


func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)


func verify_geometry_contract() -> Dictionary:
	var vertices := 0
	for node: MeshInstance3D in _geometry:
		assert(node.mesh == _geometry[node].mesh and node.transform == _geometry[node].transform)
		assert(hash(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]) == _geometry[node].vertices)
	for node in _surfaces:
		vertices += node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	for base in _rock_bases:
		assert(absf(base.y - (_height_at(Vector2(base.x, base.z)) - 0.12)) < 0.00001)
	for entry in _lifted_instances:
		assert(entry.original.basis == entry.candidate.basis)
		assert(is_equal_approx(entry.original.origin.x, entry.candidate.origin.x))
		assert(is_equal_approx(entry.original.origin.z, entry.candidate.origin.z))
		var expected: Transform3D = entry.candidate if _candidate else entry.original
		assert(entry.node.multimesh.get_instance_transform(entry.index).is_equal_approx(expected))
	assert(find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(find_children("*", "NavigationRegion3D", true, false).is_empty())
	var forest: Dictionary = _environment.get_node("FullMapDenseForest").get_debug_snapshot()
	assert(forest.total_tree_count == 7393 and forest.approved_forest.enabled)
	assert(_peak_heights.near > 30.0 and _peak_heights.mid > 60.0 and _peak_heights.far > 100.0)
	return get_debug_snapshot()

func get_debug_snapshot() -> Dictionary:
	var vertices := 0
	for node in _surfaces:
		vertices += node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	var forest: Dictionary = _environment.get_node("FullMapDenseForest").get_debug_snapshot()
	return {"original_meshes_unchanged": _geometry.size(), "candidate_mountain_vertices": vertices, "peak_heights": _peak_heights, "lifted_instances": _lifted_instances.size(), "outcrop_groups": _style.get("outcrop_centers", []).size(), "outcrop_pieces": _outcrops.get_child_count(), "embedded_base_vertices": _rock_bases.size(), "trees": forest.total_tree_count, "collision": false, "navigation": false, "enabled": _candidate}
