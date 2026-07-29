extends SceneTree

const PLAZA_NPC_ID := "priest_01"
const INDOOR_NPC_ID := "doctor_01"
const EXPECTED_SCHEDULE_ADVISORY := "这是建议日程，驿站成员不一定严格按照这个日程，如有特殊事务可自行安排"


func _init() -> void:
	root.size = Vector2i(1152, 648)
	DisplayServer.window_set_size(root.size)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	root.size = Vector2i(1152, 648)
	await process_frame

	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var notice_panel := root.get_node_or_null("Main/UI/NoticeBoardPanel")
	if memory_system == null or npc_system == null or notice_panel == null:
		_fail("Notice board systems or UI are missing")
		return

	var initial_state: Dictionary = memory_system.get_notice_board_state()
	var initial_notice := str(initial_state.get("current_notice", ""))
	var initial_schedule: Array = initial_state.get("reference_schedule", [])
	var advisory_note := str(initial_state.get("schedule_advisory_note", ""))
	if not initial_notice.contains("边境战事已起") or not initial_notice.contains("勤勉工作") or not initial_notice.contains("积极应征入伍") or not initial_notice.contains("守备官"):
		_fail("Initial narrative announcement is missing required guard-officer wartime guidance")
		return
	if initial_schedule.size() < 8:
		_fail("Initial reference schedule is not a complete daily schedule")
		return
	if not _schedule_covers_required_content(initial_schedule):
		_fail("Initial reference schedule does not cover sleep, three meals, work, mass and rest/prayer")
		return
	if advisory_note != EXPECTED_SCHEDULE_ADVISORY:
		_fail("Schedule advisory note does not match the immersive board copy")
		return

	for npc_id in npc_system.get_npc_ids():
		var witnesses: Array = memory_system.get_npc_witness_events(str(npc_id))
		if _count_initial_board_events(witnesses, "plaza_notice_changed") != 1:
			_fail("Initial announcement was not preseeded exactly once for %s" % str(npc_id))
			return
		if _count_initial_board_events(witnesses, "plaza_schedule_changed") != 1:
			_fail("Initial schedule was not preseeded exactly once for %s" % str(npc_id))
			return
		var seeded_schedule := _find_event(witnesses, "plaza_schedule_changed", "initial_notice_board_state")
		if not str(seeded_schedule.get("summary", "")).contains(EXPECTED_SCHEDULE_ADVISORY):
			_fail("Initial schedule witness is missing the advisory semantics for %s" % str(npc_id))
			return

	var board_tabs := notice_panel.find_child("BoardTabs", true, false) as TabContainer
	var notice_text_edit := notice_panel.find_child("NoticeTextEdit", true, false) as TextEdit
	var notice_status_label := notice_panel.find_child("NoticeStatusLabel", true, false) as Label
	var schedule_advisory_label := notice_panel.find_child("ScheduleAdvisoryLabel", true, false) as Label
	var schedule_status_label := notice_panel.find_child("ScheduleStatusLabel", true, false) as Label
	var schedule_add_button := notice_panel.find_child("ScheduleAddButton", true, false) as Button
	var schedule_publish_button := notice_panel.find_child("SchedulePublishButton", true, false) as Button
	if board_tabs == null or notice_text_edit == null or notice_status_label == null or schedule_advisory_label == null or schedule_status_label == null or schedule_add_button == null or schedule_publish_button == null:
		_fail("Professional two-tab notice board controls are missing")
		return
	if board_tabs.get_tab_count() != 2 or board_tabs.get_tab_title(0) != "通告" or board_tabs.get_tab_title(1) != "日程表":
		_fail("Notice board tabs are not named 通告 / 日程表")
		return
	if notice_panel.find_child("CurrentNoticeLabel", true, false) != null or notice_panel.find_child("NoticeDraftLabel", true, false) != null:
		_fail("Announcement tab still contains redundant published-count or draft heading labels")
		return
	if not notice_status_label.text.is_empty() or not schedule_status_label.text.is_empty():
		_fail("Notice board tabs still show redundant default draft/publish instructions")
		return
	if schedule_add_button.text != "+ 新建安排" or schedule_publish_button.text != "发布日程表":
		_fail("Schedule tab actions do not use the 日程表 wording")
		return

	# Announcement editing is a local draft until publish; closing must restore the published text.
	notice_panel.show_notice_board()
	await process_frame
	await process_frame
	if schedule_advisory_label.text != EXPECTED_SCHEDULE_ADVISORY:
		_fail("Schedule tab does not show the configured immersive advisory copy")
		return
	var panel_container := notice_panel.get_node_or_null("PanelContainer") as PanelContainer
	if panel_container == null or not _rect_inside_viewport(panel_container.get_global_rect(), root.size) or not _controls_inside_panel(panel_container, [
		notice_text_edit,
		notice_panel.find_child("NoticePublishButton", true, false),
		notice_panel.find_child("NoticeExitButton", true, false)
	]):
		_fail("Announcement tab controls or panel overflow at 1152x648: %s" % str(panel_container.get_global_rect() if panel_container != null else Rect2()))
		return
	board_tabs.current_tab = 1
	await process_frame
	var schedule_scroll := notice_panel.find_child("ScheduleScroll", true, false) as ScrollContainer
	if schedule_scroll == null or not _controls_inside_panel(panel_container, [
		schedule_scroll,
		schedule_add_button,
		schedule_publish_button,
		notice_panel.find_child("ScheduleExitButton", true, false)
	]):
		_fail("Reference schedule tab controls overflow the notice board panel at 1152x648")
		return
	if not _schedule_rows_fit_horizontally(schedule_scroll, notice_panel):
		_fail("Reference schedule row content overflows horizontally at 1152x648")
		return
	board_tabs.current_tab = 0
	await process_frame
	notice_text_edit.text = "这段草稿不应保存。"
	notice_panel.close_panel()
	if str(memory_system.get_notice_board_state().get("current_notice", "")) != initial_notice:
		_fail("Closing the notice editor saved an unpublished draft")
		return
	notice_panel.show_notice_board()
	if notice_text_edit.text != initial_notice:
		_fail("Reopening the notice editor did not restore the published announcement")
		return
	board_tabs.current_tab = 1
	schedule_add_button.pressed.emit()
	await process_frame
	var full_schedule_status := notice_panel.find_child("ScheduleStatusLabel", true, false) as Label
	var full_day_added_id := ""
	for raw_entry in (notice_panel.get("_schedule_draft") as Array):
		var entry: Dictionary = raw_entry
		if not _has_schedule_id(initial_schedule, str(entry.get("id", ""))):
			full_day_added_id = str(entry.get("id", ""))
			break
	if full_day_added_id.is_empty() or full_schedule_status == null or not full_schedule_status.text.contains("覆盖全天"):
		_fail("Adding to a full-day schedule should create a draft row and explain how to resolve overlap")
		return
	var full_day_added_card := _find_schedule_card(notice_panel, full_day_added_id)
	var full_day_delete: Button = null
	if full_day_added_card != null:
		full_day_delete = full_day_added_card.find_child("DeleteButton", true, false) as Button
	if full_day_delete == null:
		_fail("Full-day schedule draft row cannot be deleted")
		return
	full_day_delete.pressed.emit()
	await process_frame
	board_tabs.current_tab = 0

	# A changed page broadcasts once to every eligible NPC in the station, regardless of location.
	npc_system.debug_enter_location_immediately(PLAZA_NPC_ID, "plaza")
	npc_system.debug_enter_location_immediately(INDOOR_NPC_ID, "clinic")
	var notice_witness_counts_before := _capture_witness_counts(memory_system, npc_system.get_npc_ids())
	var notice_events_before := int(_count_events(memory_system.get_plaza_events(), "plaza_notice_changed"))
	var schedule_events_before_notice := int(_count_events(memory_system.get_plaza_events(), "plaza_schedule_changed"))
	var changed_notice := "驿站诸位：今晚请检查工具与粮食。——守备官"
	notice_text_edit.text = changed_notice
	notice_panel._on_publish_pressed()
	if str(memory_system.get_notice_board_state().get("current_notice", "")) != changed_notice:
		_fail("Publishing the announcement did not update plaza current state")
		return
	if _count_events(memory_system.get_plaza_events(), "plaza_notice_changed") != notice_events_before + 1:
		_fail("Publishing one changed announcement did not create exactly one notice event")
		return
	if _count_events(memory_system.get_plaza_events(), "plaza_schedule_changed") != schedule_events_before_notice:
		_fail("Publishing an announcement also broadcast an unchanged reference schedule")
		return
	if not _all_witness_counts_increased_once(memory_system, notice_witness_counts_before):
		_fail("Changed announcement was not broadcast exactly once to every station NPC")
		return
	var latest_notice_event := _find_latest_event(memory_system.get_plaza_events(), "plaza_notice_changed")
	if (
		not str(latest_notice_event.get("summary", "")).contains("守备官更新了通告")
		or str(latest_notice_event.get("payload", {}).get("notice", "")) != changed_notice
	):
		_fail("Published announcement did not keep the guard-officer update summary and new content")
		return
	var unchanged_notice_counts := _capture_witness_counts(memory_system, npc_system.get_npc_ids())
	notice_panel._on_publish_pressed()
	if not _all_witness_counts_unchanged(memory_system, unchanged_notice_counts):
		_fail("Publishing an unchanged announcement duplicated the all-station broadcast")
		return

	# Add/edit/delete only modify the schedule draft. One publish produces one schedule event.
	var schedule_events_before := int(_count_events(memory_system.get_plaza_events(), "plaza_schedule_changed"))
	var published_before_edit: Array = memory_system.get_plaza_reference_schedule()
	var original_card := _find_schedule_card(notice_panel, "late_afternoon_rest")
	if original_card == null:
		_fail("Initial schedule row card is missing")
		return
	var delete_button := original_card.find_child("DeleteButton", true, false) as Button
	if delete_button == null:
		_fail("Schedule row delete control is missing")
		return
	delete_button.pressed.emit()
	schedule_add_button.pressed.emit()
	await process_frame
	if JSON.stringify(memory_system.get_plaza_reference_schedule()) != JSON.stringify(published_before_edit):
		_fail("Schedule add/delete changed authoritative state before publish")
		return
	if _count_events(memory_system.get_plaza_events(), "plaza_schedule_changed") != schedule_events_before:
		_fail("Editing a schedule draft broadcast a witness event before publish")
		return

	var draft: Array = notice_panel.get("_schedule_draft")
	var added_id := ""
	for raw_entry in draft:
		var entry: Dictionary = raw_entry
		if not _has_schedule_id(published_before_edit, str(entry.get("id", ""))):
			added_id = str(entry.get("id", ""))
			break
	if added_id.is_empty():
		_fail("Adding a schedule row did not create a draft entry")
		return
	var added_card := _find_schedule_card(notice_panel, added_id)
	if added_card == null:
		_fail("New schedule row was not rendered")
		return
	var content_edit := added_card.find_child("ScheduleContent", true, false) as LineEdit
	var end_option := added_card.find_child("EndTime", true, false) as OptionButton
	if content_edit == null or end_option == null:
		_fail("New schedule row editing controls are missing")
		return
	content_edit.text = "休息／祈祷"
	content_edit.text_changed.emit(content_edit.text)
	if not _select_time(end_option, "18:00"):
		_fail("Schedule time selector cannot choose 18:00")
		return

	var schedule_witness_counts_before := _capture_witness_counts(memory_system, npc_system.get_npc_ids())
	var notice_events_before_schedule := int(_count_events(memory_system.get_plaza_events(), "plaza_notice_changed"))
	schedule_publish_button.pressed.emit()
	await process_frame
	var published_schedule: Array = memory_system.get_plaza_reference_schedule()
	if not _has_schedule_id(published_schedule, added_id) or _has_schedule_id(published_schedule, "late_afternoon_rest"):
		_fail("Published schedule did not apply the draft add/delete atomically")
		return
	if _count_events(memory_system.get_plaza_events(), "plaza_schedule_changed") != schedule_events_before + 1:
		_fail("Publishing one schedule draft did not create exactly one plaza schedule event")
		return
	if _count_events(memory_system.get_plaza_events(), "plaza_notice_changed") != notice_events_before_schedule:
		_fail("Publishing a schedule also broadcast an unchanged announcement")
		return
	if not _all_witness_counts_increased_once(memory_system, schedule_witness_counts_before):
		_fail("Changed reference schedule was not broadcast exactly once to every station NPC")
		return
	var latest_schedule_event := _find_latest_event(memory_system.get_plaza_events(), "plaza_schedule_changed")
	if (
		not str(latest_schedule_event.get("summary", "")).contains("守备官更新了参考日程")
		or not str(latest_schedule_event.get("summary", "")).contains(EXPECTED_SCHEDULE_ADVISORY)
	):
		_fail("Published schedule event omitted its distinct guard-officer update or advisory note")
		return

	# Closing also discards an unpublished schedule deletion.
	var published_key := JSON.stringify(published_schedule)
	notice_panel.show_notice_board()
	notice_panel._on_schedule_delete_pressed(added_id)
	notice_panel.close_panel()
	if JSON.stringify(memory_system.get_plaza_reference_schedule()) != published_key:
		_fail("Closing the schedule tab saved an unpublished deletion")
		return

	# A later plaza entrant gets the location snapshot without receiving either board page again.
	var entrant_before := int(memory_system.get_npc_witness_events(INDOOR_NPC_ID).size())
	npc_system.debug_enter_location_immediately(INDOOR_NPC_ID, "plaza")
	var entrant_events: Array = memory_system.get_npc_witness_events(INDOOR_NPC_ID).slice(entrant_before)
	if (
		not _find_event(entrant_events, "plaza_notice_changed", "notice_changed").is_empty()
		or not _find_event(entrant_events, "plaza_schedule_changed", "reference_schedule_changed").is_empty()
	):
		_fail("Entering the plaza rebroadcast a notice-board page")
		return
	var entry_snapshot := _find_event(entrant_events, "location_status_changed", "location_entry_snapshot")
	if entry_snapshot.is_empty():
		_fail("Later plaza entrant did not receive a location entry snapshot")
		return
	var snapshot: Dictionary = entry_snapshot.get("payload", {}).get("location_snapshot", {})
	if snapshot.has("current_notice") or snapshot.has("reference_schedule") or snapshot.has("schedule_advisory_note"):
		_fail("Later plaza entrant snapshot repeated notice-board content")
		return
	var entry_summary := str(entry_snapshot.get("summary", ""))
	if entry_summary.contains("公告牌") or entry_summary.contains("参考日程") or entry_summary.contains("仅用作参考"):
		_fail("Later plaza entrant summary repeated notice-board content")
		return

	print("T0046 notice board tabs and plaza state verification passed.")
	quit(0)


