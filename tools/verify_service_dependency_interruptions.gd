extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await process_frame

	var event_bus := root.get_node_or_null("EventBus")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	if (
		event_bus == null
		or action_system == null
		or building_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or llm_bridge == null
		or daily_plan_system == null
	):
		_fail("Required systems are missing")
		return
	for dependency_failure_id in [
		"clinic_patient_failed_no_doctor",
		"clinic_patient_failed_doctor_left",
		"training_student_failed_no_instructor",
		"training_student_failed_instructor_left",
		"attend_mass_failed_no_leader",
		"attend_mass_failed_leader_left",
		"pray_failed_mass_in_progress",
		"pray_failed_mass_started",
	]:
		if not bool(daily_plan_system.call("_is_failure_result", dependency_failure_id)):
			_fail("DailyPlanSystem did not recognize dependency failure: %s" % dependency_failure_id)
			return
		if str(daily_plan_system.call("_normalize_failure_type", dependency_failure_id)) != "target_unavailable":
			_fail("Dependency failure did not normalize to target_unavailable: %s" % dependency_failure_id)
			return
	daily_plan_system.set_auto_execution_enabled(false)

	if not _verify_chapel_lifecycle(event_bus, action_system, building_system, npc_system, memory_system, llm_bridge):
		return
	if not _verify_clinic_dependency(action_system, building_system, npc_system, memory_system):
		return
	if not _verify_training_dependency(action_system, building_system, npc_system, resource_system, equipment_system, memory_system):
		return

	print("T0043A service dependency interruption verification passed.")
	quit(0)


func _verify_chapel_lifecycle(
	event_bus: Node,
	action_system: Node,
	building_system: Node,
	npc_system: Node,
	memory_system: Node,
	llm_bridge: Node
) -> bool:
	var priest_id := "priest_01"
	var attendee_id := "cook_01"
	var prayer_id := "gardener_01"
	for npc_id in [priest_id, attendee_id, prayer_id]:
		action_system.interrupt_npc_action(npc_id, "t0043a_chapel_setup", true)
		npc_system.debug_enter_location_immediately(npc_id, "chapel")

	var attend_action: Dictionary = action_system.get_action("attend_mass")
	if (
		str(attend_action.get("workstation_type", "")) != "chapel_prayer_seat"
		or str(attend_action.get("required_active_action_id", "")) != "lead_mass"
	):
		_fail("attend_mass must use a prayer seat and require lead_mass")
		return false
	var before_mass_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(attendee_id, {"requires_time_slowdown": false})
	var before_attend := _find_candidate(before_mass_payload.get("allowed_actions", []), "attend_mass")
	if before_attend.is_empty() or bool(before_attend.get("context", {}).get("available_now", true)):
		_fail("attend_mass should remain visible but unavailable before Mass begins")
		return false
	if action_system.debug_assign_action(attendee_id, "attend_mass"):
		_fail("Mass attendance must fail without an active leader")
		return false
	if str(npc_system.get_npc_state(attendee_id).get("last_action_result", "")) != "attend_mass_failed_no_leader":
		_fail("Missing Mass leader should produce attend_mass_failed_no_leader")
		return false

	if not action_system.debug_assign_action(prayer_id, "pray_at_chapel"):
		_fail("Ordinary prayer should start without a priest or Mass")
		return false
	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Eligible priest should start Mass")
		return false
	if str(npc_system.get_npc_state(prayer_id).get("last_action_result", "")) != "pray_failed_mass_started":
		_fail("Starting Mass should interrupt an existing ordinary prayer")
		return false
	if _is_occupied_by(building_system.get_building("chapel").get("workstations", []), prayer_id):
		_fail("Interrupted ordinary prayer should release its prayer seat")
		return false

	if action_system.debug_assign_action(prayer_id, "pray_at_chapel"):
		_fail("Ordinary prayer must fail while Mass is active")
		return false
	if str(npc_system.get_npc_state(prayer_id).get("last_action_result", "")) != "pray_failed_mass_in_progress":
		_fail("Prayer during Mass should expose pray_failed_mass_in_progress")
		return false
	var during_mass_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(attendee_id, {"requires_time_slowdown": false})
	var during_attend := _find_candidate(during_mass_payload.get("allowed_actions", []), "attend_mass")
	var during_prayer := _find_candidate(during_mass_payload.get("allowed_actions", []), "pray_at_chapel")
	if not bool(during_attend.get("context", {}).get("available_now", false)):
		_fail("attend_mass should become available while the priest is leading Mass")
		return false
	if bool(during_prayer.get("context", {}).get("available_now", true)):
		_fail("Ordinary prayer candidate should be unavailable while Mass is active")
		return false
	if not action_system.debug_assign_action(attendee_id, "attend_mass"):
		_fail("NPC should be able to occupy a prayer seat and attend active Mass")
		return false
	if not _is_occupied_by(building_system.get_building("chapel").get("workstations", []), attendee_id):
		_fail("Mass attendee should occupy a prayer seat")
		return false

	event_bus.logical_time_tick.emit(3600.0, 1.0)
	if str(npc_system.get_npc_state(priest_id).get("last_action_result", "")) != "completed_mass":
		_fail("Mass leader should complete after the configured cycle")
		return false
	if str(npc_system.get_npc_state(attendee_id).get("last_action_result", "")) != "completed_mass_attendance":
		_fail("Active attendees should complete together with a normally completed Mass")
		return false
	if _is_occupied_by(building_system.get_building("chapel").get("workstations", []), attendee_id):
		_fail("Completed Mass attendance should release the prayer seat")
		return false
	var attendee_completed := _find_latest_event(memory_system.get_npc_daily_events(attendee_id), "prayer_completed", "attend_mass")
	if attendee_completed.is_empty():
		_fail("Completed Mass attendance should write a structured prayer_completed event")
		return false

	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Priest should be able to start a second Mass for interruption testing")
		return false
	if not action_system.debug_assign_action(attendee_id, "attend_mass"):
		_fail("Attendee should join the second Mass")
		return false
	action_system.interrupt_npc_action(priest_id, "t0043a_mass_interrupted", true)
	if str(npc_system.get_npc_state(attendee_id).get("last_action_result", "")) != "attend_mass_failed_leader_left":
		_fail("Interrupting the leader should immediately fail every Mass attendee")
		return false
	if _is_occupied_by(building_system.get_building("chapel").get("workstations", []), attendee_id):
		_fail("Failed Mass attendance should release the prayer seat")
		return false
	var attendee_failed := _find_latest_event(memory_system.get_npc_daily_events(attendee_id), "prayer_failed", "attend_mass")
	if attendee_failed.is_empty():
		_fail("Interrupted Mass attendance should write a structured prayer_failed event")
		return false
	return true


