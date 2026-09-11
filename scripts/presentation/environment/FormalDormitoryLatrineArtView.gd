extends Node3D


const WALL_COLOR := Color("#aa9a78")
const WALL_SHADOW_COLOR := Color("#8f8168")
const TIMBER_COLOR := Color("#4b3428")
const TIMBER_EDGE_COLOR := Color("#35251f")
const STONE_COLOR := Color("#6f7069")
const STONE_LIGHT_COLOR := Color("#85857b")
const DOOR_COLOR := Color("#5b3d2d")
const ROOF_COLOR := Color("#694348")
const ROOF_EDGE_COLOR := Color("#493038")
const IRON_COLOR := Color("#31363a")
const VENT_DARK_COLOR := Color("#241f1d")

var _configured := false


func configure(config: Dictionary) -> void:
	if _configured:
		return
	_configured = true
	set_meta("layout_id", str(config.get("id", "dormitory_latrine")))
	set_meta("display_name", str(config.get("display_name", "宿舍卫生间")))
	set_meta("outbuilding_type", "latrine")
	set_meta("authority_role", "presentation_only_noninteractive_outbuilding")
	set_meta("has_interior", false)
	set_meta("enterable", false)
	set_meta("interactive", false)
	set_meta("functional", false)
	set_meta("roof_fade_member", false)
	_build_exterior()


