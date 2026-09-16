extends SceneTree

const SLEEPER_ID := "veteran_deputy_01"
const SLEEP_ACTION_ID := "sleep_in_dormitory"
const SLEEP_BUILDING_ID := "dormitory"
const SLEEP_WORKSTATION_ID := "dormitory_bed_01"
const WORKER_ID := "gardener_01"
const WORK_ACTION_ID := "work_garden"
const WORK_BUILDING_ID := "garden"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if [action_system, npc_system, combat_system, daily_plan_system, time_system, controller].has(null):
		_fail("T0403-R3 runtime dependencies unavailable")
		return

	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_paused(false)
	var sleeper := _get_npc_node(npc_system, SLEEPER_ID)
	var worker := _get_npc_node(npc_system, WORKER_ID)
	if sleeper == null or worker == null:
		_fail("T0403-R3 NPC actors unavailable")
		return
	sleeper.set("move_speed", 8.0)
	worker.set("move_speed", 8.0)
	npc_system.update_npc_state(SLEEPER_ID, {
		"fatigue": 80,
		"satiety": 100,
		"current_action": "idle",
		"behavior_mode": "work"
	})

	if not action_system.debug_assign_action(SLEEPER_ID, SLEEP_ACTION_ID, true):
		_fail("Could not start formal dormitory sleep")
		return
	if not await _wait_for_active(action_system, time_system, SLEEPER_ID, SLEEP_ACTION_ID):
		_fail("Sleeper did not reach the assigned bed")
		return
	var sleep_route: Dictionary = controller.get_building_spatial_route(SLEEP_BUILDING_ID, SLEEP_WORKSTATION_ID)
	var sleep_stand: Variant = sleep_route.get("interior_target_position")
	var sleep_anchor: Variant = sleep_route.get("occupant_anchor_position")
	if not sleep_stand is Vector3 or not sleep_anchor is Vector3:
		_fail("Dormitory route lacks stand/anchor positions")
		return
	var sleep_session_before: Dictionary = npc_system.get_formal_workstation_action_snapshot(SLEEPER_ID)
	var sleep_position_before: Vector3 = sleeper.global_position
	time_system.set_paused(true)
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Could not spawn the edge wave: %s" % JSON.stringify(spawn_result))
		return
	var sleep_session_after_spawn: Dictionary = npc_system.get_formal_workstation_action_snapshot(SLEEPER_ID)
	if (
		str(npc_system.get_npc_state(SLEEPER_ID).get("current_action", "")) != SLEEP_ACTION_ID
		or str(npc_system.get_npc_behavior_mode(SLEEPER_ID)) != "work"
		or str(action_system.get_runtime_action_snapshot(SLEEPER_ID).get("phase", "")) != "active"
		or not bool(sleep_session_after_spawn.get("active", false))
		or int((sleep_session_after_spawn.get("session", {}) as Dictionary).get("session_id", -1))
			!= int((sleep_session_before.get("session", {}) as Dictionary).get("session_id", -2))
		or sleeper.global_position.distance_to(sleep_position_before) > 0.01
	):
		_fail("Enemy edge spawn interrupted formal sleep")
		return

	var alarm_result: Dictionary = combat_system.debug_trigger_combat_alarm()
	if not bool(alarm_result.get("ok", false)) or str(npc_system.get_npc_behavior_mode(SLEEPER_ID)) != "rally":
		_fail("Armed sleeping NPC did not enter rally through the formal alarm")
		return
	var sleep_after_alarm: Dictionary = npc_system.get_npc_state(SLEEPER_ID)
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(SLEEPER_ID).get("active", true))
		or str(sleep_after_alarm.get("physical_location_phase", "")) == "occupant_anchor"
		or sleeper.global_position.distance_to(sleep_stand) > 0.05
		or sleeper.global_position.distance_to(sleep_anchor) < 0.05
		or bool(sleeper.debug_get_spatial_attachment_snapshot().get("active", true))
	):
		_fail("Alarm rally did not hand the sleeper off through the bed stand point: %s" % JSON.stringify(sleep_after_alarm))
		return
	combat_system.debug_clear_enemies()
	await process_frame

	npc_system.set_npc_behavior_mode(WORKER_ID, "work", "verify_work_ready", {"interrupt": false})
	npc_system.update_npc_state(WORKER_ID, {"fatigue": 0, "satiety": 100, "current_action": "idle"})
	time_system.set_paused(false)
	if not action_system.debug_assign_action(WORKER_ID, WORK_ACTION_ID, true):
		_fail("Could not start formal garden work")
		return
	if not await _wait_for_active(action_system, time_system, WORKER_ID, WORK_ACTION_ID):
		_fail("Worker did not reach a formal garden workstation")
		return
	var worker_state_before: Dictionary = npc_system.get_npc_state(WORKER_ID)
	var workstation_id := str(worker_state_before.get("current_workstation_id", ""))
	var work_route: Dictionary = controller.get_building_spatial_route(WORK_BUILDING_ID, workstation_id)
	var work_stand: Variant = work_route.get("interior_target_position")
	var work_session_before: Dictionary = npc_system.get_formal_workstation_action_snapshot(WORKER_ID)
	var work_position_before: Vector3 = worker.global_position
	time_system.set_paused(true)
	spawn_result = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Could not spawn the work-preservation wave")
		return
	var work_session_after_spawn: Dictionary = npc_system.get_formal_workstation_action_snapshot(WORKER_ID)
	if (
		str(npc_system.get_npc_state(WORKER_ID).get("current_action", "")) != WORK_ACTION_ID
		or str(action_system.get_runtime_action_snapshot(WORKER_ID).get("phase", "")) != "active"
		or int((work_session_after_spawn.get("session", {}) as Dictionary).get("session_id", -1))
			!= int((work_session_before.get("session", {}) as Dictionary).get("session_id", -2))
		or worker.global_position.distance_to(work_position_before) > 0.01
	):
		_fail("Enemy edge spawn interrupted formal work")
		return

	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = worker.global_position + Vector3(1.0, 0.0, 0.0)
	combat_system._active_enemies[enemy_id] = enemy
	var avoid_result: Dictionary = combat_system.debug_trigger_npc_avoidance(WORKER_ID)
	if not bool(avoid_result.get("ok", false)) or str(npc_system.get_npc_behavior_mode(WORKER_ID)) != "avoid_combat":
		_fail("Unarmed worker did not enter avoidance from a real nearby enemy")
		return
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(WORKER_ID).get("active", true))
		or not work_stand is Vector3
		or worker.global_position.distance_to(work_stand) > 0.35
		or worker.global_position.distance_to(work_position_before) > 0.05
	):
		_fail("Standing workstation did not hand avoidance off from its configured NPCStand: %s" % JSON.stringify({
			"before": work_position_before,
			"after": worker.global_position,
			"stand": work_stand
		}))
		return

	print("T0403-R3 wartime workstation handoff verification passed")
	quit(0)


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 2400) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _get_npc_node(npc_system: Node, npc_id: String) -> Node3D:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath(""))) as Node3D


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
