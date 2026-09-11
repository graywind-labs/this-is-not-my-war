extends RefCounted
## Shared visual closure. No collision, navigation, deployment or building state.

static func install(hall: Node3D, parent: Node3D = null, root_name: String = "CoverShellFinish") -> Node3D:
	if parent == null:
		parent = hall
	if parent.has_node(NodePath(root_name)):
		return parent.get_node(NodePath(root_name)) as Node3D
	var finish := Node3D.new()
	finish.name = root_name
	finish.set_meta("presentation_only", true)
	parent.add_child(finish)
	finish.transform = parent.global_transform.affine_inverse() * hall.global_transform
	var timber := _material(Color("#493729"))
	var plaster := _material(Color("#a69a80"))
	var recess := _material(Color("#202726"))
	var warm_recess := _material(Color("#55452d"))
	warm_recess.emission_enabled = true
	warm_recess.emission = Color("#694725")
	warm_recess.emission_energy_multiplier = 0.16
	# Roof bounds were read from the imported meshes in hall coordinates. End walls
	# sit behind the tile overhang, from the existing wall/deck up to the inner ridge.
	for side in [-1.0, 1.0]:
		_gable(finish, "KeepGable", Vector3(0,4.37,side*2.83), 8.18, 1.87, plaster, timber)
		_gable(finish, "GateGable", Vector3(0,3.45,6.72+side*1.18), 4.40, 1.37, plaster, timber)
	var modules: Array[Node] = []
	modules.append_array(hall.get_node("BaseVisuals/Exterior/TexturedFacadeModules").get_children())
	modules.append_array(hall.get_node("BaseVisuals/Exterior/SolidMainHallMass/CentralCommandKeep").get_children())
	var count := 0
	for module in modules:
		var module_name := str(module.name)
		var is_window := module_name.begins_with("Outer") or module_name.begins_with("KeepFrontWall") or module_name.begins_with("KeepRearWall") or module_name.begins_with("KeepSide")
		if not module is Node3D or not is_window:
			continue
		var frame := Node3D.new()
		frame.name = "Window_%s" % module.name
		finish.add_child(frame)
		frame.transform = hall.global_transform.affine_inverse()*module.global_transform
		# Source window opening is x=-0.60..0.60, y=1.05..2.31. Exterior is -Z.
		# Opaque backing stays in the reveal and ahead of the old internal masses.
		_box(frame,"RecessedWindow",Vector3(0,1.68,-0.16),Vector3(1.24,1.30,0.06),warm_recess if count%5==1 else recess)
		for x in [-0.61,0.0,0.61]:
			_box(frame,"VerticalFrame",Vector3(x,1.68,-0.245),Vector3(0.065,1.36,0.07),timber)
		for y in [1.015,1.68,2.345]:
			_box(frame,"HorizontalFrame",Vector3(0,y,-0.245),Vector3(1.29,0.065,0.07),timber)
		count += 1
	finish.set_meta("window_count",count)
	var door := Node3D.new()
	door.name = "ClosedOakDoor"
	finish.add_child(door)
	var door_module := hall.get_node("BaseVisuals/Exterior/TexturedFacadeModules/FrontDoor") as Node3D
	door.transform = hall.global_transform.affine_inverse()*door_module.global_transform
	var oak := _material(Color("#604831"))
	_box(door,"DoorBacking",Vector3(0,1.23,-0.13),Vector3(1.37,2.49,0.09),timber)
	for index in 8:
		_box(door,"OakPlank",Vector3(-0.59+index*0.168,1.23,-0.19),Vector3(0.156,2.46,0.05),oak)
	for y in [0.50,1.57]:
		for x in [-0.34,0.34]:
			_box(door,"IronStrap",Vector3(x,y,-0.225),Vector3(0.54,0.055,0.025),recess)
	return finish

static func set_gatehouse_visible(finish: Node3D, enabled: bool) -> void:
	if finish == null:
		return
	for node in finish.get_children():
		if node.get_meta("roof_section", "") == "front_gatehouse":
			node.visible = enabled

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material

static func _box(parent: Node3D, label: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = center
	parent.add_child(node)
	return node

static func _gable(parent: Node3D, label: String, base: Vector3, width: float, rise: float, plaster: Material, timber: Material) -> void:
	var shape := PrismMesh.new()
	shape.size = Vector3(width,rise,0.18)
	shape.material = plaster
	var face := MeshInstance3D.new()
	face.name = label
	face.set_meta("roof_section", "front_gatehouse" if label == "GateGable" else "central_keep")
	face.mesh = shape
	face.position = base+Vector3(0,rise*0.5,0)
	parent.add_child(face)
	var front := 0.105 if base.z>0 else -0.105
	_box(face,"SillBeam",Vector3(0,-rise*0.5+0.07,front),Vector3(width,0.14,0.13),timber)
	_box(face,"KingPost",Vector3(0,-0.03,front),Vector3(0.14,rise-0.10,0.13),timber)
	for side in [-1.0,1.0]:
		var beam := _box(face,"RakingBeam",Vector3(side*width*0.25,0,front),Vector3(sqrt(width*width*0.25+rise*rise),0.13,0.13),timber)
		beam.rotation.z = -side*atan2(rise,width*0.5)
