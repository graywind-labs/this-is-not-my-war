extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	var startup_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if startup_plan_system != null:
		startup_plan_system.set_auto_execution_enabled(false)
	var startup_llm_bridge := main.get_node_or_null("Systems/LLMBridge")
	if (
		startup_llm_bridge != null
		and startup_llm_bridge.has_method("set_backend_base_url")
	):
		startup_llm_bridge.set_backend_base_url("http://127.0.0.1:1")
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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
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
		or time_system == null
	):
		_fail("Required systems are missing")
		return
	for dependency_failure_id in [
		"clinic_patient_failed_no_doctor",
		"clinic_patient_failed_doctor_left",
		"training_student_failed_no_instructor",
		"training_student_failed_instructor_left",
	]:
		if not bool(daily_plan_system.call("_is_failure_result", dependency_failure_id)):
			_fail("DailyPlanSystem did not recognize dependency failure: %s" % dependency_failure_id)
			return
		if str(daily_plan_system.call("_normalize_failure_type", dependency_failure_id)) != "target_unavailable":
			_fail("Dependency failure did not normalize to target_unavailable: %s" % dependency_failure_id)
			return
	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_paused(false)

	if not await _verify_chapel_lifecycle(
		event_bus,
		action_system,
		building_system,
		npc_system,
		memory_system,
		llm_bridge,
		daily_plan_system
	):
		return
	if not await _verify_clinic_dependency(action_system, building_system, npc_system, memory_system, time_system):
		return
	if not await _verify_training_dependency(action_system, building_system, npc_system, resource_system, equipment_system, memory_system, time_system):
		return

	print("T0043A service dependency interruption verification passed.")
	quit(0)


