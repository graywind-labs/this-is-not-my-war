extends Control

const GM_ENABLED := true

const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"

const DEFAULT_LOCATION_IDS := [
	"plaza", "dormitory", "dining_hall", "tavern", "garden", "blacksmith",
	"training_ground", "stable", "chapel", "clinic", "workshop"
]
const DEFAULT_VISIBILITIES := ["private", "local_public", "plaza_public"]
const COMMAND_HISTORY_LIMIT := 40

var _gm_button: Button
var _panel: PanelContainer
var _command_input: LineEdit
var _result_text: TextEdit
var _resource_select: OptionButton
var _resource_amount_input: LineEdit
var _building_select: OptionButton
var _building_amount_input: LineEdit
var _npc_select: OptionButton
var _npc_state_key_input: LineEdit
var _npc_state_value_input: LineEdit
var _location_select: OptionButton
var _action_select: OptionButton
var _notice_input: LineEdit
var _visibility_select: OptionButton
var _memory_amount_input: LineEdit
var _event_type_input: LineEdit
var _day_input: LineEdit
var _hour_input: LineEdit
var _minute_input: LineEdit
var _second_input: LineEdit
var _is_dragging_button := false
var _button_dragged := false
var _drag_offset := Vector2.ZERO
var _history: Array[String] = []


func _ready() -> void:
	visible = GM_ENABLED
	if not GM_ENABLED:
		process_mode = Node.PROCESS_MODE_DISABLED
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	call_deferred("_refresh_options")


func _build_ui() -> void:
	_gm_button = Button.new()
	_gm_button.name = "GMButton"
	_gm_button.text = "GM"
	_gm_button.tooltip_text = "打开 GM 调试面板"
	_gm_button.custom_minimum_size = Vector2(56, 36)
	_gm_button.position = Vector2(24, 220)
	_gm_button.modulate = Color(1.0, 1.0, 1.0, 0.68)
	_gm_button.focus_mode = Control.FOCUS_NONE
	_gm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_gm_button)
	_gm_button.pressed.connect(_on_gm_button_pressed)
	_gm_button.gui_input.connect(_on_gm_button_gui_input)

	_panel = PanelContainer.new()
	_panel.name = "GMWindow"
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(620, 620)
	_panel.position = Vector2(72, 72)
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	var title := Label.new()
	title.text = "GM 调试面板"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.focus_mode = Control.FOCUS_NONE
	refresh_button.pressed.connect(_refresh_options)
	header.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func() -> void:
		_panel.visible = false
	)
	header.add_child(close_button)

	var command_row := HBoxContainer.new()
	content.add_child(command_row)

	_command_input = LineEdit.new()
	_command_input.placeholder_text = "输入 GM 命令，例如 help / add_resource money 20 / memory cook_01"
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.text_submitted.connect(func(_text: String) -> void:
		_execute_command_from_input()
	)
	command_row.add_child(_command_input)

	var execute_button := Button.new()
	execute_button.text = "执行"
	execute_button.focus_mode = Control.FOCUS_NONE
	execute_button.pressed.connect(_execute_command_from_input)
	command_row.add_child(execute_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(596, 410)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 10)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sections)

	_add_resource_section(sections)
	_add_time_section(sections)
	_add_building_section(sections)
	_add_npc_section(sections)
	_add_action_section(sections)
	_add_memory_section(sections)

	_result_text = TextEdit.new()
	_result_text.editable = false
	_result_text.custom_minimum_size = Vector2(596, 130)
	_result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_result_text)
	_log("GM 面板已就绪。输入 help 查看命令。")


func _add_resource_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("资源"))
	var row := _make_row(parent)
	_resource_select = _make_select(row)
	_resource_amount_input = _make_input(row, "数量", "20", 80)
	_add_button(row, "增加", func() -> void:
		_run_add_resource(_selected_id(_resource_select), _int_from_input(_resource_amount_input, 0))
	)
	_add_button(row, "扣除", func() -> void:
		_run_spend_resource(_selected_id(_resource_select), _int_from_input(_resource_amount_input, 0))
	)
	_add_button(row, "快照", _show_resource_snapshot)


