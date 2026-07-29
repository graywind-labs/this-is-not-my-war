extends SceneTree


class CapturingLLMBridge:
	extends Node

	signal plan_revision_async_response_received(result: Dictionary)

	var revision_requests: Array[Dictionary] = []

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_npc_plan_revision_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "completion_revision_%d" % (revision_requests.size() + 1)
		revision_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true),
		})
		return {
			"ok": true,
			"pending": true,
			"request_id": request_id,
		}

	func answer_revision(
		request: Dictionary,
		action_id: String,
		action_kind: String,
		location_id: Variant
	) -> void:
		var revision_hours: Array = (
			(request.get("options", {}) as Dictionary).get(
				"revision_hours",
				[]
			)
		)
		var revised_plan: Array[Dictionary] = []
		for raw_hour in revision_hours:
			revised_plan.append({
				"hour": int(raw_hour),
				"action_kind": action_kind,
				"action_id": action_id,
				"location_id": location_id,
				"target_id": null,
				"priority": 80,
				"reason": "完成后安排",
				"dialogue_goal": "",
			})
		var immediate_action: Dictionary = (
			revised_plan[0].duplicate(true)
			if not revised_plan.is_empty()
			else {}
		)
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": revised_plan,
				"immediate_action": immediate_action,
				"summary": "完成短活动后继续行动。",
				"debug_reason": "T0086 verification",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false,
			},
		})

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "capture-real-provider",
					"configured": true,
					"fallback_to_mock": false,
				},
			},
		}


