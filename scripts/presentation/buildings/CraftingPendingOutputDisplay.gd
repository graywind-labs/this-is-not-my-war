class_name CraftingPendingOutputDisplay
extends Node3D


const CONFIG_FILE := "presentation/crafting_pending_output_visuals.json"
const CRAFTING_SYSTEM_PATH := "/root/Main/Systems/CraftingSystem"
const DEFAULT_FIXTURE_TOP_Y := 0.16
const DEFAULT_ITEM_CLEARANCE := 0.06

@export var building_id := ""

var _config: Dictionary = {}
var _fixture_root: Node3D
var _content_root: Node3D
var _displayed_item_id := ""
var _displayed_item_name := ""
var _display_kind := ""
var _material_cache: Dictionary = {}


func _ready() -> void:
	_load_config()
	_apply_building_transform()
	_build_permanent_fixture()
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system != null and crafting_system.has_signal("pending_outputs_changed"):
		crafting_system.pending_outputs_changed.connect(_on_pending_outputs_changed)
	_refresh_from_authority()


func debug_get_snapshot() -> Dictionary:
	var content_bounds := _get_mesh_bounds_in_display(_content_root)
	return {
		"building_id": building_id,
		"visible": visible,
		"fixture_visible": _fixture_root != null and _fixture_root.visible,
		"item_visible": _content_root != null and _content_root.visible,
		"displayed_item_id": _displayed_item_id,
		"displayed_item_name": _displayed_item_name,
		"display_kind": _display_kind,
		"local_position": position,
		"mesh_count": find_children("*", "MeshInstance3D", true, false).size(),
		"fixture_mesh_count": _fixture_root.find_children("*", "MeshInstance3D", true, false).size() if _fixture_root != null else 0,
		"item_mesh_count": _content_root.find_children("*", "MeshInstance3D", true, false).size() if _content_root != null else 0,
		"fixture_top_y": _get_fixture_top_y(),
		"item_bottom_y": float(content_bounds.get("min_y", 0.0)),
		"collision_object_count": find_children("*", "CollisionObject3D", true, false).size(),
		"content_child_count": _content_root.get_child_count() if _content_root != null else 0,
		"authority_role": "presentation_only"
	}


func _load_config() -> void:
	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		return
	var loaded: Variant = config_loader.load_data_file(CONFIG_FILE, {})
	if loaded is Dictionary:
		_config = (loaded as Dictionary).duplicate(true)


func _apply_building_transform() -> void:
	var definition := _get_building_definition()
	position = _vector3_from_array(definition.get("position", []), Vector3.ZERO)
	rotation_degrees.y = float(definition.get("rotation_y_degrees", 0.0))
	visible = true


func _get_building_definition() -> Dictionary:
	var buildings: Dictionary = _config.get("buildings", {}) if _config.get("buildings", {}) is Dictionary else {}
	return buildings.get(building_id, {}) if buildings.get(building_id, {}) is Dictionary else {}


func _get_fixture_top_y() -> float:
	return float(_get_building_definition().get("fixture_top_y", DEFAULT_FIXTURE_TOP_Y))


func _get_item_clearance() -> float:
	return maxf(0.0, float(_get_building_definition().get("item_clearance", DEFAULT_ITEM_CLEARANCE)))


func _build_permanent_fixture() -> void:
	_fixture_root = Node3D.new()
	_fixture_root.name = "PermanentDisplayFixture"
	_fixture_root.set_meta("fixture_role", "permanent_presentation")
	add_child(_fixture_root)
	_build_pallet(_fixture_root)


func _on_pending_outputs_changed(changed_building_id: String, _pending_snapshot: Dictionary) -> void:
	if changed_building_id == building_id:
		_refresh_from_authority()


func _refresh_from_authority() -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("get_latest_pending_output_entry"):
		_show_no_item()
		return
	var entry: Dictionary = crafting_system.get_latest_pending_output_entry(building_id)
	var item_id := str(entry.get("item_id", ""))
	if item_id.is_empty():
		_show_no_item()
		return
	if item_id == _displayed_item_id and _content_root != null:
		visible = true
		return
	_displayed_item_id = item_id
	_displayed_item_name = str(entry.get("name", item_id))
	_rebuild_content(item_id)


func _show_no_item() -> void:
	_displayed_item_id = ""
	_displayed_item_name = ""
	_display_kind = ""
	_clear_content()
	visible = true


