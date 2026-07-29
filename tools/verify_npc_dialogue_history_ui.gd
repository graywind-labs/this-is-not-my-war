extends SceneTree

const TARGET_NPC_ID := "veteran_deputy_01"
const TARGET_NPC_NAME := "艾达"
const OTHER_NPC_ID := "blacksmith_01"
const OTHER_NPC_NAME := "格伦"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	if (
		npc_system == null
		or memory_system == null
		or dialog_system == null
		or npc_panel == null
		or dialog_panel == null
	):
		_fail("Required dialogue-history UI systems are missing")
		return

	# Insert the two pre-wave conversations out of timestamp order. The player
	# history must sort by game day/time rather than leak global insertion order.
	_add_guard_dialogue(
		memory_system,
		"history_pre_wave_late",
		1,
		"08:40:00",
		"晚些再谈防线。",
		"我会留意城门。"
	)
	_add_guard_dialogue(
		memory_system,
		"history_pre_wave_early",
		1,
		"08:10:00",
		"你昨夜睡得如何？",
		"还算安稳。"
	)
	_add_npc_dialogue(memory_system, 1, "08:20:00")
	_add_combat_boundary(memory_system, "combat_started", 1, "09:00:00", 1)
	_add_guard_dialogue(
		memory_system,
		"history_wave_one",
		1,
		"09:15:00",
		"第一波已经来了。",
		"我会守住这里。"
	)
	_add_combat_boundary(memory_system, "combat_ended", 1, "10:00:00", 1)
	_add_guard_dialogue(
		memory_system,
		"history_after_wave",
		1,
		"10:30:00",
		"先清点损失。",
		"明白。"
	)
	_add_guard_dialogue(
		memory_system,
		"history_next_day",
		2,
		"07:05:00",
		"新一天继续准备。",
		"我已经在检查装备。"
	)

	var clear_result: Dictionary = memory_system.clear_npc_short_term_memory(TARGET_NPC_ID)
	if not bool(clear_result.get("ok", false)):
		_fail("Failed to simulate reflection short-memory clearing: %s" % clear_result)
		return
	if not memory_system.get_npc_daily_events(TARGET_NPC_ID).is_empty():
		_fail("Reflection fixture should clear the target NPC daily event index")
		return

	if not npc_system.debug_select_npc(TARGET_NPC_ID):
		_fail("Failed to select dialogue-history target NPC")
		return
	await process_frame
	await process_frame
	await process_frame

	var dialogue_row := npc_panel.find_child("NPCDialogueButtonRow", true, false) as HBoxContainer
	var dialogue_button := npc_panel.find_child("NPCDialogueButton", true, false) as Button
	var history_button := npc_panel.find_child("NPCDialogueHistoryButton", true, false) as Button
	if dialogue_row == null or dialogue_button == null or history_button == null:
		_fail("NPC dialogue/history button row is missing")
		return
	if (
		dialogue_button.get_parent() != dialogue_row
		or history_button.get_parent() != dialogue_row
		or history_button.get_index() != dialogue_button.get_index() + 1
	):
		_fail("The small history button must sit directly to the right of dialogue")
		return
	if history_button.text != "记录" or history_button.disabled:
		_fail("Dialogue history button should be an independent enabled read-only entry")
		return
	if history_button.size.x >= dialogue_button.size.x:
		_fail("Dialogue history entry should remain smaller than the main dialogue button")
		return
	var history_connections := history_button.get_signal_connection_list("pressed")
	if history_connections.size() != 1:
		_fail("Dialogue history button should have exactly one dedicated pressed handler")
		return
	var history_callable: Callable = history_connections[0].get("callable", Callable())
	if history_callable.get_method() != "_on_dialogue_history_pressed":
		_fail("Dialogue history button must not reuse the dialogue start/resume handler")
		return

	if dialog_system.is_dialogue_active() or dialog_panel.visible:
		_fail("Dialogue fixture unexpectedly started a live conversation")
		return
	history_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	if dialog_system.is_dialogue_active() or dialog_panel.visible:
		_fail("Opening records started or resumed a live dialogue")
		return

	var detail_popup := root.find_child("NPCMemoryDetailPopup", true, false) as Control
	var detail_title := root.find_child("NPCMemoryDetailTitle", true, false) as Label
	var detail_text := root.find_child("NPCMemoryDetailText", true, false) as TextEdit
	var detail_close := root.find_child("NPCMemoryDetailCloseButton", true, false) as Button
	if (
		detail_popup == null
		or detail_title == null
		or detail_text == null
		or detail_close == null
		or not detail_popup.visible
	):
		_fail("Dialogue history did not open the read-only detail window")
		return
	if (
		not detail_title.text.contains(TARGET_NPC_NAME)
		or not detail_title.text.contains("对话记录")
		or not detail_title.text.contains("5 场")
	):
		_fail("Dialogue history title/count mismatch: %s" % detail_title.text)
		return

	var text := detail_text.text
	for expected in [
		"【第1天｜首波前】",
		"【第1天｜第1波期间】",
		"【第1天｜第1波后】",
		"【第2天｜第1波后】",
		"08:10:00",
		"08:40:00",
		"09:15:00",
		"10:30:00",
		"07:05:00",
		"守备官：你昨夜睡得如何？",
		"艾达：还算安稳。",
		"守备官：第一波已经来了。",
		"艾达：我会守住这里。"
	]:
		if not text.contains(expected):
			_fail("Dialogue history omitted grouped transcript content '%s': %s" % [expected, text])
			return
	if text.find("08:10:00") >= text.find("08:40:00"):
		_fail("Dialogue history should sort conversations by in-game time")
		return
	if text.contains("这段 NPC-NPC 对话不应出现在记录里") or text.contains("%s：" % OTHER_NPC_NAME):
		_fail("NPC-NPC dialogue leaked into guard-officer history: %s" % text)
		return
	if text.contains("dialogue_id") or text.contains("participant_npc_ids") or text.contains("payload"):
		_fail("Read-only player history leaked internal structured metadata")
		return

	for index in range(28):
		_add_guard_dialogue(
			memory_system,
			"history_scroll_%02d" % index,
			2,
			"11:%02d:00" % index,
			"这是用于验证长对话记录滚动能力的第%d条守备官消息。" % (index + 1),
			"这是艾达对应的第%d条较长回复，窗口应保持只读并允许滚动。" % (index + 1)
		)
	await process_frame
	await process_frame
	await process_frame
	var history_scroll_bar := detail_text.get_v_scroll_bar()
	if history_scroll_bar == null or history_scroll_bar.max_value <= 0.0:
		_fail("Long dialogue history should expose a working vertical scroll bar")
		return

	detail_close.pressed.emit()
	await process_frame
	if detail_popup.visible:
		_fail("Dialogue history close button did not hide the read-only window")
		return
	var draft_result: Dictionary = dialog_system.start_player_dialogue(TARGET_NPC_ID)
	if not bool(draft_result.get("ok", false)):
		_fail("Failed to create a player dialogue draft for isolation verification: %s" % draft_result)
		return
	var draft_id := str(dialog_system.get_display_dialogue_state().get("dialogue_id", ""))
	if draft_id.is_empty() or not dialog_system.is_dialogue_active() or not dialog_panel.visible:
		_fail("Player dialogue draft fixture did not become visible")
		return
	history_button.pressed.emit()
	await process_frame
	await process_frame
	if (
		not detail_popup.visible
		or str(dialog_system.get_display_dialogue_state().get("dialogue_id", "")) != draft_id
		or not dialog_system.is_dialogue_active()
	):
		_fail("Opening records changed the existing player dialogue draft")
		return
	detail_close.pressed.emit()
	await process_frame
	if (
		detail_popup.visible
		or str(dialog_system.get_display_dialogue_state().get("dialogue_id", "")) != draft_id
		or not dialog_system.is_dialogue_active()
		or not dialog_panel.visible
	):
		_fail("Closing records changed or hid the existing player dialogue draft")
		return
	var cancel_result: Dictionary = dialog_system.cancel_displayed_dialogue(draft_id)
	if not bool(cancel_result.get("ok", false)):
		_fail("Failed to clean up dialogue draft fixture: %s" % cancel_result)
		return

	print("NPC guard-officer dialogue history UI verification passed.")
	quit(0)