const FIRST_NPC_ID := "cook_01"
const BOUNDARY_NPC_ID := "gardener_01"
const CURRENT_HOUR := 8
const EXPECTED_REEVALUATION_ACTIONS := [
	"assist_heal",
	"assist_repair",
	"assist_upgrade",
	"drink_wine",
	"receive_clinic_treatment",
]


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node_or_null("Main/Systems")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var game_state := root.get_node_or_null("GameState")
	if [
		systems,
		time_system,
		npc_system,
		action_system,
		resource_system,
		daily_plan_system,
		original_bridge,
		hud,
		game_state,
	].has(null):
		_fail("T0086 verification requires Main systems and HUD")
		return

	daily_plan_system.set_auto_execution_enabled(false)
	if (
		not original_bridge.has_method("_normalize_plan_failure_type")
		or str(original_bridge._normalize_plan_failure_type("action_completed"))
		!= "action_completed"
	):
		_fail("LLMBridge must preserve the action_completed failure type")
		return
	if not _verify_completion_catalog(action_system, daily_plan_system):
		return
	if not _verify_speed_shortcuts(hud, time_system):
		return

	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var bridge := CapturingLLMBridge.new()
	bridge.name = "LLMBridge"
	systems.add_child(bridge)
	bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	if not _prepare_drink_plan(
		FIRST_NPC_ID,
		CURRENT_HOUR,
		npc_system,
		resource_system,
		daily_plan_system,
		3
	):
		return
	daily_plan_system.set_auto_execution_enabled(true)
	var start_result: Dictionary = daily_plan_system.execute_current_plan_for_npc(
		FIRST_NPC_ID,
		true
	)
	if (
		not bool(start_result.get("ok", false))
		or str(action_system.get_runtime_action_id(FIRST_NPC_ID)) != "drink_wine"
	):
		_fail("Could not start completion-reevaluation drink action: %s" % str(start_result))
		return
	var duration := float(
		action_system.get_runtime_action_snapshot(FIRST_NPC_ID).get(
			"duration_seconds",
			0.0
		)
	)
	action_system._on_logical_time_tick(duration, 1.0)
	for _index in range(3):
		await process_frame
	if bridge.revision_requests.size() != 1:
		_fail(
			"Completed short action must start exactly one direct revision: %s"
			% str(bridge.revision_requests)
		)
		return
	var first_request: Dictionary = bridge.revision_requests[0]
	var first_options: Dictionary = first_request.get("options", {})
	var failure_context: Dictionary = first_options.get("failure_context", {})
	if (
		str(first_options.get("failure_type", "")) != "action_completed"
		or first_options.get("revision_hours", [])
		!= [CURRENT_HOUR, CURRENT_HOUR + 1, CURRENT_HOUR + 2]
		or str(
			(first_options.get("failed_plan_item", {}) as Dictionary).get(
				"action_id",
				""
			)
		) != "drink_wine"
		or not bool(failure_context.get("requires_different_current_activity", false))
		or str(failure_context.get("completion_result", ""))
		!= "completed_drink_wine"
		or failure_context.get("contiguous_revision_hours", [])
		!= [CURRENT_HOUR, CURRENT_HOUR + 1, CURRENT_HOUR + 2]
	):
		_fail("Completion revision lost its authoritative context: %s" % str(first_options))
		return

	# A model output that repeats the consumed drink action must be rejected and
	# retried before any plan is applied.
	bridge.answer_revision(first_request, "drink_wine", "drink", null)
	await process_frame
	if bridge.revision_requests.size() != 2:
		_fail(
			"Repeating the completed action did not trigger a bounded revision retry: requests=%d result=%s"
			% [
				bridge.revision_requests.size(),
				str(daily_plan_system.get_last_reevaluation_result()),
			]
		)
		return
	var second_request: Dictionary = bridge.revision_requests[1]
	bridge.answer_revision(
		second_request,
		"work_dining_hall",
		"work",
		"dining_hall"
	)
	for _index in range(3):
		await process_frame
	if str(action_system.get_runtime_action_id(FIRST_NPC_ID)) != "work_dining_hall":
		_fail(
			"Successful current-hour revision was not executed immediately: %s"
			% str(action_system.get_runtime_action_snapshot(FIRST_NPC_ID))
		)
		return
	var revised_plan: Array = daily_plan_system.get_npc_daily_plan(FIRST_NPC_ID)
	for hour in [CURRENT_HOUR, CURRENT_HOUR + 1, CURRENT_HOUR + 2]:
		if str((revised_plan[hour] as Dictionary).get("action_id", "")) != "work_dining_hall":
			_fail("Continuous completion span was not revised at hour %d" % hour)
			return
	if str((revised_plan[CURRENT_HOUR + 3] as Dictionary).get("action_id", "")) != "work_garden":
		_fail("Completion revision crossed into the first different plan item")
		return

	# Complete another short action just before the hour boundary, then advance
	# the authoritative clock before deferred completion processing. The new
	# hour's normal dispatcher must own the continuation.
	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_current_time(1, CURRENT_HOUR, 59, 50)
	if not _prepare_drink_plan(
		BOUNDARY_NPC_ID,
		CURRENT_HOUR,
		npc_system,
		resource_system,
		daily_plan_system
	):
		return
	daily_plan_system.set_auto_execution_enabled(true)
	var boundary_start: Dictionary = daily_plan_system.execute_current_plan_for_npc(
		BOUNDARY_NPC_ID,
		true
	)
	if (
		not bool(boundary_start.get("ok", false))
		or str(action_system.get_runtime_action_id(BOUNDARY_NPC_ID)) != "drink_wine"
	):
		_fail("Could not start boundary drink action: %s" % str(boundary_start))
		return
	var boundary_duration := float(
		action_system.get_runtime_action_snapshot(BOUNDARY_NPC_ID).get(
			"duration_seconds",
			0.0
		)
	)
	var requests_before_boundary := bridge.revision_requests.size()
	action_system._on_logical_time_tick(boundary_duration, 1.0)
	if not time_system.debug_advance_game_seconds(10.0):
		_fail("Could not cross hour after boundary completion")
		return
	for _index in range(3):
		await process_frame
	if bridge.revision_requests.size() != requests_before_boundary:
		_fail("Hour-crossing completion launched a stale prior-hour revision")
		return
	if (
		int(game_state.current_hour) != CURRENT_HOUR + 1
		or str(
			daily_plan_system.get_current_plan_item(BOUNDARY_NPC_ID).get(
				"action_id",
				""
			)
		) != "work_garden"
		or str(action_system.get_runtime_action_id(BOUNDARY_NPC_ID)).is_empty()
	):
		_fail(
			"New-hour normal plan dispatch did not take over after completion: %s"
			% str(action_system.get_runtime_action_snapshot(BOUNDARY_NPC_ID))
		)
		return

	print("T0086 plan completion reevaluation and speed shortcut verification passed.")
	quit(0)


