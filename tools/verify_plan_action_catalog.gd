extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const ACTOR_NPC_ID := "doctor_01"
const PLANNING_DIALOGUE_TARGET_NPC_ID := "priest_01"
const HEAL_TARGET_NPC_ID := "cook_01"
const REPAIR_BUILDING_ID := "dormitory"
const UPGRADE_BUILDING_ID := "main_hall"


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if (
		llm_bridge == null
		or npc_system == null
		or action_system == null
		or daily_plan_system == null
		or building_system == null
		or resource_system == null
		or memory_system == null
		or dialog_system == null
		or combat_system == null
	):
		_fail("Plan action catalog verification required systems not found")
		return

	var interface_error := _verify_dispatch_interfaces(
		action_system,
		daily_plan_system,
		npc_system,
		dialog_system,
		combat_system
	)
	if not interface_error.is_empty():
		_fail(interface_error)
		return

	var baseline_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	if baseline_actions.is_empty():
		_fail("LLMBridge returned an empty allowed_actions catalog")
		return
	var idle_candidates := _find_candidates(baseline_actions, "idle")
	if idle_candidates.size() != 1 or idle_candidates[0].get("location_id", null) != null:
		_fail("idle must mean waiting in place; moving to plaza belongs to visit_location")
		return

	for required_action_id in [
		"pray_at_chapel",
		"attend_mass",
		"seek_guard_officer",
		"escaping_station",
	]:
		if _find_candidates(baseline_actions, required_action_id).size() != 1:
			_fail("Expected exactly one static candidate for %s" % required_action_id)
			return
	var attend_mass_candidate: Dictionary = _find_candidates(baseline_actions, "attend_mass")[0]
	var attend_mass_context: Dictionary = attend_mass_candidate.get("context", {})
	if bool(attend_mass_context.get("available_now", true)):
		_fail("attend_mass must be unavailable until a valid Mass leader is active")
		return
	if str(attend_mass_context.get("required_active_action_id", "")) != "lead_mass":
		_fail("attend_mass candidate must expose its lead_mass runtime dependency")
		return
	if not _find_candidates(baseline_actions, "escape_intervention_dialogue").is_empty():
		_fail("escape_intervention_dialogue must never be plan-selectable")
		return
	if not _find_candidates(baseline_actions, "assist_heal").is_empty():
		_fail("assist_heal must not be offered when there is no unconscious target")
		return
	if not _find_candidates(baseline_actions, "assist_repair").is_empty():
		_fail("assist_repair must not be offered without an active repair job")
		return
	if not _find_candidates(baseline_actions, "assist_upgrade").is_empty():
		_fail("assist_upgrade must not be offered without an active upgrade job")
		return
	if not _find_candidates(baseline_actions, "receive_clinic_treatment").is_empty():
		_fail("A healthy NPC must not receive the guaranteed-to-fail clinic patient candidate")
		return
	for unavailable_training_action in ["work_training_instructor", "receive_weapon_training"]:
		if not _find_candidates(baseline_actions, unavailable_training_action).is_empty():
			_fail("An unequipped NPC must not receive training candidate %s" % unavailable_training_action)
			return

	var talk_error := _verify_dynamic_dialogue_targets(baseline_actions, npc_system)
	if not talk_error.is_empty():
		_fail(talk_error)
		return
	var visit_error := _verify_dynamic_visit_targets(baseline_actions, building_system, memory_system)
	if not visit_error.is_empty():
		_fail(visit_error)
		return
	var baseline_route_error := _verify_candidates_are_plan_routable(
		baseline_actions,
		ACTOR_NPC_ID,
		action_system,
		daily_plan_system
	)
	if not baseline_route_error.is_empty():
		_fail(baseline_route_error)
		return

	# Eight daily plans are requested concurrently. A target's transient planning state
	# must not erase that NPC from another NPC's valid same-day dialogue choices.
	if not npc_system.update_npc_state(PLANNING_DIALOGUE_TARGET_NPC_ID, {
		"current_action": "planning_day",
		"last_action_result": "planning_day_started",
	}):
		_fail("Failed to prepare transient planning_day dialogue target")
		return
	if not npc_system.set_npc_llm_activity(PLANNING_DIALOGUE_TARGET_NPC_ID, {
		"active": true,
		"kind": "plan",
		"request_id": "verify_plan_action_catalog_transient_planning",
		"cancellable": true,
	}):
		_fail("Failed to prepare transient plan_day LLM activity")
		return
	await process_frame
	var planning_state_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	var planning_target_candidates := _find_candidates(planning_state_actions, "talk_to_npc").filter(
		func(candidate: Dictionary) -> bool:
			return str(candidate.get("target_id", "")) == PLANNING_DIALOGUE_TARGET_NPC_ID
	)
	if planning_target_candidates.size() != 1:
		_fail("planning_day/plan_day LLM activity must remain a talk_to_npc candidate")
		return
	var revision_state_actions := _get_revision_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	if _candidate_target_ids(_find_candidates(revision_state_actions, "talk_to_npc")).has(PLANNING_DIALOGUE_TARGET_NPC_ID):
		_fail("Immediate plan revision must not offer a target still busy with planning/LLM activity")
		return
	var planning_route_error := _verify_candidates_are_plan_routable(
		planning_target_candidates,
		ACTOR_NPC_ID,
		action_system,
		daily_plan_system
	)
	if not planning_route_error.is_empty():
		_fail(planning_route_error)
		return
	if not npc_system.clear_npc_llm_activity(
		PLANNING_DIALOGUE_TARGET_NPC_ID,
		"verify_plan_action_catalog_transient_planning"
	):
		_fail("Failed to clear transient plan_day LLM activity")
		return
	if not npc_system.update_npc_state(PLANNING_DIALOGUE_TARGET_NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_transient_planning_cleanup",
	}):
		_fail("Failed to clean up transient planning_day target")
		return
	if not npc_system.update_npc_state(PLANNING_DIALOGUE_TARGET_NPC_ID, {
		"current_action": "proactive_talk",
		"last_action_result": "verify_proactive_talk_target_filter",
	}):
		_fail("Failed to prepare proactive_talk target filter")
		return
	var proactive_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	if _candidate_target_ids(_find_candidates(proactive_actions, "talk_to_npc")).has(PLANNING_DIALOGUE_TARGET_NPC_ID):
		_fail("A target already seeking the guard officer must not be offered for NPC dialogue")
		return
	if not npc_system.update_npc_state(PLANNING_DIALOGUE_TARGET_NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_proactive_talk_target_cleanup",
	}):
		_fail("Failed to clean up proactive_talk target filter")
		return

	# A day plan may mention a future conversation, but an immediate revision must
	# never choose a target already reserved by another NPC's approach.
	var dialogue_reservations: Dictionary = (action_system.get("_dialogue_reservations") as Dictionary).duplicate(true)
	action_system.set("_dialogue_reservations", {
		PLANNING_DIALOGUE_TARGET_NPC_ID: "stableman_01",
		"stableman_01": "stableman_01",
	})
	var reserved_daily_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	if not _candidate_target_ids(_find_candidates(reserved_daily_actions, "talk_to_npc")).has(PLANNING_DIALOGUE_TARGET_NPC_ID):
		_fail("A transient approach reservation must not erase a future daily-plan dialogue choice")
		return
	var reserved_revision_actions := _get_revision_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	if _candidate_target_ids(_find_candidates(reserved_revision_actions, "talk_to_npc")).has(PLANNING_DIALOGUE_TARGET_NPC_ID):
		_fail("Immediate plan revision must not offer an NPC reserved by another dialogue approach")
		return
	action_system.set("_dialogue_reservations", {ACTOR_NPC_ID: "stableman_01"})
	if not _find_candidates(_get_revision_allowed_actions(llm_bridge, ACTOR_NPC_ID), "talk_to_npc").is_empty():
		_fail("An actor already reserved by another dialogue approach must receive no immediate talk candidates")
		return
	action_system.set("_dialogue_reservations", dialogue_reservations)

	# DialogSystem currently owns one authoritative active conversation. While it
	# is occupied, every immediate talk candidate would deterministically fail.
	var player_dialogue_start: Dictionary = dialog_system.start_proactive_player_dialogue(
		"blacksmith_01",
		"我想向守备官汇报一件事。"
	)
	if not bool(player_dialogue_start.get("ok", false)) or not dialog_system.has_active_dialogue():
		_fail("Failed to prepare an active player dialogue for catalog filtering")
		return
	if not _find_candidates(_get_revision_allowed_actions(llm_bridge, ACTOR_NPC_ID), "talk_to_npc").is_empty():
		_fail("Immediate plan revision must expose no talk candidates while another dialogue is active")
		return
	dialog_system.end_dialogue("verify_plan_action_catalog_cleanup", {
		"suppress_plan_reevaluation": true,
	})

	if not npc_system.update_npc_state(HEAL_TARGET_NPC_ID, {
		"hp": 0,
		"unconscious": true,
		"current_action": "unconscious",
		"behavior_mode": "unconscious",
		"escaped": false,
	}):
		_fail("Failed to prepare an unconscious NPC target")
		return
	await process_frame
	var heal_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	var heal_candidates := _find_candidates(heal_actions, "assist_heal")
	if _candidate_target_ids(heal_candidates) != [HEAL_TARGET_NPC_ID]:
		_fail("assist_heal must expose only the legal unconscious target")
		return
	if _candidate_target_ids(_find_candidates(heal_actions, "talk_to_npc")).has(HEAL_TARGET_NPC_ID):
		_fail("An unconscious NPC must not remain a talk_to_npc target")
		return
	var heal_route_error := _verify_candidates_are_plan_routable(
		heal_candidates,
		ACTOR_NPC_ID,
		action_system,
		daily_plan_system
	)
	if not heal_route_error.is_empty():
		_fail(heal_route_error)
		return

	if not building_system.debug_damage_building(REPAIR_BUILDING_ID, 10):
		_fail("Failed to damage repair verification building")
		return
	if not building_system.repair_building(REPAIR_BUILDING_ID):
		_fail("Failed to start repair verification job")
		return
	if not building_system.upgrade_building(UPGRADE_BUILDING_ID):
		_fail("Failed to start upgrade verification job")
		return
	await process_frame

	var active_job_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	var repair_candidates := _find_candidates(active_job_actions, "assist_repair")
	var upgrade_candidates := _find_candidates(active_job_actions, "assist_upgrade")
	if _candidate_target_ids(repair_candidates) != [REPAIR_BUILDING_ID]:
		_fail("assist_repair must expose exactly the active repair target")
		return
	if _candidate_target_ids(upgrade_candidates) != [UPGRADE_BUILDING_ID]:
		_fail("assist_upgrade must expose exactly the active upgrade target")
		return
	var upgrade_candidate: Dictionary = upgrade_candidates[0]
	if (
		str(upgrade_candidate.get("action_id", "")) != "assist_upgrade"
		or str(upgrade_candidate.get("action_kind", "")) != "assist_upgrade"
		or not str(upgrade_candidate.get("name", "")).begins_with("协助升级")
	):
		_fail("assist_upgrade must keep English technical values and a Chinese display name")
		return
	var active_job_route_error := _verify_candidates_are_plan_routable(
		repair_candidates + upgrade_candidates,
		ACTOR_NPC_ID,
		action_system,
		daily_plan_system
	)
	if not active_job_route_error.is_empty():
		_fail(active_job_route_error)
		return

	# Priest departure only removes his ability to lead Mass. Ordinary prayer stays
	# available, while lead_mass remains visible with an explicit eligibility hint.
	if not npc_system.update_npc_state("priest_01", {
		"escaped": true,
		"current_action": "escaped",
		"behavior_mode": "escaped",
	}):
		_fail("Failed to prepare escaped priest state")
		return
	var closed_chapel_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	if _find_candidates(closed_chapel_actions, "pray_at_chapel").is_empty():
		_fail("Ordinary prayer disappeared after the priest escaped")
		return
	var mass_candidates := _find_candidates(closed_chapel_actions, "lead_mass")
	if mass_candidates.is_empty() or bool(mass_candidates[0].get("context", {}).get("eligible", true)):
		_fail("Non-priest should see an explicitly ineligible Mass candidate")
		return
	if not _find_candidates(closed_chapel_actions, "attend_mass").is_empty():
		_fail("attend_mass should disappear when no potential Mass leader remains in the station")
		return
	if bool(daily_plan_system.call("_is_plan_target_unavailable", ACTOR_NPC_ID, {
		"action_id": "pray_at_chapel",
		"target": {},
	})):
		_fail("DailyPlanSystem treated ordinary prayer as unavailable after priest departure")
		return
	if not npc_system.debug_enter_location_immediately(ACTOR_NPC_ID, "chapel"):
		_fail("Could not place actor in chapel for prayer execution check")
		return
	if not action_system.debug_assign_action(ACTOR_NPC_ID, "pray_at_chapel"):
		_fail("ActionSystem rejected ordinary prayer after the priest escaped")
		return
	action_system.interrupt_npc_action(ACTOR_NPC_ID, "verify_prayer_after_priest_escape")
	if action_system.debug_assign_action(ACTOR_NPC_ID, "lead_mass"):
		_fail("ActionSystem allowed a non-priest to lead Mass")
		return
	if not str(npc_system.get_npc_state(ACTOR_NPC_ID).get("last_action_result", "")).contains("ineligible"):
		_fail("Mass eligibility rejection did not expose its authoritative failure")
		return

	# Destroyed buildings must disappear from both static work/prayer actions and
	# target-aware visit choices, and the local parser must reject stale targets.
	for destroyed_building_id in ["chapel", "clinic"]:
		var building: Dictionary = building_system.get_building(destroyed_building_id)
		if not building_system.debug_damage_building(destroyed_building_id, int(building.get("hp", 1))):
			_fail("Failed to destroy %s for candidate filtering verification" % destroyed_building_id)
			return
	await process_frame
	var destroyed_actions := _get_allowed_actions(llm_bridge, ACTOR_NPC_ID)
	for unavailable_action_id in ["pray_at_chapel", "attend_mass", "work_clinic_doctor", "receive_clinic_treatment"]:
		if not _find_candidates(destroyed_actions, unavailable_action_id).is_empty():
			_fail("Destroyed required building still exposed action %s" % unavailable_action_id)
			return
	for destroyed_building_id in ["chapel", "clinic"]:
		if _candidate_target_ids(_find_candidates(destroyed_actions, "visit_location")).has(destroyed_building_id):
			_fail("Destroyed building remained a visit_location target: %s" % destroyed_building_id)
			return
		if bool(daily_plan_system.call("_is_valid_plan_target", ACTOR_NPC_ID, "visit_location", {
			"target_id": destroyed_building_id,
			"location_id": destroyed_building_id,
		})):
			_fail("DailyPlanSystem accepted destroyed visit target: %s" % destroyed_building_id)
			return

	print("T0025 plan action catalog verification passed.")
	quit(0)


