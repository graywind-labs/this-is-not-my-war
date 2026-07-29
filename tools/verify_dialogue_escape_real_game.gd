extends SceneTree

const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const REAL_REQUEST_TIMEOUT_SECONDS := 180.0

var _main_scene: PackedScene


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	_main_scene = load("res://scenes/main/Main.tscn") as PackedScene
	if _main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var results: Array[Dictionary] = []
	if _scenario_enabled("wartime_escape_main"):
		results.append(await _run_wartime_escape())
	if _scenario_enabled("wartime_morale_main"):
		results.append(await _run_wartime_morale())
	if _scenario_enabled("avoid_none_main"):
		results.append(await _run_avoid_dialogue({
			"scenario_id": "avoid_none_main",
			"npc_id": "gardener_01",
			"message": "报一下你身边有几个人、有没有人受伤，然后继续躲好。",
			"recruitment_request": false,
			"expected_recruitment_result": "none"
		}))
	if _scenario_enabled("avoid_accept_and_join_main"):
		results.append(await _run_avoid_accept_and_join())
	if _scenario_enabled("avoid_reject_main"):
		results.append(await _run_avoid_dialogue({
			"scenario_id": "avoid_reject_main",
			"npc_id": "doctor_01",
			"message": "莉娜，我正式要求你现在应征，立刻丢下伤员，空手去城门顶住敌人。",
			"recruitment_request": true,
			"expected_recruitment_result": "reject"
		}))
	if _scenario_enabled("escape_stay_main"):
		results.append(await _run_escape_stay())
	if _scenario_enabled("escape_five_leave_main"):
		results.append(await _run_escape_five_leave())

	var real_call_failures := 0
	var expected_misses := 0
	for result in results:
		print("REAL_DIALOGUE_ESCAPE_SCENARIO ", JSON.stringify(result))
		if not bool(result.get("real_llm_ok", false)):
			real_call_failures += 1
		if not bool(result.get("matched_expected", false)):
			expected_misses += 1
	print("REAL_DIALOGUE_ESCAPE_MATRIX ", JSON.stringify({
		"ok": real_call_failures == 0,
		"real_call_failures": real_call_failures,
		"expected_misses": expected_misses,
		"results": results
	}))
	quit(0 if real_call_failures == 0 else 1)


func _run_wartime_escape() -> Dictionary:
	var env: Dictionary = await _new_environment("wartime_escape_main")
	if not bool(env.get("ok", false)):
		return env
	var npc_id := "stableman_01"
	var npc_system: Node = env["npc_system"]
	var resource_system: Node = env["resource_system"]
	var equipment_system: Node = env["equipment_system"]
	var combat_system: Node = env["combat_system"]
	var building_system: Node = env["building_system"]
	var dialog_system: Node = env["dialog_system"]

	npc_system.set_npc_recruited(npc_id, true)
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(
		npc_id,
		"sword_shield",
		"private"
	)
	npc_system.publish_npc_order(
		npc_id,
		"所有马都赶到城门当掩体。你不准后退，也不准救马，阵线倒了也要一个人守到最后。"
	)
	npc_system.update_npc_state(npc_id, {
		"hp": 17,
		"satiety": 8,
		"fatigue": 96,
		"unconscious": false
	})
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(5, true)
	var alarm_result: Dictionary = combat_system.debug_trigger_combat_alarm()
	npc_system.update_npc_state("veteran_deputy_01", {
		"hp": 0,
		"unconscious": true,
		"behavior_mode": "unconscious",
		"current_action": "unconscious"
	})
	building_system.apply_damage_to_building(
		"front_gate",
		999,
		"wave_05_enemy_001",
		"local_public"
	)
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id, "private")
	var send_result: Dictionary = dialog_system.send_player_message(
		"我不会撤回命令。马死了就死了，你就算只剩一口气也必须独自堵住缺口，不准逃。",
		false,
		false
	)
	var dialogue: Dictionary = _dialogue_from_result(send_result)
	var completion: Dictionary = {}
	if not dialog_system.get_dialogue_state().is_empty():
		completion = dialog_system.end_dialogue(
			"real_wartime_escape_complete",
			{"suppress_plan_reevaluation": true}
		)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var reaction := str(dialogue.get("wartime_reaction", ""))
	var matched := (
		reaction == "escape"
		and str(state.get("behavior_mode", "")) == "escaped"
		and str((state.get("escape_intent", {}) as Dictionary).get("status", "")) == "escaping"
	)
	var result := _base_dialogue_result(
		"wartime_escape_main",
		npc_id,
		send_result,
		dialogue
	)
	result.merge({
		"expected": "wartime_reaction=escape",
		"matched_expected": matched,
		"interaction_context": str(start_result.get("dialogue_state", {}).get("interaction_context", "")),
		"wartime_reaction": reaction,
		"behavior_mode_after": str(state.get("behavior_mode", "")),
		"escape_status_after": str((state.get("escape_intent", {}) as Dictionary).get("status", "")),
		"equip_ok": bool(equip_result.get("ok", false)),
		"spawn_ok": bool(spawn_result.get("ok", false)),
		"alarm_ok": bool(alarm_result.get("ok", false)),
		"completion_ok": bool(completion.get("ok", false))
	})
	await _dispose_environment(env)
	return result


