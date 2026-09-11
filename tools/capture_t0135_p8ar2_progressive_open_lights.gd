extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"
const OPEN_AREAS := {
	"garden": {"target": Vector3(-42.0, 0.0, 10.0), "yaw": 90.0},
	"training_ground": {"target": Vector3(-15.0, 0.0, 36.0), "yaw": 180.0},
	"stable": {"target": Vector3(31.0, 0.0, -23.0), "yaw": -45.0},
}


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(20):
		await process_frame
		await physics_frame
	var time_system := root.get_node("Main/Systems/TimeSystem")
	var npc_system := root.get_node("Main/Systems/NPCSystem")
	var controller := root.get_node("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView/BuildingFunctionalLightController")
	time_system.call("set_paused", true)
	time_system.call("set_current_time", 3, 0, 30, 0)
	var assignments := {
		"gardener_01": "garden",
		"veteran_deputy_01": "training_ground",
		"stableman_01": "stable",
	}
	for npc_id in assignments:
		var building_id := str(assignments[npc_id])
		npc_system.call("update_npc_state", npc_id, {
			"current_location": building_id,
			"current_location_name": building_id,
			"current_action": "idle",
		})
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var formal_root := root.get_node("Main/WorldRoot/FormalStationLayout") as Node3D
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	for building_id in OPEN_AREAS:
		var host := _formal_art_host(building_id)
		if host != null:
			host.call("debug_force_visual_level", 3)
	controller.call("debug_force_refresh")
	await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, 9.0), 70.0, 55.0, 0.0, 62.0, "t0135_p8ar2_max_zoom_night_lights.png")
	for building_id in OPEN_AREAS:
		var host := _formal_art_host(building_id)
		var framing := OPEN_AREAS[building_id] as Dictionary
		for level in [1, 2, 3]:
			host.call("debug_force_visual_level", level)
			controller.call("debug_force_refresh")
			await _capture(
				formal_root,
				rig,
				camera,
				framing.target,
				38.0,
				55.0,
				float(framing.yaw),
				40.0,
				"t0135_p8ar2_%s_lv%d.png" % [building_id, level]
			)
	print("T0135-P8AR2 progressive open-area light captures written.")
	quit(0)


func _formal_art_host(building_id: String) -> Node3D:
	for raw_view in get_nodes_in_group("building_art_view"):
		var view := raw_view as Node3D
		if view != null and str(view.get("building_id")) == building_id and str(view.get_path()).contains("/FormalStationLayout/"):
			return view
	return null


func _capture(formal_root: Node3D, rig: Node3D, camera: Camera3D, target: Vector3, distance: float, pitch: float, yaw: float, fov: float, filename: String) -> void:
	rig.global_position = formal_root.global_position + target
	var pitch_radians := deg_to_rad(pitch)
	var yaw_radians := deg_to_rad(yaw)
	var direction := Vector3(sin(yaw_radians) * cos(pitch_radians), sin(pitch_radians), cos(yaw_radians) * cos(pitch_radians)).normalized()
	camera.position = direction * distance
	camera.rotation_degrees = Vector3(-pitch, yaw, 0.0)
	camera.fov = fov
	camera.current = true
	for _frame in range(3):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
