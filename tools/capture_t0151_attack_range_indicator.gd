extends SceneTree

const OUTPUT_PATH := "res://artifacts/visual_qa/t0151_npc_attack_range_indicator.png"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var npc_actor := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	var indicator := root.get_node_or_null("Main/WorldRoot/Station/Effects/AttackRangeIndicator")
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if [npc_system, equipment_system, npc_actor, indicator, rig, camera].has(null):
		push_error("T0151 capture dependencies unavailable")
		quit(1)
		return
	npc_system.set_npc_equipment_slot("stableman_01", "main_weapon", equipment_system.get_weapon_def("bow"))
	npc_system.update_npc_state("stableman_01", {
		"behavior_mode": "combat",
		"combat_mode": "combat",
		"hp": 100,
		"max_hp": 100,
		"unconscious": false,
		"escaped": false
	})
	npc_system.debug_select_npc("stableman_01")
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = npc_actor.global_position + Vector3(0.0, 19.0, 17.0)
	camera.look_at(npc_actor.global_position, Vector3.UP)
	camera.fov = 58.0
	camera.current = true
	for _frame in range(24):
		await process_frame
	var snapshot: Dictionary = indicator.get_debug_snapshot()
	if not bool(snapshot.get("visible", false)):
		push_error("T0151 range indicator was not visible for capture")
		quit(1)
		return
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("T0151 attack range indicator capture written")
	quit(0)
