extends SceneTree


const CASES := [
	{
		"npc_id": "veteran_deputy_01",
		"action_id": "sleep_in_dormitory",
		"building_id": "dormitory",
		"hold_visual": "sleeping",
		"resume_visual": "sleeping",
		"attachment_pose": "sleeping_supine",
	},
	{
		"npc_id": "gardener_01",
		"action_id": "pray_at_chapel",
		"building_id": "chapel",
		"hold_visual": "seated_idle",
		"resume_visual": "seated_prayer",
		"attachment_pose": "seated_prayer",
	},
	{
		"npc_id": "doctor_01",
		"action_id": "work_clinic_doctor",
		"building_id": "clinic",
		"hold_visual": "seated_idle",
		"resume_visual": "seated_study",
		"attachment_pose": "seated_study",
	},
	{
		"npc_id": "blacksmith_01",
		"action_id": "work_blacksmith",
		"building_id": "blacksmith",
		"hold_visual": "idle",
		"resume_visual": "work",
		"attachment_pose": "",
	},
	{
		"npc_id": "engineer_01",
		"action_id": "work_workshop",
		"building_id": "workshop",
		"hold_visual": "idle",
		"resume_visual": "work",
		"attachment_pose": "",
	},
]

var _failed := false


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
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var station_layout := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if [action_system, npc_system, building_system, crafting_system, resource_system, piety_system, time_system, daily_plan_system, dialog_system, station_layout].has(null):
		_fail("Formal dialogue suspension verification requires all runtime systems")
		return

	time_system.set_current_time(1, 11, 0, 0)
	time_system.set_time_scale(0.0)
	time_system.set_paused(false)
	for resource_id in ["iron", "wood", "money"]:
		resource_system.add_resource(resource_id, 100)
	var blacksmith_target: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", true)
	var workshop_target: Dictionary = crafting_system.set_target("workshop", "craft_wall_ballista", true)
	if not bool(blacksmith_target.get("ok", false)) or not bool(workshop_target.get("ok", false)):
		_fail("Could not prepare crafting targets")
		return

	var actors: Dictionary = {}
	var before: Dictionary = {}
	for case in CASES:
		var npc_id := str(case.get("npc_id", ""))
		var action_id := str(case.get("action_id", ""))
		var actor := _get_npc_node(npc_system, npc_id)
		if actor == null:
			_fail("NPC actor unavailable: %s" % npc_id)
			return
		actors[npc_id] = actor
		actor.set("move_speed", 40.0)
		action_system.interrupt_npc_action(npc_id, "verify_formal_dialogue_setup", true)
		if not npc_system.debug_enter_location_immediately(npc_id, str(case.get("building_id", ""))):
			_fail("Could not stage NPC inside formal building: %s" % npc_id)
			return
		npc_system.update_npc_state(npc_id, {
			"fatigue": 70 if action_id == "sleep_in_dormitory" else 0,
			"satiety": 100,
			"current_action": "idle",
			"last_action_result": "verify_formal_dialogue_ready",
		})
		if not action_system.debug_assign_action(npc_id, action_id, true):
			_fail("Could not dispatch %s for %s" % [action_id, npc_id])
			return
		if not await _stage_and_wait_for_active(action_system, npc_system, station_layout, actor, npc_id, action_id):
			_fail("Formal action did not become active: %s" % JSON.stringify({
				"npc_id": npc_id,
				"action_id": action_id,
				"runtime": action_system.get_runtime_action_snapshot(npc_id),
				"state": npc_system.get_npc_state(npc_id),
				"formal": npc_system.get_formal_workstation_action_snapshot(npc_id),
			}))
			return
		await process_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(npc_id)
		var session: Dictionary = formal.get("session", {})
		var attachment: Dictionary = actor.debug_get_spatial_attachment_snapshot()
		var expected_pose := str(case.get("attachment_pose", ""))
		if (
			str(runtime.get("phase", "")) != "active"
			or str(session.get("action_id", "")) != action_id
			or str(session.get("workstation_id", "")).is_empty()
			or not _workstation_occupied_by(
				building_system,
				str(case.get("building_id", "")),
				str(session.get("workstation_id", "")),
				npc_id
			)
			or (not expected_pose.is_empty() and str(attachment.get("pose", "")) != expected_pose)
			or (expected_pose.is_empty() and bool(attachment.get("active", false)))
		):
			_fail("Initial formal commitment mismatch: %s" % JSON.stringify({
				"case": case,
				"runtime": runtime,
				"formal": formal,
				"attachment": attachment,
			}))
			return
		before[npc_id] = {
			"position": actor.global_position,
			"runtime": runtime.duplicate(true),
			"session": session.duplicate(true),
			"attachment": attachment.duplicate(true),
			"fatigue": float(npc_system.get_npc_state(npc_id).get("fatigue", 0.0)),
		}

	var resource_before: Dictionary = resource_system.get_resource_snapshot().duplicate(true)
	var piety_before: Dictionary = piety_system.get_piety_snapshot().duplicate(true)
	var blacksmith_project_before: Dictionary = crafting_system.get_project_snapshot("blacksmith").duplicate(true)
	var workshop_project_before: Dictionary = crafting_system.get_project_snapshot("workshop").duplicate(true)

	for case in CASES:
		var npc_id := str(case.get("npc_id", ""))
		var action_id := str(case.get("action_id", ""))
		if not action_system.interrupt_npc_action(npc_id, "dialogue_interrupted"):
			_fail("Dialogue did not suspend %s" % action_id)
			return
		var gesture_result: Dictionary = (actors[npc_id] as Node).play_temporary_presentation_action(
			"talk_gesture",
			"verify_formal_hold_gesture:%s" % npc_id
		)
		if not bool(gesture_result.get("ok", false)):
			_fail("Could not inject dialogue gesture for held presentation: %s" % npc_id)
			return
	await process_frame
	await physics_frame

	for case in CASES:
		var npc_id := str(case.get("npc_id", ""))
		var actor: Node = actors[npc_id]
		var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(npc_id)
		var session: Dictionary = formal.get("session", {})
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var attachment: Dictionary = actor.debug_get_spatial_attachment_snapshot()
		var art: Dictionary = actor.debug_get_character_art_snapshot()
		var original: Dictionary = before[npc_id]
		if (
			not str(action_system.get_runtime_action_id(npc_id)).is_empty()
			or not bool(formal.get("active", false))
			or not bool(session.get("dialogue_suspended_hold", false))
			or str(state.get("current_action", "")) != "idle"
			or str(state.get("spatial_route_phase", "")) != "dialogue_workstation_hold"
			or actor.global_position.distance_to(original.get("position", Vector3.ZERO)) > 0.001
			or str(art.get("desired_state", "")) != str(case.get("hold_visual", ""))
			or attachment != original.get("attachment", {})
			or not _workstation_occupied_by(
				building_system,
				str(case.get("building_id", "")),
				str(session.get("workstation_id", "")),
				npc_id
			)
		):
			_fail("Dialogue hold changed position, workstation, pose, or idle presentation: %s" % JSON.stringify({
				"case": case,
				"state": state,
				"formal": formal,
				"attachment": attachment,
				"art": art,
				"position": actor.global_position,
				"original_position": original.get("position"),
			}))
			return

	action_system._on_logical_time_tick(1800.0, 1.0)
	await process_frame
	if (
		resource_system.get_resource_snapshot() != resource_before
		or piety_system.get_piety_snapshot() != piety_before
		or crafting_system.get_project_snapshot("blacksmith") != blacksmith_project_before
		or crafting_system.get_project_snapshot("workshop") != workshop_project_before
	):
		_fail("Suspended formal actions changed resources, piety, or crafting progress")
		return
	for case in CASES:
		var npc_id := str(case.get("npc_id", ""))
		if (
			(actors[npc_id] as Node3D).global_position.distance_to(before[npc_id].get("position", Vector3.ZERO)) > 0.001
			or not is_equal_approx(
				float(npc_system.get_npc_state(npc_id).get("fatigue", 0.0)),
				float(before[npc_id].get("fatigue", 0.0))
			)
		):
			_fail("Suspended formal action advanced position or needs: %s" % npc_id)
			return

	for case in CASES:
		var npc_id := str(case.get("npc_id", ""))
		var action_id := str(case.get("action_id", ""))
		if not action_system.debug_assign_action(npc_id, action_id):
			_fail("Could not resume suspended action: %s" % action_id)
			return
	await process_frame
	await physics_frame

	for case in CASES:
		var npc_id := str(case.get("npc_id", ""))
		var action_id := str(case.get("action_id", ""))
		var actor: Node = actors[npc_id]
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(npc_id)
		var session: Dictionary = formal.get("session", {})
		var original: Dictionary = before[npc_id]
		var art: Dictionary = actor.debug_get_character_art_snapshot()
		if (
			str(runtime.get("phase", "")) != "active"
			or str(runtime.get("action_id", "")) != action_id
			or not bool(formal.get("active", false))
			or bool(session.get("dialogue_suspended_hold", false))
			or int(session.get("started_at_msec", -1)) != int(original.get("session", {}).get("started_at_msec", -2))
			or not is_equal_approx(float(runtime.get("elapsed_seconds", -1.0)), float(original.get("runtime", {}).get("elapsed_seconds", -2.0)))
			or actor.global_position.distance_to(original.get("position", Vector3.ZERO)) > 0.001
			or str(art.get("desired_state", "")) != str(case.get("resume_visual", ""))
		):
			_fail("Suspended transaction did not resume in place: %s" % JSON.stringify({
				"case": case,
				"runtime": runtime,
				"formal": formal,
				"art": art,
				"position": actor.global_position,
			}))
			return

	# The first-sleep summary lock remains above the generic suspension layer.
	npc_system.set_first_sleep_summary_lock("veteran_deputy_01", true, "verify_formal_dialogue_deep_sleep")
	var locked_sleep_dialogue: Dictionary = dialog_system.start_player_dialogue("veteran_deputy_01")
	if (
		bool(locked_sleep_dialogue.get("ok", false))
		or str(locked_sleep_dialogue.get("error_code", "")) != "npc_deep_sleep"
		or str(action_system.get_runtime_action_id("veteran_deputy_01")) != "sleep_in_dormitory"
	):
		_fail("Deep-sleep lock was weakened by formal dialogue suspension")
		return
	npc_system.set_first_sleep_summary_lock("veteran_deputy_01", false, "verify_formal_dialogue_deep_sleep")

	# Clinic duty owns an internal live navigation request while the doctor walks
	# between the study seat and patient beds. Dialogue must pause that exact
	# request, not cancel it and create a competing route after the conversation.
	const PATIENT_ID := "cook_01"
	const PATIENT_ACTION_ID := "receive_clinic_treatment"
	var patient_actor := _get_npc_node(npc_system, PATIENT_ID)
	if patient_actor == null:
		_fail("Clinic patient actor unavailable")
		return
	action_system.interrupt_npc_action(PATIENT_ID, "verify_clinic_motion_setup", true)
	npc_system.debug_enter_location_immediately(PATIENT_ID, "clinic")
	npc_system.update_npc_state(PATIENT_ID, {
		"hp": 10,
		"max_hp": 100,
		"unconscious": false,
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
	})
	if (
		not action_system.debug_assign_action(PATIENT_ID, PATIENT_ACTION_ID, true)
		or not await _stage_and_wait_for_active(
			action_system,
			npc_system,
			station_layout,
			patient_actor,
			PATIENT_ID,
			PATIENT_ACTION_ID
		)
	):
		_fail("Could not prepare a clinic patient for internal-motion suspension")
		return
	var doctor_actor: Node3D = actors["doctor_01"]
	doctor_actor.set("move_speed", 3.2)
	action_system._on_logical_time_tick(1.0, 1.0)
	var doctor_motion_started := false
	for _frame in range(60):
		await physics_frame
		if doctor_actor.is_world_movement_active():
			doctor_motion_started = true
			break
	if not doctor_motion_started:
		_fail("Clinic doctor did not begin the live bedside route")
		return
	var doctor_hold_position := doctor_actor.global_position
	if not action_system.interrupt_npc_action("doctor_01", "dialogue_interrupted"):
		_fail("Could not suspend clinic doctor during the bedside route")
		return
	for _frame in range(20):
		await physics_frame
	var paused_motion: Dictionary = doctor_actor.debug_get_motion_snapshot()
	action_system._on_logical_time_tick(600.0, 1.0)
	if (
		doctor_hold_position.distance_to(doctor_actor.global_position) > 0.001
		or not bool(paused_motion.get("active", false))
		or not bool(paused_motion.get("authority_paused", false))
		or str(action_system.get_runtime_action_id(PATIENT_ID)) != PATIENT_ACTION_ID
	):
		_fail("Clinic dialogue did not freeze the live route or made the patient fail: %s" % JSON.stringify({
			"motion": paused_motion,
			"doctor_position": doctor_actor.global_position,
			"hold_position": doctor_hold_position,
			"patient_runtime": action_system.get_runtime_action_snapshot(PATIENT_ID),
		}))
		return
	if not action_system.debug_assign_action("doctor_01", "work_clinic_doctor"):
		_fail("Clinic doctor could not resume the paused bedside route")
		return
	var doctor_moved_after_resume := false
	for _frame in range(120):
		await physics_frame
		if doctor_actor.global_position.distance_to(doctor_hold_position) > 0.01:
			doctor_moved_after_resume = true
			break
	if (
		not doctor_moved_after_resume
		or bool(doctor_actor.debug_get_motion_snapshot().get("authority_paused", true))
		or str(action_system.get_runtime_action_id("doctor_01")) != "work_clinic_doctor"
	):
		_fail("Clinic bedside route did not continue after dialogue")
		return

	# Exercise the real guard-officer dialogue lifecycle once, including the
	# unchanged-plan cancellation path that previously restarted formal routing.
	const DIALOGUE_NPC_ID := "gardener_01"
	const DIALOGUE_ACTION_ID := "pray_at_chapel"
	if not daily_plan_system.set_npc_daily_plan(
		DIALOGUE_NPC_ID,
		_make_plan(DIALOGUE_ACTION_ID),
		false,
		"verify_formal_dialogue_hold"
	):
		_fail("Could not install unchanged prayer plan for real dialogue lifecycle")
		return
	var dialogue_position: Vector3 = (actors[DIALOGUE_NPC_ID] as Node3D).global_position
	var dialogue_result: Dictionary = dialog_system.start_player_dialogue(DIALOGUE_NPC_ID)
	var activation_result: Dictionary = dialog_system.call("_activate_player_dialogue_draft", "verify_formal_dialogue_hold")
	var effect_result: Dictionary = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_formal_dialogue_hold")
	await process_frame
	if (
		not bool(dialogue_result.get("ok", false))
		or not bool(activation_result.get("ok", false))
		or not bool(effect_result.get("interrupted_action", false))
		or str(effect_result.get("interrupted_action_id", "")) != DIALOGUE_ACTION_ID
		or not bool(npc_system.get_formal_workstation_action_snapshot(DIALOGUE_NPC_ID).get("session", {}).get("dialogue_suspended_hold", false))
		or dialogue_position.distance_to((actors[DIALOGUE_NPC_ID] as Node3D).global_position) > 0.001
		or str((actors[DIALOGUE_NPC_ID] as Node).debug_get_character_art_snapshot().get("desired_state", "")) != "seated_idle"
	):
		_fail("Real dialogue lifecycle did not hold seated prayer in place: %s" % JSON.stringify({
			"dialogue": dialogue_result,
			"activation": activation_result,
			"effect": effect_result,
			"formal": npc_system.get_formal_workstation_action_snapshot(DIALOGUE_NPC_ID),
		}))
		return
	var cancel_result: Dictionary = dialog_system.cancel_displayed_dialogue()
	for _frame in range(5):
		await process_frame
	if (
		not bool(cancel_result.get("ok", false))
		or str(action_system.get_runtime_action_id(DIALOGUE_NPC_ID)) != DIALOGUE_ACTION_ID
		or bool(npc_system.get_formal_workstation_action_snapshot(DIALOGUE_NPC_ID).get("session", {}).get("dialogue_suspended_hold", false))
		or dialogue_position.distance_to((actors[DIALOGUE_NPC_ID] as Node3D).global_position) > 0.001
	):
		_fail("Cancelling real dialogue did not resume the same prayer transaction: %s" % JSON.stringify(cancel_result))
		return

	# A changed decision must release the old standing workstation exactly once and
	# immediately begin a valid new route from that real interior position.
	const REPLACED_NPC_ID := "blacksmith_01"
	var forge_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(REPLACED_NPC_ID).get("session", {})
	var forge_id := str(forge_session.get("workstation_id", ""))
	var forge_position: Vector3 = (actors[REPLACED_NPC_ID] as Node3D).global_position
	if not action_system.interrupt_npc_action(REPLACED_NPC_ID, "dialogue_interrupted"):
		_fail("Could not suspend blacksmith action for replacement case")
		return
	if not action_system.debug_assign_action(REPLACED_NPC_ID, "pray_at_chapel"):
		_fail("Changed post-dialogue action did not dispatch")
		return
	await physics_frame
	var replacement_runtime: Dictionary = action_system.get_runtime_action_snapshot(REPLACED_NPC_ID)
	var replacement_formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(REPLACED_NPC_ID)
	if (
		str(replacement_runtime.get("phase", "")) != "pending"
		or str(replacement_runtime.get("action_id", "")) != "pray_at_chapel"
		or str(replacement_formal.get("session", {}).get("action_id", "")) != "pray_at_chapel"
		or not _workstation_is_clear(building_system, "blacksmith", forge_id)
		or forge_position.distance_to((actors[REPLACED_NPC_ID] as Node3D).global_position) > 3.0
	):
		_fail("Changed post-dialogue action left a stale forge or teleported before rerouting: %s" % JSON.stringify({
			"runtime": replacement_runtime,
			"formal": replacement_formal,
			"position_before": forge_position,
			"position_after": (actors[REPLACED_NPC_ID] as Node3D).global_position,
		}))
		return

	print("T1505-P6R42 formal-action dialogue hold/resume verification passed")
	quit(0)


