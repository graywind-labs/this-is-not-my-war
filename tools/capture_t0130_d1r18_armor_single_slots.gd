extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://scenes/debug/NPCDevLab.tscn") as PackedScene
	var lab := packed.instantiate() if packed != null else null
	if lab == null:
		push_error("NPCDevLab could not be loaded")
		quit(1)
		return
	root.add_child(lab)
	for _frame in 24:
		await process_frame
	lab.call("debug_select_unit", "stableman_01")
	lab.call("debug_set_mode", "combat")
	for slot in ["helmet", "chest", "bracers", "greaves"]:
		lab.call("debug_unequip", slot)
	await _capture("armor_none.png")
	lab.call("debug_equip", "helmet", "iron_helmet")
	await _capture("armor_helmet_only.png")
	lab.call("debug_unequip", "helmet")
	lab.call("debug_equip", "chest", "mail_chest")
	await _capture("armor_chest_only.png")
	lab.call("debug_equip", "helmet", "iron_helmet")
	await _capture("armor_helmet_chest.png")
	lab.call("debug_unequip", "helmet")
	lab.call("debug_unequip", "chest")
	lab.call("debug_equip", "bracers", "iron_bracers")
	await _capture("armor_bracers_only.png")
	lab.call("debug_equip", "chest", "mail_chest")
	await _capture("armor_chest_bracers.png")
	lab.call("debug_begin_rotation_drag")
	lab.call("debug_drag_rotation", 473.6842)
	lab.call("debug_end_rotation_drag")
	await _capture("armor_chest_bracers_back.png")
	await _capture("armor_chest_bracers_back_later.png")
	lab.call("debug_unequip", "chest")
	await _capture("armor_bracers_only_back.png")
	lab.call("debug_unequip", "bracers")
	lab.call("debug_equip", "chest", "mail_chest")
	await _capture("armor_chest_only_back.png")
	quit(0)


func _capture(file_name: String) -> void:
	for _frame in 10:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
