extends RefCounted


static func build_wash_basin(node_name: String, center: Vector3, yaw_degrees: float, palette: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	root.rotation_degrees.y = yaw_degrees
	root.set_meta("authority_role", "non_workstation_decoration")
	root.set_meta("prop_type", "medieval_wall_wash_basin")
	root.set_meta("has_water_surface", true)
	root.set_meta("uses_modern_plumbing", false)

	var timber: Color = palette.get("timber", Color("#594231"))
	var dark_timber: Color = palette.get("dark_timber", timber.darkened(0.18))
	var stone: Color = palette.get("stone", Color("#817b70"))
	var basin: Color = palette.get("basin", Color("#a9a69a"))
	var metal: Color = palette.get("metal", Color("#8a6037"))
	var water: Color = palette.get("water", Color("#5e8990"))
	var linen: Color = palette.get("linen", Color("#c9c0aa"))

	_add_box(root, "StoneFooting", Vector3(0.0, 0.12, 0.0), Vector3(1.42, 0.24, 0.62), stone.darkened(0.12))
	for x in [-0.52, 0.52]:
		for z in [-0.20, 0.20]:
			_add_cylinder(root, "OakLeg", Vector3(x, 0.55, z), 0.09, 0.86, timber)
	_add_box(root, "LowerStorageShelf", Vector3(0.0, 0.34, 0.0), Vector3(1.15, 0.11, 0.52), dark_timber)
	_add_box(root, "FrontCrossBrace", Vector3(0.0, 0.58, 0.25), Vector3(1.12, 0.1, 0.1), dark_timber)
	_add_box(root, "BasinSupportSlab", Vector3(0.0, 0.94, 0.0), Vector3(1.46, 0.15, 0.72), stone)

	_add_elliptical_bowl(root, "HammeredBasinBowl", Vector3(0.0, 1.10, 0.02), Vector2(0.62, 0.44), Vector2(0.46, 0.30), 0.24, basin.darkened(0.05))
	var rim := _add_torus(root, "RaisedBasinRim", Vector3(0.0, 1.11, 0.02), 0.43, 0.62, basin.lightened(0.08))
	rim.scale.z = 0.72
	var water_surface := _add_cylinder(root, "CleanWaterSurface", Vector3(0.0, 0.98, 0.02), 0.36, 0.025, water)
	water_surface.scale.z = 0.72

	_add_box(root, "OakBackBoard", Vector3(0.0, 1.45, -0.30), Vector3(1.42, 1.05, 0.12), timber)
	_add_box(root, "BackBoardTopRail", Vector3(0.0, 2.0, -0.29), Vector3(1.42, 0.13, 0.16), dark_timber)
	_add_box(root, "CopperWaterCistern", Vector3(-0.30, 1.78, -0.18), Vector3(0.58, 0.40, 0.28), metal.darkened(0.08))
	_add_box(root, "CisternLid", Vector3(-0.30, 2.02, -0.18), Vector3(0.70, 0.09, 0.34), metal)
	_add_cylinder(root, "CopperSpout", Vector3(-0.30, 1.49, 0.04), 0.045, 0.42, metal.lightened(0.08), Vector3(90.0, 0.0, 0.0))
	_add_cylinder(root, "DownturnedNozzle", Vector3(-0.30, 1.31, 0.24), 0.052, 0.27, metal.lightened(0.04))
	_add_cylinder(root, "WoodenTapHandle", Vector3(-0.30, 1.58, 0.27), 0.07, 0.34, dark_timber, Vector3(0.0, 0.0, 90.0))

	_add_cylinder(root, "TowelRail", Vector3(0.39, 1.66, -0.19), 0.035, 0.46, metal, Vector3(0.0, 0.0, 90.0))
	_add_box(root, "HangingLinen", Vector3(0.39, 1.40, -0.13), Vector3(0.42, 0.48, 0.055), linen)
	_add_box(root, "FoldedSoapCloth", Vector3(0.42, 1.03, 0.22), Vector3(0.28, 0.055, 0.18), linen.darkened(0.08))
	return root


static func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


static func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation_degrees = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


static func _add_elliptical_bowl(parent: Node3D, node_name: String, center: Vector3, outer_radius: Vector2, inner_radius: Vector2, depth: float, color: Color) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(_material(color, true))
	var segments := 20
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var outer_top_a := Vector3(cos(angle_a) * outer_radius.x, 0.0, sin(angle_a) * outer_radius.y)
		var outer_top_b := Vector3(cos(angle_b) * outer_radius.x, 0.0, sin(angle_b) * outer_radius.y)
		var inner_top_a := Vector3(cos(angle_a) * inner_radius.x, 0.015, sin(angle_a) * inner_radius.y)
		var inner_top_b := Vector3(cos(angle_b) * inner_radius.x, 0.015, sin(angle_b) * inner_radius.y)
		var outer_low_a := Vector3(cos(angle_a) * outer_radius.x * 0.48, -depth, sin(angle_a) * outer_radius.y * 0.48)
		var outer_low_b := Vector3(cos(angle_b) * outer_radius.x * 0.48, -depth, sin(angle_b) * outer_radius.y * 0.48)
		var inner_low_a := Vector3(cos(angle_a) * inner_radius.x * 0.52, -depth + 0.05, sin(angle_a) * inner_radius.y * 0.52)
		var inner_low_b := Vector3(cos(angle_b) * inner_radius.x * 0.52, -depth + 0.05, sin(angle_b) * inner_radius.y * 0.52)
		_add_quad(surface_tool, outer_top_a, outer_top_b, outer_low_b, outer_low_a)
		_add_quad(surface_tool, inner_top_b, inner_top_a, inner_low_a, inner_low_b)
		_add_quad(surface_tool, outer_top_a, inner_top_a, inner_top_b, outer_top_b)
		_add_quad(surface_tool, outer_low_b, inner_low_b, inner_low_a, outer_low_a)
	surface_tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = surface_tool.commit()
	parent.add_child(instance)
	return instance


static func _add_quad(surface_tool: SurfaceTool, first: Vector3, second: Vector3, third: Vector3, fourth: Vector3) -> void:
	for vertex in [first, second, third, first, third, fourth]:
		surface_tool.add_vertex(vertex)


static func _add_torus(parent: Node3D, node_name: String, center: Vector3, inner_radius: float, outer_radius: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


static func _material(color: Color, double_sided := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
