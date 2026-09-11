extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _index in 8:
		await process_frame
		await physics_frame
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if rig == null or camera == null or building_system == null or device_system == null or resource_system == null:
		quit(1)
		return
	if ui != null:
		ui.visible = false
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var buildings: Dictionary = building_system.get("_buildings")
	var wall: Dictionary = buildings.get("wall", {})
	wall["level"] = 2
	buildings["wall"] = wall
	building_system.set("_buildings", buildings)
	resource_system.add_resource("item_wall_ballista", 1)
	resource_system.add_resource("item_wall_arrow_tower", 1)
	var ballista: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	var arrow: Dictionary = device_system.deploy_device("wall_arrow_tower", "wall_slot_02")
	device_system.apply_damage_to_device(str(ballista.get("deployment_id", "")), 9999)
	device_system.apply_damage_to_device(str(arrow.get("deployment_id", "")), 9999)
	await process_frame
	await _capture_target(rig, camera, Vector3(5.0, 2.8, 54.0), 20.0, 34.0, "t0157_device_and_gate_ruins.png")

	var front_gate: Dictionary = building_system.get_building("front_gate")
	building_system.apply_damage_to_building("front_gate", int(front_gate.get("hp", 0)), "t0157_capture")
	for _index in 50:
		await physics_frame
	await _capture_target(rig, camera, Vector3(5.0, 2.0, 54.0), 18.0, 28.0, "t0157_front_gate_collapsed.png")

	var warehouse: Dictionary = building_system.get_building("warehouse")
	building_system.apply_damage_to_building("warehouse", int(warehouse.get("hp", 0)), "t0157_capture")
	await process_frame
	var warehouse_art := root.get_node("Main/WorldRoot/FormalStationLayout/BuildingRoots/Warehouse/WarehouseArt") as Node3D
	await _capture_target(rig, camera, warehouse_art.global_position + Vector3.UP * 1.4, 25.0, 42.0, "t0157_warehouse_ruin.png")

	var main_hall: Dictionary = building_system.get_building("main_hall")
	building_system.apply_damage_to_building("main_hall", int(main_hall.get("hp", 0)), "t0157_capture")
	await process_frame
	var main_hall_art := root.get_node("Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt") as Node3D
	await _capture_target(rig, camera, main_hall_art.global_position + Vector3.UP * 1.6, 32.0, 46.0, "t0157_main_hall_ruin.png")
	print("T0157 destruction captures written to %s" % OUTPUT_DIR)
	quit(0)


func _capture_target(rig: Node3D, camera: Camera3D, target: Vector3, distance: float, pitch_degrees: float, filename: String) -> void:
	rig.global_position = target
	var yaw := deg_to_rad(32.0)
	var pitch := deg_to_rad(pitch_degrees)
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	camera.position = direction * distance
	camera.look_at(target, Vector3.UP)
	camera.fov = 40.0
	camera.current = true
	for _index in 12:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
