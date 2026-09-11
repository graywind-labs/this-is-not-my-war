extends SceneTree


const REPEAT_ACTIONS := [
	"work_garden",
	"work_dining_hall",
	"work_stable",
	"work_tavern",
	"work_blacksmith",
	"work_workshop",
]
const CONTINUOUS_ACTIONS := [
	"work_training_instructor",
	"receive_weapon_training",
	"work_clinic_doctor",
]
const TARGET_RESOLVED_ACTIONS := [
	"receive_clinic_treatment",
	"assist_repair",
	"assist_upgrade",
	"assist_heal",
]
const ONE_SHOT_ACTIONS := [
	"eat_at_dining_hall",
	"drink_wine",
	"sleep_in_dormitory",
	"pray_at_chapel",
	"lead_mass",
	"talk_to_npc",
	"visit_location",
	"seek_guard_officer",
]
const TERMINAL_ACTIONS := ["escaping_station"]
const NON_PLAN_ACTIONS := [
	"escape_intervention_dialogue",
	"talk_to_guard_officer",
]
const REEVALUATE_ON_COMPLETION_ACTIONS := [
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

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	if [time_system, npc_system, action_system, resource_system, memory_system, daily_plan_system].has(null):
		_fail("Completion-policy verification requires all scene systems")
		return

	if not _verify_action_catalog(action_system):
		return

	const NPC_ID := "gardener_01"
	time_system.set_current_time(1, 7, 2, 0)
	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(true)
	resource_system.add_resource("meal", 8)
	var gardener := _get_npc_node(npc_system, NPC_ID)
	if gardener == null:
		_fail("Could not resolve repeatable-plan actor node")
		return
	gardener.set("move_speed", 5.0)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "garden"):
		_fail("Could not place repeatable-plan actor in garden")
		return
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_completion_policy_ready",
	})
	var work_plan := _make_plan("work_garden")
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		work_plan,
		false,
		"verify_completion_policy"
	):
		_fail("Could not install repeatable work plan")
		return
	var first_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(first_execute.get("ok", false)):
		_fail("Initial repeatable work did not dispatch: %s" % str(first_execute))
		return
	if not await _wait_for_active(action_system, time_system, NPC_ID, "work_garden"):
		_fail(
			"Initial repeatable work did not physically reach its garden plot: %s"
			% JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID))
		)
		return
	var first_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var first_duration := float(first_runtime.get("duration_seconds", 0.0))
	if (
		str(first_runtime.get("action_id", "")) != "work_garden"
		or first_duration <= 0.0
	):
		_fail("Initial repeatable work runtime is invalid: %s" % str(first_runtime))
		return
	var events_before_cycle: Array = memory_system.get_npc_daily_events(NPC_ID)
	var starts_before_cycle := _count_events(events_before_cycle, "work_started")
	var completions_before_cycle := _count_events(events_before_cycle, "work_completed")

	action_system._on_logical_time_tick(first_duration, 1.0)
	for _index in range(3):
		await process_frame
	var repeated_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if str(repeated_runtime.get("action_id", "")) != "work_garden":
		_fail("Successful repeatable work did not immediately open the next cycle")
		return
	if float(repeated_runtime.get("elapsed_seconds", -1.0)) > 30.0:
		_fail("The repeated work cycle did not start near zero progress: %s" % str(repeated_runtime))
		return
	var events_after_cycle: Array = memory_system.get_npc_daily_events(NPC_ID)
	if _count_events(events_after_cycle, "work_completed") != completions_before_cycle + 1:
		_fail("Repeatable cycle did not write exactly one completion event")
		return
	if _count_events(events_after_cycle, "work_started") != starts_before_cycle + 1:
		_fail("Repeatable cycle did not write exactly one new start event")
		return
	var last_completion_index := _last_event_index(events_after_cycle, "work_completed")
	var last_start_index := _last_event_index(events_after_cycle, "work_started")
	if last_completion_index < 0 or last_start_index <= last_completion_index:
		_fail("New work_started was not ordered after the previous work_completed")
		return

	# Crossing into an hour with the same logical item keeps the active runtime
	# and therefore preserves its current cycle progress.
	time_system.set_current_time(1, 8, 59, 0)
	var before_same_hour_cross: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var elapsed_before_same_hour_cross := float(before_same_hour_cross.get("elapsed_seconds", -1.0))
	if not time_system.debug_advance_game_seconds(60.0):
		_fail("Could not advance across same-action hour boundary")
		return
	await process_frame
	var after_same_hour_cross: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if str(after_same_hour_cross.get("action_id", "")) != "work_garden":
		_fail("Same-action next hour interrupted the active work cycle")
		return
	var elapsed_after_same_hour_cross := float(after_same_hour_cross.get("elapsed_seconds", -1.0))
	if absf(elapsed_after_same_hour_cross - elapsed_before_same_hour_cross - 60.0) > 30.0:
		_fail(
			"Same-action hour boundary did not preserve progress: before=%s after=%s"
			% [elapsed_before_same_hour_cross, elapsed_after_same_hour_cross]
		)
		return

	# A cycle completion immediately before an hour change is handed over to
	# hour_started. The deferred completion callback must not dispatch a second
	# cycle after that boundary.
	time_system.set_current_time(1, 9, 59, 0)
	var before_boundary_completion: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var remaining_to_completion := (
		float(before_boundary_completion.get("duration_seconds", 0.0))
		- float(before_boundary_completion.get("elapsed_seconds", 0.0))
	)
	var starts_before_boundary_completion := _count_events(
		memory_system.get_npc_daily_events(NPC_ID),
		"work_started"
	)
	action_system._on_logical_time_tick(remaining_to_completion, 1.0)
	if not time_system.debug_advance_game_seconds(60.0):
		_fail("Could not advance after boundary-adjacent work completion")
		return
	for _index in range(3):
		await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "work_garden":
		_fail("Hour-start dispatch did not continue work after boundary completion")
		return
	if (
		_count_events(memory_system.get_npc_daily_events(NPC_ID), "work_started")
		!= starts_before_boundary_completion + 1
	):
		_fail("Boundary completion and hour start dispatched more than one next cycle")
		return

	# Crossing into a different item interrupts the incomplete cycle and starts
	# the new hour's plan without granting a work completion.
	var switched_plan := _make_plan("work_garden")
	switched_plan[11] = {
		"hour": 11,
		"action_id": "eat_at_dining_hall",
		"reason": "verify different next-hour plan item",
		"priority": 50,
		"target": {},
	}
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		switched_plan,
		false,
		"verify_hour_switch"
	):
		_fail("Could not install different next-hour plan item")
		return
	time_system.set_current_time(1, 10, 59, 0)
	var completions_before_switch := _count_events(
		memory_system.get_npc_daily_events(NPC_ID),
		"work_completed"
	)
	npc_system.update_npc_state(NPC_ID, {"satiety": 0})
	if not time_system.debug_advance_game_seconds(60.0):
		_fail("Could not advance across different-action hour boundary")
		return
	await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "eat_at_dining_hall":
		_fail(
			"Different next-hour item did not replace the active work: %s"
			% str(action_system.get_runtime_action_snapshot(NPC_ID))
		)
		return
	if (
		_count_events(memory_system.get_npc_daily_events(NPC_ID), "work_completed")
		!= completions_before_switch
	):
		_fail("Interrupted incomplete work incorrectly granted a completed cycle")
		return

	print("T0075 plan action completion-policy verification passed.")
	quit(0)


