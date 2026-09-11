extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"
const FRIENDLY_IDS := [
	"stableman_01", "cook_01", "gardener_01", "blacksmith_01",
	"veteran_deputy_01", "priest_01", "doctor_01", "engineer_01",
]


func _init() -> void:
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://scenes/debug/NPCDevLab.tscn") as PackedScene
	if packed == null:
		push_error("NPCDevLab.tscn could not be loaded")
		quit(1)
		return
	var lab := packed.instantiate()
	root.add_child(lab)
	for _frame in 24:
		await process_frame

	# Establish the shared friendly loadout, leave it active while viewing an enemy,
	# then return directly to a friendly rider and attack without manually priming idle.
	lab.call("debug_select_unit", "stableman_01")
	lab.call("debug_equip", "main_weapon", "sword_shield")
	lab.call("debug_equip", "mount", "horse_chestnut_wind")
	for _frame in 8:
		await process_frame
	lab.call("debug_select_unit", "enemy:raider_cavalry")
	lab.call("debug_trigger_action", "attack")
	for _frame in 18:
		await process_frame
	for friendly_id in FRIENDLY_IDS:
		lab.call("debug_select_unit", friendly_id)
		lab.call("debug_trigger_action", "attack")
		for _frame in 4:
			await process_frame
		var player := lab.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer
		var animation := player.get_animation("Mounted_1H_Attack") if player != null else null
		if animation == null:
			push_error("Friendly Mounted_1H_Attack is missing for %s" % friendly_id)
			quit(1)
			return
		player.seek(animation.length * 0.25, true)
		for _frame in 3:
			await process_frame
		var snapshot: Dictionary = lab.call("debug_get_snapshot")
		var character: Dictionary = snapshot.get("character", {})
		print("friendly_return=%s foot_cache=%s mounted_cache=%s grip_distance=%.6f grip=%s hand=%s local=%s rotation=%s" % [
			friendly_id,
			str(character.get("foot_sword_attack_attachment_valid", false)),
			str(character.get("mounted_sword_attack_attachment_valid", false)),
			float(character.get("sword_grip_hand_distance", -1.0)),
			str(character.get("sword_grip_global_position", Vector3.ZERO)),
			str(character.get("right_hand_global_position", Vector3.ZERO)),
			str(character.get("sword_local_position", Vector3.ZERO)),
			str(character.get("sword_local_rotation_degrees", Vector3.ZERO)),
		])
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(
			"%s/friendly_return_attack_%s.png" % [OUTPUT_DIR, friendly_id]
		))
	quit(0)
