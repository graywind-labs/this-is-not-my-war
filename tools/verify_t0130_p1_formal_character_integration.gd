extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	check(not [npc_system, action_system, crafting_system, resource_system, combat_system, time_system].has(null), "Main production systems are incomplete")
	if not _failures.is_empty():
		finish()
		return
	time_system.set_paused(false)

	var glen_art: Dictionary = npc_system.debug_get_npc_character_art_snapshot("blacksmith_01")
	check(bool(glen_art.get("ready", false)), "Formal Glen chibi art did not become ready")
	check(str(glen_art.get("appearance_id", "")) == "glen_blacksmith_chibi_v1", "Formal Glen still uses the legacy appearance")
	check(str(glen_art.get("authority_role", "")) == "presentation_only", "Glen art crossed the authority boundary")
	check(str(glen_art.get("hammer_parent", "")) == "Mount", "Resting Glen hammer is not attached at the waist")
	check((glen_art.get("hammer_local_position", Vector3.ZERO) as Vector3).distance_to(Vector3(-0.264662, -0.153232, 0.023966)) < 0.001, "Resting Glen hammer left its calibrated waist position")
	check(float(glen_art.get("hammer_head_forward_dot", -1.0)) > 0.98, "Resting Glen hammer head does not point forward")
	check(float(glen_art.get("hammer_long_axis_up_dot", 1.0)) < 0.05, "Resting Glen hammer is not horizontal")
	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var glen := npc_system.get_node_or_null(npc_paths.get("blacksmith_01", NodePath("")))
	check(glen != null, "Formal Glen body is missing")
	if glen != null:
		check(not glen.get_node("BodyCollision").disabled, "Formal Glen body collision was replaced by art")
		check(not glen.get_node("InteractionArea/InteractionCollision").disabled, "Formal Glen interaction collision was replaced by art")
		check(not glen.get_node("LegacyVisuals").visible, "Formal Glen legacy mesh is still visible")
		check(glen.find_child("SelectionArea", true, false) == null, "Production Glen art added a duplicate selection collider")

	resource_system.add_resource("iron", 30)
	resource_system.add_resource("wood", 30)
	resource_system.add_resource("stone", 30)
	var target_result: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", true)
	check(bool(target_result.get("ok", false)), "Could not prepare formal blacksmith target")
	check(bool(action_system.debug_assign_action("blacksmith_01", "work_blacksmith")), "Could not dispatch formal Glen to blacksmith work")
	for _frame in range(900):
		if str(npc_system.get_npc_state("blacksmith_01").get("current_action", "")) == "work_blacksmith":
			break
		time_system.set_paused(false)
		await physics_frame
		await process_frame
	await create_timer(0.45).timeout
	glen_art = npc_system.debug_get_npc_character_art_snapshot("blacksmith_01")
	check(str(glen_art.get("desired_state", "")) == "work", "Formal blacksmith authority did not drive the chibi work loop")
	check(str(glen_art.get("hammer_parent", "")) == "RightHand", "Formal blacksmith work did not move the chibi hammer to the hand")
	check((glen_art.get("hammer_local_position", Vector3.ZERO) as Vector3).distance_to(Vector3(-0.152, 0.0, 0.055)) < 0.001, "Formal blacksmith hammer left its lowered thumb-palm grip position")
	check(float(glen_art.get("hammer_grip_hand_distance", -1.0)) > 0.05 and float(glen_art.get("hammer_grip_hand_distance", 1.0)) < 0.06, "Formal blacksmith hammer handle is not lowered into the thumb-palm gap")
	check(float(glen_art.get("hammer_handle_rear_hand_distance", -1.0)) > 0.055 and float(glen_art.get("hammer_handle_rear_hand_distance", 1.0)) < 0.07, "Formal blacksmith hand is not near the rear handle section")
	check(float(glen_art.get("hammer_head_near_hand_distance", -1.0)) > 0.36, "Formal blacksmith hand still overlaps the hammer head")
	check(int(glen_art.get("work_clip_loop_mode", 0)) == Animation.LOOP_LINEAR, "Formal chibi hammering is not cyclic")
	check(facing_dot(glen_art) > 0.9, "Formal Glen visible front is opposite the forge-facing direction")
	for _phase_sample in range(3):
		await create_timer(0.16).timeout
		glen_art = npc_system.debug_get_npc_character_art_snapshot("blacksmith_01")
		check(str(glen_art.get("hammer_parent", "")) == "RightHand", "Formal blacksmith hammer left the hand during the work cycle")
		check(float(glen_art.get("hammer_grip_hand_distance", -1.0)) > 0.05 and float(glen_art.get("hammer_grip_hand_distance", 1.0)) < 0.06, "Formal blacksmith lowered grip drifted during the work cycle")
		check(float(glen_art.get("hammer_head_near_hand_distance", -1.0)) > 0.36, "Formal blacksmith hammer head drifted back into the hand")

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1)
	check(bool(spawn_result.get("ok", false)), "Could not spawn the formal sword-shield wave: %s" % JSON.stringify(spawn_result))
	await create_timer(0.55).timeout
	var enemy_art: Array[Dictionary] = combat_system.debug_get_enemy_art_snapshots()
	check(enemy_art.size() == 8, "First wave did not expose eight formal enemy art snapshots")
	for entry in enemy_art:
		check(str(entry.get("unit_type", "")) == "melee_infantry", "P1 fixture contains a non-melee enemy")
		check(str(entry.get("weapon_type", "")) == "sword_shield", "P1 fixture contains a non-sword-shield enemy")
		check(str(entry.get("art_family", "")) == "synty_chibi", "Sword-shield enemy did not select Synty chibi art")
		var art: Dictionary = entry.get("art", {}) if entry.get("art", {}) is Dictionary else {}
		check(bool(art.get("ready", false)), "Sword-shield enemy art did not become ready")
		check(str(art.get("appearance_id", "")) == "enemy_raider_sword_shield_chibi_v1", "Sword-shield enemy appearance id is wrong")
		check(str(art.get("equipment_mode", "")) == "sword_shield", "Sword-shield enemy equipment contract is wrong")
		check(["walk", "run"].has(str(art.get("desired_state", ""))), "Formal enemy movement did not drive locomotion animation")
		# Dense RVO can change travel intent while the bounded visual turn is still
		# catching up. The regression guard rejects the former 180-degree reverse,
		# without requiring every crowd member to snap instantly to a new vector.
		check(facing_dot(art) > 0.3, "Sword-shield enemy visible front is opposite its travel direction: %s" % JSON.stringify({"enemy_id": entry.get("enemy_id", ""), "visual": art.get("visual_forward", Vector3.ZERO), "target": art.get("target_facing_direction", Vector3.ZERO), "dot": facing_dot(art)}))

	var enemy_paths: Dictionary = combat_system.get("_enemy_nodes")
	for enemy_id in combat_system.get_active_enemy_ids():
		var actor := combat_system.get_node_or_null(enemy_paths.get(enemy_id, NodePath("")))
		check(actor != null and not actor.get_node("BodyCollision").disabled, "Formal enemy body collision is missing: %s" % enemy_id)
		check(actor != null and actor.find_child("SelectionArea", true, false) == null, "Enemy art added duplicate selection collision: %s" % enemy_id)

	var gm := root.get_node_or_null("Main/UI/GMPanel")
	check(gm != null and gm.find_child("ChibiFormalGlenWorkButton", true, false) != null, "GM formal Glen button is missing")
	check(gm != null and gm.find_child("ChibiFormalSwordShieldWaveButton", true, false) != null, "GM formal sword-shield wave button is missing")
	finish()


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func facing_dot(snapshot: Dictionary) -> float:
	var visible_forward: Vector3 = snapshot.get("visual_forward", Vector3.ZERO)
	var target_forward: Vector3 = snapshot.get("target_facing_direction", Vector3.ZERO)
	if visible_forward.length_squared() <= 0.0001 or target_forward.length_squared() <= 0.0001:
		return -1.0
	return visible_forward.normalized().dot(target_forward.normalized())


func finish() -> void:
	if _failures.is_empty():
		print("T0130_P1_FORMAL_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P1_FORMAL_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
