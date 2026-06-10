extends Control

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var phase_label: Label = %PhaseLabel
@onready var resource_strip: HBoxContainer = $ResourceStrip
@onready var backend_status_label: Label = %BackendStatusLabel
@onready var speed_button: Button = $SpeedButton
@onready var pause_button: Button = $PauseButton

const DETAIL_PANEL_OFFSET := Vector2(0.0, 6.0)
const MIN_USABLE_VIEWPORT_SIZE := Vector2(320.0, 240.0)
const FALLBACK_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const DETAIL_PANEL_RESOURCE_IDS := {
	"weapons": true,
	"armor": true,
	"horse_readiness": true,
	"defense_devices": true
}

var _resource_labels: Dictionary = {}
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_text: RichTextLabel
var _detail_source_button: Control
var _detail_mode := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_strip()
	_build_detail_panel()
	if speed_button != null:
		speed_button.focus_mode = Control.FOCUS_NONE
		speed_button.pressed.connect(_on_speed_button_pressed)
	if pause_button != null:
		pause_button.focus_mode = Control.FOCUS_NONE
		pause_button.pressed.connect(_on_pause_button_pressed)
	var alarm_button := get_node_or_null("AlarmButton") as Button
	if alarm_button != null:
		alarm_button.focus_mode = Control.FOCUS_NONE
	_refresh_time()
	_refresh_time_buttons()
	_refresh_resources()
	_refresh_backend_status()
	_connect_llm_bridge()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.time_changed.connect(_on_time_changed)
		event_bus.day_started.connect(_on_day_started)
		event_bus.hour_started.connect(_on_hour_started)
		event_bus.resource_changed.connect(_on_resource_changed)


func _input(event: InputEvent) -> void:
	if _is_pause_shortcut(event):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if _is_pause_shortcut(event):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _detail_panel != null and _detail_panel.visible and _detail_source_button != null:
		_position_detail_panel_near(_detail_source_button)


func _on_time_changed(_day: int, _hour: int, _minute: int, _second: int) -> void:
	_refresh_time()


func _on_day_started(_day: int) -> void:
	_refresh_time()


func _on_hour_started(_day: int, _hour: int) -> void:
	_refresh_time()


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	_refresh_resources()


func _on_speed_button_pressed() -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null:
		return

	time_system.cycle_speed()
	_refresh_time_buttons()


func _on_pause_button_pressed() -> void:
	_toggle_pause()


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
	time_label.text = "%02d:%02d:%02d" % [hour, minute, second]
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


func _is_pause_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	if not event.pressed or event.echo or event.keycode != KEY_SPACE:
		return false

	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return false
	return true


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
		if DETAIL_PANEL_RESOURCE_IDS.has(resource_id):
			continue
		var label := Label.new()
		label.name = "%sResourceLabel" % resource_id.to_pascal_case()
		label.layout_mode = 2
		label.text = "%s --" % _resource_display_name(resource_id)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resource_strip.add_child(label)
		_resource_labels[resource_id] = label

	var equipment_button := _make_detail_button("装备", "equipment")
	resource_strip.add_child(equipment_button)

	var devices_button := _make_detail_button("器械", "devices")
	resource_strip.add_child(devices_button)


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

	lines.append("库存：武器 %d / 盔甲 %d / 马匹整备 %d" % [
		_get_resource_amount(resource_system, "weapons"),
		_get_resource_amount(resource_system, "armor"),
		_get_resource_amount(resource_system, "horse_readiness")
	])

	if equipment_system == null:
		lines.append("EquipmentSystem 不可用。")
		return "\n".join(lines)

	lines.append("")
	lines.append("主武器：%s" % _join_named_defs(equipment_system, equipment_system.get_weapon_ids(), "get_weapon_def"))
	lines.append("盔甲：%s" % _join_named_armor(equipment_system))
	lines.append("坐骑：%s" % _join_named_defs(equipment_system, equipment_system.get_mount_ids(), "get_mount_def"))
	lines.append("")
	lines.append("已分配：%s" % _build_equipped_summary())
	return "\n".join(lines)


func _build_device_detail_text() -> String:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	return "\n".join([
		"工程器械库存：%d" % _get_resource_amount(resource_system, "defense_devices"),
		"",
		"当前包含工械坊制造的弩床、拒马等防御器械占位库存。",
		"部署到围墙、自动攻击或阻挡敌人仍由后续工程器械部署任务接入。"
	])


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
