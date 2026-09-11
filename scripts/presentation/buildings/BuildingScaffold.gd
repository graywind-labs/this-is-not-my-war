extends Node3D
## Read-only construction art. The job, not helper presence or roof opacity, owns visibility.

const CONFIG_PATH := "res://data/presentation/building_scaffolds.json"
static var _catalog: Dictionary = {}
var building_id := ""
var _profile: Dictionary = {}
var _built := false
var _materials: Array[StandardMaterial3D] = []


static func install(view: Node3D, id: String) -> void:
	if view.has_node("ConstructionScaffold"):
		return
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if not parsed is Dictionary or parsed.get("schema_version", "") != "building_scaffolds_v1":
			push_error("Invalid building scaffold presentation configuration")
			return
		_catalog = parsed.get("buildings", {})
	# Art samples have no authoritative building and should not acquire formal props.
	if not _catalog.has(id):
		return
	var scaffold := new()
	scaffold.name = "ConstructionScaffold"
	scaffold.building_id = id
	scaffold._profile = _catalog[id]
	view.add_child(scaffold)


func _ready() -> void:
	visible = false
	add_to_group("building_scaffold")
	set_meta("authority_role", "presentation_only")
	get_node("/root/EventBus").building_state_changed.connect(_on_building_changed)
	call_deferred("_refresh")


func _on_building_changed(id: String) -> void:
	if id == building_id:
		_refresh()


func _refresh() -> void:
	var system := get_node_or_null("/root/Main/Systems/BuildingSystem")
	var active := system != null and (
		bool(system.is_repair_in_progress(building_id))
		or bool(system.is_upgrade_in_progress(building_id))
	)
	if active and not _built:
		_build()
	visible = active
	if not active and _built:
		# Hide synchronously, then release geometry; restarting in the same frame is safe.
		for child in get_children():
			remove_child(child)
			child.queue_free()
		_built = false


func _build() -> void:
	if _materials.is_empty():
		for color in [Color("#715039"), Color("#aa8052"), Color("#c6aa77")]:
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.roughness = 0.94
			_materials.append(material)
	for section: Dictionary in _profile.get("sections", []):
		var anchor := get_parent().get_node_or_null(NodePath(str(section.get("anchor", ".")))) as Node3D
		if anchor == null:
			push_error("Scaffold anchor missing for %s" % building_id)
			continue
		var piece := Node3D.new()
		piece.name = "TimberSection%d" % get_child_count()
		add_child(piece)
		var pos: Array = section.get("position", [0, 0, 0])
		var local_pose := Transform3D(Basis(Vector3.UP, deg_to_rad(float(section.get("yaw", 0)))), Vector3(pos[0], pos[1], pos[2]))
		piece.transform = global_transform.affine_inverse() * anchor.global_transform * local_pose
		_build_section(piece, section)
	_built = true


func _build_section(parent: Node3D, config: Dictionary) -> void:
	var length := clampf(float(config.get("length", 6.0)), 1.0, 14.0)
	var depth := clampf(float(config.get("depth", 1.0)), 0.8, 1.5)
	var tiers := clampi(int(config.get("tiers", 2)), 1, 3)
	var rise := clampf(float(config.get("tier_height", 1.6)), 0.8, 2.0)
	var bays := clampi(int(config.get("bays", 3)), 1, 6)
	var top := rise * tiers
	var groups: Array = [[], [], []]
	for i in range(bays + 1):
		var x := -length * 0.5 + length * i / bays
		for z in [-depth * 0.5, depth * 0.5]:
			_box(groups, 0, Vector3(x, (top + 0.85) * 0.5, z), Vector3(0.16, top + 0.85, 0.16))
			_box(groups, 1, Vector3(x, 0.05, z), Vector3(0.4, 0.1, 0.34))
			for tier in range(1, tiers + 1):
				for wrap in 3:
					_box(groups, 2, Vector3(x, rise * tier - 0.1 + wrap * 0.05, z), Vector3(0.20, 0.032, 0.20))
		for tier in range(1, tiers + 1):
			_box(groups, 0, Vector3(x, rise * tier - 0.13, 0), Vector3(0.18, 0.18, depth + 0.24))
	for tier in range(1, tiers + 1):
		var y := rise * tier
		for z in [-depth * 0.5, depth * 0.5]:
			_box(groups, 0, Vector3(0, y - 0.13, z), Vector3(length + 0.3, 0.18, 0.14))
		# Separate warm boards leave fine seams visible from the management camera.
		for bay in bays:
			for plank in 5:
				_box(groups, 1, Vector3(-length * 0.5 + length * (bay + 0.5) / bays, y, -depth * 0.5 + depth * (plank + 0.5) / 5), Vector3(length / bays - 0.035, 0.11, depth / 5 - 0.018))
		_box(groups, 0, Vector3(0, y + 0.72, depth * 0.5), Vector3(length + 0.2, 0.1, 0.1))
		for bay in bays:
			var left := -length * 0.5 + length * bay / bays
			var right := left + length / bays
			_beam(groups, 0, Vector3(left, y - rise + 0.16, depth * 0.5 + 0.1), Vector3(right, y - 0.18, depth * 0.5 + 0.1), 0.085)
			_beam(groups, 0, Vector3(right, y - rise + 0.16, depth * 0.5 + 0.12), Vector3(left, y - 0.18, depth * 0.5 + 0.12), 0.085)
	# A ladder leans against the outer platform edge, with both feet at ground level.
	var ladder_x := -length * 0.5 + minf(0.7, length * 0.3)
	var foot := Vector3(ladder_x, 0.10, depth * 0.5 + top * 0.23)
	var head := Vector3(ladder_x, top + 0.3, depth * 0.5)
	for side in [-0.27, 0.27]:
		_beam(groups, 1, foot + Vector3(side, 0, 0), head + Vector3(side, 0, 0), 0.085)
	var rungs := maxi(3, int(top / 0.28))
	for i in range(1, rungs + 1):
		_box(groups, 1, foot.lerp(head, float(i) / (rungs + 1)), Vector3(0.62, 0.07, 0.09))
	for index in groups.size():
		var transforms: Array = groups[index]
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = mesh
		batch.instance_count = transforms.size()
		for i in transforms.size():
			batch.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = ["TimberFrame", "DeckAndLadder", "RopeBindings"][index]
		instance.multimesh = batch
		instance.material_override = _materials[index]
		parent.add_child(instance)


func _box(groups: Array, material: int, center: Vector3, size: Vector3) -> void:
	groups[material].append(Transform3D(Basis.IDENTITY.scaled(size), center))


func _beam(groups: Array, material: int, start: Vector3, end: Vector3, width: float) -> void:
	var delta := end - start
	groups[material].append(Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())).scaled(Vector3(width, delta.length(), width)), (start + end) * 0.5))


func get_debug_snapshot() -> Dictionary:
	return {"building_id": building_id, "design": _profile.get("design", ""), "visible": visible, "built": _built, "sections": get_child_count(), "authority_role": "presentation_only"}