func _add_time_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("时间"))
	var row := _make_row(parent)
	_day_input = _make_input(row, "天", "1", 54)
	_hour_input = _make_input(row, "时", "6", 54)
	_minute_input = _make_input(row, "分", "0", 54)
	_second_input = _make_input(row, "秒", "0", 54)
	_add_button(row, "设置", func() -> void:
		_run_set_time(
			_int_from_input(_day_input, 1),
			_int_from_input(_hour_input, 6),
			_int_from_input(_minute_input, 0),
			_int_from_input(_second_input, 0)
		)
	)
	_add_button(row, "跳 1 小时", _run_advance_hour)
	_add_button(row, "LLM 减速", func() -> void:
		_run_slowdown("gm_manual", -1.0, "gm_manual")
	)
	_add_button(row, "清减速", _run_clear_slowdowns)


func _add_building_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("建筑"))
	var row := _make_row(parent)
	_building_select = _make_select(row)
	_building_amount_input = _make_input(row, "数值", "20", 80)
	_add_button(row, "选中", func() -> void:
		_run_select_building(_selected_id(_building_select))
	)
	_add_button(row, "受损", func() -> void:
		_run_damage_building(_selected_id(_building_select), _int_from_input(_building_amount_input, 0))
	)
	_add_button(row, "修复", func() -> void:
		_run_repair_building(_selected_id(_building_select))
	)
	_add_button(row, "升级", func() -> void:
		_run_upgrade_building(_selected_id(_building_select))
	)
	_add_button(row, "快照", func() -> void:
		_show_building(_selected_id(_building_select))
	)


func _add_npc_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("NPC"))
	var row := _make_row(parent)
	_npc_select = _make_select(row)
	_location_select = _make_select(row)
	_add_button(row, "选中", func() -> void:
		_run_select_npc(_selected_id(_npc_select))
	)
	_add_button(row, "移动到地点", func() -> void:
		_run_move_npc(_selected_id(_npc_select), _selected_id(_location_select))
	)
	_add_button(row, "立即进入", func() -> void:
		_run_enter_location(_selected_id(_npc_select), _selected_id(_location_select))
	)

	var state_row := _make_row(parent)
	_npc_state_key_input = _make_input(state_row, "状态字段", "satiety", 120)
	_npc_state_value_input = _make_input(state_row, "值", "80", 100)
	_add_button(state_row, "设置状态", func() -> void:
		_run_set_npc_state(
			_selected_id(_npc_select),
			_npc_state_key_input.text.strip_edges(),
			_parse_value(_npc_state_value_input.text)
		)
	)
	_add_button(state_row, "NPC 快照", func() -> void:
		_show_npc(_selected_id(_npc_select))
	)


func _add_action_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("行动"))
	var row := _make_row(parent)
	_action_select = _make_select(row)
	_add_button(row, "指定行动", func() -> void:
		_run_assign_action(_selected_id(_npc_select), _selected_id(_action_select))
	)
	_add_button(row, "工作", func() -> void:
		_run_work(_selected_id(_npc_select), _selected_id(_building_select))
	)
	_add_button(row, "吃饭", func() -> void:
		_run_eat(_selected_id(_npc_select))
	)
	_add_button(row, "睡觉", func() -> void:
		_run_sleep(_selected_id(_npc_select))
	)


func _add_memory_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_title("记忆 / 见闻 / 广场"))
	var row := _make_row(parent)
	_notice_input = _make_input(row, "公告内容", "今天所有人先吃饭。", 260)
	_add_button(row, "写公告", func() -> void:
		_run_plaza_notice(_notice_input.text)
	)
	_add_button(row, "地点快照", func() -> void:
		_show_location(_selected_id(_location_select))
	)
	_add_button(row, "短期记忆", func() -> void:
		_show_memory(_selected_id(_npc_select))
	)

	var event_row := _make_row(parent)
	_visibility_select = _make_select(event_row)
	_memory_amount_input = _make_input(event_row, "数值", "5", 70)
	_event_type_input = _make_input(event_row, "事件类型", "plaza_status_changed", 170)
	_add_button(event_row, "给钱事件", func() -> void:
		_run_give_money(_selected_id(_npc_select), _int_from_input(_memory_amount_input, 0), _selected_id(_visibility_select))
	)
	_add_button(event_row, "攻击事件", func() -> void:
		_run_attack_npc(_selected_id(_npc_select), _int_from_input(_memory_amount_input, 0), _selected_id(_visibility_select))
	)
	_add_button(event_row, "广场广播", func() -> void:
		_run_public_event(_event_type_input.text.strip_edges(), _selected_id(_npc_select))
	)
	_add_button(event_row, "事件列表", _show_events)