func _rebuild_content(item_id: String) -> void:
	_clear_content()
	_content_root = Node3D.new()
	_content_root.name = "LatestPendingItem"
	_content_root.set_meta("item_id", item_id)
	_content_root.set_meta("collision_policy", "none")
	add_child(_content_root)
	var items: Dictionary = _config.get("items", {}) if _config.get("items", {}) is Dictionary else {}
	var definition: Dictionary = items.get(item_id, {}) if items.get(item_id, {}) is Dictionary else {}
	_display_kind = str(definition.get("kind", ""))
	match _display_kind:
		"helmet":
			_build_helmet(_content_root)
		"bracers":
			_build_bracers(_content_root)
		"greaves":
			_build_greaves(_content_root)
		"mail_chest":
			_build_mail_chest(_content_root)
		"polearm":
			_build_polearm(_content_root)
		"crossbow":
			_build_crossbow(_content_root)
		"asset", "sword_shield":
			_build_assets(_content_root, definition.get("assets", []))
		_:
			_build_fallback_crate(_content_root)
	_place_content_above_fixture()
	visible = true


func _clear_content() -> void:
	if _content_root == null:
		return
	remove_child(_content_root)
	_content_root.queue_free()
	_content_root = null


func _place_content_above_fixture() -> void:
	if _content_root == null:
		return
	var bounds := _get_mesh_bounds_in_display(_content_root)
	if not bool(bounds.get("valid", false)):
		return
	var desired_bottom := _get_fixture_top_y() + _get_item_clearance()
	_content_root.position.y += desired_bottom - float(bounds.get("min_y", desired_bottom))


func _get_mesh_bounds_in_display(root_node: Node3D) -> Dictionary:
	if root_node == null:
		return {"valid": false, "min_y": 0.0, "max_y": 0.0}
	var has_point := false
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	for raw_node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := raw_node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var aabb := mesh_node.get_aabb()
		for x_index in 2:
			for y_index in 2:
				for z_index in 2:
					var local_corner := aabb.position + Vector3(
						aabb.size.x * float(x_index),
						aabb.size.y * float(y_index),
						aabb.size.z * float(z_index)
					)
					var display_corner := to_local(mesh_node.to_global(local_corner))
					if not has_point:
						minimum = display_corner
						maximum = display_corner
						has_point = true
					else:
						minimum = minimum.min(display_corner)
						maximum = maximum.max(display_corner)
	return {
		"valid": has_point,
		"min": minimum,
		"max": maximum,
		"min_y": minimum.y,
		"max_y": maximum.y,
	}


func _build_pallet(parent: Node3D) -> void:
	var wood := _material("pallet", Color("#6c4a2f"), 0.86)
	for z in [-0.52, 0.0, 0.52]:
		_add_box(parent, "PalletPlank", Vector3(0.0, 0.10, z), Vector3(1.75, 0.12, 0.38), wood)
	for x in [-0.65, 0.65]:
		_add_box(parent, "PalletRunner", Vector3(x, 0.035, 0.0), Vector3(0.16, 0.07, 1.35), wood)


func _build_helmet(parent: Node3D) -> void:
	var iron := _material("iron", Color("#666c70"), 0.38, 0.72)
	var bowl_mesh := SphereMesh.new()
	bowl_mesh.radius = 0.48
	bowl_mesh.height = 0.76
	bowl_mesh.radial_segments = 12
	bowl_mesh.rings = 6
	bowl_mesh.material = iron
	var bowl := MeshInstance3D.new()
	bowl.name = "HelmetBowl"
	bowl.mesh = bowl_mesh
	bowl.position = Vector3(0.0, 0.56, 0.0)
	bowl.scale = Vector3(1.0, 0.82, 1.0)
	parent.add_child(bowl)
	_add_cylinder(parent, "HelmetRim", Vector3(0.0, 0.36, 0.0), 0.52, 0.10, iron)
	_add_box(parent, "NoseGuard", Vector3(0.0, 0.48, 0.46), Vector3(0.10, 0.42, 0.07), iron)


func _build_bracers(parent: Node3D) -> void:
	var iron := _material("iron", Color("#666c70"), 0.40, 0.70)
	for x in [-0.38, 0.38]:
		var bracer := _add_cylinder(parent, "IronBracer", Vector3(x, 0.34, 0.0), 0.20, 0.68, iron)
		bracer.rotation_degrees.z = 82.0
		_add_box(parent, "BracerBand", Vector3(x, 0.35, 0.0), Vector3(0.12, 0.74, 0.08), iron, Vector3(0.0, 0.0, 82.0))


