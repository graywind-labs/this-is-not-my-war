extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const MOCK_BACKEND_URL := "http://127.0.0.1:5016"


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null(
		"Main/Systems/DailyPlanSystem"
	)
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if (
		time_system == null
		or npc_system == null
		or daily_plan_system == null
		or llm_bridge == null
	):
		push_error("Required systems not found")
		quit(1)
		return

	time_system.set_current_time(1, 8, 0, 0)
	time_system.set_time_scale(1.0)
	llm_bridge.set_backend_base_url(MOCK_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 5.0
	var health: Dictionary = llm_bridge.check_health()
	if not bool(health.get("ok", false)):
		push_error("Mock backend is not available on port 5016")
		quit(1)
		return

	var cases := [
		{
			"npc_id": "engineer_01",
			"goal": "守备官，我来汇报弩床当前制造进度。",
			"decision": "continue"
		},
		{
			"npc_id": "blacksmith_01",
			"goal": "守备官，我要用旧说法汇报弩床进度。",
			"decision": "modify"
		},
		{
			"npc_id": "gardener_01",
			"goal": "守备官，这件事已经解决，不必再谈。",
			"decision": "cancel_and_replan"
		}
	]
	for case_data in cases:
		var npc_id := str(case_data.get("npc_id", ""))
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": "verify_dialogue_intent_revalidation"
		})
		var plan := _make_plan(
			daily_plan_system,
			str(case_data.get("goal", ""))
		)
		if not daily_plan_system.set_npc_daily_plan(
			npc_id,
			plan,
			false,
			"verify_dialogue_intent"
		):
			push_error("Failed to install dialogue plan for %s" % npc_id)
			quit(1)
			return
		var current_item: Dictionary = (
			daily_plan_system.get_current_plan_item(npc_id)
		)
		if (
			int(current_item.get("intent_created_day", 0)) != 1
			or str(current_item.get("intent_created_time", "")).is_empty()
			or str(current_item.get("intent_source", "")).is_empty()
		):
			push_error(
				"Dialogue intent creation metadata was not stamped: %s"
				% str(current_item)
			)
			quit(1)
			return
		var payload: Dictionary = (
			llm_bridge.build_dialogue_intent_revalidation_payload(
				npc_id,
				current_item,
				{"current_plan": daily_plan_system.get_npc_daily_plan(npc_id)}
			)
		)
		if (
			payload.is_empty()
			or (payload.get("current_plan", []) as Array).size() != 24
			or not payload.has("station_context")
			or not payload.has("current_building_states")
			or not payload.has("current_resource_states")
			or str(
				payload.get("planned_intent", {}).get("created_time", "")
			).is_empty()
		):
			push_error("Dialogue intent payload lacks full current context: %s" % str(payload))
			quit(1)
			return
		var execute_result: Dictionary = (
			daily_plan_system.execute_current_plan_for_npc(npc_id, true)
		)
		if str(execute_result.get("status", "")) != "dialogue_intent_revalidation_pending":
			push_error("Dialogue action did not enter preflight first: %s" % str(execute_result))
			quit(1)
			return
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) != "idle":
			push_error("Preflight changed NPC action before LLM response for %s" % npc_id)
			quit(1)
			return
		var snapshot := await _wait_for_result(
			daily_plan_system,
			npc_id,
			8.0
		)
		var last_result: Dictionary = snapshot.get("last_result", {})
		if llm_bridge.get_pending_slowdown_count() != 0:
			push_error(
				"Dialogue intent revalidation leaked a TimeSystem slowdown: %s"
				% str(llm_bridge.debug_get_llm_runtime_snapshot())
			)
			quit(1)
			return
		if str(last_result.get("decision", "")) != str(case_data.get("decision", "")):
			push_error(
				"Dialogue intent decision mismatch for %s: %s"
				% [npc_id, str(snapshot)]
			)
			quit(1)
			return
		if str(case_data.get("decision", "")) == "modify":
			var modified_item: Dictionary = daily_plan_system.get_current_plan_item(
				npc_id
			)
			if (
				"旧说法" in str(modified_item.get("dialogue_goal", ""))
				or str(modified_item.get("intent_source", ""))
					!= "llm_dialogue_intent_revalidation"
			):
				push_error("Modified dialogue goal was not persisted: %s" % str(modified_item))
				quit(1)
				return
		elif str(case_data.get("decision", "")) == "cancel_and_replan":
			if str(last_result.get("status", "")) != "cancelled_and_replanning":
				push_error("Cancelled intent did not trigger replanning: %s" % str(snapshot))
				quit(1)
				return

	print("T0116 dialogue intent revalidation verification passed.")
	quit(0)


func _make_plan(daily_plan_system: Node, dialogue_goal: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "idle",
			"priority": 50,
			"reason": "测试等待",
			"source": "verify_dialogue_intent",
			"target": {},
			"dialogue_goal": ""
		})
	plan[8] = {
		"hour": 8,
		"action_id": "seek_guard_officer",
		"priority": 80,
		"reason": "复核后再与守备官交涉",
		"source": "verify_dialogue_intent",
		"target": {},
		"dialogue_goal": dialogue_goal
	}
	return plan


func _wait_for_result(
	daily_plan_system: Node,
	npc_id: String,
	timeout_seconds: float
) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var snapshot: Dictionary = (
			daily_plan_system.debug_get_dialogue_intent_revalidation_snapshot(
				npc_id
			)
		)
		if not (snapshot.get("last_result", {}) as Dictionary).is_empty():
			return snapshot
		await create_timer(0.05).timeout
	return daily_plan_system.debug_get_dialogue_intent_revalidation_snapshot(
		npc_id
	)