func _get_allowed_actions(llm_bridge: Node, npc_id: String) -> Array:
	var payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(npc_id, {
		"request_id": "verify_plan_action_catalog",
		"requires_time_slowdown": false,
	})
	var raw_actions = payload.get("allowed_actions", [])
	return raw_actions if raw_actions is Array else []


func _get_revision_allowed_actions(llm_bridge: Node, npc_id: String) -> Array:
	var current_plan: Array = []
	for hour in range(24):
		current_plan.append({
			"hour": hour,
			"action_id": "work_clinic_doctor",
			"reason": "验证即时修订候选",
			"target": {}
		})
	var payload: Dictionary = llm_bridge.build_npc_plan_revision_payload(npc_id, {
		"request_id": "verify_plan_action_catalog_revision",
		"current_plan": current_plan,
		"failed_plan_item": current_plan[8],
		"failure_type": "workstation_occupied",
		"failure_summary": "验证即时执行候选。",
		"requires_time_slowdown": true,
	})
	var raw_actions = payload.get("allowed_actions", [])
	return raw_actions if raw_actions is Array else []


func _verify_dynamic_dialogue_targets(actions: Array, npc_system: Node) -> String:
	var talk_candidates := _find_candidates(actions, "talk_to_npc")
	var actual_target_ids := _candidate_target_ids(talk_candidates)
	var expected_target_ids: Array[String] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if npc_id != ACTOR_NPC_ID:
			expected_target_ids.append(npc_id)
	expected_target_ids.sort()
	if actual_target_ids != expected_target_ids:
		return "talk_to_npc target catalog mismatch: expected=%s actual=%s" % [
			str(expected_target_ids),
			str(actual_target_ids),
		]
	for candidate in talk_candidates:
		if str(candidate.get("target_kind", "")) != "npc":
			return "talk_to_npc candidate must declare target_kind=npc"
		if candidate.has("location_id"):
			return "talk_to_npc candidate must not expose or bind a location_id"
	return ""