func _verify_action_catalog(action_system: Node) -> bool:
	if (
		action_system.is_action_completion_policy_valid("", true)
		or action_system.is_action_completion_policy_valid("unknown_policy", true)
		or action_system.is_action_completion_policy_valid("not_plan_selectable", true)
		or action_system.is_action_completion_policy_valid("repeat_while_planned", false)
	):
		_fail("Completion-policy validator accepted a missing, unknown, or conflicting policy")
		return false
	var expected := {}
	for action_id in REPEAT_ACTIONS:
		expected[action_id] = "repeat_while_planned"
	for action_id in CONTINUOUS_ACTIONS:
		expected[action_id] = "continuous_until_plan_changes"
	for action_id in TARGET_RESOLVED_ACTIONS:
		expected[action_id] = "until_target_resolved"
	for action_id in ONE_SHOT_ACTIONS:
		expected[action_id] = "once_per_plan_hour"
	for action_id in TERMINAL_ACTIONS:
		expected[action_id] = "terminal"
	for action_id in NON_PLAN_ACTIONS:
		expected[action_id] = "not_plan_selectable"
	if expected.size() != 24:
		_fail("Completion-policy audit does not cover exactly 25 configured actions")
		return false
	var definition_errors: Array[String] = action_system.get_action_definition_errors()
	if not definition_errors.is_empty():
		_fail("Action definitions contain completion-policy errors: %s" % str(definition_errors))
		return false
	var configured_ids: Array[String] = action_system.get_action_ids()
	if configured_ids.size() != expected.size():
		_fail(
			"Configured action count is not exhaustively covered: configured=%d expected=%d"
			% [configured_ids.size(), expected.size()]
		)
		return false
	for action_id in configured_ids:
		var expected_policy := str(expected.get(action_id, ""))
		var actual_policy := str(action_system.get_action_completion_policy(action_id))
		if expected_policy.is_empty() or actual_policy != expected_policy:
			_fail(
				"Unexpected completion policy for %s: expected=%s actual=%s"
				% [action_id, expected_policy, actual_policy]
			)
			return false
		var action: Dictionary = action_system.get_action(action_id)
		var should_reevaluate := bool(
			action.get("reevaluate_current_hour_on_completion", false)
		)
		if should_reevaluate != REEVALUATE_ON_COMPLETION_ACTIONS.has(action_id):
			_fail(
				"Unexpected completion reevaluation flag for %s: %s"
				% [action_id, should_reevaluate]
			)
			return false
	return true


func _make_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0075 completion-policy verification",
			"priority": 50,
			"target": {},
		})
	return plan


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count


func _last_event_index(events: Array, event_type: String) -> int:
	for index in range(events.size() - 1, -1, -1):
		var raw_event: Variant = events[index]
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			return index
	return -1


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(
	action_system: Node,
	time_system: Node,
	npc_id: String,
	action_id: String,
	max_frames: int = 1800
) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if (
			str(runtime.get("phase", "")) == "active"
			and str(runtime.get("action_id", "")) == action_id
		):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