func _build_exterior() -> void:
	var foundation := Node3D.new()
	foundation.name = "StoneFoundation"
	add_child(foundation)
	_add_box(foundation, "FoundationCore", Vector3(0.0, 0.14, 0.0), Vector3(3.02, 0.28, 2.62), STONE_COLOR)
	for x in [-1.23, -0.42, 0.40, 1.21]:
		_add_box(foundation, "FrontFoundationStone", Vector3(x, 0.22, 1.34), Vector3(0.70, 0.30, 0.16), STONE_LIGHT_COLOR.darkened(abs(x) * 0.035))
	for x in [-1.15, 0.0, 1.15]:
		_add_box(foundation, "RearFoundationStone", Vector3(x, 0.20, -1.34), Vector3(0.94, 0.28, 0.15), STONE_COLOR.darkened(0.05))

	var shell := Node3D.new()
	shell.name = "ClosedExteriorShell"
	add_child(shell)
	_add_box(shell, "RearPlasterWall", Vector3(0.0, 1.56, -1.22), Vector3(2.86, 2.58, 0.16), WALL_SHADOW_COLOR)
	_add_box(shell, "WestPlasterWall", Vector3(-1.43, 1.56, 0.0), Vector3(0.16, 2.58, 2.48), WALL_COLOR.darkened(0.04))
	_add_box(shell, "EastPlasterWall", Vector3(1.43, 1.56, 0.0), Vector3(0.16, 2.58, 2.48), WALL_COLOR)
	_add_box(shell, "FrontLeftWall", Vector3(-1.02, 1.56, 1.23), Vector3(0.82, 2.58, 0.16), WALL_COLOR.lightened(0.03))
	_add_box(shell, "FrontRightWall", Vector3(1.02, 1.56, 1.23), Vector3(0.82, 2.58, 0.16), WALL_COLOR.lightened(0.03))
	_add_box(shell, "FrontHeaderWall", Vector3(0.0, 2.57, 1.23), Vector3(1.25, 0.56, 0.16), WALL_COLOR)

	var frame := Node3D.new()
	frame.name = "OakTimberFrame"
	add_child(frame)
	for x in [-1.50, 1.50]:
		for z in [-1.27, 1.27]:
			_add_box(frame, "CornerPost", Vector3(x, 1.58, z), Vector3(0.18, 2.78, 0.18), TIMBER_COLOR)
	for z in [-1.28, 1.28]:
		_add_box(frame, "WallTopRail", Vector3(0.0, 2.91, z), Vector3(3.12, 0.20, 0.20), TIMBER_EDGE_COLOR)
	for x in [-1.48, 1.48]:
		_add_box(frame, "SideTopRail", Vector3(x, 2.91, 0.0), Vector3(0.20, 0.20, 2.45), TIMBER_EDGE_COLOR)
	_add_box(frame, "RearMidRail", Vector3(0.0, 1.40, -1.31), Vector3(2.90, 0.13, 0.13), TIMBER_COLOR)
	_add_box(frame, "WestDiagonalBrace", Vector3(-1.52, 1.58, 0.0), Vector3(0.13, 2.42, 0.13), TIMBER_COLOR, Vector3(39.0, 0.0, 0.0))
	_add_box(frame, "EastDiagonalBrace", Vector3(1.52, 1.58, 0.0), Vector3(0.13, 2.42, 0.13), TIMBER_COLOR, Vector3(-39.0, 0.0, 0.0))

	var door := Node3D.new()
	door.name = "ClosedPlankDoor"
	add_child(door)
	for plank_index in range(5):
		var plank_x := -0.48 + float(plank_index) * 0.24
		var plank_color := DOOR_COLOR.lightened(0.025 if plank_index % 2 == 0 else -0.015)
		_add_box(door, "DoorPlank%02d" % (plank_index + 1), Vector3(plank_x, 1.36, 1.335), Vector3(0.215, 2.28, 0.10), plank_color)
	_add_box(door, "DoorTopRail", Vector3(0.0, 2.36, 1.40), Vector3(1.16, 0.13, 0.11), TIMBER_EDGE_COLOR)
	_add_box(door, "DoorBottomRail", Vector3(0.0, 0.48, 1.40), Vector3(1.16, 0.13, 0.11), TIMBER_EDGE_COLOR)
	_add_box(door, "DoorDiagonalBrace", Vector3(0.0, 1.37, 1.40), Vector3(0.13, 1.82, 0.11), TIMBER_EDGE_COLOR, Vector3(0.0, 0.0, -28.0))
	for hinge_y in [0.72, 2.10]:
		_add_box(door, "IronStrapHinge", Vector3(-0.39, hinge_y, 1.47), Vector3(0.58, 0.07, 0.05), IRON_COLOR)
	_add_cylinder(door, "IronLatch", Vector3(0.39, 1.34, 1.49), 0.055, 0.14, IRON_COLOR, Vector3(90.0, 0.0, 0.0))
	_add_crescent_mark(door)

	var roof := Node3D.new()
	roof.name = "PermanentOpaqueRoof"
	add_child(roof)
	var slope_degrees := 27.0
	_add_box(roof, "WestRoofPlane", Vector3(-0.82, 3.33, 0.0), Vector3(1.90, 0.18, 3.12), ROOF_COLOR, Vector3(0.0, 0.0, slope_degrees))
	_add_box(roof, "EastRoofPlane", Vector3(0.82, 3.33, 0.0), Vector3(1.90, 0.18, 3.12), ROOF_COLOR.lightened(0.025), Vector3(0.0, 0.0, -slope_degrees))
	_add_cylinder(roof, "RoofRidge", Vector3(0.0, 3.74, 0.0), 0.13, 3.20, ROOF_EDGE_COLOR, Vector3(90.0, 0.0, 0.0))
	for z in [-1.38, -0.92, -0.46, 0.0, 0.46, 0.92, 1.38]:
		_add_box(roof, "WestShingleBand", Vector3(-0.83, 3.35, z), Vector3(1.83, 0.035, 0.055), ROOF_EDGE_COLOR.lightened(0.05), Vector3(0.0, 0.0, slope_degrees))
		_add_box(roof, "EastShingleBand", Vector3(0.83, 3.35, z), Vector3(1.83, 0.035, 0.055), ROOF_EDGE_COLOR.lightened(0.07), Vector3(0.0, 0.0, -slope_degrees))

	var ventilation := Node3D.new()
	ventilation.name = "RoofVentilation"
	add_child(ventilation)
	_add_cylinder(ventilation, "VentPipe", Vector3(-0.91, 3.48, -0.74), 0.11, 0.74, IRON_COLOR)
	_add_cylinder(ventilation, "VentCap", Vector3(-0.91, 3.88, -0.74), 0.18, 0.09, IRON_COLOR.lightened(0.08))
	_add_box(ventilation, "RearLouverDark", Vector3(0.0, 2.24, -1.315), Vector3(0.66, 0.42, 0.035), VENT_DARK_COLOR)
	for louver_y in [2.12, 2.24, 2.36]:
		_add_box(ventilation, "RearLouverSlat", Vector3(0.0, louver_y, -1.35), Vector3(0.72, 0.055, 0.055), TIMBER_EDGE_COLOR)

	var ground_detail := Node3D.new()
	ground_detail.name = "GroundingDetails"
	add_child(ground_detail)
	for stone_data in [
		[Vector3(-1.27, 0.10, 1.52), Vector3(0.42, 0.18, 0.32)],
		[Vector3(1.22, 0.09, 1.48), Vector3(0.50, 0.16, 0.28)],
		[Vector3(-1.44, 0.08, -0.82), Vector3(0.34, 0.14, 0.42)],
		[Vector3(1.40, 0.08, -0.64), Vector3(0.30, 0.14, 0.36)]
	]:
		_add_box(ground_detail, "DrainageStone", stone_data[0], stone_data[1], STONE_COLOR.darkened(0.08))


func _add_crescent_mark(parent: Node3D) -> void:
	var dark_disk := _add_cylinder(parent, "CrescentVentDark", Vector3(0.0, 2.00, 1.486), 0.18, 0.025, VENT_DARK_COLOR, Vector3(90.0, 0.0, 0.0))
	dark_disk.scale.y = 1.22
	var cover_disk := _add_cylinder(parent, "CrescentVentDoorMask", Vector3(0.085, 2.035, 1.502), 0.15, 0.026, DOOR_COLOR, Vector3(90.0, 0.0, 0.0))
	cover_disk.scale.y = 1.18


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation_degrees = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color, rotation_value := Vector3.ZERO) -> MeshInstance3D:
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


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material