func _add_guard_dialogue(
	memory_system: Node,
	dialogue_id: String,
	day: int,
	time_text: String,
	guard_text: String,
	npc_text: String
) -> void:
	var history := [
		{
			"speaker_id": GUARD_OFFICER_ID,
			"speaker_name": GUARD_OFFICER_NAME,
			"listener_id": TARGET_NPC_ID,
			"listener_name": TARGET_NPC_NAME,
			"text": guard_text
		},
		{
			"speaker_id": TARGET_NPC_ID,
			"speaker_name": TARGET_NPC_NAME,
			"listener_id": GUARD_OFFICER_ID,
			"listener_name": GUARD_OFFICER_NAME,
			"text": npc_text
		}
	]
	var event: Dictionary = memory_system.add_event({
		"type": "dialogue_turn",
		"day": day,
		"time": time_text,
		"subject_npc_id": TARGET_NPC_ID,
		"actor_ids": [GUARD_OFFICER_ID],
		"target_ids": [TARGET_NPC_ID],
		"location_id": "plaza",
		"visibility": "private",
		"payload": {
			"dialogue_id": dialogue_id,
			"dialogue_kind": "player_npc",
			"participant_npc_ids": [TARGET_NPC_ID],
			"dialogue_text": history,
			"speaker_name": GUARD_OFFICER_NAME,
			"listener_name": TARGET_NPC_NAME,
			"speaker_text": guard_text,
			"reply_text": npc_text,
			"visibility": "private",
			"current_round": 1,
			"max_rounds": 999999,
			"is_recruitment_request": false,
			"recruitment_result": "none",
			"session_completed": true
		}
	})
	if event.is_empty():
		_fail("Failed to add guard dialogue fixture: %s" % dialogue_id)


