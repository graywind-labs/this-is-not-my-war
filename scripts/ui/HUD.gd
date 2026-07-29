extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var phase_label: Label = %PhaseLabel
@onready var resource_strip: HBoxContainer = $ResourceStrip
@onready var backend_status_label: Label = %BackendStatusLabel
@onready var speed_button: Button = $SpeedButton
@onready var pause_button: Button = $PauseButton
@onready var wave_countdown_label: Label = get_node_or_null("WaveCountdownLabel") as Label

const DETAIL_PANEL_OFFSET := Vector2(0.0, 6.0)
const MIN_USABLE_VIEWPORT_SIZE := Vector2(320.0, 240.0)
const FALLBACK_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
var _resource_labels: Dictionary = {}
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_text: RichTextLabel
var _detail_source_button: Control
var _detail_mode := ""
var _detail_drag_controller
var _escape_warning_label: Label
var _game_over_panel: PanelContainer
var _game_over_title_label: Label
var _game_over_reason_label: Label
var _game_over_detail_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_strip()
	_build_detail_panel()
	_build_wave_countdown_label()
	_build_escape_warning_label()
	_build_game_over_panel()
	if speed_button != null:
		speed_button.focus_mode = Control.FOCUS_NONE
		speed_button.tooltip_text = "点击循环 x1 / x2 / x4；主键盘 1 / 2 / 3 可直接切换。"
		speed_button.pressed.connect(_on_speed_button_pressed)
	if pause_button != null:
		pause_button.focus_mode = Control.FOCUS_NONE
		pause_button.pressed.connect(_on_pause_button_pressed)
	var alarm_button := get_node_or_null("AlarmButton") as Button
	if alarm_button != null:
		alarm_button.focus_mode = Control.FOCUS_NONE
		alarm_button.pressed.connect(_on_alarm_button_pressed)
	_refresh_time()
	_refresh_time_buttons()
	_refresh_resources()
	_refresh_wave_countdown()
	_refresh_backend_status()
	_connect_llm_bridge()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.time_changed.connect(_on_time_changed)
		event_bus.day_started.connect(_on_day_started)
		event_bus.hour_started.connect(_on_hour_started)
		event_bus.resource_changed.connect(_on_resource_changed)
		event_bus.building_state_changed.connect(_on_building_state_changed)
		if event_bus.has_signal("time_scale_changed"):
			event_bus.time_scale_changed.connect(_on_time_scale_changed)
		if event_bus.has_signal("gameplay_pause_changed"):
			event_bus.gameplay_pause_changed.connect(_on_gameplay_pause_changed)
		if event_bus.has_signal("game_over_changed"):
			event_bus.game_over_changed.connect(_on_game_over_changed)
		if event_bus.has_signal("npc_state_changed"):
			event_bus.npc_state_changed.connect(_on_npc_state_changed)
	_refresh_escape_warning()
	_refresh_game_over_panel()


func _input(event: InputEvent) -> void:
	var shortcut_scale := _get_speed_shortcut_scale(event)
	if shortcut_scale > 0.0:
		_set_time_scale_from_shortcut(shortcut_scale)
		get_viewport().set_input_as_handled()
		return
	if _is_pause_shortcut(event):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	var shortcut_scale := _get_speed_shortcut_scale(event)
	if shortcut_scale > 0.0:
		_set_time_scale_from_shortcut(shortcut_scale)
		get_viewport().set_input_as_handled()
		return
	if _is_pause_shortcut(event):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _detail_panel != null and _detail_panel.visible and _detail_source_button != null and (_detail_drag_controller == null or not _detail_drag_controller.has_user_position()):
		_position_detail_panel_near(_detail_source_button)


func _on_time_changed(_day: int, _hour: int, _minute: int, _second: int) -> void:
	_refresh_time()
	_refresh_wave_countdown()


func _on_day_started(_day: int) -> void:
	_refresh_time()
	_refresh_wave_countdown()


func _on_hour_started(_day: int, _hour: int) -> void:
	_refresh_time()
	_refresh_wave_countdown()


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	_refresh_resources()


