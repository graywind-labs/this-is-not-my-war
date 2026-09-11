extends SceneTree


const ASSET_PATH := "res://assets/3d/synty/t0130_pilot/SK_Knights_Dark_01.fbx"


func _initialize() -> void:
	var packed := load(ASSET_PATH) as PackedScene
	var root_node := packed.instantiate() if packed != null else null
	if root_node == null:
		push_error("Could not load knight source")
		quit(1)
		return
	var skeleton := root_node.find_child("Skeleton3D", true, false) as Skeleton3D
	var mesh_instance := root_node.find_child("SK_Knights_Dark_01", true, false) as MeshInstance3D
	if skeleton == null or mesh_instance == null or not mesh_instance.mesh is ArrayMesh:
		push_error("Knight skeleton or mesh is missing")
		quit(1)
		return
	var arrays := (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var parent: Array[int] = []
	parent.resize(vertices.size())
	for vertex_index in vertices.size():
		parent[vertex_index] = vertex_index
	for triangle_start in range(0, indices.size(), 3):
		_union(parent, indices[triangle_start], indices[triangle_start + 1])
		_union(parent, indices[triangle_start], indices[triangle_start + 2])
	var coincident := {}
	for vertex_index in vertices.size():
		var v := vertices[vertex_index]
		var key := Vector3i(roundi(v.x * 10000.0), roundi(v.y * 10000.0), roundi(v.z * 10000.0))
		if coincident.has(key):
			_union(parent, vertex_index, int(coincident[key]))
		else:
			coincident[key] = vertex_index
	var components := {}
	for triangle_start in range(0, indices.size(), 3):
		var root_index := _find(parent, indices[triangle_start])
		var entry: Dictionary = components.get(root_index, {"indices": {}, "triangles": 0})
		entry["triangles"] = int(entry["triangles"]) + 1
		for corner in 3:
			entry["indices"][indices[triangle_start + corner]] = true
		components[root_index] = entry
	var sorted: Array = components.values()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["triangles"]) > int(b["triangles"]))
	print("vertices=%d triangles=%d components=%d bones_per_vertex=%d" % [vertices.size(), indices.size() / 3, sorted.size(), bones.size() / maxi(vertices.size(), 1)])
	for component_index in sorted.size():
		var entry: Dictionary = sorted[component_index]
		var unique_indices: Array = entry["indices"].keys()
		var min_v := Vector3(INF, INF, INF)
		var max_v := Vector3(-INF, -INF, -INF)
		var bone_totals := {}
		for raw_vertex_index in unique_indices:
			var vertex_index := int(raw_vertex_index)
			min_v = min_v.min(vertices[vertex_index])
			max_v = max_v.max(vertices[vertex_index])
			for influence in 4:
				var packed_index := vertex_index * 4 + influence
				if packed_index >= bones.size() or packed_index >= weights.size() or weights[packed_index] <= 0.0001:
					continue
				var bone_index := bones[packed_index]
				var bone_name := str(skeleton.get_bone_name(bone_index)) if bone_index >= 0 and bone_index < skeleton.get_bone_count() else "bone_%d" % bone_index
				bone_totals[bone_name] = float(bone_totals.get(bone_name, 0.0)) + weights[packed_index]
		var ranked_bones: Array = bone_totals.keys()
		ranked_bones.sort_custom(func(a: Variant, b: Variant) -> bool: return float(bone_totals[a]) > float(bone_totals[b]))
		var top_bones: Array[String] = []
		for bone_rank in mini(6, ranked_bones.size()):
			var bone_name := str(ranked_bones[bone_rank])
			top_bones.append("%s:%.1f" % [bone_name, float(bone_totals[bone_name])])
		print("component=%02d triangles=%4d vertices=%4d min=%s max=%s size=%s bones=%s" % [
			component_index,
			int(entry["triangles"]),
			unique_indices.size(),
			str(min_v),
			str(max_v),
			str(max_v - min_v),
			", ".join(top_bones),
		])
	root_node.free()
	quit(0)


func _find(parent: Array[int], value: int) -> int:
	var root_index := value
	while parent[root_index] != root_index:
		root_index = parent[root_index]
	while parent[value] != value:
		var next := parent[value]
		parent[value] = root_index
		value = next
	return root_index


func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a