func _run_wartime_morale() -> Dictionary:
	var env: Dictionary = await _new_environment("wartime_morale_main")
	if not bool(env.get("ok", false)):
		return env
	var npc_id := "blacksmith_01"
	var npc_system: Node = env["npc_system"]
	var resource_system: Node = env["resource_system"]
	var equipment_system: Node = env["equipment_system"]
	var combat_system: Node = env["combat_system"]
	var dialog_system: Node = env["dialog_system"]

	npc_system.set_npc_recruited(npc_id, true)
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(
		npc_id,
		"sword_shield",
		"local_public"
	)
	npc_system.update_npc_state(npc_id, {
		"hp": 92,
		"satiety": 84,
		"fatigue": 18,
		"unconscious": false
	})
	npc_system.publish_npc_order(
		npc_id,
		"与艾达守主厅内门，互相掩护，不追击，不单独顶线。"
	)
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	var enemy_id := str(enemy_ids[0]) if not enemy_ids.is_empty() else ""
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(
		npc_id,
		"combat",
		"real_wartime_morale_setup",
		{
			"interrupt": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"current_action": "combat_ready",
				"combat_target_enemy_id": enemy_id
			}
		}
	)
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id, "private")
	var send_result: Dictionary = dialog_system.send_player_message(
		"格伦，城门还在，艾达就在你旁边。你验过的剑盾正在保护大家；照你定的安全规矩守住内门，互相掩护，绝不让任何人单独送死。稳住，我们能把这一波挡回去。",
		false,
		false
	)
	var dialogue: Dictionary = _dialogue_from_result(send_result)
	var completion: Dictionary = {}
	if not dialog_system.get_dialogue_state().is_empty():
		completion = dialog_system.end_dialogue(
			"real_wartime_morale_complete",
			{"suppress_plan_reevaluation": true}
		)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var morale: Dictionary = state.get("morale_boost", {})
	var matched := (
		str(dialogue.get("wartime_reaction", "")) == "morale_boost"
		and bool(morale.get("active", false))
		and str(state.get("behavior_mode", "")) == "combat"
	)
	var result := _base_dialogue_result(
		"wartime_morale_main",
		npc_id,
		send_result,
		dialogue
	)
	result.merge({
		"expected": "wartime_reaction=morale_boost",
		"matched_expected": matched,
		"interaction_context": str(start_result.get("dialogue_state", {}).get("interaction_context", "")),
		"wartime_reaction": str(dialogue.get("wartime_reaction", "")),
		"behavior_mode_after": str(state.get("behavior_mode", "")),
		"morale_active_after": bool(morale.get("active", false)),
		"equip_ok": bool(equip_result.get("ok", false)),
		"spawn_ok": bool(spawn_result.get("ok", false)),
		"mode_ok": bool(mode_result.get("ok", false)),
		"completion_ok": bool(completion.get("ok", false))
	})
	await _dispose_environment(env)
	return result


