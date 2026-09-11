extends SceneTree


const OUTPUT_PATH := "res://artifacts/visual_qa/t0135_p8ar4_dining_kitchen_active.png"
const CHIMNEY_OUTPUT_PATH := "res://artifacts/visual_qa/t0135_p8ar4_dining_chimney_hollow.png"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame
	var art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall/DiningHallArt") as Node3D
	var bruno := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01") as CharacterBody3D
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if [art, bruno, action_system, npc_system, resource_system, time_system, rig, camera].has(null):
		push_error("P8AR4 capture dependencies unavailable")
		quit(1)
		return
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var fade_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController")
	if fade_controller != null:
		fade_controller.process_mode = Node.PROCESS_MODE_DISABLED
	art.call("debug_force_visual_level", 1)
	art.call("apply_roof_camera_distance", 54.0, 0.0)
	time_system.call("set_paused", false)
	bruno.set("move_speed", 40.0)
	resource_system.call("add_resource", "grain", 10)
	npc_system.call("update_npc_state", "cook_01", {"fatigue": 0, "satiety": 100, "current_action": "idle"})
	if not bool(action_system.call("debug_assign_work", "cook_01", "dining_hall")):
		push_error("Could not dispatch Bruno for P8AR4 capture")
		quit(1)
		return
	for frame in range(1800):
		await physics_frame
		var runtime := action_system.call("get_runtime_action_snapshot", "cook_01") as Dictionary
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == "work_dining_hall":
			break
		if frame == 1799:
			push_error("Bruno did not reach the dining station for capture")
			quit(1)
			return
	var center := art.global_position
	rig.global_position = Vector3(center.x, 0.0, center.z)
	rig.rotation = Vector3.ZERO
	camera.global_position = art.to_global(Vector3(0.0, 15.0, -15.0))
	camera.look_at(art.to_global(Vector3(-1.0, 1.2, -3.4)), Vector3.UP)
	camera.fov = 38.0
	camera.current = true
	for _frame in range(120):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	art.call("debug_force_visual_level", 2)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	camera.global_position = art.to_global(Vector3(0.0, 12.5, -8.5))
	camera.look_at(art.to_global(Vector3(0.0, 5.65, -4.75)), Vector3.UP)
	camera.fov = 31.0
	for _frame in range(36):
		await process_frame
	var chimney_image := root.get_texture().get_image()
	chimney_image.save_png(ProjectSettings.globalize_path(CHIMNEY_OUTPUT_PATH))
	print("T0135-P8AR4 dining kitchen capture written")
	quit(0)
