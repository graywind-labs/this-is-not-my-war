extends Node

const EpilogueFactCompiler = preload("res://scripts/systems/EpilogueFactCompiler.gd")
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"

var _active_settlement_id := ""
var _active_request_id := ""
var _last_snapshot: Dictionary = {}


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("game_over_changed"):
		event_bus.game_over_changed.connect(_on_game_over_changed)
	var bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if bridge != null and bridge.has_signal("game_epilogue_async_response_received"):
		bridge.game_epilogue_async_response_received.connect(_on_epilogue_response)


func _on_game_over_changed(result: String, reason: String) -> void:
	call_deferred("_begin_epilogue", result, reason)


func _begin_epilogue(result: String, reason: String) -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.game_over):
		return
	var settlement: Dictionary = game_state.settlement_snapshot.duplicate(true)
	var existing: Dictionary = settlement.get("epilogue", {}) if settlement.get("epilogue", {}) is Dictionary else {}
	if ["llm", "template_fallback"].has(str(existing.get("status", ""))):
		return
	_active_settlement_id = "d%d_%02d%02d%02d_%s_%d" % [
		int(game_state.game_over_day), int(game_state.game_over_hour),
		int(game_state.game_over_minute), int(game_state.game_over_second), result,
		Time.get_ticks_usec()
	]
	var payload: Dictionary = EpilogueFactCompiler.new().compile(
		_active_settlement_id, result, reason, settlement
	)
	if payload.is_empty():
		_apply_template_fallback("fact_snapshot_unavailable", {})
		return
	settlement["epilogue_fact_snapshot"] = payload.duplicate(true)
	settlement["epilogue"] = {
		"status": "pending",
		"source": "pending",
		"settlement_id": _active_settlement_id,
		"message": "战地记录整理中……"
	}
	game_state.settlement_snapshot = settlement
	_emit_changed(settlement.get("epilogue", {}))
	var bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if bridge == null or not bridge.has_method("request_game_epilogue_async"):
		_apply_template_fallback("llm_bridge_missing", payload)
		return
	var start_result: Dictionary = bridge.request_game_epilogue_async(payload)
	if not bool(start_result.get("ok", false)):
		_apply_template_fallback(str(start_result.get("error_code", "request_start_failed")), payload)
		return
	_active_request_id = str(start_result.get("request_id", ""))


func _on_epilogue_response(result: Dictionary) -> void:
	if str(result.get("request_id", "")) != _active_request_id or _active_settlement_id.is_empty():
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.game_over):
		return
	var settlement: Dictionary = game_state.settlement_snapshot.duplicate(true)
	var epilogue_state: Dictionary = settlement.get("epilogue", {}) if settlement.get("epilogue", {}) is Dictionary else {}
	if str(epilogue_state.get("settlement_id", "")) != _active_settlement_id:
		return
	if not bool(result.get("ok", false)):
		_apply_template_fallback(str(result.get("error_code", "provider_failed")), settlement.get("epilogue_fact_snapshot", {}))
		return
	var body: Dictionary = result.get("game_epilogue", {}) if result.get("game_epilogue", {}) is Dictionary else {}
	if bool(body.get("model_fallback_used", false)):
		_apply_template_fallback("automatic_mock_fallback_rejected", settlement.get("epilogue_fact_snapshot", {}))
		return
	if not _apply_generated_epilogue(body, "llm"):
		_apply_template_fallback("client_continuity_validation_failed", settlement.get("epilogue_fact_snapshot", {}))


