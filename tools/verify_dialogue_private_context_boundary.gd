extends SceneTree


const SPEAKER_ID := "blacksmith_01"
const REPLYER_ID := "gardener_01"
const PRIVATE_MARKER := "蓝鸦七号铁盔批次只记在格伦私账中"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if memory_system == null or llm_bridge == null:
		_fail("Dialogue private-context verification required nodes not found")
		return

	var private_event: Dictionary = memory_system.add_event({
		"type": "order_assigned",
		"subject_npc_id": SPEAKER_ID,
		"actor_ids": ["guard_officer"],
		"target_ids": [SPEAKER_ID],
		"location_id": "blacksmith",
		"visibility": "private",
		"importance": 90,
		"summary": PRIVATE_MARKER,
		"payload": {
			"previous_order_text": "",
			"new_order_text": PRIVATE_MARKER,
			"order_revision": 1,
			"private_marker": PRIVATE_MARKER,
			"target_item_id": "item_iron_helmet"
		}
	})
	if private_event.is_empty():
		_fail("Failed to create the speaker-only private memory fixture")
		return

	var speaker_memory: Dictionary = memory_system.get_npc_short_term_memory(SPEAKER_ID)
	var replyer_memory: Dictionary = memory_system.get_npc_short_term_memory(REPLYER_ID)
	if not _contains_marker(speaker_memory):
		_fail("Speaker private memory fixture was not stored")
		return
	if _contains_marker(replyer_memory):
		_fail("Replyer received the speaker's private memory before payload construction")
		return

	var dialogue_payload: Dictionary = llm_bridge.build_npc_dialogue_payload(
		REPLYER_ID,
		"伊沃，菜园工位你还要用多久？",
		{
			"dialogue_kind": "npc_npc",
			"dialogue_phase": "invitation",
			"speaker_kind": "npc",
			"speaker_npc_id": SPEAKER_ID,
			"speaker_name": "格伦",
			"dialogue_state": {
				"visibility": "local_public",
				"location_id": "garden",
				"location_name": "菜园",
				"participants": [SPEAKER_ID, REPLYER_ID]
			}
		}
	)
	if dialogue_payload.is_empty():
		_fail("Failed to build NPC-NPC dialogue payload")
		return
	if dialogue_payload.has("speaker_npc"):
		_fail("NPC-NPC dialogue payload still exposes speaker_npc")
		return
	var speaker_context: Dictionary = dialogue_payload.get("speaker_context", {})
	if not (speaker_context.get("state", {}) as Dictionary).is_empty():
		_fail("speaker_context.state must not expose the speaker's private runtime state")
		return
	for forbidden_key in [
		"short_term_memory",
		"long_term_memory",
		"knowledge_graph",
		"current_order",
		"location_context",
		"plaza_context",
		"skills",
		"stats",
		"money",
		"wine"
	]:
		if speaker_context.has(forbidden_key):
			_fail("speaker_context exposes forbidden key: %s" % forbidden_key)
			return
	if _contains_marker(dialogue_payload):
		_fail("Replyer dialogue payload leaked the speaker-only private marker")
		return
	for raw_action in dialogue_payload.get("allowed_actions", []):
		var action: Dictionary = raw_action
		if str(action.get("action_id", "")) != "talk_to_npc":
			continue
		if action.has("location_id"):
			_fail("talk_to_npc candidate exposed or bound another NPC's live location")
			return
		var action_context: Dictionary = action.get("context", {})
		for private_runtime_key in ["current_action", "current_location_name", "recruited"]:
			if action_context.has(private_runtime_key):
				_fail("talk_to_npc candidate exposed private runtime key: %s" % private_runtime_key)
				return

	var target_short_memory: Dictionary = dialogue_payload.get("short_memory", {})
	var target_long_memory: Dictionary = dialogue_payload.get("long_memory", {})
	if (
		not target_short_memory.has("experienced_events")
		or not target_short_memory.has("witnessed_events")
		or not target_long_memory.has("knowledge_graph")
		or not target_long_memory.has("diary")
	):
		_fail("The replyer's own short/long memory was removed while isolating the speaker")
		return

	var all_payloads := {
		"dialogue": dialogue_payload,
		"plan_day": llm_bridge.build_npc_daily_plan_payload(REPLYER_ID),
		"plan_revision_judgement": llm_bridge.build_dialogue_plan_revision_judgement_payload(REPLYER_ID, {
			"current_plan": _build_idle_plan(),
			"dialogue_history": [{
				"speaker_id": SPEAKER_ID,
				"speaker_name": "格伦",
				"listener_id": REPLYER_ID,
				"listener_name": "伊沃",
				"text": "伊沃，菜园工位你还要用多久？",
				"visibility": "local_public"
			}]
		}),
		"revise_plan": llm_bridge.build_npc_plan_revision_payload(REPLYER_ID),
		"battle_judgement": llm_bridge.build_npc_battle_judgement_payload(REPLYER_ID, {
			"allowed_decisions": ["avoid_battle", "escape_station"]
		}),
		"daily_reflection": llm_bridge.build_npc_daily_reflection_payload(REPLYER_ID, {"day": 1})
	}
	for call_type in all_payloads.keys():
		var payload: Dictionary = all_payloads[call_type]
		if payload.is_empty():
			_fail("%s payload was empty during six-call audit" % call_type)
			return
		if _contains_marker(payload):
			_fail("%s payload leaked another NPC's private marker" % call_type)
			return

	print("T0071 dialogue private-context boundary verification passed.")
	quit(0)


func _build_idle_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_kind": "idle",
			"action_id": "idle",
			"location_id": null,
			"target_id": null,
			"priority": 20,
			"reason": "等待",
			"dialogue_goal": ""
		})
	return plan


func _contains_marker(value: Variant) -> bool:
	return JSON.stringify(value).contains(PRIVATE_MARKER)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
