extends RefCounted

const IMPORTANT_EVENT_TYPES: Array[String] = [
	"npc_recruited", "dialogue_special_interaction_result", "money_given", "wine_given", "equipment_given",
	"equipment_changed", "order_assigned", "damage_taken", "unconscious_started", "revived",
	"healing_completed", "escape_started", "escape_intervention_result", "escaped",
	"combat_started", "combat_ended", "battle_psychology_result", "work_completed",
	"building_repaired", "building_upgraded", "dialogue_turn"
]


func compile(settlement_id: String, result: String, reason: String, settlement_snapshot: Dictionary) -> Dictionary:
	var npc_system := _node("/root/Main/Systems/NPCSystem")
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return {}
	var memory_system := _node("/root/Main/Systems/MemorySystem")
	var global_fact := {
		"fact_id": "global_outcome",
		"category": "settlement",
		"summary": "驿站最终%s；结算原因为%s。" % ["守住了五波敌军" if result == "victory" else "因主厅被摧毁而失守", reason]
	}
	var npc_items_by_id := {}
	var settlement_npcs: Dictionary = settlement_snapshot.get("npcs", {}) if settlement_snapshot.get("npcs", {}) is Dictionary else {}
	for raw_item in settlement_npcs.get("items", []):
		if raw_item is Dictionary:
			npc_items_by_id[str(raw_item.get("id", ""))] = raw_item
	var npcs: Array = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var profile: Dictionary = npc_system.get_npc(npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var settled: Dictionary = npc_items_by_id.get(npc_id, {}) if npc_items_by_id.get(npc_id, {}) is Dictionary else {}
		var long_memory: Dictionary = npc_system.get_npc_long_memory(npc_id) if npc_system.has_method("get_npc_long_memory") else {}
		# Settlement facts are authoritative here. Failure can transform the final
		# narrative state (everyone evacuates) without mutating the stopped world.
		var status := (
			"escaped" if bool(settled.get("escaped", state.get("escaped", false)))
			else "unconscious" if bool(settled.get("unconscious", state.get("unconscious", false)))
			else "active"
		)
		var escape_circumstance := str(settled.get("escape_circumstance", "none"))
		var key_facts := _compile_npc_facts(npc_id, profile, status, escape_circumstance, memory_system)
		npcs.append({
			"npc_id": npc_id,
			"name": str(profile.get("name", npc_id)),
			"profession": str(profile.get("background_job", "驿站成员")),
			"background_story": str(profile.get("background_story", "")),
			"personality": _string_array(profile.get("personality", []), 6),
			"desires": _string_array(profile.get("desires", []), 6),
			"fears": _string_array(profile.get("fears", []), 6),
			"recruited": bool(profile.get("recruited", false)),
			"opening_status": status,
			"escape_circumstance": escape_circumstance,
			"hp": maxi(0, int(state.get("hp", 0))),
			"max_hp": maxi(1, int(state.get("max_hp", 1))),
			"final_location": str(settled.get("current_location_name", "驿站外" if status == "escaped" else "未知")),
			"current_order": profile.get("current_order", {}).duplicate(true) if profile.get("current_order", {}) is Dictionary else {},
			"diary": _compile_diary(long_memory),
			"knowledge": _compile_knowledge(long_memory),
			"key_facts": key_facts
		})
	return {
		"meta": {
			"request_id": "epilogue_%s" % settlement_id,
			"call_type": "game_epilogue",
			"source": "godot",
			"requires_time_slowdown": false,
			"related_event_id": null
		},
		"settlement_id": settlement_id,
		"fact_snapshot_version": 1,
		"result": result,
		"reason": reason,
		"game_time": {
			"day": int(settlement_snapshot.get("day", 1)),
			"time": str(settlement_snapshot.get("time", "00:00:00"))
		},
		"station_summary": _compile_station_summary(settlement_snapshot),
		"global_facts": [global_fact],
		"npcs": npcs
	}


func _compile_station_summary(settlement_snapshot: Dictionary) -> Dictionary:
	var resources: Dictionary = settlement_snapshot.get("resources", {}).duplicate(true) if settlement_snapshot.get("resources", {}) is Dictionary else {}
	if resources.is_empty():
		var resource_system := _node("/root/Main/Systems/ResourceSystem")
		var resource_items: Array = []
		if resource_system != null and resource_system.has_method("get_resource_ids"):
			for raw_resource_id in resource_system.get_resource_ids():
				var resource_id := str(raw_resource_id)
				resource_items.append({
					"id": resource_id,
					"name": str(resource_system.get_resource_name(resource_id)) if resource_system.has_method("get_resource_name") else resource_id,
					"amount": int(resource_system.get_resource(resource_id)) if resource_system.has_method("get_resource") else 0
				})
		resources = {"items": resource_items}
	var buildings: Dictionary = settlement_snapshot.get("buildings", {}).duplicate(true) if settlement_snapshot.get("buildings", {}) is Dictionary else {}
	if buildings.is_empty():
		var building_system := _node("/root/Main/Systems/BuildingSystem")
		var building_items: Array = []
		var damaged: Array = []
		var destroyed: Array = []
		var station_operational := false
		if building_system != null and building_system.has_method("get_building_ids"):
			for raw_building_id in building_system.get_building_ids():
				var building_id := str(raw_building_id)
				var building: Dictionary = building_system.get_building(building_id)
				var hp := int(building.get("hp", 0))
				var max_hp := maxi(1, int(building.get("max_hp", 1)))
				var item := {
					"id": building_id,
					"name": str(building.get("name", building_id)),
					"level": int(building.get("level", 1)),
					"hp": hp,
					"max_hp": max_hp,
					"destroyed": hp <= 0,
					"damaged": hp < max_hp
				}
				building_items.append(item)
				if bool(item["destroyed"]):
					destroyed.append(item.duplicate(true))
				elif bool(item["damaged"]):
					damaged.append(item.duplicate(true))
				if building_id == "main_hall":
					station_operational = hp > 0
		buildings = {
			"items": building_items,
			"damaged_buildings": damaged,
			"destroyed_buildings": destroyed,
			"station_operational": station_operational
		}
	return {"resources": resources, "buildings": buildings}


func _compile_npc_facts(npc_id: String, profile: Dictionary, status: String, escape_circumstance: String, memory_system: Node) -> Array:
	var status_summary := "仍在昏迷" if status == "unconscious" else "仍可行动"
	if status == "escaped":
		status_summary = (
			"在驿站失守前已经主动逃离"
			if escape_circumstance == "before_fall_voluntary"
			else "在驿站失守后被迫撤离"
			if escape_circumstance == "after_fall_forced"
			else "已经离开驿站"
		)
	var facts: Array = [{
		"fact_id": "npc_%s_final" % npc_id,
		"category": "final_state",
		"summary": "%s在结算时%s，且%s。" % [
			str(profile.get("name", npc_id)),
			status_summary,
			"已经应征入伍" if bool(profile.get("recruited", false)) else "没有应征入伍"
		]
	}]
	if memory_system == null or not memory_system.has_method("get_all_events"):
		return facts
	var candidates: Array[Dictionary] = []
	for raw_event in memory_system.get_all_events():
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var event_type := str(event.get("type", ""))
		if not IMPORTANT_EVENT_TYPES.has(event_type) or not _event_involves_npc(event, npc_id):
			continue
		var summary := str(event.get("summary", "")).strip_edges()
		if summary.is_empty():
			continue
		candidates.append({
			"fact_id": "npc_%s_event_%s" % [npc_id, str(event.get("event_id", candidates.size()))],
			"category": event_type,
			"summary": summary,
			"importance": int(event.get("importance", 0)),
			"day": int(event.get("day", 0)),
			"time": str(event.get("time", ""))
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("importance", 0)) != int(b.get("importance", 0)):
			return int(a.get("importance", 0)) > int(b.get("importance", 0))
		if int(a.get("day", 0)) != int(b.get("day", 0)):
			return int(a.get("day", 0)) > int(b.get("day", 0))
		return str(a.get("time", "")) > str(b.get("time", ""))
	)
	var seen_categories := {}
	for candidate in candidates:
		var category := str(candidate.get("category", ""))
		if int(seen_categories.get(category, 0)) >= 2:
			continue
		seen_categories[category] = int(seen_categories.get(category, 0)) + 1
		candidate.erase("importance")
		candidate.erase("day")
		candidate.erase("time")
		facts.append(candidate)
		if facts.size() >= 12:
			break
	return facts


func _event_involves_npc(event: Dictionary, npc_id: String) -> bool:
	if str(event.get("subject_npc_id", "")) == npc_id:
		return true
	for key in ["actor_ids", "target_ids"]:
		var ids: Array = event.get(key, []) if event.get(key, []) is Array else []
		if ids.has(npc_id):
			return true
	return false


func _compile_diary(long_memory: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var diary: Array = long_memory.get("diary", []) if long_memory.get("diary", []) is Array else []
	for index in range(maxi(0, diary.size() - 4), diary.size()):
		var item: Variant = diary[index]
		var text := str(item.get("entry", "")) if item is Dictionary else str(item)
		if not text.strip_edges().is_empty():
			result.append(text.strip_edges())
	return result


func _compile_knowledge(long_memory: Dictionary) -> Array[String]:
	var graph: Dictionary = long_memory.get("knowledge_graph", {}) if long_memory.get("knowledge_graph", {}) is Dictionary else {}
	var by_subject: Dictionary = graph.get("by_subject", {}) if graph.get("by_subject", {}) is Dictionary else {}
	var result: Array[String] = []
	for raw_subject in by_subject.keys():
		var relations: Variant = by_subject.get(raw_subject)
		if not relations is Dictionary:
			continue
		for raw_relation in relations.keys():
			var value: Variant = relations.get(raw_relation)
			var text := str(value.get("value_label", value.get("value", ""))) if value is Dictionary else str(value)
			if not text.strip_edges().is_empty():
				result.append("%s：%s" % [str(raw_subject), text.strip_edges()])
				if result.size() >= 10:
					return result
	return result


func _string_array(value: Variant, limit: int) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty():
				result.append(text)
				if result.size() >= limit:
					break
	elif not str(value).strip_edges().is_empty():
		result.append(str(value).strip_edges())
	return result


func _node(path: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(path) if tree != null else null