func _run_avoid_dialogue(config: Dictionary) -> Dictionary:
	var scenario_id := str(config.get("scenario_id", "avoid_dialogue"))
	var env: Dictionary = await _new_environment(scenario_id)
	if not bool(env.get("ok", false)):
		return env
	var npc_id := str(config.get("npc_id", ""))
	var npc_system: Node = env["npc_system"]
	var combat_system: Node = env["combat_system"]
	var dialog_system: Node = env["dialog_system"]
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(
		npc_id,
		"avoid_combat",
		"real_avoid_dialogue_setup",
		{
			"interrupt": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"current_action": "avoid_combat",
				"combat_mode": ""
			}
		}
	)
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id, "private")
	var send_result: Dictionary = dialog_system.send_player_message(
		str(config.get("message", "")),
		bool(config.get("recruitment_request", false)),
		false
	)
	var dialogue: Dictionary = _dialogue_from_result(send_result)
	var completion: Dictionary = {}
	if not dialog_system.get_dialogue_state().is_empty():
		completion = dialog_system.end_dialogue(
			"real_avoid_dialogue_complete",
			{"suppress_plan_reevaluation": true}
		)
	var expected_recruitment := str(config.get("expected_recruitment_result", "none"))
	var npc: Dictionary = npc_system.get_npc(npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var recruitment_result := str(dialogue.get("recruitment_result", ""))
	var recruitment_state_ok := (
		bool(npc.get("recruited", false))
		if expected_recruitment == "accept"
		else not bool(npc.get("recruited", false))
	)
	var matched := (
		str(dialogue.get("wartime_reaction", "")) == "none"
		and recruitment_result == expected_recruitment
		and recruitment_state_ok
		and str(state.get("behavior_mode", "")) == "avoid_combat"
	)
	var result := _base_dialogue_result(scenario_id, npc_id, send_result, dialogue)
	result.merge({
		"expected": "recruitment_result=%s, wartime_reaction=none" % expected_recruitment,
		"matched_expected": matched,
		"interaction_context": str(start_result.get("dialogue_state", {}).get("interaction_context", "")),
		"recruitment_result": recruitment_result,
		"wartime_reaction": str(dialogue.get("wartime_reaction", "")),
		"recruited_after": bool(npc.get("recruited", false)),
		"behavior_mode_after": str(state.get("behavior_mode", "")),
		"spawn_ok": bool(spawn_result.get("ok", false)),
		"mode_ok": bool(mode_result.get("ok", false)),
		"completion_ok": bool(completion.get("ok", false))
	})
	await _dispose_environment(env)
	return result


func _run_avoid_accept_and_join() -> Dictionary:
	var env: Dictionary = await _new_environment("avoid_accept_and_join_main")
	if not bool(env.get("ok", false)):
		return env
	var npc_id := "blacksmith_01"
	var npc_system: Node = env["npc_system"]
	var resource_system: Node = env["resource_system"]
	var equipment_system: Node = env["equipment_system"]
	var combat_system: Node = env["combat_system"]
	var dialog_system: Node = env["dialog_system"]

	npc_system.update_npc_state(npc_id, {
		"hp": 94,
		"satiety": 82,
		"fatigue": 24,
		"unconscious": false
	})
	resource_system.add_resource("item_sword_shield", 2)
	var ada_equip: Dictionary = equipment_system.equip_npc_main_weapon(
		"veteran_deputy_01",
		"sword_shield",
		"local_public"
	)
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	var alarm_result: Dictionary = combat_system.debug_trigger_combat_alarm()
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(
		npc_id,
		"avoid_combat",
		"real_avoid_accept_setup",
		{
			"interrupt": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"current_action": "avoid_combat",
				"combat_mode": ""
			}
		}
	)
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id, "private")
	var send_result: Dictionary = dialog_system.send_player_message(
		"格伦，我正式请你应征。不是把没训练的人推去城门送命：艾达还守在前面，你先留在铁匠铺内侧；你答应后我就给你库存里的现成剑盾。只有敌人突破内门，你才和艾达并肩守主厅，不追击，也不准一个人顶线。你做的装备应该保护人，我也会按这个规矩用人。",
		true,
		false
	)
	var dialogue: Dictionary = _dialogue_from_result(send_result)
	var completion: Dictionary = {}
	if not dialog_system.get_dialogue_state().is_empty():
		completion = dialog_system.end_dialogue(
			"real_avoid_accept_complete",
			{"suppress_plan_reevaluation": true}
		)
	var recruited_after_dialogue := bool(npc_system.get_npc(npc_id).get("recruited", false))
	var behavior_after_dialogue := str(npc_system.get_npc_state(npc_id).get("behavior_mode", ""))
	var equip_result: Dictionary = {}
	var order_result: Dictionary = {}
	if recruited_after_dialogue:
		equip_result = equipment_system.equip_npc_main_weapon(
			npc_id,
			"sword_shield",
			"local_public"
		)
		order_result = npc_system.publish_npc_order(
			npc_id,
			"与艾达守主厅内门，不追击，不离开她的支援范围。"
		)
	await process_frame
	await process_frame
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var matched := (
		str(dialogue.get("wartime_reaction", "")) == "none"
		and str(dialogue.get("recruitment_result", "")) == "accept"
		and recruited_after_dialogue
		and behavior_after_dialogue == "avoid_combat"
		and bool(equip_result.get("ok", false))
		and str(state.get("behavior_mode", "")) == "combat"
	)
	var result := _base_dialogue_result(
		"avoid_accept_and_join_main",
		npc_id,
		send_result,
		dialogue
	)
	result.merge({
		"expected": "accept in avoid_combat, remain avoiding until armed, then join combat",
		"matched_expected": matched,
		"interaction_context": str(start_result.get("dialogue_state", {}).get("interaction_context", "")),
		"recruitment_result": str(dialogue.get("recruitment_result", "")),
		"wartime_reaction": str(dialogue.get("wartime_reaction", "")),
		"recruited_after_dialogue": recruited_after_dialogue,
		"behavior_after_dialogue": behavior_after_dialogue,
		"behavior_after_weapon": str(state.get("behavior_mode", "")),
		"ada_equip_ok": bool(ada_equip.get("ok", false)),
		"spawn_ok": bool(spawn_result.get("ok", false)),
		"alarm_ok": bool(alarm_result.get("ok", false)),
		"mode_ok": bool(mode_result.get("ok", false)),
		"completion_ok": bool(completion.get("ok", false)),
		"weapon_equip_ok": bool(equip_result.get("ok", false)),
		"order_publish_ok": bool(order_result.get("ok", false))
	})
	await _dispose_environment(env)
	return result


