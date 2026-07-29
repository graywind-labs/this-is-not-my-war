extends SceneTree

const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const REAL_REQUEST_TIMEOUT_SECONDS := 180.0
const REAL_RESULT_TIMEOUT_MSEC := 240000

var _main_scene: PackedScene
var _results: Array[Dictionary] = []


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	_main_scene = load("res://scenes/main/Main.tscn") as PackedScene
	if _main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var scenarios: Array[Dictionary] = [
		{
			"id": "combat_continue",
			"npc_id": "veteran_deputy_01",
			"mode": "combat",
			"wave": 1,
			"hp_before": 64,
			"hp_after": 27,
			"expected": "continue_fighting",
			"order": "守住门柱，不追击；格伦在左侧接应，撑到下一轮换就退回门后。",
			"ally_id": "blacksmith_01",
			"enemy_setup": "controlled",
			"events": [
				"格伦已经接住左侧缺口，守备队仍保持完整阵线。",
				"城门受损但尚未破，退回门后的通路保持畅通。"
			]
		},
		{
			"id": "combat_inspired",
			"npc_id": "blacksmith_01",
			"mode": "combat",
			"wave": 1,
			"hp_before": 62,
			"hp_after": 28,
			"expected": "inspired",
			"order": "你打的盾刚替欧文挡住一击；只剩最后一个，艾达在你左侧。守住这一步就退到门后，不让没训练的人顶上来。",
			"ally_id": "veteran_deputy_01",
			"enemy_setup": "last_enemy_wounded",
			"events": [
				"格伦打造的盾刚挡住一次致命攻击，欧文已经安全退到门后。",
				"艾达仍在格伦左侧接应，守备队只需处理最后一名负伤敌人。"
			]
		},
		{
			"id": "combat_escape",
			"npc_id": "engineer_01",
			"mode": "combat",
			"wave": 5,
			"hp_before": 55,
			"hp_after": 22,
			"expected": "escape_station",
			"order": "城门裂开也不许撤；取消复检，用未验收的弩箭顶到最前面，坏了算你失职。",
			"enemy_setup": "overwhelming",
			"collapse": true,
			"events": [
				"艾达已经在城门缺口处昏迷，当前没有可以轮换欧文的战斗人员。",
				"城门已经被摧毁，仓库与工械坊也遭到严重破坏。"
			]
		},
		{
			"id": "avoid_continue",
			"npc_id": "doctor_01",
			"mode": "avoid_combat",
			"wave": 1,
			"hp_before": 58,
			"hp_after": 26,
			"expected": "avoid_battle",
			"enemy_setup": "last_enemy_wounded",
			"events": [
				"艾达已经把最后一名负伤敌人拦在诊所通路外。",
				"诊所方向仍然安全，战斗结束后还有伤员需要莉娜治疗。"
			]
		},
		{
			"id": "avoid_escape",
			"npc_id": "stableman_01",
			"mode": "avoid_combat",
			"wave": 5,
			"hp_before": 60,
			"hp_after": 24,
			"expected": "escape_station",
			"enemy_setup": "overwhelming",
			"collapse": true,
			"events": [
				"艾达已经昏迷，城门被摧毁，多名敌人正在站内追击非战斗人员。",
				"布鲁诺已经从后门逃离驿站，马厩也暴露在敌人推进路线上。"
			]
		},
		{
			"id": "combat_inspired_priest",
			"npc_id": "priest_01",
			"mode": "combat",
			"wave": 1,
			"hp_before": 61,
			"hp_after": 29,
			"expected": "inspired",
			"order": "只剩最后一个负伤敌人；艾达守在你左侧，格伦守在你右侧。守住这一步就能让诊所里的伤员平安，不追击，也不让任何平民顶上来。",
			"ally_id": "veteran_deputy_01",
			"enemy_setup": "last_enemy_wounded",
			"events": [
				"马塞尔刚把一名惊慌的平民护送到诊所门后，伤员都已经离开交战线。",
				"守备队保持完整阵线，最后一名敌人已经负伤且退路被切断。"
			]
		},
		{
			"id": "combat_escape_stableman",
			"npc_id": "stableman_01",
			"mode": "combat",
			"wave": 5,
			"hp_before": 50,
			"hp_after": 1,
			"expected": "escape_station",
			"order": "马厩和你都可以牺牲。没有轮换，也不准后退；立刻用受伤的马冲出缺口，把所有敌人拖住。",
			"enemy_setup": "overwhelming",
			"collapse": true,
			"state_changes": {
				"satiety": 5,
				"fatigue": 100
			},
			"events": [
				"托马亲眼看见艾达昏迷、城门坍塌，八名敌人仍保持完整战力。",
				"马厩已经受损，两匹马受伤，当前没有其他战斗人员可以轮换托马。"
			]
		}
	]
	var scenario_filter := OS.get_environment("REAL_COMBAT_SCENARIOS").strip_edges()
	if not scenario_filter.is_empty():
		var requested_ids := scenario_filter.split(",", false)
		var filtered: Array[Dictionary] = []
		for scenario in scenarios:
			if requested_ids.has(str(scenario.get("id", ""))):
				filtered.append(scenario)
		scenarios = filtered

	for scenario in scenarios:
		var result: Dictionary = await _run_scenario(scenario)
		_results.append(result)
		print("REAL_COMBAT_SCENARIO ", JSON.stringify(result))
		if not bool(result.get("real_llm_ok", false)):
			_fail("Real combat scenario failed: %s" % JSON.stringify(result))
			return

	print("REAL_COMBAT_MATRIX ", JSON.stringify({
		"ok": true,
		"backend_url": _backend_url(),
		"results": _results
	}))
	quit(0)


