extends SceneTree


const NPC_IDS: Array[String] = [
	"stableman_01",
	"cook_01",
	"gardener_01",
	"blacksmith_01",
	"veteran_deputy_01",
	"priest_01",
	"doctor_01",
	"engineer_01"
]
const DIARY_PERIODS: Array[String] = ["往昔·来站前", "往昔·初到驿站", "往昔·近日"]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if npc_system == null or building_system == null or llm_bridge == null or npc_panel == null:
		_fail("Initial long-memory verification required nodes not found")
		return
	if npc_system.get_npc_ids() != NPC_IDS:
		_fail("Initial NPC ids changed or NPCSystem failed to load the complete memory dataset")
		return

	var building_ids: Array = building_system.get_building_ids()
	if building_ids.size() != 15:
		_fail("Expected 15 configured buildings, got %d" % building_ids.size())
		return

	var idle_plan := _build_idle_plan()
	var largest_payload_chars: Dictionary = {}
	for npc_id in NPC_IDS:
		var npc: Dictionary = npc_system.get_npc(npc_id)
		var long_memory: Dictionary = npc_system.get_npc_long_memory(npc_id)
		var diary: Array = long_memory.get("diary", [])
		var graph: Dictionary = long_memory.get("knowledge_graph", {})
		if diary.size() < 3:
			_fail("%s did not load three initial diary slices" % npc_id)
			return
		for index in range(3):
			var diary_entry: Dictionary = diary[index] if diary[index] is Dictionary else {}
			if (
				int(diary_entry.get("day", -1)) != 0
				or str(diary_entry.get("time", "")) != DIARY_PERIODS[index]
				or str(diary_entry.get("entry", "")).strip_edges().is_empty()
				or str(diary_entry.get("source", "")) != "initial_long_memory"
				or str(diary_entry.get("model_provider", "")) != ""
				or str(diary_entry.get("model_name", "")) != ""
				or bool(diary_entry.get("model_fallback_used", true))
				or str(diary_entry.get("debug_reason", "")) != "seeded_before_game"
				or diary_entry.has("memory_summary")
			):
				_fail("%s initial diary record %d did not keep the runtime diary shape" % [npc_id, index])
				return
		if str(graph.get("schema_version", "")) != "key_value_replace_v1" or graph.has("patches"):
			_fail("%s did not load a replace-style knowledge graph" % npc_id)
			return
		var by_subject: Dictionary = graph.get("by_subject", {}) if graph.get("by_subject", {}) is Dictionary else {}
		for raw_building_id in building_ids:
			if not by_subject.has(str(raw_building_id)):
				_fail("%s knowledge graph missed building %s" % [npc_id, str(raw_building_id)])
				return
		for other_npc_id in NPC_IDS:
			if other_npc_id != npc_id and not by_subject.has(other_npc_id):
				_fail("%s knowledge graph missed resident %s" % [npc_id, other_npc_id])
				return
		if not by_subject.has("guard_officer"):
			_fail("%s knowledge graph missed the guard-officer duties relation" % npc_id)
			return
		for non_building_id in ["plaza", "notice_board"]:
			if by_subject.has(non_building_id):
				_fail("%s incorrectly seeded %s as a building subject" % [npc_id, non_building_id])
				return
		var warehouse_record: Dictionary = (
			by_subject.get("warehouse", {}).values()[0]
			if by_subject.get("warehouse", {}) is Dictionary
			and not (by_subject.get("warehouse", {}) as Dictionary).is_empty()
			else {}
		)
		var warehouse_text := str(warehouse_record.get("value_label", ""))
		if (
			str(warehouse_record.get("value", ""))
			!= "level_based_bulk_storage_and_post_breach_attack_target"
			or not warehouse_text.contains("上限")
			or not warehouse_text.contains("扩建")
		):
			_fail("%s did not load level-based warehouse-capacity knowledge" % npc_id)
			return
		var wall_text := _format_relation_values(by_subject.get("wall", {}))
		var main_hall_text := _format_relation_values(by_subject.get("main_hall", {}))
		if (
			not wall_text.contains("弩床")
			or not wall_text.contains("箭塔")
			or not wall_text.contains("1、2、2、3、3、4")
		):
			_fail("%s did not load the current wall slot curve" % npc_id)
			return
		if (
			not main_hall_text.contains("弩床")
			or not main_hall_text.contains("箭塔")
			or not main_hall_text.contains("1、1、2、2、3、4")
		):
			_fail("%s did not load the current main-hall slot rule" % npc_id)
			return
		for removed_range_phrase in ["两倍", "翻倍", "加倍", "2.0x"]:
			if main_hall_text.contains(removed_range_phrase):
				_fail("%s retained the removed main-hall range bonus" % npc_id)
				return
		for stale_phrase in [
			"只能安在各自合适的墙位",
			"只会让墙体更耐打",
			"不会凭空多出安装器械的地方"
		]:
			if ("%s %s" % [wall_text, main_hall_text]).contains(stale_phrase):
				_fail("%s retained stale wall-only device knowledge" % npc_id)
				return
		if npc_id == "veteran_deputy_01":
			var training_relations: Dictionary = by_subject.get("training_ground", {})
			var instructor_rule: Dictionary = training_relations.get("instructor_growth_rule", {})
			if not str(instructor_rule.get("value_label", "")).contains("没有受训者"):
				_fail("Ada did not load the solo-instructor growth rule")
				return
		elif npc_id == "stableman_01":
			if not (by_subject.get("stable", {}) as Dictionary).has("assignment_rule"):
				_fail("Toma did not load the horse-assignment rule")
				return
		elif npc_id == "cook_01":
			if not (by_subject.get("dining_hall", {}) as Dictionary).has("meal_value_rule"):
				_fail("Bruno did not load the prepared-meal rule")
				return
		elif npc_id == "doctor_01":
			if not (by_subject.get("clinic", {}) as Dictionary).has("study_rule"):
				_fail("Lina did not load the idle-study rule")
				return

		var diary_text: String = npc_panel._format_diary_block(diary)
		for period in DIARY_PERIODS:
			if not diary_text.contains(period):
				_fail("%s diary UI lost period label %s" % [npc_id, period])
				return
		var knowledge_text: String = npc_panel._format_knowledge_graph_block(graph)
		if not knowledge_text.contains("【守备官】"):
			_fail("%s knowledge UI did not use the Chinese guard-officer label" % npc_id)
			return
		if knowledge_text.contains("可信度") or knowledge_text.contains("更新于"):
			_fail("%s knowledge UI exposed internal confidence/time metadata" % npc_id)
			return
		var guard_relations: Dictionary = by_subject.get("guard_officer", {})
		var expected_guard_values := {
			"role": "station_defense_alert_and_emergency_staff_coordination",
			"arrival_at_station": "arrived_three_years_before_game_start",
			"past_before_station": "unknown_not_disclosed",
			"pre_game_relationship": "consistently_dedicated_and_harmonious",
		}
		if guard_relations.size() != expected_guard_values.size():
			_fail("%s guard-officer seed must contain four stable background relations" % npc_id)
			return
		for relation_key in expected_guard_values:
			var guard_record: Dictionary = guard_relations.get(relation_key, {})
			if (
				str(guard_record.get("value", "")) != str(expected_guard_values[relation_key])
				or not guard_record.has("confidence")
				or not guard_record.has("day")
				or not guard_record.has("time")
			):
				_fail("%s guard-officer relation %s lost its stable value or metadata" % [
					npc_id,
					relation_key,
				])
				return
		if (
			not str(guard_relations.get("arrival_at_station", {}).get("value_label", "")).contains("三年前")
			or not str(guard_relations.get("past_before_station", {}).get("value_label", "")).contains("不")
			or not str(guard_relations.get("pre_game_relationship", {}).get("value_label", "")).contains("和")
		):
			_fail("%s guard-officer player-facing history boundary is incomplete" % npc_id)
			return
		for raw_building_id in building_ids:
			var building: Dictionary = building_system.get_building(str(raw_building_id))
			if not knowledge_text.contains("【%s】" % str(building.get("name", ""))):
				_fail("%s knowledge UI missed Chinese building label %s" % [
					npc_id,
					str(building.get("name", ""))
				])
				return
		for other_npc_id in NPC_IDS:
			if other_npc_id == npc_id:
				continue
			var other_npc: Dictionary = npc_system.get_npc(other_npc_id)
			if not knowledge_text.contains("【%s】" % str(other_npc.get("name", ""))):
				_fail("%s knowledge UI missed Chinese resident label %s" % [
					npc_id,
					str(other_npc.get("name", ""))
				])
				return

		var payloads := {
			"dialogue": llm_bridge.build_npc_dialogue_payload(
				npc_id,
				"说说你记得的过去。",
				{"speaker_kind": "guard_officer"}
			),
			"plan_day": llm_bridge.build_npc_daily_plan_payload(npc_id),
			"plan_revision_judgement": llm_bridge.build_dialogue_plan_revision_judgement_payload(
				npc_id,
				{
					"current_plan": idle_plan,
					"dialogue_history": [{
						"speaker_id": "guard_officer",
						"speaker_name": "守备官",
						"listener_id": npc_id,
						"listener_name": str(npc.get("name", npc_id)),
						"text": "按你认为合适的方式继续今天。",
						"visibility": "private"
					}]
				}
			),
			"revise_plan": llm_bridge.build_npc_plan_revision_payload(
				npc_id,
				{"current_plan": idle_plan}
			),
			"battle_judgement": llm_bridge.build_npc_battle_judgement_payload(
				npc_id,
				{"allowed_decisions": ["avoid_battle", "escape_station"]}
			),
			"daily_reflection": llm_bridge.build_npc_daily_reflection_payload(
				npc_id,
				{"day": 1}
			)
		}
		var expected_diary_texts := _diary_entry_texts(diary)
		for call_type in payloads.keys():
			var payload: Dictionary = payloads[call_type]
			if payload.is_empty():
				_fail("%s produced an empty %s payload" % [npc_id, str(call_type)])
				return
			var prompt_identity: Dictionary = (
				payload.get("npc_setting", {})
				if str(call_type) == "dialogue"
				else payload.get("npc", {}).get("identity", {})
			)
			if str(prompt_identity.get("religion", "")) != "天主教":
				_fail("%s %s payload lost the shared religion field" % [
					npc_id,
					str(call_type)
				])
				return
			if prompt_identity.has("signature_lines"):
				_fail("%s %s payload still exposed fixed representative expressions" % [
					npc_id,
					str(call_type)
				])
				return
			largest_payload_chars[call_type] = maxi(
				int(largest_payload_chars.get(call_type, 0)),
				JSON.stringify(payload).length()
			)
			var injected: Dictionary = (
				payload.get("long_memory", {})
				if str(call_type) == "dialogue"
				else payload.get("npc", {}).get("long_term_memory", {})
			)
			if (
				injected.get("knowledge_graph", {}) != graph
				or injected.get("diary", []) != expected_diary_texts
			):
				_fail("%s %s payload lost or changed initial long memory" % [npc_id, str(call_type)])
				return
			if str(call_type) == "dialogue":
				var target_long_memory: Dictionary = payload.get("target_npc", {}).get("long_term_memory", {})
				if not target_long_memory.is_empty():
					_fail("%s dialogue duplicated long memory inside target_npc" % npc_id)
					return
				if not (payload.get("target_npc", {}).get("knowledge_graph", {}) as Dictionary).is_empty():
					_fail("%s dialogue target context duplicated the compatibility knowledge graph" % npc_id)
					return
			elif not (payload.get("npc", {}).get("knowledge_graph", {}) as Dictionary).is_empty():
				_fail("%s %s payload duplicated long-term knowledge in a compatibility mirror" % [
					npc_id,
					str(call_type)
				])
				return
			if str(call_type) == "daily_reflection" and payload.get("existing_diary_entries", []) != expected_diary_texts:
				_fail("%s daily reflection did not receive the seeded diary history" % npc_id)
				return

	var reinitialize_npc_id := "cook_01"
	var append_result: Dictionary = npc_system.apply_daily_reflection(reinitialize_npc_id, {
		"day": 1,
		"diary_entry": "我写入一篇临时日记，只用于确认重新开局不会重复追加同一批开局记忆。",
		"knowledge_graph_updates": [],
		"source": "verification"
	})
	if (
		not bool(append_result.get("ok", false))
		or (npc_system.get_npc_long_memory(reinitialize_npc_id).get("diary", []) as Array).size() != 4
	):
		_fail("Failed to prepare repeated-initialize verification")
		return
	var appended_diary: Array = npc_system.get_npc_long_memory(reinitialize_npc_id).get("diary", [])
	var appended_record: Dictionary = appended_diary[appended_diary.size() - 1]
	var appended_payload: Dictionary = llm_bridge.build_npc_dialogue_payload(
		reinitialize_npc_id,
		"请回顾最近一次日记。",
		{}
	)
	var projected_diary: Array = appended_payload.get("long_memory", {}).get("diary", [])
	var expected_runtime_prefix := "第1天 %s：" % str(appended_record.get("time", ""))
	if (
		projected_diary.size() != appended_diary.size()
		or not str(projected_diary[projected_diary.size() - 1]).begins_with(expected_runtime_prefix)
		or not str(projected_diary[projected_diary.size() - 1]).ends_with(
			str(appended_record.get("entry", ""))
		)
	):
		_fail("Runtime diary projection did not preserve authoritative day/time prefix")
		return
	npc_system.initialize()
	await process_frame
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if (
		(npc_system.get_npc_long_memory(reinitialize_npc_id).get("diary", []) as Array).size() != 3
		or npc_system.get_npc_ids() != NPC_IDS
		or npc_root == null
		or npc_root.get_child_count() != 8
	):
		_fail("Repeated NPCSystem initialization appended seeds or duplicated NPC nodes")
		return

	print(
		"T0061/T0101 NPC copy and initial long-memory verification passed: "
		+ "8 NPCs, 24 diary slices, 15 buildings each, four-part guard knowledge, "
		+ "four overlooked-role rules, level-based warehouse-capacity knowledge, "
		+ "six-level wall/main-hall device-slot knowledge without a main-hall range bonus, "
		+ "narrative building labels, compact knowledge UI, labeled six-way LLM payloads, "
		+ "idempotent reinitialization; "
		+ "largest payload chars=%s." % JSON.stringify(largest_payload_chars)
	)
	quit(0)


func _format_relation_values(raw_relations: Variant) -> String:
	if not raw_relations is Dictionary:
		return ""
	var parts: Array[String] = []
	for raw_record in (raw_relations as Dictionary).values():
		if raw_record is Dictionary:
			parts.append(str((raw_record as Dictionary).get("value_label", "")))
	return " ".join(parts)


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


func _diary_entry_texts(diary: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_entry in diary:
		if raw_entry is Dictionary:
			var diary_record := raw_entry as Dictionary
			var entry_text := str(diary_record.get("entry", "")).strip_edges()
			if not entry_text.is_empty():
				var day := int(diary_record.get("day", 0))
				var time_label := str(diary_record.get("time", "")).strip_edges()
				if day > 0 and not time_label.is_empty():
					result.append("第%d天 %s：%s" % [day, time_label, entry_text])
				elif day > 0:
					result.append("第%d天：%s" % [day, entry_text])
				elif not time_label.is_empty():
					result.append("%s：%s" % [time_label, entry_text])
				else:
					result.append(entry_text)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
