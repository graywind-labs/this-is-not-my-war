extends SceneTree


class CapturingLLMBridge:
	extends Node

	signal plan_revision_judgement_async_response_received(result: Dictionary)
	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var judgement_requests: Array[Dictionary] = []
	var revision_requests: Array[Dictionary] = []
	var revision_launch_attempts: Array[Dictionary] = []
	var synchronous_revision_failures_remaining := 0

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_dialogue_plan_revision_judgement_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_options := options.duplicate(true)
		request_options["trigger_kind"] = "dialogue"
		return request_plan_revision_judgement_async(npc_id, request_options)

	func request_plan_revision_judgement_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "capture_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		revision_launch_attempts.append({
			"npc_id": npc_id,
			"options": options.duplicate(true),
			"forced_sync_failure": synchronous_revision_failures_remaining > 0
		})
		if synchronous_revision_failures_remaining > 0:
			synchronous_revision_failures_remaining -= 1
			return {
				"ok": false,
				"error_code": "forced_sync_launch_failure",
				"message": "Deterministic synchronous stage-two launch failure."
			}
		var request_id := "capture_revision_%d" % (revision_requests.size() + 1)
		revision_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_judgement(request: Dictionary, revision_hours: Array, needs_revision: bool = true) -> void:
		plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision_judgement": {
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": needs_revision,
				"revision_hours": revision_hours.duplicate(),
				"summary": "deterministic judgement",
				"debug_reason": "verification",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func answer_revision(request: Dictionary, revised_items: Array, immediate_action: Variant) -> void:
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": revised_items.duplicate(true),
				"immediate_action": immediate_action,
				"summary": "deterministic selected-hour revision",
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


