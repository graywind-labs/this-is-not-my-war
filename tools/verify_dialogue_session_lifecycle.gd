extends SceneTree

class FakeLLMBridge extends Node:
	signal dialogue_async_response_received(result: Dictionary)

	func request_npc_dialogue_async(_npc_id: String, _text: String, options: Dictionary = {}) -> Dictionary:
		return {"ok": true, "pending": true, "request_id": str(options.get("request_id", "fake_dialogue_request"))}

	func cancel_npc_llm_requests(_npc_id: String, _reason: String = "cancelled") -> Dictionary:
		return {"ok": true, "cancelled": true}

	func get_provider_mode_snapshot() -> Dictionary:
		return {"ok": true, "provider": "mock", "real_provider": false}


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if dialog_system == null or npc_system == null or memory_system == null or llm_bridge == null or dialog_panel == null or npc_panel == null:
		_fail("Dialogue lifecycle verification required nodes not found")
		return
	var systems := root.get_node("Main/Systems")
	systems.remove_child(llm_bridge)
	llm_bridge.queue_free()
	var fake_llm_bridge := FakeLLMBridge.new()
	fake_llm_bridge.name = "LLMBridge"
	systems.add_child(fake_llm_bridge)

	for button_name in ["DialogEndButton", "DialogCancelButton", "DialogSuspendButton"]:
		if dialog_panel.find_child(button_name, true, false) == null:
			_fail("Missing dialogue lifecycle button: %s" % button_name)
			return

	if not _verify_draggable_panels(main):
		return

	# Completing while the reply is still pending must preserve the already-rendered
	# guard line, cancel the reply, write exactly one session event and request judgement.
	var dialogue_events_before := _count_events(memory_system, "cook_01", "dialogue_turn")
	var start_result: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not start completion test dialogue")
		return
	var send_result: Dictionary = dialog_system.send_player_message("把今天的工作重新安排一下。", false, true)
	var waiting_state: Dictionary = dialog_system.get_dialogue_state()
	var waiting_history: Array = waiting_state.get("history", [])
	if not bool(send_result.get("ok", false)) or not bool(waiting_state.get("waiting", false)) or waiting_history.size() != 1 or str((waiting_history[0] as Dictionary).get("text", "")) != "把今天的工作重新安排一下。":
		_fail("Guard message was not visible immediately while the LLM reply was pending")
		return
	var complete_result: Dictionary = dialog_system.complete_displayed_dialogue(str(waiting_state.get("dialogue_id", "")))
	var completed_event: Dictionary = complete_result.get("dialogue_event", {}) if complete_result.get("dialogue_event", {}) is Dictionary else {}
	var completed_payload: Dictionary = completed_event.get("payload", {}) if completed_event.get("payload", {}) is Dictionary else {}
	var completed_history: Array = completed_payload.get("dialogue_text", [])
	if (
		not bool(complete_result.get("ok", false))
		or not bool(completed_payload.get("ended_while_waiting", false))
		or completed_history.size() != 1
		or _count_events(memory_system, "cook_01", "dialogue_turn") != dialogue_events_before + 1
	):
		_fail("Completing a waiting dialogue did not commit the guard-final session exactly once")
		return

	# A completed multi-round guard session remains one event, but both its payload
	# and deterministic player-facing summary must preserve every spoken line.
	dialogue_events_before = _count_events(memory_system, "stableman_01", "dialogue_turn")
	start_result = dialog_system.start_player_dialogue("stableman_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not start multi-round transcript test dialogue")
		return
	send_result = dialog_system.send_player_message("第一轮问题", false, true)
	var pending: Dictionary = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "stableman_01",
			"reply_text": "第一轮回复",
			"emotion": "steady",
			"recruitment_result": "none",
			"wartime_reaction": "none",
		}
	}, pending)
	send_result = dialog_system.send_player_message("第二轮问题", false, true)
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "stableman_01",
			"reply_text": "第二轮回复",
			"emotion": "steady",
			"recruitment_result": "none",
			"wartime_reaction": "none",
		}
	}, pending)
	complete_result = dialog_system.complete_displayed_dialogue()
	var transcript_event: Dictionary = complete_result.get("dialogue_event", {}) if complete_result.get("dialogue_event", {}) is Dictionary else {}
	var transcript_payload: Dictionary = transcript_event.get("payload", {}) if transcript_event.get("payload", {}) is Dictionary else {}
	var transcript_history: Array = transcript_payload.get("dialogue_text", [])
	var transcript_summary := str(transcript_event.get("summary", ""))
	if (
		not bool(send_result.get("ok", false))
		or transcript_history.size() != 4
		or _count_events(memory_system, "stableman_01", "dialogue_turn") != dialogue_events_before + 1
		or not transcript_summary.begins_with("守备官与托马对话：")
		or transcript_summary.contains("完整对话")
		or not transcript_summary.contains("第一轮问题")
		or not transcript_summary.contains("第一轮回复")
		or not transcript_summary.contains("第二轮问题")
		or not transcript_summary.contains("第二轮回复")
	):
		_fail("Completed multi-round dialogue did not expose the full transcript in one event")
		return
	npc_system.debug_select_npc("stableman_01")
	await process_frame
	var detail_result: Dictionary = npc_panel.debug_open_memory_detail("event_log")
	await process_frame
	var memory_detail_text := root.get_node("Main/UI").find_child("NPCMemoryDetailText", true, false) as TextEdit
	if (
		not bool(detail_result.get("ok", false))
		or memory_detail_text == null
		or not memory_detail_text.text.contains("第一轮问题")
		or not memory_detail_text.text.contains("第一轮回复")
		or not memory_detail_text.text.contains("第二轮问题")
		or not memory_detail_text.text.contains("第二轮回复")
	):
		_fail("NPC event library detail did not render the completed full transcript")
		return
	npc_panel.call("_close_memory_detail_popup")

	# Sending any recruitment-marked line makes the whole session non-cancellable.
	# The toggle stays armed for later turns until the player explicitly switches it off.
	dialogue_events_before = _count_events(memory_system, "gardener_01", "dialogue_turn")
	start_result = dialog_system.start_player_dialogue("gardener_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not start cancellation test dialogue")
		return
	send_result = dialog_system.send_player_message("请应征入伍。", true, true)
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "gardener_01",
			"reply_text": "不，我还没有准备好应征。",
			"emotion": "steady",
			"recruitment_result": "reject",
			"wartime_reaction": "none",
		}
	}, pending)
	var recruitment_state: Dictionary = dialog_system.get_dialogue_state()
	dialog_panel.call("_refresh", recruitment_state)
	var cancel_button := dialog_panel.find_child("DialogCancelButton", true, false) as Button
	var cancel_result: Dictionary = dialog_system.cancel_displayed_dialogue()
	if (
		bool(cancel_result.get("ok", false))
		or not bool(recruitment_state.get("recruitment_request_pending", false))
		or not bool(recruitment_state.get("session_had_recruitment_request", false))
		or cancel_button == null
		or not cancel_button.disabled
		or _count_events(memory_system, "gardener_01", "dialogue_turn") != dialogue_events_before
		or bool(npc_system.get_npc("gardener_01").get("recruited", false))
	):
		_fail("Recruitment message did not keep the toggle armed and lock cancellation")
		return
	send_result = dialog_system.send_player_message("第二轮继续谈应征条件。", false, true)
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	if not bool(send_result.get("ok", false)) or not bool(pending.get("effective_recruitment_request", false)):
		_fail("Sticky recruitment toggle did not mark the next player message")
		return
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "gardener_01",
			"reply_text": "我的答复仍然是不。",
			"emotion": "steady",
			"recruitment_result": "reject",
			"wartime_reaction": "none",
		}
	}, pending)
	if not bool(dialog_system.set_recruitment_request_pending(false).get("ok", false)):
		_fail("Player could not explicitly switch off the sticky recruitment toggle")
		return
	send_result = dialog_system.send_player_message("那先谈谈今天的安排。", false, true)
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	if not bool(send_result.get("ok", false)) or bool(pending.get("effective_recruitment_request", true)):
		_fail("Switching off the recruitment toggle did not restore an ordinary next message")
		return
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "gardener_01",
			"reply_text": "那就只谈今天的活。",
			"emotion": "steady",
			"recruitment_result": "none",
			"wartime_reaction": "none",
		}
	}, pending)
	if bool(dialog_system.cancel_displayed_dialogue().get("ok", false)):
		_fail("Switching off the toggle incorrectly unlocked a recruitment-marked session")
		return
	complete_result = dialog_system.complete_displayed_dialogue()
	if (
		not bool(complete_result.get("ok", false))
		or _count_events(memory_system, "gardener_01", "dialogue_turn") != dialogue_events_before + 1
		or bool(npc_system.get_npc("gardener_01").get("recruited", false))
	):
		_fail("Recruitment-locked dialogue did not complete after an explicit rejection")
		return

	# Attack is authoritative immediately and locks cancellation; completion then
	# stores the conversation session independently from the damage event.
	dialogue_events_before = _count_events(memory_system, "blacksmith_01", "dialogue_turn")
	start_result = dialog_system.start_player_dialogue("blacksmith_01")
	var attack_result: Dictionary = dialog_system.attack_target_npc(1, true)
	var attack_state: Dictionary = dialog_system.get_dialogue_state()
	dialog_panel.call("_refresh", attack_state)
	cancel_button = dialog_panel.find_child("DialogCancelButton", true, false) as Button
	var locked_cancel_result: Dictionary = dialog_system.cancel_displayed_dialogue()
	if not bool(attack_result.get("ok", false)) or not bool(attack_state.get("attack_committed", false)) or cancel_button == null or not cancel_button.disabled or bool(locked_cancel_result.get("ok", false)):
		_fail("Attack did not lock the cancel action")
		return
	complete_result = dialog_system.complete_displayed_dialogue()
	if not bool(complete_result.get("ok", false)) or _count_events(memory_system, "blacksmith_01", "dialogue_turn") != dialogue_events_before + 1:
		_fail("Attack dialogue was not stored on completion")
		return

	# Suspending a draft must actually pause the NPC, hide the window, show both the
	# orange panel dot and the differently-colored clickable overhead bubble.
	start_result = dialog_system.start_player_dialogue("doctor_01")
	var suspend_result: Dictionary = dialog_system.suspend_displayed_dialogue()
	await process_frame
	var doctor_state: Dictionary = npc_system.get_npc_state("doctor_01")
	var doctor_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Doctor01")
	if doctor_node == null:
		for child in root.get_node("Main/WorldRoot/Station/NPCs").get_children():
			if str(child.get("npc_id")) == "doctor_01":
				doctor_node = child
				break
	var bubble_snapshot: Dictionary = doctor_node.debug_get_dialogue_bubble_snapshot() if doctor_node != null and doctor_node.has_method("debug_get_dialogue_bubble_snapshot") else {}
	npc_system.debug_select_npc("doctor_01")
	await process_frame
	var suspended_dot := npc_panel.find_child("NPCDialogueSuspendedDot", true, false) as Label
	if (
		not bool(suspend_result.get("ok", false))
		or dialog_panel.visible
		or str(doctor_state.get("current_action", "")) != "talk_to_guard_officer"
		or not bool(doctor_state.get("player_dialogue_suspended", false))
		or not bool(bubble_snapshot.get("visible", false))
		or not bool(bubble_snapshot.get("suspended_player_dialogue", false))
		or suspended_dot == null
		or not suspended_dot.visible
	):
		_fail("Suspended dialogue did not expose the paused NPC bubble and panel dot")
		return
	doctor_node.debug_click_dialogue_bubble()
	await process_frame
	if not dialog_panel.visible or bool(dialog_system.get_dialogue_state().get("suspended", true)):
		_fail("Clicking the suspended dialogue bubble did not reopen the session")
		return
	if not bool(dialog_system.cancel_displayed_dialogue().get("ok", false)):
		_fail("Resumed non-attack dialogue could not be cancelled")
		return

	# Two logical game hours automatically cancel a suspended non-attack session.
	dialogue_events_before = _count_events(memory_system, "priest_01", "dialogue_turn")
	dialog_system.start_player_dialogue("priest_01")
	dialog_system.suspend_displayed_dialogue()
	dialog_system.call("_on_logical_time_tick", 7200.0, 1.0)
	if dialog_system.has_active_dialogue() or _count_events(memory_system, "priest_01", "dialogue_turn") != dialogue_events_before:
		_fail("Two-hour suspension timeout did not auto-cancel without a dialogue event")
		return

	# A recruitment-marked session uses the same non-cancellable boundary while
	# suspended, so timeout completes and stores it instead of silently cancelling.
	dialogue_events_before = _count_events(memory_system, "gardener_01", "dialogue_turn")
	dialog_system.start_player_dialogue("gardener_01")
	dialog_system.send_player_message("我再次正式提出应征。", true, true)
	dialog_system.suspend_displayed_dialogue()
	dialog_system.call("_on_logical_time_tick", 7200.0, 1.0)
	if dialog_system.has_active_dialogue() or _count_events(memory_system, "gardener_01", "dialogue_turn") != dialogue_events_before + 1:
		_fail("Recruitment-locked suspension timeout did not complete and store the session")
		return

	# An attack cannot be erased by the same timeout: it auto-completes and keeps the
	# authoritative attack/session evidence instead of taking the cancel path.
	dialogue_events_before = _count_events(memory_system, "engineer_01", "dialogue_turn")
	dialog_system.start_player_dialogue("engineer_01")
	dialog_system.attack_target_npc(1, true)
	dialog_system.suspend_displayed_dialogue()
	dialog_system.call("_on_logical_time_tick", 7200.0, 1.0)
	if dialog_system.has_active_dialogue() or _count_events(memory_system, "engineer_01", "dialogue_turn") != dialogue_events_before + 1:
		_fail("Attack-locked suspension timeout did not preserve and complete the session")
		return

	print("DIALOGUE_SESSION_LIFECYCLE_VERIFY_OK")
	quit(0)


