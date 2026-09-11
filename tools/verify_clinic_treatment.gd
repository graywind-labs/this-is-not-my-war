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
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if event_bus == null or action_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null or time_system == null:
		push_error("Required systems not found")
		quit(1)
		return
	time_system.set_current_time(1, 7, 2, 0)
	time_system.set_paused(false)

	var clinic: Dictionary = building_system.get_building("clinic")
	if not _has_workstation_type(clinic.get("workstations", []), "clinic_doctor_station"):
		push_error("Clinic should expose a doctor workstation")
		quit(1)
		return
	if not _has_workstation_type(clinic.get("workstations", []), "clinic_patient_bed"):
		push_error("Clinic should expose a patient bed")
		quit(1)
		return

	var doctor_action: Dictionary = action_system.get_action("work_clinic_doctor")
	var patient_action: Dictionary = action_system.get_action("receive_clinic_treatment")
	if str(doctor_action.get("type", "")) != "clinic_doctor" or str(doctor_action.get("skill", "")) != "医术":
		push_error("Clinic doctor action should use medical skill")
		quit(1)
		return
	if str(patient_action.get("type", "")) != "clinic_patient":
		push_error("Clinic patient action should be a separate patient-bed action")
		quit(1)
		return

	var doctor_id := "doctor_01"
	var patient_id := "cook_01"
	_get_npc_node(npc_system, doctor_id).set("move_speed", 5.0)
	_get_npc_node(npc_system, patient_id).set("move_speed", 5.0)
	if not action_system.debug_assign_action(doctor_id, "work_clinic_doctor"):
		push_error("Doctor should accept formal clinic duty")
		quit(1)
		return
	if not await _wait_for_active(action_system, time_system, doctor_id, "work_clinic_doctor"):
		push_error("Doctor should physically reach a clinic desk before duty begins")
		quit(1)
		return
	event_bus.logical_time_tick.emit(14400.0, 1.0)
	var doctor_after_study: Dictionary = npc_system.get_npc(doctor_id)
	if int(doctor_after_study.get("skills", {}).get("医术", 0)) < 85:
		push_error("Doctor should slowly improve medical skill while studying without patients")
		quit(1)
		return
	if not _has_skill_event(memory_system.get_npc_daily_events(doctor_id), "clinic_study"):
		push_error("Clinic study should write a medical skill event")
		quit(1)
		return

	npc_system.update_npc_state(patient_id, {"hp": 40, "max_hp": 100, "unconscious": false, "last_action_result": ""})
	if not action_system.debug_assign_action(patient_id, "receive_clinic_treatment"):
		push_error("Injured patient should accept a formal clinic-bed route")
		quit(1)
		return
	if not await _wait_for_active(action_system, time_system, patient_id, "receive_clinic_treatment"):
		push_error("Patient should physically reach and occupy a clinic bed")
		quit(1)
		return
	var money_before := int(resource_system.get_resource("money"))
	event_bus.logical_time_tick.emit(3600.0, 1.0)
	var patient_after_hour: Dictionary = npc_system.get_npc_state(patient_id)
	if int(patient_after_hour.get("hp", 0)) <= 40:
		push_error("Patient should recover HP only after doctor and bed are both active")
		quit(1)
		return
	if int(resource_system.get_resource("money")) >= money_before:
		push_error("Clinic treatment should consume money over time")
		quit(1)
		return
	if not _has_skill_event(memory_system.get_npc_daily_events(doctor_id), "clinic_treatment"):
		push_error("Clinic treatment should grant a small medical skill event")
		quit(1)
		return

	event_bus.logical_time_tick.emit(6.0 * 3600.0, 1.0)
	var patient_after_treatment: Dictionary = npc_system.get_npc_state(patient_id)
	if int(patient_after_treatment.get("hp", 0)) < int(patient_after_treatment.get("max_hp", 100)):
		push_error("Clinic treatment should eventually restore an injured patient to full HP")
		quit(1)
		return
	if str(patient_after_treatment.get("current_action", "")) != "idle":
		push_error("Clinic patient should leave active treatment after full recovery")
		quit(1)
		return
	if _is_workstation_occupied_by(building_system.get_building("clinic").get("workstations", []), patient_id):
		push_error("Clinic patient bed should be released after treatment")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(doctor_id), "healing_completed"):
		push_error("Clinic treatment completion should write a healing_completed event for doctor")
		quit(1)
		return

	var low_skill_id := "stableman_01"
	var high_skill_id := "engineer_01"
	_set_profile_medical_and_intelligence(npc_system, low_skill_id, 10, 4)
	_set_profile_medical_and_intelligence(npc_system, high_skill_id, 80, 8)
	var low_rate: float = action_system._get_clinic_hp_per_hour(low_skill_id)
	var high_rate: float = action_system._get_clinic_hp_per_hour(high_skill_id)
	if high_rate <= low_rate:
		push_error("Medical skill and intelligence should improve clinic treatment speed")
		quit(1)
		return
	var level_one_rate: float = action_system._get_clinic_hp_per_hour(high_skill_id)
	if not building_system.upgrade_building("clinic"):
		push_error("Failed to start clinic upgrade")
		quit(1)
		return
	event_bus.logical_time_tick.emit(100000.0, 1.0)
	var level_two_rate: float = action_system._get_clinic_hp_per_hour(high_skill_id)
	if level_two_rate <= level_one_rate:
		push_error("Clinic level should improve clinic treatment speed")
		quit(1)
		return

	print("T0808 clinic treatment verification passed.")
	quit(0)


func _has_workstation_type(workstations: Array, workstation_type: String) -> bool:
	for raw_workstation in workstations:
		if raw_workstation is Dictionary and str(raw_workstation.get("type", "")) == workstation_type:
			return true
	return false


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


func _is_workstation_occupied_by(workstations: Array, npc_id: String) -> bool:
	for raw_workstation in workstations:
		if raw_workstation is Dictionary and str(raw_workstation.get("occupied_by", "")) == npc_id:
			return true
	return false


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return true
	return false


func _has_skill_event(events: Array, reason: String) -> bool:
	for event in events:
		if not event is Dictionary:
			continue
		if str(event.get("type", "")) != "skill_improved":
			continue
		if str(event.get("payload", {}).get("reason", "")) == reason:
			return true
	return false


func _set_profile_medical_and_intelligence(npc_system: Node, npc_id: String, medical_skill: int, intelligence: int) -> void:
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["医术"] = medical_skill
	profile["skills"] = skills
	var stats: Dictionary = profile.get("stats", {}).duplicate(true)
	stats["intelligence"] = intelligence
	profile["stats"] = stats
	npc_system._profiles[npc_id] = profile
