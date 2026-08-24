extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"
func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in 4:
		await process_frame
	# Route traversal itself is covered by the headless formal-route regression. This
	# visual capture places the production scene at the exact audited dock to avoid
	# advancing every Main simulation subscriber for the full journey under D3D12.
	var layout_controller := root.get_node("Main/Presentation/StationLayoutController")
	var route: Dictionary = layout_controller.get_formal_merchant_route_world()
	var points: Array = route.get("path_points", [])
	var dock: Vector3 = route.get("dock", Vector3.ZERO)
	var approach: Vector3 = (dock - (points[points.size() - 2] as Vector3)).normalized()
	var wagon := (load("res://scenes/world/MerchantWagon.tscn") as PackedScene).instantiate()
	wagon.name = "T0132P7DockVisual"
	root.get_node("Main/WorldRoot").add_child(wagon)
	wagon.global_position = dock
	wagon.rotation.y = atan2(-approach.x, -approach.z)
	wagon.set_trade_available(true)
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		if not wagon.is_ancestor_of(label):
			(label as Label3D).visible = false
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	var direction := camera.position.normalized()
	rig.global_position = wagon.global_position + Vector3(0.0, 0.0, 0.4)
	camera.position = direction * 25.0
	camera.fov = 36.0
	for _frame in 16:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, "t0132_p7r_merchant_wagon_formal_dock.png"]))
	print("T0132-P7R formal covered-wagon dock capture written.")
	quit(0)