func _apply_generated_epilogue(body: Dictionary, source: String) -> bool:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or str(body.get("result", "")) != str(game_state.game_result):
		return false
	var settlement: Dictionary = game_state.settlement_snapshot.duplicate(true)
	var npcs: Dictionary = settlement.get("npcs", {}) if settlement.get("npcs", {}) is Dictionary else {}
	var items: Array = npcs.get("items", []) if npcs.get("items", []) is Array else []
	var endings: Array = body.get("npc_endings", []) if body.get("npc_endings", []) is Array else []
	if endings.size() != items.size():
		return false
	var endings_by_id := {}
	for raw_ending in endings:
		if not raw_ending is Dictionary:
			return false
		var npc_id := str(raw_ending.get("npc_id", ""))
		if npc_id.is_empty() or endings_by_id.has(npc_id):
			return false
		endings_by_id[npc_id] = raw_ending
	for index in range(items.size()):
		var item: Dictionary = items[index] if items[index] is Dictionary else {}
		var npc_id := str(item.get("id", ""))
		if not endings_by_id.has(npc_id):
			return false
		var ending: Dictionary = endings_by_id[npc_id]
		var expected_status := "escaped" if bool(item.get("escaped", false)) else "unconscious" if bool(item.get("unconscious", false)) else "active"
		if str(ending.get("opening_status", "")) != expected_status:
			return false
		item["ending_title"] = str(ending.get("ending_title", ""))
		item["final_opinion"] = str(ending.get("final_opinion", ""))
		item["fate_summary"] = str(ending.get("fate_story", ""))
		item["ending_tone"] = str(ending.get("tone", ""))
		item["ending_fact_refs"] = ending.get("fact_refs", []).duplicate()
		items[index] = item
	npcs["items"] = items
	var active_items: Array = []
	var unconscious_items: Array = []
	var escaped_items: Array = []
	for raw_item in items:
		var grouped_item: Dictionary = raw_item if raw_item is Dictionary else {}
		if bool(grouped_item.get("escaped", false)):
			escaped_items.append(grouped_item.duplicate(true))
		elif bool(grouped_item.get("unconscious", false)):
			unconscious_items.append(grouped_item.duplicate(true))
		else:
			active_items.append(grouped_item.duplicate(true))
	npcs["active_npcs"] = active_items
	npcs["unconscious_npcs"] = unconscious_items
	npcs["escaped_npcs"] = escaped_items
	settlement["npcs"] = npcs
	settlement["epilogue"] = {
		"status": source,
		"source": source,
		"settlement_id": _active_settlement_id,
		"ending_title": str(body.get("ending_title", "")),
		"station_coda": str(body.get("station_coda", "")),
		"model_provider": str(body.get("model_provider", "")),
		"model_name": str(body.get("model_name", "")),
		"fallback_used": bool(body.get("model_fallback_used", false))
	}
	game_state.settlement_snapshot = settlement
	_last_snapshot = settlement.get("epilogue", {}).duplicate(true)
	_emit_changed(_last_snapshot)
	return true


func _apply_template_fallback(reason: String, payload: Dictionary) -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var settlement: Dictionary = game_state.settlement_snapshot.duplicate(true)
	var result := str(game_state.game_result)
	var body := _build_template_epilogue(result, settlement, payload)
	if not _apply_generated_epilogue(body, "template_fallback"):
		return
	settlement = game_state.settlement_snapshot.duplicate(true)
	var epilogue: Dictionary = settlement.get("epilogue", {})
	epilogue["failure_reason"] = reason
	epilogue["message"] = "叙事生成失败，已根据战地记录整理。"
	settlement["epilogue"] = epilogue
	game_state.settlement_snapshot = settlement
	_last_snapshot = epilogue.duplicate(true)
	_emit_changed(_last_snapshot)


func _build_template_epilogue(result: String, settlement: Dictionary, payload: Dictionary) -> Dictionary:
	var input_by_id := {}
	var payload_npcs: Array = payload.get("npcs", []) if payload.get("npcs", []) is Array else []
	for raw_input in payload_npcs:
		if raw_input is Dictionary:
			input_by_id[str(raw_input.get("npc_id", ""))] = raw_input
	var endings: Array = []
	var npc_data: Dictionary = settlement.get("npcs", {}) if settlement.get("npcs", {}) is Dictionary else {}
	for raw_item in npc_data.get("items", []):
		var item: Dictionary = raw_item if raw_item is Dictionary else {}
		var npc_id := str(item.get("id", ""))
		var input: Dictionary = input_by_id.get(npc_id, {}) if input_by_id.get(npc_id, {}) is Dictionary else {}
		var status := "escaped" if bool(item.get("escaped", false)) else "unconscious" if bool(item.get("unconscious", false)) else "active"
		var name := str(item.get("name", npc_id))
		var profession := str(input.get("profession", "驿站成员"))
		var fact_refs := ["npc_%s_final" % npc_id]
		var story := _template_story(name, profession, status, result)
		endings.append({
			"npc_id": npc_id,
			"ending_title": _template_title(profession, result),
			"opening_status": status,
			"final_opinion": _template_opinion(name, status, result),
			"fate_story": story,
			"tone": "hopeful_bittersweet" if result == "victory" else "sorrowful_resilient",
			"fact_refs": fact_refs
		})
	return {
		"ok": true,
		"result": result,
		"ending_title": "仍有炊烟升起" if result == "victory" else "风越过空厅",
		"station_coda": "敌声远去后，驿站仍留着这一局真实生活过的痕迹。" if result == "victory" else "主厅沉寂以后，驿站留下的并不只有废墟，还有每个人未说完的话。",
		"npc_endings": endings
	}


