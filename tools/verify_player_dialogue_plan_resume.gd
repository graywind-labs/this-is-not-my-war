extends SceneTree


class CapturingJudgementBridge:
	extends Node

	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var judgement_requests: Array[Dictionary] = []
	var revision_request_count := 0
	var capture_revision_requests := false
	var revision_requests: Array[Dictionary] = []

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

	func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		revision_request_count += 1
		if capture_revision_requests:
			var request_id := "player_dialogue_revision_%d" % revision_request_count
			revision_requests.append({
				"request_id": request_id,
				"npc_id": npc_id,
				"options": options.duplicate(true)
			})
			return {"ok": true, "pending": true, "request_id": request_id}
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

	func answer_needs_revision(request: Dictionary, revision_hour: int) -> void:
		dialogue_plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"dialogue_plan_revision_judgement": {
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": true,
				"revision_hours": [revision_hour],
				"summary": "当前小时需要重排。",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func answer_revision_failure(request: Dictionary) -> void:
		plan_revision_async_response_received.emit({
			"ok": false,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"message": "Deterministic late stage-two failure."
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
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var systems := root.get_node_or_null("Main/Systems")
	var original_llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [time_system, npc_system, action_system, resource_system, daily_plan_system, dialog_system, systems, original_llm_bridge].has(null):
		_fail("Player-dialogue plan judgement verification requires all scene systems")
		return

	const NPC_ID := "cook_01"
	time_system.set_current_time(1, 8, 0, 0)
	time_system.set_time_scale(0.0)
	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dining_hall"):
		_fail("Could not place cook in dining hall")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_dialogue_judgement_ready"
	})
	_set_debug_move_speed(NPC_ID, 5.0)
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
	bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)

	if root.get_node_or_null("Main/UI/DialogPanel/Panel/VBox/DialogPlanReevaluationToggle") != null:
		_fail("Removed guard-officer plan-reevaluation toggle is still present")
		return

	var first_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(first_execute.get("ok", false)) or str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Initial current-hour plan did not start: %s" % JSON.stringify(first_execute))
		return
	if not await _wait_for_active_action(action_system, NPC_ID, "work_dining_hall"):
		_fail("Cook did not physically reach the dining-hall workstation before dialogue")
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

	# If the dialogue crosses a real hour_started boundary, the old-hour action is
	# no longer a resumable phase. The NPC must keep the same player dialogue and
	# workstation hold until the player explicitly ends it; only the completed
	# judgement may release exactly the new-hour plan.
	time_system.set_current_time(1, 8, 59, 50)
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
	if not await _wait_for_active_action(action_system, NPC_ID, "work_dining_hall"):
		_fail("Cook did not physically resume the old-hour dining work before cross-hour dialogue")
		return
	var cross_hour_npc_node := _get_npc_node(NPC_ID)
	if cross_hour_npc_node == null or not cross_hour_npc_node.has_method("debug_get_spatial_attachment_snapshot"):
		_fail("Could not inspect the cross-hour workstation attachment")
		return
	var cross_hour_position_before: Variant = npc_system.get_npc_world_position(NPC_ID)
	var cross_hour_formal_before: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var cross_hour_session_before: Dictionary = cross_hour_formal_before.get("session", {})
	var cross_hour_workstation_id := str(cross_hour_session_before.get("workstation_id", ""))
	var cross_hour_attachment_before: Dictionary = cross_hour_npc_node.debug_get_spatial_attachment_snapshot()
	var cross_hour_meal_before := int(resource_system.get_resource("meal"))
	var cross_hour_grain_before := int(resource_system.get_resource("grain"))
	if (
		not cross_hour_position_before is Vector3
		or cross_hour_workstation_id.is_empty()
		or not bool(cross_hour_formal_before.get("active", false))
	):
		_fail("Old-hour work did not establish an inspectable workstation before dialogue: %s" % JSON.stringify({
			"formal": cross_hour_formal_before,
			"attachment": cross_hour_attachment_before,
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
			"state": npc_system.get_npc_state(NPC_ID),
		}))
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
	var cross_hour_dialogue_id := str(dialog_system.get_dialogue_state().get("dialogue_id", ""))
	daily_plan_system.set_auto_execution_enabled(true)
	if not time_system.debug_advance_game_seconds(10.0):
		_fail("Could not advance the authoritative clock across the dialogue hour boundary")
		return
	await process_frame
	await physics_frame
	daily_plan_system.set_auto_execution_enabled(false)
	var deferred_new_hour: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	var cross_hour_dialogue_after: Dictionary = dialog_system.get_dialogue_state()
	var cross_hour_position_after: Variant = npc_system.get_npc_world_position(NPC_ID)
	var cross_hour_formal_after: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var cross_hour_session_after: Dictionary = cross_hour_formal_after.get("session", {})
	var cross_hour_attachment_after: Dictionary = cross_hour_npc_node.debug_get_spatial_attachment_snapshot()
	var cross_hour_npc_state_after: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not str(deferred_new_hour.get("status", "")) in [
			"priority_dialogue_active",
			"dialogue_plan_judgement_pending",
		]
		or not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
		or str(cross_hour_dialogue_after.get("dialogue_id", "")) != cross_hour_dialogue_id
		or str(cross_hour_dialogue_after.get("session_status", "")) != "active"
		or bool(cross_hour_dialogue_after.get("waiting", false))
		or not (cross_hour_npc_state_after.get("llm_activity", {}) as Dictionary).is_empty()
		or not cross_hour_position_after is Vector3
		or (cross_hour_position_before as Vector3).distance_to(cross_hour_position_after) > 0.001
		or not bool(cross_hour_formal_after.get("active", false))
		or not bool(cross_hour_session_after.get("dialogue_suspended_hold", false))
		or str(cross_hour_session_after.get("workstation_id", "")) != cross_hour_workstation_id
		or cross_hour_attachment_after != cross_hour_attachment_before
		or int(resource_system.get_resource("meal")) != cross_hour_meal_before
		or int(resource_system.get_resource("grain")) != cross_hour_grain_before
	):
		_fail("Real hour boundary did not preserve the active dialogue and workstation hold: %s" % JSON.stringify({
			"dispatch": deferred_new_hour,
			"dialogue": cross_hour_dialogue_after,
			"position_before": cross_hour_position_before,
			"position_after": cross_hour_position_after,
			"formal": cross_hour_formal_after,
			"attachment": cross_hour_attachment_after,
			"npc_state": cross_hour_npc_state_after,
		}))
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
	var replacement_formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var replacement_session: Dictionary = replacement_formal.get("session", {})
	if (
		not dialog_system.get_dialogue_state().is_empty()
		or str(replacement_session.get("action_id", "")) == "work_dining_hall"
		or str(replacement_session.get("workstation_id", "")) == cross_hour_workstation_id
		or bool(replacement_session.get("dialogue_suspended_hold", false))
		or bool(cross_hour_npc_node.debug_get_spatial_attachment_snapshot().get("active", false))
	):
		_fail("Cross-hour replacement left the ended dialogue or old workstation transaction behind: %s" % JSON.stringify({
			"dialogue": dialog_system.get_dialogue_state(),
			"formal": replacement_formal,
			"attachment": cross_hour_npc_node.debug_get_spatial_attachment_snapshot(),
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
		}))
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

	# Regression: at the first-day handoff NPCs leave their dormitory for
	# breakfast. The first effective guard-officer message must stop that formal
	# route in place, rather than restoring the actor to the bed/workstation safe
	# point, and the unchanged plan must subsequently route from that position.
	time_system.set_current_time(1, 6, 0, 0)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dormitory"):
		_fail("Could not place cook in dormitory for moving-dialogue regression")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_moving_dialogue_ready"
	})
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_eat_plan(),
		false,
		"verify_moving_dialogue"
	):
		_fail("Could not install breakfast plan for moving-dialogue regression")
		return
	var breakfast_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(breakfast_execute.get("ok", false)):
		_fail("Could not start breakfast route: %s" % JSON.stringify(breakfast_execute))
		return
	var moving_position: Variant = await _wait_for_moving_position(
		npc_system,
		action_system,
		NPC_ID,
		"eat_at_dining_hall"
	)
	if not moving_position is Vector3:
		_fail("Cook did not begin the dormitory-to-dining-hall breakfast route")
		return
	dialogue_result = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open dialogue during breakfast travel")
		return
	activation_result = dialog_system.call("_activate_player_dialogue_draft", "verify_moving_dialogue")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate dialogue during breakfast travel")
		return
	var position_before_interrupt: Vector3 = npc_system.get_npc_world_position(NPC_ID)
	effect_result = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_moving_dialogue")
	if not bool(effect_result.get("ok", false)):
		_fail("Could not interrupt breakfast travel for dialogue: %s" % JSON.stringify(effect_result))
		return
	var position_after_interrupt: Variant = npc_system.get_npc_world_position(NPC_ID)
	if (
		not position_after_interrupt is Vector3
		or position_before_interrupt.distance_to(position_after_interrupt) > 0.001
	):
		_fail("Dialogue interruption displaced the moving NPC: before=%s after=%s" % [
			str(position_before_interrupt),
			str(position_after_interrupt)
		])
		return
	var interrupted_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	var interrupted_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
		or not str(interrupted_state.get("movement_target", "")).is_empty()
		or not (interrupted_spatial.get("route", {}) as Dictionary).is_empty()
	):
		_fail("Dialogue interruption left stale movement authority: state=%s spatial=%s" % [
			JSON.stringify(interrupted_state),
			JSON.stringify(interrupted_spatial)
		])
		return
	if not _apply_completed_turn(dialog_system, NPC_ID, "吃完早饭再继续原计划。"):
		return
	var moving_end: Dictionary = dialog_system.end_dialogue("verify_moving_dialogue")
	if not bool(moving_end.get("plan_judgement_queued", false)):
		_fail("Moving dialogue did not queue plan judgement")
		return
	await process_frame
	if bridge.judgement_requests.size() != 4:
		_fail("Moving dialogue did not launch exactly one judgement request")
		return
	bridge.answer_unchanged(bridge.judgement_requests[3])
	for _index in range(3):
		await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "eat_at_dining_hall":
		_fail("Unchanged breakfast plan did not resume after dialogue")
		return
	if not await _wait_for_active_action(action_system, NPC_ID, "eat_at_dining_hall"):
		_fail("Resumed breakfast plan did not reach a dining seat")
		return

	# Regression: a guard-officer dialogue pauses an already seated meal in place.
	# The consumed food and elapsed progress belong to the same meal transaction;
	# the seat, sitting attachment and position must survive until it resumes.
	var npc_node := _get_npc_node(NPC_ID)
	if npc_node == null or not npc_node.has_method("debug_get_spatial_attachment_snapshot"):
		_fail("Could not inspect the seated dining attachment")
		return
	var seated_attachment: Dictionary = npc_node.debug_get_spatial_attachment_snapshot()
	var seated_position: Variant = npc_system.get_npc_world_position(NPC_ID)
	var seated_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var meal_before_dialogue := int(resource_system.get_resource("meal"))
	var grain_before_dialogue := int(resource_system.get_resource("grain"))
	var satiety_before_dialogue := float(npc_system.get_npc_state(NPC_ID).get("satiety", 0.0))
	if (
		not bool(seated_attachment.get("active", false))
		or str(seated_attachment.get("pose", "")) != "sitting"
		or not seated_position is Vector3
	):
		_fail("Breakfast did not establish a seated attachment before dialogue")
		return
	dialogue_result = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open dialogue during active seated eating")
		return
	activation_result = dialog_system.call("_activate_player_dialogue_draft", "verify_seated_eat_dialogue")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate dialogue during active seated eating")
		return
	effect_result = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_seated_eat_dialogue")
	if (
		not bool(effect_result.get("ok", false))
		or not bool(effect_result.get("interrupted_action", false))
		or str(effect_result.get("interrupted_action_id", "")) != "eat_at_dining_hall"
	):
		_fail("Seated meal dialogue did not interrupt the active meal: %s" % JSON.stringify(effect_result))
		return
	await process_frame
	await physics_frame
	var held_position: Variant = npc_system.get_npc_world_position(NPC_ID)
	var held_attachment: Dictionary = npc_node.debug_get_spatial_attachment_snapshot()
	var interrupted_seated_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var held_formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var held_session: Dictionary = held_formal.get("session", {})
	action_system._on_logical_time_tick(600.0, 1.0)
	if (
		not held_position is Vector3
		or (seated_position as Vector3).distance_to(held_position) > 0.001
		or not bool(held_attachment.get("active", false))
		or str(held_attachment.get("pose", "")) != "sitting"
		or not bool(held_attachment.get("body_collision_disabled", false))
		or str(interrupted_seated_state.get("physical_location_phase", "")) != "occupant_anchor"
		or str(interrupted_seated_state.get("spatial_route_phase", "")) != "dialogue_workstation_hold"
		or str(interrupted_seated_state.get("current_workstation_id", "")).is_empty()
		or not bool(held_formal.get("active", false))
		or not bool(held_session.get("dialogue_suspended_hold", false))
		or not action_system.get_runtime_action_snapshot(NPC_ID).is_empty()
		or int(resource_system.get_resource("meal")) != meal_before_dialogue
		or int(resource_system.get_resource("grain")) != grain_before_dialogue
		or not is_equal_approx(float(npc_system.get_npc_state(NPC_ID).get("satiety", 0.0)), satiety_before_dialogue)
	):
		_fail("Seated meal dialogue did not preserve a non-consuming in-place hold: %s" % JSON.stringify({
			"seated_position": seated_position,
			"held_position": held_position,
			"attachment": held_attachment,
			"state": interrupted_seated_state,
			"formal": held_formal,
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID)
		}))
		return
	if not _apply_completed_turn(dialog_system, NPC_ID, "吃完午饭再继续原计划。"):
		return
	var seated_end: Dictionary = dialog_system.end_dialogue("verify_seated_eat_dialogue")
	if not bool(seated_end.get("plan_judgement_queued", false)):
		_fail("Seated meal dialogue did not queue plan judgement")
		return
	await process_frame
	if bridge.judgement_requests.size() != 5:
		_fail("Seated meal dialogue did not launch exactly one judgement request")
		return
	bridge.answer_unchanged(bridge.judgement_requests[4])
	for _index in range(3):
		await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "eat_at_dining_hall":
		_fail("Unchanged seated meal plan did not resume in place after dialogue")
		return
	var resumed_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var resumed_attachment: Dictionary = npc_node.debug_get_spatial_attachment_snapshot()
	var resumed_position: Variant = npc_system.get_npc_world_position(NPC_ID)
	var resumed_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if (
		str(resumed_state.get("physical_location_phase", "")) != "occupant_anchor"
		or str(resumed_state.get("spatial_route_phase", "")) != "occupant_attached"
		or not bool(resumed_attachment.get("active", false))
		or str(resumed_attachment.get("pose", "")) != "sitting"
		or not resumed_position is Vector3
		or (seated_position as Vector3).distance_to(resumed_position) > 0.001
		or not is_equal_approx(float(resumed_runtime.get("elapsed_seconds", -1.0)), float(seated_runtime.get("elapsed_seconds", -2.0)))
		or int(resource_system.get_resource("meal")) != meal_before_dialogue
		or int(resource_system.get_resource("grain")) != grain_before_dialogue
		or not (resumed_state.get("last_action_failure_context", {}) as Dictionary).is_empty()
	):
		_fail("Resumed seated meal changed seat, progress, resources or attachment state: %s" % JSON.stringify({
			"state": resumed_state,
			"attachment": resumed_attachment,
			"runtime": resumed_runtime,
			"position": resumed_position
		}))
		return

	# Regression: the player can end a dialogue immediately before the hour boundary,
	# leaving its plan judgement in flight while hour_started creates a new marker.
	# The late response is stale for revision purposes, but must terminally unlock
	# that same dialogue chain's latest-hour plan instead of erasing its marker.
	if not action_system.interrupt_npc_action(NPC_ID, "verify_late_judgement_setup"):
		_fail("Could not stop the resumed meal before the late-judgement regression")
		return
	time_system.set_current_time(1, 12, 59, 50)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dining_hall"):
		_fail("Could not stage the late-judgement NPC in the dining hall")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_late_judgement_ready",
	})
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_cross_hour_plan(12, 13),
		false,
		"verify_late_judgement"
	):
		_fail("Could not install the late-judgement cross-hour plan")
		return
	var late_old_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(late_old_execute.get("ok", false)):
		_fail("Could not start old-hour work for the late-judgement case")
		return
	if not await _wait_for_active_action(action_system, NPC_ID, "work_dining_hall"):
		_fail("Late-judgement old-hour work did not become active")
		return
	var late_formal_before: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var late_workstation_id := str(late_formal_before.get("session", {}).get("workstation_id", ""))
	dialogue_result = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open the late-judgement player dialogue")
		return
	activation_result = dialog_system.call("_activate_player_dialogue_draft", "verify_late_judgement")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate the late-judgement player dialogue")
		return
	effect_result = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_late_judgement")
	if not bool(effect_result.get("ok", false)):
		_fail("Could not suspend old-hour work for the late-judgement case")
		return
	if not _apply_completed_turn(dialog_system, NPC_ID, "下一小时按新计划行动。"):
		return
	var late_request_count_before := bridge.judgement_requests.size()
	var late_end: Dictionary = dialog_system.end_dialogue("verify_late_judgement")
	if not bool(late_end.get("plan_judgement_queued", false)):
		_fail("Late-judgement dialogue did not queue its mandatory judgement")
		return
	await process_frame
	if bridge.judgement_requests.size() != late_request_count_before + 1:
		_fail("Late-judgement dialogue did not launch exactly one request")
		return
	var late_request: Dictionary = bridge.judgement_requests.back()
	daily_plan_system.set_auto_execution_enabled(true)
	if not time_system.debug_advance_game_seconds(10.0):
		_fail("Could not cross the hour while dialogue judgement was pending")
		return
	await process_frame
	daily_plan_system.set_auto_execution_enabled(false)
	var late_pending_before_response: Dictionary = daily_plan_system.get(
		"_deferred_current_revision_execution_by_npc"
	)
	if (
		not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
		or not bool(late_pending_before_response.get(NPC_ID, {}).get("wait_for_dialogue_resolution", false))
		or not bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {}).get("dialogue_suspended_hold", false))
	):
		_fail("Current-hour dispatch was not held while the old-hour judgement remained pending")
		return
	bridge.answer_unchanged(late_request)
	for _index in range(3):
		await process_frame
	var late_judgement: Dictionary = daily_plan_system.get_last_dialogue_plan_judgement_result()
	var late_formal_after: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var late_session_after: Dictionary = late_formal_after.get("session", {})
	var late_pending_after_response: Dictionary = daily_plan_system.get(
		"_deferred_current_revision_execution_by_npc"
	)
	if (
		str(late_judgement.get("status", "")) != "stale_dialogue_plan_judgement_discarded"
		or str(action_system.get_runtime_action_id(NPC_ID)) != "visit_location"
		or str(late_session_after.get("action_id", "")) == "work_dining_hall"
		or str(late_session_after.get("workstation_id", "")) == late_workstation_id
		or bool(late_session_after.get("dialogue_suspended_hold", false))
		or late_pending_after_response.has(NPC_ID)
	):
		_fail("Late stale judgement did not unlock the latest-hour plan cleanly: %s" % JSON.stringify({
			"judgement": late_judgement,
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
			"formal": late_formal_after,
			"pending": late_pending_after_response,
		}))
		return

	# Cancellation has no judgement stage. After a real active-dialogue hour crossing,
	# it must release the marker and replace the old workstation transaction directly.
	if not action_system.interrupt_npc_action(NPC_ID, "verify_cross_hour_cancel_setup"):
		_fail("Could not stop the late-judgement replacement before cancellation regression")
		return
	time_system.set_current_time(1, 13, 59, 50)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dining_hall"):
		_fail("Could not stage the cross-hour cancellation NPC")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_cross_hour_cancel_ready",
	})
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_cross_hour_plan(13, 14),
		false,
		"verify_cross_hour_cancel"
	):
		_fail("Could not install the cross-hour cancellation plan")
		return
	var cancel_old_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(cancel_old_execute.get("ok", false)):
		_fail("Could not start old-hour work for cancellation")
		return
	if not await _wait_for_active_action(action_system, NPC_ID, "work_dining_hall"):
		_fail("Cancellation old-hour work did not become active")
		return
	dialogue_result = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open the cross-hour cancellation dialogue")
		return
	activation_result = dialog_system.call("_activate_player_dialogue_draft", "verify_cross_hour_cancel")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate the cross-hour cancellation dialogue")
		return
	effect_result = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_cross_hour_cancel")
	if not bool(effect_result.get("ok", false)):
		_fail("Could not suspend old-hour work for cancellation")
		return
	var cancel_dialogue_id := str(dialog_system.get_dialogue_state().get("dialogue_id", ""))
	var cancel_request_count_before := bridge.judgement_requests.size()
	daily_plan_system.set_auto_execution_enabled(true)
	if not time_system.debug_advance_game_seconds(10.0):
		_fail("Could not cross the active-dialogue cancellation hour boundary")
		return
	await process_frame
	daily_plan_system.set_auto_execution_enabled(false)
	if (
		str(dialog_system.get_dialogue_state().get("dialogue_id", "")) != cancel_dialogue_id
		or not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
	):
		_fail("Hour change ended the dialogue or dispatched before cancellation")
		return
	var cancel_result: Dictionary = dialog_system.cancel_displayed_dialogue(cancel_dialogue_id)
	for _index in range(3):
		await process_frame
	var cancel_pending_after: Dictionary = daily_plan_system.get(
		"_deferred_current_revision_execution_by_npc"
	)
	var cancel_session_after: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	if (
		not bool(cancel_result.get("ok", false))
		or not bool(cancel_result.get("cancelled", false))
		or bridge.judgement_requests.size() != cancel_request_count_before
		or not dialog_system.get_dialogue_state().is_empty()
		or str(action_system.get_runtime_action_id(NPC_ID)) != "visit_location"
		or str(cancel_session_after.get("action_id", "")) == "work_dining_hall"
		or bool(cancel_session_after.get("dialogue_suspended_hold", false))
		or cancel_pending_after.has(NPC_ID)
	):
		_fail("Cross-hour cancellation did not immediately unlock the new plan: %s" % JSON.stringify({
			"cancel": cancel_result,
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
			"formal": npc_system.get_formal_workstation_action_snapshot(NPC_ID),
			"pending": cancel_pending_after,
		}))
		return

	# The same hourly barrier must survive the second-stage plan revision request.
	# A response that becomes stale while waiting still owns terminal cleanup for
	# this dialogue chain and must dispatch the latest-hour plan exactly once.
	if not action_system.interrupt_npc_action(NPC_ID, "verify_late_stage_two_setup"):
		_fail("Could not stop the cancellation replacement before stage-two regression")
		return
	time_system.set_current_time(1, 15, 59, 50)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dining_hall"):
		_fail("Could not stage the late stage-two NPC")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_late_stage_two_ready",
	})
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_cross_hour_plan(15, 16),
		false,
		"verify_late_stage_two"
	):
		_fail("Could not install the late stage-two cross-hour plan")
		return
	var stage_two_old_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(stage_two_old_execute.get("ok", false)):
		_fail("Could not start old-hour work for the stage-two case")
		return
	if not await _wait_for_active_action(action_system, NPC_ID, "work_dining_hall"):
		_fail("Stage-two old-hour work did not become active")
		return
	dialogue_result = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_result.get("ok", false)):
		_fail("Could not open the late stage-two player dialogue")
		return
	activation_result = dialog_system.call("_activate_player_dialogue_draft", "verify_late_stage_two")
	if not bool(activation_result.get("ok", false)):
		_fail("Could not activate the late stage-two player dialogue")
		return
	effect_result = dialog_system.call("_ensure_player_dialogue_effect_started", "verify_late_stage_two")
	if not bool(effect_result.get("ok", false)):
		_fail("Could not suspend old-hour work for the late stage-two case")
		return
	if not _apply_completed_turn(dialog_system, NPC_ID, "现在需要调整安排。"):
		return
	bridge.capture_revision_requests = true
	var stage_two_judgement_count_before := bridge.judgement_requests.size()
	var stage_two_end: Dictionary = dialog_system.end_dialogue("verify_late_stage_two")
	if not bool(stage_two_end.get("plan_judgement_queued", false)):
		_fail("Late stage-two dialogue did not queue judgement")
		return
	await process_frame
	if bridge.judgement_requests.size() != stage_two_judgement_count_before + 1:
		_fail("Late stage-two dialogue did not launch exactly one judgement request")
		return
	bridge.answer_needs_revision(bridge.judgement_requests.back(), 15)
	for _index in range(3):
		await process_frame
	if bridge.revision_requests.size() != 1:
		_fail("Dialogue judgement did not launch exactly one stage-two revision request")
		return
	var stage_two_request: Dictionary = bridge.revision_requests[0]
	daily_plan_system.set_auto_execution_enabled(true)
	if not time_system.debug_advance_game_seconds(10.0):
		_fail("Could not cross the hour while stage-two revision was pending")
		return
	await process_frame
	daily_plan_system.set_auto_execution_enabled(false)
	var stage_two_pending_before: Dictionary = daily_plan_system.get(
		"_deferred_current_revision_execution_by_npc"
	)
	if (
		not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
		or not bool(stage_two_pending_before.get(NPC_ID, {}).get("wait_for_dialogue_resolution", false))
		or not bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {}).get("dialogue_suspended_hold", false))
	):
		_fail("Current-hour dispatch was not held while stage-two revision remained pending")
		return
	bridge.answer_revision_failure(stage_two_request)
	for _index in range(3):
		await process_frame
	bridge.capture_revision_requests = false
	var stage_two_result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	var stage_two_pending_after: Dictionary = daily_plan_system.get(
		"_deferred_current_revision_execution_by_npc"
	)
	var stage_two_session_after: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	if (
		str(stage_two_result.get("status", "")) != "stale_revision_discarded"
		or str(action_system.get_runtime_action_id(NPC_ID)) != "visit_location"
		or str(stage_two_session_after.get("action_id", "")) == "work_dining_hall"
		or bool(stage_two_session_after.get("dialogue_suspended_hold", false))
		or stage_two_pending_after.has(NPC_ID)
	):
		_fail("Late stage-two terminal response did not unlock the latest-hour plan: %s" % JSON.stringify({
			"result": stage_two_result,
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
			"formal": npc_system.get_formal_workstation_action_snapshot(NPC_ID),
			"pending": stage_two_pending_after,
		}))
		return

	# A terminal reply from an older dialogue epoch must never delete or release a
	# marker owned by a newer conversation, even when both concern the same NPC.
	var current_dialogue_epoch := int(dialog_system.get_npc_dialogue_epoch(NPC_ID))
	var judgement_generations: Dictionary = daily_plan_system.get(
		"_dialogue_plan_judgement_generation_by_npc"
	)
	var current_judgement_generation := int(judgement_generations.get(NPC_ID, 0))
	daily_plan_system.prepare_dialogue_plan_resolution_group(
		[NPC_ID],
		"verify_newer_dialogue_marker",
		{NPC_ID: current_dialogue_epoch}
	)
	var newer_marker_before: Dictionary = (
		daily_plan_system.get("_deferred_current_revision_execution_by_npc").get(NPC_ID, {})
		as Dictionary
	).duplicate(true)
	var older_finish_result: Dictionary = daily_plan_system.call(
		"_finish_stale_dialogue_judgement_resolution",
		{
			"npc_id": NPC_ID,
			"dialogue_id": "verify_older_dialogue_marker",
			"dialogue_epoch": current_dialogue_epoch - 1,
			"judgement_generation": current_judgement_generation - 1,
			"request_day": 1,
			"request_hour": 15,
			"execute_current_plan_when_resolved": true,
		}
	)
	var newer_marker_after: Dictionary = (
		daily_plan_system.get("_deferred_current_revision_execution_by_npc").get(NPC_ID, {})
		as Dictionary
	).duplicate(true)
	if (
		str(older_finish_result.get("status", "")) != "stale_dialogue_resolution"
		or newer_marker_after != newer_marker_before
		or str(newer_marker_after.get("dialogue_id", "")) != "verify_newer_dialogue_marker"
		or not bool(newer_marker_after.get("wait_for_dialogue_resolution", false))
		or str(action_system.get_runtime_action_id(NPC_ID)) != "visit_location"
	):
		_fail("Older dialogue epoch disturbed the newer marker: %s" % JSON.stringify({
			"finish": older_finish_result,
			"before": newer_marker_before,
			"after": newer_marker_after,
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
		}))
		return
	daily_plan_system.release_deferred_current_plan_after_dialogue(
		NPC_ID,
		"verify_newer_dialogue_marker",
		current_dialogue_epoch
	)

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