func _on_building_state_changed(building_id: String) -> void:
	if building_id == "warehouse":
		_refresh_resources()


func _on_npc_state_changed(_npc_id: String) -> void:
	_refresh_escape_warning()


func _on_gameplay_pause_changed(_paused: bool) -> void:
	_refresh_time_buttons()


func _on_time_scale_changed(
	_player_scale: float,
	_effective_scale: float,
	_numeric_multiplier: float,
	_reason: String
) -> void:
	_refresh_time()
	_refresh_wave_countdown()
	_refresh_time_buttons()


func _on_game_over_changed(_result: String, _reason: String) -> void:
	_refresh_time_buttons()
	_refresh_game_over_panel()


func _on_speed_button_pressed() -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null:
		return

	time_system.cycle_speed()
	_refresh_time_buttons()


func _on_pause_button_pressed() -> void:
	_toggle_pause()


func _on_alarm_button_pressed() -> void:
	var combat_system := get_node_or_null("/root/Main/Systems/CombatSystem")
	if combat_system == null or not combat_system.has_method("trigger_combat_alarm"):
		return
	combat_system.trigger_combat_alarm("hud")


func _refresh_time() -> void:
	var game_state := get_node_or_null("/root/GameState")
	var day := 1
	var hour := 6
	var minute := 0
	var second := 0
	if game_state != null:
		day = game_state.current_day
		hour = game_state.current_hour
		minute = game_state.current_minute
		second = game_state.current_second

	day_label.text = "第 %d 天" % day
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	time_label.text = (
		str(time_system.format_game_clock(hour, minute, second))
		if time_system != null and time_system.has_method("format_game_clock")
		else "%02d:%02d:%02d" % [hour, minute, second]
	)
	phase_label.text = _get_phase_label(hour)


func _refresh_resources() -> void:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system == null:
		for resource_id in _resource_labels.keys():
			var label := _resource_labels[resource_id] as Label
			if label != null:
				label.text = "%s --" % str(resource_id)
		return

	if _resource_labels.is_empty():
		_build_resource_strip()

	for raw_resource_id in resource_system.get_resource_ids():
		var resource_id := str(raw_resource_id)
		var label := _resource_labels.get(resource_id, null) as Label
		if label == null:
			continue
		label.text = "%s %d" % [
			resource_system.get_resource_name(resource_id),
			resource_system.get_resource(resource_id)
		]
		_refresh_resource_capacity_tooltip(label, resource_system, resource_id)

	if _detail_panel != null and _detail_panel.visible:
		_refresh_detail_panel()


func _refresh_backend_status() -> void:
	var llm_bridge := get_node_or_null("/root/Main/Systems/LLMBridge")
	if llm_bridge == null or not llm_bridge.has_method("get_last_backend_status"):
		backend_status_label.text = "后端：未检查"
		return
	var status: Dictionary = llm_bridge.get_last_backend_status()
	backend_status_label.text = str(status.get("status_text", "后端：未检查"))


func _refresh_time_buttons() -> void:
	if speed_button == null:
		return

	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null:
		speed_button.text = "速度 x1"
		if pause_button != null:
			pause_button.text = "暂停"
		return

	speed_button.text = "速度 %s" % time_system.get_speed_label()
	if pause_button != null:
		pause_button.text = time_system.get_pause_label()


func _toggle_pause() -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null:
		return

	time_system.toggle_paused()
	_refresh_time_buttons()


func _set_time_scale_from_shortcut(scale: float) -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null:
		return
	time_system.set_time_scale(scale)
	_refresh_time_buttons()


func _get_speed_shortcut_scale(event: InputEvent) -> float:
	if not (event is InputEventKey):
		return 0.0
	var key_event := event as InputEventKey
	if (
		not key_event.pressed
		or key_event.echo
		or key_event.ctrl_pressed
		or key_event.alt_pressed
		or key_event.meta_pressed
		or key_event.shift_pressed
		or _is_text_input_focused()
	):
		return 0.0
	var shortcut_key := key_event.physical_keycode
	if shortcut_key == KEY_NONE:
		shortcut_key = key_event.keycode
	match shortcut_key:
		KEY_1:
			return 1.0
		KEY_2:
			return 2.0
		KEY_3:
			return 4.0
		_:
			return 0.0