const NPC_ID := "cook_01"
const CURRENT_HOUR := 8


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var original_llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var systems := root.get_node_or_null("Main/Systems")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	if [daily_plan_system, original_llm_bridge, systems, time_system, npc_system, action_system, dialog_system].has(null):
		_fail("Selected-hour revision verification nodes missing")
		return

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	daily_plan_system.set_auto_execution_enabled(false)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dining_hall"):
		_fail("Could not place cook in dining hall")
		return
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_selected_hours"):
		_fail("Could not install deterministic 24-hour plan")
		return

	# Stage one is deliberately lightweight: dialogue + original plan, without the heavy revise context.
	var judgement_payload: Dictionary = original_llm_bridge.build_dialogue_plan_revision_judgement_payload(NPC_ID, {
		"current_plan": daily_plan_system.get_npc_daily_plan(NPC_ID),
		"dialogue_kind": "player_npc",
		"dialogue_history": [
			{"speaker_id": "player", "speaker_name": "守备官", "text": "照旧还是调整？"},
			{"speaker_id": NPC_ID, "speaker_name": "厨子", "text": "我先判断一下。"}
		],
		"dialogue_end_reason": "verification_completed",
		"dialogue_context": {"dialogue_id": "slim_payload_verification"}
	})
	if (
		str(judgement_payload.get("npc_id", "")) != NPC_ID
		or str(judgement_payload.get("npc_name", "")).is_empty()
		or not judgement_payload.get("game_time", {}) is Dictionary
		or (judgement_payload.get("dialogue_history", []) as Array).size() != 2
		or (judgement_payload.get("current_plan", []) as Array).size() != 24
	):
		_fail("Dialogue judgement payload is missing its lightweight required fields: %s" % JSON.stringify(judgement_payload))
		return
	for forbidden_field in [
		"station_context",
		"npc",
		"allowed_actions",
		"current_building_states",
		"current_resource_states"
	]:
		if judgement_payload.has(forbidden_field):
			_fail("Dialogue judgement payload still contains heavy field '%s'" % forbidden_field)
			return

	# LLMBridge must carry only the explicit selected hours into the second-stage request.
	var payload: Dictionary = original_llm_bridge.build_npc_plan_revision_payload(NPC_ID, {
		"current_plan": daily_plan_system.get_npc_daily_plan(NPC_ID),
		"failed_plan_item": daily_plan_system.get_current_plan_item(NPC_ID),
		"failure_type": "dialogue_interrupted",
		"failure_summary": "verification",
		"revision_hours": [CURRENT_HOUR, 11]
	})
	if str(payload.get("revision_scope", "")) != "selected_hours" or payload.get("revision_hours", []) != [CURRENT_HOUR, 11]:
		_fail("LLMBridge did not preserve the exact selected-hour scope: %s" % JSON.stringify(payload))
		return
	for required_context_field in [
		"station_context",
		"npc",
		"allowed_actions",
		"current_building_states",
		"current_resource_states"
	]:
		if not payload.has(required_context_field):
			_fail("Second-stage revision lost existing context field '%s'" % required_context_field)
			return

	systems.remove_child(original_llm_bridge)
	original_llm_bridge.queue_free()
	await process_frame
	var bridge := CapturingLLMBridge.new()
	bridge.name = "LLMBridge"
	systems.add_child(bridge)
	bridge.plan_revision_judgement_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_judgement_async_response")
	)
	bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)

	# Empty revision_hours means no second call and resumes the exact interrupted action.
	var start_result: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(start_result.get("ok", false)) or str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Could not start baseline current-hour action: %s" % JSON.stringify(start_result))
		return
	if not action_system.interrupt_npc_action(NPC_ID, "verify_dialogue_no_change"):
		_fail("Could not interrupt baseline action for judgement")
		return
	var judgement_start := _request_judgement(daily_plan_system, "dialogue_no_change", "work_dining_hall")
	if str(judgement_start.get("status", "")) != "dialogue_plan_judgement_pending":
		_fail("No-change dialogue did not start judgement: %s" % JSON.stringify(judgement_start))
		return
	var no_change_request: Dictionary = bridge.judgement_requests.back()
	bridge.answer_judgement(no_change_request, [], false)
	if not bridge.revision_requests.is_empty():
		_fail("Empty judgement unexpectedly launched the second-stage revision")
		return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Empty judgement did not resume the interrupted current action")
		return
	var no_change_result: Dictionary = daily_plan_system.get_last_dialogue_plan_judgement_result()
	if str(no_change_result.get("status", "")) != "dialogue_plan_unchanged":
		_fail("Empty judgement result was not recorded as unchanged: %s" % JSON.stringify(no_change_result))
		return

	# Future-only revision resumes once after the dialogue, then applying the future item must not replay current work.
	if not action_system.interrupt_npc_action(NPC_ID, "verify_dialogue_future_only"):
		_fail("Could not interrupt work for future-only judgement")
		return
	judgement_start = _request_judgement(daily_plan_system, "dialogue_future_only", "work_dining_hall")
	if not bool(judgement_start.get("ok", false)):
		_fail("Future-only judgement did not start")
		return
	var future_judgement_request: Dictionary = bridge.judgement_requests.back()
	bridge.answer_judgement(future_judgement_request, [10], true)
	if bridge.revision_requests.size() != 1:
		_fail("Future-only judgement did not launch exactly one revision")
		return
	var future_revision_request: Dictionary = bridge.revision_requests.back()
	if not _assert_selected_hours(future_revision_request, [10], "future-only dialogue"):
		return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Future-only judgement did not resume the interrupted current action")
		return
	action_system.call("_on_logical_time_tick", 5.0, 1.0)
	var elapsed_before_revision := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -1.0))
	bridge.answer_revision(future_revision_request, [_schema_item(10, "idle")], null)
	var elapsed_after_revision := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -2.0))
	if not is_equal_approx(elapsed_after_revision, elapsed_before_revision):
		_fail("Future-only revision replayed/reset the current action progress")
		return
	var after_future: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	if str(after_future[10].get("action_id", "")) != "idle" or str(after_future[CURRENT_HOUR].get("action_id", "")) != "work_dining_hall":
		_fail("Future-only revision modified the wrong hours")
		return
	if not action_system.interrupt_npc_action(NPC_ID, "verify_future_dispatch_guard"):
		_fail("Could not interrupt current work after future-only merge")
		return
	var guarded_repeat: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if str(guarded_repeat.get("status", "")) != "already_executed_this_plan_phase":
		_fail("Future-only merge lost the current-hour execution signature: %s" % JSON.stringify(guarded_repeat))
		return

	# A current+future decision must merge exactly those hours and execute the selected current item.
	var restart: Dictionary = daily_plan_system.resume_current_plan_after_dialogue(NPC_ID, "work_dining_hall")
	if not bool(restart.get("ok", false)):
		_fail("Could not restart work before current+future judgement: %s" % JSON.stringify(restart))
		return
	if not action_system.interrupt_npc_action(NPC_ID, "verify_dialogue_current_future"):
		_fail("Could not interrupt work for current+future judgement")
		return
	var before_current_future: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	judgement_start = _request_judgement(daily_plan_system, "dialogue_current_future", "work_dining_hall")
	if not bool(judgement_start.get("ok", false)):
		_fail("Current+future judgement did not start")
		return
	var current_future_judgement: Dictionary = bridge.judgement_requests.back()
	bridge.answer_judgement(current_future_judgement, [CURRENT_HOUR, 11], true)
	if bridge.revision_requests.size() != 2:
		_fail("Current+future judgement did not launch exactly one additional revision")
		return
	var current_future_request: Dictionary = bridge.revision_requests.back()
	if not _assert_selected_hours(current_future_request, [CURRENT_HOUR, 11], "current+future dialogue"):
		return
	var current_item := _schema_item(CURRENT_HOUR, "idle")
	bridge.answer_revision(
		current_future_request,
		[current_item, _schema_item(11, "idle")],
		current_item.duplicate(true)
	)
	var after_current_future: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	for hour in range(24):
		if hour in [CURRENT_HOUR, 11]:
			if str(after_current_future[hour].get("action_id", "")) != "idle":
				_fail("Selected hour %d was not merged" % hour)
				return
		elif str(after_current_future[hour].get("action_id", "")) != str(before_current_future[hour].get("action_id", "")):
			_fail("Unselected hour %d was changed by current+future revision" % hour)
			return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "":
		_fail("Current-hour idle revision should leave no replayed work action")
		return

	# An illegal/past hour is rejected before the second call.
	var revision_count_before_invalid := bridge.revision_requests.size()
	judgement_start = _request_judgement(daily_plan_system, "dialogue_invalid_hours", "")
	if not bool(judgement_start.get("ok", false)):
		_fail("Invalid-hour judgement request did not start")
		return
	bridge.answer_judgement(bridge.judgement_requests.back(), [CURRENT_HOUR - 1], true)
	if bridge.revision_requests.size() != revision_count_before_invalid:
		_fail("Illegal judgement hours reached the second-stage revision")
		return
	var invalid_result: Dictionary = daily_plan_system.get_last_dialogue_plan_judgement_result()
	if str(invalid_result.get("status", "")) != "invalid_dialogue_plan_judgement":
		_fail("Illegal judgement hours were not rejected: %s" % JSON.stringify(invalid_result))
		return

	# A finished current phase has no runtime to adopt. Future-only merge must still carry
	# its execution signature across the plan-version bump and must not replay it.
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_completed_phase"):
		_fail("Could not reset the plan for completed-phase verification")
		return
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle", "last_action_result": "verify_completed_phase_ready"})
	var completed_phase_start: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(completed_phase_start.get("ok", false)):
		_fail("Could not start the action used by completed-phase verification")
		return
	var completed_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	action_system.call(
		"_on_logical_time_tick",
		float(completed_runtime.get("duration_seconds", 3600.0)) + 1.0,
		1.0
	)
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("Current plan action did not complete before future-only merge")
		return
	var execution_signatures: Dictionary = daily_plan_system.get("_plan_execution_signature_by_npc")
	if str(execution_signatures.get(NPC_ID, "")).is_empty():
		_fail("Completed current phase did not retain its dispatched execution signature")
		return
	var completed_revision_count := bridge.revision_requests.size()
	judgement_start = _request_judgement(daily_plan_system, "dialogue_after_completed_phase", "")
	if not bool(judgement_start.get("ok", false)):
		_fail("Completed-phase future-only judgement did not start")
		return
	bridge.answer_judgement(bridge.judgement_requests.back(), [12], true)
	if bridge.revision_requests.size() != completed_revision_count + 1:
		_fail("Completed-phase future-only judgement did not launch one revision")
		return
	var completed_phase_revision: Dictionary = bridge.revision_requests.back()
	bridge.answer_revision(completed_phase_revision, [_schema_item(12, "idle")], null)
	var completed_phase_repeat: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if str(completed_phase_repeat.get("status", "")) != "already_executed_this_plan_phase":
		_fail("Future-only merge replayed a completed current phase: %s" % JSON.stringify(completed_phase_repeat))
		return
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("Future-only merge recreated runtime state for a completed current phase")
		return

	# Consecutive dialogues share the interrupted-action token through the newer epoch.
	# D1's late reply must be stale; only D2's no-change reply may resume the action.
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_consecutive_dialogues"):
		_fail("Could not reset the plan for consecutive-dialogue verification")
		return
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle", "last_action_result": "verify_epoch_ready"})
	var epoch_action_start: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(epoch_action_start.get("ok", false)):
		_fail("Could not start the action interrupted by consecutive dialogues")
		return
	var judgement_count_before_epoch := bridge.judgement_requests.size()
	var d1_result := _complete_player_dialogue(dialog_system, NPC_ID, "epoch_d1", "第一轮先谈到这里。")
	if not bool(d1_result.get("ok", false)) or not bool(d1_result.get("interrupted_action", false)):
		_fail("D1 did not interrupt the running plan action: %s" % JSON.stringify(d1_result))
		return
	await process_frame
	if bridge.judgement_requests.size() != judgement_count_before_epoch + 1:
		_fail("D1 did not leave one judgement token in flight")
		return
	var d1_request: Dictionary = bridge.judgement_requests.back()
	var d1_epoch := int(d1_result.get("dialogue_epoch", -1))

	var d2_result := _complete_player_dialogue(dialog_system, NPC_ID, "epoch_d2", "紧接着再确认一次。")
	if not bool(d2_result.get("ok", false)) or bool(d2_result.get("interrupted_action", true)):
		_fail("D2 should inherit D1's token without inventing a second runtime interruption: %s" % JSON.stringify(d2_result))
		return
	await process_frame
	if bridge.judgement_requests.size() != judgement_count_before_epoch + 2:
		_fail("D2 did not start its own newer-epoch judgement")
		return
	var d2_request: Dictionary = bridge.judgement_requests.back()
	var d2_epoch := int(d2_result.get("dialogue_epoch", -1))
	if d1_epoch < 0 or d2_epoch != d1_epoch + 1:
		_fail("Consecutive dialogues did not advance exactly one NPC dialogue epoch")
		return
	var saved_resume_contexts: Dictionary = daily_plan_system.get("_dialogue_resume_context_by_npc")
	var inherited_token: Dictionary = saved_resume_contexts.get(NPC_ID, {})
	if (
		int(inherited_token.get("dialogue_epoch", -1)) != d2_epoch
		or str(inherited_token.get("dialogue_id", "")) != str(d2_result.get("dialogue_id", ""))
		or str(inherited_token.get("interrupted_action_id", "")) != "work_dining_hall"
	):
		_fail("D2 did not inherit D1's interrupted-action token: %s" % JSON.stringify(inherited_token))
		return

	# Resolve D2 first while D1's obsolete HTTP request is deliberately still in the
	# registry. The stale generation must not block D2's ready marker.
	bridge.answer_judgement(d2_request, [], false)
	for _index in range(2):
		await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail(
			"D1's stale in-flight judgement blocked D2's ready marker: pending=%s"
			% str(daily_plan_system.get("_async_dialogue_plan_judgement_requests"))
		)
		return
	action_system.call("_on_logical_time_tick", 5.0, 1.0)
	var d2_elapsed_once := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -1.0))
	bridge.answer_judgement(d1_request, [], false)
	var stale_d1_result: Dictionary = daily_plan_system.get_last_dialogue_plan_judgement_result()
	var d2_elapsed_after_stale_d1 := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -2.0))
	if (
		str(stale_d1_result.get("status", "")) != "stale_dialogue_plan_judgement_discarded"
		or not is_equal_approx(d2_elapsed_after_stale_d1, d2_elapsed_once)
	):
		_fail("D1's late judgement was not stale or disturbed D2's resumed action: %s" % JSON.stringify(stale_d1_result))
		return
	bridge.answer_judgement(d2_request, [], false)
	var d2_elapsed_after_duplicate := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -2.0))
	if not is_equal_approx(d2_elapsed_after_duplicate, d2_elapsed_once):
		_fail("A duplicate D2 response resumed/reset the action more than once")
		return

	# Same-frame replacement is the tighter race: D1 has already interrupted work,
	# then activating D2 ends D1 and advances the token before either judgement can
	# resolve. Only D2 may consume that inherited token, exactly once.
	if not action_system.interrupt_npc_action(NPC_ID, "verify_same_frame_dialogue_reset"):
		_fail("Could not stop the previous resumed action before the same-frame race")
		return
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_same_frame_dialogues"):
		_fail("Could not reset the plan for same-frame dialogue replacement")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_same_frame_epoch_ready"
	})
	var same_frame_action_start: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if (
		not bool(same_frame_action_start.get("ok", false))
		or str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall"
	):
		_fail("Could not start the action for same-frame dialogue replacement")
		return
	var same_frame_judgement_start := bridge.judgement_requests.size()
	var same_d1_start: Dictionary = dialog_system.start_player_dialogue(NPC_ID)
	var same_d1_activation: Dictionary = dialog_system.call(
		"_activate_player_dialogue_draft",
		"same_frame_d1"
	)
	var same_d1_effect: Dictionary = dialog_system.call(
		"_ensure_player_dialogue_effect_started",
		"same_frame_d1"
	)
	if (
		not bool(same_d1_start.get("ok", false))
		or not bool(same_d1_activation.get("ok", false))
		or not bool(same_d1_effect.get("interrupted_action", false))
		or str(same_d1_effect.get("interrupted_action_id", "")) != "work_dining_hall"
	):
		_fail("Same-frame D1 did not interrupt the running work action: %s" % JSON.stringify(same_d1_effect))
		return
	var same_d1_apply := _apply_player_dialogue_turn(
		dialog_system,
		NPC_ID,
		"D1 已经打断工作，马上换成下一轮。"
	)
	if not bool(same_d1_apply.get("ok", false)):
		_fail("Could not apply the completed D1 turn in the same-frame race")
		return
	var same_d1_state: Dictionary = dialog_system.get_dialogue_state()
	var same_d1_id := str(same_d1_state.get("dialogue_id", ""))
	var same_d1_epoch := int((same_d1_state.get("dialogue_epoch_by_npc", {}) as Dictionary).get(NPC_ID, -1))

	# Intentionally no await/process frame between D1's completed turn and D2's
	# activation: activating this draft synchronously ends and queues D1.
	var same_d2_start: Dictionary = dialog_system.start_player_dialogue(NPC_ID)
	var same_d2_activation: Dictionary = dialog_system.call(
		"_activate_player_dialogue_draft",
		"same_frame_d2_replaces_d1"
	)
	var same_d2_effect: Dictionary = dialog_system.call(
		"_ensure_player_dialogue_effect_started",
		"same_frame_d2"
	)
	if (
		not bool(same_d2_start.get("ok", false))
		or not bool(same_d2_activation.get("ok", false))
		or not bool(same_d2_effect.get("ok", false))
		or bool(same_d2_effect.get("interrupted_action", true))
	):
		_fail("Same-frame D2 did not replace D1 while inheriting its interruption: %s" % JSON.stringify(same_d2_effect))
		return
	if bridge.judgement_requests.size() != same_frame_judgement_start + 1:
		_fail("Activating same-frame D2 did not synchronously register D1's judgement")
		return
	var same_d2_apply := _apply_player_dialogue_turn(
		dialog_system,
		NPC_ID,
		"D2 保留原计划。"
	)
	if not bool(same_d2_apply.get("ok", false)):
		_fail("Could not apply the completed D2 turn in the same-frame race")
		return
	var same_d2_state: Dictionary = dialog_system.get_dialogue_state()
	var same_d2_id := str(same_d2_state.get("dialogue_id", ""))
	var same_d2_epoch := int((same_d2_state.get("dialogue_epoch_by_npc", {}) as Dictionary).get(NPC_ID, -1))
	if same_d1_epoch < 0 or same_d2_epoch != same_d1_epoch + 1:
		_fail("Same-frame replacement did not advance exactly one dialogue epoch")
		return
	var same_d2_end: Dictionary = dialog_system.end_dialogue("same_frame_d2")
	if not bool(same_d2_end.get("plan_judgement_queued", false)):
		_fail("Same-frame D2 did not queue its no-change judgement")
		return
	if bridge.judgement_requests.size() != same_frame_judgement_start + 2:
		_fail("Same-frame replacement did not leave exactly D1 and D2 judgements")
		return
	var same_d1_request := _find_judgement_request_by_dialogue_id(
		bridge.judgement_requests,
		same_frame_judgement_start,
		same_d1_id
	)
	var same_d2_request := _find_judgement_request_by_dialogue_id(
		bridge.judgement_requests,
		same_frame_judgement_start,
		same_d2_id
	)
	if same_d1_request.is_empty() or same_d2_request.is_empty():
		_fail("Could not match same-frame judgement requests to D1/D2 dialogue ids")
		return
	var same_frame_tokens: Dictionary = daily_plan_system.get("_dialogue_resume_context_by_npc")
	var same_d2_token: Dictionary = same_frame_tokens.get(NPC_ID, {})
	if (
		str(same_d2_token.get("dialogue_id", "")) != same_d2_id
		or int(same_d2_token.get("dialogue_epoch", -1)) != same_d2_epoch
		or str(same_d2_token.get("interrupted_action_id", "")) != "work_dining_hall"
	):
		_fail("Same-frame D2 did not inherit D1's interrupted work token: %s" % JSON.stringify(same_d2_token))
		return

	bridge.answer_judgement(same_d1_request, [], false)
	var same_d1_stale: Dictionary = daily_plan_system.get_last_dialogue_plan_judgement_result()
	if (
		str(same_d1_stale.get("status", "")) != "stale_dialogue_plan_judgement_discarded"
		or not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
	):
		_fail("Same-frame D1 reply was not stale or resumed work early: %s" % JSON.stringify(same_d1_stale))
		return
	bridge.answer_judgement(same_d2_request, [], false)
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Same-frame D2 no-change did not resume the original work action")
		return
	action_system.call("_on_logical_time_tick", 5.0, 1.0)
	var same_d2_elapsed_once := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -1.0))
	bridge.answer_judgement(same_d2_request, [], false)
	var same_d2_elapsed_duplicate := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -2.0))
	if not is_equal_approx(same_d2_elapsed_duplicate, same_d2_elapsed_once):
		_fail("Same-frame D2 duplicate response resumed the original work more than once")
		return

	# Queue ordering contract: A normal active revision owns the lock, a dialogue
	# stage-two revision waits behind it, and a later normal failure must wait behind
	# that dialogue barrier. Even if the dialogue stage-two launch fails synchronously
	# on every retry, the normal followup must still drain and launch.
	if not action_system.interrupt_npc_action(NPC_ID, "verify_sync_fail_followup_reset"):
		_fail("Could not stop work before the synchronous dialogue-stage-two failure chain")
		return
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_sync_fail_followup"):
		_fail("Could not reset the plan for synchronous stage-two failure followup")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_sync_fail_followup_ready"
	})
	var sync_chain_revision_start := bridge.revision_requests.size()
	var sync_active_result: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"resource_insufficient",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"sync_chain_active",
		{},
		{"revision_hours": [CURRENT_HOUR + 1], "skip_plan_revision_judgement": true}
	)
	if str(sync_active_result.get("status", "")) != "pending_async":
		_fail("Could not launch the active revision before the sync-failure chain")
		return
	var sync_active_request: Dictionary = bridge.revision_requests.back()
	var sync_dialogue_context := _make_dialogue_barrier_context(
		daily_plan_system,
		dialog_system,
		"sync_fail_dialogue_stage_two"
	)
	daily_plan_system.call(
		"_defer_current_plan_until_dialogue_resolved",
		NPC_ID,
		sync_dialogue_context
	)
	var sync_dialogue_queued: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"dialogue_plan_revision",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"sync_chain_dialogue_stage_two",
		{},
		{
			"revision_hours": [CURRENT_HOUR + 2],
			"skip_plan_revision_judgement": true,
			"dialogue_resume_context": sync_dialogue_context,
			"dialogue_epoch": int(sync_dialogue_context.get("dialogue_epoch", -1))
		}
	)
	if str(sync_dialogue_queued.get("status", "")) != "reevaluation_queued":
		_fail("Dialogue stage-two revision did not queue behind the active revision: %s" % JSON.stringify(sync_dialogue_queued))
		return
	var sync_followup_queued: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"work_failed_no_resources",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"sync_chain_normal_followup",
		{},
		{"skip_plan_revision_judgement": true}
	)
	if str(sync_followup_queued.get("status", "")) != "reevaluation_deferred_behind_dialogue_revision":
		_fail("Normal followup did not remain behind the queued dialogue barrier: %s" % JSON.stringify(sync_followup_queued))
		return
	bridge.synchronous_revision_failures_remaining = 3
	bridge.answer_revision(
		sync_active_request,
		[_schema_item(CURRENT_HOUR + 1, "idle")],
		null
	)
	for _index in range(8):
		await process_frame
	if _count_revision_launch_attempts_by_summary(
		bridge.revision_launch_attempts,
		"sync_chain_dialogue_stage_two"
	) != 3:
		_fail("Dialogue stage-two did not exhaust exactly three synchronous launch attempts")
		return
	var sync_followup_request := _find_revision_request_by_failure_summary(
		bridge.revision_requests,
		sync_chain_revision_start,
		"sync_chain_normal_followup"
	)
	if sync_followup_request.is_empty():
		_fail(
			"Normal followup did not drain after dialogue stage-two sync failure; queued=%s followups=%s reevaluating=%s"
			% [
				str(daily_plan_system.get("_queued_reevaluation_by_npc")),
				str(daily_plan_system.get("_queued_followup_reevaluation_by_npc")),
				str(daily_plan_system.get("_reevaluating_npcs"))
			]
		)
		return
	var sync_followup_item := _schema_item(CURRENT_HOUR, "work_dining_hall")
	bridge.answer_revision(
		sync_followup_request,
		[sync_followup_item],
		sync_followup_item.duplicate(true)
	)
	for _index in range(3):
		await process_frame

	# The successful variant must also rebase the normal followup. The queued
	# dialogue changes only a future hour, but applying it still bumps plan_version;
	# because the failed current action is unchanged, the followup remains valid.
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		action_system.interrupt_npc_action(NPC_ID, "verify_future_rebase_followup_reset")
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_future_rebase_followup"):
		_fail("Could not reset the plan for future-only dialogue followup rebase")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_future_rebase_followup_ready"
	})
	var future_chain_revision_start := bridge.revision_requests.size()
	var future_active_result: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"resource_insufficient",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"future_chain_active",
		{},
		{"revision_hours": [CURRENT_HOUR + 1], "skip_plan_revision_judgement": true}
	)
	if str(future_active_result.get("status", "")) != "pending_async":
		_fail("Could not launch the active revision before the future-only chain")
		return
	var future_active_request: Dictionary = bridge.revision_requests.back()
	var future_dialogue_context := _make_dialogue_barrier_context(
		daily_plan_system,
		dialog_system,
		"future_only_dialogue_stage_two"
	)
	daily_plan_system.call(
		"_defer_current_plan_until_dialogue_resolved",
		NPC_ID,
		future_dialogue_context
	)
	var future_dialogue_queued: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"dialogue_plan_revision",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"future_chain_dialogue_stage_two",
		{},
		{
			"revision_hours": [CURRENT_HOUR + 2],
			"skip_plan_revision_judgement": true,
			"dialogue_resume_context": future_dialogue_context,
			"dialogue_epoch": int(future_dialogue_context.get("dialogue_epoch", -1))
		}
	)
	if str(future_dialogue_queued.get("status", "")) != "reevaluation_queued":
		_fail("Future-only dialogue revision did not queue behind the active revision")
		return
	var future_followup_queued: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"work_failed_no_resources",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"future_chain_current_failure_followup",
		{},
		{"skip_plan_revision_judgement": true}
	)
	if str(future_followup_queued.get("status", "")) != "reevaluation_deferred_behind_dialogue_revision":
		_fail("Current-action followup did not queue behind the future-only dialogue revision")
		return
	bridge.answer_revision(
		future_active_request,
		[_schema_item(CURRENT_HOUR + 1, "idle")],
		null
	)
	for _index in range(4):
		await process_frame
	var future_dialogue_request := _find_revision_request_by_failure_summary(
		bridge.revision_requests,
		future_chain_revision_start,
		"future_chain_dialogue_stage_two"
	)
	if future_dialogue_request.is_empty():
		_fail("Queued future-only dialogue stage-two did not launch after the active revision")
		return
	bridge.answer_revision(
		future_dialogue_request,
		[_schema_item(CURRENT_HOUR + 2, "idle")],
		null
	)
	for _index in range(5):
		await process_frame
	var future_followup_request := _find_revision_request_by_failure_summary(
		bridge.revision_requests,
		future_chain_revision_start,
		"future_chain_current_failure_followup"
	)
	if future_followup_request.is_empty():
		_fail(
			"Same-action current failure followup became stale after the future-only version bump; last=%s"
			% JSON.stringify(daily_plan_system.get_last_reevaluation_result())
		)
		return
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("The ready marker replayed the failed current action before its queued followup reached a terminal response")
		return
	var blocked_followup_markers: Dictionary = daily_plan_system.get("_deferred_current_revision_execution_by_npc")
	if (
		not blocked_followup_markers.has(NPC_ID)
		or not bool(daily_plan_system.call("_has_pending_dialogue_plan_chain", NPC_ID))
	):
		_fail("Queued followup did not retain and block the dialogue ready marker")
		return
	var rebased_followup_options: Dictionary = future_followup_request.get("options", {})
	var rebased_plan: Array = rebased_followup_options.get("current_plan", [])
	if (
		rebased_plan.size() != 24
		or str((rebased_plan[CURRENT_HOUR] as Dictionary).get("action_id", "")) != "work_dining_hall"
		or str((rebased_plan[CURRENT_HOUR + 1] as Dictionary).get("action_id", "")) != "idle"
		or str((rebased_plan[CURRENT_HOUR + 2] as Dictionary).get("action_id", "")) != "idle"
	):
		_fail("Current-failure followup did not rebase onto both newer future-only revisions")
		return
	var future_followup_pending: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if str(future_followup_pending.get("status", "")) != "pending_async":
		_fail("Rebased current-failure followup was reported stale: %s" % JSON.stringify(future_followup_pending))
		return
	var future_followup_item := _schema_item(CURRENT_HOUR, "work_dining_hall")
	bridge.answer_revision(
		future_followup_request,
		[future_followup_item],
		future_followup_item.duplicate(true)
	)
	for _index in range(3):
		await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Queued followup terminal response did not release the current plan action")
		return
	var released_followup_markers: Dictionary = daily_plan_system.get("_deferred_current_revision_execution_by_npc")
	if released_followup_markers.has(NPC_ID):
		_fail("Queued followup terminal response left its ready marker unconsumed")
		return

	# A current-hour revision received under combat authority applies the plan now but
	# executes it exactly once as soon as the NPC returns to work mode.
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_work_plan(), false, "verify_deferred_behavior_revision"):
		_fail("Could not reset the plan for behavior-mode deferred execution")
		return
	var avoid_result: Dictionary = npc_system.set_npc_behavior_mode(
		NPC_ID,
		"avoid_combat",
		"verify_deferred_behavior_revision",
		{"interrupt": true}
	)
	if not bool(avoid_result.get("ok", false)):
		_fail("Could not enter avoid-combat mode for deferred revision verification")
		return
	var deferred_request_result: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"resource_insufficient",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"verification deferred current-hour revision",
		{},
		{"skip_plan_revision_judgement": true}
	)
	if str(deferred_request_result.get("status", "")) != "pending_async":
		_fail("Current-hour revision did not launch under avoid-combat mode")
		return
	var deferred_revision_request: Dictionary = bridge.revision_requests.back()
	var deferred_current_item := _schema_item(CURRENT_HOUR, "work_dining_hall")
	bridge.answer_revision(
		deferred_revision_request,
		[deferred_current_item],
		deferred_current_item.duplicate(true)
	)
	var deferred_apply_result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if (
		str(deferred_apply_result.get("status", "")) != "llm_revision_applied_deferred"
		or not bool(deferred_apply_result.get("plan_applied", false))
		or str(action_system.get_runtime_action_id(NPC_ID)) == "work_dining_hall"
	):
		_fail("Avoid-combat current-hour revision was not applied-and-deferred: %s" % JSON.stringify(deferred_apply_result))
		return
	var deferred_markers: Dictionary = daily_plan_system.get("_deferred_current_revision_execution_by_npc")
	if not deferred_markers.has(NPC_ID):
		_fail("Deferred current-hour revision did not retain its wake-up marker")
		return

	daily_plan_system.set_auto_execution_enabled(true)
	var work_mode_result: Dictionary = npc_system.set_npc_behavior_mode(
		NPC_ID,
		"work",
		"verify_deferred_behavior_resume",
		{"interrupt": false, "state_changes": {"current_action": "idle"}}
	)
	if not bool(work_mode_result.get("ok", false)):
		_fail("Could not return NPC to work mode after deferred revision")
		return
	for _index in range(3):
		await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_dining_hall":
		_fail("Deferred current-hour revision did not execute immediately on return to work")
		return
	deferred_markers = daily_plan_system.get("_deferred_current_revision_execution_by_npc")
	if deferred_markers.has(NPC_ID):
		_fail("Deferred current-hour execution marker was not consumed")
		return
	action_system.call("_on_logical_time_tick", 5.0, 1.0)
	var deferred_elapsed_once := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -1.0))
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_no_duplicate_deferred_execution", {"interrupt": false})
	await process_frame
	var deferred_elapsed_after_repeat := float(action_system.get_runtime_action_snapshot(NPC_ID).get("elapsed_seconds", -2.0))
	if deferred_elapsed_after_repeat + 0.001 < deferred_elapsed_once:
		_fail("Returning to work a second time replayed the deferred current-hour action")
		return
	daily_plan_system.set_auto_execution_enabled(false)

	# Non-dialogue failures remain one-stage and default to the current hour only.
	var direct_result: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"resource_insufficient",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"verification action failure",
		{},
		{"skip_plan_revision_judgement": true}
	)
	if str(direct_result.get("status", "")) != "pending_async":
		_fail("Direct non-dialogue reevaluation did not launch: %s" % JSON.stringify(direct_result))
		return
	if not _assert_selected_hours(bridge.revision_requests.back(), [CURRENT_HOUR], "non-dialogue failure"):
		return

	print("T0049 dialogue judgement and selected-hour revision contract verification passed.")
	quit(0)