func _stage_and_wait_for_active(
	action_system: Node,
	npc_system: Node,
	station_layout: Node,
	actor: Node3D,
	npc_id: String,
	action_id: String,
	max_frames: int = 300
) -> bool:
	var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(npc_id)
	var session: Dictionary = formal.get("session", {})
	var route: Dictionary = station_layout.get_building_spatial_route(
		str(session.get("building_id", "")),
		str(session.get("workstation_id", ""))
	)
	var target_position: Variant = route.get("interior_target_position")
	if target_position is Vector3:
		actor.global_position = target_position
	for _frame in range(max_frames):
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _get_npc_node(npc_system: Node, npc_id: String) -> Node3D:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath(""))) as Node3D


func _make_plan(action_id: String) -> Array:
	var result: Array = []
	for hour in range(24):
		result.append({
			"hour": hour,
			"action_id": action_id,
			"action_kind": "pray",
			"location_id": "chapel",
			"target_id": "",
			"priority": 60,
			"reason": "T1505-P6R42 formal dialogue resume verification",
			"dialogue_goal": "",
			"source": "verify_t1505_p6r42",
		})
	return result


func _workstation_occupied_by(
	building_system: Node,
	building_id: String,
	workstation_id: String,
	npc_id: String
) -> bool:
	var workstation := _get_workstation(building_system, building_id, workstation_id)
	var reserved_by: Variant = workstation.get("reserved_by")
	return str(workstation.get("occupied_by", "")) == npc_id and (reserved_by == null or str(reserved_by).is_empty())


func _workstation_is_clear(building_system: Node, building_id: String, workstation_id: String) -> bool:
	var workstation := _get_workstation(building_system, building_id, workstation_id)
	var occupied_by: Variant = workstation.get("occupied_by")
	var reserved_by: Variant = workstation.get("reserved_by")
	return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())


func _get_workstation(building_system: Node, building_id: String, workstation_id: String) -> Dictionary:
	for raw_workstation in building_system.get_building(building_id).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == workstation_id:
			return raw_workstation
	return {}


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