func _verify_dynamic_visit_targets(actions: Array, building_system: Node, memory_system: Node) -> String:
	var visit_candidates := _find_candidates(actions, "visit_location")
	var actual_target_ids := _candidate_target_ids(visit_candidates)
	var expected_target_ids: Array[String] = ["plaza"]
	for raw_building_id in building_system.get_building_ids():
		var building_id := str(raw_building_id)
		var building: Dictionary = building_system.get_building(building_id)
		if int(building.get("hp", 0)) > 0 and memory_system.is_enterable_location(building_id):
			expected_target_ids.append(building_id)
	expected_target_ids.sort()
	if actual_target_ids != expected_target_ids:
		return "visit_location target catalog mismatch: expected=%s actual=%s" % [
			str(expected_target_ids),
			str(actual_target_ids),
		]
	for candidate in visit_candidates:
		var target_id := str(candidate.get("target_id", ""))
		if str(candidate.get("target_kind", "")) != "location":
			return "visit_location candidate must declare target_kind=location"
		if str(candidate.get("location_id", "")) != target_id:
			return "visit_location candidate location_id must equal target_id"
		if not memory_system.is_enterable_location(target_id):
			return "visit_location exposed non-enterable location: %s" % target_id
	return ""


func _verify_candidates_are_plan_routable(
	candidates: Array,
	npc_id: String,
	action_system: Node,
	daily_plan_system: Node
) -> String:
	for candidate in candidates:
		if not candidate is Dictionary:
			return "allowed_actions contained a non-dictionary candidate"
		var action_id := str(candidate.get("action_id", ""))
		var action_kind := str(candidate.get("action_kind", ""))
		if action_kind.is_empty():
			return "Catalog candidate is missing action_kind: %s" % action_id
		if not daily_plan_system.call("_is_supported_plan_action", action_id):
			return "DailyPlanSystem rejected catalog action: %s" % action_id
		var schema_item := {
			"hour": 8,
			"action_id": action_id,
			"action_kind": action_kind,
			"target_id": candidate.get("target_id", null),
			"priority": 50,
			"reason": "验证计划候选可被正式计划解析。",
			"dialogue_goal": "我想和你谈谈当前的安排。" if action_id == "talk_to_npc" else "",
		}
		if action_id != "talk_to_npc":
			schema_item["location_id"] = candidate.get("location_id", null)
		var plan_item = daily_plan_system.call(
			"_plan_item_from_schema",
			schema_item,
			"verify_plan_action_catalog",
			npc_id
		)
		if not plan_item is Dictionary or plan_item.is_empty():
			return "Catalog candidate cannot become a valid plan item: %s target=%s location=%s" % [
				action_id,
				str(candidate.get("target_id", null)),
				str(candidate.get("location_id", null)),
			]
		var route_error := _verify_candidate_dispatch_interface(action_id, action_system)
		if not route_error.is_empty():
			return route_error
	return ""