func _verify_chapel_lifecycle(
	event_bus: Node,
	action_system: Node,
	building_system: Node,
	npc_system: Node,
	memory_system: Node,
	llm_bridge: Node,
	daily_plan_system: Node
) -> bool:
	var priest_id := "priest_01"
	var prayer_id := "gardener_01"
	var observer_id := "cook_01"
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if time_system == null:
		_fail("TimeSystem is missing from chapel lifecycle verification")
		return false
	for npc_id in [priest_id, prayer_id, observer_id]:
		action_system.interrupt_npc_action(npc_id, "t0043a_chapel_setup", true)
		npc_system.debug_enter_location_immediately(npc_id, "chapel")

	if action_system.get_action_ids().has("attend_mass"):
		_fail("attend_mass must be removed from the runtime action catalog")
		return false
	var before_mass_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(prayer_id, {"requires_time_slowdown": false})
	if not _find_candidate(before_mass_payload.get("allowed_actions", []), "attend_mass").is_empty():
		_fail("attend_mass must not appear in allowed_actions")
		return false
	var prayer_candidate := _find_candidate(before_mass_payload.get("allowed_actions", []), "pray_at_chapel")
	if prayer_candidate.is_empty() or not bool(prayer_candidate.get("context", {}).get("available_now", false)):
		_fail("Merged prayer must be available without a Mass leader")
		return false

	if not action_system.debug_assign_action(prayer_id, "pray_at_chapel"):
		_fail("Prayer should start without a priest or Mass")
		return false
	if not await _wait_for_active(action_system, time_system, prayer_id, "pray_at_chapel"):
		_fail("Prayer actor did not physically reach a chapel seat")
		return false
	var personal_snapshot: Dictionary = action_system.get_runtime_action_snapshot(prayer_id)
	if (
		str(personal_snapshot.get("action_id", "")) != "pray_at_chapel"
		or str(personal_snapshot.get("prayer_mode", "")) != "personal_prayer"
	):
		_fail("Prayer without an active Mass should begin as personal prayer")
		return false
	event_bus.logical_time_tick.emit(600.0, 1.0)
	var elapsed_before_mass := float(action_system.get_runtime_action_snapshot(prayer_id).get("elapsed_seconds", -1.0))

	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Eligible priest should start Mass")
		return false
	if not await _wait_for_active(action_system, time_system, priest_id, "lead_mass"):
		_fail("Eligible priest did not physically reach the altar")
		return false
	var joined_snapshot: Dictionary = action_system.get_runtime_action_snapshot(prayer_id)
	if str(joined_snapshot.get("prayer_mode", "")) != "mass_attendance":
		_fail("Starting Mass should convert active prayer to Mass attendance")
		return false
	if float(joined_snapshot.get("elapsed_seconds", -2.0)) < elapsed_before_mass:
		_fail("Joining Mass must preserve elapsed prayer time accrued while the leader travelled")
		return false
	if not _is_occupied_by(building_system.get_building("chapel").get("workstations", []), prayer_id):
		_fail("Joining Mass must keep the same prayer seat")
		return false
	if not npc_system.get_npc_state(prayer_id).get("last_action_failure_context", {}).is_empty():
		_fail("Joining Mass must not create an action failure")
		return false
	var joined_event := _find_latest_event(
		memory_system.get_npc_daily_events(prayer_id),
		"prayer_joined_mass",
		"pray_at_chapel"
	)
	if joined_event.is_empty() or str(joined_event.get("visibility", "")) != "local_public":
		_fail("Joining Mass should write a local-public structured event")
		return false
	if _find_latest_event(
		memory_system.get_npc_witness_events(observer_id),
		"prayer_joined_mass",
		"pray_at_chapel"
	).is_empty():
		_fail("Joining Mass should broadcast to eligible NPCs already in the chapel")
		return false

	action_system.interrupt_npc_action(priest_id, "dialogue_interrupted", true)
	var resumed_snapshot: Dictionary = action_system.get_runtime_action_snapshot(prayer_id)
	if str(resumed_snapshot.get("prayer_mode", "")) != "personal_prayer":
		_fail("Stopping Mass should resume personal prayer")
		return false
	if absf(float(resumed_snapshot.get("elapsed_seconds", -2.0)) - float(joined_snapshot.get("elapsed_seconds", -3.0))) > 5.0:
		_fail("Mass interruption must not reset prayer progress")
		return false
	if not _is_occupied_by(building_system.get_building("chapel").get("workstations", []), prayer_id):
		_fail("Resuming personal prayer must keep the prayer seat")
		return false
	var resumed_event := _find_latest_event(
		memory_system.get_npc_daily_events(prayer_id),
		"prayer_resumed_alone",
		"pray_at_chapel"
	)
	if resumed_event.is_empty():
		_fail("Mass interruption should write a prayer_resumed_alone event")
		return false
	var interrupted_payload: Dictionary = resumed_event.get("payload", {})
	var interrupted_summary := str(resumed_event.get("summary", ""))
	if (
		str(interrupted_payload.get("trigger", "")) != "mass_leader_stopped"
		or str(interrupted_payload.get("provider_stop_reason", ""))
		!= "dialogue_interrupted"
		or not interrupted_summary.contains("主持中断")
	):
		_fail("Dialogue interruption should preserve its interruption trigger and wording")
		return false
	if _find_latest_event(
		memory_system.get_npc_witness_events(observer_id),
		"prayer_resumed_alone",
		"pray_at_chapel"
	).is_empty():
		_fail("Resuming personal prayer should broadcast to eligible NPCs in the chapel")
		return false

	action_system.interrupt_npc_action(prayer_id, "t0098_chapel_second_scenario", true)
	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Priest should start Mass before a new prayer arrives")
		return false
	if not await _wait_for_active(action_system, time_system, priest_id, "lead_mass"):
		_fail("Priest did not reach the altar before the new prayer")
		return false
	event_bus.logical_time_tick.emit(600.0, 1.0)
	if not action_system.debug_assign_action(prayer_id, "pray_at_chapel"):
		_fail("Merged prayer should start while Mass is already active")
		return false
	if not await _wait_for_active(action_system, time_system, prayer_id, "pray_at_chapel"):
		_fail("Prayer did not physically reach a seat during Mass")
		return false
	var started_during_mass: Dictionary = action_system.get_runtime_action_snapshot(prayer_id)
	if (
		str(started_during_mass.get("action_id", "")) != "pray_at_chapel"
		or str(started_during_mass.get("prayer_mode", "")) != "mass_attendance"
	):
		_fail("Prayer started during Mass should immediately become Mass attendance")
		return false
	var attendee_elapsed_before_completion := float(started_during_mass.get("elapsed_seconds", 0.0))
	event_bus.logical_time_tick.emit(3000.0, 1.0)
	if str(npc_system.get_npc_state(priest_id).get("last_action_result", "")) != "completed_mass":
		_fail("Mass leader should complete after its configured duration")
		return false
	var after_normal_mass: Dictionary = action_system.get_runtime_action_snapshot(prayer_id)
	if (
		str(after_normal_mass.get("phase", "")) != "active"
		or str(after_normal_mass.get("prayer_mode", "")) != "personal_prayer"
		or absf(float(after_normal_mass.get("elapsed_seconds", -1.0)) - (attendee_elapsed_before_completion + 3000.0)) > 5.0
	):
		_fail("Normal Mass completion should resume the unfinished original prayer")
		return false
	var normal_completion_event := _find_latest_event(
		memory_system.get_npc_daily_events(prayer_id),
		"prayer_resumed_alone",
		"pray_at_chapel"
	)
	var normal_completion_payload: Dictionary = normal_completion_event.get(
		"payload",
		{}
	)
	var normal_completion_summary := str(normal_completion_event.get("summary", ""))
	if (
		normal_completion_event.is_empty()
		or str(normal_completion_payload.get("trigger", "")) != "mass_completed"
		or not normal_completion_summary.contains("弥撒结束")
		or normal_completion_summary.contains("中断")
	):
		_fail("Normal Mass completion should record the return to personal prayer")
		return false

	action_system.interrupt_npc_action(prayer_id, "t0105b_plan_boundary_setup", true)
	if not action_system.debug_assign_action(prayer_id, "pray_at_chapel"):
		_fail("Prayer should restart for the planned Mass boundary scenario")
		return false
	if not await _wait_for_active(action_system, time_system, prayer_id, "pray_at_chapel"):
		_fail("Boundary prayer did not physically reach a seat")
		return false
	event_bus.logical_time_tick.emit(1800.0, 1.0)
	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Priest should start Mass for the planned boundary scenario")
		return false
	if not await _wait_for_active(action_system, time_system, priest_id, "lead_mass"):
		_fail("Boundary Mass leader did not physically reach the altar")
		return false
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		_fail("GameState is missing")
		return false
	var current_hour := int(game_state.current_hour)
	if not daily_plan_system.set_npc_daily_plan(
		priest_id,
		_make_current_plan(current_hour, "idle", "idle", ""),
		false,
		"verify_t0105b_mass_boundary"
	):
		_fail("Could not install the post-Mass plan")
		return false
	if not daily_plan_system.set_npc_daily_plan(
		prayer_id,
		_make_current_plan(current_hour, "work_garden", "work", "garden"),
		false,
		"verify_t0105b_mass_attendee_boundary"
	):
		_fail("Could not install the post-Mass attendee plan")
		return false
	daily_plan_system.set_auto_execution_enabled(true)
	var leader_boundary_result: Dictionary = daily_plan_system.execute_current_plan_for_npc(
		priest_id,
		true,
		false,
		true
	)
	var attendee_boundary_result: Dictionary = (
		daily_plan_system.execute_current_plan_for_npc(
			prayer_id,
			true,
			false,
			true
		)
	)
	if (
		str(leader_boundary_result.get("status", ""))
		!= "deferred_until_mass_completed"
		or str(attendee_boundary_result.get("status", ""))
		!= "deferred_until_mass_completed"
	):
		_fail("The planned Mass boundary should defer both plans: %s / %s" % [
			JSON.stringify(leader_boundary_result),
			JSON.stringify(attendee_boundary_result),
		])
		return false
	var boundary_resumed_count_before := _count_events(
		memory_system.get_npc_daily_events(prayer_id),
		"prayer_resumed_alone",
		"pray_at_chapel"
	)
	var leader_during_boundary: Dictionary = action_system.get_runtime_action_snapshot(
		priest_id
	)
	var attendee_during_boundary: Dictionary = action_system.get_runtime_action_snapshot(
		prayer_id
	)
	if (
		str(leader_during_boundary.get("action_id", "")) != "lead_mass"
		or str(attendee_during_boundary.get("action_id", ""))
		!= "pray_at_chapel"
		or str(attendee_during_boundary.get("prayer_mode", ""))
		!= "mass_attendance"
	):
		_fail("The hour boundary must preserve the active Mass and its attendee")
		return false
	event_bus.logical_time_tick.emit(1800.0, 1.0)
	var attendee_at_own_duration: Dictionary = action_system.get_runtime_action_snapshot(
		prayer_id
	)
	if (
		str(attendee_at_own_duration.get("phase", "")) != "active"
		or str(attendee_at_own_duration.get("prayer_mode", ""))
		!= "mass_attendance"
		or not is_equal_approx(
			float(attendee_at_own_duration.get("elapsed_seconds", -1.0)),
			3600.0
		)
		or _count_events(
			memory_system.get_npc_daily_events(prayer_id),
			"prayer_resumed_alone",
			"pray_at_chapel"
		) != boundary_resumed_count_before
	):
		_fail("An attendee whose prayer timer expires must remain in Mass")
		return false
	event_bus.logical_time_tick.emit(1800.0, 1.0)
	await process_frame
	await process_frame
	daily_plan_system.set_auto_execution_enabled(false)
	if (
		action_system.has_active_action(priest_id)
		or str(npc_system.get_npc_state(priest_id).get("current_action", ""))
		!= "idle"
		or action_system.get_pending_action_id(prayer_id) != "work_garden"
	):
		_fail("Deferred plans should execute only after Mass truly completes")
		return false
	var completed_attendee_snapshot: Dictionary = action_system.get_runtime_action_snapshot(
		prayer_id
	)
	if (
		str(completed_attendee_snapshot.get("phase", "")) != "pending"
		or str(completed_attendee_snapshot.get("action_id", "")) != "work_garden"
		or _is_occupied_by(
			building_system.get_building("chapel").get("workstations", []),
			prayer_id
		)
	):
		_fail("The attendee should release prayer and begin the deferred work plan")
		return false
	var boundary_resumed_event := _find_latest_event(
		memory_system.get_npc_daily_events(prayer_id),
		"prayer_resumed_alone",
		"pray_at_chapel"
	)
	var boundary_payload: Dictionary = boundary_resumed_event.get("payload", {})
	var boundary_summary := str(boundary_resumed_event.get("summary", ""))
	if (
		_count_events(
			memory_system.get_npc_daily_events(prayer_id),
			"prayer_resumed_alone",
			"pray_at_chapel"
		) != boundary_resumed_count_before + 1
		or str(boundary_payload.get("trigger", "")) != "mass_completed"
		or not boundary_summary.contains("弥撒结束")
		or boundary_summary.contains("中断")
	):
		_fail("Natural completion after the boundary should use Mass-ended wording")
		return false
	if _find_latest_event(
		memory_system.get_npc_daily_events(prayer_id),
		"prayer_completed",
		"pray_at_chapel"
	).is_empty():
		_fail("The expired attendee prayer should complete after Mass ends")
		return false
	if _find_latest_event(
		memory_system.get_npc_daily_events(priest_id),
		"prayer_completed",
		"lead_mass"
	).is_empty():
		_fail("The protected Mass leader should finish normally")
		return false

	action_system.interrupt_npc_action(observer_id, "t0105b_ordinary_boundary_setup", true)
	if not npc_system.debug_enter_location_immediately(observer_id, "dining_hall"):
		_fail("Could not place the ordinary boundary actor")
		return false
	if not action_system.debug_assign_action(observer_id, "work_dining_hall"):
		_fail("Could not start ordinary work for boundary isolation")
		return false
	if not await _wait_for_active(action_system, time_system, observer_id, "work_dining_hall"):
		_fail("Ordinary boundary work did not physically reach its workstation")
		return false
	if not daily_plan_system.set_npc_daily_plan(
		observer_id,
		_make_current_plan(current_hour, "idle", "idle", ""),
		false,
		"verify_t0105b_ordinary_boundary"
	):
		_fail("Could not install the ordinary post-boundary plan")
		return false
	var ordinary_boundary_result: Dictionary = (
		daily_plan_system.execute_current_plan_for_npc(
			observer_id,
			true,
			false,
			true
		)
	)
	if (
		not bool(ordinary_boundary_result.get("ok", false))
		or str(ordinary_boundary_result.get("status", "")) != "started"
		or action_system.has_active_action(observer_id)
		or str(npc_system.get_npc_state(observer_id).get("current_action", ""))
		!= "idle"
	):
		_fail("The Mass boundary protection must not preserve ordinary work")
		return false
	return true


