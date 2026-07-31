extends SceneTree


const TARGET_NPC_ID := "blacksmith_01"
const OTHER_NPC_ID := "cook_01"
const CAUSAL_MARKER := "缺铁后改去菜园的旧因果仍应可见"
const WITNESS_MARKER := "早先听见仓库铁料告急"


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
	var game_state := root.get_node_or_null("GameState")
	if memory_system == null or llm_bridge == null or game_state == null:
		_fail("Full compact short-memory verification nodes are missing")
		return

	var causal_event: Dictionary = memory_system.add_event({
		"type": "plan_revised",
		"subject_npc_id": TARGET_NPC_ID,
		"actor_ids": [TARGET_NPC_ID],
		"target_ids": [TARGET_NPC_ID],
		"location_id": "blacksmith",
		"visibility": "private",
		"importance": 95,
		"summary": CAUSAL_MARKER,
		"payload": {
			"plan_day": 1,
			"items": _build_idle_plan(),
			"reason": "铁储备为0，无法继续打铁；%s" % CAUSAL_MARKER,
			"source": "llm_plan_revision",
			"summary": CAUSAL_MARKER,
			"work_phase_count": 8,
			"location_snapshot": {
				"people_present": [TARGET_NPC_ID, OTHER_NPC_ID],
				"building_external_states": {"blacksmith": {"level": 1}}
			}
		}
	})
	if causal_event.is_empty():
		_fail("Failed to create the old causal plan_revised event")
		return

	for index in range(12):
		memory_system.add_event({
			"type": "work_started",
			"subject_npc_id": TARGET_NPC_ID,
			"actor_ids": [TARGET_NPC_ID],
			"target_ids": [TARGET_NPC_ID],
			"location_id": "garden",
			"visibility": "private",
			"importance": 30,
			"summary": "后续亲历事件%d" % index,
			"payload": {
				"action_id": "work_garden",
				"workstation_id": "garden_plot_01",
				"technical_sequence": index
			}
		})

	var old_witness_event: Dictionary = memory_system.add_event({
		"type": "resource_changed",
		"subject_npc_id": OTHER_NPC_ID,
		"actor_ids": [OTHER_NPC_ID],
		"target_ids": ["iron"],
		"location_id": "dining_hall",
		"visibility": "private",
		"importance": 90,
		"summary": WITNESS_MARKER,
		"payload": {
			"resource_id": "iron",
			"before": 4,
			"after": 0,
			"reason": "blacksmith_consumption",
			"building_snapshot": {"forbidden_large_snapshot": true}
		}
	})
	if old_witness_event.is_empty() or not memory_system.add_witness_event(
		TARGET_NPC_ID,
		str(old_witness_event.get("event_id", ""))
	):
		_fail("Failed to create the old witnessed resource fact")
		return
	for index in range(12):
		var filler_witness: Dictionary = memory_system.add_event({
			"type": "resource_changed",
			"subject_npc_id": OTHER_NPC_ID,
			"actor_ids": [OTHER_NPC_ID],
			"target_ids": ["grain"],
			"location_id": "dining_hall",
			"visibility": "private",
			"importance": 20,
			"summary": "后续见闻事件%d" % index,
			"payload": {
				"resource_id": "grain",
				"before": 20 - index,
				"after": 19 - index,
				"reason": "verification"
			}
		})
		if filler_witness.is_empty() or not memory_system.add_witness_event(
			TARGET_NPC_ID,
			str(filler_witness.get("event_id", ""))
		):
			_fail("Failed to append witnessed filler event %d" % index)
			return

	var raw_memory: Dictionary = memory_system.get_npc_short_term_memory(TARGET_NPC_ID)
	var expected_experienced := int(raw_memory.get("event_count", 0))
	var expected_witnessed := int(raw_memory.get("witness_count", 0))
	if expected_experienced <= 8 or expected_witnessed <= 8:
		_fail("Fixture did not exceed the removed 8-event boundary")
		return

	var current_plan := _build_idle_plan()
	var current_hour := clampi(int(game_state.current_hour), 0, 23)
	var payloads := {
		"dialogue": llm_bridge.build_npc_dialogue_payload(
			TARGET_NPC_ID,
			"你为什么没继续去铁匠铺？"
		),
		"plan_day": llm_bridge.build_npc_daily_plan_payload(TARGET_NPC_ID),
		"plan_revision_judgement": llm_bridge.build_dialogue_plan_revision_judgement_payload(
			TARGET_NPC_ID,
			{
				"current_plan": current_plan,
				"dialogue_history": [{
					"speaker_id": "guard_officer",
					"speaker_name": "守备官",
					"listener_id": TARGET_NPC_ID,
					"listener_name": "格伦",
					"text": "你为什么没继续去铁匠铺？",
					"visibility": "private"
				}]
			}
		),
		"revise_plan": llm_bridge.build_npc_plan_revision_payload(
			TARGET_NPC_ID,
			{
				"current_plan": current_plan,
				"revision_hours": [current_hour],
				"failed_plan_item": current_plan[current_hour],
				"failure_type": "resource_insufficient",
				"failure_summary": "铁储备不足。",
				"failure_context": {"failure_id": "work_failed_no_resources"}
			}
		),
		"battle_judgement": llm_bridge.build_npc_battle_judgement_payload(
			TARGET_NPC_ID,
			{"allowed_decisions": ["avoid_battle", "escape_station"]}
		),
		"daily_reflection": llm_bridge.build_npc_daily_reflection_payload(
			TARGET_NPC_ID,
			{"day": 1}
		)
	}

	for call_type in payloads.keys():
		var payload: Dictionary = payloads[call_type]
		if payload.is_empty():
			_fail("%s payload is empty" % call_type)
			return
		var short_memory: Dictionary = (
			payload.get("short_memory", {})
			if call_type == "dialogue"
			else (payload.get("npc", {}) as Dictionary).get("short_term_memory", {})
		)
		if not _verify_short_memory(
			call_type,
			short_memory,
			expected_experienced,
			expected_witnessed
		):
			return

	var dialogue_memory: Dictionary = (payloads.get("dialogue", {}) as Dictionary).get(
		"short_memory",
		{}
	)
	var raw_memory_chars := JSON.stringify(raw_memory).length()
	var compact_memory_chars := JSON.stringify(dialogue_memory).length()
	if compact_memory_chars >= raw_memory_chars:
		_fail("Compact LLM projection did not reduce the authoritative raw memory fixture")
		return

	var reflection_payload: Dictionary = payloads.get("daily_reflection", {})
	var day_events: Array = reflection_payload.get("day_events", [])
	if day_events.size() != expected_experienced + expected_witnessed:
		_fail("daily_reflection day_events did not preserve the complete snapshot")
		return
	if not _events_contain_summary(day_events, CAUSAL_MARKER):
		_fail("daily_reflection omitted the old causal plan_revised event")
		return
	if not _events_contain_summary(day_events, WITNESS_MARKER):
		_fail("daily_reflection omitted the old witnessed resource event")
		return
	for raw_event in day_events:
		if not raw_event is Dictionary:
			_fail("daily_reflection contains a non-dictionary event")
			return
		var event: Dictionary = raw_event
		if not ["experienced", "witnessed"].has(str(event.get("memory_kind", ""))):
			_fail("daily_reflection compact event lost memory_kind")
			return
		if not _verify_compact_event(event, "daily_reflection"):
			return

	print(
		"T0106 full compact short-memory verification passed. "
		+ "experienced=%d witnessed=%d raw_chars=%d compact_chars=%d"
		% [
			expected_experienced,
			expected_witnessed,
			raw_memory_chars,
			compact_memory_chars
		]
	)
	quit(0)


