extends SceneTree


const NPC_ID := "veteran_deputy_01"
const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if horse_system == null or npc_system == null or combat_system == null or time_system == null:
		_fail("Mounted-fall verification systems are missing")
		return
	if time_system.has_method("set_paused"):
		time_system.set_paused(false)

	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.is_empty():
		_fail("Mounted-fall verification requires an initial horse")
		return
	var horse_id := str(horse_ids[0])
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "mounted_fall_test_reset", {"force_idle": true})
	var assigned: Dictionary = horse_system.assign_horse_to_npc(NPC_ID, horse_id, "private")
	if not bool(assigned.get("ok", false)):
		_fail("Could not assign the mounted-fall test horse: %s" % JSON.stringify(assigned))
		return
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(NPC_ID, "combat", "mounted_fall_test", {
		"state_changes": {"current_action": "combat_ready"},
		"request_plan_reevaluation": false
	})
	if not bool(mode_result.get("ok", false)) or not bool(horse_system.debug_complete_horse_transition(horse_id).get("ok", false)):
		_fail("Could not enter mounted combat for the fall test")
		return
	await process_frame

	var rider := _get_npc_node(npc_system)
	if rider == null:
		_fail("Mounted-fall rider node is missing")
		return
	var mounted: Dictionary = rider.debug_get_character_art_snapshot()
	var mounted_offset: Vector3 = mounted.get("presentation_pose_offset", Vector3.ZERO)
	if str(mounted.get("desired_state", "")) != "vehicle_seated" or mounted_offset.y < 0.5:
		_fail("Formal rider did not enter the raised mounted pose: %s" % str(mounted))
		return
	if not bool(mounted.get("combat_mount_visual_visible", false)) or not bool(mounted.get("combat_mount_uses_imported_horse", false)):
		_fail("Formal combat mount is not using the imported horse model: %s" % str(mounted))
		return
	if not Vector3(mounted.get("combat_mount_horse_local_position", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_ROOT_POSITION):
		_fail("Main friendly horse position diverged from NPCDevLab reference: %s" % str(mounted))
		return
	if not Vector3(mounted.get("combat_mount_horse_scale", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_SCALE):
		_fail("Main friendly horse scale diverged from NPCDevLab reference: %s" % str(mounted))
		return
	if float(mounted.get("combat_mount_forward_dot", -1.0)) < 0.99:
		_fail("Main friendly rider and horse facing diverged: %s" % str(mounted))
		return

	npc_system.update_npc_state(NPC_ID, {"hp": 1, "unconscious": false})
	combat_system._apply_enemy_attack_to_npc(
		{"id": "mounted_fall_test_enemy", "name": "坠马测试敌军"},
		NPC_ID,
		20,
		20.0,
		0.0,
		0.0,
		0.0
	)
	await process_frame
	var rider_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var airborne: Dictionary = rider.debug_get_character_art_snapshot()
	if not bool(rider_state.get("unconscious", false)) or str(horse.get("location", "")) != "returning_stable":
		_fail("Mounted rider unconsciousness did not keep the T0138 authority result")
		return
	if not str(horse.get("assigned_npc_id", "")).is_empty() or not str(horse.get("ridden_by_npc_id", "")).is_empty():
		_fail("Mounted fall delayed the authoritative horse assignment cleanup")
		return
	if str(airborne.get("desired_state", "")) != "mounted_fall" or str(airborne.get("current_clip", "")) != "Death_A":
		_fail("Mounted unconsciousness did not select the mounted fall / Death_A transition: %s" % str(airborne))
		return
	if not bool(airborne.get("mounted_fall_active", false)) or str(airborne.get("mounted_fall_phase", "")) != "airborne":
		_fail("Mounted fall did not begin in its airborne phase")
		return
	if bool(airborne.get("combat_mount_visual_visible", true)):
		_fail("The ridden horse projection remained under the falling rider")
		return

	await create_timer(0.46).timeout
	var middle: Dictionary = rider.debug_get_character_art_snapshot()
	var middle_offset: Vector3 = middle.get("presentation_pose_offset", Vector3.ZERO)
	var middle_progress := float(middle.get("mounted_fall_progress", 0.0))
	if middle_progress < 0.35 or middle_progress > 0.75 or absf(middle_offset.x) < 0.12 or middle_offset.y < 0.25:
		_fail("Mounted fall middle phase has no readable sideways airborne arc: %s" % str(middle))
		return

	await create_timer(0.58).timeout
	var landed: Dictionary = rider.debug_get_character_art_snapshot()
	var landed_offset: Vector3 = landed.get("presentation_pose_offset", Vector3.ZERO)
	if str(landed.get("mounted_fall_phase", "")) != "landed" or str(landed.get("desired_state", "")) != "mounted_fall":
		_fail("Mounted fall did not settle into its landed unconscious pose: %s" % str(landed))
		return
	if absf(landed_offset.x) < 0.5 or absf(landed_offset.y) > 0.05:
		_fail("Mounted fall landing offset is not grounded beside the horse path: %s" % str(landed_offset))
		return

	var recovered: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	if (recovered.get("revived", []) as Array).is_empty():
		_fail("Could not revive the mounted-fall rider through the existing authority path")
		return
	await process_frame
	var getting_up: Dictionary = rider.debug_get_character_art_snapshot()
	if str(getting_up.get("desired_state", "")) != "get_up" or not bool(getting_up.get("mounted_fall_recovering", false)):
		_fail("Mounted fall did not hand off to the existing get-up animation")
		return

	await create_timer(1.35).timeout
	npc_system.update_npc_state(NPC_ID, {"hp": 1, "unconscious": false, "current_action": "idle"})
	var trigger_count := int(rider.debug_get_character_art_snapshot().get("mounted_fall_trigger_count", 0))
	npc_system.debug_damage_npc(NPC_ID, 9999)
	await process_frame
	var foot_fall: Dictionary = rider.debug_get_character_art_snapshot()
	if str(foot_fall.get("desired_state", "")) != "unconscious" or int(foot_fall.get("mounted_fall_trigger_count", -1)) != trigger_count:
		_fail("Unmounted unconsciousness incorrectly triggered the mounted fall branch: %s" % str(foot_fall))
		return

	print("T0139 friendly mounted fall animation verification passed.")
	quit(0)


func _get_npc_node(npc_system: Node) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(NPC_ID, NodePath("")))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
