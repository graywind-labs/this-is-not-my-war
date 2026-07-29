extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const NPC_ID := "veteran_deputy_01"
const CURRENT_HOUR := 8
const ORDER_TEXT := "立刻前往小教堂并在那里停留，检查是否安全；当前小时优先执行。"


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var order_panel := root.get_node_or_null("Main/UI/OrderPanel")
	var order_text := root.get_node_or_null(
		"Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/OrderTextEdit"
	) as TextEdit
	var publish_button := root.get_node_or_null(
		"Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/ButtonRow/OrderPublishButton"
	) as Button
	if [
		time_system,
		npc_system,
		daily_plan_system,
		llm_bridge,
		order_panel,
		order_text,
		publish_button
	].has(null):
		_fail("Required runtime nodes are missing")
		return

	llm_bridge.set_backend_base_url(_backend_url())
	llm_bridge.request_timeout_seconds = 4.0
	var health: Dictionary = llm_bridge.check_health()
	if not bool(health.get("ok", false)):
		_fail("Real backend health check failed: %s" % JSON.stringify(health))
		return
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {})
	if (
		str(adapter.get("provider", "")).strip_edges().to_lower() == "mock"
		or not bool(adapter.get("configured", false))
		or bool(adapter.get("fallback_to_mock", false))
	):
		_fail("Formal order-plan verification requires a configured real provider without Mock fallback")
		return

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	daily_plan_system.set_auto_execution_enabled(false)
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_plan(),
		false,
		"verify_order_plan_effect_real"
	):
		_fail("Could not install the real-provider baseline plan")
		return
	var before_item: Dictionary = daily_plan_system.get_npc_daily_plan(NPC_ID)[CURRENT_HOUR]
	if str(before_item.get("action_id", "")) != "idle":
		_fail("Real-provider baseline must begin with idle")
		return

	var show_result: Dictionary = order_panel.show_order(NPC_ID)
	if not bool(show_result.get("ok", false)):
		_fail("Could not open OrderPanel: %s" % JSON.stringify(show_result))
		return
	order_text.text = ORDER_TEXT
	publish_button.pressed.emit()

	var result: Dictionary = await _wait_for_reevaluation(daily_plan_system, NPC_ID, 240.0)
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	var injected_order: Dictionary = (
		injection.get("current_order", {})
		if injection.get("current_order", {}) is Dictionary
		else {}
	)
	if (
		str(injection.get("call_type", "")) != "revise_plan"
		or str(injected_order.get("text", "")) != ORDER_TEXT
	):
		_fail("The live revise_plan call did not inject the published order: %s" % JSON.stringify(injection))
		return
	if (
		not bool(result.get("plan_applied", false))
		or str(result.get("reason", "")) != "order_changed"
		or str(result.get("source", "")) != "llm_plan_revision"
		or bool(result.get("fallback_used", true))
		or str(result.get("model_provider", "")).strip_edges().to_lower() in ["", "mock"]
	):
		_fail("The real provider did not apply an order-driven plan revision: %s" % JSON.stringify(result))
		return

	var after_item: Dictionary = daily_plan_system.get_npc_daily_plan(NPC_ID)[CURRENT_HOUR]
	var target: Dictionary = (
		after_item.get("target", {})
		if after_item.get("target", {}) is Dictionary
		else {}
	)
	if (
		str(after_item.get("action_id", "")) != "visit_location"
		or str(target.get("target_id", "")) != "chapel"
	):
		_fail(
			"The real provider received the order but did not turn the current plan into a chapel visit: %s"
			% JSON.stringify(after_item)
		)
		return

	print(JSON.stringify({
		"ok": true,
		"provider": result.get("model_provider", ""),
		"model": result.get("model_name", ""),
		"status": result.get("status", ""),
		"before_action": before_item.get("action_id", ""),
		"after_action": after_item.get("action_id", ""),
		"after_target": target.get("target_id", ""),
		"order_injected": true
	}))
	quit(0)


func _wait_for_reevaluation(
	daily_plan_system: Node,
	npc_id: String,
	timeout_seconds: float
) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var result: Dictionary = daily_plan_system.get_last_reevaluation_result()
		if (
			str(result.get("npc_id", "")) == npc_id
			and str(result.get("status", "")) not in [
				"pending",
				"pending_async",
				"plan_revision_judgement_pending",
				"action_failure_plan_revision_requested"
			]
		):
			return result
		await create_timer(0.05).timeout
	return daily_plan_system.get_last_reevaluation_result()


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		var action_id := "work_training_instructor" if hour >= 9 and hour <= 14 else "idle"
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0073 real-provider order-plan baseline",
			"source": "verify_order_plan_effect_real"
		})
	return plan


func _backend_url() -> String:
	var configured := OS.get_environment("T0073_BACKEND_URL").strip_edges()
	return DEFAULT_BACKEND_URL if configured.is_empty() else configured


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
