extends SceneTree


class PendingDialogueBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)
	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)

	var request_count := 0

	func request_npc_dialogue_async(_npc_id: String, _text: String, options: Dictionary = {}) -> Dictionary:
		request_count += 1
		return {"ok": true, "pending": true, "request_id": str(options.get("request_id", "t0154_pending"))}

	func cancel_npc_llm_requests(_npc_id: String, reason: String = "cancelled") -> Dictionary:
		return {"ok": true, "cancelled": false, "reason": reason}


const PORTRAIT_NPC_ID := "cook_01"
const ATTACK_NPC_ID := "blacksmith_01"
const LETHAL_NPC_ID := "engineer_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node_or_null("Main/Systems")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [systems, npc_system, dialog_system, daily_plan_system, action_system, memory_system, npc_panel, dialog_panel, original_bridge].has(null):
		_fail("T0154 runtime dependencies unavailable")
		return
	daily_plan_system.set_auto_execution_enabled(false)
	for _frame in range(8):
		await process_frame
		await physics_frame
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		original_bridge.cancel_npc_llm_requests(npc_id, "verify_t0154_isolation")
		action_system.interrupt_npc_action(npc_id, "verify_t0154_fixture")
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"movement_target": "",
			"movement_target_name": "",
			"behavior_mode": "work",
			"unconscious": false,
			"escaped": false,
			"escape_intent": {},
			"last_action_result": "t0154_fixture_ready"
		})
	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var fake_bridge := PendingDialogueBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)

	if not await _verify_portrait_entry(npc_system, memory_system, npc_panel):
		return
	if not await _verify_dialogue_attack_entry(npc_system, dialog_system, memory_system, dialog_panel, fake_bridge):
		return
	if not await _verify_lethal_attack_priority(npc_system, dialog_system, dialog_panel):
		return

	print("T0154 portrait and dialogue hit feedback verification passed.")
	quit(0)


func _verify_portrait_entry(npc_system: Node, memory_system: Node, npc_panel: Control) -> bool:
	var npc_node := _get_npc_node(npc_system, PORTRAIT_NPC_ID)
	if npc_node == null:
		_fail("Portrait NPC world node unavailable")
		return false
	npc_panel.show_npc(PORTRAIT_NPC_ID)
	await process_frame
	var portrait := npc_panel.get_node_or_null("NPCPortraitView")
	if portrait == null or portrait.find_child("PortraitClickButton", true, false) == null:
		_fail("Portrait click surface unavailable")
		return false
	var state_before: Dictionary = npc_system.get_npc_state(PORTRAIT_NPC_ID)
	var position_before: Vector3 = npc_system.get_npc_world_position(PORTRAIT_NPC_ID)
	var memory_count_before := int(memory_system.get_event_count())
	var art_before: Dictionary = npc_node.debug_get_character_art_snapshot()
	var count_before := _presentation_events(npc_system, "portrait_idle_talk_gesture").size()
	portrait.call("_on_portrait_pressed")
	await process_frame
	var portrait_events := _presentation_events(npc_system, "portrait_idle_talk_gesture")
	var art_after: Dictionary = npc_node.debug_get_character_art_snapshot()
	if portrait_events.size() != count_before + 1:
		_fail("Idle portrait click did not emit exactly one gesture event")
		return false
	if (
		int(art_after.get("temporary_presentation_event_count", 0))
		!= int(art_before.get("temporary_presentation_event_count", 0)) + 1
		or str(art_after.get("temporary_presentation_state", "")) != "talk"
	):
		_fail("Idle portrait click did not play one world talk gesture")
		return false
	if (
		npc_system.get_npc_state(PORTRAIT_NPC_ID) != state_before
		or npc_system.get_npc_world_position(PORTRAIT_NPC_ID) != position_before
		or int(memory_system.get_event_count()) != memory_count_before
	):
		_fail("Portrait gesture changed authority state, position, or memory")
		return false
	npc_panel.show_npc(PORTRAIT_NPC_ID)
	npc_panel.show_npc(PORTRAIT_NPC_ID)
	await process_frame
	if _presentation_events(npc_system, "portrait_idle_talk_gesture").size() != portrait_events.size():
		_fail("NPCPanel refresh replayed the portrait gesture")
		return false

	for fixture in [
		{"changes": {"current_action": "work_dining_hall"}, "label": "busy"},
		{"changes": {"current_action": "idle", "movement_target": "plaza"}, "label": "moving"},
		{"changes": {"current_action": "unconscious", "movement_target": "", "unconscious": true}, "label": "unconscious"},
		{"changes": {"current_action": "idle", "unconscious": false, "escaped": true}, "label": "escaped"}
	]:
		npc_system.update_npc_state(PORTRAIT_NPC_ID, fixture["changes"])
		var blocked_before := _presentation_events(npc_system, "portrait_idle_talk_gesture").size()
		portrait.call("_on_portrait_pressed")
		await process_frame
		if _presentation_events(npc_system, "portrait_idle_talk_gesture").size() != blocked_before:
			_fail("%s portrait click incorrectly played a gesture" % str(fixture["label"]))
			return false
	npc_panel.show_npc("")
	portrait.call("_on_portrait_pressed")
	await process_frame
	if _presentation_events(npc_system, "portrait_idle_talk_gesture").size() != portrait_events.size():
		_fail("Invalid portrait target emitted a gesture")
		return false
	npc_system.update_npc_state(PORTRAIT_NPC_ID, {
		"current_action": "idle", "movement_target": "", "unconscious": false, "escaped": false, "behavior_mode": "work"
	})
	return true


