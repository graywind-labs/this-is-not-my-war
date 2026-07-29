extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if action_system == null or needs_system == null or npc_system == null or building_system == null or resource_system == null:
		_fail("Required systems not found")
		return
	needs_system.initialize()

	var engineer_id := "engineer_01"
	var engineering_before := int(npc_system.get_npc(engineer_id).get("skills", {}).get("工程", 0))
	var engineer_xp_before := int(npc_system.get_npc_progression(engineer_id).get("total_experience", 0))
	resource_system.add_resource("stone", 100)
	resource_system.add_resource("wood", 100)
	if not building_system.debug_damage_building("wall", 200):
		_fail("Failed to damage wall for repair integration")
		return
	if not building_system.repair_building("wall"):
		_fail("Failed to start wall repair integration")
		return
	npc_system.debug_enter_location_immediately(engineer_id, "plaza")
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20})
	if not action_system.debug_assign_repair_assist(engineer_id, "wall"):
		_fail("Failed to assign repair helper")
		return

	needs_system._on_logical_time_tick(1800.0, 1.0)
	building_system._on_logical_time_tick(1800.0, 1.0)
	if int(npc_system.get_npc(engineer_id).get("skills", {}).get("工程", 0)) != engineering_before:
		_fail("Repair helper must not gain a skill point before one effective hour")
		return
	var first_repair_timer: Dictionary = action_system.get_timed_action_experience_snapshot(engineer_id, "assist_repair")
	if not is_equal_approx(float(first_repair_timer.get("remainder_seconds", -1.0)), 1800.0):
		_fail("Repair helper did not retain the first 1800 effective seconds")
		return

	needs_system._on_logical_time_tick(1800.0, 1.0)
	building_system._on_logical_time_tick(1800.0, 1.0)
	if int(npc_system.get_npc(engineer_id).get("skills", {}).get("工程", 0)) != engineering_before + 1:
		_fail("Repair helper must gain engineering after one effective hour")
		return
	if int(npc_system.get_npc_progression(engineer_id).get("total_experience", 0)) <= engineer_xp_before:
		_fail("Repair helper skill gain must enter total experience progression")
		return
	var engineer_needs: Dictionary = npc_system.get_npc_state(engineer_id)
	if int(engineer_needs.get("satiety", -1)) != 76 or int(engineer_needs.get("fatigue", -1)) != 28:
		_fail("Repair helper must receive heavy-work needs settlement for the same effective hour")
		return

	var engineering_after_repair := int(npc_system.get_npc(engineer_id).get("skills", {}).get("工程", 0))
	var upgrade_first: Dictionary = action_system.advance_timed_action_experience(
		engineer_id,
		"assist_upgrade",
		3599.0,
		"plaza"
	)
	if int(upgrade_first.get("awards", -1)) != 0:
		_fail("Upgrade assist must not award before the configured effective hour")
		return
	var upgrade_second: Dictionary = action_system.advance_timed_action_experience(
		engineer_id,
		"assist_upgrade",
		1.0,
		"plaza"
	)
	if int(upgrade_second.get("awards", 0)) != 1:
		_fail("Upgrade assist must award exactly at one accumulated effective hour")
		return
	if int(npc_system.get_npc(engineer_id).get("skills", {}).get("工程", 0)) != engineering_after_repair + 1:
		_fail("Upgrade assist must improve engineering")
		return

	var doctor_id := "doctor_01"
	var target_id := "veteran_deputy_01"
	var medical_before := int(npc_system.get_npc(doctor_id).get("skills", {}).get("医术", 0))
	resource_system.add_resource("money", 100)
	npc_system.debug_enter_location_immediately(doctor_id, "plaza")
	npc_system.debug_enter_location_immediately(target_id, "plaza")
	npc_system.update_npc_state(target_id, {
		"hp": 29,
		"max_hp": 100,
		"unconscious": true,
		"escaped": false,
		"behavior_mode": "unconscious",
		"current_action": "unconscious",
	})
	if not action_system.debug_assign_heal_assist(doctor_id, target_id):
		_fail("Failed to assign healing helper")
		return
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(doctor_id)
	var effective_heal_seconds: float = npc_system.get_assisted_recovery_effective_seconds(
		target_id,
		3600.0,
		doctor_id,
		int(runtime.get("medical_skill", 0))
	)
	if effective_heal_seconds <= 0.0 or effective_heal_seconds >= 3600.0:
		_fail("Healing setup must revive partway through the one-hour test window")
		return
	needs_system._on_logical_time_tick(3600.0, 1.0)
	action_system._on_logical_time_tick(3600.0, 1.0)
	var heal_timer: Dictionary = action_system.get_timed_action_experience_snapshot(doctor_id, "assist_heal")
	if not is_equal_approx(float(heal_timer.get("remainder_seconds", -1.0)), effective_heal_seconds):
		_fail("Healing assist XP timer must clamp to actual time before revival")
		return
	if int(npc_system.get_npc(doctor_id).get("skills", {}).get("医术", 0)) != medical_before:
		_fail("Short effective healing must not award a full-hour skill point")
		return
	var finish_heal: Dictionary = action_system.advance_timed_action_experience(
		doctor_id,
		"assist_heal",
		3600.0 - effective_heal_seconds,
		"plaza"
	)
	if int(finish_heal.get("awards", 0)) != 1:
		_fail("Healing assist must accumulate effective time across patients")
		return
	if int(npc_system.get_npc(doctor_id).get("skills", {}).get("医术", 0)) != medical_before + 1:
		_fail("Healing assist must improve medicine")
		return

	var doctor_xp_before_dialogue := int(npc_system.get_npc_progression(doctor_id).get("total_experience", 0))
	if not action_system.advance_timed_action_experience(doctor_id, "talk_to_npc", 7200.0, "plaza").is_empty():
		_fail("Dialogue must not expose timed work experience")
		return
	if int(npc_system.get_npc_progression(doctor_id).get("total_experience", 0)) != doctor_xp_before_dialogue:
		_fail("Dialogue must not increase work experience")
		return

	main.queue_free()
	await process_frame
	print("T0081 assist effective-time experience verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