func _schedule_covers_required_content(schedule: Array) -> bool:
	var contents: Array[String] = []
	for raw_entry in schedule:
		contents.append(str((raw_entry as Dictionary).get("content", "")))
	return (
		contents.count("早餐") == 1
		and contents.count("午餐") == 1
		and contents.count("晚餐") == 1
		and contents.count("弥撒") == 1
		and contents.has("工作")
		and contents.has("睡觉")
		and contents.has("休息／祈祷")
	)


func _count_initial_board_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type and str(event.get("payload", {}).get("reason", "")) == "initial_notice_board_state":
			count += 1
	return count


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count


func _capture_witness_counts(memory_system: Node, npc_ids: Array) -> Dictionary:
	var counts := {}
	for npc_id in npc_ids:
		counts[str(npc_id)] = memory_system.get_npc_witness_events(str(npc_id)).size()
	return counts


func _all_witness_counts_increased_once(memory_system: Node, counts_before: Dictionary) -> bool:
	for npc_id in counts_before.keys():
		if memory_system.get_npc_witness_events(str(npc_id)).size() != int(counts_before[npc_id]) + 1:
			return false
	return true


func _all_witness_counts_unchanged(memory_system: Node, counts_before: Dictionary) -> bool:
	for npc_id in counts_before.keys():
		if memory_system.get_npc_witness_events(str(npc_id)).size() != int(counts_before[npc_id]):
			return false
	return true


