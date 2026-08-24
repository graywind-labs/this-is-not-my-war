extends SceneTree

const DOCTOR_ID := "doctor_01"
const PATIENT_ID := "cook_01"
const BUILDING_ID := "clinic"
const DOCTOR_ACTION_ID := "work_clinic_doctor"
const PATIENT_ACTION_ID := "receive_clinic_treatment"
const DOCTOR_STATION_ID := "doctor_desk_01"
const PATIENT_STATION_ID := "treatment_bed_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var doctor_button := gm_window.find_child("FormalClinicDoctorButton", true, false) as Button if gm_window != null else null
	var patient_button := gm_window.find_child("FormalClinicPatientButton", true, false) as Button if gm_window != null else null
	var lina := _get_npc_node(npc_system, DOCTOR_ID) if npc_system != null else null
	var bruno := _get_npc_node(npc_system, PATIENT_ID) if npc_system != null else null
	if [action_system, npc_system, building_system, resource_system, time_system, gm_panel, gm_window, doctor_button, patient_button, lina, bruno].has(null):
		_fail("A5-P5g runtime dependencies unavailable")
		return

	time_system.set_current_time(1, 7, 2, 0)
	time_system.set_paused(false)
	lina.set("move_speed", 5.0)
	bruno.set("move_speed", 5.0)
	if int(resource_system.get_resource("money")) < 20:
		resource_system.add_resource("money", 20 - int(resource_system.get_resource("money")))
	npc_system.update_npc_state(DOCTOR_ID, {
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_a5_p5g_doctor_ready"
	})
	npc_system.update_npc_state(PATIENT_ID, {
		"hp": 10,
		"max_hp": 100,
		"unconscious": false,
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_a5_p5g_patient_ready"
	})

	var doctor_action: Dictionary = action_system.get_action(DOCTOR_ACTION_ID)
	var patient_action: Dictionary = action_system.get_action(PATIENT_ACTION_ID)
	if (
		not bool(doctor_action.get("formal_spatial_route", false))
		or bool(doctor_action.get("formal_preflight_input_resources", true))
		or not bool(patient_action.get("formal_spatial_route", false))
	):
		_fail("Clinic actions do not expose the formal route and study-without-prepaid-money contract")
		return

	# Exercise the visible entries in provider-first order. The patient is allowed
	# to reach the bed while Lina is still travelling, but HP and money stay frozen
	# until both physical commitments are active.
	gm_window.visible = true
	doctor_button.pressed.emit()
	await process_frame
	var pending_doctor_art: Dictionary = lina.debug_get_character_art_snapshot()
	if (
		gm_window.visible
		or str(action_system.get_runtime_action_snapshot(DOCTOR_ID).get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, DOCTOR_STATION_ID, DOCTOR_ID)
		or not lina.visible
		or lina.global_position.x < 900.0
	):
		_fail("Lina's GM entry did not start a reservation-only visible clinic route: %s" % JSON.stringify({
			"runtime": action_system.get_runtime_action_snapshot(DOCTOR_ID),
			"formal": npc_system.get_formal_workstation_action_snapshot(DOCTOR_ID),
			"state": npc_system.get_npc_state(DOCTOR_ID),
			"station": _get_workstation(building_system, DOCTOR_STATION_ID),
			"gm_visible": gm_window.visible,
			"npc_visible": lina.visible,
			"position": lina.global_position
		}))
		return
	if (
		bool(pending_doctor_art.get("medical_book_visible", true))
		or bool(pending_doctor_art.get("medical_bandage_visible", true))
		or not bool(pending_doctor_art.get("medical_satchel_visible", false))
	):
		_fail("Lina exposed clinic-duty props before physically reaching the doctor desk: %s" % JSON.stringify(pending_doctor_art))
		return

	gm_window.visible = true
	patient_button.pressed.emit()
	await process_frame
	if (
		gm_window.visible
		or str(action_system.get_runtime_action_snapshot(PATIENT_ID).get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, PATIENT_STATION_ID, PATIENT_ID)
		or not bruno.visible
		or bruno.global_position.x < 900.0
	):
		_fail("Bruno's GM entry did not start a reservation-only visible patient-bed route")
		return
	var pending_hp := int(npc_system.get_npc_state(PATIENT_ID).get("hp", 0))
	var pending_money := int(resource_system.get_resource("money"))
	action_system._on_logical_time_tick(600.0, 1.0)
	if (
		int(npc_system.get_npc_state(PATIENT_ID).get("hp", 0)) != pending_hp
		or int(resource_system.get_resource("money")) != pending_money
	):
		_fail("Clinic treatment changed HP or money before both actors physically committed")
		return

	if not await _wait_for_active(action_system, time_system, DOCTOR_ID, DOCTOR_ACTION_ID):
		_fail("Lina did not physically reach the first doctor desk")
		return
	if not await _wait_for_active(action_system, time_system, PATIENT_ID, PATIENT_ACTION_ID):
		_fail("Bruno did not physically reach and claim the first clinic bed")
		return
	await physics_frame

	var doctor_state: Dictionary = npc_system.get_npc_state(DOCTOR_ID)
	var patient_state: Dictionary = npc_system.get_npc_state(PATIENT_ID)
	var doctor_art: Dictionary = lina.debug_get_character_art_snapshot()
	var attachment: Dictionary = bruno.debug_get_spatial_attachment_snapshot()
	if (
		str(doctor_state.get("current_location", "")) != BUILDING_ID
		or str(doctor_state.get("current_workstation_id", "")) != DOCTOR_STATION_ID
		or str(doctor_state.get("physical_location_phase", "")) not in ["occupant_anchor", "clinic_round_path", "clinic_bedside"]
		or not _workstation_occupied_by(building_system, DOCTOR_STATION_ID, DOCTOR_ID)
	):
		_fail("Doctor arrival did not atomically commit the first clinic desk")
		return
	if (
		str(patient_state.get("current_location", "")) != BUILDING_ID
		or str(patient_state.get("current_workstation_id", "")) != PATIENT_STATION_ID
		or str(patient_state.get("physical_location_phase", "")) != "occupant_anchor"
		or not _workstation_occupied_by(building_system, PATIENT_STATION_ID, PATIENT_ID)
		or not bool(attachment.get("active", false))
		or str(attachment.get("pose", "")) != "lying_supine"
		or not bool(attachment.get("body_collision_disabled", false))
		or not bool(attachment.get("interaction_enabled", false))
	):
		_fail("Patient occupancy did not mount Bruno onto the real bed anchor: %s" % JSON.stringify(attachment))
		return
	var doctor_visual_state := str(doctor_art.get("desired_state", ""))
	var valid_duty_visual := doctor_visual_state in ["seated_study", "walk", "run", "medical_treatment"]
	var valid_duty_prop := (
		(doctor_visual_state == "seated_study" and bool(doctor_art.get("medical_book_visible", false)) and not bool(doctor_art.get("medical_bandage_visible", true)))
		or (doctor_visual_state == "medical_treatment" and bool(doctor_art.get("medical_bandage_visible", false)) and not bool(doctor_art.get("medical_book_visible", true)))
		or (doctor_visual_state in ["walk", "run"] and not bool(doctor_art.get("medical_book_visible", true)) and not bool(doctor_art.get("medical_bandage_visible", true)))
	)
	if (
		str(doctor_art.get("appearance_id", "")) != "lina_doctor_chibi_v1"
		or not valid_duty_visual
		or not valid_duty_prop
		or not bool(doctor_art.get("medical_satchel_visible", false))
		or bool(doctor_art.get("hammer_visible", true))
	):
		_fail("Lina's seated-study / bedside-round presentation contract is not active: %s" % JSON.stringify(doctor_art))
		return
	if float(action_system.get_clinic_team_hp_per_hour()) <= 0.0:
		_fail("Active clinic doctors do not contribute an authoritative team healing rate")
		return

	var hp_before_treatment := int(patient_state.get("hp", 0))
	var money_before_treatment := int(resource_system.get_resource("money"))
	action_system._on_logical_time_tick(600.0, 1.0)
	var hp_after_short_tick := int(npc_system.get_npc_state(PATIENT_ID).get("hp", 0))
	if hp_after_short_tick <= hp_before_treatment or int(resource_system.get_resource("money")) != money_before_treatment:
		_fail("Active clinic treatment did not heal before its first cost interval, or charged too early")
		return
	action_system._on_logical_time_tick(1201.0, 1.0)
	if (
		int(npc_system.get_npc_state(PATIENT_ID).get("hp", 0)) <= hp_after_short_tick
		or int(resource_system.get_resource("money")) >= money_before_treatment
	):
		_fail("Clinic treatment did not continue healing and charge money at the 1800-second interval")
		return

	gm_panel._stop_formal_clinic_work()
	await process_frame
	await physics_frame
	if (
		str(npc_system.get_npc_state(PATIENT_ID).get("last_action_result", "")) != "clinic_patient_failed_doctor_left"
		or bool(npc_system.get_formal_workstation_action_snapshot(DOCTOR_ID).get("active", true))
		or bool(npc_system.get_formal_workstation_action_snapshot(PATIENT_ID).get("active", true))
		or not _workstation_is_clear(building_system, DOCTOR_STATION_ID)
		or not _workstation_is_clear(building_system, PATIENT_STATION_ID)
		or bool(bruno.debug_get_spatial_attachment_snapshot().get("active", true))
		or str(npc_system.get_npc_state(PATIENT_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("Stopping the last doctor did not fail the patient and restore both formal sessions")
		return

	print("T0129C A5-P5g formal clinic work verification passed")
	quit(0)


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


func _workstation_reserved_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var occupied_by: Variant = workstation.get("occupied_by")
	return str(workstation.get("reserved_by", "")) == npc_id and (occupied_by == null or str(occupied_by).is_empty())


func _workstation_occupied_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var reserved_by: Variant = workstation.get("reserved_by")
	return str(workstation.get("occupied_by", "")) == npc_id and (reserved_by == null or str(reserved_by).is_empty())


func _workstation_is_clear(building_system: Node, workstation_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var occupied_by: Variant = workstation.get("occupied_by")
	var reserved_by: Variant = workstation.get("reserved_by")
	return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())


func _get_workstation(building_system: Node, workstation_id: String) -> Dictionary:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == workstation_id:
			return raw_workstation
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
