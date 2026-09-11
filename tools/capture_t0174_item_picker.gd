extends SceneTree


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var dev_lab := (load("res://scenes/debug/NPCDevLab.tscn") as PackedScene).instantiate()
	root.add_child(dev_lab)
	for _frame in 12:
		await process_frame
	dev_lab.call("_open_equipment_picker", "main_weapon")
	for _frame in 8:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/visual_qa/t0174_weapon_picker.png"))
	quit(0)