func _verify_dialogue_attack_entry(
	npc_system: Node,
	dialog_system: Node,
	memory_system: Node,
	dialog_panel: Control,
	fake_bridge: Node
) -> bool:
	var start_result: Dictionary = dialog_system.start_player_dialogue(ATTACK_NPC_ID)
	if not bool(start_result.get("ok", false)):
		_fail("Attack dialogue could not open")
		return false
	await process_frame
	var hp_before := int(npc_system.get_npc_state(ATTACK_NPC_ID).get("hp", 0))
	var damage_events_before := _count_memory_events(memory_system, ATTACK_NPC_ID, "damage_taken")
	var hit_events_before := _presentation_events(npc_system, "damage_hit_react").size()
	dialog_panel.call("_on_attack_pressed")
	await process_frame
	var confirm_dialog := dialog_panel.get_node_or_null("DialogAttackConfirmationDialog") as ConfirmationDialog
	if confirm_dialog == null or not confirm_dialog.visible:
		_fail("Attack button did not open confirmation")
		return false
	confirm_dialog.hide()
	await process_frame
	if (
		int(npc_system.get_npc_state(ATTACK_NPC_ID).get("hp", 0)) != hp_before
		or _count_memory_events(memory_system, ATTACK_NPC_ID, "damage_taken") != damage_events_before
		or _presentation_events(npc_system, "damage_hit_react").size() != hit_events_before
	):
		_fail("Cancelled attack confirmation caused damage or feedback")
		return false
	dialog_panel.call("_on_attack_confirmation_confirmed")
	await process_frame
	var hit_events := _presentation_events(npc_system, "damage_hit_react")
	if (
		int(npc_system.get_npc_state(ATTACK_NPC_ID).get("hp", 0)) != hp_before - 10
		or _count_memory_events(memory_system, ATTACK_NPC_ID, "damage_taken") != damage_events_before + 1
		or hit_events.size() != hit_events_before + 1
		or int(fake_bridge.get("request_count")) != 1
	):
		_fail("Confirmed dialogue attack did not create one damage fact and one feedback event")
		return false
	var hit_event: Dictionary = hit_events.back()
	if (
		str(hit_event.get("damage_event_id", "")).is_empty()
		or str(hit_event.get("presentation_action", "")) != "hit_react"
		or bool(hit_event.get("suppressed", true))
	):
		_fail("Dialogue hit feedback is not linked to its unique damage event")
		return false
	var target_node := _get_npc_node(npc_system, ATTACK_NPC_ID)
	var art_snapshot: Dictionary = target_node.debug_get_character_art_snapshot()
	if str(art_snapshot.get("temporary_presentation_state", "")) != "hit_react":
		_fail("Confirmed dialogue attack did not play the hit animation")
		return false
	for _refresh_index in range(3):
		dialog_panel.call("_refresh", dialog_system.get_dialogue_state())
	await process_frame
	if (
		_presentation_events(npc_system, "damage_hit_react").size() != hit_events.size()
		or int(npc_system.get_npc_state(ATTACK_NPC_ID).get("hp", 0)) != hp_before - 10
	):
		_fail("DialogPanel refresh replayed damage or hit feedback")
		return false
	var duplicate_result: Dictionary = npc_system.play_damage_presentation_event({
		"ok": true,
		"npc_id": ATTACK_NPC_ID,
		"actor_id": "guard_officer",
		"damage": 10,
		"hp_before": hp_before,
		"hp_after": hp_before - 10,
		"unconscious": false,
		"damage_event": {"event_id": str(hit_event.get("damage_event_id", ""))}
	})
	if not bool(duplicate_result.get("duplicate", false)) or _presentation_events(npc_system, "damage_hit_react").size() != hit_events.size():
		_fail("Repeated damage event ID was not deduplicated")
		return false
	dialog_system.end_dialogue("verify_t0154_nonlethal_complete", {"skip_plan_reevaluation": true})
	await process_frame
	return true


