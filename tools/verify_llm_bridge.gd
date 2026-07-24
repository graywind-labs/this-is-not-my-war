extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const LLM_BRIDGE_SCRIPT := "res://scripts/systems/LLMBridge.gd"
const BACKEND_URL := "http://127.0.0.1:5000"
const CLOSED_BACKEND_URL := "http://127.0.0.1:5999"

func _init() -> void:
	var live_backend_url := OS.get_environment("TEST_BACKEND_URL").strip_edges()
	if live_backend_url.is_empty():
		live_backend_url = BACKEND_URL
	var script_file := FileAccess.open(LLM_BRIDGE_SCRIPT, FileAccess.READ)
	if script_file == null:
		push_error("Failed to read LLMBridge.gd")
		quit(1)
		return
	var script_source := script_file.get_as_text()
	script_file.close()
	for forbidden in ["curl.exe", "OS.execute", "llm_bridge_request_", "_write_request_body_file"]:
		if script_source.contains(forbidden):
			push_error("LLMBridge transport must not depend on %s" % forbidden)
			quit(1)
			return

	var main_scene := load(MAIN_SCENE) as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	if llm_bridge == null or time_system == null or npc_system == null or hud == null:
		push_error("LLMBridge verification required nodes not found")
		quit(1)
		return

	var target_npc_id := "veteran_deputy_01"
	var publish_result: Dictionary = npc_system.publish_npc_order(target_npc_id, "优先守住城门，但不要冒进。")
	if not bool(publish_result.get("ok", false)):
		push_error("Failed to publish order before LLMBridge payload verification")
		quit(1)
		return
	var payload: Dictionary = llm_bridge.build_npc_dialogue_payload(target_npc_id, "我们要一起守住这里。", {
		"is_recruitment_request": true,
		"dialogue_state": {
			"visibility": "local_public"
		},
		"current_round": 1,
		"max_rounds": 3
	})
	if payload.is_empty():
		push_error("LLMBridge failed to build dialogue payload")
		quit(1)
		return
	if str(payload.get("speaker_name", "")) != "守备官":
		push_error("Player initiated dialogue must use speaker_name == 守备官")
		quit(1)
		return
	if str(payload.get("dialogue_phase", "")) != "conversation":
		push_error("Ordinary dialogue payload must default to conversation phase")
		quit(1)
		return
	if str(payload.get("npc_id", "")) != target_npc_id:
		push_error("Dialogue payload target npc_id mismatch")
		quit(1)
		return
	if not bool(payload.get("is_recruitment_request", false)):
		push_error("Dialogue payload recruitment flag was not preserved")
		quit(1)
		return
	var dialogue_state: Dictionary = payload.get("dialogue_state", {})
	if str(dialogue_state.get("visibility", "")) != "local_public":
		push_error("Dialogue payload visibility mismatch")
		quit(1)
		return
	var short_memory: Dictionary = payload.get("short_memory", {})
	if not short_memory.has("experienced_events") or not short_memory.has("witnessed_events"):
		push_error("Dialogue payload short memory must separate experienced_events and witnessed_events")
		quit(1)
		return
	var speaker_context: Dictionary = payload.get("speaker_context", {})
	if str(speaker_context.get("speaker_kind", "")) != "guard_officer":
		push_error("Guard officer speaker_context was not generated")
		quit(1)
		return
	var current_order: Dictionary = payload.get("current_order", {})
	var target_npc: Dictionary = payload.get("target_npc", {})
	if str(current_order.get("text", "")) != "优先守住城门，但不要冒进。" or target_npc.get("current_order", {}) != current_order:
		push_error("Dialogue and shared NPC context must contain the latest current_order")
		quit(1)
		return
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("npc_id", "")) != target_npc_id or injection.get("current_order", {}) != current_order:
		push_error("LLMBridge did not expose the latest current_order injection snapshot")
		quit(1)
		return
	var invitation_payload: Dictionary = llm_bridge.build_npc_dialogue_payload(target_npc_id, "我想和你谈谈。", {
		"dialogue_kind": "npc_npc",
		"dialogue_phase": "invitation",
		"speaker_kind": "npc",
		"speaker_npc_id": "doctor_01",
		"current_round": 1,
		"max_rounds": 0,
		"soft_round_threshold": 5,
		"soft_round_guidance": "第六轮起若无紧急或必要事项，应自然告别并结束。"
	})
	if (
		str(invitation_payload.get("dialogue_phase", "")) != "invitation"
		or int(invitation_payload.get("current_round", -1)) != 0
		or int(invitation_payload.get("max_rounds", -1)) != 0
		or int(invitation_payload.get("soft_round_threshold", 0)) != 5
		or str(invitation_payload.get("soft_round_guidance", "")).is_empty()
		or int((invitation_payload.get("dialogue_state", {}) as Dictionary).get("current_round", -1)) != 0
		or int((invitation_payload.get("dialogue_state", {}) as Dictionary).get("max_rounds", -1)) != 0
	):
		push_error("NPC invitation payload must be a pre-round phase with soft guidance and no hard cap")
		quit(1)
		return
	llm_bridge.cancel_npc_llm_requests(target_npc_id, "verification_cleanup")

	print("LLMBridge verify: closed health")
	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.5
	var closed_result: Dictionary = llm_bridge.check_health()
	if bool(closed_result.get("ok", false)):
		push_error("Closed backend health check should fail without crashing")
		quit(1)
		return

	print("LLMBridge verify: live health")
	llm_bridge.set_backend_base_url(live_backend_url)
	llm_bridge.request_timeout_seconds = 4.0
	var health_result: Dictionary = llm_bridge.check_health()
	if not bool(health_result.get("ok", false)):
		push_error("Backend health check failed. Start backend/app.py before running this verification. Result: %s" % str(health_result))
		quit(1)
		return

	var backend_label := hud.get_node_or_null("%BackendStatusLabel") as Label
	if backend_label == null or not backend_label.text.begins_with("后端：已连接"):
		push_error("HUD did not display connected backend status")
		quit(1)
		return

	print("LLMBridge verify: live dialogue")
	time_system.set_time_scale(4.0)
	var dialogue_result: Dictionary = llm_bridge.request_npc_dialogue("cook_01", "守备官需要你一起保护大家。", {
		"is_recruitment_request": true,
		"current_round": 1,
		"max_rounds": 3
	})
	if not bool(dialogue_result.get("ok", false)):
		push_error("Dialogue mock request failed: %s" % str(dialogue_result))
		quit(1)
		return
	var dialogue: Dictionary = dialogue_result.get("dialogue", {})
	if str(dialogue.get("replyer_id", "")) != "cook_01":
		push_error("Dialogue mock replyer_id mismatch")
		quit(1)
		return
	if str(dialogue.get("recruitment_result", "")) != "accept":
		push_error("Dialogue mock recruitment result should accept persuasive guard text")
		quit(1)
		return
	if not llm_bridge.debug_was_slowdown_registered():
		push_error("Dialogue request did not register an LLM slowdown")
		quit(1)
		return
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Dialogue request left pending LLM slowdown ids")
		quit(1)
		return
	if absf(time_system.get_effective_time_scale() - 4.0) > 0.001:
		push_error("Dialogue request did not restore player time scale")
		quit(1)
		return

	print("LLMBridge verify: usage snapshot")
	var usage_result: Dictionary = llm_bridge.debug_request_llm_usage()
	if not bool(usage_result.get("ok", false)):
		push_error("LLM usage request failed: %s" % str(usage_result))
		quit(1)
		return
	var usage_body: Dictionary = usage_result.get("body", {})
	var usage_summary: Dictionary = usage_body.get("summary", {})
	if int(usage_summary.get("count", 0)) <= 0:
		push_error("LLM usage summary should include the dialogue call")
		quit(1)
		return
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("LLM usage request must not leave pending slowdown ids")
		quit(1)
		return
	if not llm_bridge.has_method("debug_get_llm_runtime_snapshot"):
		push_error("LLMBridge must expose runtime debug snapshot")
		quit(1)
		return
	var runtime_snapshot: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
	if int(runtime_snapshot.get("pending_slowdown_count", -1)) != 0:
		push_error("LLM runtime snapshot pending_slowdown_count mismatch")
		quit(1)
		return
	var runtime_time_scale: Dictionary = runtime_snapshot.get("time_scale", {})
	if runtime_time_scale.is_empty() or not runtime_time_scale.has("effective_scale"):
		push_error("LLM runtime snapshot must include TimeSystem effective scale")
		quit(1)
		return
	if not runtime_time_scale.has("last_time_scale_reason"):
		push_error("TimeSystem snapshot must include last_time_scale_reason")
		quit(1)
		return

	print("LLMBridge verify: failed dialogue")
	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.5
	var failed_dialogue: Dictionary = llm_bridge.request_npc_dialogue("cook_01", "这次后端关着。", {})
	if bool(failed_dialogue.get("ok", false)):
		push_error("Dialogue request against closed backend should fail")
		quit(1)
		return
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Failed dialogue request left pending LLM slowdown ids")
		quit(1)
		return
	if absf(time_system.get_effective_time_scale() - 4.0) > 0.001:
		push_error("Failed dialogue request did not restore player time scale")
		quit(1)
		return

	print("T0604A LLMBridge verification passed.")
	quit(0)