func _is_pause_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	if not event.pressed or event.echo or event.keycode != KEY_SPACE:
		return false

	if _is_text_input_focused():
		return false
	return true


func _is_text_input_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _get_phase_label(hour: int) -> String:
	if hour >= 5 and hour < 12:
		return "阶段：清晨"
	if hour >= 12 and hour < 18:
		return "阶段：白昼"
	if hour >= 18 and hour < 22:
		return "阶段：黄昏"
	return "阶段：夜间"


func _connect_llm_bridge() -> void:
	var llm_bridge := get_node_or_null("/root/Main/Systems/LLMBridge")
	if llm_bridge == null or not llm_bridge.has_signal("backend_status_changed"):
		return
	if not llm_bridge.backend_status_changed.is_connected(_on_backend_status_changed):
		llm_bridge.backend_status_changed.connect(_on_backend_status_changed)


func _on_backend_status_changed(status_text: String, _ok: bool) -> void:
	backend_status_label.text = status_text


func _build_resource_strip() -> void:
	if resource_strip == null:
		return

	for child in resource_strip.get_children():
		resource_strip.remove_child(child)
		child.free()
	_resource_labels.clear()

	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	var resource_ids: Array = []
	if resource_system != null and resource_system.has_method("get_resource_ids"):
		resource_ids = resource_system.get_resource_ids()
	else:
		resource_ids = ["money", "grain", "meal", "wine", "weapons", "armor", "defense_devices", "horse_readiness", "wood", "stone", "iron"]

	for raw_resource_id in resource_ids:
		var resource_id := str(raw_resource_id)
		if not _should_show_resource_in_main_hud(resource_system, resource_id):
			continue
		var label := Label.new()
		label.name = "%sResourceLabel" % resource_id.to_pascal_case()
		label.layout_mode = 2
		label.text = "%s --" % _resource_display_name(resource_id)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		_refresh_resource_capacity_tooltip(label, resource_system, resource_id)
		resource_strip.add_child(label)
		_resource_labels[resource_id] = label

	var equipment_button := _make_detail_button("装备", "equipment")
	resource_strip.add_child(equipment_button)

	var devices_button := _make_detail_button("器械", "devices")
	resource_strip.add_child(devices_button)


func _refresh_resource_capacity_tooltip(
	label: Label,
	resource_system: Node,
	resource_id: String
) -> void:
	if (
		label == null
		or resource_system == null
		or not resource_system.has_method("get_resource_capacity")
	):
		if label != null:
			label.tooltip_text = ""
		return
	var capacity := int(resource_system.get_resource_capacity(resource_id))
	label.tooltip_text = (
		"仓库储存上限：%d" % capacity
		if capacity >= 0
		else ""
	)


func _build_escape_warning_label() -> void:
	if _escape_warning_label != null:
		return
	_escape_warning_label = Label.new()
	_escape_warning_label.name = "EscapeWarningLabel"
	_escape_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escape_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_escape_warning_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78, 1.0))
	_escape_warning_label.add_theme_color_override("font_outline_color", Color(0.26, 0.04, 0.02, 1.0))
	_escape_warning_label.add_theme_constant_override("outline_size", 5)
	_escape_warning_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_escape_warning_label.offset_left = 220.0
	_escape_warning_label.offset_right = -220.0
	_escape_warning_label.offset_top = 34.0
	_escape_warning_label.offset_bottom = 66.0
	_escape_warning_label.visible = false
	add_child(_escape_warning_label)


