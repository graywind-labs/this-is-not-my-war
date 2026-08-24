extends Node3D

const ART_REVISION := "t0132_p4b"
const FOOTPRINT_SIZE := Vector3(3.6, 3.38, 3.6)
const WOOD_BASE := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_BaseColor.png"
const WOOD_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Normal.png"
const WOOD_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Roughness.png"
const METAL_BASE := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_MetalOrnaments_BaseColor.png"
const METAL_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_MetalOrnaments_Roughness.png"

var _wood_material: StandardMaterial3D
var _wood_dark_material: StandardMaterial3D
var _metal_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_platform()
	set_meta("art_revision", ART_REVISION)
	set_meta("formal_main_hall_wood_platform", true)
	set_meta("footprint_size", FOOTPRINT_SIZE)
	set_meta("device_anchor_local_y", 0.88)
	set_meta("uses_quaternius_pbr", true)


func get_debug_snapshot() -> Dictionary:
	return {
		"art_revision": ART_REVISION,
		"footprint_size": {"x": FOOTPRINT_SIZE.x, "y": FOOTPRINT_SIZE.y, "z": FOOTPRINT_SIZE.z},
		"device_anchor_local_y": 0.88,
		"wood_texture": WOOD_BASE,
		"structure_parts": find_children("*", "MeshInstance3D", true, false).size(),
		"has_timber_corbel_frame": get_node_or_null("TimberStructure/TimberCorbelFrame") != null,
		"has_open_front_firing_arc": true,
		"authority_role": "presentation_only"
	}


func _build_materials() -> void:
	_wood_material = _make_pbr_material(WOOD_BASE, WOOD_ROUGHNESS, WOOD_NORMAL, Color("#6a4d39"), Vector3(2.0, 2.0, 2.0))
	_wood_dark_material = _make_pbr_material(WOOD_BASE, WOOD_ROUGHNESS, WOOD_NORMAL, Color("#4d382d"), Vector3(2.4, 2.4, 2.4))
	_metal_material = _make_pbr_material(METAL_BASE, METAL_ROUGHNESS, "", Color("#4a4b4b"), Vector3(2.5, 2.5, 2.5))


func _build_platform() -> void:
	var structure := Node3D.new()
	structure.name = "TimberStructure"
	add_child(structure)

	# The visible deck ends at y=0.66. Devices continue to use the pre-existing
	# authoritative anchor at local y=0.88, leaving a small iron-shod mounting gap.
	_add_box(structure, "TimberCorbelFrame", Vector3(3.6, 0.50, 3.6), Vector3(0.0, 0.25, 0.0), _wood_dark_material)
	_add_box(structure, "TimberDeck", Vector3(3.42, 0.16, 3.42), Vector3(0.0, 0.58, 0.0), _wood_material)
	for z in [-1.20, -0.40, 0.40, 1.20]:
		_add_box(structure, "DeckPlank", Vector3(3.30, 0.04, 0.08), Vector3(0.0, 0.68, z), _wood_dark_material)

	for x in [-1.56, 1.56]:
		_add_box(structure, "TimberSideParapet", Vector3(0.28, 0.62, 3.40), Vector3(x, 0.88, 0.0), _wood_dark_material)
	for x in [-1.42, -0.48, 0.48, 1.42]:
		_add_box(structure, "TimberRearMerlon", Vector3(0.48, 0.66, 0.30), Vector3(x, 0.90, -1.53), _wood_dark_material)
		_add_box(structure, "TimberFrontMerlon", Vector3(0.48, 0.66, 0.30), Vector3(x, 0.90, 1.53), _wood_dark_material)

	# Short roof-deck corbels echo the wall platforms without pretending that the
	# main-hall platforms are freestanding towers extending through the building.
	for x in [-1.40, 1.40]:
		_add_box(structure, "PlatformSupportPost", Vector3(0.26, 2.38, 0.28), Vector3(x, -0.94, -0.72), _wood_dark_material)
		var rear_brace := _add_box(structure, "RearPlatformBrace", Vector3(0.18, 1.42, 0.18), Vector3(x, -0.18, -0.74), _wood_material)
		rear_brace.rotation_degrees.x = -24.0
		var side_brace := _add_box(structure, "SidePlatformBrace", Vector3(0.18, 1.26, 0.18), Vector3(x, -0.10, 0.62), _wood_material)
		side_brace.rotation_degrees.z = 22.0 if x < 0.0 else -22.0

	for x in [-1.42, 1.42]:
		for z in [-1.42, 1.42]:
			_add_box(structure, "IronCornerShoe", Vector3(0.34, 0.14, 0.34), Vector3(x, 0.51, z), _metal_material)


func _make_pbr_material(base_path: String, roughness_path: String, normal_path: String, tint: Color, uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	material.uv1_triplanar = true
	material.uv1_scale = uv_scale
	if ResourceLoader.exists(base_path):
		material.albedo_texture = load(base_path)
	if not roughness_path.is_empty() and ResourceLoader.exists(roughness_path):
		material.roughness_texture = load(roughness_path)
	if not normal_path.is_empty() and ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_texture = load(normal_path)
	return material


func _add_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.set_meta("formal_textured_part", true)
	parent.add_child(mesh_instance)
	return mesh_instance
