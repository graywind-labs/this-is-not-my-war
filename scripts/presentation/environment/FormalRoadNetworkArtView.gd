extends Node3D

const ART_REVISION := "t0132_p5"
const ROAD_SURFACE_Y := 0.061
const CORE_SURFACE_Y := 0.068
const RUT_SURFACE_Y := 0.074
const MAX_SECTION_LENGTH := 7.5

var _road_configs: Array = []
var _materials: Dictionary = {}
var _road_roots: Dictionary = {}
var _ribbon_count := 0
var _rut_strip_count := 0
var _embedded_stone_count := 0
var _junction_patch_count := 0
var _total_triangle_count := 0


func configure(roads: Array) -> void:
	_road_configs = roads.duplicate(true)
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_rebuild()


func get_debug_snapshot() -> Dictionary:
	var kind_counts := {"main": 0, "service": 0, "enemy": 0, "trade": 0}
	var widths: Dictionary = {}
	var endpoints: Dictionary = {}
	for raw_road in _road_configs:
		var road: Dictionary = raw_road
		var road_id := str(road.get("id", ""))
		var kind := str(road.get("kind", "service"))
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		widths[road_id] = float(road.get("width", 0.0))
		endpoints[road_id] = {
			"from": road.get("from", []).duplicate(),
			"to": road.get("to", []).duplicate()
		}
	return {
		"art_revision": ART_REVISION,
		"road_count": _road_configs.size(),
		"road_root_count": _road_roots.size(),
		"kind_counts": kind_counts,
		"widths": widths,
		"endpoints": endpoints,
		"ribbon_count": _ribbon_count,
		"rut_strip_count": _rut_strip_count,
		"embedded_stone_count": _embedded_stone_count,
		"junction_patch_count": _junction_patch_count,
		"triangle_count": _total_triangle_count,
		"surface_y": ROAD_SURFACE_Y,
		"has_irregular_edges": true,
		"has_compacted_core": true,
		"has_cart_ruts": true,
		"has_collision": find_children("*", "CollisionShape3D", true, false).size() > 0,
		"roads_affect_navigation": false,
		"authority_role": "presentation_only"
	}


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_materials.clear()
	_road_roots.clear()
	_ribbon_count = 0
	_rut_strip_count = 0
	_embedded_stone_count = 0
	_junction_patch_count = 0
	_total_triangle_count = 0
	_build_materials()
	for raw_road in _road_configs:
		if raw_road is Dictionary:
			_build_road(raw_road as Dictionary)
	_build_junction_patches()
	set_meta("art_revision", ART_REVISION)
	set_meta("roads_affect_navigation", false)
	set_meta("presentation_only", true)


func _build_materials() -> void:
	_materials["main_shoulder"] = _make_earth_material(Color("#66513e"), 101, 0.085)
	_materials["main_core"] = _make_earth_material(Color("#705a43"), 111, 0.095)
	_materials["service_shoulder"] = _make_earth_material(Color("#5d5042"), 201, 0.075)
	_materials["service_core"] = _make_earth_material(Color("#675746"), 211, 0.085)
	_materials["enemy_shoulder"] = _make_earth_material(Color("#57443b"), 301, 0.090)
	_materials["enemy_core"] = _make_earth_material(Color("#624b3f"), 311, 0.105)
	_materials["trade_shoulder"] = _make_earth_material(Color("#5e4f3d"), 401, 0.080)
	_materials["trade_core"] = _make_earth_material(Color("#695843"), 411, 0.095)
	var rut := StandardMaterial3D.new()
	rut.albedo_color = Color("#463a32")
	rut.roughness = 1.0
	_materials["rut"] = rut
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#5a584f")
	stone.roughness = 1.0
	_materials["stone"] = stone


func _build_road(road: Dictionary) -> void:
	var road_id := str(road.get("id", "road"))
	var from_point := _v2(road.get("from", [0.0, 0.0]))
	var to_point := _v2(road.get("to", [0.0, 0.0]))
	var width := maxf(1.0, float(road.get("width", 3.0)))
	var kind := str(road.get("kind", "service"))
	if not _materials.has("%s_shoulder" % kind):
		kind = "service"
	var length := from_point.distance_to(to_point)
	if length < 0.05:
		return
	var section_count := maxi(2, int(ceil(length / MAX_SECTION_LENGTH)))
	var seed_value := _stable_hash(road_id)
	var center_points := _make_centerline(from_point, to_point, width, section_count, seed_value)
	var road_root := Node3D.new()
	road_root.name = road_id.to_pascal_case()
	road_root.set_meta("road_id", road_id)
	road_root.set_meta("road_kind", kind)
	road_root.set_meta("configured_width", width)
	road_root.set_meta("configured_from", from_point)
	road_root.set_meta("configured_to", to_point)
	road_root.set_meta("collision_free_decal", true)
	add_child(road_root)
	_road_roots[road_id] = road_root

	_build_ribbon(road_root, "FeatheredShoulder", center_points, width, ROAD_SURFACE_Y, _materials["%s_shoulder" % kind], seed_value, 0.075)
	_build_ribbon(road_root, "CompactedCore", center_points, width * _core_width_ratio(kind), CORE_SURFACE_Y, _materials["%s_core" % kind], seed_value + 37, 0.038)
	_build_cart_ruts(road_root, center_points, width, kind, seed_value)
	_build_embedded_stones(road_root, center_points, width, length, kind, seed_value)