func _build_game_over_panel() -> void:
	if _game_over_panel != null:
		return
	_game_over_panel = PanelContainer.new()
	_game_over_panel.name = "GameOverPanel"
	_game_over_panel.visible = false
	_game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.custom_minimum_size = Vector2(760.0, 520.0)
	_game_over_panel.offset_left = -380.0
	_game_over_panel.offset_top = -260.0
	_game_over_panel.offset_right = 380.0
	_game_over_panel.offset_bottom = 260.0
	add_child(_game_over_panel)

	var margin := MarginContainer.new()
	margin.name = "GameOverMargin"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_game_over_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "GameOverContent"
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	_game_over_title_label = Label.new()
	_game_over_title_label.name = "GameOverTitleLabel"
	_game_over_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_title_label.add_theme_font_size_override("font_size", 24)
	_game_over_title_label.text = "防守失败"
	content.add_child(_game_over_title_label)

	_game_over_reason_label = Label.new()
	_game_over_reason_label.name = "GameOverReasonLabel"
	_game_over_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_reason_label.text = "原因：--"
	content.add_child(_game_over_reason_label)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "GameOverDetailScroll"
	detail_scroll.custom_minimum_size = Vector2(700.0, 360.0)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(detail_scroll)

	_game_over_detail_label = Label.new()
	_game_over_detail_label.name = "GameOverDetailLabel"
	_game_over_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_game_over_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_over_detail_label.text = "游戏已停止推进。"
	detail_scroll.add_child(_game_over_detail_label)


func _build_wave_countdown_label() -> void:
	if wave_countdown_label != null:
		return
	wave_countdown_label = Label.new()
	wave_countdown_label.name = "WaveCountdownLabel"
	wave_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_countdown_label.layout_mode = 0
	wave_countdown_label.offset_left = 24.0
	wave_countdown_label.offset_top = 118.0
	wave_countdown_label.offset_right = 520.0
	wave_countdown_label.offset_bottom = 142.0
	wave_countdown_label.text = "下一波：--"
	add_child(wave_countdown_label)
	if backend_status_label != null:
		backend_status_label.offset_top = 144.0
		backend_status_label.offset_bottom = 168.0
	if speed_button != null:
		speed_button.offset_top = 178.0
		speed_button.offset_bottom = 210.0
	if pause_button != null:
		pause_button.offset_top = 178.0
		pause_button.offset_bottom = 210.0
	var alarm_button := get_node_or_null("AlarmButton") as Button
	if alarm_button != null:
		alarm_button.offset_top = 178.0
		alarm_button.offset_bottom = 210.0


func _refresh_wave_countdown() -> void:
	if wave_countdown_label == null:
		return
	var combat_system := get_node_or_null("/root/Main/Systems/CombatSystem")
	if combat_system == null or not combat_system.has_method("get_wave_schedule_snapshot"):
		wave_countdown_label.text = "下一波：未接入"
		return
	var snapshot: Dictionary = combat_system.get_wave_schedule_snapshot()
	var active_enemy_count := int(snapshot.get("active_enemy_count", 0))
	var active_battle: Dictionary = snapshot.get("active_battle", {}) if snapshot.get("active_battle", {}) is Dictionary else {}
	var prefix := ""
	if active_enemy_count > 0:
		var current_wave := int(active_battle.get("wave_number", 0))
		prefix = "当前第%d波 敌人%d | " % [current_wave, active_enemy_count] if current_wave > 0 else "当前敌人%d | " % active_enemy_count
	if bool(snapshot.get("all_waves_triggered", false)):
		wave_countdown_label.text = "%s下一波：无" % prefix
		return
	var next_wave: Dictionary = snapshot.get("next_wave", {}) if snapshot.get("next_wave", {}) is Dictionary else {}
	if next_wave.is_empty():
		wave_countdown_label.text = "%s下一波：--" % prefix
		return
	var countdown_text := _format_wave_countdown(float(next_wave.get("seconds_until", 0.0)))
	wave_countdown_label.text = "%s下一波 第%d波：%s" % [
		prefix,
		int(next_wave.get("wave_number", 0)),
		countdown_text
	]


func _refresh_escape_warning() -> void:
	if _escape_warning_label == null:
		return
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc_state"):
		_escape_warning_label.visible = false
		return
	var names: Array[String] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if bool(state.get("escaped", false)):
			continue
		var intent: Dictionary = state.get("escape_intent", {}) if state.get("escape_intent", {}) is Dictionary else {}
		if not bool(intent.get("active", false)):
			continue
		if not ["escaping", "paused_unconscious"].has(str(intent.get("status", ""))):
			continue
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
		names.append(str(npc.get("name", npc_id)))
	if names.is_empty():
		_escape_warning_label.visible = false
		return
	_escape_warning_label.text = "警告：%s正在逃离驿站" % "、".join(names)
	_escape_warning_label.visible = true


