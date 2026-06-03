extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var event_bus := root.get_node_or_null("EventBus")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if event_bus == null or npc_system == null or action_system == null or memory_system == null or resource_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var target_id := "cook_01"
	var healer_id := "doctor_01"
	var second_healer_id := "engineer_01"
	var third_healer_id := "priest_01"
	var witness_id := "gardener_01"
	for npc_id in [target_id, healer_id, second_healer_id, third_healer_id, witness_id]:
		if not npc_system.debug_enter_location_immediately(npc_id, "clinic"):
			push_error("Failed to place NPC in clinic: %s" % npc_id)
			quit(1)
			return

	var damage_result: Dictionary = npc_system.debug_damage_npc(target_id, 150, "local_public")
	if damage_result.is_empty() or not bool(damage_result.get("ok", false)):
		push_error("Failed to make target unconscious")
		quit(1)
		return

	var money_before: int = resource_system.get_resource("money")
	if not action_system.debug_assign_heal_assist(healer_id, target_id):
		push_error("Doctor should be able to assist healing an unconscious NPC")
		quit(1)
		return
	if resource_system.get_resource("money") != money_before - 1:
		push_error("Healing should spend initial money when started")
		quit(1)
		return
	if not action_system.debug_assign_heal_assist(second_healer_id, target_id):
		push_error("Second healer should be able to assist the same unconscious NPC")
		quit(1)
		return
	if action_system.debug_assign_heal_assist(third_healer_id, target_id):
		push_error("Third healer should be rejected because target already has two helpers")
		quit(1)
		return

	var healer_state: Dictionary = npc_system.get_npc_state(healer_id)
	if not str(healer_state.get("current_action", "")).begins_with("assist_heal_"):
		push_error("Healer current_action should show assist_heal target")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(healer_id), "healing_started"):
		push_error("Healer event_log missing healing_started")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "healing_started"):
		push_error("Target event_log missing healing_started")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_witness_events(witness_id), "healing_started"):
		push_error("Witness log missing local_public healing_started")
		quit(1)
		return
	if _has_healing_event(memory_system.get_npc_witness_events(healer_id), healer_id, target_id):
		push_error("Healer should not receive their own healing event as witness")
		quit(1)
		return
	if _has_event(memory_system.get_npc_witness_events(target_id), "healing_started"):
		push_error("Unconscious target should not receive healing event as witness")
		quit(1)
		return
	var clinic_snapshot: Dictionary = memory_system.debug_get_location_snapshot("clinic")
	var clinic_statuses: Array = clinic_snapshot.get("building", {}).get("internal_state", {}).get("people_statuses", [])
	if not _has_status_with_text(clinic_statuses, target_id, "unconscious", "正在治疗"):
		push_error("Clinic snapshot should expose unconscious target and active healer")
		quit(1)
		return
	if not _has_status_with_text(clinic_statuses, healer_id, "healthy", "协助治疗布鲁诺"):
		push_error("Clinic snapshot should expose healer action as concise Chinese")
		quit(1)
		return
	var healing_event: Dictionary = _first_event(memory_system.get_npc_daily_events(healer_id), "healing_started")
	if _event_exposes_medical_skill(healing_event):
		push_error("Healing event should not expose medical skill")
		quit(1)
		return

	event_bus.logical_time_tick.emit(3600.0, 1.0)
	var one_hour_state: Dictionary = npc_system.get_npc_state(target_id)
	if int(one_hour_state.get("hp", 0)) <= 2:
		push_error("Healing should recover faster than natural recovery after one hour")
		quit(1)
		return
	if int(resource_system.get_resource("money")) >= money_before - 2:
		push_error("Healing should continue spending money over time")
		quit(1)
		return

	event_bus.logical_time_tick.emit(3.0 * 3600.0, 1.0)
	var revived_state: Dictionary = npc_system.get_npc_state(target_id)
	if bool(revived_state.get("unconscious", true)):
		push_error("Assisted healing should revive target after enough logical time")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "revived"):
		push_error("Target event_log missing revived after healing")
		quit(1)
		return
	var revived_event: Dictionary = _first_event(memory_system.get_npc_daily_events(target_id), "revived")
	if _event_exposes_hp_recovery(revived_event):
		push_error("Revived event summary should not expose HP recovery amount")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(healer_id), "healing_completed"):
		push_error("Healer event_log missing healing_completed")
		quit(1)
		return
	var healing_completed_event: Dictionary = _first_event(memory_system.get_npc_daily_events(healer_id), "healing_completed")
	if _event_exposes_medical_skill(healing_completed_event):
		push_error("Healing completed event should not expose medical skill")
		quit(1)
		return
	if _event_exposes_completion_reason(healing_completed_event):
		push_error("Healing completed event should not expose a reason field")
		quit(1)
		return

	var no_money_target_id := "stableman_01"
	if not npc_system.debug_enter_location_immediately(no_money_target_id, "clinic"):
		push_error("Failed to place no-money target in clinic")
		quit(1)
		return
	npc_system.debug_damage_npc(no_money_target_id, 150, "local_public")
	var remaining_money: int = resource_system.get_resource("money")
	if remaining_money > 0 and not resource_system.debug_spend_resources({"money": remaining_money}):
		push_error("Failed to drain money for insufficient-resource check")
		quit(1)
		return
	if action_system.debug_assign_heal_assist(third_healer_id, no_money_target_id):
		push_error("Healing should fail when money is insufficient")
		quit(1)
		return

	print("T0503 NPC unconscious healing verification passed.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return true
	return false


func _first_event(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _event_exposes_medical_skill(event: Dictionary) -> bool:
	var payload: Dictionary = event.get("payload", {})
	var summary := str(event.get("summary", ""))
	return payload.has("medical_skill") or summary.contains("医术熟练度")


func _event_exposes_hp_recovery(event: Dictionary) -> bool:
	var summary := str(event.get("summary", ""))
	return summary.contains("HP") or summary.contains("恢复到")


func _event_exposes_completion_reason(event: Dictionary) -> bool:
	var payload: Dictionary = event.get("payload", {})
	var summary := str(event.get("summary", ""))
	return payload.has("reason") or summary.contains("原因")


func _has_healing_event(events: Array, healer_npc_id: String, target_npc_id: String) -> bool:
	for event in events:
		if not event is Dictionary:
			continue
		if str(event.get("type", "")) != "healing_started":
			continue
		var payload: Dictionary = event.get("payload", {})
		if str(payload.get("healer_npc_id", "")) == healer_npc_id and str(payload.get("target_npc_id", "")) == target_npc_id:
			return true
	return false


func _has_status_with_text(statuses: Array, npc_id: String, life_status: String, expected_text: String) -> bool:
	for raw_status in statuses:
		if not raw_status is Dictionary:
			continue
		var status: Dictionary = raw_status
		if str(status.get("npc_id", "")) != npc_id:
			continue
		if str(status.get("life_status", "")) != life_status:
			continue
		var combined_text := "%s %s" % [
			str(status.get("life_status_text", "")),
			str(status.get("action_status", ""))
		]
		if combined_text.contains(expected_text):
			return true
	return false
