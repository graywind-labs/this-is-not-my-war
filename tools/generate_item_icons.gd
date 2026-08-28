extends SceneTree


const OUTPUT_ROOT := "res://assets/ui/item_icons"
const CONFIG_PATH := "res://data/presentation/item_icon_render.json"
const TOMA_SCENE := "res://scenes/characters/TomaChibiArtView.tscn"
const HORSE_SCENE := "res://assets/3d/quaternius/animals/merchant_horse.glb"
const SWORD_SCENE := "res://assets/3d/synty/t0130_pilot/Prop_Sword_01.fbx"
const SHIELD_SCENE := "res://assets/3d/synty/t0130_pilot/Prop_ShieldKnight_01.fbx"
const HORSE_APPEARANCE := preload("res://scripts/presentation/characters/HorseAppearance.gd")
const WEAPONS := ["sword_shield", "polearm", "bow", "crossbow"]
const ARMOR := ["helmet", "chest", "bracers", "greaves"]
const ARMOR_IDS := {
	"helmet": "iron_helmet",
	"chest": "mail_chest",
	"bracers": "iron_bracers",
	"greaves": "iron_greaves",
}
const ARMOR_NODE_NAMES := {
	"helmet": "SyntyKnightHelmetArmor",
	"chest": "SyntyKnightChestArmor",
	"bracers": "SyntyKnightBracersArmor",
	"greaves": "SyntyKnightGreavesArmor",
}
const DEFENSE_DEVICES := {
	"wall_ballista": "res://scenes/defense_devices/FormalBallistaArtView.tscn",
	"wall_arrow_tower": "res://scenes/defense_devices/FormalArrowTowerArtView.tscn",
}

var _world: Node3D
var _camera: Camera3D
var _environment_resource: Environment
var _config: Dictionary
var _generated_paths: Array[String] = []


func _init() -> void:
	_config = _read_json_dictionary(CONFIG_PATH)
	var icon_size := int(_config.get("size", 512))
	root.size = Vector2i(icon_size, icon_size)
	root.msaa_3d = Viewport.MSAA_4X
	for category in ["weapon", "armor", "horse", "defense_device"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_ROOT, category]))
	_world = Node3D.new()
	_world.name = "ItemIconStudio"
	root.add_child(_world)
	_configure_studio()
	for weapon_id in WEAPONS:
		await _render_weapon(str(weapon_id))
	for armor_slot in ARMOR:
		await _render_armor(str(armor_slot))
	var horse_defs := _read_json_dictionary("res://data/horse_defs.json")
	for raw_template in horse_defs.get("horse_templates", []):
		if raw_template is Dictionary:
			await _render_horse(raw_template as Dictionary)
	for device_id in DEFENSE_DEVICES:
		await _render_defense_device(str(device_id), str(DEFENSE_DEVICES[device_id]))
	await _build_contact_sheet()
	print("ITEM_ICON_GENERATION PASS count=%d" % _generated_paths.size())
	quit(0)


func _configure_studio() -> void:
	var world_environment := WorldEnvironment.new()
	_environment_resource = Environment.new()
	_environment_resource.background_mode = Environment.BG_COLOR
	_environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment_resource.ambient_light_color = Color("DDE5E1")
	_environment_resource.ambient_light_energy = 0.78
	_environment_resource.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = _environment_resource
	_world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	key.light_color = Color("FFF0D2")
	key.light_energy = 1.65
	key.shadow_enabled = false
	_world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18.0, 148.0, 0.0)
	rim.light_color = Color("BCD5E8")
	rim.light_energy = 0.78
	rim.shadow_enabled = false
	_world.add_child(rim)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = float((_config.get("camera", {}) as Dictionary).get("fov_degrees", 30.0))
	_world.add_child(_camera)


