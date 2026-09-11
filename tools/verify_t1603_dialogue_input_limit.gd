extends SceneTree

class FakeLLMBridge extends Node:
	signal dialogue_async_response_received(result: Dictionary)
	var requests: Array[Dictionary] = []

	func request_npc_dialogue_async(npc_id: String, text: String, options: Dictionary = {}) -> Dictionary:
		requests.append({"npc_id": npc_id, "text": text, "options": options.duplicate(true)})
		return {"ok": true, "pending": true, "request_id": str(options.get("request_id", "fake"))}

	func cancel_npc_llm_requests(_npc_id: String, _reason: String = "cancelled") -> Dictionary:
		return {"ok": true, "cancelled": true}

	func get_provider_mode_snapshot() -> Dictionary:
		return {"ok": true, "provider": "mock", "real_provider": false}


func _init() -> void:
	var packed_main := load("res://scenes/main/Main.tscn") as PackedScene
	if packed_main == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed_main.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var panel := root.get_node_or_null("Main/UI/DialogPanel")
	var input_edit := panel.find_child("DialogInputEdit", true, false) as LineEdit
	var limit_dialog := panel.find_child("DialogInputLimitDialog", true, false) as AcceptDialog
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if null in [dialog_system, panel, input_edit, limit_dialog, original_bridge]:
		_fail("T1603 required nodes are missing")
		return
	var systems := root.get_node("Main/Systems")
	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	var fake_bridge := FakeLLMBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)

	if input_edit.max_length != 0 or dialog_system.get_player_message_max_characters() != 300:
		_fail("Dialogue input must keep unlimited draft storage and load the shared 300 limit")
		return
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_input_config.json"))
	if not config is Dictionary or int((config as Dictionary).get("player_message_max_characters", 0)) != 300:
		_fail("Shared dialogue input config mismatch")
		return

	var start_result: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not open 301-character UI test dialogue")
		return
	dialog_system.set_dialogue_visibility("local_public")
	dialog_system.set_recruitment_request_pending(true)
	var protected_state_before: Dictionary = dialog_system.get_display_dialogue_state()
	var over_limit := "甲".repeat(301)
	input_edit.text = over_limit
	panel.call("_send_current_text")
	await process_frame
	var protected_state_after: Dictionary = dialog_system.get_display_dialogue_state()
	if (
		input_edit.text != over_limit
		or not limit_dialog.visible
		or limit_dialog.dialog_text != "输入文字超过上限300字"
		or not fake_bridge.requests.is_empty()
		or str(protected_state_after.get("visibility", "")) != str(protected_state_before.get("visibility", ""))
		or bool(protected_state_after.get("recruitment_request_pending", false)) != bool(protected_state_before.get("recruitment_request_pending", false))
		or not (protected_state_after.get("history", []) as Array).is_empty()
	):
		_fail("301-character UI rejection changed draft, state, history, or transport")
		return
	limit_dialog.hide()
	limit_dialog.confirmed.emit()
	await process_frame
	if not input_edit.has_focus():
		_fail("Input focus was not restored after closing the limit dialog")
		return

	input_edit.text = "乙".repeat(299)
	panel.call("_send_current_text")
	await process_frame
	if fake_bridge.requests.size() != 1 or str(fake_bridge.requests[0].get("text", "")).length() != 299 or not input_edit.text.is_empty():
		_fail("299-character text was not accepted and cleared after submission")
		return
	_cancel_current_dialogue(dialog_system)

	start_result = dialog_system.start_player_dialogue("cook_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not open 300-character UI test dialogue")
		return
	var mixed_prefix := "汉字，空 格（愤怒地）"
	var exactly_limit := mixed_prefix + "丙".repeat(300 - mixed_prefix.length())
	input_edit.text = exactly_limit
	panel.call("_send_current_text")
	await process_frame
	if fake_bridge.requests.size() != 2 or str(fake_bridge.requests[1].get("text", "")) != exactly_limit or not input_edit.text.is_empty():
		_fail("300-character mixed text was not accepted")
		return
	_cancel_current_dialogue(dialog_system)

	start_result = dialog_system.start_player_dialogue("cook_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not open voice overflow test dialogue")
		return
	input_edit.text = "丁".repeat(299)
	panel.call("_append_recognized_segment", "语音")
	if input_edit.text.length() != 302:
		_fail("Voice append was truncated before send validation")
		return
	var requests_before_overflow := fake_bridge.requests.size()
	panel.call("_send_current_text")
	await process_frame
	if input_edit.text.length() != 302 or fake_bridge.requests.size() != requests_before_overflow or not limit_dialog.visible:
		_fail("Voice-created over-limit draft was not preserved and blocked")
		return
	limit_dialog.hide()

	var direct_result: Dictionary = dialog_system.send_player_message("戊".repeat(301), false, true)
	var direct_state: Dictionary = dialog_system.get_display_dialogue_state()
	if (
		bool(direct_result.get("ok", true))
		or str(direct_result.get("error_code", "")) != "input_too_long"
		or int(direct_result.get("max_characters", 0)) != 300
		or int(direct_result.get("actual_characters", 0)) != 301
		or fake_bridge.requests.size() != requests_before_overflow
		or not (direct_state.get("history", []) as Array).is_empty()
	):
		_fail("DialogSystem second-layer 301-character guard failed")
		return

	print("T1603_DIALOGUE_INPUT_LIMIT_OK")
	main.queue_free()
	await process_frame
	quit(0)


func _cancel_current_dialogue(dialog_system: Node) -> void:
	var state: Dictionary = dialog_system.get_display_dialogue_state()
	var dialogue_id := str(state.get("dialogue_id", ""))
	if not dialogue_id.is_empty():
		dialog_system.cancel_displayed_dialogue(dialogue_id)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
