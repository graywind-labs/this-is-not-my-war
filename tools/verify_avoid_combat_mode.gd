extends SceneTree

var _reevaluation_signal_count := 0


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var event_bus := root.get_node_or_null("EventBus")
	if (
		combat_system == null
		or npc_system == null
		or memory_system == null
		or gm_panel == null
		or daily_plan_system == null
		or event_bus == null
	):
		push_error("Avoid-combat verification required nodes not found")
		quit(1)
		return

	for raw_connection in event_bus.npc_plan_reevaluation_requested.get_connections():
		var connection: Dictionary = raw_connection
		var callable: Callable = connection.get("callable", Callable())
		if callable.get_object() == daily_plan_system:
			event_bus.npc_plan_reevaluation_requested.disconnect(callable)
	event_bus.npc_plan_reevaluation_requested.connect(func(_npc_id: String, _reason: String) -> void:
		_reevaluation_signal_count += 1
	)

	var cook_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01") as Node3D
	if cook_node == null:
		push_error("Cook node missing")
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var contact_position := enemy_position + Vector3(0.0, 0.0, -3.0)
	cook_node.global_position = contact_position

	combat_system.debug_step_enemy_ai(0.1)
	await process_frame
	if _mode(npc_system, "cook_01") != "avoid_combat":
		push_error("Unrecruited working NPC should enter avoid_combat on enemy proximity")
		quit(1)
		return
	var cook_state: Dictionary = npc_system.get_npc_state("cook_01")
	if str(cook_state.get("combat_mode", "")) != "":
		push_error("Avoiding unrecruited NPC should not be marked as combat personnel")
		quit(1)
		return
	if str(cook_state.get("current_action", "")).begins_with("attacking_") or str(cook_state.get("current_action", "")) == "combat_ready":
		push_error("Avoiding unrecruited NPC should not attack or enter combat_ready")
		quit(1)
		return
	var cook_avoidance := _find_avoidance(combat_system.get_active_avoidances(), "cook_01")
	if cook_avoidance.is_empty():
		push_error("Avoiding NPC should have an active avoidance target")
		quit(1)
		return
	var target_position := _dict_to_vector3(cook_avoidance.get("target_position", {}))
	if not _inside_station_avoidance_bounds(target_position):
		push_error("Avoidance target should stay inside the station bounds: %s" % str(target_position))
		quit(1)
		return
	if target_position.distance_to(enemy_position) <= contact_position.distance_to(enemy_position):
		push_error("Avoidance target should be farther from the enemy than the contact position")
		quit(1)
		return
	if not _npc_has_event(memory_system, "cook_01", "npc_mode_changed"):
		push_error("Avoidance mode switch should write npc_mode_changed")
		quit(1)
		return
	if not _npc_has_event(memory_system, "cook_01", "avoidance_started"):
		push_error("Avoidance start should write avoidance_started")
		quit(1)
		return
	print("[T1103B] proximity avoidance checked")

	gm_panel._execute_command("avoid_npc engineer_01")
	await process_frame
	if _find_avoidance(combat_system.get_active_avoidances(), "engineer_01").is_empty():
		push_error("GM avoid_npc command should expose avoidance trigger and target snapshot")
		quit(1)
		return

	var reevaluations_before_clear := _reevaluation_signal_count
	combat_system.debug_clear_enemies()
	await process_frame
	if _mode(npc_system, "cook_01") != "work" or _mode(npc_system, "engineer_01") != "work":
		push_error("Avoiding NPCs should return to work when enemies are cleared")
		quit(1)
		return
	if _reevaluation_signal_count != reevaluations_before_clear:
		push_error("Avoidance exit should not request plan reevaluation")
		quit(1)
		return
	if not _npc_has_event(memory_system, "cook_01", "avoidance_ended"):
		push_error("Avoidance end should write avoidance_ended")
		quit(1)
		return
	print("[T1103B] avoidance clear checked")

	spawn_result = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn for sleep test failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	enemy_id = str(combat_system.get_active_enemy_ids()[0])
	enemy = combat_system.get_enemy(enemy_id)
	enemy_position = enemy.get("position", Vector3.ZERO)
	var doctor_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Doctor01") as Node3D
	var gardener_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Gardener01") as Node3D
	if doctor_node == null or gardener_node == null:
		push_error("Doctor or gardener node missing")
		quit(1)
		return
	npc_system.update_npc_state("doctor_01", {"current_action": "sleep_in_dormitory"})
	doctor_node.global_position = enemy_position + Vector3(0.0, 0.0, -3.0)
	combat_system.debug_step_enemy_ai(0.1)
	await process_frame
	if _mode(npc_system, "doctor_01") == "avoid_combat":
		push_error("Sleeping unrecruited NPC should not avoid from proximity alone")
		quit(1)
		return
	npc_system.update_npc_state("gardener_01", {"current_action": "sleep_in_dormitory"})
	gardener_node.global_position = enemy_position + Vector3(0.0, 0.0, -3.0)
	npc_system.apply_damage_to_npc("gardener_01", 1, enemy_id, "local_public", {
		"enemy_attack": true,
		"request_plan_reevaluation": false
	})
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "gardener_01") != "avoid_combat":
		push_error("Sleeping unrecruited NPC should enter avoid_combat when attacked")
		quit(1)
		return
	if _find_avoidance(combat_system.get_active_avoidances(), "gardener_01").is_empty():
		push_error("Attacked sleeping NPC should receive an avoidance target after mode switch")
		quit(1)
		return
	print("[T1103B] sleeping exception checked")

	combat_system.debug_clear_enemies()
	spawn_result = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn for recruitment routing failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	enemy_id = str(combat_system.get_active_enemy_ids()[0])
	enemy = combat_system.get_enemy(enemy_id)
	enemy_position = enemy.get("position", Vector3.ZERO)
	var priest_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Priest01") as Node3D
	if priest_node == null:
		push_error("Priest node missing")
		quit(1)
		return
	priest_node.global_position = enemy_position + Vector3(0.0, 0.0, -3.0)
	combat_system.debug_step_enemy_ai(0.1)
	await process_frame
	if _mode(npc_system, "priest_01") != "avoid_combat":
		push_error("Priest should be avoiding before recruitment routing test")
		quit(1)
		return
	npc_system.set_npc_recruited("priest_01", true)
	await process_frame
	if _mode(npc_system, "priest_01") != "combat":
		push_error("NPC recruited during avoidance should enter combat while enemies remain")
		quit(1)
		return
	if not _find_avoidance(combat_system.get_active_avoidances(), "priest_01").is_empty():
		push_error("Avoidance snapshot should be cleared after recruited NPC enters combat")
		quit(1)
		return
	print("[T1103B] recruitment-to-combat routing checked")

	combat_system.debug_clear_enemies()
	npc_system.set_npc_behavior_mode("blacksmith_01", "avoid_combat", "verify_no_enemy_recruit", {
		"state_changes": {"current_action": "avoid_combat"},
		"request_plan_reevaluation": false
	})
	npc_system.set_npc_recruited("blacksmith_01", true)
	await process_frame
	if _mode(npc_system, "blacksmith_01") != "work":
		push_error("NPC recruited during avoidance with no enemies should return to work")
		quit(1)
		return

	print("T1103B avoid-combat mode verification passed.")
	quit(0)


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))


func _find_avoidance(avoidances: Array, npc_id: String) -> Dictionary:
	for raw_avoidance in avoidances:
		var avoidance: Dictionary = raw_avoidance
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _dict_to_vector3(raw_value: Variant) -> Vector3:
	if raw_value is Vector3:
		return raw_value
	var data: Dictionary = raw_value if raw_value is Dictionary else {}
	return Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)


func _inside_station_avoidance_bounds(position: Vector3) -> bool:
	return absf(position.x) <= 13.0 and position.z >= -12.5 and position.z <= 6.5


func _npc_has_event(memory_system: Node, npc_id: String, event_type: String) -> bool:
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type:
			return true
	return false