func _render_weapon(weapon_id: String) -> void:
	var showcase := Node3D.new()
	var extracted_item: Node3D
	showcase.name = "%sIconModel" % weapon_id.to_pascal_case()
	_world.add_child(showcase)
	if weapon_id == "sword_shield":
		var material_character := await _new_preview_character()
		material_character.call("debug_set_equipment_preview", weapon_id, true)
		for _frame in 3:
			await process_frame
		var material_source := material_character.find_child("Sword", true, false) as Node3D
		var palette_material: Material
		if material_source != null:
			var source_meshes := material_source.find_children("*", "MeshInstance3D", true, false)
			var source_mesh := source_meshes[0] as MeshInstance3D if not source_meshes.is_empty() else null
			if source_mesh != null:
				palette_material = source_mesh.get_active_material(0)
		for source in [{"name": "Sword", "path": SWORD_SCENE}, {"name": "Shield", "path": SHIELD_SCENE}]:
			var packed := load(str(source["path"])) as PackedScene
			var item := packed.instantiate() as Node3D if packed != null else null
			if item == null:
				continue
			item.name = str(source["name"])
			showcase.add_child(item)
			if palette_material != null:
				_apply_material_recursive(item, palette_material)
			_arrange_weapon_part(weapon_id, item.name, item)
		material_character.queue_free()
	else:
		var character := await _new_preview_character()
		character.call("debug_set_equipment_preview", weapon_id, true)
		character.call("debug_force_animation_state", "idle")
		for _frame in 4:
			await process_frame
		var item := character.find_child(weapon_id.to_pascal_case(), true, false) as Node3D
		if item != null:
			item.reparent(showcase, false)
			item.visible = true
			item.scale = Vector3.ONE
			extracted_item = item
		character.queue_free()
	await process_frame
	# The character wrapper still owns the extracted preview node until its
	# deferred free completes and may write one final held pose. Arrange only
	# after that frame so the studio transform remains authoritative.
	if extracted_item != null:
		_arrange_weapon_part(weapon_id, extracted_item.name, extracted_item)
		await process_frame
	await _capture_model(showcase, "weapon", "%s/weapon/%s.png" % [OUTPUT_ROOT, weapon_id], false)
	showcase.queue_free()
	await process_frame


func _arrange_weapon_part(weapon_id: String, node_name: String, item: Node3D) -> void:
	item.position = Vector3.ZERO
	match weapon_id:
		"sword_shield":
			if node_name == "Sword":
				item.position = Vector3(-0.34, 0.03, 0.18)
				item.rotation_degrees = Vector3(8.0, -18.0, -38.0)
			else:
				item.position = Vector3(0.30, -0.18, -0.05)
				var toward_camera := Vector3(1.0, 0.42, -1.0).normalized()
				item.basis = Basis.looking_at(-toward_camera, Vector3.UP)
		"polearm":
			item.rotation_degrees = Vector3(6.0, -16.0, -52.0)
		"bow":
			# Keep the long limb vertical. The procedural string sits at local -Z,
			# so local +Z points screen-right and places the string on the left.
			var bow_screen_depth := Vector3(-1.0, 0.0, -1.0).normalized()
			item.basis = Basis(Vector3.UP.cross(bow_screen_depth), Vector3.UP, bow_screen_depth)
		"crossbow":
			item.rotation_degrees = Vector3(58.0, 0.0, -28.0)


func _render_armor(slot: String) -> void:
	var character := await _new_preview_character()
	character.call("debug_set_armor_preview", {slot: ARMOR_IDS[slot]}, true)
	character.call("debug_force_animation_state", "idle")
	for _frame in 5:
		await process_frame
	var armor_node := character.find_child(str(ARMOR_NODE_NAMES[slot]), true, false) as MeshInstance3D
	for raw_mesh in character.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		mesh_instance.visible = mesh_instance == armor_node
	await _capture_model(character, "armor", "%s/armor/%s.png" % [OUTPUT_ROOT, str(ARMOR_IDS[slot])], true)
	character.queue_free()
	await process_frame


func _render_horse(template: Dictionary) -> void:
	var packed := load(HORSE_SCENE) as PackedScene
	var horse := packed.instantiate() as Node3D if packed != null else null
	if horse == null:
		push_error("Horse icon source unavailable")
		return
	_world.add_child(horse)
	# The source horse faces local +Z; turn it toward the -Z side of the
	# three-quarter studio camera so the head, not the rump, is nearest.
	horse.rotation_degrees.y = 180.0
	HORSE_APPEARANCE.apply_coat_color(horse, str(template.get("coat_color", "#9B6846")))
	var animation_player := horse.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player != null and animation_player.has_animation("Idle"):
		animation_player.play("Idle")
		animation_player.seek(0.2, true)
	for _frame in 3:
		await process_frame
	await _capture_model(horse, "horse", "%s/horse/%s.png" % [OUTPUT_ROOT, str(template.get("template_id", "horse"))], false)
	horse.queue_free()
	await process_frame