func _verify_clinic_dependency(
	action_system: Node,
	building_system: Node,
	npc_system: Node,
	memory_system: Node
) -> bool:
	var doctor_id := "doctor_01"
	var patient_id := "gardener_01"
	for npc_id in [doctor_id, patient_id]:
		action_system.interrupt_npc_action(npc_id, "t0043a_clinic_setup", true)
	npc_system.debug_enter_location_immediately(doctor_id, "garden")
	npc_system.debug_enter_location_immediately(patient_id, "stable")
	npc_system.apply_damage_to_npc(patient_id, 20, "guard_officer", "private")

	# A paired plan is dispatched provider-first, but both NPCs can still be in
	# transit. The dependent waits instead of producing a false no-doctor failure.
	if not action_system.debug_assign_action(doctor_id, "work_clinic_doctor"):
		_fail("Travelling doctor should accept a pending clinic duty")
		return false
	if not action_system.debug_assign_action(patient_id, "receive_clinic_treatment"):
		_fail("Patient should wait while the paired doctor is travelling")
		return false
	if (
		str(action_system.get_pending_action_id(doctor_id)) != "work_clinic_doctor"
		or str(action_system.get_pending_action_id(patient_id)) != "receive_clinic_treatment"
	):
		_fail("Travelling clinic pair did not preserve provider/dependent pending actions")
		return false
	npc_system.debug_enter_location_immediately(patient_id, "clinic")
	if str(action_system.get_pending_action_id(patient_id)) != "receive_clinic_treatment":
		_fail("Patient should keep waiting after arriving before the doctor")
		return false
	npc_system.debug_enter_location_immediately(doctor_id, "clinic")
	if (
		str(action_system.get_active_action_id(doctor_id)) != "work_clinic_doctor"
		or str(action_system.get_active_action_id(patient_id)) != "receive_clinic_treatment"
	):
		_fail("Doctor arrival should start the waiting clinic pair")
		return false
	action_system.interrupt_npc_action(doctor_id, "t0043a_travel_pair_cleanup", true)
	action_system.interrupt_npc_action(patient_id, "t0043a_travel_pair_cleanup", true)
	for npc_id in [doctor_id, patient_id]:
		npc_system.debug_enter_location_immediately(npc_id, "clinic")

	if action_system.debug_assign_action(patient_id, "receive_clinic_treatment"):
		_fail("Clinic treatment must fail when no doctor is active")
		return false
	if str(npc_system.get_npc_state(patient_id).get("last_action_result", "")) != "clinic_patient_failed_no_doctor":
		_fail("Missing doctor should produce clinic_patient_failed_no_doctor")
		return false
	if not action_system.debug_assign_action(doctor_id, "work_clinic_doctor"):
		_fail("Doctor should start clinic duty")
		return false
	if not action_system.debug_assign_action(patient_id, "receive_clinic_treatment"):
		_fail("Injured patient should start treatment while a doctor is active")
		return false
	action_system.interrupt_npc_action(doctor_id, "t0043a_doctor_left", true)
	if str(npc_system.get_npc_state(patient_id).get("last_action_result", "")) != "clinic_patient_failed_doctor_left":
		_fail("Last doctor leaving should immediately fail active patients")
		return false
	var failure_context: Dictionary = npc_system.get_npc_state(patient_id).get("last_action_failure_context", {})
	if str(failure_context.get("required_active_action_id", "")) != "work_clinic_doctor":
		_fail("Clinic interruption should preserve its provider dependency in failure context")
		return false
	if _is_occupied_by(building_system.get_building("clinic").get("workstations", []), patient_id):
		_fail("Failed clinic treatment should release the patient bed")
		return false
	if _find_latest_event(memory_system.get_npc_daily_events(patient_id), "work_failed", "receive_clinic_treatment").is_empty():
		_fail("Doctor departure should write a patient work_failed event")
		return false
	return true


