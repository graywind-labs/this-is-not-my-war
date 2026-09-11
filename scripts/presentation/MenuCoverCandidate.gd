extends "res://scripts/presentation/MenuCoverPreview.gd"
## Presentation overrides only. The approved staging remains owned by the base scene.

const TreeMeshes := preload("res://scripts/presentation/environment/StylizedTreeMeshes.gd")
const GROUND_SHADER := preload("res://shaders/environment/menu_courtyard_trial.gdshader")
const HallFinish := preload("res://scripts/presentation/buildings/MenuMainHallFinish.gd")
var _style: Dictionary = {}

func _ready() -> void:
	_style = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/menu_cover_trial.json"))
	super._ready()
	_configure_lighting()
	_build_fog_banks()
	call_deferred("_finish_ground")
	call_deferred("_finish_main_hall")

func _finish_main_hall() -> void:
	HallFinish.install(set_root.get_node("MainHallHero"))
	_build_cover_ballista()

func _build_cover_ballista() -> void:
	var settings: Dictionary = _style.get("defense_display", {})
	var fixture := _get_fixture("main_hall", str(settings.get("fixture_id", "main_hall_slot_03_platform")))
	if fixture.is_empty():
		return
	var hall := set_root.get_node("MainHallHero") as Node3D
	var display := Node3D.new()
	display.name = "CoverDefenseDisplay"
	display.set_meta("presentation_only", true)
	display.set_meta("source_fixture", fixture.id)
	hall.add_child(display)
	display.position = _fixture_vector3(settings.get("offset", [0.0, 0.0, 0.0]))
	var center: Array = fixture.get("center", [-7.0, 5.0])
	var platform := (load(str(fixture.asset_path)) as PackedScene).instantiate() as Node3D
	platform.name = "LevelOnePlatform"
	platform.position = Vector3(float(center[0]), float(fixture.get("visual_y", 3.05)), float(center[1]))
	platform.rotation_degrees.y = float(fixture.get("rotation_degrees", 180.0))
	platform.scale = _fixture_vector3(fixture.get("visual_scale", [1.0, 1.0, 1.0]))
	display.add_child(platform)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_device_defs.json"))
	for definition in definitions.get("devices", []):
		if str(definition.get("id", "")) != str(settings.get("device_id", "wall_ballista")):
			continue
		var visual_path := str(definition.get("presentation", {}).get("model_scene", ""))
		var ballista := (load(visual_path) as PackedScene).instantiate() as Node3D
		ballista.name = "LoadedBallista"
		ballista.position = Vector3(float(center[0]), float(fixture.get("device_anchor_y", 3.93)), float(center[1]))
		# The source model fires along local +Z, over the front courtyard approach.
		ballista.rotation_degrees.y = float(settings.get("yaw_degrees", 0.0))
		display.add_child(ballista)
		break
	var accent := SpotLight3D.new()
	accent.name = "BallistaSoftLight"
	accent.position = Vector3(-8.0, 8.0, 12.0)
	accent.light_color = Color("#dfd0b4")
	accent.light_energy = 3.2
	accent.spot_range = 14.0
	accent.spot_angle = 26.0
	accent.light_volumetric_fog_energy = 0.0
	display.add_child(accent)
	accent.look_at(display.to_global(Vector3(float(center[0]),5.0,float(center[1]))))

func _configure_lighting() -> void:
	# Environment is a shared inherited resource: duplicate before touching any field.
	var env := ($WorldEnvironment as WorldEnvironment).environment.duplicate(true) as Environment
	($WorldEnvironment as WorldEnvironment).environment = env
	env.ambient_light_color = Color("#92a6bc")
	env.ambient_light_energy = float(_style.get("ambient_energy", 0.48))
	env.fog_density = float(_style.get("fog_density", 0.0015))
	env.fog_light_color = Color("#405367")
	env.fog_sky_affect = 0.2
	env.background_color = Color("#141e2e")
	env.volumetric_fog_density = float(_style.get("volume_density", 0.0018))
	env.volumetric_fog_albedo = Color("#748494")
	env.volumetric_fog_emission = Color.BLACK
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.35
	$MoonKey.light_energy = float(_style.get("moon_energy", 0.9))
	$MoonKey.light_color = Color("#91b1d4")
	$WarmRim.light_energy = float(_style.get("warm_rim_energy", 0.16))
	$CourtyardKey.position = Vector3(8.2, 5.3, 7.5)
	$CourtyardKey.light_color = Color("#ffe0a7")
	$CourtyardKey.light_energy = float(_style.get("courtyard_energy", 2.8))
	$CourtyardKey.omni_range = float(_style.get("courtyard_range", 11.0))
	$CourtyardKey.light_volumetric_fog_energy = 0.15
	for light in set_root.find_children("*", "OmniLight3D", true, false):
		light.light_volumetric_fog_energy = 0.18
		if str(light.name).begins_with("EnemyFireGlow"):
			light.omni_range = 3.6
			light.light_energy = 0.8
		elif str(light.name) == "WarmLight":
			light.omni_range = 7.0
			light.light_energy *= 0.65
			light.light_color = Color("#ffc77d")
	var fill := SpotLight3D.new()
	fill.name = "WorkersSoftKey"
	fill.position = Vector3(7, 8, 12)
	fill.light_color = Color("#ffe9c6")
	fill.light_energy = 3.0
	fill.spot_range = 18
	fill.spot_angle = 38
	fill.spot_angle_attenuation = 0.7
	fill.light_volumetric_fog_energy = 0.0
	fill.shadow_enabled = true
	add_child(fill)
	fill.look_at(Vector3(9, 0.8, 3.5))

