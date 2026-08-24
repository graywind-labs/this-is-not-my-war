class_name FormalNoticeBoardArtView
extends Node3D


const ART_REVISION := "t0132_p6"
const VISIBLE_ENVELOPE := Vector3(2.92, 3.18, 1.18)
const WOOD_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_BaseColor.png"
const WOOD_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Normal.png"
const WOOD_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Roughness.png"
const ROOF_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RoundTiles_BaseColor.png"
const ROOF_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RoundTiles_Normal.png"
const ROOF_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RoundTiles_Roughness.png"
const ROCK_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_BaseColor.png"
const ROCK_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_Normal.png"
const ROCK_ORM := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_ORM.png"

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_notice_board()


func get_debug_snapshot() -> Dictionary:
	var geometry := get_node_or_null("Geometry")
	return {
		"art_revision": ART_REVISION,
		"visual_identity": "sheltered_main_hall_notice_board",
		"visible_envelope": VISIBLE_ENVELOPE,
		"mesh_count": 0 if geometry == null else geometry.find_children("*", "MeshInstance3D", true, false).size(),
		"textured_mesh_count": _count_meta(geometry, "formal_textured_part"),
		"paper_sheet_count": _count_meta(geometry, "notice_paper_sheet"),
		"roof_panel_count": _count_meta(geometry, "notice_roof_panel"),
		"support_post_count": _count_meta(geometry, "notice_support_post"),
		"has_physics_collision": not find_children("*", "CollisionObject3D", true, false).is_empty(),
		"presentation_only": true,
		"building_authority": false
	}


func _build_formal_notice_board() -> void:
	if get_node_or_null("Geometry") != null:
		return
	set_meta("art_revision", ART_REVISION)
	set_meta("presentation_only", true)
	set_meta("building_authority", false)
	set_meta("visible_envelope", VISIBLE_ENVELOPE)

	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)

	var wood_dark := _pbr_material("wood", Color("#4a342c"), 0.78)
	var wood_mid := _pbr_material("wood", Color("#735344"), 0.72)
	var wood_edge := _pbr_material("wood", Color("#8a6650"), 0.66)
	var roof := _pbr_material("roof", Color("#665957"), 0.82)
	var stone := _pbr_material("rock", Color("#77746d"), 0.72)
	var iron := _flat_material(Color("#30363a"), 0.68, 0.52)
	var brass := _flat_material(Color("#8b6b34"), 0.61, 0.38)
	var paper_old := _flat_material(Color("#d6c49b"), 0.94)
	var paper_pale := _flat_material(Color("#e3d4ac"), 0.96)
	var paper_dim := _flat_material(Color("#bba87f"), 0.97)
	var wax := _flat_material(Color("#7a3035"), 0.76)

	for side in [-1.0, 1.0]:
		var post := _add_box(geometry, "SupportPost", Vector3(0.24, 2.58, 0.26), Vector3(side * 1.12, 1.37, -0.04), Vector3(0.0, 0.0, side * 0.018), wood_dark)
		post.set_meta("notice_support_post", true)
		_add_box(geometry, "PostIronFoot", Vector3(0.32, 0.42, 0.34), Vector3(side * 1.12, 0.32, -0.04), Vector3.ZERO, iron)
		_add_box(geometry, "StoneFooting", Vector3(0.58, 0.18, 0.62), Vector3(side * 1.12, 0.10, -0.03), Vector3(0.0, side * 0.12, 0.0), stone)
		var brace := _add_box(geometry, "LowerBrace", Vector3(0.15, 1.02, 0.17), Vector3(side * 0.70, 0.72, -0.01), Vector3(0.0, 0.0, side * 0.73), wood_mid)
		brace.set_meta("structural_brace", true)

	_add_box(geometry, "LowerTieBeam", Vector3(2.52, 0.18, 0.24), Vector3(0.0, 0.62, -0.04), Vector3.ZERO, wood_dark)
	_add_box(geometry, "BoardBack", Vector3(2.46, 1.34, 0.15), Vector3(0.0, 1.78, 0.0), Vector3.ZERO, wood_mid)
	_add_box(geometry, "BoardInner", Vector3(2.16, 1.08, 0.06), Vector3(0.0, 1.78, 0.105), Vector3.ZERO, wood_dark)
	_add_box(geometry, "FrameTop", Vector3(2.72, 0.18, 0.25), Vector3(0.0, 2.50, 0.03), Vector3.ZERO, wood_edge)
	_add_box(geometry, "FrameBottom", Vector3(2.72, 0.20, 0.25), Vector3(0.0, 1.07, 0.03), Vector3.ZERO, wood_dark)
	for side in [-1.0, 1.0]:
		_add_box(geometry, "FrameSide", Vector3(0.18, 1.52, 0.25), Vector3(side * 1.31, 1.78, 0.03), Vector3.ZERO, wood_edge)
		_add_box(geometry, "FrameCornerIron", Vector3(0.24, 0.24, 0.29), Vector3(side * 1.30, 2.48, 0.04), Vector3.ZERO, iron)

	for front_sign in [-1.0, 1.0]:
		var roof_panel := _add_box(
			geometry,
			"RoofPanel",
			Vector3(2.92, 0.13, 0.72),
			Vector3(0.0, 2.82, front_sign * 0.31),
			Vector3(front_sign * deg_to_rad(24.0), 0.0, 0.0),
			roof
		)
		roof_panel.set_meta("notice_roof_panel", true)
	_add_box(geometry, "RoofRidge", Vector3(3.02, 0.18, 0.20), Vector3(0.0, 3.05, 0.0), Vector3.ZERO, wood_dark)
	for side in [-1.0, 1.0]:
		_add_box(geometry, "RoofKnee", Vector3(0.15, 0.62, 0.16), Vector3(side * 1.13, 2.61, 0.0), Vector3(0.0, 0.0, side * 0.54), wood_mid)

	_add_paper(geometry, "CenterNotice", Vector2(1.20, 0.84), Vector3(0.02, 1.79, 0.158), -0.012, paper_pale)
	_add_paper(geometry, "LeftNotice", Vector2(0.52, 0.72), Vector3(-0.86, 1.77, 0.164), 0.065, paper_old)
	_add_paper(geometry, "RightNotice", Vector2(0.48, 0.68), Vector3(0.87, 1.80, 0.166), -0.048, paper_dim)
	for pin in [Vector3(-0.87, 2.04, 0.205), Vector3(0.86, 2.05, 0.207), Vector3(0.02, 2.12, 0.205)]:
		_add_cylinder(geometry, "IronPin", 0.038, 0.045, pin, Vector3(deg_to_rad(90.0), 0.0, 0.0), iron, 8)
	_add_cylinder(geometry, "WaxSeal", 0.085, 0.042, Vector3(0.47, 1.50, 0.215), Vector3(deg_to_rad(90.0), 0.0, 0.0), wax, 12)
	_add_box(geometry, "SealRibbonLeft", Vector3(0.055, 0.24, 0.025), Vector3(0.43, 1.34, 0.214), Vector3(0.0, 0.0, -0.12), wax)
	_add_box(geometry, "SealRibbonRight", Vector3(0.055, 0.24, 0.025), Vector3(0.51, 1.34, 0.214), Vector3(0.0, 0.0, 0.12), wax)

	_add_cylinder(geometry, "GuardCrest", 0.20, 0.055, Vector3(0.0, 2.62, 0.22), Vector3(deg_to_rad(90.0), 0.0, 0.0), brass, 10)
	_add_box(geometry, "CrestVertical", Vector3(0.07, 0.28, 0.045), Vector3(0.0, 2.62, 0.255), Vector3.ZERO, iron)
	_add_box(geometry, "CrestHorizontal", Vector3(0.25, 0.065, 0.045), Vector3(0.0, 2.64, 0.255), Vector3.ZERO, iron)
	for side in [-1.0, 1.0]:
		_add_cylinder(geometry, "HangingRing", 0.075, 0.04, Vector3(side * 1.07, 1.02, 0.19), Vector3(deg_to_rad(90.0), 0.0, 0.0), iron, 10)
	_add_cylinder(geometry, "SpareNoticeRoll", 0.075, 0.82, Vector3(-0.53, 0.88, 0.13), Vector3(0.0, 0.0, deg_to_rad(90.0)), paper_old, 10)
	_add_box(geometry, "ShelfLip", Vector3(1.22, 0.10, 0.32), Vector3(-0.30, 0.80, 0.10), Vector3.ZERO, wood_mid)