func _verify_short_memory(
	call_type: String,
	short_memory: Dictionary,
	expected_experienced: int,
	expected_witnessed: int
) -> bool:
	var experienced: Array = short_memory.get("experienced_events", [])
	var witnessed: Array = short_memory.get("witnessed_events", [])
	if experienced.size() != expected_experienced:
		_fail("%s experienced memory count was truncated" % call_type)
		return false
	if witnessed.size() != expected_witnessed:
		_fail("%s witnessed memory count was truncated" % call_type)
		return false
	if not _events_contain_summary(experienced, CAUSAL_MARKER):
		_fail("%s omitted the old causal plan_revised event" % call_type)
		return false
	if not _events_contain_summary(witnessed, WITNESS_MARKER):
		_fail("%s omitted the old witnessed resource event" % call_type)
		return false
	for raw_event in experienced + witnessed:
		if not raw_event is Dictionary:
			_fail("%s contains a non-dictionary compact event" % call_type)
			return false
		if not _verify_compact_event(raw_event as Dictionary, call_type):
			return false
	var causal_event := _find_event_by_summary(experienced, CAUSAL_MARKER)
	var causal_details: Dictionary = causal_event.get("details", {})
	if not str(causal_details.get("reason", "")).contains("铁储备为0"):
		_fail("%s lost the decision-relevant plan revision reason" % call_type)
		return false
	var plan_segments: Array = causal_details.get("plan_segments", [])
	if plan_segments.size() != 1:
		_fail("%s did not compact 24 repeated plan items into one segment" % call_type)
		return false
	return true


func _verify_compact_event(event: Dictionary, call_type: String) -> bool:
	for forbidden_key in ["event_id", "payload"]:
		if event.has(forbidden_key):
			_fail("%s compact event still contains %s" % [call_type, forbidden_key])
			return false
	var details: Dictionary = event.get("details", {})
	for forbidden_detail in [
		"items",
		"location_snapshot",
		"building_snapshot",
		"enemy_roster",
		"friendly_roster",
		"dialogue_text"
	]:
		if details.has(forbidden_detail):
			_fail("%s compact details still contain %s" % [call_type, forbidden_detail])
			return false
	return true


func _events_contain_summary(events: Array, marker: String) -> bool:
	return not _find_event_by_summary(events, marker).is_empty()


func _find_event_by_summary(events: Array, marker: String) -> Dictionary:
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("summary", "")).contains(marker):
			return raw_event as Dictionary
	return {}


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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