func _build_fog_banks() -> void:
	var banks := Node3D.new()
	banks.name = "LayeredForestMist"
	add_child(banks)
	for entry in _style.get("fog_banks", []):
		var bank := FogVolume.new()
		bank.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		bank.position = _fixture_vector3(entry.position)
		bank.size = _fixture_vector3(entry.size)
		var material := FogMaterial.new()
		material.density = float(entry.density)
		material.albedo = Color("#6b819a")
		material.edge_fade = 0.65
		bank.material = material
		banks.add_child(bank)

func _build_tree_silhouettes() -> void:
	# Read the old tree height so the replacement preserves the authored skyline.
	var source := TREE_SCENE.instantiate() as Node3D
	var bounds := AABB()
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var transform := Transform3D.IDENTITY
		var cursor := node as Node3D
		while cursor != source:
			transform = cursor.transform * transform
			cursor = cursor.get_parent() as Node3D
		bounds = bounds.merge(transform * node.get_aabb())
	source.free()
	var trees := Node3D.new()
	trees.name = "TreeSilhouettes"
	trees.set_meta("presentation_only", true)
	set_root.add_child(trees)
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/forest_art_trial.json"))
	var builder := TreeMeshes.new(settings)
	var rng := builder.make_species_rng(Vector2(370, 0))
	for index in OUTER_TREE_LAYOUT.size():
		var entry: Dictionary = OUTER_TREE_LAYOUT[index]
		var tree := MeshInstance3D.new()
		tree.name = "Tree%02d" % (index + 1)
		var point: Vector3 = entry.position
		var variant := builder.choose_variant(Vector2(point.x, point.z), rng)
		tree.mesh = builder.meshes[variant]
		tree.position = point
		tree.rotation_degrees.y = float(entry.yaw)
		var height_ratio := bounds.size.y / tree.mesh.get_aabb().size.y
		tree.scale = Vector3.ONE * float(entry.scale) * height_ratio * float(_style.get("tree_height_factor", 1.0))
		tree.set_meta("outside_station", true)
		tree.set_meta("tree_zone", entry.zone)
		tree.set_meta("variant", variant)
		trees.add_child(tree)

func _finish_ground() -> void:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	for key in ["ground_dark", "ground_earth", "ground_worn"]:
		material.set_shader_parameter(key, Color(str(_style.get(key, "#30352c"))))
	var patches := PackedVector4Array()
	for entry in CHARACTER_LAYOUT:
		var point: Vector3 = entry.position
		patches.append(Vector4(point.x, point.z, 1.9, 1.6))
	material.set_shader_parameter("work_patches", patches)
	var contacts := PackedVector4Array()
	var groups: Array[Node] = [set_root.get_node("MainHallHero")]
	groups.append_array(set_root.get_node("ProfessionWorkstations").get_children())
	for group in groups:
		var bounds := AABB()
		var found := false
		for node in group.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			if box.position.y > 0.48 or box.end.y > 1.25:
				continue
			bounds = bounds.merge(box) if found else box
			found = true
		if found:
			var center := bounds.get_center()
			contacts.append(Vector4(center.x, center.z, bounds.size.x * 0.5, bounds.size.z * 0.5))
	material.set_shader_parameter("contact_count", contacts.size())
	contacts.resize(16)
	material.set_shader_parameter("contact_boxes", contacts)
	($Ground as MeshInstance3D).material_override = material

func get_preview_snapshot() -> Dictionary:
	var result := super.get_preview_snapshot()
	result["purpose"] = "approved_menu_cover" if _runtime_connected else "menu_cover_review"
	result["formal_menu_connected"] = _runtime_connected
	result["hall_finish"] = set_root.get_node("MainHallHero").has_node("CoverShellFinish")
	result["defense_display"] = set_root.get_node("MainHallHero").has_node("CoverDefenseDisplay/LoadedBallista")
	result["ground_color"] = _style.get("ground_dark")
	result["fog_bank_count"] = $LayeredForestMist.get_child_count()
	result["tree_style"] = "approved_t0364"
	return result

func get_edge_fog_color() -> Color:
	return Color(str(_style.get("edge_fog_color", "#515f71")))