func _verify_lethal_attack_priority(npc_system: Node, dialog_system: Node, dialog_panel: Control) -> bool:
	npc_system.update_npc_state(LETHAL_NPC_ID, {
		"hp": 5,
		"max_hp": 100,
		"unconscious": false,
		"escaped": false,
		"current_action": "idle",
		"movement_target": "",
		"behavior_mode": "work"
	})
	var start_result: Dictionary = dialog_system.start_player_dialogue(LETHAL_NPC_ID)
	if not bool(start_result.get("ok", false)):
		_fail("Lethal attack dialogue could not open")
		return false
	await process_frame
	dialog_panel.call("_on_attack_confirmation_confirmed")
	await process_frame
	var state: Dictionary = npc_system.get_npc_state(LETHAL_NPC_ID)
	var hit_events := _presentation_events(npc_system, "damage_hit_react")
	var lethal_event: Dictionary = hit_events.back()
	var target_node := _get_npc_node(npc_system, LETHAL_NPC_ID)
	var art_snapshot: Dictionary = target_node.debug_get_character_art_snapshot()
	if (
		int(state.get("hp", -1)) != 0
		or not bool(state.get("unconscious", false))
		or not bool(lethal_event.get("suppressed_by_unconscious", false))
		or not bool(lethal_event.get("suppressed", false))
		or str(art_snapshot.get("desired_state", "")) != "unconscious"
		or str(art_snapshot.get("temporary_presentation_state", "")) == "hit_react"
	):
		_fail("Lethal dialogue attack did not leave unconscious presentation authoritative")
		return false
	return true


func _presentation_events(npc_system: Node, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var snapshot: Dictionary = npc_system.get_temporary_presentation_event_snapshot()
	for raw_event in snapshot.get("events", []):
		if raw_event is Dictionary and str(raw_event.get("event_kind", "")) == kind:
			result.append((raw_event as Dictionary).duplicate(true))
	return result


func _count_memory_events(memory_system: Node, npc_id: String, event_type: String) -> int:
	var count := 0
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		if raw_event is Dictionary and str(raw_event.get("type", "")) == event_type:
			count += 1
	return count


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	if not paths.has(npc_id):
		return null
	return npc_system.get_node_or_null(paths[npc_id])


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
