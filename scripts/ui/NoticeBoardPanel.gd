extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const GUARD_OFFICER_ID := "guard_officer"
const MINUTES_PER_DAY := 24 * 60
const TIME_STEP_MINUTES := 15

var notice_text_edit: TextEdit
var notice_status_label: Label
var publish_button: Button
var close_button: Button
var board_tabs: TabContainer
var schedule_advisory_label: Label
var schedule_rows: VBoxContainer
var schedule_status_label: Label
var schedule_add_button: Button
var schedule_publish_button: Button

var _schedule_draft: Array[Dictionary] = []
var _schedule_row_counter := 0
var _drag_controller


func _ready() -> void:
	visible = false
	_build_interface()
	var header := get_node_or_null("PanelContainer/MarginContainer/Content/Header") as Control
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, header)
	_connect_world_signals()


func show_notice_board() -> void:
	_load_published_state()
	board_tabs.current_tab = 0
	visible = true
	notice_text_edit.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	# 两个页面都只编辑本地草稿；关闭时立即恢复权威状态，避免下次打开泄露未发布内容。
	_load_published_state()


func _on_publish_pressed() -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("set_plaza_notice"):
		notice_status_label.text = "通告系统不可用。"
		return
	var notice := notice_text_edit.text.strip_edges()
	var event: Dictionary = memory_system.set_plaza_notice(notice, GUARD_OFFICER_ID)
	_refresh_published_labels()
	if event.is_empty():
		notice_status_label.text = "通告内容没有变化。"
	elif notice.is_empty():
		notice_status_label.text = "通告已清空并发布。"
	else:
		notice_status_label.text = "新通告已向全站 NPC 广播。"


func _on_schedule_publish_pressed() -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("set_plaza_reference_schedule"):
		schedule_status_label.text = "日程表系统不可用。"
		return
	var result: Dictionary = memory_system.set_plaza_reference_schedule(
		_schedule_draft.duplicate(true),
		GUARD_OFFICER_ID
	)
	if not bool(result.get("ok", false)):
		schedule_status_label.text = str(result.get("message", "日程表无法发布，请检查时间和内容。"))
		return
	_schedule_draft = _duplicate_schedule(result.get("schedule", []))
	_render_schedule_rows()
	_refresh_published_labels()
	if bool(result.get("changed", false)):
		schedule_status_label.text = "日程表已向全站 NPC 广播。"
	else:
		schedule_status_label.text = "日程表没有变化。"


func _on_schedule_add_pressed() -> void:
	var slot := _find_first_schedule_gap()
	var schedule_is_full := slot.x < 0
	if schedule_is_full:
		slot = Vector2i(0, 30)
	var row_id := _next_schedule_row_id()
	_schedule_draft.append({
		"id": row_id,
		"start_time": _format_time(slot.x),
		"end_time": _format_time(slot.y),
		"content": ""
	})
	_render_schedule_rows()
	if schedule_is_full:
		schedule_status_label.text = "已新增本地草稿，但现有日程表已覆盖全天；请先调整或删除重叠时段，再填写内容并发布。"
	else:
		schedule_status_label.text = "已新增本地草稿；填写内容并发布后才会生效。"


func _on_schedule_delete_pressed(row_id: String) -> void:
	for index in range(_schedule_draft.size()):
		if str(_schedule_draft[index].get("id", "")) != row_id:
			continue
		_schedule_draft.remove_at(index)
		break
	_render_schedule_rows()
	schedule_status_label.text = "已从本地草稿删除；发布后才会生效。"


func _on_schedule_time_selected(item_index: int, row_id: String, field: String, option: OptionButton) -> void:
	if item_index < 0 or item_index >= option.item_count:
		return
	var selected_time := str(option.get_item_metadata(item_index))
	for entry in _schedule_draft:
		if str(entry.get("id", "")) == row_id:
			entry[field] = selected_time
			break
	schedule_status_label.text = "日程表草稿有未发布的更改。"


func _on_schedule_content_changed(new_text: String, row_id: String) -> void:
	for entry in _schedule_draft:
		if str(entry.get("id", "")) == row_id:
			entry["content"] = new_text
			break
	schedule_status_label.text = "日程表草稿有未发布的更改。"


