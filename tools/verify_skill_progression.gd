extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var event_bus := root.get_node_or_null("EventBus")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if (
		event_bus == null
		or action_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or npc_panel == null
		or gm_panel == null
	):
		push_error("Required systems not found")
		quit(1)
		return

	var worker_id := "gardener_01"
	var worker_before: Dictionary = npc_system.get_npc(worker_id)
	var farming_before := int(worker_before.get("skills", {}).get("耕种", 0))
	npc_system.debug_enter_location_immediately(worker_id, "garden")
	if not action_system.debug_assign_action(worker_id, "work_garden"):
		push_error("Garden work should start")
		quit(1)
		return
	event_bus.logical_time_tick.emit(7200.0, 1.0)
	var worker_after: Dictionary = npc_system.get_npc(worker_id)
	if int(worker_after.get("skills", {}).get("耕种", 0)) <= farming_before:
		push_error("Completed work should slowly improve professional skill")
		quit(1)
		return
	var worker_progression: Dictionary = npc_system.get_npc_progression(worker_id)
	if int(worker_progression.get("total_experience", 0)) <= 0:
		push_error("Skill improvement should add total experience")
		quit(1)
		return
	if not _has_skill_event(memory_system.get_npc_daily_events(worker_id), "work_completed", "耕种"):
		push_error("Work skill gain should write a skill_improved event")
		quit(1)
		return

	var trainee_id := "veteran_deputy_01"
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(trainee_id, "sword_shield", "private")
	if not bool(equip_result.get("ok", false)):
		push_error("Failed to equip training weapon: %s" % JSON.stringify(equip_result))
		quit(1)
		return
	var trainee_xp_before := int(npc_system.get_npc_progression(trainee_id).get("total_experience", 0))
	npc_system.debug_enter_location_immediately(trainee_id, "training_ground")
	if not action_system.debug_assign_action(trainee_id, "work_training_instructor"):
		push_error("Equipped NPC should start solo training")
		quit(1)
		return
	event_bus.logical_time_tick.emit(14400.0, 1.0)
	if int(npc_system.get_npc_progression(trainee_id).get("total_experience", 0)) <= trainee_xp_before:
		push_error("Training skill gain should use the same progression pipeline")
		quit(1)
		return

	var doctor_id := "doctor_01"
	var doctor_xp_before := int(npc_system.get_npc_progression(doctor_id).get("total_experience", 0))
	npc_system.debug_enter_location_immediately(doctor_id, "clinic")
	if not action_system.debug_assign_action(doctor_id, "work_clinic_doctor"):
		push_error("Clinic doctor work should start")
		quit(1)
		return
	event_bus.logical_time_tick.emit(14400.0, 1.0)
	if int(npc_system.get_npc_progression(doctor_id).get("total_experience", 0)) <= doctor_xp_before:
		push_error("Clinic study should use the same progression pipeline")
		quit(1)
		return

	var assign_id := "cook_01"
	_set_profile_skill_and_progression(npc_system, assign_id, "厨艺", 0, 0)
	for _index in range(5):
		var gain_result: Dictionary = npc_system.increase_npc_skill(assign_id, "厨艺", 1)
		if gain_result.is_empty():
			push_error("Direct skill gain should succeed before reaching cap")
			quit(1)
			return
	var progression_after_threshold: Dictionary = npc_system.get_npc_progression(assign_id)
	if int(progression_after_threshold.get("unspent_skill_points", 0)) != 1:
		push_error("Five skill experience should grant one unspent skill point")
		quit(1)
		return

	var stats_before: Dictionary = npc_system.get_npc(assign_id).get("stats", {})
	var strength_before := int(stats_before.get("strength", 0))
	var assign_result: Dictionary = npc_system.assign_npc_attribute_point(assign_id, "strength")
	if not bool(assign_result.get("ok", false)):
		push_error("Player skill point assignment should succeed: %s" % JSON.stringify(assign_result))
		quit(1)
		return
	var assigned_npc: Dictionary = npc_system.get_npc(assign_id)
	if int(assigned_npc.get("stats", {}).get("strength", 0)) != strength_before + 1:
		push_error("Skill point should increase strength by one")
		quit(1)
		return
	if int(npc_system.get_npc_progression(assign_id).get("unspent_skill_points", 0)) != 0:
		push_error("Assigned skill point should be consumed")
		quit(1)
		return
	var strength_event := _find_attribute_event(memory_system.get_npc_daily_events(assign_id), "strength")
	if strength_event.is_empty():
		push_error("Attribute assignment should write attribute_improved event")
		quit(1)
		return
	var npc_name := str(assigned_npc.get("name", assign_id))
	if str(strength_event.get("summary", "")) != "%s通过锻炼体力，力量从%d提高到%d。" % [npc_name, strength_before, strength_before + 1]:
		push_error("Strength growth should use the NPC physical-training narrative")
		quit(1)
		return
	if strength_event.get("actor_ids", []) != [assign_id] or str(strength_event.get("summary", "")).contains("守备官"):
		push_error("Attribute growth event should describe the NPC as the actor without mentioning the guard officer")
		quit(1)
		return

	var failed_assign: Dictionary = npc_system.assign_npc_attribute_point(assign_id, "intelligence")
	if bool(failed_assign.get("ok", false)):
		push_error("Cannot assign attributes without unspent points")
		quit(1)
		return

	npc_panel.show_npc(assign_id)
	await process_frame
	var old_progression_label := npc_panel.find_child("NPCProgressionLabel", true, false) as Label
	var experience_label := npc_panel.find_child("NPCExperienceLabel", true, false) as Label
	var strength_button := npc_panel.find_child("NPCStrengthPointButton", true, false) as Button
	var intelligence_button := npc_panel.find_child("NPCIntelligencePointButton", true, false) as Button
	if old_progression_label != null:
		push_error("NPC panel should not keep the old progression explanation label")
		quit(1)
		return
	if experience_label == null or not experience_label.text.begins_with("经验：") or not experience_label.text.contains(" / "):
		push_error("NPC panel should show HP-style experience text")
		quit(1)
		return
	if strength_button == null or intelligence_button == null:
		push_error("NPC panel should expose inline attribute point buttons")
		quit(1)
		return
	if strength_button.visible or intelligence_button.visible:
		push_error("NPC panel attribute buttons should disappear when no skill points remain")
		quit(1)
		return

	for _index in range(5):
		npc_system.increase_npc_skill(assign_id, "厨艺", 1)
	npc_panel.show_npc(assign_id)
	await process_frame
	if not strength_button.visible or not intelligence_button.visible:
		push_error("NPC panel attribute buttons should appear beside attributes when skill points are available")
		quit(1)
		return
	var intelligence_before := int(npc_system.get_npc(assign_id).get("stats", {}).get("intelligence", 0))
	intelligence_button.pressed.emit()
	await process_frame
	if int(npc_system.get_npc_progression(assign_id).get("unspent_skill_points", 0)) != 0:
		push_error("Inline strength button should consume one skill point")
		quit(1)
		return
	if strength_button.visible or intelligence_button.visible:
		push_error("NPC panel attribute buttons should disappear after the last point is spent")
		quit(1)
		return
	var intelligence_event := _find_attribute_event(memory_system.get_npc_daily_events(assign_id), "intelligence")
	if str(intelligence_event.get("summary", "")) != "%s通过锻炼脑力，智力从%d提高到%d。" % [npc_name, intelligence_before, intelligence_before + 1]:
		push_error("Intelligence growth should use the NPC mental-training narrative")
		quit(1)
		return

	gm_panel._execute_command("assign_attribute %s intelligence" % assign_id)
	await process_frame
	if not gm_panel._result_text.text.contains("没有可分配技能点"):
		push_error("GM assign_attribute command should call NPCSystem and show failure reason")
		quit(1)
		return

	main.queue_free()
	await process_frame
	print("T0904 skill progression verification passed.")
	quit(0)


func _has_skill_event(events: Array, reason: String, skill_name: String) -> bool:
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var payload: Dictionary = event.get("payload", {})
		if (
			str(event.get("type", "")) == "skill_improved"
			and str(payload.get("reason", "")) == reason
			and str(payload.get("skill_name", "")) == skill_name
			and int(payload.get("experience_gained", 0)) > 0
		):
			return true
	return false


func _find_attribute_event(events: Array, attribute_name: String) -> Dictionary:
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var payload: Dictionary = event.get("payload", {})
		if (
			str(event.get("type", "")) == "attribute_improved"
			and str(payload.get("attribute", "")) == attribute_name
		):
			return event
	return {}


func _set_profile_skill_and_progression(npc_system: Node, npc_id: String, skill_name: String, skill_value: int, total_experience: int) -> void:
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills[skill_name] = skill_value
	profile["skills"] = skills
	profile["progression"] = {
		"total_experience": total_experience,
		"next_skill_point_xp": 5,
		"unspent_skill_points": 0,
		"spent_skill_points": 0,
		"skill_experience": {}
	}
	npc_system._profiles[npc_id] = profile