func _render_defense_device(device_id: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	var device := packed.instantiate() as Node3D if packed != null else null
	if device == null:
		push_error("Defense device icon source unavailable: %s" % scene_path)
		return
	_world.add_child(device)
	for _frame in 6:
		await process_frame
	await _capture_model(device, "defense_device", "%s/defense_device/%s.png" % [OUTPUT_ROOT, device_id], false)
	device.queue_free()
	await process_frame


func _new_preview_character() -> Node3D:
	var packed := load(TOMA_SCENE) as PackedScene
	var character := packed.instantiate() as Node3D
	_world.add_child(character)
	for _frame in 8:
		await process_frame
	return character


func _capture_model(model: Node3D, category: String, output_path: String, front_view: bool) -> void:
	_environment_resource.background_color = Color(str((_config.get("background_colors", {}) as Dictionary).get(category, "#404040")))
	var bounds := _combined_mesh_bounds(model)
	if bounds.size.length_squared() <= 0.0001:
		push_error("No visible geometry for %s" % output_path)
		return
	var camera_config := _config.get("camera", {}) as Dictionary
	var direction_data := camera_config.get("front_direction" if front_view else "three_quarter_direction", {}) as Dictionary
	var direction := Vector3(float(direction_data.get("x", 0.0)), float(direction_data.get("y", 0.0)), float(direction_data.get("z", -1.0))).normalized()
	var center := bounds.get_center()
	var radius := bounds.size.length() * 0.5
	var distance_multiplier := float((_config.get("distance_multipliers", {}) as Dictionary).get(category, 1.0))
	if output_path.ends_with("/sword_shield.png"):
		distance_multiplier *= 1.25
	elif output_path.ends_with("/bow.png"):
		distance_multiplier *= 1.25
	var distance := radius / tan(deg_to_rad(_camera.fov * 0.5)) * float(camera_config.get("frame_padding", 1.16)) * distance_multiplier
	_camera.global_position = center + direction * maxf(distance, 1.0)
	_camera.look_at(center, Vector3.UP)
	for _frame in 8:
		await process_frame
	var viewport_image := root.get_texture().get_image()
	var square_size := mini(viewport_image.get_width(), viewport_image.get_height())
	var crop_origin := Vector2i(
		(viewport_image.get_width() - square_size) / 2,
		(viewport_image.get_height() - square_size) / 2
	)
	var image := Image.create(square_size, square_size, false, viewport_image.get_format())
	image.blit_rect(viewport_image, Rect2i(crop_origin, Vector2i(square_size, square_size)), Vector2i.ZERO)
	var configured_size := int(_config.get("size", 512))
	if square_size != configured_size:
		image.resize(configured_size, configured_size, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(output_path))
	_generated_paths.append(output_path)


func _combined_mesh_bounds(model: Node3D) -> AABB:
	var has_bounds := false
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for raw_mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var local_bounds := _tight_mesh_bounds(mesh_instance.mesh)
		for x in [local_bounds.position.x, local_bounds.end.x]:
			for y in [local_bounds.position.y, local_bounds.end.y]:
				for z in [local_bounds.position.z, local_bounds.end.z]:
					var point := mesh_instance.global_transform * Vector3(x, y, z)
					minimum = minimum.min(point)
					maximum = maximum.max(point)
					has_bounds = true
	return AABB(minimum, maximum - minimum) if has_bounds else AABB()


func _tight_mesh_bounds(mesh: Mesh) -> AABB:
	var has_bounds := false
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if vertices.is_empty():
			continue
		if indices.is_empty():
			for vertex in vertices:
				minimum = minimum.min(vertex)
				maximum = maximum.max(vertex)
				has_bounds = true
		else:
			for vertex_index in indices:
				if vertex_index < 0 or vertex_index >= vertices.size():
					continue
				minimum = minimum.min(vertices[vertex_index])
				maximum = maximum.max(vertices[vertex_index])
				has_bounds = true
	return AABB(minimum, maximum - minimum) if has_bounds else mesh.get_aabb()


func _apply_material_recursive(root_node: Node3D, material: Material) -> void:
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(surface_index, material)


func _build_contact_sheet() -> void:
	if _generated_paths.is_empty():
		return
	var tile_size := 192
	var columns := 6
	var rows := ceili(float(_generated_paths.size()) / columns)
	var sheet := Image.create(columns * tile_size, rows * tile_size, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("171B1A"))
	for index in _generated_paths.size():
		var icon := Image.load_from_file(ProjectSettings.globalize_path(_generated_paths[index]))
		if icon == null or icon.is_empty():
			continue
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(tile_size, tile_size, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(index % columns, index / columns) * tile_size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	sheet.save_png(ProjectSettings.globalize_path("res://artifacts/visual_qa/item_icons_contact_sheet.png"))


func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