func _refresh_game_over_panel() -> void:
	if _game_over_panel == null:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.get("game_over")):
		_game_over_panel.visible = false
		return
	var result := str(game_state.get("game_result"))
	var reason := str(game_state.get("game_over_reason"))
	if reason.is_empty():
		reason = str(game_state.get("failure_reason"))
	var settlement_snapshot: Dictionary = game_state.get("settlement_snapshot") if game_state.get("settlement_snapshot") is Dictionary else {}
	_game_over_title_label.text = "防守成功" if result == "victory" else "防守失败"
	_game_over_reason_label.text = "%s：%s" % [
		"结果" if result == "victory" else "原因",
		_format_game_over_reason(reason)
	]
	_game_over_detail_label.text = _build_game_over_detail_text(result, settlement_snapshot)
	_game_over_panel.visible = true
	_game_over_panel.move_to_front()


func _format_game_over_reason(reason: String) -> String:
	match reason:
		"main_hall_destroyed":
			return "主厅被摧毁"
		"no_available_combatants":
			return "无可战斗人员"
		"five_waves_survived":
			return "守住 5 波敌人"
		_:
			return reason if not reason.is_empty() else "未知"


func _build_game_over_detail_text(result: String, settlement_snapshot: Dictionary) -> String:
	var game_state := get_node_or_null("/root/GameState")
	var timestamp := "时间：--"
	if game_state != null:
		timestamp = "时间：第 %d 天 %02d:%02d:%02d" % [
			int(game_state.get("game_over_day")),
			int(game_state.get("game_over_hour")),
			int(game_state.get("game_over_minute")),
			int(game_state.get("game_over_second"))
		]
	if result != "victory":
		return "%s\n%s\n游戏已停止正常推进。" % [
			timestamp,
			_build_npc_endings_text(settlement_snapshot.get("npcs", {}) if settlement_snapshot.get("npcs", {}) is Dictionary else {})
		]
	return "%s\n%s\n%s\n%s\n\n%s\n游戏已停止正常推进。" % [
		timestamp,
		_build_victory_resource_summary(settlement_snapshot.get("resources", {}) if settlement_snapshot.get("resources", {}) is Dictionary else {}),
		_build_victory_building_summary(settlement_snapshot.get("buildings", {}) if settlement_snapshot.get("buildings", {}) is Dictionary else {}),
		_build_victory_npc_summary(settlement_snapshot.get("npcs", {}) if settlement_snapshot.get("npcs", {}) is Dictionary else {}),
		_build_npc_endings_text(settlement_snapshot.get("npcs", {}) if settlement_snapshot.get("npcs", {}) is Dictionary else {})
	]


func _build_victory_resource_summary(resources: Dictionary) -> String:
	var items: Array = resources.get("items", []) if resources.get("items", []) is Array else []
	if items.is_empty():
		return "剩余资源：未记录"
	var parts: Array[String] = []
	for index in range(mini(items.size(), 6)):
		var item: Dictionary = items[index] if items[index] is Dictionary else {}
		parts.append("%s %d" % [str(item.get("name", item.get("id", ""))), int(item.get("amount", 0))])
	return "剩余资源：%s" % " / ".join(parts)


func _build_victory_building_summary(buildings: Dictionary) -> String:
	var damaged: Array = buildings.get("damaged_buildings", []) if buildings.get("damaged_buildings", []) is Array else []
	var destroyed: Array = buildings.get("destroyed_buildings", []) if buildings.get("destroyed_buildings", []) is Array else []
	var operational := bool(buildings.get("station_operational", false))
	if damaged.is_empty() and destroyed.is_empty():
		return "建筑状态：%s，暂无损毁" % ("仍可运转" if operational else "不可运转")
	var damaged_names := _join_settlement_names(damaged, 4)
	var destroyed_names := _join_settlement_names(destroyed, 4)
	return "建筑状态：%s；受损 %s；摧毁 %s" % [
		"仍可运转" if operational else "不可运转",
		damaged_names if not damaged_names.is_empty() else "无",
		destroyed_names if not destroyed_names.is_empty() else "无"
	]