func _verify_clinic_dependency(
	action_system: Node,
	building_system: Node,
	npc_system: Node,
	memory_system: Node,
	time_system: Node
) -> bool:
	var doctor_id := "doctor_01"
	var patient_id := "gardener_01"
	for npc_id in [doctor_id, patient_id]:
		action_system.interrupt_npc_action(npc_id, "t0043a_clinic_setup", true)
	var doctor_node := _get_npc_node(npc_system, doctor_id)
	var patient_node := _get_npc_node(npc_system, patient_id)
	doctor_node.set("move_speed", 2.0)
	patient_node.set("move_speed", 8.0)
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
	if not await _wait_for_formal_workstation_arrival(action_system, npc_system, time_system, patient_id, "receive_clinic_treatment"):
		_fail("Patient did not physically reach the reserved clinic bed")
		return false
	if (
		str(action_system.get_pending_action_id(patient_id)) != "receive_clinic_treatment"
		or str(npc_system.get_npc_state(patient_id).get("physical_location_phase", "")) != "workstation"
	):
		_fail("Patient should keep waiting after arriving before the doctor")
		return false
	if not await _wait_for_active(action_system, time_system, doctor_id, "work_clinic_doctor"):
		_fail("Doctor did not physically reach the reserved clinic desk")
		return false
	if not await _wait_for_active(action_system, time_system, patient_id, "receive_clinic_treatment", 120):
		_fail("Patient did not commit after the doctor became active")
		return false
	if (
		str(action_system.get_active_action_id(doctor_id)) != "work_clinic_doctor"
		or str(action_system.get_active_action_id(patient_id)) != "receive_clinic_treatment"
	):
		_fail("Doctor arrival should start the waiting clinic pair")
		return false
	action_system.interrupt_npc_action(doctor_id, "t0043a_travel_pair_cleanup", true)
	action_system.interrupt_npc_action(patient_id, "t0043a_travel_pair_cleanup", true)

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
	doctor_node.set("move_speed", 5.0)
	patient_node.set("move_speed", 5.0)
	if not await _wait_for_active(action_system, time_system, doctor_id, "work_clinic_doctor"):
		_fail("Doctor should physically return to clinic duty")
		return false
	if not await _wait_for_active(action_system, time_system, patient_id, "receive_clinic_treatment"):
		_fail("Injured patient should physically return to a clinic bed")
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


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		if str(action_system.get_active_action_id(npc_id)) == action_id:
			return true
	return false


