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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if (
		event_bus == null
		or action_system == null
		or npc_system == null
		or building_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or time_system == null
	):
		push_error("Required systems not found")
		quit(1)
		return

	var training_ground: Dictionary = building_system.get_building("training_ground")
	if not _has_workstation_type(training_ground.get("workstations", []), "training_instructor_station"):
		push_error("Training ground should expose an instructor workstation")
		quit(1)
		return
	if not _has_workstation_type(training_ground.get("workstations", []), "training_practice_slot"):
		push_error("Training ground should expose a student workstation")
		quit(1)
		return

	var instructor_action: Dictionary = action_system.get_action("work_training_instructor")
	var student_action: Dictionary = action_system.get_action("receive_weapon_training")
	if str(instructor_action.get("type", "")) != "training_instructor" or str(instructor_action.get("skill", "")) != "教练":
		push_error("Training instructor action should use coach skill")
		quit(1)
		return
	if str(student_action.get("type", "")) != "training_student":
		push_error("Training student action should be separate from instructor action")
		quit(1)
		return

	var no_equipment_id := "cook_01"
	npc_system.set_npc_recruited(no_equipment_id, true)
	npc_system.debug_enter_location_immediately(no_equipment_id, "training_ground")
	if action_system.debug_assign_action(no_equipment_id, "work_training_instructor"):
		push_error("NPC without weapon or mount should not become a training instructor")
		quit(1)
		return
	if str(npc_system.get_npc_state(no_equipment_id).get("last_action_result", "")) != "training_instructor_failed_no_equipment":
		push_error("No-equipment instructor failure should be explicit")
		quit(1)
		return

	var instructor_id := "veteran_deputy_01"
	var student_id := "stableman_01"
	time_system.set_paused(false)
	_get_npc_node(npc_system, instructor_id).set("move_speed", 5.0)
	_get_npc_node(npc_system, student_id).set("move_speed", 5.0)
	npc_system.set_npc_recruited(student_id, true)
	_set_profile_skills(npc_system, instructor_id, {
		"剑盾": 40,
		"弓": 80,
		"骑术": 70,
		"教练": 42
	})
	_set_profile_skills(npc_system, student_id, {
		"弓": 5,
		"骑术": 5
	})

	resource_system.add_resource("item_sword_shield", 1)
	resource_system.add_resource("item_bow", 1)
	var instructor_weapon: Dictionary = equipment_system.equip_npc_main_weapon(instructor_id, "sword_shield", "private")
	if not bool(instructor_weapon.get("ok", false)):
		push_error("Failed to equip instructor sword shield: %s" % JSON.stringify(instructor_weapon))
		quit(1)
		return
	var student_weapon: Dictionary = equipment_system.equip_npc_main_weapon(student_id, "bow", "private")
	var student_mount: Dictionary = equipment_system.equip_npc_mount(student_id, "", "private")
	if not bool(student_weapon.get("ok", false)) or not bool(student_mount.get("ok", false)):
		push_error("Failed to equip student bow and mount: weapon=%s mount=%s" % [
			JSON.stringify(student_weapon),
			JSON.stringify(student_mount)
		])
		quit(1)
		return

	npc_system.debug_enter_location_immediately(student_id, "training_ground")
	if action_system.debug_assign_action(student_id, "receive_weapon_training"):
		push_error("Student training should fail when no instructor is active")
		quit(1)
		return
	if str(npc_system.get_npc_state(student_id).get("last_action_result", "")) != "training_student_failed_no_instructor":
		push_error("No-instructor student failure should be explicit")
		quit(1)
		return

	npc_system.debug_enter_location_immediately(instructor_id, "training_ground")
	if not action_system.debug_assign_action(instructor_id, "work_training_instructor"):
		push_error("Equipped instructor should start training duty")
		quit(1)
		return
	if not await _wait_for_active(action_system, time_system, instructor_id, "work_training_instructor"):
		push_error("Equipped instructor should physically reach the instructor station")
		quit(1)
		return
	event_bus.logical_time_tick.emit(14400.0, 1.0)
	var instructor_after_solo: Dictionary = npc_system.get_npc(instructor_id)
	if int(instructor_after_solo.get("skills", {}).get("剑盾", 0)) <= 40:
		push_error("Solo instructor should slowly improve their currently equipped weapon skill")
		quit(1)
		return
	if int(instructor_after_solo.get("skills", {}).get("弓", 0)) != 80 or int(instructor_after_solo.get("skills", {}).get("骑术", 0)) != 70:
		push_error("Solo instructor should only improve currently equipped weapon or mount skills")
		quit(1)
		return
	if not _has_skill_event(memory_system.get_npc_daily_events(instructor_id), "training_solo", "剑盾"):
		push_error("Solo training should write a skill_improved event")
		quit(1)
		return

	var instructor_sword_before_students := int(instructor_after_solo.get("skills", {}).get("剑盾", 0))
	var instructor_coach_before_students := int(instructor_after_solo.get("skills", {}).get("教练", 0))
	var student_before_training: Dictionary = npc_system.get_npc(student_id)
	var student_bow_before := int(student_before_training.get("skills", {}).get("弓", 0))
	var student_riding_before := int(student_before_training.get("skills", {}).get("骑术", 0))
	var student_state_before: Dictionary = npc_system.get_npc_state(student_id)
	if not action_system.debug_assign_action(student_id, "receive_weapon_training"):
		push_error("Equipped student should start training when an instructor is active")
		quit(1)
		return
	if not await _wait_for_active(action_system, time_system, student_id, "receive_weapon_training"):
		push_error("Equipped student should physically reach a practice slot")
		quit(1)
		return
	event_bus.logical_time_tick.emit(7200.0, 1.0)
	var student_after_training: Dictionary = npc_system.get_npc(student_id)
	var instructor_after_students: Dictionary = npc_system.get_npc(instructor_id)
	if int(student_after_training.get("skills", {}).get("弓", 0)) <= student_bow_before:
		push_error("Student should improve current bow skill during training")
		quit(1)
		return
	if int(student_after_training.get("skills", {}).get("骑术", 0)) <= student_riding_before:
		push_error("Student should improve riding skill when training with a mount equipped")
		quit(1)
		return
	if int(instructor_after_students.get("skills", {}).get("剑盾", 0)) != instructor_sword_before_students:
		push_error("Instructor should not keep improving own weapon while training students")
		quit(1)
		return
	if int(instructor_after_students.get("skills", {}).get("教练", 0)) <= instructor_coach_before_students:
		push_error("Instructor should improve coach skill while training students")
		quit(1)
		return
	var student_state_after: Dictionary = npc_system.get_npc_state(student_id)
	if int(student_state_after.get("fatigue", 0)) <= int(student_state_before.get("fatigue", 0)):
		push_error("Training should increase student fatigue over unit time")
		quit(1)
		return
	if int(student_state_after.get("satiety", 0)) >= int(student_state_before.get("satiety", 0)):
		push_error("Training should consume student satiety over unit time")
		quit(1)
		return
	if not _has_skill_event(memory_system.get_npc_daily_events(student_id), "training_student", "弓"):
		push_error("Student training should write bow skill event")
		quit(1)
		return
	if not _has_skill_event(memory_system.get_npc_daily_events(student_id), "training_student", "骑术"):
		push_error("Student training should write riding skill event")
		quit(1)
		return
	if not _has_skill_event(memory_system.get_npc_daily_events(instructor_id), "training_coaching", "教练"):
		push_error("Instructor coaching should write coach skill event")
		quit(1)
		return

	_set_profile_skills(npc_system, instructor_id, {"弓": 10})
	_set_profile_skills(npc_system, student_id, {"弓": 90})
	var low_teacher_interval: float = action_system._get_training_student_skill_interval_seconds(
		instructor_id,
		student_id,
		"弓",
		student_action
	)
	if low_teacher_interval <= float(student_action.get("student_skill_interval_seconds", 3600)):
		push_error("Instructor with lower project skill should train the student very slowly")
		quit(1)
		return

	print("T0903 training system verification passed.")
	quit(0)


func _has_workstation_type(workstations: Array, workstation_type: String) -> bool:
	for raw_workstation in workstations:
		if raw_workstation is Dictionary and str(raw_workstation.get("type", "")) == workstation_type:
			return true
	return false


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
		):
			return true
	return false


func _set_profile_skills(npc_system: Node, npc_id: String, changed_skills: Dictionary) -> void:
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	for skill_name in changed_skills.keys():
		skills[str(skill_name)] = int(changed_skills[skill_name])
	profile["skills"] = skills
	npc_system._profiles[npc_id] = profile


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false