func _make_centerline(from_point: Vector2, to_point: Vector2, width: float, section_count: int, seed_value: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var direction := (to_point - from_point).normalized()
	var normal := Vector2(-direction.y, direction.x)
	for index in range(section_count + 1):
		var t := float(index) / float(section_count)
		var point := from_point.lerp(to_point, t)
		if index > 0 and index < section_count:
			var envelope := sin(PI * t)
			var offset := _signed_noise(seed_value, index, 13) * minf(width * 0.055, 0.30) * envelope
			point += normal * offset
		points.append(point)
	return points


func _build_ribbon(parent: Node3D, node_name: String, points: Array[Vector2], width: float, height: float, material: Material, seed_value: int, edge_variation: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var accumulated := 0.0
	for index in points.size():
		if index > 0:
			accumulated += points[index - 1].distance_to(points[index])
		var tangent: Vector2
		if index == 0:
			tangent = (points[1] - points[0]).normalized()
		elif index == points.size() - 1:
			tangent = (points[index] - points[index - 1]).normalized()
		else:
			tangent = (points[index + 1] - points[index - 1]).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var endpoint_factor := 0.0 if index == 0 or index == points.size() - 1 else 1.0
		var left_width := width * 0.5 * (1.0 + _signed_noise(seed_value, index, 29) * edge_variation * endpoint_factor)
		var right_width := width * 0.5 * (1.0 + _signed_noise(seed_value, index, 47) * edge_variation * endpoint_factor)
		var left := points[index] + side * left_width
		var right := points[index] - side * right_width
		vertices.append(Vector3(left.x, height, left.y))
		vertices.append(Vector3(right.x, height, right.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, accumulated * 0.18))
		uvs.append(Vector2(1.0, accumulated * 0.18))
	if points.size() >= 2:
		for index in range(points.size() - 1):
			var base := index * 2
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("road_surface", true)
	parent.add_child(instance)
	_ribbon_count += 1
	_total_triangle_count += indices.size() / 3


func _build_cart_ruts(parent: Node3D, points: Array[Vector2], width: float, kind: String, seed_value: int) -> void:
	var separation := minf(width * 0.23, 0.92)
	var rut_width := 0.16 if kind == "service" else 0.21
	for side_sign in [-1.0, 1.0]:
		for index in range(points.size() - 1):
			# Broken strips feel worn into the earth instead of painted on top.
			if ((_stable_hash(str(seed_value + index * 17)) + index) % 4) == 0:
				continue
			var start := points[index]
			var finish := points[index + 1]
			var tangent := (finish - start).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var inset := minf(0.30, start.distance_to(finish) * 0.08)
			start += tangent * inset + normal * separation * side_sign
			finish -= tangent * inset
			finish += normal * separation * side_sign
			_build_flat_quad(parent, "CartRut", start, finish, rut_width, RUT_SURFACE_Y, _materials["rut"])
			_rut_strip_count += 1


func _build_embedded_stones(parent: Node3D, points: Array[Vector2], width: float, length: float, kind: String, seed_value: int) -> void:
	var count := clampi(int(round(length / 17.0)), 1, 6)
	if kind == "enemy":
		count = maxi(1, count - 1)
	for index in count:
		var t := (float(index) + 0.55 + _signed_noise(seed_value, index, 71) * 0.18) / float(count)
		var sample := _sample_polyline(points, clampf(t, 0.06, 0.94))
		var tangent: Vector2 = sample.get("tangent", Vector2.DOWN)
		var normal := Vector2(-tangent.y, tangent.x)
		var side_sign := -1.0 if ((seed_value + index) % 2) == 0 else 1.0
		var center: Vector2 = sample.get("position", Vector2.ZERO) + normal * width * (0.40 + 0.06 * _unit_noise(seed_value, index, 83)) * side_sign
		var stone := MeshInstance3D.new()
		stone.name = "EmbeddedRoadStone"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.16 + 0.07 * _unit_noise(seed_value, index, 89)
		mesh.bottom_radius = mesh.top_radius * 1.12
		mesh.height = 0.055
		mesh.radial_segments = 6
		stone.mesh = mesh
		stone.position = Vector3(center.x, 0.073, center.y)
		stone.rotation_degrees.y = float((seed_value + index * 47) % 180)
		stone.scale = Vector3(1.25, 1.0, 0.72 + 0.22 * _unit_noise(seed_value, index, 97))
		stone.set_surface_override_material(0, _materials["stone"])
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stone.set_meta("embedded_road_detail", true)
		parent.add_child(stone)
		_embedded_stone_count += 1


func _build_junction_patches() -> void:
	var endpoints: Dictionary = {}
	for raw_road in _road_configs:
		var road: Dictionary = raw_road
		var kind := str(road.get("kind", "service"))
		for endpoint_key in ["from", "to"]:
			var point := _v2(road.get(endpoint_key, [0.0, 0.0]))
			var key := "%.3f,%.3f" % [point.x, point.y]
			var entry: Dictionary = endpoints.get(key, {
				"position": point,
				"count": 0,
				"width": 0.0,
				"kind": kind,
				"has_main": false
			})
			entry["count"] = int(entry.get("count", 0)) + 1
			entry["width"] = maxf(float(entry.get("width", 0.0)), float(road.get("width", 3.0)))
			entry["has_main"] = bool(entry.get("has_main", false)) or kind == "main"
			if bool(entry.get("has_main", false)):
				entry["kind"] = "main"
			endpoints[key] = entry
	for raw_entry in endpoints.values():
		var entry: Dictionary = raw_entry
		if int(entry.get("count", 0)) < 2:
			continue
		var point: Vector2 = entry.get("position", Vector2.ZERO)
		var width := float(entry.get("width", 3.0))
		var kind := str(entry.get("kind", "service"))
		_build_junction_disc("JunctionShoulder", point, width * 0.54, 0.055, _materials["%s_shoulder" % kind])
		_build_junction_disc("JunctionCore", point, width * 0.42, 0.066, _materials["%s_core" % kind])
		_junction_patch_count += 1


func _build_junction_disc(node_name: String, center: Vector2, radius: float, height: float, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.03
	mesh.height = 0.012
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.position = Vector3(center.x, height, center.y)
	instance.set_surface_override_material(0, material)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("road_junction_decal", true)
	add_child(instance)


func _build_flat_quad(parent: Node3D, node_name: String, from_point: Vector2, to_point: Vector2, width: float, height: float, material: Material) -> void:
	var delta := to_point - from_point
	if delta.length_squared() < 0.001:
		return
	var normal := Vector2(-delta.y, delta.x).normalized() * width * 0.5
	var vertices := PackedVector3Array([
		Vector3((from_point + normal).x, height, (from_point + normal).y),
		Vector3((to_point + normal).x, height, (to_point + normal).y),
		Vector3((from_point - normal).x, height, (from_point - normal).y),
		Vector3((to_point - normal).x, height, (to_point - normal).y)
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2.ONE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 2, 3, 1])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	_total_triangle_count += 2


func _sample_polyline(points: Array[Vector2], t: float) -> Dictionary:
	var distances: Array[float] = []
	var total := 0.0
	for index in range(points.size() - 1):
		var distance := points[index].distance_to(points[index + 1])
		distances.append(distance)
		total += distance
	var target := total * t
	var walked := 0.0
	for index in distances.size():
		var distance := distances[index]
		if target <= walked + distance or index == distances.size() - 1:
			var local_t := clampf((target - walked) / maxf(distance, 0.001), 0.0, 1.0)
			return {
				"position": points[index].lerp(points[index + 1], local_t),
				"tangent": (points[index + 1] - points[index]).normalized()
			}
		walked += distance
	return {"position": points.back(), "tangent": Vector2.DOWN}


func _core_width_ratio(kind: String) -> float:
	match kind:
		"enemy":
			return 0.80
		"trade":
			return 0.82
		"main":
			return 0.84
		_:
			return 0.78


func _make_earth_material(base_color: Color, seed_value: int, contrast: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.075
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.48
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([base_color.darkened(contrast), base_color.lightened(contrast * 0.55)])
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.normalize = true
	texture.noise = noise
	texture.color_ramp = gradient
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.98
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


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


func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		return Vector2(value.x, value.z)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
