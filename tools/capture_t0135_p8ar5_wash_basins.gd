extends SceneTree


const DORMITORY_OUTPUT := "res://artifacts/visual_qa/t0135_p8ar5_dormitory_wash_basin.png"
const CLINIC_OUTPUT := "res://artifacts/visual_qa/t0135_p8ar5_clinic_wash_basin.png"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame
	var dormitory_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory/DormitoryArt") as Node3D
	var clinic_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Clinic/ClinicArt") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if dormitory_art == null or clinic_art == null or camera == null:
		push_error("P8AR5 capture dependencies unavailable")
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
	camera.current = true
	camera.fov = 34.0

	dormitory_art.call("debug_force_visual_level", 2)
	dormitory_art.call("apply_roof_camera_distance", 54.0, 0.0)
	_place_camera(camera, dormitory_art, Vector3(-1.2, 12.5, 7.6), Vector3(-0.8, 0.9, -3.6))
	await _settle_frames(48)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(DORMITORY_OUTPUT))

	clinic_art.call("debug_force_visual_level", 1)
	clinic_art.call("apply_roof_camera_distance", 54.0, 0.0)
	_place_camera(camera, clinic_art, Vector3(0.0, 11.5, 7.4), Vector3(0.0, 0.95, -3.9))
	await _settle_frames(48)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CLINIC_OUTPUT))
	print("T0135-P8AR5 wash basin captures written")
	quit(0)


func _place_camera(camera: Camera3D, art: Node3D, local_position: Vector3, local_target: Vector3) -> void:
	camera.global_position = art.to_global(local_position)
	camera.look_at(art.to_global(local_target), art.global_basis.y.normalized())


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