func _make_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _make_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _make_select(row: HBoxContainer) -> OptionButton:
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(150, 30)
	select.focus_mode = Control.FOCUS_NONE
	row.add_child(select)
	return select


func _make_input(row: HBoxContainer, placeholder: String, text: String, width: int) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.text = text
	input.custom_minimum_size = Vector2(width, 30)
	row.add_child(input)
	return input


func _add_button(row: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	row.add_child(button)
	return button


func _refresh_options() -> void:
	_fill_resource_select()
	_fill_building_select()
	_fill_npc_select()
	_fill_action_select()
	_fill_location_select()
	_fill_visibility_select()
	_log("GM 选项已刷新。")


func _fill_resource_select() -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var ids: Array = []
	if resource_system != null and resource_system.has_method("get_resource_ids"):
		ids = resource_system.get_resource_ids()
	_fill_select(_resource_select, ids, func(id: String) -> String:
		if resource_system != null and resource_system.has_method("get_resource_name"):
			return "%s | %s" % [id, resource_system.get_resource_name(id)]
		return id
	)


func _fill_building_select() -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var ids: Array = []
	if building_system != null and building_system.has_method("get_building_ids"):
		ids = building_system.get_building_ids()
	_fill_select(_building_select, ids, func(id: String) -> String:
		if building_system != null:
			var building: Dictionary = building_system.get_building(id)
			return "%s | %s" % [id, str(building.get("name", id))]
		return id
	)


func _fill_npc_select() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var ids: Array = []
	if npc_system != null and npc_system.has_method("get_npc_ids"):
		ids = npc_system.get_npc_ids()
	_fill_select(_npc_select, ids, func(id: String) -> String:
		if npc_system != null:
			var npc: Dictionary = npc_system.get_npc(id)
			return "%s | %s" % [id, str(npc.get("name", id))]
		return id
	)


func _fill_action_select() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var ids: Array = []
	if action_system != null and action_system.has_method("get_action_ids"):
		ids = action_system.get_action_ids()
	_fill_select(_action_select, ids, func(id: String) -> String:
		if action_system != null:
			var action: Dictionary = action_system.get_action(id)
			return "%s | %s" % [id, str(action.get("name", id))]
		return id
	)


func _fill_location_select() -> void:
	_fill_select(_location_select, DEFAULT_LOCATION_IDS, func(id: String) -> String:
		return id
	)


func _fill_visibility_select() -> void:
	_fill_select(_visibility_select, DEFAULT_VISIBILITIES, func(id: String) -> String:
		return id
	)


func _fill_select(select: OptionButton, ids: Array, label_getter: Callable) -> void:
	if select == null:
		return
	var previous_id := _selected_id(select)
	select.clear()
	var selected_index := 0
	for raw_id in ids:
		var id := str(raw_id)
		var index := select.get_item_count()
		select.add_item(str(label_getter.call(id)))
		select.set_item_metadata(index, id)
		if id == previous_id:
			selected_index = index
	if select.get_item_count() > 0:
		select.select(selected_index)


func _selected_id(select: OptionButton) -> String:
	if select == null or select.get_item_count() <= 0:
		return ""
	var metadata: Variant = select.get_item_metadata(select.selected)
	if metadata != null:
		return str(metadata)
	return select.get_item_text(select.selected).split(" | ")[0]


func _execute_command_from_input() -> void:
	var command := _command_input.text.strip_edges()
	if command.is_empty():
		return
	_log("> %s" % command)
	_execute_command(command)
	_command_input.clear()


func _execute_command(command: String) -> void:
	var parts := command.split(" ", false)
	if parts.is_empty():
		return

	var op := str(parts[0]).to_lower()
	match op:
		"help":
			_log(_help_text())
		"refresh":
			_refresh_options()
		"snapshot":
			_show_resource_snapshot()
			_show_events()
		"add_resource":
			if _require_args(parts, 3, "add_resource <resource_id> <amount>"):
				_run_add_resource(str(parts[1]), int(parts[2]))
		"spend_resource":
			if _require_args(parts, 3, "spend_resource <resource_id> <amount>"):
				_run_spend_resource(str(parts[1]), int(parts[2]))
		"set_time":
			if _require_args(parts, 5, "set_time <day> <hour> <minute> <second>"):
				_run_set_time(int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4]))
		"advance_hour":
			_run_advance_hour()
		"slowdown":
			if parts.size() >= 2:
				var scale := float(parts[2]) if parts.size() >= 3 else -1.0
				var reason := str(parts[3]) if parts.size() >= 4 else "gm_manual"
				_run_slowdown(str(parts[1]), scale, reason)
			else:
				_run_slowdown("gm_manual", -1.0, "gm_manual")
		"release_slowdown":
			if _require_args(parts, 2, "release_slowdown <request_id>"):
				_run_release_slowdown(str(parts[1]))
		"clear_slowdowns":
			_run_clear_slowdowns()
		"select_npc":
			if _require_args(parts, 2, "select_npc <npc_id>"):
				_run_select_npc(str(parts[1]))
		"select_building":
			if _require_args(parts, 2, "select_building <building_id>"):
				_run_select_building(str(parts[1]))
		"move_npc":
			if _require_args(parts, 3, "move_npc <npc_id> <building_id>"):
				_run_move_npc(str(parts[1]), str(parts[2]))
		"enter_location":
			if _require_args(parts, 3, "enter_location <npc_id> <location_id>"):
				_run_enter_location(str(parts[1]), str(parts[2]))
		"set_npc_state":
			if _require_args(parts, 4, "set_npc_state <npc_id> <key> <value>"):
				_run_set_npc_state(str(parts[1]), str(parts[2]), _parse_value(str(parts[3])))
		"assign_action":
			if _require_args(parts, 3, "assign_action <npc_id> <action_id>"):
				_run_assign_action(str(parts[1]), str(parts[2]))
		"work":
			if _require_args(parts, 3, "work <npc_id> <building_id>"):
				_run_work(str(parts[1]), str(parts[2]))
		"eat":
			if _require_args(parts, 2, "eat <npc_id>"):
				_run_eat(str(parts[1]))
		"sleep":
			if _require_args(parts, 2, "sleep <npc_id>"):
				_run_sleep(str(parts[1]))
		"damage_building":
			if _require_args(parts, 3, "damage_building <building_id> <amount>"):
				_run_damage_building(str(parts[1]), int(parts[2]))
		"repair_building":
			if _require_args(parts, 2, "repair_building <building_id>"):
				_run_repair_building(str(parts[1]))
		"upgrade_building":
			if _require_args(parts, 2, "upgrade_building <building_id>"):
				_run_upgrade_building(str(parts[1]))
		"plaza_notice":
			_run_plaza_notice(command.substr("plaza_notice".length()).strip_edges())
		"give_money":
			if _require_args(parts, 3, "give_money <npc_id> <amount> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "local_public"
				_run_give_money(str(parts[1]), int(parts[2]), visibility)
		"attack_npc":
			if _require_args(parts, 3, "attack_npc <npc_id> <damage> [visibility]"):
				var visibility := str(parts[3]) if parts.size() >= 4 else "plaza_public"
				_run_attack_npc(str(parts[1]), int(parts[2]), visibility)
		"memory":
			if _require_args(parts, 2, "memory <npc_id>"):
				_show_memory(str(parts[1]))
		"location":
			if _require_args(parts, 2, "location <location_id>"):
				_show_location(str(parts[1]))
		"events":
			_show_events()
		"plaza_events":
			_show_plaza_events()
		_:
			_log("未知命令：%s。输入 help 查看命令。" % op)


func _require_args(parts: Array, count: int, usage: String) -> bool:
	if parts.size() >= count:
		return true
	_log("参数不足：%s" % usage)
	return false


func _run_add_resource(resource_id: String, amount: int) -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		_log("ResourceSystem 不可用。")
		return
	var ok: bool = resource_system.debug_add_resource(resource_id, amount)
	_log("资源增加 %s %+d：%s，当前=%d" % [resource_id, amount, _ok_text(ok), resource_system.get_resource(resource_id)])


func _run_spend_resource(resource_id: String, amount: int) -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		_log("ResourceSystem 不可用。")
		return
	var ok: bool = resource_system.debug_spend_resources({resource_id: amount})
	_log("资源扣除 %s %d：%s，当前=%d" % [resource_id, amount, _ok_text(ok), resource_system.get_resource(resource_id)])


func _show_resource_snapshot() -> void:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		_log("ResourceSystem 不可用。")
		return
	_log("资源快照：%s" % _compact(resource_system.get_resource_snapshot()))


func _run_set_time(day: int, hour: int, minute: int, second: int) -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.set_current_time(day, hour, minute, second)
	_log("时间已设置为第 %d 天 %02d:%02d:%02d。" % [day, hour, minute, second])


func _run_advance_hour() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.debug_advance_hour()
	_log("已跳过 1 小时。")


func _run_slowdown(request_id: String, scale: float, reason: String) -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.request_time_slowdown(request_id, scale, reason)
	_log("已注册减速请求：%s，有效倍率=%s。" % [request_id, time_system.get_effective_speed_label()])


func _run_release_slowdown(request_id: String) -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.release_time_slowdown(request_id)
	_log("已释放减速请求：%s，有效倍率=%s。" % [request_id, time_system.get_effective_speed_label()])


func _run_clear_slowdowns() -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		_log("TimeSystem 不可用。")
		return
	time_system.clear_time_slowdowns()
	_log("已清空所有减速请求。")


func _run_select_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	_log("选中建筑 %s：%s" % [building_id, _ok_text(building_system.debug_select_building(building_id))])


func _run_damage_building(building_id: String, amount: int) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	var ok: bool = building_system.debug_damage_building(building_id, amount)
	_log("建筑受损 %s -%d：%s" % [building_id, amount, _ok_text(ok)])
	_show_building(building_id)


func _run_repair_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	var ok: bool = building_system.repair_building(building_id)
	_log("修复建筑 %s：%s" % [building_id, _ok_text(ok)])
	_show_building(building_id)


func _run_upgrade_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	var ok: bool = building_system.upgrade_building(building_id)
	_log("升级建筑 %s：%s" % [building_id, _ok_text(ok)])
	_show_building(building_id)


func _show_building(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		_log("BuildingSystem 不可用。")
		return
	_log("建筑快照 %s：%s" % [building_id, _compact(building_system.get_building(building_id))])


func _run_select_npc(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("选中 NPC %s：%s" % [npc_id, _ok_text(npc_system.debug_select_npc(npc_id))])


func _run_move_npc(npc_id: String, building_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("移动 NPC %s -> %s：%s" % [npc_id, building_id, _ok_text(npc_system.debug_move_npc_to_building(npc_id, building_id))])


func _run_enter_location(npc_id: String, location_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("NPC 立即进入 %s -> %s：%s" % [npc_id, location_id, _ok_text(npc_system.debug_enter_location_immediately(npc_id, location_id))])


func _run_set_npc_state(npc_id: String, key: String, value: Variant) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("设置 NPC 状态 %s.%s=%s：%s" % [npc_id, key, str(value), _ok_text(npc_system.set_npc_state_value(npc_id, key, value))])


func _show_npc(npc_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		_log("NPCSystem 不可用。")
		return
	_log("NPC 快照 %s：%s" % [npc_id, _compact(npc_system.get_npc(npc_id))])


func _run_assign_action(npc_id: String, action_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派行动 %s -> %s：%s" % [npc_id, action_id, _ok_text(action_system.debug_assign_action(npc_id, action_id))])


func _run_work(npc_id: String, building_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派工作 %s -> %s：%s" % [npc_id, building_id, _ok_text(action_system.debug_assign_work(npc_id, building_id))])


func _run_eat(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派吃饭 %s：%s" % [npc_id, _ok_text(action_system.debug_assign_eat(npc_id))])


func _run_sleep(npc_id: String) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_log("ActionSystem 不可用。")
		return
	_log("指派睡觉 %s：%s" % [npc_id, _ok_text(action_system.debug_assign_sleep(npc_id))])


func _run_plaza_notice(text: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	memory_system.debug_set_plaza_notice(text)
	_log("广场公告已更新：%s" % text)


func _run_give_money(npc_id: String, amount: int, visibility: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var event: Dictionary = memory_system.debug_record_player_money_given(npc_id, amount, visibility)
	_log("给钱事件：%s" % _compact(event))


func _run_attack_npc(npc_id: String, damage: int, visibility: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var event: Dictionary = memory_system.debug_record_player_attack_npc(npc_id, damage, visibility)
	_log("攻击事件：%s" % _compact(event))


func _run_public_event(event_type: String, subject_npc_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var event: Dictionary = memory_system.debug_broadcast_plaza_public_event(event_type, subject_npc_id, {"source": "gm_panel"})
	_log("广场广播：%s" % _compact(event))


func _show_memory(npc_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	_log("短期记忆 %s：%s" % [npc_id, _compact(memory_system.debug_get_npc_short_term_memory(npc_id))])


func _show_location(location_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	_log("地点快照 %s：%s" % [location_id, _compact(memory_system.debug_get_location_snapshot(location_id))])


func _show_events() -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var events: Array = memory_system.debug_get_all_events()
	_log("全局事件 %d 条：%s" % [events.size(), _compact(_tail(events, 8))])


func _show_plaza_events() -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_log("MemorySystem 不可用。")
		return
	var events: Array = memory_system.debug_get_plaza_public_events()
	_log("广场公开事件 %d 条：%s" % [events.size(), _compact(_tail(events, 8))])


func _on_gm_button_pressed() -> void:
	if _button_dragged:
		_button_dragged = false
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_panel.move_to_front()


func _on_gm_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_dragging_button = event.pressed
		if event.pressed:
			_button_dragged = false
			_drag_offset = event.position
		return

	if event is InputEventMouseMotion and _is_dragging_button:
		var motion := event as InputEventMouseMotion
		if motion.relative.length() > 1.0:
			_button_dragged = true
		var viewport_size := get_viewport_rect().size
		var next_position := _gm_button.position + motion.relative
		next_position.x = clampf(next_position.x, 0.0, viewport_size.x - _gm_button.size.x)
		next_position.y = clampf(next_position.y, 0.0, viewport_size.y - _gm_button.size.y)
		_gm_button.position = next_position


func _int_from_input(input: LineEdit, fallback: int) -> int:
	if input == null:
		return fallback
	var text := input.text.strip_edges()
	if text.is_valid_int():
		return int(text)
	return fallback


func _parse_value(text: String) -> Variant:
	var clean := text.strip_edges()
	if clean.to_lower() == "true":
		return true
	if clean.to_lower() == "false":
		return false
	if clean.is_valid_int():
		return int(clean)
	if clean.is_valid_float():
		return float(clean)
	return clean


func _tail(items: Array, max_count: int) -> Array:
	var start := maxi(0, items.size() - max_count)
	return items.slice(start, items.size())


func _compact(value: Variant) -> String:
	var text := JSON.stringify(value)
	if text.length() > 2200:
		return "%s..." % text.substr(0, 2200)
	return text


func _ok_text(ok: bool) -> String:
	return "成功" if ok else "失败"


func _log(message: String) -> void:
	_history.append(message)
	while _history.size() > COMMAND_HISTORY_LIMIT:
		_history.remove_at(0)
	if _result_text != null:
		_result_text.text = "\n".join(_history)
		_result_text.scroll_vertical = _result_text.get_line_count()


func _help_text() -> String:
	return "\n".join([
		"常用命令：",
		"refresh | snapshot | events | plaza_events",
		"add_resource <id> <amount> | spend_resource <id> <amount>",
		"set_time <day> <hour> <minute> <second> | advance_hour",
		"slowdown [id] [scale] [reason] | release_slowdown <id> | clear_slowdowns",
		"select_npc <npc_id> | select_building <building_id>",
		"move_npc <npc_id> <building_id> | enter_location <npc_id> <location_id>",
		"set_npc_state <npc_id> <key> <value>",
		"assign_action <npc_id> <action_id> | work <npc_id> <building_id> | eat <npc_id> | sleep <npc_id>",
		"damage_building <building_id> <amount> | repair_building <building_id> | upgrade_building <building_id>",
		"plaza_notice <text> | give_money <npc_id> <amount> [visibility] | attack_npc <npc_id> <damage> [visibility]",
		"memory <npc_id> | location <location_id>"
	])
