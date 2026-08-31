extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const COMBATANT_ID := "veteran_deputy_01"
const NONCOMBATANT_ID := "cook_01"
const POSITION_EPSILON := 0.01
const MAX_FIRST_FRAME_DISPLACEMENT := 0.35

var _failures: PackedStringArray = []


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	_check(
		npc_system != null
		and combat_system != null
		and daily_plan_system != null
		and equipment_system != null
		and resource_system != null
		and hud != null,
		"T0256 runtime dependencies are missing"
	)
	if not _failures.is_empty():
		_finish({})
		return

	var alarm_button := hud.get_node_or_null("AlarmButton") as Button
	var dismiss_button := hud.get_node_or_null("DismissRallyButton") as Button
	_check(alarm_button != null and dismiss_button != null, "HUD alarm/dismiss buttons are missing")
	if alarm_button != null and dismiss_button != null:
		_check(dismiss_button.text == "解散", "Dismiss button text is incorrect")
		_check(dismiss_button.position.x >= alarm_button.position.x + alarm_button.size.x, "Dismiss button is not beside the alarm")
		_check(dismiss_button.position.x - (alarm_button.position.x + alarm_button.size.x) <= 16.0, "Alarm/dismiss button gap is too large")
		_check(dismiss_button.pressed.is_connected(Callable(hud, "_on_dismiss_rally_button_pressed")), "Dismiss button is not connected to the HUD handler")
	if not _failures.is_empty():
		_finish({})
		return

	daily_plan_system.set_auto_execution_enabled(false)
	_check(daily_plan_system.set_npc_daily_plan(COMBATANT_ID, _make_work_plan("work_garden"), false, "t0256"), "Could not install combatant plan")
	_check(daily_plan_system.set_npc_daily_plan(NONCOMBATANT_ID, _make_work_plan("work_dining_hall"), false, "t0256"), "Could not install noncombatant plan")
	npc_system.set_npc_recruited(COMBATANT_ID, true)
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(COMBATANT_ID, "sword_shield", "private")
	_check(bool(equip_result.get("ok", false)), "Could not equip combatant: %s" % equip_result)
	_check(bool(daily_plan_system.execute_current_plan_for_npc(COMBATANT_ID, true).get("ok", false)), "Combatant work plan did not start")
	_check(bool(daily_plan_system.execute_current_plan_for_npc(NONCOMBATANT_ID, true).get("ok", false)), "Noncombatant work plan did not start")
	if not _failures.is_empty():
		_finish({})
		return

	# work -> rally must only replace state/movement authority, never position.
	var work_position := npc_system.get_npc_world_position(COMBATANT_ID) as Vector3
	alarm_button.pressed.emit()
	var rally_position := npc_system.get_npc_world_position(COMBATANT_ID) as Vector3
	_check(_mode(npc_system, COMBATANT_ID) == "rally", "Alarm did not enter rally mode")
	_check(work_position.distance_to(rally_position) <= POSITION_EPSILON, "work -> rally teleported %.3f m" % work_position.distance_to(rally_position))

	# rally -> work through the production HUD button must resume the exact plan.
	var captured_plan_marker: Dictionary = (daily_plan_system.get("_behavior_mode_interrupted_plan_by_npc") as Dictionary).duplicate(true)
	dismiss_button.pressed.emit()
	var dismiss_result: Dictionary = (combat_system.get("_last_mode_transition_result") as Dictionary).duplicate(true)
	var dismissed_position := npc_system.get_npc_world_position(COMBATANT_ID) as Vector3
	var dismissed_state: Dictionary = npc_system.get_npc_state(COMBATANT_ID)
	var dismissed_transition := _find_transition(dismiss_result.get("dismissed", []), COMBATANT_ID)
	var dismissed_resume: Dictionary = dismissed_transition.get("plan_resume_status", {}) if dismissed_transition.get("plan_resume_status", {}) is Dictionary else {}
	_check(_mode(npc_system, COMBATANT_ID) == "work", "Dismiss did not return rallying NPC to work")
	_check(rally_position.distance_to(dismissed_position) <= POSITION_EPSILON, "rally -> work teleported %.3f m" % rally_position.distance_to(dismissed_position))
	_check(bool(dismissed_resume.get("resumed_after_behavior_mode", false)) and str(dismissed_resume.get("status", "")) == "scheduled", "Dismiss did not schedule the current work plan: marker=%s resume=%s state=%s" % [captured_plan_marker, dismissed_resume, dismissed_state])
	_check(not _find_rally(combat_system.get_active_rallies(), COMBATANT_ID).has("npc_id"), "Dismiss retained the active rally runtime")
	var ignored_combat_probe: Dictionary = npc_system.set_npc_behavior_mode(NONCOMBATANT_ID, "avoid_combat", "t0256_dismiss_scope", {"state_changes": {"current_action": "avoid_combat"}})
	dismiss_button.pressed.emit()
	_check(bool(ignored_combat_probe.get("ok", false)) and _mode(npc_system, NONCOMBATANT_ID) == "avoid_combat", "Dismiss changed a non-rally behavior mode")
	npc_system.set_npc_behavior_mode(NONCOMBATANT_ID, "work", "t0256_scope_reset", {"force_idle": true, "resume_current_plan": true})

	var after_dismiss_frame := dismissed_position
	await physics_frame
	after_dismiss_frame = npc_system.get_npc_world_position(COMBATANT_ID) as Vector3
	_check(dismissed_position.distance_to(after_dismiss_frame) <= MAX_FIRST_FRAME_DISPLACEMENT, "Resumed work exceeded smooth first-frame movement bound")
	var resumed_work_route := str(npc_system.get_npc_state(COMBATANT_ID).get("current_action", "")).contains("garden")
	for _frame in range(30):
		if resumed_work_route:
			break
		await physics_frame
		resumed_work_route = str(npc_system.get_npc_state(COMBATANT_ID).get("current_action", "")).contains("garden")
	_check(resumed_work_route, "Dismissed NPC did not enter its resumed work route")

	# Put both actors close together while retaining their running plans. Spawning
	# the formal wave performs the combat-world authority handoff and must preserve
	# these exact entry coordinates.
	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var combatant_node := npc_system.get_node_or_null(npc_paths.get(COMBATANT_ID, NodePath())) as Node3D
	var noncombatant_node := npc_system.get_node_or_null(npc_paths.get(NONCOMBATANT_ID, NodePath())) as Node3D
	_check(combatant_node != null and noncombatant_node != null, "Formal NPC nodes are missing")
	if not _failures.is_empty():
		_finish({})
		return
	combatant_node.global_position = Vector3(-0.5, 0.0, 4.0)
	noncombatant_node.global_position = Vector3(0.5, 0.0, 4.0)
	var combat_entry := combatant_node.global_position
	var avoid_entry := noncombatant_node.global_position
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn_result.get("ok", false)), "Could not spawn transition fixture: %s" % spawn_result)
	_check(combat_entry.distance_to(combatant_node.global_position) <= POSITION_EPSILON, "work -> formal combat world moved combatant")
	_check(avoid_entry.distance_to(noncombatant_node.global_position) <= POSITION_EPSILON, "work -> formal combat world moved noncombatant")
	var enemy_id := _place_first_enemy(combat_system, Vector3(0.0, 0.0, 5.5))
	_check(not enemy_id.is_empty(), "No enemy was available for contact fixture")
	var combat_before_contact := combatant_node.global_position
	var avoid_before_contact := noncombatant_node.global_position
	combat_system.debug_step_enemy_ai(0.0)
	var combat_after_contact := combatant_node.global_position
	var avoid_after_contact := noncombatant_node.global_position
	_check(_mode(npc_system, COMBATANT_ID) == "combat", "Armed working NPC did not enter direct combat")
	_check(_mode(npc_system, NONCOMBATANT_ID) == "avoid_combat", "Unarmed working NPC did not enter avoidance")
	_check(combat_before_contact.distance_to(combat_after_contact) <= POSITION_EPSILON, "work -> combat teleported %.3f m" % combat_before_contact.distance_to(combat_after_contact))
	_check(avoid_before_contact.distance_to(avoid_after_contact) <= POSITION_EPSILON, "work -> avoid teleported %.3f m" % avoid_before_contact.distance_to(avoid_after_contact))

	var clear_result: Dictionary = combat_system.debug_clear_enemies()
	var combat_after_clear := combatant_node.global_position
	var avoid_after_clear := noncombatant_node.global_position
	_check(_mode(npc_system, COMBATANT_ID) == "work", "Combatant did not return to work after enemies cleared")
	_check(_mode(npc_system, NONCOMBATANT_ID) == "work", "Avoiding NPC did not return to work after enemies cleared")
	_check(combat_after_contact.distance_to(combat_after_clear) <= POSITION_EPSILON, "combat -> work teleported %.3f m" % combat_after_contact.distance_to(combat_after_clear))
	_check(avoid_after_contact.distance_to(avoid_after_clear) <= POSITION_EPSILON, "avoid -> work teleported %.3f m" % avoid_after_contact.distance_to(avoid_after_clear))
	var avoid_exit := _find_transition((clear_result.get("mode_exit_result", {}) as Dictionary).get("avoid_to_work", []), NONCOMBATANT_ID)
	var avoid_resume: Dictionary = avoid_exit.get("plan_resume_status", {}) if avoid_exit.get("plan_resume_status", {}) is Dictionary else {}
	_check(bool(avoid_resume.get("resumed_after_behavior_mode", false)) and str(avoid_resume.get("status", "")) == "scheduled", "Avoidance exit did not schedule current-plan resume: %s" % avoid_exit)

	var combat_frame_start := combatant_node.global_position
	var avoid_frame_start := noncombatant_node.global_position
	await physics_frame
	_check(combat_frame_start.distance_to(combatant_node.global_position) <= MAX_FIRST_FRAME_DISPLACEMENT, "Post-combat work movement jumped on first frame")
	_check(avoid_frame_start.distance_to(noncombatant_node.global_position) <= MAX_FIRST_FRAME_DISPLACEMENT, "Post-avoid work movement jumped on first frame")
	var avoidance_plan_resumed := str(npc_system.get_npc_state(NONCOMBATANT_ID).get("current_action", "")).contains("dining_hall")
	for _frame in range(30):
		if avoidance_plan_resumed:
			break
		await physics_frame
		avoidance_plan_resumed = str(npc_system.get_npc_state(NONCOMBATANT_ID).get("current_action", "")).contains("dining_hall")
	_check(avoidance_plan_resumed, "Avoiding NPC did not enter its resumed current-plan route")

	_finish({
		"work_to_rally": work_position.distance_to(rally_position),
		"rally_to_work": rally_position.distance_to(dismissed_position),
		"work_to_combat": combat_before_contact.distance_to(combat_after_contact),
		"combat_to_work": combat_after_contact.distance_to(combat_after_clear),
		"work_to_avoid": avoid_before_contact.distance_to(avoid_after_contact),
		"avoid_to_work": avoid_after_contact.distance_to(avoid_after_clear),
		"avoid_resume_status": avoid_resume.get("status", "")
	})


func _make_work_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0256 behavior-mode continuity verification",
			"source": "t0256"
		})
	return plan


func _mode(npc_system: Node, npc_id: String) -> String:
	return str(npc_system.get_npc_behavior_mode_snapshot(npc_id).get("behavior_mode", ""))


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _find_transition(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _place_first_enemy(combat_system: Node, position: Vector3) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	var enemy_id := str(enemy_ids[0])
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = position
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnemies")
	if formal_root != null:
		for child in formal_root.get_children():
			if str(child.get_meta("enemy_id", "")) == enemy_id and child is Node3D:
				(child as Node3D).global_position = position
				if child.has_method("set_motion_paused"):
					child.set_motion_paused(true)
				break
	return enemy_id


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	print("T0256_MODE_TRANSITION_CONTINUITY_METRICS=%s" % JSON.stringify(metrics))
	if _failures.is_empty():
		print("T0256 mode transition continuity verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