func _find_event(events: Array, event_type: String, reason: String) -> Dictionary:
	for raw_event in events:
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type and str(event.get("payload", {}).get("reason", "")) == reason:
			return event
	return {}


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _find_schedule_card(panel: Node, row_id: String) -> PanelContainer:
	for node in panel.find_children("ScheduleRow_*", "PanelContainer", true, false):
		if str(node.get_meta("schedule_row_id", "")) == row_id:
			return node as PanelContainer
	return null


func _has_schedule_id(schedule: Array, row_id: String) -> bool:
	for raw_entry in schedule:
		if str((raw_entry as Dictionary).get("id", "")) == row_id:
			return true
	return false


func _select_time(option: OptionButton, time_text: String) -> bool:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) != time_text:
			continue
		option.select(index)
		option.item_selected.emit(index)
		return true
	return false


func _controls_inside_panel(panel: Control, controls: Array) -> bool:
	var panel_rect := panel.get_global_rect().grow(1.0)
	for control in controls:
		if control == null or not control is Control:
			return false
		if not panel_rect.encloses((control as Control).get_global_rect()):
			return false
	return true


func _rect_inside_viewport(rect: Rect2, viewport_size: Vector2i) -> bool:
	return (
		rect.position.x >= -1.0
		and rect.position.y >= -1.0
		and rect.end.x <= float(viewport_size.x) + 1.0
		and rect.end.y <= float(viewport_size.y) + 1.0
	)


func _schedule_rows_fit_horizontally(scroll: ScrollContainer, panel: Node) -> bool:
	var scroll_rect := scroll.get_global_rect().grow(1.0)
	for node in panel.find_children("ScheduleRow_*", "PanelContainer", true, false):
		var row_rect := (node as Control).get_global_rect()
		if row_rect.position.x < scroll_rect.position.x or row_rect.end.x > scroll_rect.end.x:
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
