extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"
const EQUIPPED_ITEMS := {
	"main_weapon": "sword_shield",
	"helmet": "iron_helmet",
	"chest": "mail_chest",
	"bracers": "iron_bracers",
	"greaves": "iron_greaves",
	"mount": "horse_chestnut_wind",
}


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var lab := (load("res://scenes/debug/NPCDevLab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for _frame in 14:
		await process_frame
	_save("t0175_equipment_panel_empty.png")
	for slot in EQUIPPED_ITEMS:
		lab.call("debug_equip", slot, str(EQUIPPED_ITEMS[slot]))
	for _frame in 10:
		await process_frame
	_save("t0175_equipment_panel_equipped.png")
	quit(0)


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