func _verify_completion_catalog(
	action_system: Node,
	daily_plan_system: Node
) -> bool:
	var marked_actions: Array[String] = []
	for action_id in action_system.get_action_ids():
		var definition: Dictionary = action_system.get_action(action_id)
		if bool(definition.get("reevaluate_current_hour_on_completion", false)):
			marked_actions.append(action_id)
	marked_actions.sort()
	if marked_actions != EXPECTED_REEVALUATION_ACTIONS:
		_fail("Completion reevaluation catalog mismatch: %s" % str(marked_actions))
		return false
	for completion_case in [
		["assist_repair", "completed_assist_repair_wall"],
		["assist_upgrade", "completed_assist_upgrade_clinic"],
		["assist_heal", "assist_heal_completed_cook_01"],
		["receive_clinic_treatment", "clinic_treatment_completed"],
		["drink_wine", "completed_drink_wine"],
	]:
		if not daily_plan_system._is_successful_plan_action_completion(
			str(completion_case[0]),
			str(completion_case[1])
		):
			_fail("Successful completion result was not recognized: %s" % str(completion_case))
			return false
	return true


func _verify_speed_shortcuts(hud: Node, time_system: Node) -> bool:
	for shortcut_case in [
		[KEY_1, 1.0],
		[KEY_2, 2.0],
		[KEY_3, 4.0],
	]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = shortcut_case[0]
		event.physical_keycode = shortcut_case[0]
		hud._input(event)
		if not is_equal_approx(time_system.time_scale, float(shortcut_case[1])):
			_fail("Top-row speed shortcut failed: %s" % str(shortcut_case))
			return false
	var numpad_event := InputEventKey.new()
	numpad_event.pressed = true
	numpad_event.keycode = KEY_KP_1
	numpad_event.physical_keycode = KEY_KP_1
	hud._input(numpad_event)
	if not is_equal_approx(time_system.time_scale, 4.0):
		_fail("Numpad digit unexpectedly changed the time scale")
		return false
	var line_edit := LineEdit.new()
	hud.add_child(line_edit)
	line_edit.grab_focus()
	var focused_event := InputEventKey.new()
	focused_event.pressed = true
	focused_event.keycode = KEY_1
	focused_event.physical_keycode = KEY_1
	hud._input(focused_event)
	if not is_equal_approx(time_system.time_scale, 4.0):
		_fail("Speed shortcut stole a digit from focused text input")
		return false
	line_edit.release_focus()
	line_edit.queue_free()
	return true


func _prepare_drink_plan(
	npc_id: String,
	hour: int,
	npc_system: Node,
	resource_system: Node,
	daily_plan_system: Node,
	consecutive_hour_count: int = 1
) -> bool:
	var current_action := str(npc_system.get_npc_state(npc_id).get("current_action", ""))
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	if (
		action_system != null
		and current_action != "idle"
		and not current_action.is_empty()
	):
		action_system.interrupt_npc_action(npc_id, "t0086_prepare", true)
	if not npc_system.debug_enter_location_immediately(npc_id, "dining_hall"):
		_fail("Could not place %s in dining hall" % npc_id)
		return false
	npc_system.update_npc_state(npc_id, {
		"behavior_mode": "work",
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "t0086_ready",
	})
	resource_system.add_resource("wine", consecutive_hour_count)
	var gift_result: Dictionary = npc_system.give_wine_to_npc(
		npc_id,
		consecutive_hour_count,
		"private"
	)
	if not bool(gift_result.get("ok", false)):
		_fail("Could not give verification wine to %s: %s" % [npc_id, gift_result])
		return false
	var plan := _make_plan("work_garden")
	for offset in range(consecutive_hour_count):
		var plan_hour := hour + offset
		plan[plan_hour] = {
			"hour": plan_hour,
			"action_id": "drink_wine",
			"reason": "T0086 short completion",
			"priority": 80,
			"target": {},
		}
	if not daily_plan_system.set_npc_daily_plan(
		npc_id,
		plan,
		false,
		"verify_completion_reevaluation"
	):
		_fail("Could not install drink plan for %s" % npc_id)
		return false
	return true


func _make_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0086 verification",
			"priority": 50,
			"target": {},
		})
	return plan


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