func _build_victory_npc_summary(npcs: Dictionary) -> String:
	var active: Array = npcs.get("active_npcs", []) if npcs.get("active_npcs", []) is Array else []
	var unconscious: Array = npcs.get("unconscious_npcs", []) if npcs.get("unconscious_npcs", []) is Array else []
	var escaped: Array = npcs.get("escaped_npcs", []) if npcs.get("escaped_npcs", []) is Array else []
	return "NPC：可行动 %d（%s）；昏迷 %d（%s）；逃离 %d（%s）" % [
		active.size(),
		_join_settlement_names(active, 3, "无"),
		unconscious.size(),
		_join_settlement_names(unconscious, 3, "无"),
		escaped.size(),
		_join_settlement_names(escaped, 3, "无")
	]


func _build_npc_endings_text(npcs: Dictionary) -> String:
	var items: Array = npcs.get("items", []) if npcs.get("items", []) is Array else []
	if items.is_empty():
		return "NPC 结局：未记录"
	var lines: Array[String] = ["NPC 结局："]
	for raw_item in items:
		var item: Dictionary = raw_item if raw_item is Dictionary else {}
		var recruited_text := "已入伍" if bool(item.get("recruited", false)) else "未入伍"
		var status_text := str(item.get("final_status_label", item.get("final_status", "可行动")))
		var location_text := str(item.get("current_location_name", item.get("current_location", "未知")))
		var opinion := str(item.get("final_opinion", "Mock：尚无明确看法。"))
		var fate := str(item.get("fate_summary", "Mock：后续命运未记录。"))
		lines.append("- %s：%s / %s / 最后位置：%s" % [
			str(item.get("name", item.get("id", ""))),
			status_text,
			recruited_text,
			location_text
		])
		lines.append("  对守备官最终看法：%s" % opinion)
		lines.append("  后续命运：%s" % fate)
	return "\n".join(lines)


func _join_settlement_names(items: Array, limit: int, empty_text: String = "") -> String:
	if items.is_empty():
		return empty_text
	var names: Array[String] = []
	for index in range(mini(items.size(), limit)):
		var item: Dictionary = items[index] if items[index] is Dictionary else {}
		names.append(str(item.get("name", item.get("id", ""))))
	if items.size() > limit:
		names.append("等%d人" % items.size())
	return "、".join(names)


func _format_wave_countdown(seconds_until: float) -> String:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	var total_seconds := (
		int(time_system.get_display_duration_seconds(seconds_until))
		if time_system != null and time_system.has_method("get_display_duration_seconds")
		else ceili(maxf(0.0, seconds_until))
	)
	if total_seconds <= 0:
		return "即将来袭"
	var days := total_seconds / 86400
	var remainder := total_seconds % 86400
	var hours := remainder / 3600
	remainder %= 3600
	var minutes := remainder / 60
	if days > 0:
		return "%d天%02d时" % [days, hours]
	if hours > 0:
		return "%d时%02d分" % [hours, minutes]
	return "%d分%02d秒" % [minutes, remainder % 60]


func _make_detail_button(text: String, mode: String) -> Button:
	var button := Button.new()
	button.name = "%sDetailButton" % mode.to_pascal_case()
	button.text = text
	button.tooltip_text = "查看%s库存详情" % text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(58, 24)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func() -> void:
		_toggle_detail_panel(mode, button)
	)
	return button


