extends SceneTree


class CapturingJudgementBridge:
	extends Node

	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)

	var judgement_requests: Array[Dictionary] = []
	var revision_request_count := 0

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_dialogue_plan_revision_judgement_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "player_dialogue_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func request_npc_plan_revision_async(_npc_id: String, _options: Dictionary = {}) -> Dictionary:
		revision_request_count += 1
		return {"ok": false, "message": "No revision expected in this verification."}

	func answer_unchanged(request: Dictionary) -> void:
		dialogue_plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"dialogue_plan_revision_judgement": {
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": false,
				"revision_hours": [],
				"summary": "原计划仍然适用。",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "capture-real-provider",
					"configured": true,
					"fallback_to_mock": false
				}
			}
		}


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var systems := root.get_node_or_null("Main/Systems")
	var original_llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [time_system, npc_system, action_system, daily_plan_system, dialog_system, systems, original_llm_bridge].has(null):
		_fail("Player-dialogue plan judgement verification requires all scene systems")
		return

	const NPC_ID := "cook_01"
	time_system.set_current_time(1, 8, 0, 0)
	time_system.set_time_scale(0.0)
	daily_plan_system.set_auto_execution_enabled(false)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dining_hall"):
		_fail("Could not place cook in dining hall")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_dialogue_judgement_ready"
	})
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_dialogue_judgement"):
		_fail("Could not install work plan")
		return

	systems.remove_child(original_llm_bridge)
	original_llm_bridge.queue_free()
	await process_frame
	var bridge := CapturingJudgementBridge.new()
	bridge.name = "LLMBridge"
	systems.add_child(bridge)
	bridge.dialogue_plan_revision_judgement_async_response_received.connect(
		Callable(daily_plan_system, "_on_dialogue_plan_revision_judgement_async_response")
	)

	if root.get_node_or_null("Main/UI/DialogPanel/Panel/VBox/DialogPlanReevaluationToggle") != null:
		_fail("Removed guard-officer plan-reevaluation toggle is still present")
		return

	var first_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(first_execute.get("ok", false)) or str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Initial current-hour plan did not start: %s" % JSON.stringify(first_execute))
		return

	var dialogue_result: Dictionary = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open player dialogue: %s" % JSON.stringify(dialogue_result))
		return
	if dialog_system.get_dialogue_state().has("reevaluate_plan_on_end"):
		_fail("Player dialogue state still exposes the removed manual reevaluation option")
		return
	var activation_result: Dictionary = dialog_system.call("_activate_player_dialogue_draft", "verify_dialogue_judgement")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate player dialogue: %s" % JSON.stringify(activation_result))
		return
	var effect_result: Dictionary = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_dialogue_judgement")
	if not bool(effect_result.get("ok", false)):
		_fail("Could not start player-dialogue interruption: %s" % JSON.stringify(effect_result))
		return
	if not bool(effect_result.get("interrupted_action", false)) or str(effect_result.get("interrupted_action_id", "")) != "work_dining_hall":
		_fail("Player dialogue did not record the interrupted plan action: %s" % JSON.stringify(effect_result))
		return
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("Effective player dialogue should interrupt the current work action")
		return
	if not _apply_completed_turn(dialog_system, NPC_ID, "按原安排继续吧。"):
		return

	var end_result: Dictionary = dialog_system.end_dialogue("verify_dialogue_judgement")
	if not bool(end_result.get("plan_judgement_queued", false)):
		_fail("Completed player dialogue did not queue the mandatory judgement layer: %s" % JSON.stringify(end_result))
		return
	if end_result.has("resume_plan_result"):
		_fail("Completed player dialogue resumed before the judgement result")
		return
	await process_frame
	if bridge.judgement_requests.size() != 1:
		_fail("Completed player dialogue should launch exactly one judgement request")
		return
	var judgement_options: Dictionary = bridge.judgement_requests[0].get("options", {})
	if (judgement_options.get("dialogue_history", []) as Array).size() < 2:
		_fail("Judgement request did not receive the completed dialogue history")
		return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "":
		_fail("Interrupted action resumed before the no-change judgement arrived")
		return

	bridge.answer_unchanged(bridge.judgement_requests[0])
	if bridge.revision_request_count != 0:
		_fail("No-change judgement unexpectedly called plan revision")
		return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("No-change judgement did not resume the interrupted plan action")
		return
	var judgement_result: Dictionary = daily_plan_system.get_last_dialogue_plan_judgement_result()
	if str(judgement_result.get("status", "")) != "dialogue_plan_unchanged":
		_fail("No-change judgement status mismatch: %s" % JSON.stringify(judgement_result))
		return

	# The explicit resume consumes only the interrupted phase; ordinary dispatch remains deduplicated.
	if not action_system.interrupt_npc_action(NPC_ID, "verify_normal_dispatch_guard"):
		_fail("Could not interrupt resumed work for deduplication check")
		return
	var ordinary_repeat: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if str(ordinary_repeat.get("status", "")) != "already_executed_this_plan_phase":
		_fail("Normal same-phase dispatch guard was weakened: %s" % JSON.stringify(ordinary_repeat))
		return

	# A completed dialogue with no interrupted action is still judged, but no-change must not replay work.
	dialogue_result = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open idle player dialogue")
		return
	activation_result = dialog_system.call("_activate_player_dialogue_draft", "verify_idle_dialogue")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate idle player dialogue")
		return
	effect_result = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_idle_dialogue")
	if not bool(effect_result.get("ok", false)) or bool(effect_result.get("interrupted_action", true)):
		_fail("Idle player dialogue incorrectly reported an interrupted action: %s" % JSON.stringify(effect_result))
		return
	if not _apply_completed_turn(dialog_system, NPC_ID, "照旧即可。"):
		return
	var idle_end_result: Dictionary = dialog_system.end_dialogue("verify_idle_dialogue")
	if not bool(idle_end_result.get("plan_judgement_queued", false)):
		_fail("Idle completed dialogue skipped the mandatory judgement layer")
		return
	await process_frame
	if bridge.judgement_requests.size() != 2:
		_fail("Second completed dialogue did not launch exactly one additional judgement")
		return
	bridge.answer_unchanged(bridge.judgement_requests[1])
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("No-change judgement replayed an already-finished current-hour action")
		return
	var idle_repeat: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if str(idle_repeat.get("status", "")) != "already_executed_this_plan_phase":
		_fail("Idle dialogue weakened the normal same-phase dispatch guard: %s" % JSON.stringify(idle_repeat))
		return

	# If the dialogue crosses an hour boundary, the old-hour action is no longer a
	# resumable phase. A no-change judgement must release exactly the new-hour plan.
	time_system.set_current_time(1, 8, 0, 0)
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_cross_hour_plan(8, 9),
		false,
		"verify_cross_hour_dialogue"
	):
		_fail("Could not install the cross-hour dialogue plan")
		return
	var cross_hour_old_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if (
		not bool(cross_hour_old_execute.get("ok", false))
		or str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall"
	):
		_fail("Could not start the old-hour action for the cross-hour case: %s" % JSON.stringify(cross_hour_old_execute))
		return
	dialogue_result = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open the cross-hour player dialogue")
		return
	activation_result = dialog_system.call("_activate_player_dialogue_draft", "verify_cross_hour_dialogue")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate the cross-hour player dialogue")
		return
	effect_result = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_cross_hour_dialogue")
	if (
		not bool(effect_result.get("ok", false))
		or str(effect_result.get("interrupted_action_id", "")) != "work_dining_hall"
		or not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
	):
		_fail("Cross-hour dialogue did not interrupt and retain the old-hour action id: %s" % JSON.stringify(effect_result))
		return
	if not _apply_completed_turn(dialog_system, NPC_ID, "下一时段也按计划办。"):
		return
	time_system.set_current_time(1, 9, 0, 0)
	var deferred_new_hour: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if (
		str(deferred_new_hour.get("status", "")) != "priority_dialogue_active"
		or not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
	):
		_fail("New-hour dispatch was not deferred behind the active player dialogue: %s" % JSON.stringify(deferred_new_hour))
		return
	var cross_hour_end: Dictionary = dialog_system.end_dialogue("verify_cross_hour_dialogue")
	if not bool(cross_hour_end.get("plan_judgement_queued", false)):
		_fail("Cross-hour player dialogue did not queue its judgement")
		return
	await process_frame
	if bridge.judgement_requests.size() != 3:
		_fail("Cross-hour player dialogue did not launch exactly one additional judgement")
		return
	bridge.answer_unchanged(bridge.judgement_requests[2])
	for _index in range(3):
		await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "visit_location":
		_fail(
			"Cross-hour no-change judgement did not dispatch the current-hour plan; runtime=%s result=%s"
			% [
				str(action_system.get_runtime_action_id(NPC_ID)),
				JSON.stringify(daily_plan_system.get_last_dialogue_plan_judgement_result())
			]
		)
		return
	var cross_hour_judgement: Dictionary = daily_plan_system.get_last_dialogue_plan_judgement_result()
	if str(cross_hour_judgement.get("resume_result", {}).get("status", "")) != "interrupted_action_not_current_plan":
		_fail("Cross-hour judgement did not explicitly reject the old action resume: %s" % JSON.stringify(cross_hour_judgement))
		return
	if not action_system.interrupt_npc_action(NPC_ID, "verify_cross_hour_dispatch_once"):
		_fail("Could not interrupt the new-hour action for the exactly-once check")
		return
	var cross_hour_repeat: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if str(cross_hour_repeat.get("status", "")) != "already_executed_once_per_plan_hour":
		_fail("Cross-hour no-change judgement dispatched the current-hour phase more than once: %s" % JSON.stringify(cross_hour_repeat))
		return

	print("T0049 player-dialogue judgement and current-plan resume verification passed.")
	quit(0)


