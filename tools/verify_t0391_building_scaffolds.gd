extends SceneTree

const OUT := "res://artifacts/visual_qa/t0391/"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	main.get_node("Systems/GameStartupSystem").startup_mode = 0
	root.add_child(main)
	current_scene = main
	for i in 25:
		await process_frame
	main.get_node("Systems").process_mode = Node.PROCESS_MODE_DISABLED
	var system = main.get_node("Systems/BuildingSystem")
	var resources = main.get_node("Systems/ResourceSystem")
	var scaffolds := {}
	for scaffold in get_nodes_in_group("building_scaffold"):
		check(not scaffolds.has(scaffold.building_id), "Unique scaffold: " + scaffold.building_id)
		scaffolds[scaffold.building_id] = scaffold
	check(scaffolds.size() == 15, "All 15 building profiles installed")
	for id: String in system.get_building_ids():
		if not scaffolds.has(id):
			check(false, "Missing scaffold: " + id)
			continue
		var art: Node3D = scaffolds[id]
		check(not art.visible and art.get_child_count() == 0, id + " initially absent")
		refill(resources)
		check(system.debug_damage_building(id, 5), id + " damaged for repair")
		check(system.repair_building(id), id + " repair begins")
		check(art.visible and art.get_child_count() > 0, id + " repair scaffold immediate")
		check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), id + " no collision")
		var count := art.get_child_count()
		system._on_logical_time_tick(0.01, 1.0)
		check(art.get_child_count() == count, id + " tick does not duplicate meshes")
		check(system.debug_damage_building(id, 1), id + " repair interrupted by hit")
		check(not art.visible and art.get_child_count() == 0, id + " repair interrupted removes art")
		check(system.repair_building(id), id + " repair restarts")
		system._on_logical_time_tick(100000, 1)
		check(not art.visible and art.get_child_count() == 0, id + " repair completion removes art")
		check(system.upgrade_building(id), id + " upgrade begins")
		check(art.visible, id + " upgrade scaffold immediate")
		check(system.debug_damage_building(id, 1), id + " upgrade interrupted by hit")
		check(not art.visible and art.get_child_count() == 0, id + " upgrade interrupted removes art")
		check(system.repair_building(id), id + " repair before upgrade")
		system._on_logical_time_tick(100000, 1)
		refill(resources)
		check(system.upgrade_building(id), id + " upgrade restarts")
		if "--capture" in OS.get_cmdline_user_args():
			await capture(main, art, id)
		system._on_logical_time_tick(100000, 1)
		check(not art.visible and art.get_child_count() == 0, id + " upgrade completion removes art")
		check(system.get_building(id).level == 2, id + " level authority preserved")
		var building: Dictionary = system.get_building(id)
		var max_level := int(building.get("upgrade", {}).get("max_level", 3))
		for level in range(3, max_level + 1):
			refill(resources)
			check(system.upgrade_building(id), id + " higher-level upgrade " + str(level))
			check(art.visible, id + " higher-level scaffold")
			system._on_logical_time_tick(100000, 1)
			check(not art.visible, id + " higher-level completion")
		refill(resources)
		check(system.debug_damage_building(id, 5) and system.repair_building(id), id + " maximum-level repair")
		check(art.visible, id + " maximum-level scaffold")
		if "--capture" in OS.get_cmdline_user_args():
			await capture(main, art, id + "_max")
		system._on_logical_time_tick(100000, 1)
		check(not art.visible, id + " maximum-level repair completed")
		await process_frame
	print("T0391_PASS all 15 buildings: repair/upgrade start, finish, hit interruption, restart, unique geometry" if failures.is_empty() else "T0391_FAIL " + str(failures))
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func refill(resources: Node) -> void:
	for id in ["stone", "wood", "iron", "money"]:
		var capacity: int = resources.get_resource_capacity(id)
		var target := capacity if capacity >= 0 else 10000
		check(resources.add_resource(id, maxi(0, target - int(resources.get_resource(id)))), "Resource fixture refill " + id)

func capture(main: Node, art: Node3D, id: String) -> void:
	if art.get_child_count() == 0:
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1100, 760)
	main.get_node("UI").hide()
	main.get_node("Systems/TimeSystem").set_current_time(1, 12, 0, 0)
	var rig: Node3D = main.get_node("CameraRig")
	rig.set_process(false)
	var camera: Camera3D = rig.get_node("Camera3D")
	var section: Node3D = art.get_child(0)
	var target := section.global_position + Vector3(0, 1.4, 0)
	for view in [["front", Vector3(9, 10, 18)], ["side", Vector3(-17, 8, 9)]]:
		camera.global_position = target + section.global_basis * view[1]
		camera.look_at(target)
		for i in 8:
			await process_frame
		for popup: Window in main.find_children("*", "Window", true, false):
			popup.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + id + "_" + view[0] + ".png")