func _on_location_info_changed(location_id: String) -> void:
	if location_id == "plaza" and visible:
		# 外部入口更新公告牌时只刷新已发布摘要，不覆盖玩家正在编辑的草稿。
		_refresh_published_labels()


func _on_world_selection_changed(_id: String) -> void:
	close_panel()


func _build_interface() -> void:
	# 基准 1152×648 下保留上下 24px 安全区，同时给双页内容足够的阅读高度。
	offset_top = -300.0
	offset_bottom = 300.0
	var content := get_node_or_null("PanelContainer/MarginContainer/Content") as VBoxContainer
	if content == null:
		push_error("NoticeBoardPanel is missing its Content container.")
		return
	for child in content.get_children():
		child.free()

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "主厅前公告牌"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	close_button = Button.new()
	close_button.name = "NoticeCloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "退出并丢弃未发布的更改"
	close_button.custom_minimum_size = Vector2(36, 30)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	board_tabs = TabContainer.new()
	board_tabs.name = "BoardTabs"
	board_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board_tabs)
	_build_notice_tab()
	_build_schedule_tab()


func _build_notice_tab() -> void:
	var notice_page := Control.new()
	notice_page.name = "通告"
	board_tabs.add_child(notice_page)

	var notice_tab := VBoxContainer.new()
	notice_tab.name = "NoticeTabContent"
	notice_tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice_tab.add_theme_constant_override("separation", 10)
	notice_page.add_child(notice_tab)

	notice_text_edit = TextEdit.new()
	notice_text_edit.name = "NoticeTextEdit"
	notice_text_edit.placeholder_text = "以守备官的口吻写下要向驿站公开的通告……"
	notice_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notice_text_edit.custom_minimum_size = Vector2(0, 250)
	notice_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notice_tab.add_child(notice_text_edit)

	notice_status_label = Label.new()
	notice_status_label.name = "NoticeStatusLabel"
	notice_status_label.text = ""
	notice_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_tab.add_child(notice_status_label)

	var button_row := HBoxContainer.new()
	button_row.name = "NoticeButtonRow"
	button_row.add_theme_constant_override("separation", 8)
	notice_tab.add_child(button_row)

	var exit_button := Button.new()
	exit_button.name = "NoticeExitButton"
	exit_button.text = "退出"
	exit_button.tooltip_text = "丢弃这次未发布的草稿"
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_button.pressed.connect(close_panel)
	button_row.add_child(exit_button)

	publish_button = Button.new()
	publish_button.name = "NoticePublishButton"
	publish_button.text = "发布通告"
	publish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	publish_button.pressed.connect(_on_publish_pressed)
	button_row.add_child(publish_button)


func _build_schedule_tab() -> void:
	var schedule_page := Control.new()
	schedule_page.name = "日程表"
	board_tabs.add_child(schedule_page)

	var schedule_tab := VBoxContainer.new()
	schedule_tab.name = "ScheduleTabContent"
	schedule_tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	schedule_tab.add_theme_constant_override("separation", 8)
	schedule_page.add_child(schedule_tab)

	schedule_advisory_label = Label.new()
	schedule_advisory_label.name = "ScheduleAdvisoryLabel"
	schedule_advisory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	schedule_advisory_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.56))
	schedule_tab.add_child(schedule_advisory_label)

	var column_header := HBoxContainer.new()
	column_header.name = "ScheduleColumnHeader"
	column_header.add_theme_constant_override("separation", 8)
	schedule_tab.add_child(column_header)
	var time_header := Label.new()
	time_header.text = "建议时段"
	time_header.custom_minimum_size = Vector2(236, 0)
	column_header.add_child(time_header)
	var content_header := Label.new()
	content_header.text = "安排内容"
	content_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column_header.add_child(content_header)
	var action_header := Label.new()
	action_header.text = "操作"
	action_header.custom_minimum_size = Vector2(58, 0)
	column_header.add_child(action_header)

	var scroll := ScrollContainer.new()
	scroll.name = "ScheduleScroll"
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	schedule_tab.add_child(scroll)

	schedule_rows = VBoxContainer.new()
	schedule_rows.name = "ScheduleRows"
	schedule_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	schedule_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(schedule_rows)

	schedule_status_label = Label.new()
	schedule_status_label.name = "ScheduleStatusLabel"
	schedule_status_label.text = ""
	schedule_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	schedule_tab.add_child(schedule_status_label)

	var button_row := HBoxContainer.new()
	button_row.name = "ScheduleButtonRow"
	button_row.add_theme_constant_override("separation", 8)
	schedule_tab.add_child(button_row)

	schedule_add_button = Button.new()
	schedule_add_button.name = "ScheduleAddButton"
	schedule_add_button.text = "+ 新建安排"
	schedule_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	schedule_add_button.pressed.connect(_on_schedule_add_pressed)
	button_row.add_child(schedule_add_button)

	var exit_button := Button.new()
	exit_button.name = "ScheduleExitButton"
	exit_button.text = "退出"
	exit_button.tooltip_text = "丢弃这次未发布的日程表草稿"
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_button.pressed.connect(close_panel)
	button_row.add_child(exit_button)

	schedule_publish_button = Button.new()
	schedule_publish_button.name = "SchedulePublishButton"
	schedule_publish_button.text = "发布日程表"
	schedule_publish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	schedule_publish_button.pressed.connect(_on_schedule_publish_pressed)
	button_row.add_child(schedule_publish_button)


