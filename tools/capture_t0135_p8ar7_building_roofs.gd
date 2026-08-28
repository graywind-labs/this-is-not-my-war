extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const OUTPUT_DIR := "res://artifacts/visual_qa"
const BUILDING_VIEWS := [
	{
		"name": "dining_hall_gable",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall/DiningHallArt",
		"yaw": 0.0,
		"pitch": 18.0,
		"distance": 18.0,
	},
	{
		"name": "tavern_gable",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Tavern/TavernArt",
		"yaw": 135.0,
		"pitch": 18.0,
		"distance": 17.0,
	},
	{
		"name": "dormitory_gable",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory/DormitoryArt",
		"yaw": 90.0,
		"pitch": 19.0,
		"distance": 19.0,
	},
	{
		"name": "dormitory_eave",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory/DormitoryArt",
		"yaw": 0.0,
		"pitch": 19.0,
		"distance": 19.0,
	},
	{
		"name": "workshop_eave",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt",
		"yaw": 45.0,
		"pitch": 17.0,
		"distance": 18.0,
	},
	{
		"name": "workshop_gable",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt",
		"yaw": 135.0,
		"pitch": 17.0,
		"distance": 18.0,
	},
	{
		"name": "workshop_top",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt",
		"yaw": 45.0,
		"pitch": 58.0,
		"distance": 23.0,
	},
	{
		"name": "blacksmith_flat_roof",
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt",
		"yaw": 35.0,
		"pitch": 34.0,
		"distance": 19.0,
	},
]


func _init() -> void:
	var scene := load(MAIN_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	var fade_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController") as Node
	if rig == null or camera == null:
		push_error("T0135-P8AR7 capture dependencies unavailable")
		quit(1)
		return
	if ui != null:
		ui.visible = false
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	if fade_controller != null:
		fade_controller.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for view: Dictionary in BUILDING_VIEWS:
		var art := root.get_node_or_null(String(view["path"])) as Node3D
		if art == null:
			push_error("Missing art view for capture: %s" % view["path"])
			quit(1)
			return
		art.call("apply_roof_camera_distance", 70.0, 1.0)
		rig.global_position = art.global_position + Vector3(0.0, 2.5, 0.0)
		var yaw := deg_to_rad(float(view["yaw"]))
		var pitch := deg_to_rad(float(view["pitch"]))
		var direction := Vector3(
			sin(yaw) * cos(pitch),
			sin(pitch),
			cos(yaw) * cos(pitch)
		).normalized()
		camera.position = direction * float(view["distance"])
		camera.look_at(rig.global_position, Vector3.UP)
		camera.fov = 38.0
		camera.current = true
		await _settle_and_capture("t0135_p8ar7_%s.png" % view["name"])
	print("T0135-P8AR7 roof visual captures written to %s" % OUTPUT_DIR)
	quit(0)


func _settle_and_capture(file_name: String) -> void:
	for _frame in range(12):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
