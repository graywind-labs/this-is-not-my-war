extends SceneTree


const SOURCE_PATH := "res://assets/3d/synty/t0130_pilot/SK_Knights_Dark_01.fbx"
const OUTPUT_DIR := "res://artifacts/visual_qa"


func _initialize() -> void:
	root.size = Vector2i(900, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111815")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	world_environment.environment = environment
	root.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	light.light_energy = 1.8
	light.shadow_enabled = true
	root.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.55
	camera.look_at_from_position(Vector3(0.0, 1.0, 4.0), Vector3(0.0, 0.95, 0.0))
	root.add_child(camera)
	var packed := load(SOURCE_PATH) as PackedScene
	for component_index in 5:
		var knight := packed.instantiate() as Node3D
		root.add_child(knight)
		var mesh_instance := knight.find_child("SK_Knights_Dark_01", true, false) as MeshInstance3D
		mesh_instance.mesh = _extract_component(mesh_instance.mesh as ArrayMesh, component_index)
		for _frame in 5:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(
			"%s/knight_component_%02d.png" % [OUTPUT_DIR, component_index]
		))
		knight.free()
	quit(0)


func _extract_component(source_mesh: ArrayMesh, selected_component: int) -> ArrayMesh:
	var arrays := source_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
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
		var component_root := _find(parent, indices[triangle_start])
		var component_indices: PackedInt32Array = components.get(component_root, PackedInt32Array())
		component_indices.append_array(indices.slice(triangle_start, triangle_start + 3))
		components[component_root] = component_indices
	var sorted: Array = components.values()
	sorted.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool: return a.size() > b.size())
	arrays[Mesh.ARRAY_INDEX] = sorted[selected_component]
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, source_mesh.surface_get_material(0))
	return result


func _find(parent: Array[int], value: int) -> int:
	if parent[value] != value:
		parent[value] = _find(parent, parent[value])
	return parent[value]


func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a
