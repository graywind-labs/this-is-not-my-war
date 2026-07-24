extends SceneTree

const ACTOR_ID := "stableman_01"
const FIRST_TARGET_ID := "doctor_01"
const SECOND_TARGET_ID := "priest_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	if npc_system == null or action_system == null or daily_plan_system == null:
		_fail("Target replacement verification requires NPC, action, and plan systems")
		return
	if not action_system.has_method("get_runtime_action_snapshot"):
		_fail("ActionSystem does not expose a target-aware runtime snapshot")
		return

	if (
		not npc_system.debug_enter_location_immediately(ACTOR_ID, "stable")
		or not npc_system.debug_enter_location_immediately(FIRST_TARGET_ID, "clinic")
		or not npc_system.debug_enter_location_immediately(SECOND_TARGET_ID, "chapel")
	):
		_fail("Could not prepare target replacement locations")
		return
	var hour := int(root.get_node("GameState").current_hour)

	# Same action id with a different target must interrupt the old approach and
	# install the newly revised target instead of returning already_running.
	if not _install_and_execute(daily_plan_system, hour, "talk_to_npc", {
		"target_id": FIRST_TARGET_ID,
		"target_npc_id": FIRST_TARGET_ID,
		"location_id": "clinic",
	}, "先去找医生。"):
		_fail("Could not start first dialogue approach")
		return
	var first_runtime: Dictionary = action_system.get_runtime_action_snapshot(ACTOR_ID)
	if str(first_runtime.get("action_id", "")) != "talk_to_npc" or str(first_runtime.get("target_id", "")) != FIRST_TARGET_ID:
		_fail("First dialogue target was not installed: %s" % str(first_runtime))
		return

	if not _install_and_execute(daily_plan_system, hour, "talk_to_npc", {
		"target_id": SECOND_TARGET_ID,
		"target_npc_id": SECOND_TARGET_ID,
		"location_id": "chapel",
	}, "改去找神父。"):
		_fail("Could not replace dialogue approach target")
		return
	var second_runtime: Dictionary = action_system.get_runtime_action_snapshot(ACTOR_ID)
	if (
		str(second_runtime.get("action_id", "")) != "talk_to_npc"
		or str(second_runtime.get("target_id", "")) != SECOND_TARGET_ID
		or str(second_runtime.get("options", {}).get("opening_text", "")) != "改去找神父。"
	):
		_fail("Revised dialogue target/goal did not replace the pending runtime: %s" % str(second_runtime))
		return
	action_system.interrupt_npc_action(ACTOR_ID, "verify_dialogue_target_cleanup")

	if not npc_system.debug_enter_location_immediately(ACTOR_ID, "stable"):
		_fail("Could not reset actor for visit target replacement")
		return
	if not _install_and_execute(daily_plan_system, hour, "visit_location", {
		"target_id": "clinic",
		"location_id": "clinic",
	}, "先去诊所。"):
		_fail("Could not start first visit approach")
		return
	if not _install_and_execute(daily_plan_system, hour, "visit_location", {
		"target_id": "chapel",
		"location_id": "chapel",
	}, "改去教堂。"):
		_fail("Could not replace visit target")
		return
	var visit_runtime: Dictionary = action_system.get_runtime_action_snapshot(ACTOR_ID)
	if str(visit_runtime.get("action_id", "")) != "visit_location" or str(visit_runtime.get("target_id", "")) != "chapel":
		_fail("Revised visit target did not replace the pending runtime: %s" % str(visit_runtime))
		return

	print("T0025 target-aware plan replacement verification passed.")
	quit(0)


func _install_and_execute(
	daily_plan_system: Node,
	hour: int,
	action_id: String,
	target: Dictionary,
	dialogue_goal: String
) -> bool:
	var plan: Array = []
	for plan_hour in range(24):
		plan.append({
			"hour": plan_hour,
			"action_id": action_id if plan_hour == hour else "idle",
			"action_name": action_id if plan_hour == hour else "等待",
			"source": "verify_target_replacement",
			"target": target.duplicate(true) if plan_hour == hour else {},
			"priority": 70 if plan_hour == hour else 10,
			"reason": dialogue_goal if plan_hour == hour else "测试占位。",
			"dialogue_goal": dialogue_goal if plan_hour == hour else "",
		})
	if not daily_plan_system.set_npc_daily_plan(ACTOR_ID, plan, false, "verify_target_replacement"):
		return false
	var result: Dictionary = daily_plan_system.execute_current_plan_for_npc(ACTOR_ID, true)
	return bool(result.get("ok", false)) and str(result.get("status", "")) != "already_running"


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
