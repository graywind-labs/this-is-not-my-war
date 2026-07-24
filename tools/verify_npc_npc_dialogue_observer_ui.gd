extends SceneTree


class FakeDialogueBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)

	var requests: Array[Dictionary] = []
	var cancel_call_count := 0
	var reply_delay_seconds := 0.12

	func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
		var request_index := requests.size() + 1
		var request_id := str(options.get("request_id", "observer_dialogue_%d" % request_index))
		requests.append({
			"npc_id": npc_id,
			"speaker_text": speaker_text,
			"options": options.duplicate(true),
			"request_id": request_id
		})
		var timer := get_tree().create_timer(reply_delay_seconds)
		timer.timeout.connect(_emit_reply.bind(request_id, request_index, npc_id))
		return {"ok": true, "pending": true, "request_id": request_id}

	func cancel_npc_llm_requests(_npc_id: String, _reason: String = "cancelled") -> Dictionary:
		cancel_call_count += 1
		return {"ok": true, "cancelled": false}

	func _emit_reply(request_id: String, request_index: int, npc_id: String) -> void:
		dialogue_async_response_received.emit({
			"ok": true,
			"request_id": request_id,
			"dialogue": {
				"replyer_id": npc_id,
				"reply_text": "第 %d 轮回复。" % request_index,
				"response_kind": "reply_to_npc",
				"emotion": "neutral",
				"should_end_dialogue": request_index >= 2,
				"model_provider": "deepseek",
				"model_name": "observer-ui-fake-real-shape",
				"model_fallback_used": false
			}
		})


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node_or_null("Main/Systems")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var input_edit := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogInputEdit") as LineEdit
	var send_button := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogSendButton") as Button
	var attack_button := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogAttackButton") as Button
	var end_button := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogEndButton") as Button
	var recruitment_toggle := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/Header/DialogHeaderToggles/DialogRecruitmentToggle") as CheckButton
	var name_label := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/Header/DialogNPCNameLabel") as Label
	var status_label := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/DialogStatusLabel") as Label
	var round_label := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/DialogRoundLabel") as Label
	var history_text := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/DialogHistoryText") as RichTextLabel
	if [systems, npc_system, dialog_system, dialog_panel, npc_panel, original_bridge, input_edit, send_button, attack_button, end_button, recruitment_toggle, name_label, status_label, round_label, history_text].has(null):
		_fail("NPC dialogue observer UI verification required nodes not found")
		return

	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var fake_bridge := FakeDialogueBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.dialogue_async_response_received.connect(Callable(dialog_system, "_on_dialogue_async_response_received"))

	if not npc_system.debug_enter_location_immediately("doctor_01", "plaza") or not npc_system.debug_enter_location_immediately("cook_01", "plaza"):
		_fail("Could not place NPC dialogue participants in plaza")
		return
	var start_result: Dictionary = dialog_system.start_npc_dialogue(
		"doctor_01",
		"cook_01",
		"local_public",
		2,
		{
			"autonomous": true,
			"ui_visible": false,
			"replace_existing": false,
			"require_real_provider": false
		}
	)
	if not bool(start_result.get("ok", false)):
		_fail("Could not start autonomous NPC dialogue: %s" % JSON.stringify(start_result))
		return
	await process_frame

	var doctor_node := _find_npc_node("doctor_01")
	var cook_node := _find_npc_node("cook_01")
	if doctor_node == null or cook_node == null:
		_fail("Could not find NPC world nodes")
		return
	var active_dialogue_id := str(doctor_node.debug_get_dialogue_bubble_snapshot().get("dialogue_id", ""))
	if active_dialogue_id.is_empty():
		_fail("Autonomous dialogue bubble did not expose its active dialogue id")
		return
	if not _bubble_is_clickable(doctor_node) or not _bubble_is_clickable(cook_node):
		_fail("Both autonomous dialogue participants must show clickable bubbles")
		return
	if dialog_panel.visible:
		_fail("Autonomous dialogue must not open DialogPanel before a bubble is clicked")
		return

	await physics_frame
	var doctor_click: Dictionary = await _click_dialogue_bubble_with_mouse(doctor_node, npc_system)
	if not bool(doctor_click.get("ok", false)):
		_fail("Could not perform real projected mouse click on doctor bubble: %s" % JSON.stringify(doctor_click))
		return
	if not dialog_panel.visible:
		_fail("Real mouse click on autonomous dialogue bubble did not open observer UI")
		return
	if npc_panel.visible:
		_fail("Dialogue bubble mouse click was incorrectly handled as an NPC body click")
		return
	if input_edit.visible or send_button.visible or attack_button.visible or recruitment_toggle.visible:
		_fail("Observer UI exposed player dialogue actions")
		return
	if not name_label.text.contains("莉娜") or not name_label.text.contains("布鲁诺"):
		_fail("Observer UI did not show both participant display names")
		return
	if end_button.text != "关闭" or not str(end_button.tooltip_text).contains("不会打断"):
		_fail("Observer UI close action is not clearly read-only")
		return
	if not round_label.text.contains("轮次：0") or not round_label.text.contains("无硬上限") or not round_label.text.contains("第 3 轮起建议收尾"):
		_fail("Observer UI did not show current round and soft-round guidance before the first reply")
		return

	var send_result: Dictionary = dialog_system.send_npc_message("诊所的工位能先让我用吗？", true)
	if not bool(send_result.get("ok", false)) or not bool(send_result.get("pending", false)):
		_fail("Could not start observer dialogue LLM round")
		return
	await process_frame
	if fake_bridge.requests.size() != 1 or not bool(fake_bridge.requests[0].get("options", {}).get("requires_time_slowdown", false)):
		_fail("Autonomous dialogue round did not explicitly request TimeSystem slowdown")
		return
	if not status_label.text.contains("第 1 轮 LLM 回复") or not history_text.text.contains("诊所的工位"):
		_fail("Observer UI did not expose the pending opening line and wait state")
		return

	var cancel_calls_before_close := fake_bridge.cancel_call_count
	end_button.pressed.emit()
	await process_frame
	if dialog_panel.visible or not dialog_system.has_active_dialogue():
		_fail("Closing observer UI ended the autonomous dialogue")
		return
	if fake_bridge.cancel_call_count != cancel_calls_before_close:
		_fail("Closing observer UI cancelled an autonomous dialogue LLM request")
		return

	var cook_click: Dictionary = await _click_dialogue_bubble_with_mouse(cook_node, npc_system)
	if not bool(cook_click.get("ok", false)):
		_fail("Could not perform real projected mouse click on cook bubble: %s" % JSON.stringify(cook_click))
		return
	if not dialog_panel.visible:
		_fail("Either participant bubble should reopen the same observer session through real mouse input")
		return
	if npc_panel.visible:
		_fail("Reopening observer through the other bubble unexpectedly opened NPCPanel")
		return
	if str(dialog_panel.get("_displayed_dialogue_id")) != active_dialogue_id:
		_fail("Reopened observer UI did not retain the active autonomous dialogue id")
		return
	if not status_label.text.contains("第 1 轮 LLM 回复") or not history_text.text.contains("诊所的工位"):
		_fail("Reopened observer UI did not restore the latest in-flight conversation state")
		return

	var first_round_deadline := Time.get_ticks_msec() + 2000
	while fake_bridge.requests.size() < 2 and Time.get_ticks_msec() < first_round_deadline:
		await create_timer(0.01).timeout
	if fake_bridge.requests.size() < 2:
		_fail("Autonomous dialogue did not continue into the second round")
		return
	if not bool(fake_bridge.requests[1].get("options", {}).get("requires_time_slowdown", false)):
		_fail("Autonomous dialogue continuation did not request TimeSystem slowdown")
		return
	if not round_label.text.contains("轮次：1") or not round_label.text.contains("无硬上限") or not history_text.text.contains("第 1 轮回复"):
		_fail("Observer UI did not live-refresh after the first completed round")
		return

	var end_deadline := Time.get_ticks_msec() + 2000
	while dialog_system.has_active_dialogue() and Time.get_ticks_msec() < end_deadline:
		await create_timer(0.01).timeout
	await process_frame
	if dialog_system.has_active_dialogue():
		_fail("Autonomous dialogue did not finish after its second round")
		return
	if _bubble_is_visible(doctor_node) or _bubble_is_visible(cook_node):
		_fail("Dialogue bubbles remained after autonomous dialogue ended")
		return
	if not dialog_panel.visible or not status_label.text.contains("已结束") or not history_text.text.contains("第 2 轮回复"):
		_fail("Observer UI did not preserve the final conversation after natural completion")
		return
	if input_edit.visible or send_button.visible or attack_button.visible or recruitment_toggle.visible:
		_fail("Finished observer UI unexpectedly exposed player controls")
		return
	end_button.pressed.emit()
	await process_frame
	if dialog_panel.visible:
		_fail("Finished observer UI did not close locally")
		return
	var body_click: Dictionary = await _click_npc_body_with_mouse(doctor_node, npc_system)
	if not bool(body_click.get("ok", false)) or not npc_panel.visible:
		_fail("NPC body real mouse click regressed after bubble routing fix: %s" % JSON.stringify(body_click))
		return
	npc_panel.visible = false

	# Forced interruption follows the same bubble cleanup path, while an open observer
	# keeps the final interrupted snapshot and the in-flight request is cancelled by
	# DialogSystem rather than by merely closing the observer.
	var interrupt_start: Dictionary = dialog_system.start_npc_dialogue(
		"doctor_01",
		"cook_01",
		"local_public",
		2,
		{
			"autonomous": true,
			"ui_visible": false,
			"replace_existing": false,
			"require_real_provider": false
		}
	)
	if not bool(interrupt_start.get("ok", false)):
		_fail("Could not start interruption cleanup dialogue")
		return
	await process_frame
	var interrupt_click: Dictionary = await _click_dialogue_bubble_with_mouse(doctor_node, npc_system)
	if not bool(interrupt_click.get("ok", false)):
		_fail("Could not open interruption observer through real mouse input")
		return
	var interrupt_send: Dictionary = dialog_system.send_npc_message("这轮会被高优先级状态中断。", true)
	if not bool(interrupt_send.get("ok", false)):
		_fail("Could not start interruption cleanup LLM request")
		return
	var cancel_calls_before_interrupt := fake_bridge.cancel_call_count
	dialog_system.end_dialogue("verify_authority_interrupt", {"suppress_plan_reevaluation": true})
	await process_frame
	if dialog_system.has_active_dialogue() or _bubble_is_visible(doctor_node) or _bubble_is_visible(cook_node):
		_fail("Forced dialogue interruption did not clear both bubbles")
		return
	if fake_bridge.cancel_call_count <= cancel_calls_before_interrupt:
		_fail("Forced dialogue interruption did not cancel the in-flight LLM request")
		return
	if not dialog_panel.visible or not status_label.text.contains("已结束"):
		_fail("Observer UI did not preserve the forced-interruption final snapshot")
		return
	end_button.pressed.emit()
	await create_timer(fake_bridge.reply_delay_seconds + 0.03).timeout

	main.queue_free()
	await process_frame
	print("T0028/T0032 NPC-NPC dialogue bubble real mouse and observer UI verification passed.")
	quit(0)