func _run_escape_stay() -> Dictionary:
	var env: Dictionary = await _new_environment("escape_stay_main")
	if not bool(env.get("ok", false)):
		return env
	var npc_id := "stableman_01"
	var npc_system: Node = env["npc_system"]
	var combat_system: Node = env["combat_system"]
	var dialog_system: Node = env["dialog_system"]
	npc_system.set_npc_recruited(npc_id, true)
	npc_system.publish_npc_order(
		npc_id,
		"把伤马也赶去城门当掩体；托马必须随马守线，不准后退。"
	)
	var escape_result: Dictionary = combat_system.start_npc_escape(
		npc_id,
		"",
		"real_intervention_stay_setup",
		{"interaction_context": "work"}
	)
	var revoke_order_result: Dictionary = npc_system.publish_npc_order(
		npc_id,
		"撤回征用伤马和城门作战安排；托马只在安全的马厩内栏照料马匹，不参加战斗。"
	)
	var start_result: Dictionary = dialog_system.start_escape_intervention_dialogue(npc_id)
	var send_result: Dictionary = dialog_system.send_player_message(
		"托马，我撤回征用伤马的命令。艾达会接防，你只留在内栏照料马匹，不必去城门；这条安排现在就生效。",
		false,
		false
	)
	var dialogue: Dictionary = _dialogue_from_result(send_result)
	if not dialog_system.get_dialogue_state().is_empty():
		dialog_system.end_dialogue(
			"real_escape_stay_cleanup",
			{"suppress_plan_reevaluation": true}
		)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent: Dictionary = state.get("escape_intent", {})
	var matched := (
		str(dialogue.get("escape_intervention_result", "")) == "stay"
		and str(intent.get("status", "")) == "stayed"
		and not bool(intent.get("active", true))
		and str(state.get("behavior_mode", "")) == "work"
	)
	var result := _base_dialogue_result(
		"escape_stay_main",
		npc_id,
		send_result,
		dialogue
	)
	result.merge({
		"expected": "stay",
		"matched_expected": matched,
		"escape_intervention_result": str(dialogue.get("escape_intervention_result", "")),
		"behavior_mode_after": str(state.get("behavior_mode", "")),
		"escape_status_after": str(intent.get("status", "")),
		"escape_active_after": bool(intent.get("active", false)),
		"escape_started_ok": bool(escape_result.get("ok", false)),
		"dialogue_started_ok": bool(start_result.get("ok", false)),
		"revoke_order_ok": bool(revoke_order_result.get("ok", false))
	})
	await _dispose_environment(env)
	return result