func _verify_training_dependency(
	action_system: Node,
	building_system: Node,
	npc_system: Node,
	resource_system: Node,
	equipment_system: Node,
	memory_system: Node
) -> bool:
	var instructor_id := "veteran_deputy_01"
	var student_id := "stableman_01"
	for npc_id in [instructor_id, student_id]:
		action_system.interrupt_npc_action(npc_id, "t0043a_training_setup", true)
		npc_system.debug_enter_location_immediately(npc_id, "training_ground")
	npc_system.set_npc_recruited(student_id, true)
	resource_system.add_resource("item_sword_shield", 1)
	resource_system.add_resource("item_bow", 1)
	var instructor_equip: Dictionary = equipment_system.equip_npc_main_weapon(instructor_id, "sword_shield", "private")
	var student_equip: Dictionary = equipment_system.equip_npc_main_weapon(student_id, "bow", "private")
	if not bool(instructor_equip.get("ok", false)) or not bool(student_equip.get("ok", false)):
		_fail("Failed to equip training dependency actors")
		return false

	if action_system.debug_assign_action(student_id, "receive_weapon_training"):
		_fail("Training must fail when no instructor is active")
		return false
	if str(npc_system.get_npc_state(student_id).get("last_action_result", "")) != "training_student_failed_no_instructor":
		_fail("Missing instructor should produce training_student_failed_no_instructor")
		return false
	if not action_system.debug_assign_action(instructor_id, "work_training_instructor"):
		_fail("Equipped instructor should start duty")
		return false
	if not action_system.debug_assign_action(student_id, "receive_weapon_training"):
		_fail("Equipped student should start while an instructor is active")
		return false
	action_system.interrupt_npc_action(instructor_id, "t0043a_instructor_left", true)
	if str(npc_system.get_npc_state(student_id).get("last_action_result", "")) != "training_student_failed_instructor_left":
		_fail("Last instructor leaving should immediately fail active trainees")
		return false
	var failure_context: Dictionary = npc_system.get_npc_state(student_id).get("last_action_failure_context", {})
	if str(failure_context.get("required_active_action_id", "")) != "work_training_instructor":
		_fail("Training interruption should preserve its provider dependency in failure context")
		return false
	if _is_occupied_by(building_system.get_building("training_ground").get("workstations", []), student_id):
		_fail("Failed training should release the practice slot")
		return false
	if _find_latest_event(memory_system.get_npc_daily_events(student_id), "work_failed", "receive_weapon_training").is_empty():
		_fail("Instructor departure should write a trainee work_failed event")
		return false
	return true


func _find_candidate(raw_candidates, action_id: String) -> Dictionary:
	if not raw_candidates is Array:
		return {}
	for raw_candidate in raw_candidates:
		if raw_candidate is Dictionary and str(raw_candidate.get("action_id", "")) == action_id:
			return raw_candidate
	return {}


func _is_occupied_by(raw_workstations, npc_id: String) -> bool:
	if not raw_workstations is Array:
		return false
	for raw_workstation in raw_workstations:
		if raw_workstation is Dictionary and str(raw_workstation.get("occupied_by", "")) == npc_id:
			return true
	return false


func _find_latest_event(events: Array, event_type: String, action_id: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var raw_event = events[index]
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var payload: Dictionary = event.get("payload", {})
		if str(event.get("type", "")) == event_type and str(payload.get("action_id", "")) == action_id:
			return event
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
