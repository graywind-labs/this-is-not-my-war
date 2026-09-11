extends Node3D
## Ground-only contact masks from existing bases; never edit building geometry.
const CONFIG_PATH := "res://data/presentation/building_ground_contact.json"
var _material: ShaderMaterial
var _image: Image
var _bounds: Rect2
var _settings: Dictionary
var _sources: Array[Dictionary] = []
var _building_count := 0
var _wall_count := 0
var _entry_count := 0
var _enabled := true

func configure(environment: Node3D, layout: Dictionary, material: ShaderMaterial) -> void:
	_settings = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	assert(_settings.get("schema_version", "") == "building_ground_contact_v1")
	_material = material
	set_meta("presentation_only", true)
	var b: Array = _settings.get("bounds", [-70.0, -65.0, 70.0, 70.0])
	_bounds = Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
	var resolution := int(_settings.get("resolution", 1024))
	_image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 1))
	var formal := environment.get_parent()
	var buildings := formal.get_node_or_null("BuildingRoots")
	if buildings == null:
		return
	for building: Dictionary in layout.get("buildings", []):
		var root := buildings.get_node(str(building.node_name)) as Node3D
		_stamp_building(environment, root)
		var route: Dictionary = layout.get("building_spatial", {}).get(building.id, {}).get("entry_route", {})
		if not route.is_empty():
			var a: Array = route.get("door_outside", [0.0, 0.0])
			var end: Array = route.get("exit_outside", a)
			_stamp_segment(_xz(environment.to_local(root.to_global(Vector3(a[0], 0, a[1])))), _xz(environment.to_local(root.to_global(Vector3(end[0], 0, end[1])))), 0.6, 1.25, true)
			_entry_count += 1
	# Outbuildings use the same actual foundation lookup, wherever the layout mounts them.
	for base: MeshInstance3D in formal.find_children("FoundationCore", "MeshInstance3D", true, false):
		_stamp_base(environment, base)
	var station: Dictionary = layout.get("station", {})
	for footing: MeshInstance3D in formal.get_node("WallsAndGates").find_children("LowStoneFooting", "MeshInstance3D", true, false):
		_stamp_base(environment, footing, false)
		_wall_count += 1
	for key in ["front_gate", "back_gate"]:
		var gate: Dictionary = station.get(key, {})
		if gate.is_empty():
			continue
		var center := Vector2(gate.center[0], gate.center[1])
		var angle := deg_to_rad(float(gate.get("rotation_degrees", 0)))
		var across := Vector2.RIGHT.rotated(-angle)
		for side: float in [-1.0, 1.0]:
			var post := center + across * side * (float(gate.clear_width) * 0.5 + 0.6)
			_stamp_segment(post, post, 0.65, 1.4)
	_material.set_shader_parameter("building_contact_map", ImageTexture.create_from_image(_image))
	_material.set_shader_parameter("building_contact_bounds", Vector4(_bounds.position.x, _bounds.position.y, _bounds.size.x, _bounds.size.y))
	set_enabled(bool(_settings.get("enabled", true)))

func _stamp_building(environment: Node3D, root: Node3D) -> void:
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if str(node.name) in _settings.get("base_mesh_names", []):
			_stamp_base(environment, node)
			return
	push_error("Ground contact needs an actual base mesh: " + str(root.name))

func _stamp_base(environment: Node3D, base: MeshInstance3D, building := true) -> void:
	var aabb := base.mesh.get_aabb()
	var points: Array[Vector2] = []
	for corner in [Vector3(aabb.position.x, 0, aabb.position.z), Vector3(aabb.end.x, 0, aabb.position.z), Vector3(aabb.end.x, 0, aabb.end.z), Vector3(aabb.position.x, 0, aabb.end.z)]:
		points.append(_xz(environment.to_local(base.to_global(corner))))
	for i in 4:
		_stamp_segment(points[i], points[(i + 1) % 4], 0.04, float(_settings.get("building_fade_width", 2.5) if building else _settings.get("wall_fade_width", 1.9)))
	_sources.append({"node": base, "mesh": base.mesh, "transform": base.global_transform, "corners": points})
	if building:
		_building_count += 1

func _stamp_segment(a: Vector2, b: Vector2, half_width: float, fade: float, entry := false) -> void:
	var margin := half_width + fade
	var lo := (a.min(b) - Vector2.ONE * margin - _bounds.position) / _bounds.size * _image.get_width()
	var hi := (a.max(b) + Vector2.ONE * margin - _bounds.position) / _bounds.size * _image.get_width()
	for y in range(maxi(0, floori(lo.y)), mini(_image.get_height(), ceili(hi.y) + 1)):
		for x in range(maxi(0, floori(lo.x)), mini(_image.get_width(), ceili(hi.x) + 1)):
			var p := _bounds.position + (Vector2(x, y) + Vector2.ONE * 0.5) / _image.get_width() * _bounds.size
			var d := maxf(0.0, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - half_width)
			if d >= fade:
				continue
			var old := _image.get_pixel(x, y)
			var wear := 1.0 - d / fade
			var contact := 0.0 if entry else 1.0 - smoothstep(0.0, float(_settings.get("contact_width", 0.36)), d)
			_image.set_pixel(x, y, Color(maxf(old.r, wear), maxf(old.g, contact), maxf(old.b, wear if entry else 0.0), 1))

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_material.set_shader_parameter("building_contact_enabled", enabled)

func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

func get_debug_snapshot() -> Dictionary:
	return {"enabled": _enabled, "base_count": _building_count, "wall_segments": _wall_count, "entries": _entry_count, "resolution": _image.get_width(), "new_meshes": 0, "authority_role": "presentation_only"}

func verify_contract() -> Dictionary:
	assert(_building_count == 14 and _wall_count == 14 and _entry_count == 12)
	for source in _sources:
		assert(source.node.mesh == source.mesh and source.node.global_transform == source.transform)
		var corners: Array[Vector2] = source.corners
		for i in 4:
			var middle := (corners[i] + corners[(i + 1) % 4]) * 0.5
			var pixel := (middle - _bounds.position) / _bounds.size * _image.get_width()
			var mask := _image.get_pixel(clampi(int(pixel.x), 0, _image.get_width() - 1), clampi(int(pixel.y), 0, _image.get_height() - 1))
			assert(mask.r > 0.9 and mask.g > 0.65, "Contact mask must follow actual rotated base edges")
	assert(_image.get_pixel(0, 0).r == 0.0 and _image.get_pixel(_image.get_width() - 1, _image.get_height() - 1).r == 0.0)
	assert(find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(find_children("*", "MeshInstance3D", true, false).is_empty())
	return get_debug_snapshot()
