extends SceneTree


class FakeRevisionBridge:
	extends Node

	signal plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var judgement_request_count := 0

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "verify-navigation-no-revision",
					"configured": true,
					"fallback_to_mock": false,
				}
			}
		}

	func check_health() -> Dictionary:
		return get_cached_health()

	func request_plan_revision_judgement_async(_npc_id: String, _options: Dictionary = {}) -> Dictionary:
		judgement_request_count += 1
		return {
			"ok": true,
			"pending": true,
			"request_id": "verify_navigation_judgement_%d" % judgement_request_count,
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

	var systems := root.get_node_or_null("Main/Systems")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if systems == null or npc_system == null or daily_plan_system == null or original_bridge == null:
		_fail("Navigation failure verification requires NPC, plan and LLM systems")
		return

	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var fake_bridge := FakeRevisionBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)

	var npc_id := "doctor_01"
	daily_plan_system.generate_rule_plan_for_npc(npc_id)
	var baseline_result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	var navigation_failures: Array[Dictionary] = [
		{
			"last_action_result": "movement_failed_stuck_timeout",
			"last_action_failure_context": {"reason": "stuck_timeout"},
		},
		{
			"last_action_result": "movement_failed_target_unreachable",
			"last_action_failure_context": {"reason": "target_unreachable"},
		},
		{
			"last_action_result": "work_clinic_doctor_failed_spatial_route",
			"last_action_failure_context": {
				"action_id": "work_clinic_doctor",
				"failure_reason": "navigation_failed",
			},
		},
	]
	for failure in navigation_failures:
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": failure["last_action_result"],
			"last_action_failure_context": failure["last_action_failure_context"],
			"spatial_route_phase": "navigation_failed",
		})
		await process_frame
		if fake_bridge.judgement_request_count != 0:
			_fail("Navigation failure launched plan judgement: %s" % str(failure))
			return
		if daily_plan_system.get_last_reevaluation_result() != baseline_result:
			_fail("Navigation failure was recorded as a plan reevaluation: %s" % str(failure))
			return
		if (daily_plan_system.get("_reevaluating_npcs") as Dictionary).has(npc_id):
			_fail("Navigation failure left NPC in reevaluating state: %s" % str(failure))
			return
		if (daily_plan_system.get("_queued_reevaluation_by_npc") as Dictionary).has(npc_id):
			_fail("Navigation failure queued a later reevaluation: %s" % str(failure))
			return

	var guarded_result: Dictionary = daily_plan_system.request_plan_reevaluation(
		npc_id,
		"revision_execution_failed_movement_failed_stuck_timeout"
	)
	if str(guarded_result.get("status", "")) != "navigation_failure_ignored":
		_fail("Public reevaluation guard accepted a navigation retry: %s" % str(guarded_result))
		return
	if fake_bridge.judgement_request_count != 0:
		_fail("Guarded navigation retry reached the model bridge")
		return

	npc_system.update_npc_state(npc_id, {
		"current_action": "idle",
		"last_action_result": "work_clinic_doctor_failed_no_resources",
		"last_action_failure_context": {
			"action_id": "work_clinic_doctor",
			"failure_reason": "insufficient_stage_resources",
		},
		"spatial_route_phase": "none",
	})
	await process_frame
	if fake_bridge.judgement_request_count != 1:
		_fail("Non-navigation business failure no longer triggers plan judgement")
		return

	print("T1505 navigation failure no-reevaluation verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