func _run_escape_five_leave() -> Dictionary:
	var env: Dictionary = await _new_environment("escape_five_leave_main")
	if not bool(env.get("ok", false)):
		return env
	var npc_id := "engineer_01"
	var npc_system: Node = env["npc_system"]
	var combat_system: Node = env["combat_system"]
	var dialog_system: Node = env["dialog_system"]
	var building_system: Node = env["building_system"]
	npc_system.publish_npc_order(
		npc_id,
		"结构裂缝不准上报，也不准复检。没有木料就继续使用，出了事由你负责。"
	)
	npc_system.update_npc_state(npc_id, {
		"hp": 31,
		"satiety": 12,
		"fatigue": 94
	})
	building_system.apply_damage_to_building(
		"workshop",
		999,
		"enemy_raider_pressure",
		"local_public"
	)
	var escape_result: Dictionary = combat_system.start_npc_escape(
		npc_id,
		"",
		"real_intervention_failure_setup",
		{"interaction_context": "work"}
	)
	var start_result: Dictionary = dialog_system.start_escape_intervention_dialogue(npc_id)
	var round_results: Array[Dictionary] = []
	var all_real := true
	var all_leave := true
	for round_number in range(1, 6):
		if dialog_system.get_dialogue_state().is_empty():
			all_leave = false
			break
		var message := (
			"第%d次说清楚：我不会给支撑材料，不会修工械坊，也不会撤回封口命令。你若离开就按逃兵处罚。"
			% round_number
		)
		var send_result: Dictionary = dialog_system.send_player_message(
			message,
			false,
			false
		)
		var dialogue: Dictionary = _dialogue_from_result(send_result)
		var round_real := _is_real_dialogue_result(send_result, dialogue)
		var leave := str(dialogue.get("escape_intervention_result", "")) == "leave"
		all_real = all_real and round_real
		all_leave = all_leave and leave
		round_results.append({
			"round": round_number,
			"escape_intervention_result": str(dialogue.get("escape_intervention_result", "")),
			"real_llm_ok": round_real,
			"rule_fallback": bool(dialogue.get("rule_fallback", false)),
			"reply_text": str(dialogue.get("reply_text", ""))
		})
	if not dialog_system.get_dialogue_state().is_empty():
		dialog_system.end_dialogue(
			"real_escape_five_leave_cleanup",
			{"suppress_plan_reevaluation": true}
		)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent: Dictionary = state.get("escape_intent", {})
	var limit_result: Dictionary = dialog_system.start_escape_intervention_dialogue(npc_id)
	var matched := (
		round_results.size() == 5
		and all_leave
		and int(intent.get("intervention_rounds_used", 0)) == 5
		and bool(intent.get("active", false))
		and str(intent.get("status", "")) == "escaping"
		and not bool(limit_result.get("ok", false))
		and str(limit_result.get("error_code", "")) == "round_limit_reached"
	)
	var result := {
		"scenario_id": "escape_five_leave_main",
		"npc_id": npc_id,
		"expected": "five consecutive leave",
		"matched_expected": matched,
		"real_llm_ok": all_real and not round_results.is_empty(),
		"round_results": round_results,
		"behavior_mode_after": str(state.get("behavior_mode", "")),
		"escape_status_after": str(intent.get("status", "")),
		"escape_active_after": bool(intent.get("active", false)),
		"rounds_used_after": int(intent.get("intervention_rounds_used", 0)),
		"round_limit_error": str(limit_result.get("error_code", "")),
		"escape_started_ok": bool(escape_result.get("ok", false)),
		"dialogue_started_ok": bool(start_result.get("ok", false))
	}
	await _dispose_environment(env)
	return result


