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
	print("[T1103A] main scene ready")

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var event_bus := root.get_node_or_null("EventBus")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or gm_panel == null
		or daily_plan_system == null
		or event_bus == null
	):
		push_error("Behavior mode verification required nodes not found")
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
	print("[T1103A] systems ready")

	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("weapons", 5)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	if not bool(equip_result.get("ok", false)):
		push_error("Failed to equip stableman: %s" % JSON.stringify(equip_result))
		quit(1)
		return

	var alarm_result: Dictionary = combat_system.debug_trigger_combat_alarm()
	if not bool(alarm_result.get("ok", false)):
		push_error("Alarm failed: %s" % JSON.stringify(alarm_result))
		quit(1)
		return
	if _mode(npc_system, "stableman_01") != "rally":
		push_error("Armed recruited NPC should enter behavior_mode=rally")
		quit(1)
		return
	if not _npc_has_mode_event(memory_system, "stableman_01", "work", "rally"):
		push_error("Rally mode switch should write npc_mode_changed")
		quit(1)
		return
	print("[T1103A] rally mode checked")

	var stableman_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	var stableman_rally := _find_rally(combat_system.get_active_rallies(), "stableman_01")
	if stableman_node == null or stableman_rally.is_empty():
		push_error("Stableman rally node/snapshot missing")
		quit(1)
		return
	stableman_node.global_position = _dict_to_vector3(stableman_rally.get("position", {}))
	var reevaluations_before_timeout := _reevaluation_signal_count
	combat_system.debug_advance_rally_wait(3600.0)
	await process_frame
	if _mode(npc_system, "stableman_01") != "work":
		push_error("Rallied NPC should return to work after 1 in-game hour without contact")
		quit(1)
		return
	if _reevaluation_signal_count != reevaluations_before_timeout:
		push_error("Rally timeout should not request plan reevaluation")
		quit(1)
		return
	print("[T1103A] rally timeout checked")

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	stableman_node.global_position = enemy.get("position", Vector3.ZERO) + Vector3(0.0, 0.0, -1.0)
	combat_system.debug_step_enemy_ai(0.1)
	await process_frame
	if _mode(npc_system, "stableman_01") != "combat":
		push_error("Recruited NPC should enter combat mode on contact")
		quit(1)
		return
	print("[T1103A] contact combat checked")

	var reevaluations_before_clear := _reevaluation_signal_count
	combat_system.debug_clear_enemies()
	await process_frame
	if _mode(npc_system, "stableman_01") != "work":
		push_error("Combat NPC should return to work after enemies are cleared")
		quit(1)
		return
	if _reevaluation_signal_count <= reevaluations_before_clear:
		push_error("Combat exit should request plan reevaluation")
		quit(1)
		return
	print("[T1103A] enemy clear checked")

	combat_system.debug_spawn_wave(1, true)
	enemy_id = str(combat_system.get_active_enemy_ids()[0])
	enemy = combat_system.get_enemy(enemy_id)
	stableman_node.global_position = enemy.get("position", Vector3.ZERO) + Vector3(0.0, 0.0, -4.0)
	npc_system.update_npc_state("stableman_01", {"current_action": "sleep_in_dormitory"})
	combat_system.debug_step_enemy_ai(0.1)
	await process_frame
	if _mode(npc_system, "stableman_01") == "combat":
		push_error("Sleeping recruited NPC should not enter combat from proximity alone")
		quit(1)
		return
	npc_system.apply_damage_to_npc("stableman_01", 1, enemy_id, "local_public", {
		"enemy_attack": true,
		"request_plan_reevaluation": false
	})
	if _mode(npc_system, "stableman_01") != "combat":
		push_error("Sleeping recruited NPC should enter combat when attacked")
		quit(1)
		return
	print("[T1103A] sleeping attack checked")

	npc_system.apply_damage_to_npc("cook_01", 999, enemy_id, "local_public", {
		"enemy_attack": true,
		"request_plan_reevaluation": false
	})
	var recover_result: Dictionary = npc_system.debug_advance_unconscious_recovery("cook_01", 20.0 * 3600.0)
	var revived_ids: Array = recover_result.get("revived", []) if (recover_result.get("revived", []) is Array) else []
	if not revived_ids.has("cook_01"):
		push_error("Cook should revive during verification")
		quit(1)
		return
	var cook_mode := _mode(npc_system, "cook_01")
	if cook_mode != "avoid_combat":
		push_error("Unrecruited revived NPC should enter avoid_combat while enemies remain")
		quit(1)
		return
	print("[T1103A] revive routing checked")

	gm_panel._execute_command("behavior_modes")
	gm_panel._execute_command("advance_rally_wait 1")

	print("T1103A behavior mode state machine verification passed.")
	quit(0)


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))


func _find_rally(rallies: Array, npc_id: String) -> Dictionary:
	for raw_rally in rallies:
		var rally: Dictionary = raw_rally
		if str(rally.get("npc_id", "")) == npc_id:
			return rally
	return {}


func _dict_to_vector3(raw_value: Variant) -> Vector3:
	var data: Dictionary = raw_value if raw_value is Dictionary else {}
	return Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)


func _npc_has_mode_event(memory_system: Node, npc_id: String, from_mode: String, to_mode: String) -> bool:
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) != "npc_mode_changed":
			continue
		var payload: Dictionary = event.get("payload", {})
		if str(payload.get("from_mode", "")) == from_mode and str(payload.get("to_mode", "")) == to_mode:
			return true
	return false