func _find_npc_node(npc_id: String) -> Node:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return null
	for child in npc_root.get_children():
		if str(child.get_meta("npc_id", "")) == npc_id:
			return child
	return null


func _bubble_is_clickable(npc_node: Node) -> bool:
	var snapshot: Dictionary = npc_node.debug_get_dialogue_bubble_snapshot()
	return bool(snapshot.get("visible", false)) and bool(snapshot.get("click_enabled", false))


func _bubble_is_visible(npc_node: Node) -> bool:
	return bool(npc_node.debug_get_dialogue_bubble_snapshot().get("visible", false))


func _click_dialogue_bubble_with_mouse(npc_node: Node, npc_system: Node) -> Dictionary:
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var bubble := npc_node.get_node_or_null("AutonomousDialogueBubble") as Node3D
	if camera == null or bubble == null:
		return {"ok": false, "error": "camera_or_bubble_missing"}
	if camera.is_position_behind(bubble.global_position):
		return {"ok": false, "error": "bubble_behind_camera"}
	var screen_position := camera.unproject_position(bubble.global_position)
	var picked: Dictionary = npc_system._pick_npc_interaction_at_screen_position(screen_position)
	if str(picked.get("kind", "")) != "autonomous_dialogue_bubble":
		return {
			"ok": false,
			"error": "projected_ray_did_not_pick_dialogue_bubble",
			"screen_position": screen_position,
			"picked_kind": str(picked.get("kind", "")),
			"picked_npc_id": str(picked.get("npc_id", ""))
		}
	var motion := InputEventMouseMotion.new()
	motion.position = screen_position
	motion.global_position = screen_position
	root.push_input(motion)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen_position
	click.global_position = screen_position
	root.push_input(click)
	await process_frame
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)
	await process_frame
	return {
		"ok": true,
		"screen_position": screen_position,
		"picked_kind": str(picked.get("kind", "")),
		"npc_id": str(picked.get("npc_id", "")),
		"dialogue_id": str(picked.get("dialogue_id", ""))
	}


func _click_npc_body_with_mouse(npc_node: Node3D, npc_system: Node) -> Dictionary:
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if camera == null:
		return {"ok": false, "error": "camera_missing"}
	var body_world_position := npc_node.global_position + Vector3(0.0, 0.8, 0.0)
	var screen_position := camera.unproject_position(body_world_position)
	var picked: Dictionary = npc_system._pick_npc_interaction_at_screen_position(screen_position)
	if str(picked.get("kind", "")) != "npc":
		return {"ok": false, "error": "projected_ray_did_not_pick_npc", "picked": picked}
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen_position
	click.global_position = screen_position
	root.push_input(click)
	await process_frame
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)
	await process_frame
	return {"ok": true, "npc_id": str(picked.get("npc_id", "")), "screen_position": screen_position}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
