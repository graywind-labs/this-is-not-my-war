extends SceneTree


const MAIN_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const NPC_ID := "stableman_01"
const CURRENT_HOUR := 8
const RECOVERY_ACTION_IDS: Array[String] = [
	"sleep_in_dormitory", "pray_at_chapel", "attend_mass", "drink_wine",
	"receive_clinic_treatment"
]


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	root.add_child(packed.instantiate())
	for _frame in 6:
		await process_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [time_system, npc_system, needs_system, daily_plan_system, llm_bridge].has(null):
		_fail("Required runtime nodes are missing")
		return

	llm_bridge.set_backend_base_url(_backend_url())
	llm_bridge.request_timeout_seconds = 180.0
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
		_fail("Formal full-fatigue verification requires a configured real provider without Mock fallback")
		return

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	time_system.set_paused(true)
	daily_plan_system.set_auto_execution_enabled(false)
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_plan(), false, "verify_full_fatigue_real"):
		_fail("Could not install the real-provider full-fatigue plan")
		return
	needs_system.initialize()
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 99,
		"satiety": 100,
		"current_location": "stable",
		"unconscious": false,
		"escaped": false,
		"behavior_mode": "work"
	})
	needs_system.debug_advance_profile(NPC_ID, "light_work", 600.0)

	var result: Dictionary = await _wait_for_reevaluation(daily_plan_system, 360.0)
	var judgement: Dictionary = daily_plan_system.get_last_plan_revision_judgement_result()
	var revised_plan: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	var current_item: Dictionary = revised_plan[CURRENT_HOUR] if revised_plan.size() == 24 else {}
	if (
		str(judgement.get("failure_type", "")) != "high_fatigue"
		or not bool(judgement.get("revision_requested", false))
		or not (judgement.get("revision_hours", []) as Array).has(CURRENT_HOUR)
		or str(judgement.get("model_provider", "")).strip_edges().to_lower() in ["", "mock"]
		or bool(judgement.get("fallback_used", false))
	):
		_fail("Real stage-one fatigue judgement was not accepted: %s" % JSON.stringify(judgement))
		return
	if (
		not bool(result.get("plan_applied", false))
		or str(result.get("reason", "")) != "high_fatigue"
		or str(result.get("source", "")) != "llm_plan_revision"
		or bool(result.get("fallback_used", true))
		or str(result.get("model_provider", "")).strip_edges().to_lower() in ["", "mock"]
	):
		_fail("Real stage-two fatigue revision was not applied: %s" % JSON.stringify(result))
		return
	if not RECOVERY_ACTION_IDS.has(str(current_item.get("action_id", ""))):
		_fail("Real fatigue revision did not replace current work with recovery: %s" % JSON.stringify(current_item))
		return

	print(JSON.stringify({
		"ok": true,
		"provider": result.get("model_provider", ""),
		"model": result.get("model_name", ""),
		"judgement_hours": judgement.get("revision_hours", []),
		"current_action": current_item.get("action_id", ""),
		"fallback_used": result.get("fallback_used", true)
	}))
	quit(0)


func _wait_for_reevaluation(daily_plan_system: Node, timeout_seconds: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var result: Dictionary = daily_plan_system.get_last_reevaluation_result()
		if (
			str(result.get("npc_id", "")) == NPC_ID
			and str(result.get("reason", "")) == "high_fatigue"
			and str(result.get("status", "")) not in [
				"pending", "pending_async", "plan_revision_judgement_pending",
				"action_failure_plan_revision_requested"
			]
		):
			return result
		await create_timer(0.05).timeout
	return daily_plan_system.get_last_reevaluation_result()


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		var action_id := "work_stable" if hour >= CURRENT_HOUR and hour <= 15 else "idle"
		plan.append({
			"hour": hour,
			"action_kind": "work" if action_id == "work_stable" else "idle",
			"action_id": action_id,
			"location_id": "stable" if action_id == "work_stable" else "",
			"target_id": "",
			"reason": "连续照料马厩。" if action_id == "work_stable" else "空闲。"
		})
	return plan


func _backend_url() -> String:
	var from_env := OS.get_environment("BACKEND_BASE_URL").strip_edges()
	return from_env.trim_suffix("/") if not from_env.is_empty() else DEFAULT_BACKEND_URL


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