func _render_schedule_rows() -> void:
	if schedule_rows == null:
		return
	for child in schedule_rows.get_children():
		schedule_rows.remove_child(child)
		child.queue_free()
	for entry in _schedule_draft:
		_create_schedule_row(entry)
	if _schedule_draft.is_empty():
		var empty_label := Label.new()
		empty_label.name = "EmptyScheduleLabel"
		empty_label.text = "日程表尚无安排。点击“+ 新建安排”添加一条。"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 56)
		schedule_rows.add_child(empty_label)


func _create_schedule_row(entry: Dictionary) -> void:
	var row_id := str(entry.get("id", ""))
	var card := PanelContainer.new()
	card.name = "ScheduleRow_%s" % row_id
	card.set_meta("schedule_row_id", row_id)
	schedule_rows.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var start_option := OptionButton.new()
	start_option.name = "StartTime"
	start_option.custom_minimum_size = Vector2(96, 0)
	_populate_time_options(start_option, str(entry.get("start_time", "00:00")), false)
	start_option.item_selected.connect(_on_schedule_time_selected.bind(row_id, "start_time", start_option))
	row.add_child(start_option)

	var separator := Label.new()
	separator.text = "至"
	separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(separator)

	var end_option := OptionButton.new()
	end_option.name = "EndTime"
	end_option.custom_minimum_size = Vector2(96, 0)
	_populate_time_options(end_option, str(entry.get("end_time", "00:15")), true)
	end_option.item_selected.connect(_on_schedule_time_selected.bind(row_id, "end_time", end_option))
	row.add_child(end_option)

	var content_edit := LineEdit.new()
	content_edit.name = "ScheduleContent"
	content_edit.placeholder_text = "例如：工作、弥撒、休息／祈祷"
	content_edit.text = str(entry.get("content", ""))
	content_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_edit.text_changed.connect(_on_schedule_content_changed.bind(row_id))
	row.add_child(content_edit)

	var delete_button := Button.new()
	delete_button.name = "DeleteButton"
	delete_button.text = "删除"
	delete_button.tooltip_text = "从本地草稿删除，发布后生效"
	delete_button.custom_minimum_size = Vector2(58, 0)
	delete_button.pressed.connect(_on_schedule_delete_pressed.bind(row_id))
	row.add_child(delete_button)


func _populate_time_options(option: OptionButton, selected_time: String, allow_end_of_day: bool) -> void:
	var selected_index := -1
	var first_minutes := TIME_STEP_MINUTES if allow_end_of_day else 0
	var last_minutes := MINUTES_PER_DAY if allow_end_of_day else MINUTES_PER_DAY - TIME_STEP_MINUTES
	for minutes in range(first_minutes, last_minutes + 1, TIME_STEP_MINUTES):
		var time_text := _format_time(minutes)
		option.add_item(time_text)
		var index := option.item_count - 1
		option.set_item_metadata(index, time_text)
		if time_text == selected_time:
			selected_index = index
	if selected_index < 0:
		option.add_item(selected_time)
		selected_index = option.item_count - 1
		option.set_item_metadata(selected_index, selected_time)
	option.select(selected_index)