func _make_eat_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "eat_at_dining_hall",
			"reason": "T1505 moving dialogue resume verification",
			"source": "verify_moving_dialogue"
		})
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


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return


func _get_npc_node(npc_id: String) -> Node:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return null
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id:
			return npc_node
	return null


func _wait_for_active_action(
	action_system: Node,
	npc_id: String,
	action_id: String,
	max_frames: int = 2400
) -> bool:
	for _frame in range(max_frames):
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if (
			str(runtime.get("phase", "")) == "active"
			and str(runtime.get("action_id", "")) == action_id
		):
			return true
		await physics_frame
	return false


func _wait_for_moving_position(
	npc_system: Node,
	action_system: Node,
	npc_id: String,
	action_id: String,
	max_frames: int = 1200
) -> Variant:
	var start_position: Variant = npc_system.get_npc_world_position(npc_id)
	for _frame in range(max_frames):
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var current_position: Variant = npc_system.get_npc_world_position(npc_id)
		if (
			str(runtime.get("phase", "")) == "pending"
			and str(runtime.get("action_id", "")) == action_id
			and str(state.get("current_action", "")).begins_with("moving_to_")
			and current_position is Vector3
			and start_position is Vector3
			and current_position.distance_to(start_position) > 0.2
		):
			return current_position
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