func _make_work_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "work_dining_hall",
			"reason": "T0049 dialogue judgement resume verification",
			"source": "verify_dialogue_judgement"
		})
	return plan


func _make_cross_hour_plan(old_hour: int, new_hour: int) -> Array:
	var plan := _make_work_plan()
	plan[old_hour] = {
		"hour": old_hour,
		"action_id": "work_dining_hall",
		"reason": "验证跨小时前的原行动不可恢复",
		"source": "verify_cross_hour_dialogue"
	}
	plan[new_hour] = {
		"hour": new_hour,
		"action_id": "visit_location",
		"reason": "验证判别结束后只派发当前小时计划",
		"source": "verify_cross_hour_dialogue",
		"target": {
			"target_id": "plaza",
			"location_id": "plaza"
		}
	}
	return plan


func _apply_completed_turn(dialog_system: Node, npc_id: String, player_text: String) -> bool:
	var apply_result: Dictionary = dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"ok": true,
			"replyer_id": npc_id,
			"reply_text": "明白了，守备官。",
			"response_kind": "reply_to_player",
			"emotion": "neutral",
			"recruitment_result": "none",
			"wartime_reaction": "none",
		}
	}, {
		"kind": "player_message",
		"clean_text": player_text,
		"next_round": 1,
		"effective_recruitment_request": false,
		"dialogue_kind": "player_npc"
	})
	if not bool(apply_result.get("ok", false)):
		_fail("Could not apply completed player dialogue turn: %s" % JSON.stringify(apply_result))
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
