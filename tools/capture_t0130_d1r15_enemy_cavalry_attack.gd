extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"


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
	lab.call("debug_select_unit", "enemy:raider_cavalry")
	for _frame in 24:
		await process_frame
	lab.call("debug_trigger_action", "attack")
	for _frame in 4:
		await process_frame
	var player := lab.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_error("Mounted cavalry PilotAnimationPlayer is missing")
		quit(1)
		return
	var animation := player.get_animation("Mounted_1H_Attack")
	if animation == null:
		push_error("Mounted_1H_Attack is missing")
		quit(1)
		return
	for phase in [0.0, 0.25, 0.50, 0.75]:
		player.seek(animation.length * float(phase), true)
		for _frame in 3:
			await process_frame
		var snapshot: Dictionary = lab.call("debug_get_snapshot")
		var character: Dictionary = snapshot.get("character", {})
		print("enemy_cavalry_phase=%.2f grip_distance=%.6f grip=%s hand=%s lower_arm=%s local=%s rotation=%s" % [
			phase,
			float(character.get("sword_grip_hand_distance", -1.0)),
			str(character.get("sword_grip_global_position", Vector3.ZERO)),
			str(character.get("right_hand_global_position", Vector3.ZERO)),
			str(character.get("right_lower_arm_global_position", Vector3.ZERO)),
			str(character.get("sword_local_position", Vector3.ZERO)),
			str(character.get("sword_local_rotation_degrees", Vector3.ZERO)),
		])
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(
			"%s/enemy_cavalry_attack_%02d.png" % [OUTPUT_DIR, int(round(float(phase) * 100.0))]
		))
	lab.call("debug_select_unit", "stableman_01")
	for _frame in 12:
		await process_frame
	lab.call("debug_equip", "main_weapon", "sword_shield")
	lab.call("debug_trigger_action", "idle")
	for _frame in 12:
		await process_frame
	lab.call("debug_equip", "mount", "horse_chestnut_wind")
	lab.call("debug_trigger_action", "attack")
	for _frame in 4:
		await process_frame
	var friendly_player := lab.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer
	var friendly_animation := friendly_player.get_animation("Mounted_1H_Attack") if friendly_player != null else null
	if friendly_animation != null:
		friendly_player.seek(friendly_animation.length * 0.25, true)
		for _frame in 3:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(
			"%s/friendly_cavalry_attack_25.png" % OUTPUT_DIR
		))
	var friendly_snapshot: Dictionary = lab.call("debug_get_snapshot")
	var friendly_character: Dictionary = friendly_snapshot.get("character", {})
	print("friendly_cavalry grip_distance=%.6f grip=%s hand=%s lower_arm=%s local=%s rotation=%s" % [
		float(friendly_character.get("sword_grip_hand_distance", -1.0)),
		str(friendly_character.get("sword_grip_global_position", Vector3.ZERO)),
		str(friendly_character.get("right_hand_global_position", Vector3.ZERO)),
		str(friendly_character.get("right_lower_arm_global_position", Vector3.ZERO)),
		str(friendly_character.get("sword_local_position", Vector3.ZERO)),
		str(friendly_character.get("sword_local_rotation_degrees", Vector3.ZERO)),
	])
	quit(0)