func _wait_for_formal_workstation_arrival(action_system: Node, npc_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if (
			str(action_system.get_pending_action_id(npc_id)) == action_id
			and str(state.get("physical_location_phase", "")) == "workstation"
		):
			return true
	return false


func _verify_training_dependency(
	action_system: Node,
	building_system: Node,
	npc_system: Node,
	resource_system: Node,
	equipment_system: Node,
	memory_system: Node,
	time_system: Node
) -> bool:
	var instructor_id := "veteran_deputy_01"
	var student_id := "stableman_01"
	for npc_id in [instructor_id, student_id]:
		action_system.interrupt_npc_action(npc_id, "t0043a_training_setup", true)
		npc_system.debug_enter_location_immediately(npc_id, "training_ground")
		_get_npc_node(npc_system, npc_id).set("move_speed", 5.0)
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
		_fail("Equipped student should reserve a practice slot while the instructor is travelling")
		return false
	if not await _wait_for_active(action_system, time_system, instructor_id, "work_training_instructor"):
		_fail("Training instructor did not physically reach the formal command post")
		return false
	if not await _wait_for_active(action_system, time_system, student_id, "receive_weapon_training"):
		_fail("Training student did not physically reach the reserved practice slot")
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


func _make_current_plan(
	current_hour: int,
	current_action_id: String,
	current_action_kind: String,
	current_location_id: String
) -> Array:
	var plan: Array = []
	for hour in range(24):
		var is_current_hour := hour == current_hour
		plan.append({
			"hour": hour,
			"action_kind": current_action_kind if is_current_hour else "idle",
			"action_id": current_action_id if is_current_hour else "idle",
			"location_id": current_location_id if is_current_hour else "",
			"target_id": "",
			"priority": 50 if is_current_hour else 40,
			"reason": "T0105B planned Mass boundary verification",
			"dialogue_goal": "",
			"source": "verify_t0105b_mass_boundary",
		})
	return plan


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


func _count_events(events: Array, event_type: String, action_id: String) -> int:
	var count := 0
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var payload: Dictionary = event.get("payload", {})
		if (
			str(event.get("type", "")) == event_type
			and str(payload.get("action_id", "")) == action_id
		):
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