func _complete_player_dialogue(
	dialog_system: Node,
	npc_id: String,
	label: String,
	player_text: String
) -> Dictionary:
	var start_result: Dictionary = dialog_system.start_player_dialogue(npc_id)
	if not bool(start_result.get("ok", false)):
		return {"ok": false, "stage": "start", "result": start_result}
	var activation_result: Dictionary = dialog_system.call(
		"_activate_player_dialogue_draft",
		label
	)
	if not bool(activation_result.get("ok", false)):
		return {"ok": false, "stage": "activate", "result": activation_result}
	var effect_result: Dictionary = dialog_system.call(
		"_ensure_player_dialogue_effect_started",
		label
	)
	if not bool(effect_result.get("ok", false)):
		return {"ok": false, "stage": "effect", "result": effect_result}
	var apply_result: Dictionary = dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"ok": true,
			"replyer_id": npc_id,
			"reply_text": "我听见了，先保留原计划。",
			"response_kind": "reply_to_player",
			"invitation_result": "not_applicable",
			"intent": "continue_talk",
			"emotion": "neutral",
			"recruitment_result": "none",
			"wartime_reaction": "none",
			"should_end_dialogue": false
		}
	}, {
		"kind": "player_message",
		"clean_text": player_text,
		"next_round": 1,
		"effective_recruitment_request": false,
		"dialogue_kind": "player_npc"
	})
	if not bool(apply_result.get("ok", false)):
		return {"ok": false, "stage": "apply", "result": apply_result}
	var active_state: Dictionary = dialog_system.get_dialogue_state()
	var dialogue_epochs: Dictionary = active_state.get("dialogue_epoch_by_npc", {})
	var dialogue_id := str(active_state.get("dialogue_id", ""))
	var end_result: Dictionary = dialog_system.end_dialogue(label)
	return {
		"ok": bool(end_result.get("ok", false)),
		"dialogue_id": dialogue_id,
		"dialogue_epoch": int(dialogue_epochs.get(npc_id, -1)),
		"interrupted_action": bool(effect_result.get("interrupted_action", false)),
		"interrupted_action_id": str(effect_result.get("interrupted_action_id", "")),
		"end_result": end_result
	}