func _load_published_state() -> void:
	var state := _get_board_state()
	notice_text_edit.text = str(state.get("current_notice", ""))
	_schedule_draft = _duplicate_schedule(state.get("reference_schedule", []))
	_schedule_row_counter = _schedule_draft.size()
	_render_schedule_rows()
	_refresh_published_labels(state)
	notice_status_label.text = ""
	schedule_status_label.text = ""


func _refresh_published_labels(state: Dictionary = {}) -> void:
	var board_state := state if not state.is_empty() else _get_board_state()
	var advisory_note := str(board_state.get("schedule_advisory_note", ""))
	schedule_advisory_label.text = advisory_note


func _get_board_state() -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		return {}
	if memory_system.has_method("get_notice_board_state"):
		return memory_system.get_notice_board_state()
	if memory_system.has_method("get_location_snapshot"):
		var plaza: Dictionary = memory_system.get_location_snapshot("plaza")
		return {
			"current_notice": str(plaza.get("current_notice", "")),
			"reference_schedule": plaza.get("reference_schedule", []),
			"schedule_advisory_note": str(plaza.get("schedule_advisory_note", ""))
		}
	return {}


func _duplicate_schedule(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for raw_entry in value:
		if raw_entry is Dictionary:
			result.append((raw_entry as Dictionary).duplicate(true))
	return result


func _find_first_schedule_gap() -> Vector2i:
	var ranges: Array[Vector2i] = []
	for entry in _schedule_draft:
		var start_minutes := _time_to_minutes(str(entry.get("start_time", "")))
		var end_minutes := _time_to_minutes(str(entry.get("end_time", "")))
		if start_minutes >= 0 and end_minutes > start_minutes:
			ranges.append(Vector2i(start_minutes, end_minutes))
	ranges.sort_custom(func(left: Vector2i, right: Vector2i) -> bool: return left.x < right.x)
	var cursor := 0
	for occupied in ranges:
		if occupied.x - cursor >= 30:
			return Vector2i(cursor, cursor + 30)
		cursor = maxi(cursor, occupied.y)
	if MINUTES_PER_DAY - cursor >= 30:
		return Vector2i(cursor, cursor + 30)
	return Vector2i(-1, -1)


func _next_schedule_row_id() -> String:
	while true:
		_schedule_row_counter += 1
		var candidate := "schedule_%02d" % _schedule_row_counter
		var exists := false
		for entry in _schedule_draft:
			if str(entry.get("id", "")) == candidate:
				exists = true
				break
		if not exists:
			return candidate
	return "schedule_new"


func _time_to_minutes(value: String) -> int:
	var parts := value.split(":", false)
	if parts.size() != 2 or not str(parts[0]).is_valid_int() or not str(parts[1]).is_valid_int():
		return -1
	var hour := int(parts[0])
	var minute := int(parts[1])
	if hour == 24 and minute == 0:
		return MINUTES_PER_DAY
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return -1
	return hour * 60 + minute


func _format_time(minutes: int) -> String:
	if minutes >= MINUTES_PER_DAY:
		return "24:00"
	return "%02d:%02d" % [int(minutes / 60), minutes % 60]


func _connect_world_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	if event_bus.has_signal("notice_board_clicked"):
		event_bus.notice_board_clicked.connect(show_notice_board)
	if event_bus.has_signal("merchant_clicked"):
		event_bus.merchant_clicked.connect(close_panel)
	if event_bus.has_signal("location_info_changed"):
		event_bus.location_info_changed.connect(_on_location_info_changed)
	if event_bus.has_signal("npc_clicked"):
		event_bus.npc_clicked.connect(_on_world_selection_changed)
	if event_bus.has_signal("enemy_clicked"):
		event_bus.enemy_clicked.connect(_on_world_selection_changed)
	if event_bus.has_signal("horse_clicked"):
		event_bus.horse_clicked.connect(_on_world_selection_changed)
	if event_bus.has_signal("building_clicked"):
		event_bus.building_clicked.connect(_on_world_selection_changed)