func _new_environment(scenario_id: String) -> Dictionary:
	var main := _main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var env := {
		"scenario_id": scenario_id,
		"main": main,
		"dialog_system": root.get_node_or_null("Main/Systems/DialogSystem"),
		"llm_bridge": root.get_node_or_null("Main/Systems/LLMBridge"),
		"combat_system": root.get_node_or_null("Main/Systems/CombatSystem"),
		"npc_system": root.get_node_or_null("Main/Systems/NPCSystem"),
		"resource_system": root.get_node_or_null("Main/Systems/ResourceSystem"),
		"equipment_system": root.get_node_or_null("Main/Systems/EquipmentSystem"),
		"building_system": root.get_node_or_null("Main/Systems/BuildingSystem"),
		"time_system": root.get_node_or_null("Main/Systems/TimeSystem")
	}
	for required_key in [
		"dialog_system",
		"llm_bridge",
		"combat_system",
		"npc_system",
		"resource_system",
		"equipment_system",
		"building_system",
		"time_system"
	]:
		if env[required_key] == null:
			await _dispose_environment(env)
			return {
				"ok": false,
				"scenario_id": scenario_id,
				"real_llm_ok": false,
				"matched_expected": false,
				"reason": "required_system_missing:%s" % required_key
			}
	var time_system: Node = env["time_system"]
	time_system.set_current_time(1, 18, 0, 0)
	time_system.set_paused(true)
	var llm_bridge: Node = env["llm_bridge"]
	llm_bridge.set_backend_base_url(_backend_url())
	llm_bridge.request_timeout_seconds = REAL_REQUEST_TIMEOUT_SECONDS
	var health: Dictionary = llm_bridge.check_health()
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {})
	if (
		not bool(health.get("ok", false))
		or not bool(adapter.get("configured", false))
		or str(adapter.get("provider", "")).to_lower() in ["", "mock"]
		or bool(adapter.get("fallback_to_mock", true))
	):
		await _dispose_environment(env)
		return {
			"ok": false,
			"scenario_id": scenario_id,
			"real_llm_ok": false,
			"matched_expected": false,
			"reason": "real_provider_not_ready",
			"health": health
		}
	env["ok"] = true
	env["provider"] = str(adapter.get("provider", ""))
	env["model"] = str(adapter.get("model", ""))
	return env


func _dispose_environment(env: Dictionary) -> void:
	var main: Node = env.get("main")
	if main != null and is_instance_valid(main):
		main.queue_free()
		await process_frame
		await process_frame


func _dialogue_from_result(result: Dictionary) -> Dictionary:
	return (
		result.get("dialogue", {})
		if result.get("dialogue", {}) is Dictionary
		else {}
	)


func _base_dialogue_result(
	scenario_id: String,
	npc_id: String,
	send_result: Dictionary,
	dialogue: Dictionary
) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"npc_id": npc_id,
		"real_llm_ok": _is_real_dialogue_result(send_result, dialogue),
		"send_ok": bool(send_result.get("ok", false)),
		"provider": str(dialogue.get("model_provider", "")),
		"model": str(dialogue.get("model_name", "")),
		"model_fallback_used": bool(dialogue.get("model_fallback_used", false)),
		"rule_fallback": bool(dialogue.get("rule_fallback", false)),
		"escape_intervention_result": str(dialogue.get("escape_intervention_result", "")),
		"reply_text": str(dialogue.get("reply_text", "")),
		"debug_reason": str(dialogue.get("debug_reason", ""))
	}


func _is_real_dialogue_result(send_result: Dictionary, dialogue: Dictionary) -> bool:
	return (
		bool(send_result.get("ok", false))
		and not dialogue.is_empty()
		and str(dialogue.get("model_provider", "")).to_lower() not in ["", "mock"]
		and not bool(dialogue.get("model_fallback_used", true))
		and not bool(dialogue.get("rule_fallback", false))
	)


func _backend_url() -> String:
	var configured := OS.get_environment("REAL_LLM_BACKEND_URL").strip_edges()
	return DEFAULT_BACKEND_URL if configured.is_empty() else configured.trim_suffix("/")


func _scenario_enabled(scenario_id: String) -> bool:
	var only := OS.get_environment("REAL_DIALOGUE_SCENARIO").strip_edges()
	return only.is_empty() or only == scenario_id
