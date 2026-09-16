extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const COMBAT_NPC_ID := "veteran_deputy_01"
const CIVILIAN_NPC_ID := "cook_01"
const UNARMED_RECRUIT_ID := "stableman_01"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(not [combat_system, npc_system, action_system, memory_system, station_controller, time_system].has(null), "T0421 runtime dependencies unavailable")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	# Exercise both civilian reasons: never recruited, and recruited but unarmed.
	npc_system.set_npc_recruited(UNARMED_RECRUIT_ID, true)
	npc_system.set_npc_equipment_slot(UNARMED_RECRUIT_ID, "main_weapon", {})
	var combat_identity: Dictionary = npc_system.get_npc_combat_identity(COMBAT_NPC_ID)
	_check(bool(combat_identity.get("recruited", false)) and bool(combat_identity.get("has_main_weapon", false)), "T0421 veteran fixture is not combat eligible")

	var combat_sleep: Dictionary = action_system.stage_npc_sleep_for_tutorial(COMBAT_NPC_ID)
	var civilian_sleep: Dictionary = action_system.stage_npc_sleep_for_tutorial(CIVILIAN_NPC_ID)
	_check(bool(combat_sleep.get("ok", false)), "T0421 could not stage armed recruit sleep: %s" % combat_sleep)
	_check(bool(civilian_sleep.get("ok", false)), "T0421 could not stage civilian sleep: %s" % civilian_sleep)
	if not _failures.is_empty():
		_finish()
		return
	var combat_safe_position: Vector3 = station_controller.get_building_spatial_route(
		str(combat_sleep.get("building_id", "")),
		str(combat_sleep.get("workstation_id", ""))
	).get("interior_target_position", Vector3.ZERO)
	var civilian_safe_position: Vector3 = station_controller.get_building_spatial_route(
		str(civilian_sleep.get("building_id", "")),
		str(civilian_sleep.get("workstation_id", ""))
	).get("interior_target_position", Vector3.ZERO)

	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true, true)
	_check(bool(spawn.get("ok", false)), "T0421 enemy spawn failed: %s" % spawn)
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0421 enemy fixture is empty")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(enemy_ids.size()):
		_set_enemy_position(combat_system, str(enemy_ids[index]), Vector3(0.0, 0.0, 150.0 + float(index) * 2.0))
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(npc_system.is_npc_sleeping(COMBAT_NPC_ID), "T0421 an outside spawn woke the armed sleeper")
	_check(npc_system.is_npc_sleeping(CIVILIAN_NPC_ID), "T0421 an outside spawn woke the civilian sleeper")

	var intruder_id := str(enemy_ids[0])
	var intruder_position := _find_far_station_point(station_controller, [
		npc_system.get_npc_world_position(COMBAT_NPC_ID),
		npc_system.get_npc_world_position(CIVILIAN_NPC_ID)
	])
	_check(station_controller.is_world_position_inside_station(intruder_position), "T0421 could not select an interior intruder point")
	_check(intruder_position.distance_to(civilian_safe_position) > combat_system._get_avoidance_trigger_range(), "T0421 standby fixture is inside civilian avoidance range")
	combat_system._tutorial_raid_active = true
	_set_enemy_position(combat_system, intruder_id, intruder_position)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(npc_system.is_npc_sleeping(COMBAT_NPC_ID), "T0421 formal breach routing leaked into the tutorial raid")
	_check(npc_system.is_npc_sleeping(CIVILIAN_NPC_ID), "T0421 tutorial raid woke a civilian sleeper")
	_check(_count_event(memory_system, COMBAT_NPC_ID, "enemy_breach_combat_response") == 0, "T0421 tutorial raid wrote a formal breach event")
	_set_enemy_position(combat_system, intruder_id, Vector3(0.0, 0.0, 150.0))
	combat_system._tutorial_raid_active = false
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame

	_set_enemy_position(combat_system, intruder_id, intruder_position)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame

	var combat_state: Dictionary = npc_system.get_npc_state(COMBAT_NPC_ID)
	var civilian_state: Dictionary = npc_system.get_npc_state(CIVILIAN_NPC_ID)
	var unarmed_state: Dictionary = npc_system.get_npc_state(UNARMED_RECRUIT_ID)
	_check(str(combat_state.get("behavior_mode", "")) == "combat", "T0421 armed recruit did not enter combat")
	_check(str(civilian_state.get("behavior_mode", "")) == "avoid_combat", "T0421 civilian did not enter avoidance standby")
	_check(str(unarmed_state.get("behavior_mode", "")) == "avoid_combat", "T0421 unarmed recruit did not enter avoidance")
	_check(not npc_system.is_npc_sleeping(COMBAT_NPC_ID), "T0421 armed recruit remained asleep after breach")
	_check(not npc_system.is_npc_sleeping(CIVILIAN_NPC_ID), "T0421 civilian remained asleep after breach")
	_check(_npc_position(npc_system, COMBAT_NPC_ID).distance_to(combat_safe_position) <= 0.1, "T0421 armed sleeper did not exit at the bed stand point")
	_check(_npc_position(npc_system, CIVILIAN_NPC_ID).distance_to(civilian_safe_position) <= 0.1, "T0421 civilian sleeper did not exit at the bed stand point")
	_check(not _attachment_active(npc_system, COMBAT_NPC_ID), "T0421 armed sleeper remained attached to the bed")
	_check(not _attachment_active(npc_system, CIVILIAN_NPC_ID), "T0421 civilian sleeper remained attached to the bed")
	_check(_find_avoidance(combat_system.get_active_avoidances(), CIVILIAN_NPC_ID).is_empty(), "T0421 far civilian started moving instead of holding avoidance standby")

	_check(_count_event(memory_system, COMBAT_NPC_ID, "enemy_breach_combat_response") == 1, "T0421 combat response event was not written exactly once")
	_check(_count_event(memory_system, CIVILIAN_NPC_ID, "enemy_breach_noncombat_response") == 1, "T0421 civilian response event was not written exactly once")
	_check(_count_event(memory_system, UNARMED_RECRUIT_ID, "enemy_breach_noncombat_response") == 1, "T0421 unarmed recruit response event was not written exactly once")
	_check(_event_summary(memory_system, COMBAT_NPC_ID, "enemy_breach_combat_response").contains("已经入伍并握有武器"), "T0421 combat event copy is incorrect")
	_check(_event_summary(memory_system, CIVILIAN_NPC_ID, "enemy_breach_noncombat_response").contains("尚未入伍"), "T0421 unrecruited event copy is incorrect")
	_check(_event_summary(memory_system, UNARMED_RECRUIT_ID, "enemy_breach_noncombat_response").contains("手中没有可用武器"), "T0421 unarmed recruit event copy is incorrect")

	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(_count_event(memory_system, COMBAT_NPC_ID, "enemy_breach_combat_response") == 1, "T0421 repeated contact duplicated the combat event")
	_check(_count_event(memory_system, CIVILIAN_NPC_ID, "enemy_breach_noncombat_response") == 1, "T0421 repeated contact duplicated the civilian event")

	var near_position := _find_near_station_point(station_controller, _npc_position(npc_system, CIVILIAN_NPC_ID))
	_set_enemy_position(combat_system, intruder_id, near_position)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(not _find_avoidance(combat_system.get_active_avoidances(), CIVILIAN_NPC_ID).is_empty(), "T0421 nearby intruder did not activate existing avoidance movement")

	print("T0421_STATION_BREACH_RESPONSE_OK %s" % JSON.stringify({
		"intruder_position": intruder_position,
		"combat_summary": _event_summary(memory_system, COMBAT_NPC_ID, "enemy_breach_combat_response"),
		"civilian_summary": _event_summary(memory_system, CIVILIAN_NPC_ID, "enemy_breach_noncombat_response"),
		"unarmed_summary": _event_summary(memory_system, UNARMED_RECRUIT_ID, "enemy_breach_noncombat_response")
	}))
	combat_system.debug_clear_enemies()
	_finish()


