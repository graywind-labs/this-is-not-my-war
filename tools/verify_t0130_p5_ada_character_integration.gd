extends SceneTree


const NPC_ID := "veteran_deputy_01"
const TRAINING_ACTION_ID := "work_training_instructor"
const SLEEP_ACTION_ID := "sleep_in_dormitory"

var _failures: Array[String] = []


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_failures.append("Main.tscn unavailable")
		finish()
		return
	var main := packed.instantiate()
	var startup_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if startup_plan_system != null:
		startup_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var ada := _get_npc_node(npc_system) if npc_system != null else null
	if [npc_system, action_system, equipment_system, resource_system, time_system, gm, ada].has(null):
		_failures.append("T0130-P5 runtime dependencies unavailable")
		finish()
		return

	time_system.set_paused(false)
	ada.set("move_speed", 8.0)
	npc_system.update_npc_state(NPC_ID, {
		"hp": 120,
		"unconscious": false,
		"fatigue": 80,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_t0130_p5_ready",
	})
	await process_frame

	var initial_art: Dictionary = ada.debug_get_character_art_snapshot()
	check(bool(initial_art.get("ready", false)), "Ada chibi art did not become ready")
	check(str(initial_art.get("appearance_id", "")) == "ada_veteran_deputy_chibi_v1", "Ada still uses the Quaternius fallback")
	check(str(initial_art.get("equipment_mode", "")) == "synced_sword_shield", "Ada does not use authority-synced sword and shield")
	check(bool(initial_art.get("use_imported_character_material", false)), "Ada does not preserve the authored ShieldMaiden material settings")
	check(ada.find_child("FaceReadabilityOverlay", true, false) == null, "Ada still contains the rejected procedural face overlay")
	check(str(initial_art.get("authority_main_weapon_id", "")) == "sword_shield", "Ada initial story weapon did not reach presentation")
	check(not bool(initial_art.get("sword_visible", true)) and not bool(initial_art.get("shield_visible", true)), "Ada displays her story weapon while in work mode")
	check(str(initial_art.get("sword_parent", "")) == "RightHand" and str(initial_art.get("shield_parent", "")) == "LeftHand", "Ada weapon props are not attached to hand sockets")
	check(float(initial_art.get("palette_saturation", 1.0)) <= 0.65, "Ada palette is not restrained enough")
	check(str(initial_art.get("palette_path", "")).ends_with("PolygonMinis_Texture_Blue_A.png"), "Ada does not use the authored blue Albedo palette")
	var target_mesh := ada.find_child("SK_Vikings_ShieldMaiden_01", true, false) as MeshInstance3D
	var authored_material := target_mesh.material_override as BaseMaterial3D if target_mesh != null else null
	check(authored_material != null and authored_material.vertex_color_use_as_albedo, "Ada lost the ShieldMaiden authored vertex-color face details")
	check(authored_material != null and authored_material.albedo_texture != null and authored_material.albedo_texture.resource_path.ends_with("PolygonMinis_Texture_Blue_A.png"), "Ada imported material does not bind the blue authored Albedo")
	check(not ada.get_node("BodyCollision").disabled, "Ada body collision was replaced by art")
	check(not ada.get_node("InteractionArea/InteractionCollision").disabled, "Ada interaction collision was replaced by art")
	check(not ada.get_node("LegacyVisuals").visible, "Ada legacy mesh is still visible")
	check(ada.find_child("SelectionArea", true, false) == null, "Ada production art added a duplicate selection collider")

	var action_before_preview := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	var talk_art: Dictionary = ada.debug_force_character_animation("talk")
	check(str(talk_art.get("current_clip", "")) == "Waving", "Ada talk state is unavailable")
	var attack_art: Dictionary = ada.debug_force_character_animation("attack")
	check(str(attack_art.get("current_clip", "")) == "Melee_1H_Attack_Slice_Horizontal", "Ada sword attack state is unavailable")
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_before_preview, "Animation preview changed Ada authoritative action")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	await process_frame

	resource_system.add_resource("item_polearm", 1)
	var polearm_result: Dictionary = equipment_system.equip_npc_main_weapon(NPC_ID, "polearm", "private")
	check(bool(polearm_result.get("ok", false)), "Could not replace Ada sword and shield with a polearm")
	await process_frame
	var polearm_art: Dictionary = ada.debug_get_character_art_snapshot()
	check(str(polearm_art.get("authority_main_weapon_id", "")) == "polearm", "Polearm authority did not reach Ada presentation")
	check(not bool(polearm_art.get("sword_visible", true)) and not bool(polearm_art.get("shield_visible", true)), "Ada kept false sword-and-shield props after a real equipment change")
	var sword_result: Dictionary = equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private")
	check(bool(sword_result.get("ok", false)), "Could not restore Ada sword and shield")
	await process_frame
	check(not bool(ada.debug_get_character_art_snapshot().get("sword_visible", true)), "Restored sword appeared before a weapon-using state")

	var training_button := gm.find_child("FormalTrainingInstructorButton", true, false) as Button
	check(training_button != null, "GM formal training instructor entry is missing")
	if training_button != null:
		gm.visible = true
		training_button.pressed.emit()
		await process_frame
		var reached_training := await _wait_for_action(action_system, time_system, TRAINING_ACTION_ID)
		check(reached_training, "Ada did not physically reach the training instructor station")
		if reached_training:
			await create_timer(0.18).timeout
			var training_art: Dictionary = ada.debug_get_character_art_snapshot()
			check(str(training_art.get("desired_state", "")) == "training_instructor", "Real training did not select instructor animation")
			check(str(training_art.get("current_clip", "")) == "Melee_Block_Attack", "Ada instructor animation is not the sword-and-shield demonstration")
			check(int(training_art.get("training_instructor_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Ada instructor demonstration is not cyclic")
			check(bool(training_art.get("sword_visible", false)) and bool(training_art.get("shield_visible", false)), "Weapon training did not draw Ada's sword and shield")
		action_system.interrupt_npc_action(NPC_ID, "verify_t0130_p5_training_complete", true)
		await process_frame

	var sleep_button := gm.find_child("FormalDormitorySleepButton", true, false) as Button
	var sleep_stop_button := gm.find_child("FormalDormitorySleepStopButton", true, false) as Button
	check(sleep_button != null and sleep_stop_button != null, "GM formal dormitory sleep entries are missing")
	if sleep_button != null and sleep_stop_button != null:
		npc_system.update_npc_state(NPC_ID, {"fatigue": 80, "satiety": 100, "current_action": "idle"})
		gm.visible = true
		sleep_button.pressed.emit()
		await process_frame
		var reached_sleep := await _wait_for_action(action_system, time_system, SLEEP_ACTION_ID)
		check(reached_sleep, "Ada did not physically reach her assigned dormitory bed")
		if reached_sleep:
			await create_timer(0.18).timeout
			var sleep_art: Dictionary = ada.debug_get_character_art_snapshot()
			var attachment: Dictionary = ada.debug_get_spatial_attachment_snapshot()
			check(str(sleep_art.get("desired_state", "")) == "sleeping" and str(sleep_art.get("current_clip", "")) == "Lie_Idle", "Real sleep did not select the lying idle loop")
			check(int(sleep_art.get("sleeping_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Ada sleep animation is not cyclic")
			check(str(sleep_art.get("spatial_attachment_pose", "")) == "sleeping_supine", "Dormitory pose did not reach Ada art")
			check(not bool(sleep_art.get("sword_visible", true)) and not bool(sleep_art.get("shield_visible", true)), "Ada sleeps while holding sword and shield")
			check(bool(attachment.get("active", false)) and str(attachment.get("pose", "")) == "sleeping_supine", "Real sleep did not attach Ada to her bed")
		gm.visible = true
		sleep_stop_button.pressed.emit()
		await process_frame
		await physics_frame
		var awake_art: Dictionary = ada.debug_get_character_art_snapshot()
		check(str(awake_art.get("spatial_attachment_pose", "")) == "", "Ada art kept the bed attachment after sleep stopped")
		check(not bool(awake_art.get("sword_visible", true)) and not bool(awake_art.get("shield_visible", true)), "Ada woke into work mode while still holding combat equipment")

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	check(bool(damage_result.get("ok", false)), "Ada authoritative damage entry failed")
	await process_frame
	var unconscious_art: Dictionary = ada.debug_get_character_art_snapshot()
	check(str(unconscious_art.get("desired_state", "")) == "unconscious", "Ada unconscious state did not select the fall clip")
	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	check(not (recovery_result.get("revived", []) as Array).is_empty(), "Ada did not revive through the authority recovery API")
	await process_frame
	check(str(ada.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Ada revival did not select get-up")
	finish()


func _get_npc_node(npc_system: Node) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(NPC_ID, NodePath("")))


func _wait_for_action(action_system: Node, time_system: Node, action_id: String, max_frames: int = 3600) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		await process_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0130_P5_ADA_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P5_ADA_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