func _add_npc_dialogue(memory_system: Node, day: int, time_text: String) -> void:
	var secret_text := "这段 NPC-NPC 对话不应出现在记录里"
	var event: Dictionary = memory_system.add_event({
		"type": "dialogue_turn",
		"day": day,
		"time": time_text,
		"subject_npc_id": TARGET_NPC_ID,
		"actor_ids": [TARGET_NPC_ID],
		"target_ids": [TARGET_NPC_ID, OTHER_NPC_ID],
		"location_id": "plaza",
		"visibility": "private",
		"payload": {
			"dialogue_id": "npc_npc_history_exclusion",
			"dialogue_kind": "npc_npc",
			"participant_npc_ids": [TARGET_NPC_ID, OTHER_NPC_ID],
			"dialogue_text": [{
				"speaker_id": TARGET_NPC_ID,
				"speaker_name": TARGET_NPC_NAME,
				"listener_id": OTHER_NPC_ID,
				"listener_name": OTHER_NPC_NAME,
				"text": secret_text
			}],
			"speaker_name": TARGET_NPC_NAME,
			"listener_name": OTHER_NPC_NAME,
			"speaker_text": secret_text,
			"reply_text": "",
			"visibility": "private",
			"current_round": 1,
			"max_rounds": 0,
			"is_recruitment_request": false,
			"recruitment_result": "none"
		}
	})
	if event.is_empty():
		_fail("Failed to add NPC-NPC exclusion fixture")


func _add_combat_boundary(
	memory_system: Node,
	event_type: String,
	day: int,
	time_text: String,
	wave_number: int
) -> void:
	var payload := {
		"wave_number": wave_number,
		"enemy_count": 2,
		"enemy_roster": [],
		"friendly_combatant_count": 1,
		"friendly_roster": []
	}
	if event_type == "combat_ended":
		payload["injured_npcs"] = []
		payload["unconscious_npcs"] = []
		payload["defeated_by_npc"] = []
		payload["reason"] = "enemies_defeated"
	var event: Dictionary = memory_system.add_event({
		"type": event_type,
		"day": day,
		"time": time_text,
		"subject_npc_id": "system",
		"actor_ids": ["system"],
		"target_ids": [],
		"location_id": "plaza",
		"visibility": "private",
		"payload": payload
	})
	if event.is_empty():
		_fail("Failed to add combat boundary fixture: %s" % event_type)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
