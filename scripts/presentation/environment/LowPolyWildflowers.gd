extends RefCounted
## Small, solid field flowers; the caller fits the clump to the replaced grass.
static func make_mesh(petal_color: Color, grass_bounds: AABB) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color("#52673b").srgb_to_linear()
	var petals := petal_color.srgb_to_linear()
	var pollen := Color("#b58a2d").srgb_to_linear()
	for head: Vector3 in [Vector3(-0.10, 0.32, 0.04), Vector3(0.08, 0.46, 0.0), Vector3(0.10, 0.27, -0.13)]:
		for side in 5:
			var a := float(side) * TAU / 5.0
			var b := float(side + 1) * TAU / 5.0
			var root_a := Vector3(head.x + cos(a)*0.012, 0, head.z + sin(a)*0.012)
			var root_b := Vector3(head.x + cos(b)*0.012, 0, head.z + sin(b)*0.012)
			_triangle(st, root_a, root_b, root_a + Vector3.UP*head.y, green)
			_triangle(st, root_b, root_b + Vector3.UP*head.y, root_a + Vector3.UP*head.y, green)
		for side: float in [-1.0, 1.0]:
			var stem := Vector3(head.x, head.y*0.40, head.z)
			var tip := stem + Vector3(side*0.10, 0.07, 0.04)
			_triangle(st, stem, stem+Vector3(side*0.04,0.035,-0.025), tip, green)
			_triangle(st, stem, tip, stem+Vector3(side*0.04,0.025,0.05), green)
		for petal in 6:
			var angle := float(petal)*TAU/6.0
			var forward := Vector3(cos(angle), 0, sin(angle))
			var across := Vector3(-sin(angle), 0, cos(angle))
			var start := head + forward*0.023
			var tip := head + forward*0.115 + Vector3.UP*0.012
			var left := head + forward*0.07 + across*0.036
			var right := head + forward*0.07 - across*0.036
			_triangle(st, start, left, tip, petals)
			_triangle(st, start, tip, right, petals)
			var next := Vector3(cos(angle+TAU/6.0),0,sin(angle+TAU/6.0))
			_triangle(st, head+Vector3.UP*0.014, head+forward*0.031, head+next*0.031, pollen)
	var source := st.commit()
	var box := source.get_aabb()
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = (vertices[i]-box.position) / box.size * grass_bounds.size + grass_bounds.position
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in normals.size():
		normals[i] = (normals[i] / (grass_bounds.size / box.size)).normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	return mesh

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.y < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	st.set_color(color)
	for v in [a,b,c]:
		st.set_normal(normal)
		st.add_vertex(v)