func _verify_candidate_dispatch_interface(action_id: String, action_system: Node) -> String:
	match action_id:
		"idle", "seek_guard_officer", "escaping_station":
			return ""
		"talk_to_npc":
			return "" if action_system.has_method("assign_npc_dialogue") else "talk_to_npc has no ActionSystem dispatcher"
		"visit_location":
			return "" if action_system.has_method("assign_visit_location") else "visit_location has no ActionSystem dispatcher"
		"assist_heal":
			return "" if action_system.has_method("debug_assign_heal_assist") else "assist_heal has no ActionSystem dispatcher"
		"assist_repair":
			return "" if action_system.has_method("debug_assign_repair_assist") else "assist_repair has no ActionSystem dispatcher"
		"assist_upgrade":
			return "" if action_system.has_method("debug_assign_upgrade_assist") else "assist_upgrade has no ActionSystem dispatcher"
		_:
			var action: Dictionary = action_system.get_action(action_id)
			var supported_direct_types := [
				"work",
				"eat",
				"sleep",
				"pray",
				"clinic_doctor",
				"clinic_patient",
				"training_instructor",
				"training_student",
			]
			if action.is_empty() or not supported_direct_types.has(str(action.get("type", ""))):
				return "Catalog action has no executable ActionSystem type: %s" % action_id
			return "" if action_system.has_method("debug_assign_action") else "%s has no direct ActionSystem dispatcher" % action_id