func _find_far_station_point(station_controller: Node, origins: Array) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := -1.0
	for x in range(-50, 51, 5):
		for z in range(-50, 51, 5):
			var candidate: Vector3 = Vector3(float(x), 0.0, float(z))
			if not station_controller.is_world_position_inside_station(candidate):
				continue
			var nearest_distance := INF
			for origin in origins:
				nearest_distance = minf(nearest_distance, candidate.distance_to(origin as Vector3))
			if nearest_distance > best_distance:
				best = candidate
				best_distance = nearest_distance
	return best


func _find_near_station_point(station_controller: Node, origin: Vector3) -> Vector3:
	for offset in [Vector3(2.5, 0.0, 0.0), Vector3(-2.5, 0.0, 0.0), Vector3(0.0, 0.0, 2.5), Vector3(0.0, 0.0, -2.5)]:
		var candidate: Vector3 = origin + (offset as Vector3)
		if station_controller.is_world_position_inside_station(candidate):
			return candidate
	return origin


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	combat_system._active_enemies[enemy_id] = enemy
	var actor := combat_system.get_node_or_null(combat_system._enemy_nodes.get(enemy_id, NodePath())) as Node3D
	if actor != null:
		if actor.has_method("stop_movement"):
			actor.stop_movement()
		actor.global_position = position


func _npc_position(npc_system: Node, npc_id: String) -> Vector3:
	return npc_system.get_npc_world_position(npc_id) as Vector3


func _attachment_active(npc_system: Node, npc_id: String) -> bool:
	var actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath()))
	return actor != null and bool(actor.debug_get_spatial_attachment_snapshot().get("active", false))


func _find_avoidance(avoidances: Array, npc_id: String) -> Dictionary:
	for raw_avoidance in avoidances:
		var avoidance: Dictionary = raw_avoidance
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _count_event(memory_system: Node, npc_id: String, event_type: String) -> int:
	var count := 0
	for event in memory_system.get_npc_daily_events(npc_id):
		if str(event.get("type", "")) == event_type:
			count += 1
	return count


func _event_summary(memory_system: Node, npc_id: String, event_type: String) -> String:
	for event in memory_system.get_npc_daily_events(npc_id):
		if str(event.get("type", "")) == event_type:
			return str(event.get("summary", ""))
	return ""


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