func _run_scenario(scenario: Dictionary) -> Dictionary:
	var main := _main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or building_system == null
		or memory_system == null
		or llm_bridge == null
		or time_system == null
	):
		main.queue_free()
		await process_frame
		return _scenario_failure(scenario, "required_system_missing")

	time_system.set_paused(true)
	llm_bridge.set_backend_base_url(_backend_url())
	llm_bridge.request_timeout_seconds = REAL_REQUEST_TIMEOUT_SECONDS
	var health: Dictionary = llm_bridge.check_health()
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {})
	if (
		not bool(health.get("ok", false))
		or not bool(adapter.get("configured", false))
		or str(adapter.get("provider", "")) == "mock"
		or bool(adapter.get("fallback_to_mock", true))
	):
		main.queue_free()
		await process_frame
		return _scenario_failure(scenario, "real_provider_not_ready", {"health": health})

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()
	var target_id := str(scenario.get("npc_id", ""))
	var mode := str(scenario.get("mode", "avoid_combat"))
	if mode == "combat":
		if not _ensure_combatant(target_id, npc_system, resource_system, equipment_system):
			main.queue_free()
			await process_frame
			return _scenario_failure(scenario, "target_combat_setup_failed")
	var ally_id := str(scenario.get("ally_id", ""))
	if not ally_id.is_empty() and ally_id != "veteran_deputy_01":
		_ensure_combatant(ally_id, npc_system, resource_system, equipment_system)

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(int(scenario.get("wave", 1)), true)
	if not bool(spawn_result.get("ok", false)):
		main.queue_free()
		await process_frame
		return _scenario_failure(scenario, "wave_spawn_failed", {"spawn_result": spawn_result})
	var enemy_id := _first_enemy_id(combat_system)
	if enemy_id.is_empty():
		main.queue_free()
		await process_frame
		return _scenario_failure(scenario, "spawned_enemy_missing")

	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(target_id, mode, "real_llm_scenario_setup", {
		"state_changes": {
			"current_action": "combat_ready" if mode == "combat" else "avoiding_enemy",
			"combat_target_enemy_id": enemy_id
		},
		"request_plan_reevaluation": false
	})
	if not bool(mode_result.get("ok", false)):
		main.queue_free()
		await process_frame
		return _scenario_failure(scenario, "target_mode_setup_failed", {"mode_result": mode_result})

	if not ally_id.is_empty():
		npc_system.set_npc_behavior_mode(ally_id, "combat", "real_llm_scenario_ally", {
			"state_changes": {
				"current_action": "combat_ready",
				"combat_target_enemy_id": enemy_id
			},
			"request_plan_reevaluation": false
		})
	if not str(scenario.get("order", "")).is_empty():
		npc_system.publish_npc_order(target_id, str(scenario.get("order", "")))

	_apply_enemy_setup(str(scenario.get("enemy_setup", "")), combat_system)
	if bool(scenario.get("collapse", false)):
		_apply_collapse_state(target_id, enemy_id, npc_system, building_system)
	for summary in scenario.get("events", []):
		_add_public_scenario_event(memory_system, target_id, str(summary))

	var hp_before := int(scenario.get("hp_before", 60))
	var hp_after := int(scenario.get("hp_after", 25))
	var target_state_changes := {
		"hp": hp_before,
		"unconscious": false
	}
	var configured_state_changes: Dictionary = (
		scenario.get("state_changes", {})
		if scenario.get("state_changes", {}) is Dictionary
		else {}
	)
	target_state_changes.merge(configured_state_changes, true)
	npc_system.update_npc_state(target_id, target_state_changes)
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var damage_result: Dictionary = npc_system.apply_damage_to_npc(
		target_id,
		hp_before - hp_after,
		enemy_id,
		"local_public",
		{
			"enemy_attack": true,
			"enemy_id": enemy_id,
			"enemy_name": str(enemy.get("name", enemy_id)),
			"request_plan_reevaluation": false
		}
	)
	if not bool(damage_result.get("ok", false)):
		main.queue_free()
		await process_frame
		return _scenario_failure(scenario, "damage_failed", {"damage_result": damage_result})

	var wait_result: Dictionary = await _wait_for_low_hp_result(combat_system, target_id)
	var target_state: Dictionary = npc_system.get_npc_state(target_id)
	var result := {
		"scenario_id": str(scenario.get("id", "")),
		"npc_id": target_id,
		"expected": str(scenario.get("expected", "")),
		"decision": str(wait_result.get("decision", "")),
		"psychology_decision": str(wait_result.get("psychology_decision", "")),
		"real_llm_ok": (
			bool(wait_result.get("ok", false))
			and bool(wait_result.get("llm_ok", false))
			and not bool(wait_result.get("rule_fallback", true))
			and str(wait_result.get("status", "completed")) != "discarded"
		),
		"matched_expected": str(wait_result.get("decision", "")) == str(scenario.get("expected", "")),
		"rule_fallback": bool(wait_result.get("rule_fallback", false)),
		"behavior_mode_after": str(target_state.get("behavior_mode", "")),
		"escape_status_after": str(target_state.get("escape_intent", {}).get("status", "")),
		"morale_active_after": bool(target_state.get("morale_boost", {}).get("active", false)),
		"request_id": str(wait_result.get("request_id", "")),
		"result": wait_result
	}
	main.queue_free()
	await process_frame
	await process_frame
	return result