func _verify_dispatch_interfaces(
	action_system: Node,
	daily_plan_system: Node,
	npc_system: Node,
	dialog_system: Node,
	combat_system: Node
) -> String:
	for method_name in [
		"debug_assign_action",
		"assign_npc_dialogue",
		"assign_visit_location",
		"debug_assign_heal_assist",
		"debug_assign_repair_assist",
		"debug_assign_upgrade_assist",
	]:
		if not action_system.has_method(method_name):
			return "ActionSystem missing plan dispatch interface: %s" % method_name
	for method_name in ["_is_supported_plan_action", "_plan_item_from_schema", "_assign_plan_item"]:
		if not daily_plan_system.has_method(method_name):
			return "DailyPlanSystem missing plan route interface: %s" % method_name
	if not dialog_system.has_method("start_autonomous_npc_dialogue"):
		return "DialogSystem missing autonomous NPC-NPC dialogue entry point"
	if not npc_system.has_method("start_proactive_talk"):
		return "NPCSystem missing seek_guard_officer execution entry point"
	if not combat_system.has_method("start_npc_escape"):
		return "CombatSystem missing escaping_station authoritative execution entry point"
	return ""


func _find_candidates(actions: Array, action_id: String) -> Array:
	var result: Array = []
	for raw_candidate in actions:
		if raw_candidate is Dictionary and str(raw_candidate.get("action_id", "")) == action_id:
			result.append(raw_candidate)
	return result


func _candidate_target_ids(candidates: Array) -> Array[String]:
	var target_ids: Array[String] = []
	for candidate in candidates:
		var target_id := str(candidate.get("target_id", ""))
		if not target_id.is_empty() and target_id != "<null>":
			target_ids.append(target_id)
	target_ids.sort()
	return target_ids


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
