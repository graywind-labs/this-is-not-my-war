extends SceneTree

const STUDENT_ID := "cook_01"
const INSTRUCTOR_ID := "priest_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if npc_system == null or action_system == null or daily_plan_system == null or llm_bridge == null:
		_fail("Training coordination verification requires all plan systems")
		return

	var training_weapon := {
		"id": "verify_training_sword",
		"name": "验证训练剑",
		"required_skill": "剑术",
	}
	# Keep the potential-instructor fixture deterministic even when other NPC
	# profiles gain initial equipment in later content updates.
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if npc_id in [STUDENT_ID, INSTRUCTOR_ID]:
			continue
		npc_system.set_npc_equipment_slot(npc_id, "main_weapon", {})
		npc_system.set_npc_equipment_slot(npc_id, "mount", {})
	if not npc_system.set_npc_equipment_slot(STUDENT_ID, "main_weapon", training_weapon):
		_fail("Could not equip student")
		return
	var solo_actions := _allowed_actions(llm_bridge, STUDENT_ID, false)
	if _has_action(solo_actions, "receive_weapon_training"):
		_fail("The station's only equipped NPC cannot be their own potential instructor")
		return
	if not _has_action(solo_actions, "work_training_instructor"):
		_fail("An equipped NPC must be allowed to train alone as instructor")
		return

	if not npc_system.set_npc_equipment_slot(INSTRUCTOR_ID, "main_weapon", training_weapon):
		_fail("Could not equip potential instructor")
		return
	var paired_actions := _allowed_actions(llm_bridge, STUDENT_ID, false)
	if not _has_action(paired_actions, "receive_weapon_training"):
		_fail("Equipped student did not receive a candidate when another instructor is possible")
		return
	var revision_before_instructor := _allowed_actions(llm_bridge, STUDENT_ID, true)
	if _has_action(revision_before_instructor, "receive_weapon_training"):
		_fail("Immediate revision offered student training without a live instructor")
		return

	if (
		not npc_system.debug_enter_location_immediately(STUDENT_ID, "training_ground")
		or not npc_system.debug_enter_location_immediately(INSTRUCTOR_ID, "training_ground")
	):
		_fail("Could not place training pair")
		return
	var hour := int(root.get_node("GameState").current_hour)
	if (
		not daily_plan_system.set_npc_daily_plan(STUDENT_ID, _make_plan(hour, "receive_weapon_training"), false, "verify_training_order")
		or not daily_plan_system.set_npc_daily_plan(INSTRUCTOR_ID, _make_plan(hour, "work_training_instructor"), false, "verify_training_order")
	):
		_fail("Could not install paired training plans")
		return
	var npc_order: Array[String] = npc_system.get_npc_ids()
	if npc_order.find(STUDENT_ID) >= npc_order.find(INSTRUCTOR_ID):
		_fail("Test precondition requires student to precede instructor in config order")
		return

	var batch_result: Dictionary = daily_plan_system.execute_current_plan_for_all(true)
	if (
		not bool(batch_result.get(INSTRUCTOR_ID, {}).get("ok", false))
		or not bool(batch_result.get(STUDENT_ID, {}).get("ok", false))
	):
		_fail("Instructor-first batch dispatch failed: %s" % str(batch_result))
		return
	if (
		str(action_system.get_active_action_id(INSTRUCTOR_ID)) != "work_training_instructor"
		or str(action_system.get_active_action_id(STUDENT_ID)) != "receive_weapon_training"
	):
		_fail("Student ran before a live instructor was established")
		return
	var revision_with_instructor := _allowed_actions(llm_bridge, STUDENT_ID, true)
	if not _has_action(revision_with_instructor, "receive_weapon_training"):
		_fail("Immediate revision omitted student training despite a live instructor")
		return

	print("T0025 training plan coordination verification passed.")
	quit(0)


func _allowed_actions(llm_bridge: Node, npc_id: String, revision: bool) -> Array:
	var payload: Dictionary
	if revision:
		var plan := _make_plan(int(root.get_node("GameState").current_hour), "work_dining_hall")
		payload = llm_bridge.build_npc_plan_revision_payload(npc_id, {
			"request_id": "verify_training_revision",
			"current_plan": plan,
			"failed_plan_item": plan[int(root.get_node("GameState").current_hour)],
			"failure_type": "unknown",
			"failure_summary": "验证训练即时候选。",
		})
	else:
		payload = llm_bridge.build_npc_daily_plan_payload(npc_id, {
			"request_id": "verify_training_daily",
			"requires_time_slowdown": false,
		})
	var actions = payload.get("allowed_actions", [])
	return actions if actions is Array else []


func _has_action(actions: Array, action_id: String) -> bool:
	for raw_action in actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("action_id", "")) == action_id:
			return true
	return false


func _make_plan(current_hour: int, current_action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": current_action_id if hour == current_hour else "work_dining_hall",
			"action_name": current_action_id if hour == current_hour else "食堂工作",
			"source": "verify_training_order",
			"target": {},
			"priority": 60,
			"reason": "验证训练顺序。",
			"dialogue_goal": "",
		})
	return plan


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