func _build_greaves(parent: Node3D) -> void:
	var iron := _material("iron", Color("#686e72"), 0.40, 0.68)
	for x in [-0.34, 0.34]:
		_add_box(parent, "IronGreave", Vector3(x, 0.48, 0.0), Vector3(0.34, 0.82, 0.28), iron, Vector3(0.0, 0.0, -5.0 if x < 0.0 else 5.0))
		_add_box(parent, "GreaveKnee", Vector3(x, 0.89, 0.02), Vector3(0.42, 0.20, 0.34), iron)


func _build_mail_chest(parent: Node3D) -> void:
	var mail := _material("mail", Color("#70777a"), 0.48, 0.78)
	_add_box(parent, "MailTorso", Vector3(0.0, 0.63, 0.0), Vector3(0.92, 0.92, 0.40), mail)
	_add_box(parent, "MailSkirt", Vector3(0.0, 0.28, 0.0), Vector3(1.06, 0.34, 0.42), mail)
	for x in [-0.61, 0.61]:
		var sleeve := _add_cylinder(parent, "MailSleeve", Vector3(x, 0.72, 0.0), 0.19, 0.44, mail)
		sleeve.rotation_degrees.z = 90.0


func _build_polearm(parent: Node3D) -> void:
	var wood := _material("ash", Color("#704b26"), 0.86)
	var iron := _material("iron", Color("#676d70"), 0.38, 0.72)
	var shaft := _add_cylinder(parent, "AshShaft", Vector3(0.0, 0.34, 0.0), 0.045, 2.35, wood)
	shaft.rotation_degrees.z = 90.0
	var tip := _add_cone(parent, "SpearPoint", Vector3(1.30, 0.34, 0.0), 0.13, 0.36, iron)
	tip.rotation_degrees.z = -90.0
	_add_box(parent, "HalberdBlade", Vector3(1.12, 0.48, 0.0), Vector3(0.30, 0.30, 0.08), iron, Vector3(0.0, 0.0, 34.0))


func _build_crossbow(parent: Node3D) -> void:
	var wood := _material("walnut", Color("#603719"), 0.82)
	var light_wood := _material("bow_wood", Color("#9a642f"), 0.76)
	var iron := _material("iron", Color("#636a6e"), 0.38, 0.72)
	var rope := _material("rope", Color("#c0aa78"), 0.90)
	_add_box(parent, "CrossbowStock", Vector3(0.0, 0.34, 0.0), Vector3(0.18, 0.16, 1.28), wood)
	_add_box(parent, "CrossbowLimb", Vector3(0.0, 0.38, -0.38), Vector3(1.42, 0.10, 0.13), light_wood)
	_add_box(parent, "IronLock", Vector3(0.0, 0.46, 0.05), Vector3(0.26, 0.16, 0.22), iron)
	_add_segment(parent, "LeftString", Vector3(-0.70, 0.40, -0.38), Vector3(0.0, 0.48, 0.05), 0.012, rope)
	_add_segment(parent, "RightString", Vector3(0.70, 0.40, -0.38), Vector3(0.0, 0.48, 0.05), 0.012, rope)


func _build_assets(parent: Node3D, raw_assets: Variant) -> void:
	if not raw_assets is Array:
		_build_fallback_crate(parent)
		return
	for index in (raw_assets as Array).size():
		var raw_definition: Variant = (raw_assets as Array)[index]
		if not raw_definition is Dictionary:
			continue
		var definition := raw_definition as Dictionary
		var path := str(definition.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		if instance == null:
			continue
		instance.name = "DisplayedAsset%02d" % index
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		parent.add_child(instance)
		instance.position = _vector3_from_array(definition.get("position", []), Vector3.ZERO)
		instance.rotation_degrees = _vector3_from_array(definition.get("rotation_degrees", []), Vector3.ZERO)
		instance.scale = _vector3_from_array(definition.get("scale", []), Vector3.ONE)


func _build_fallback_crate(parent: Node3D) -> void:
	_add_box(parent, "FallbackFinishedGoods", Vector3(0.0, 0.48, 0.0), Vector3(0.90, 0.72, 0.80), _material("fallback", Color("#765034"), 0.86))


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, material: Material, local_rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = local_position
	node.rotation_degrees = local_rotation_degrees
	parent.add_child(node)
	return node


func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = local_position
	parent.add_child(node)
	return node


func _add_cone(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = local_position
	parent.add_child(node)
	return node


func _add_segment(parent: Node3D, node_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var delta := to - from
	var node := _add_cylinder(parent, node_name, (from + to) * 0.5, radius, delta.length(), material)
	if delta.length_squared() > 0.000001:
		node.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return node


func _material(key: String, color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_material_cache[key] = material
	return material


func _vector3_from_array(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array or (value as Array).size() < 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
