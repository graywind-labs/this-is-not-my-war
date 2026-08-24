extends SceneTree

const INSTRUCTOR_ID := "veteran_deputy_01"
const STUDENT_ID := "blacksmith_01"
const BUILDING_ID := "training_ground"
const INSTRUCTOR_ACTION_ID := "work_training_instructor"
const STUDENT_ACTION_ID := "receive_weapon_training"
const INSTRUCTOR_STATION_ID := "training_instructor_01"
const STUDENT_STATION_ID := "training_student_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	var startup_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if startup_plan_system != null:
		startup_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var instructor_button := gm_window.find_child("FormalTrainingInstructorButton", true, false) as Button if gm_window != null else null
	var student_button := gm_window.find_child("FormalTrainingStudentButton", true, false) as Button if gm_window != null else null
	var ada := _get_npc_node(npc_system, INSTRUCTOR_ID) if npc_system != null else null
	var glen := _get_npc_node(npc_system, STUDENT_ID) if npc_system != null else null
	if [action_system, npc_system, building_system, resource_system, equipment_system, memory_system, time_system, gm_panel, gm_window, instructor_button, student_button, ada, glen].has(null):
		_fail("A5-P5h runtime dependencies unavailable")
		return

	time_system.set_current_time(1, 7, 2, 0)
	time_system.set_paused(false)
	ada.set("move_speed", 5.0)
	glen.set("move_speed", 5.0)
	npc_system.set_npc_recruited(STUDENT_ID, true)
	resource_system.add_resource("item_sword_shield", 1)
	var student_equip: Dictionary = equipment_system.equip_npc_main_weapon(STUDENT_ID, "sword_shield", "private")
	if not bool(student_equip.get("ok", false)):
		_fail("Could not equip Glen through EquipmentSystem: %s" % JSON.stringify(student_equip))
		return
	_set_skills(npc_system, INSTRUCTOR_ID, {"剑盾": 70, "教练": 45})
	_set_skills(npc_system, STUDENT_ID, {"剑盾": 5})
	for npc_id in [INSTRUCTOR_ID, STUDENT_ID]:
		npc_system.update_npc_state(npc_id, {
			"fatigue": 0,
			"satiety": 100,
			"current_action": "idle",
			"last_action_result": "verify_a5_p5h_ready"
		})

	var instructor_action: Dictionary = action_system.get_action(INSTRUCTOR_ACTION_ID)
	var student_action: Dictionary = action_system.get_action(STUDENT_ACTION_ID)
	if not bool(instructor_action.get("formal_spatial_route", false)) or not bool(student_action.get("formal_spatial_route", false)):
		_fail("Training actions do not expose the formal spatial route contract")
		return

	gm_window.visible = true
	instructor_button.pressed.emit()
	await process_frame
	if (
		gm_window.visible
		or str(action_system.get_runtime_action_snapshot(INSTRUCTOR_ID).get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, INSTRUCTOR_STATION_ID, INSTRUCTOR_ID)
		or not ada.visible
		or ada.global_position.x < 900.0
	):
		_fail("Ada GM entry did not start a reservation-only visible instructor route")
		return

	gm_window.visible = true
	student_button.pressed.emit()
	await process_frame
	if (
		gm_window.visible
		or str(action_system.get_runtime_action_snapshot(STUDENT_ID).get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, STUDENT_STATION_ID, STUDENT_ID)
		or not glen.visible
		or glen.global_position.x < 900.0
	):
		_fail("Glen GM entry did not preserve the dependent reservation while Ada was travelling")
		return

	var ada_sword_pending := _skill(npc_system, INSTRUCTOR_ID, "剑盾")
	var ada_coach_pending := _skill(npc_system, INSTRUCTOR_ID, "教练")
	var glen_sword_pending := _skill(npc_system, STUDENT_ID, "剑盾")
	action_system._on_logical_time_tick(14400.0, 1.0)
	if (
		_skill(npc_system, INSTRUCTOR_ID, "剑盾") != ada_sword_pending
		or _skill(npc_system, INSTRUCTOR_ID, "教练") != ada_coach_pending
		or _skill(npc_system, STUDENT_ID, "剑盾") != glen_sword_pending
	):
		_fail("Pending training routes produced skill growth before physical commitment")
		return

	if not await _wait_for_active(action_system, time_system, INSTRUCTOR_ID, INSTRUCTOR_ACTION_ID):
		_fail("Ada did not physically reach the instructor station")
		return
	if not await _wait_for_active(action_system, time_system, STUDENT_ID, STUDENT_ACTION_ID):
		_fail("Glen did not physically reach a practice slot after Ada became active")
		return
	await physics_frame

	var instructor_state: Dictionary = npc_system.get_npc_state(INSTRUCTOR_ID)
	var student_state: Dictionary = npc_system.get_npc_state(STUDENT_ID)
	var ada_art: Dictionary = ada.debug_get_character_art_snapshot()
	var glen_art: Dictionary = glen.debug_get_character_art_snapshot()
	if (
		str(instructor_state.get("current_location", "")) != BUILDING_ID
		or str(instructor_state.get("current_workstation_id", "")) != INSTRUCTOR_STATION_ID
		or str(instructor_state.get("physical_location_phase", "")) != "workstation"
		or not _workstation_occupied_by(building_system, INSTRUCTOR_STATION_ID, INSTRUCTOR_ID)
		or str(student_state.get("current_location", "")) != BUILDING_ID
		or str(student_state.get("current_workstation_id", "")) != STUDENT_STATION_ID
		or str(student_state.get("physical_location_phase", "")) != "workstation"
		or not _workstation_occupied_by(building_system, STUDENT_STATION_ID, STUDENT_ID)
	):
		_fail("Training arrival did not atomically commit both configured stations")
		return
	if (
		str(ada_art.get("appearance_id", "")) != "ada_veteran_deputy_chibi_v1"
		or str(ada_art.get("desired_state", "")) != "training_instructor"
		or int(ada_art.get("training_instructor_clip_loop_mode", 0)) == 0
		or not bool(ada_art.get("sword_visible", false))
		or not bool(ada_art.get("shield_visible", false))
		or bool(ada_art.get("hammer_visible", true))
		or str(glen_art.get("desired_state", "")) != "training_practice"
		or int(glen_art.get("training_practice_clip_loop_mode", 0)) == 0
		or bool(glen_art.get("hammer_visible", true))
	):
		_fail("Instructor/student looping presentation is incomplete: %s" % JSON.stringify({"ada": ada_art, "glen": glen_art}))
		return

	var ada_sword_before_team := _skill(npc_system, INSTRUCTOR_ID, "剑盾")
	var ada_coach_before_team := _skill(npc_system, INSTRUCTOR_ID, "教练")
	var glen_sword_before_team := _skill(npc_system, STUDENT_ID, "剑盾")
	action_system._on_logical_time_tick(3600.0, 1.0)
	if (
		_skill(npc_system, INSTRUCTOR_ID, "剑盾") != ada_sword_before_team
		or _skill(npc_system, INSTRUCTOR_ID, "教练") <= ada_coach_before_team
		or _skill(npc_system, STUDENT_ID, "剑盾") <= glen_sword_before_team
		or not _has_skill_event(memory_system.get_npc_daily_events(INSTRUCTOR_ID), "training_coaching", "教练")
		or not _has_skill_event(memory_system.get_npc_daily_events(STUDENT_ID), "training_student", "剑盾")
	):
		_fail("Authoritative team training growth did not preserve the existing skill contract")
		return

	gm_panel._stop_formal_training_work()
	await process_frame
	await physics_frame
	if (
		str(npc_system.get_npc_state(STUDENT_ID).get("last_action_result", "")) != "training_student_failed_instructor_left"
		or bool(npc_system.get_formal_workstation_action_snapshot(INSTRUCTOR_ID).get("active", true))
		or bool(npc_system.get_formal_workstation_action_snapshot(STUDENT_ID).get("active", true))
		or not _workstation_is_clear(building_system, INSTRUCTOR_STATION_ID)
		or not _workstation_is_clear(building_system, STUDENT_STATION_ID)
		or str(npc_system.get_npc_state(STUDENT_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("Last-instructor departure did not fail Glen and restore both formal sessions")
		return

	print("T0129C A5-P5h formal training work verification passed")
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


func _set_skills(npc_system: Node, npc_id: String, values: Dictionary) -> void:
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	for raw_skill_name in values.keys():
		skills[str(raw_skill_name)] = int(values[raw_skill_name])
	profile["skills"] = skills
	npc_system._profiles[npc_id] = profile


func _skill(npc_system: Node, npc_id: String, skill_name: String) -> int:
	return int(npc_system.get_npc(npc_id).get("skills", {}).get(skill_name, 0))


func _has_skill_event(events: Array, reason: String, skill_name: String) -> bool:
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var payload: Dictionary = event.get("payload", {})
		if str(event.get("type", "")) == "skill_improved" and str(payload.get("reason", "")) == reason and str(payload.get("skill_name", "")) == skill_name:
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
