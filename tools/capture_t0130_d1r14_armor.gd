extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"
const ARMOR_LOADOUT := {
	"helmet": "iron_helmet",
	"chest": "mail_chest",
	"bracers": "iron_bracers",
	"greaves": "iron_greaves",
}
const CHARACTER_SCENES := {
	"toma": "res://scenes/characters/TomaChibiArtView.tscn",
	"bruno": "res://scenes/characters/BrunoChibiArtView.tscn",
	"ivo": "res://scenes/characters/IvoChibiArtView.tscn",
	"glen": "res://scenes/characters/GlenChibiArtView.tscn",
	"ada": "res://scenes/characters/AdaChibiArtView.tscn",
	"marcel": "res://scenes/characters/MarcelChibiArtView.tscn",
	"lina": "res://scenes/characters/LinaChibiArtView.tscn",
	"owen": "res://scenes/characters/OwenChibiArtView.tscn",
}


func _init() -> void:
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var world := Node3D.new()
	world.name = "ArmorVisualQA"
	root.add_child(world)
	_configure_world(world)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 31.0
	world.add_child(camera)
	for character_id in CHARACTER_SCENES:
		var character := (load(str(CHARACTER_SCENES[character_id])) as PackedScene).instantiate() as Node3D
		character.name = str(character_id).capitalize()
		world.add_child(character)
		for _frame in 10:
			await process_frame
		character.call("debug_set_equipment_preview", "", true)
		character.call("debug_set_armor_preview", ARMOR_LOADOUT, true)
		character.call("debug_force_animation_state", "idle")
		for _frame in 8:
			await process_frame
		await _capture(camera, Vector3(0.0, 1.28, -4.2), Vector3(0.0, 0.96, 0.0), "%s_armor_front.png" % character_id)
		if character_id in ["toma", "lina", "marcel"]:
			await _capture(camera, Vector3(4.2, 1.28, 0.0), Vector3(0.0, 0.96, 0.0), "%s_armor_side.png" % character_id)
			await _capture(camera, Vector3(0.0, 1.28, 4.2), Vector3(0.0, 0.96, 0.0), "%s_armor_back.png" % character_id)
		if character_id in ["lina", "marcel"]:
			character.call("debug_set_armor_preview", {"greaves": "iron_greaves"}, true)
			for _frame in 5:
				await process_frame
			await _capture(camera, Vector3(0.0, 1.28, -4.2), Vector3(0.0, 0.96, 0.0), "%s_greaves_only_front.png" % character_id)
			await _capture(camera, Vector3(4.2, 1.28, 0.0), Vector3(0.0, 0.96, 0.0), "%s_greaves_only_side.png" % character_id)
			await _capture(camera, Vector3(0.0, 1.28, 4.2), Vector3(0.0, 0.96, 0.0), "%s_greaves_only_back.png" % character_id)
		character.call("debug_set_armor_preview", {"chest": "mail_chest"}, true)
		for _frame in 5:
			await process_frame
		await _capture(camera, Vector3(0.0, 1.28, -4.2), Vector3(0.0, 1.05, 0.0), "%s_chest_only_front.png" % character_id)
		character.queue_free()
		await process_frame
	var articulation_character := (load(str(CHARACTER_SCENES["toma"])) as PackedScene).instantiate() as Node3D
	articulation_character.name = "TomaArmorArticulation"
	world.add_child(articulation_character)
	for _frame in 10:
		await process_frame
	for armor_slot in ARMOR_LOADOUT:
		articulation_character.call("debug_set_armor_preview", {armor_slot: ARMOR_LOADOUT[armor_slot]}, true)
		articulation_character.call("debug_force_animation_state", "idle")
		for _frame in 5:
			await process_frame
		await _capture(camera, Vector3(0.0, 1.28, -4.2), Vector3(0.0, 0.96, 0.0), "toma_armor_slot_%s_front.png" % armor_slot)
		await _capture(camera, Vector3(4.2, 1.28, 0.0), Vector3(0.0, 0.96, 0.0), "toma_armor_slot_%s_side.png" % armor_slot)
	articulation_character.call("debug_set_armor_preview", ARMOR_LOADOUT, true)
	articulation_character.call("debug_force_action_preview", "attack", "attack")
	for _frame in 5:
		await process_frame
	var player := articulation_character.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer
	var attack_animation := player.get_animation("Melee_1H_Attack_Slice_Horizontal") if player != null else null
	if attack_animation != null:
		for phase in [0.20, 0.50, 0.80]:
			player.seek(attack_animation.length * phase, true)
			for _frame in 3:
				await process_frame
			await _capture(camera, Vector3(0.0, 1.28, -4.2), Vector3(0.0, 0.96, 0.0), "toma_armor_attack_%02d_front.png" % int(round(phase * 100.0)))
	articulation_character.call("debug_force_action_preview", "mounted_pose", "vehicle_seated")
	for _frame in 5:
		await process_frame
	await _capture(camera, Vector3(0.0, 1.28, -4.2), Vector3(0.0, 0.96, 0.0), "toma_armor_mounted_front.png")
	await _capture(camera, Vector3(4.2, 1.28, 0.0), Vector3(0.0, 0.96, 0.0), "toma_armor_mounted_side.png")
	articulation_character.queue_free()
	print("T0130-D1R14 armor visual-QA captures written.")
	quit(0)


func _configure_world(world: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("17201d")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("dbe2d8")
	environment_resource.ambient_light_energy = 0.74
	environment.environment = environment_resource
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -28.0, 0.0)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 1.3
	ground_mesh.bottom_radius = 1.38
	ground_mesh.height = 0.10
	ground_mesh.radial_segments = 24
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("5a4835")
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.position.y = -0.05
	world.add_child(ground)


func _capture(camera: Camera3D, camera_position: Vector3, target: Vector3, file_name: String) -> void:
	camera.position = camera_position
	camera.look_at(target)
	for _frame in 8:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