func _build_detail_panel() -> void:
	if _detail_panel != null:
		return

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "ResourceDetailPanel"
	_detail_panel.visible = false
	_detail_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_detail_panel.position = Vector2(24, 116)
	_detail_panel.custom_minimum_size = Vector2(360, 220)
	_detail_panel.size = _detail_panel.custom_minimum_size
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_detail_panel)

	var margin := MarginContainer.new()
	margin.name = "ResourceDetailMargin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_detail_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "ResourceDetailContent"
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	_detail_title = Label.new()
	_detail_title.text = "库存详情"
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_detail_title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func() -> void:
		_detail_panel.visible = false
		_detail_source_button = null
		_detail_mode = ""
	)
	header.add_child(close_button)
	_detail_drag_controller = DraggablePanelController.new()
	_detail_drag_controller.bind(_detail_panel, header)

	_detail_text = RichTextLabel.new()
	_detail_text.name = "ResourceDetailText"
	_detail_text.bbcode_enabled = false
	_detail_text.fit_content = true
	_detail_text.custom_minimum_size = Vector2(340, 150)
	_detail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_detail_text)


func _toggle_detail_panel(mode: String, source_button: Control) -> void:
	if _detail_panel == null:
		return
	if _detail_panel.visible and _detail_mode == mode:
		_detail_panel.visible = false
		_detail_source_button = null
		_detail_mode = ""
		return
	_detail_mode = mode
	_detail_source_button = source_button
	_refresh_detail_panel()
	_detail_panel.visible = true
	if _detail_drag_controller == null or not _detail_drag_controller.has_user_position():
		_position_detail_panel_near(source_button)
	_detail_panel.move_to_front()


func _refresh_detail_panel() -> void:
	if _detail_text == null or _detail_title == null:
		return
	if _detail_mode == "equipment":
		_detail_title.text = "装备库存"
		_detail_text.text = _build_equipment_detail_text()
	elif _detail_mode == "devices":
		_detail_title.text = "器械库存"
		_detail_text.text = _build_device_detail_text()


func _position_detail_panel_near(source_button: Control) -> void:
	if _detail_panel == null or source_button == null:
		return

	var button_rect := source_button.get_global_rect()
	var panel_size := _get_panel_size(_detail_panel)
	var desired_position := button_rect.position + Vector2(0.0, button_rect.size.y) + DETAIL_PANEL_OFFSET
	_detail_panel.global_position = _clamp_panel_position(desired_position, panel_size)


func _get_panel_size(panel: Control) -> Vector2:
	var panel_size := panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel.custom_minimum_size
	return panel_size


func _clamp_panel_position(desired_position: Vector2, panel_size: Vector2) -> Vector2:
	var viewport_size := _get_usable_viewport_size()
	var max_x := maxf(0.0, viewport_size.x - panel_size.x)
	var max_y := maxf(0.0, viewport_size.y - panel_size.y)
	return Vector2(
		clampf(desired_position.x, 0.0, max_x),
		clampf(desired_position.y, 0.0, max_y)
	)


func _get_usable_viewport_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < MIN_USABLE_VIEWPORT_SIZE.x or viewport_size.y < MIN_USABLE_VIEWPORT_SIZE.y:
		return FALLBACK_VIEWPORT_SIZE
	return viewport_size


func _build_equipment_detail_text() -> String:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	var equipment_system := get_node_or_null("/root/Main/Systems/EquipmentSystem")
	var lines: Array[String] = []

	lines.append("具体库存")
	lines.append("武器：%s" % _build_inventory_group_text(resource_system, "weapon"))
	lines.append("盔甲：%s" % _build_inventory_group_text(resource_system, "armor"))
	lines.append("弹药：%s" % _build_inventory_group_text(resource_system, "ammunition"))
	var horse_system := get_node_or_null("/root/Main/Systems/HorseSystem")
	if horse_system != null and horse_system.has_method("get_stable_summary"):
		var stable_summary: Dictionary = horse_system.get_stable_summary()
		lines.append("马厩：%d 匹（成年 %d / 小马 %d）" % [
			int(stable_summary.get("total_count", stable_summary.get("total", 0))),
			int(stable_summary.get("adult_count", stable_summary.get("adult", 0))),
			int(stable_summary.get("foal_count", stable_summary.get("foal", 0)))
		])

	if equipment_system == null:
		lines.append("EquipmentSystem 不可用。")
		return "\n".join(lines)

	lines.append("")
	lines.append("已分配：%s" % _build_equipped_summary())
	return "\n".join(lines)