func _request_judgement(daily_plan_system: Node, dialogue_id: String, interrupted_action_id: String) -> Dictionary:
	return daily_plan_system.request_dialogue_plan_revision_judgement(NPC_ID, {
		"dialogue_id": dialogue_id,
		"dialogue_kind": "player_npc",
		"dialogue_end_reason": "verification_completed",
		"dialogue_history": [
			{"speaker_id": "player", "speaker_name": "守备官", "text": "我们刚才谈的事怎么办？"},
			{"speaker_id": NPC_ID, "speaker_name": "厨子", "text": "我会按情况决定是否调整。"}
		],
		"participant_npc_ids": [NPC_ID],
		"interrupted_action_id": interrupted_action_id
	})


func _apply_player_dialogue_turn(
	dialog_system: Node,
	npc_id: String,
	player_text: String
) -> Dictionary:
	return dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"ok": true,
			"replyer_id": npc_id,
			"reply_text": "我听见了，先保留原计划。",
			"response_kind": "reply_to_player",
			"invitation_result": "not_applicable",
			"intent": "continue_talk",
			"emotion": "neutral",
			"recruitment_result": "none",
			"wartime_reaction": "none",
			"should_end_dialogue": false
		}
	}, {
		"kind": "player_message",
		"clean_text": player_text,
		"next_round": 1,
		"effective_recruitment_request": false,
		"dialogue_kind": "player_npc"
	})