func _verify_draggable_panels(main: Node) -> bool:
	var panel_paths := [
		"UI/DialogPanel",
		"UI/NPCPanel",
		"UI/BuildingPanel",
		"UI/OrderPanel",
		"UI/NoticeBoardPanel",
		"UI/MerchantPanel"
	]
	for panel_path in panel_paths:
		var panel := main.get_node_or_null(panel_path) as Control
		var controller: Variant = panel.get("_drag_controller") if panel != null else null
		if panel == null or controller == null or not controller.has_method("debug_drag_to"):
			_fail("Panel does not use the shared drag controller: %s" % panel_path)
			return false
		controller.debug_drag_to(Vector2(96.0, 84.0))
		if not controller.has_user_position() or panel.global_position.x < 0.0 or panel.global_position.y < 0.0:
			_fail("Panel drag/clamp failed: %s" % panel_path)
			return false
	var npc_panel := main.get_node("UI/NPCPanel")
	npc_panel.call("_setup_memory_detail_popup")
	var memory_controller: Variant = npc_panel.get("_memory_detail_drag_controller")
	var hud := main.get_node("UI/HUD")
	var detail_controller: Variant = hud.get("_detail_drag_controller")
	if memory_controller == null or detail_controller == null:
		_fail("Memory/resource detail popup drag controllers were not created")
		return false
	return true


func _count_events(memory_system: Node, npc_id: String, event_type: String) -> int:
	var count := 0
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