func _build_device_detail_text() -> String:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	var lines: Array[String] = [
		"具体库存：%s" % _build_inventory_group_text(resource_system, "defense_device")
	]
	var device_system := get_node_or_null("/root/Main/Systems/DefenseDeviceSystem")
	if device_system != null and device_system.has_method("get_deployments"):
		var deployments: Array = device_system.get_deployments()
		lines.append("已部署：%d 件" % deployments.size())
		for raw_deployment in deployments:
			if raw_deployment is Dictionary:
				lines.append("- %s / %s" % [
					str(raw_deployment.get("device_name", "工程器械")),
					str(raw_deployment.get("slot_name", "围墙槽位"))
				])
	return "\n".join(lines)


func _build_inventory_group_text(resource_system: Node, detail_group: String) -> String:
	if resource_system == null or not resource_system.has_method("get_resource_ids"):
		return "无法读取"
	var parts: Array[String] = []
	for raw_resource_id in resource_system.get_resource_ids():
		var resource_id := str(raw_resource_id)
		var definition: Dictionary = resource_system.get_resource_definition(resource_id)
		if str(definition.get("detail_group", "")) != detail_group:
			continue
		parts.append("%s %d" % [
			str(definition.get("name", resource_id)),
			int(resource_system.get_resource(resource_id))
		])
	return "、".join(parts) if not parts.is_empty() else "无"


func _should_show_resource_in_main_hud(resource_system: Node, resource_id: String) -> bool:
	if resource_system == null or not resource_system.has_method("get_resource_definition"):
		return not ["weapons", "armor", "horse_readiness", "defense_devices"].has(resource_id)
	var definition: Dictionary = resource_system.get_resource_definition(resource_id)
	return bool(definition.get("show_in_main_hud", true))


func _join_named_defs(system: Node, ids: Array, method_name: String) -> String:
	var names: Array[String] = []
	for raw_id in ids:
		var id := str(raw_id)
		var definition: Dictionary = system.call(method_name, id)
		names.append(str(definition.get("name", id)))
	if names.is_empty():
		return "无"
	return "、".join(names)


func _join_named_armor(equipment_system: Node) -> String:
	var slot_ids: Array = equipment_system.get_armor_slot_ids()
	var names: Array[String] = []
	for raw_slot in slot_ids:
		var slot := str(raw_slot)
		var armor_ids: Array = equipment_system.get_armor_ids(slot)
		if armor_ids.is_empty():
			continue
		var armor_id := str(armor_ids[0])
		var definition: Dictionary = equipment_system.get_armor_def(armor_id)
		var slot_label := slot
		if equipment_system.has_method("get_slot_label"):
			slot_label = str(equipment_system.get_slot_label(slot))
		names.append("%s：%s" % [slot_label, str(definition.get("name", slot))])
	if names.is_empty():
		return "无"
	return "；".join(names)


func _build_equipped_summary() -> String:
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return "无法读取 NPC"

	var weapon_count := 0
	var armor_count := 0
	var mount_count := 0
	for raw_npc_id in npc_system.get_npc_ids():
		var npc: Dictionary = npc_system.get_npc(str(raw_npc_id))
		var equipment: Dictionary = npc.get("equipment", {})
		if not str(equipment.get("main_weapon", {}).get("id", "")).is_empty():
			weapon_count += 1
		for slot in ["helmet", "chest", "bracers", "greaves"]:
			if not str(equipment.get(slot, {}).get("id", "")).is_empty():
				armor_count += 1
		if not str(equipment.get("mount", {}).get("id", "")).is_empty():
			mount_count += 1

	return "武器 %d 件 / 盔甲 %d 件 / 坐骑 %d 匹" % [weapon_count, armor_count, mount_count]


func _get_resource_amount(resource_system: Node, resource_id: String) -> int:
	if resource_system == null or not resource_system.has_method("get_resource"):
		return 0
	return int(resource_system.get_resource(resource_id))


func _resource_display_name(resource_id: String) -> String:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system != null and resource_system.has_method("get_resource_name"):
		return resource_system.get_resource_name(resource_id)
	return resource_id