func _template_story(name: String, profession: String, status: String, result: String) -> String:
	var opening := "%s在结算时已经离开驿站" % name if status == "escaped" else "%s在结算时仍未醒来" % name if status == "unconscious" else "%s在战事结束后仍站在驿站里" % name
	var closing := _template_closing(profession, result)
	if result == "victory":
		return "%s。胜利没有抹去这些日子留下的伤处，也没有替任何人回答以后该往哪里去。后来，%s重新拾起%s的旧手艺，把沉默、迟疑和曾经承担过的责任一起带进寻常生活。许多个黄昏过去，旧路上偶尔仍有人谈起那座守住了的驿站；话音散尽以后，%s" % [opening, name, profession, closing]
	return "%s。失守把原先寻常的生活截成了两段，留下的人和离开的人都没有真正带走完整的过去。后来，%s在陌生地方重新做起%s的活计，很少主动提起守备官，却会在某个相似的声响里停下手。岁月让驿站的名字渐渐模糊，经过旧路的人也不再知道每道伤痕的来历；%s" % [opening, name, profession, closing]


func _template_closing(profession: String, result: String) -> String:
	var victory_closings := {
		"马夫": "潮湿路面上传来渐远的蹄声，像有人终于找到了归途。",
		"厨子": "新烤的麦香从门缝里漫出来，炉心还留着不张扬的红光。",
		"园丁": "秋雨落进松土，几粒旧种子在来年春天冒出了芽。",
		"铁匠": "锤声停下以后，一粒火星仍在暮色里缓慢发亮。",
		"老兵副官": "风翻动旧名册，却始终没有吹走最后一页的字迹。",
		"神父": "晚钟隔着薄雾传来，余音停在归巢的鸟群之后。",
		"医生": "晒干的药草在梁下轻响，苦香一直留到入夜。",
		"工程师": "折旧的图纸压着窗缝，晨光沿墨线一点点铺开。"
	}
	var failure_closings := {
		"马夫": "风追着空鞍上的皮带声，一路没入北方旧道。",
		"厨子": "冷炉里只剩一点麦香，随着灰烬落回砖缝。",
		"园丁": "荒草结籽以后，风把它们带过倒塌的矮墙。",
		"铁匠": "最后一记锤声沉入夜色，铁砧上只余冷光。",
		"老兵副官": "名册被合上时，褪色布角仍在窗边轻轻摆动。",
		"神父": "没有敲完的钟声留在雾里，许久才被群山收走。",
		"医生": "药草的苦味从旧布包里散出，又被雨气慢慢冲淡。",
		"工程师": "破损图纸卷过石地，停在一道长满苔藓的裂缝旁。"
	}
	var closings: Dictionary = victory_closings if result == "victory" else failure_closings
	return str(closings.get(profession, "一盏微弱的灯在风里亮着，像一句迟迟无人说完的话。"))


func _template_title(profession: String, result: String) -> String:
	return "%s的余火" % profession if result == "victory" else "%s的旧路" % profession


func _template_opinion(name: String, status: String, result: String) -> String:
	if status == "escaped":
		return "%s没有忘记守备官，也没有把自己的离开解释成一个简单答案；距离只让理解与怨意同时沉淀。" % name
	if result == "victory":
		return "%s记得守备官让普通人承担过沉重责任，也承认共同守住驿站改变了彼此。" % name
	return "%s对守备官的记忆停在失守那天，理解、责难和没有兑现的期望长久并存。" % name


func debug_get_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


func _emit_changed(snapshot: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("epilogue_changed"):
		event_bus.epilogue_changed.emit(snapshot.duplicate(true))