func _add_paper(parent: Node3D, node_name: String, size: Vector2, center: Vector3, roll: float, material: Material) -> MeshInstance3D:
	var paper := _add_box(parent, node_name, Vector3(size.x, size.y, 0.025), center, Vector3(0.0, 0.0, roll), material)
	paper.set_meta("notice_paper_sheet", true)
	return paper


func _add_box(parent: Node3D, node_name: String, size: Vector3, center: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation = rotation_value
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	if material is StandardMaterial3D and (material as StandardMaterial3D).albedo_texture != null:
		instance.set_meta("formal_textured_part", true)
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, center: Vector3, rotation_value: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation = rotation_value
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	parent.add_child(instance)
	return instance


func _pbr_material(kind: String, tint: Color, density: float) -> StandardMaterial3D:
	var key := "%s:%s:%.2f" % [kind, tint.to_html(true), density]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * density
	var base_path := WOOD_BASE_COLOR
	var normal_path := WOOD_NORMAL
	var roughness_path := WOOD_ROUGHNESS
	var orm_path := ""
	if kind == "roof":
		base_path = ROOF_BASE_COLOR
		normal_path = ROOF_NORMAL
		roughness_path = ROOF_ROUGHNESS
	elif kind == "rock":
		base_path = ROCK_BASE_COLOR
		normal_path = ROCK_NORMAL
		roughness_path = ""
		orm_path = ROCK_ORM
	if ResourceLoader.exists(base_path):
		material.albedo_texture = load(base_path) as Texture2D
	if ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_scale = 0.58
		material.normal_texture = load(normal_path) as Texture2D
	if not orm_path.is_empty() and ResourceLoader.exists(orm_path):
		material.orm_texture = load(orm_path) as Texture2D
	elif not roughness_path.is_empty() and ResourceLoader.exists(roughness_path):
		material.roughness_texture = load(roughness_path) as Texture2D
	_material_cache[key] = material
	return material


func _flat_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "flat:%s:%.2f:%.2f" % [color.to_html(true), roughness, metallic]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_material_cache[key] = material
	return material


func _count_meta(root: Node, meta_name: String) -> int:
	if root == null:
		return 0
	var count := 1 if root.has_meta(meta_name) else 0
	for child in root.get_children():
		count += _count_meta(child, meta_name)
	return count
