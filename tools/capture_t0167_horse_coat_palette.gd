extends SceneTree


const HORSE_ASSET := "res://assets/3d/quaternius/animals/merchant_horse.glb"
const HORSE_APPEARANCE := preload("res://scripts/presentation/characters/HorseAppearance.gd")
const OUTPUT_PATH := "res://artifacts/visual_qa/t0167_horse_coat_palette.png"


func _init() -> void:
	root.size = Vector2i(1600, 900)
	DisplayServer.window_set_size(root.size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	_add_environment(scene_root)

	var defs := _load_json("res://data/horse_defs.json")
	var templates: Array = defs.get("horse_templates", [])
	var packed := load(HORSE_ASSET) as PackedScene
	if templates.size() != 24 or packed == null:
		push_error("T0167 palette capture dependencies unavailable")
		quit(1)
		return

	for index in range(templates.size()):
		var template: Dictionary = templates[index]
		var column := index % 6
		var row := index / 6
		var holder := Node3D.new()
		holder.position = Vector3((float(column) - 2.5) * 4.0, 0.0, (float(row) - 1.5) * 4.1)
		scene_root.add_child(holder)
		var horse := packed.instantiate() as Node3D
		horse.scale = Vector3(0.52, 0.42, 0.48)
		horse.rotation_degrees.y = 180.0
		holder.add_child(horse)
		HORSE_APPEARANCE.apply_coat_color(horse, str(template.get("coat_color", "")))
		var label := Label3D.new()
		label.text = "%s · %s" % [str(template.get("name", "")), str(template.get("coat_name", ""))]
		label.position = Vector3(0.0, 2.35, 0.0)
		label.font_size = 34
		label.outline_size = 8
		label.modulate = Color("#F4E7CB")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		holder.add_child(label)

	for _frame in range(32):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("T0167 horse coat palette capture written")
	quit(0)


func _add_environment(parent: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#26352D")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#D8CDBB")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	parent.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#FFF1D5")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	parent.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(27.0, 21.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#4A493E")
	material.roughness = 0.95
	plane.material = material
	ground.mesh = plane
	parent.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 44.0
	parent.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 25.5, 25.0), Vector3(0.0, 0.9, 0.0), Vector3.UP)
	camera.current = true


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