func _find_judgement_request_by_dialogue_id(
	requests: Array[Dictionary],
	start_index: int,
	dialogue_id: String
) -> Dictionary:
	for index in range(start_index, requests.size()):
		var request: Dictionary = requests[index]
		var options: Dictionary = request.get("options", {})
		var dialogue_context: Dictionary = options.get("dialogue_context", {})
		if str(dialogue_context.get("dialogue_id", "")) == dialogue_id:
			return request
	return {}


func _make_dialogue_barrier_context(
	daily_plan_system: Node,
	dialog_system: Node,
	dialogue_id: String
) -> Dictionary:
	return {
		"npc_id": NPC_ID,
		"dialogue_id": dialogue_id,
		"dialogue_kind": "player_npc",
		"dialogue_end_reason": "verification_completed",
		"dialogue_epoch": int(dialog_system.get_npc_dialogue_epoch(NPC_ID)),
		"request_day": 1,
		"request_hour": CURRENT_HOUR,
		"plan_version": int(daily_plan_system.call("_get_plan_version", NPC_ID)),
		"execute_current_plan_when_resolved": true,
		"interrupted_action_id": ""
	}


func _find_revision_request_by_failure_summary(
	requests: Array[Dictionary],
	start_index: int,
	failure_summary: String
) -> Dictionary:
	for index in range(start_index, requests.size()):
		var request: Dictionary = requests[index]
		var options: Dictionary = request.get("options", {})
		if str(options.get("failure_summary", "")) == failure_summary:
			return request
	return {}


func _count_revision_launch_attempts_by_summary(
	attempts: Array[Dictionary],
	failure_summary: String
) -> int:
	var count := 0
	for attempt in attempts:
		var options: Dictionary = attempt.get("options", {})
		if str(options.get("failure_summary", "")) == failure_summary:
			count += 1
	return count


func _assert_selected_hours(request: Dictionary, expected_hours: Array, trigger_name: String) -> bool:
	var options: Dictionary = request.get("options", {})
	if str(options.get("revision_scope", "")) != "selected_hours" or options.get("revision_hours", []) != expected_hours:
		_fail("%s did not preserve exact selected hours: %s" % [trigger_name, JSON.stringify(options)])
		return false
	return true


func _make_work_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "work_dining_hall",
			"reason": "T0049 selected-hour verification",
			"source": "verify_selected_hours"
		})
	return plan


func _schema_item(hour: int, action_id: String) -> Dictionary:
	return {
		"hour": hour,
		"action_kind": "idle" if action_id == "idle" else "work",
		"action_id": action_id,
		"location_id": null,
		"target_id": null,
		"priority": 50,
		"reason": "T0049 deterministic revision",
		"dialogue_goal": ""
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