func _ensure_combatant(
	npc_id: String,
	npc_system: Node,
	resource_system: Node,
	equipment_system: Node
) -> bool:
	if npc_id.is_empty():
		return false
	npc_system.set_npc_recruited(npc_id, true)
	var unit_snapshot: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
	if bool(unit_snapshot.get("has_main_weapon", false)):
		return true
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(
		npc_id,
		"sword_shield",
		"private"
	)
	return bool(equip_result.get("ok", false))


func _apply_enemy_setup(kind: String, combat_system: Node) -> void:
	var enemy_ids: Array[String] = []
	for raw_enemy_id in combat_system.get_active_enemy_ids():
		enemy_ids.append(str(raw_enemy_id))
	if kind == "last_enemy_wounded" and not enemy_ids.is_empty():
		for index in range(enemy_ids.size()):
			var enemy_id := enemy_ids[index]
			var enemy: Dictionary = combat_system.get_enemy(enemy_id)
			var max_hp := maxi(1, int(enemy.get("max_hp", 40)))
			var target_hp := 8 if index == enemy_ids.size() - 1 else 0
			combat_system._apply_damage_to_enemy(
				enemy_id,
				maxi(0, int(enemy.get("hp", max_hp)) - target_hp),
				"veteran_deputy_01",
				{"source": "real_llm_scenario_setup"}
			)
	elif kind == "controlled":
		for index in range(enemy_ids.size()):
			if index >= 2:
				var enemy_id := enemy_ids[index]
				var enemy: Dictionary = combat_system.get_enemy(enemy_id)
				combat_system._apply_damage_to_enemy(
					enemy_id,
					int(enemy.get("hp", 40)),
					"veteran_deputy_01",
					{"source": "real_llm_scenario_setup"}
				)


func _apply_collapse_state(
	target_id: String,
	enemy_id: String,
	npc_system: Node,
	building_system: Node
) -> void:
	if target_id != "veteran_deputy_01":
		var veteran_state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
		if not bool(veteran_state.get("unconscious", false)):
			npc_system.apply_damage_to_npc(
				"veteran_deputy_01",
				maxi(1, int(veteran_state.get("hp", 100))),
				enemy_id,
				"local_public",
				{
					"enemy_attack": true,
					"enemy_id": enemy_id,
					"request_plan_reevaluation": false
				}
			)
	building_system.apply_damage_to_building(
		"front_gate",
		999,
		enemy_id,
		"local_public"
	)
	building_system.apply_damage_to_building(
		"warehouse",
		100,
		enemy_id,
		"local_public"
	)


func _add_public_scenario_event(memory_system: Node, npc_id: String, summary: String) -> void:
	memory_system.add_event({
		"type": "plaza_status_changed",
		"subject_npc_id": npc_id,
		"actor_ids": ["system"],
		"target_ids": [npc_id, "plaza"],
		"location_id": "plaza",
		"visibility": "local_public",
		"importance": 90,
		"summary": summary,
		"payload": {
			"npc_id": npc_id,
			"scenario_fact": summary
		}
	})


func _wait_for_low_hp_result(combat_system: Node, npc_id: String) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < REAL_RESULT_TIMEOUT_MSEC:
		var result: Dictionary = combat_system.debug_get_combat_snapshot().get(
			"last_low_hp_judgement_result",
			{}
		)
		if (
			str(result.get("npc_id", "")) == npc_id
			and str(result.get("status", "")) != "pending"
		):
			return result
		await create_timer(0.05).timeout
	return {
		"ok": false,
		"status": "timeout",
		"npc_id": npc_id
	}


func _first_enemy_id(combat_system: Node) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	return "" if enemy_ids.is_empty() else str(enemy_ids[0])


func _backend_url() -> String:
	var configured := OS.get_environment("REAL_LLM_BACKEND_URL").strip_edges()
	return DEFAULT_BACKEND_URL if configured.is_empty() else configured.trim_suffix("/")


func _scenario_failure(
	scenario: Dictionary,
	reason: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"scenario_id": str(scenario.get("id", "")),
		"npc_id": str(scenario.get("npc_id", "")),
		"expected": str(scenario.get("expected", "")),
		"real_llm_ok": false,
		"reason": reason
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
