extends SceneTree


class CapturingLLMBridge:
	extends Node

	signal plan_revision_async_response_received(result: Dictionary)

	var revision_requests: Array[Dictionary] = []


	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()


	func check_health() -> Dictionary:
		return _real_health()


	func request_npc_plan_revision_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "order_revision_%d" % (revision_requests.size() + 1)
		revision_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}


	func answer_revision(request: Dictionary, revised_item: Dictionary) -> void:
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"ok": true,
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": [revised_item.duplicate(true)],
				"immediate_action": revised_item.duplicate(true),
				"summary": "守备官的新指令使当前计划改为前往小教堂。",
				"debug_reason": "deterministic order plan effect verification",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})


	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "capture-real-provider",
					"configured": true,
					"fallback_to_mock": false
				}
			}
		}


const NPC_ID := "veteran_deputy_01"
const CURRENT_HOUR := 8
const ORDER_TEXT := "立刻去小教堂停留，确认那里是否安全。"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var systems := root.get_node_or_null("Main/Systems")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var order_panel := root.get_node_or_null("Main/UI/OrderPanel")
	var order_text := root.get_node_or_null(
		"Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/OrderTextEdit"
	) as TextEdit
	var publish_button := root.get_node_or_null(
		"Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/ButtonRow/OrderPublishButton"
	) as Button
	if [
		systems,
		time_system,
		npc_system,
		daily_plan_system,
		original_bridge,
		order_panel,
		order_text,
		publish_button
	].has(null):
		_fail("Required runtime nodes are missing")
		return

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	daily_plan_system.set_auto_execution_enabled(false)
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_plan(),
		false,
		"verify_order_plan_effect"
	):
		_fail("Could not install the deterministic 24-hour plan")
		return
	var before_plan: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	if str((before_plan[CURRENT_HOUR] as Dictionary).get("action_id", "")) != "idle":
		_fail("Verification plan must begin with idle at the current hour")
		return

	systems.remove_child(original_bridge)
	original_bridge.name = "PayloadInspector"
	systems.add_child(original_bridge)
	var bridge := CapturingLLMBridge.new()
	bridge.name = "LLMBridge"
	systems.add_child(bridge)
	bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)

	var show_result: Dictionary = order_panel.show_order(NPC_ID)
	if not bool(show_result.get("ok", false)):
		_fail("Could not open OrderPanel: %s" % JSON.stringify(show_result))
		return
	order_text.text = ORDER_TEXT
	publish_button.pressed.emit()
	await process_frame

	if bridge.revision_requests.size() != 1:
		_fail("Publishing a changed order did not launch exactly one plan revision")
		return
	var request: Dictionary = bridge.revision_requests[0]
	var options: Dictionary = request.get("options", {})
	if (
		str(request.get("npc_id", "")) != NPC_ID
		or str(options.get("failure_type", "")) != "order_changed"
		or options.get("revision_hours", []) != [CURRENT_HOUR]
		or (options.get("current_plan", []) as Array).size() != 24
	):
		_fail("Order-triggered plan revision options are incomplete: %s" % JSON.stringify(request))
		return
	var payload: Dictionary = original_bridge.build_npc_plan_revision_payload(NPC_ID, options)
	var payload_order: Dictionary = (
		(payload.get("npc", {}) as Dictionary).get("current_order", {})
		if payload.get("npc", {}) is Dictionary
		else {}
	)
	if (
		str(payload_order.get("text", "")) != ORDER_TEXT
		or str(payload.get("failure_type", "")) != "order_changed"
		or payload.get("revision_hours", []) != [CURRENT_HOUR]
	):
		_fail("Formal revision payload did not inject the newly published order: %s" % JSON.stringify(payload_order))
		return

	var revised_item := {
		"hour": CURRENT_HOUR,
		"action_kind": "visit",
		"action_id": "visit_location",
		"location_id": "chapel",
		"target_id": "chapel",
		"priority": 95,
		"reason": "遵循守备官的新指令，前往小教堂确认安全。",
		"dialogue_goal": ""
	}
	bridge.answer_revision(request, revised_item)
	await process_frame
	await process_frame

	var after_plan: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	var current_item: Dictionary = after_plan[CURRENT_HOUR]
	var current_target: Dictionary = (
		current_item.get("target", {})
		if current_item.get("target", {}) is Dictionary
		else {}
	)
	if (
		str(current_item.get("action_id", "")) != "visit_location"
		or str(current_target.get("target_id", "")) != "chapel"
		or str(current_item.get("source", "")) != "llm_plan_revision"
	):
		_fail("Published order did not change the authoritative current plan: %s" % JSON.stringify(current_item))
		return
	var applied: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if (
		not bool(applied.get("plan_applied", false))
		or str(applied.get("reason", "")) != "order_changed"
		or str(applied.get("source", "")) != "llm_plan_revision"
		or bool(applied.get("fallback_used", true))
	):
		_fail("Order-driven plan revision did not finish as a real-provider plan application: %s" % JSON.stringify(applied))
		return

	print("T0073 order publication changed the authoritative plan through the formal revision chain.")
	quit(0)


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		var action_id := "work_training_instructor" if hour >= 9 and hour <= 14 else "idle"
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0073 order-plan effect baseline",
			"source": "verify_order_plan_effect"
		})
	return plan


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
