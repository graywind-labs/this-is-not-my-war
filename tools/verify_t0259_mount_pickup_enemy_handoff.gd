extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const RIDER_START := Vector3(0.0, 0.0, 72.0)
const ENEMY_CONTACT_OFFSET := Vector3(0.0, 0.0, 10.0)
const MAX_MOUNT_FRAMES := 3000


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if combat_system == null or npc_system == null or horse_system == null or time_system == null or controller == null:
		_fail("T0259 runtime dependencies are missing")
		return
	time_system.set_paused(false)
	time_system.set_time_scale(0.0)
	controller.debug_set_preview_enabled(true)
	await physics_frame
	controller.force_sync_production_navigation()

	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.is_empty():
		_fail("T0259 requires an initial horse")
		return
	var horse_id := str(horse_ids[0])
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0259_reset", {"force_idle": true})
	var assignment: Dictionary = horse_system.assign_horse_to_npc(NPC_ID, horse_id, "private")
	if not bool(assignment.get("ok", false)):
		_fail("T0259 could not assign a horse: %s" % assignment)
		return
	var rider := _get_npc_node(npc_system, NPC_ID)
	if rider == null:
		_fail("T0259 rider body is missing")
		return
	rider.set("move_speed", 8.0)
	if rider.has_method("stop_movement"):
		rider.stop_movement()
	rider.global_position = RIDER_START

	var alarm_before_enemy: Dictionary = combat_system.trigger_combat_alarm("t0259_pre_enemy_rally")
	if not bool(alarm_before_enemy.get("ok", false)):
		_fail("T0259 could not start the pre-enemy rally: %s" % alarm_before_enemy)
		return
	await physics_frame
	var pickup_before_enemy: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		str(pickup_before_enemy.get("behavior_mode", "")) != "rally"
		or str(pickup_before_enemy.get("combat_mount_phase", "")) != "going_to_stable_horse"
		or not npc_system.is_npc_world_movement_active(NPC_ID)
	):
		_fail("T0259 pre-enemy mount pickup did not start: %s" % pickup_before_enemy)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true, true)
	if not bool(spawn_result.get("ok", false)) or combat_system.get_active_enemy_ids().is_empty():
		_fail("T0259 could not generate the GM wave fixture: %s" % spawn_result)
		return
	var route_recovered_after_spawn := false
	for _frame in range(30):
		await process_frame
		await physics_frame
		if npc_system.is_npc_world_movement_active(NPC_ID):
			route_recovered_after_spawn = true
			break
	if not route_recovered_after_spawn:
		_fail("T0259 wave generation cancelled the active stable pickup route: state=%s horse=%s" % [npc_system.get_npc_state(NPC_ID), horse_system.get_horse_snapshot(horse_id)])
		return
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	var enemy_id := enemy_ids[0]
	_set_enemy_position(combat_system, enemy_id, Vector3(rider.global_position) + ENEMY_CONTACT_OFFSET)
	combat_system._advance_behavior_mode_contacts()
	await process_frame
	await physics_frame

	var contact_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		str(contact_state.get("behavior_mode", "")) != "combat"
		or str(contact_state.get("combat_target_enemy_id", "")) != enemy_id
		or str(contact_state.get("combat_mount_phase", "")) != "going_to_stable_horse"
	):
		_fail("T0259 rally contact did not retain combat + mount intent: %s" % contact_state)
		return
	if not npc_system.is_npc_world_movement_active(NPC_ID):
		_fail("T0259 enemy contact cancelled the rider's stable pickup route: state=%s horse=%s" % [contact_state, horse_system.get_horse_snapshot(horse_id)])
		return

	# Reproduce the user's second-bell observation without changing the valid
	# attack lock: only the missing rider-to-horse route may be recovered.
	rider.stop_movement()
	if npc_system.is_npc_world_movement_active(NPC_ID):
		_fail("T0259 could not create the stale target-locked pickup fixture")
		return
	var repeat_alarm: Dictionary = combat_system.trigger_combat_alarm("t0259_repeat_alarm_recovery")
	await process_frame
	await physics_frame
	var after_repeat: Dictionary = npc_system.get_npc_state(NPC_ID)
	if str(after_repeat.get("combat_target_enemy_id", "")) != enemy_id:
		_fail("T0259 repeat alarm changed the valid combat target: %s" % after_repeat)
		return
	if not npc_system.is_npc_world_movement_active(NPC_ID):
		_fail("T0259 repeat alarm did not recover the target-locked mount route: %s" % repeat_alarm)
		return
	if int(repeat_alarm.get("mount_route_recovered_count", 0)) < 1:
		_fail("T0259 repeat alarm did not report the recovered mount route: %s" % repeat_alarm)
		return

	var mounted := false
	for _frame in range(MAX_MOUNT_FRAMES):
		await physics_frame
		_set_enemy_position(combat_system, enemy_id, RIDER_START + Vector3(0.0, 0.0, 120.0))
		if bool(npc_system.get_npc_state(NPC_ID).get("combat_mounted", false)):
			mounted = true
			break
	if not mounted:
		_fail("T0259 rider never completed the recovered mount pickup: state=%s horse=%s" % [npc_system.get_npc_state(NPC_ID), horse_system.get_horse_snapshot(horse_id)])
		return

	var final_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	print("T0259_MOUNT_PICKUP_ENEMY_HANDOFF_METRICS=%s" % JSON.stringify({
		"enemy_id": enemy_id,
		"target_preserved_after_repeat_alarm": str(after_repeat.get("combat_target_enemy_id", "")),
		"repeat_alarm_target_locked_count": int(repeat_alarm.get("target_locked_count", 0)),
		"repeat_alarm_mount_route_recovered_count": int(repeat_alarm.get("mount_route_recovered_count", 0)),
		"mounted": bool(final_state.get("combat_mounted", false)),
		"final_mode": str(final_state.get("behavior_mode", "")),
		"final_action": str(final_state.get("current_action", "")),
	}))
	print("T0259 mount pickup enemy handoff verification passed.")
	quit(0)


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	enemy["target"] = {}
	combat_system._active_enemies[enemy_id] = enemy
	var actor_path: NodePath = combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	var actor := combat_system.get_node_or_null(actor_path) as Node3D
	if actor != null:
		if actor.has_method("stop_movement"):
			actor.stop_movement()
		actor.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node3D:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath(""))) as Node3D


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
