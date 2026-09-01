extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const PietyAbilityButtonClass = preload("res://scripts/ui/PietyAbilityButton.gd")

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var phase_label: Label = %PhaseLabel
@onready var resource_strip: HBoxContainer = $ResourceStrip
@onready var backend_status_label: Label = %BackendStatusLabel
@onready var speed_button: Button = $SpeedButton
@onready var pause_button: Button = $PauseButton
@onready var wave_countdown_label: Label = get_node_or_null("WaveCountdownLabel") as Label
@onready var hud_frame: Panel = $HUDFrame
@onready var escape_started_alert_dialog: AcceptDialog = %EscapeStartedAlertDialog
@onready var npc_revived_alert_dialog: AcceptDialog = %NpcRevivedAlertDialog

const DETAIL_PANEL_OFFSET := Vector2(0.0, 6.0)
const DETAIL_PANEL_MINIMUM_SIZE := Vector2(500.0, 430.0)
const DETAIL_SCROLL_MINIMUM_SIZE := Vector2(470.0, 360.0)
const DETAIL_ITEM_BUTTON_SIZE := Vector2(68.0, 68.0)
const DETAIL_ITEM_ICON_MAX_WIDTH := 66
const DETAIL_ITEM_CONTENT_MARGIN := 1.0
const DETAIL_ITEM_BORDER_WIDTH := 1
const DETAIL_GRID_COLUMNS := 6
const ASSIGNED_ITEM_MODULATE := Color(0.44, 0.44, 0.44, 0.78)
const MIN_USABLE_VIEWPORT_SIZE := Vector2(320.0, 240.0)
const FALLBACK_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const HUD_FRAME_CONTENT_PADDING := Vector2(12.0, 12.0)
const SPEED_BUTTON_NORMAL_TOOLTIP := "点击循环 x1 / x2 / x4；主键盘 1 / 2 / 3 可直接切换。"
const RESOURCE_ICON_PATHS := {
	"money": "res://assets/ui/resource_icons/money.svg",
	"grain": "res://assets/ui/resource_icons/grain.svg",
	"meal": "res://assets/ui/resource_icons/meal.svg",
	"wine": "res://assets/ui/resource_icons/wine.svg",
	"wood": "res://assets/ui/resource_icons/wood.svg",
	"stone": "res://assets/ui/resource_icons/stone.svg",
	"iron": "res://assets/ui/resource_icons/iron.svg"
}
const RESOURCE_ICON_SIZE := Vector2(22.0, 22.0)
var _resource_labels: Dictionary = {}
var _resource_icons: Dictionary = {}
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_scroll: ScrollContainer
var _detail_grid: GridContainer
var _detail_item_snapshots: Array[Dictionary] = []
var _detail_source_button: Control
var _detail_mode := ""
var _detail_drag_controller
var _escape_warning_label: Label
var _game_over_panel: PanelContainer
var _game_over_title_label: Label
var _game_over_reason_label: Label
var _game_over_detail_label: Label
var _piety_ability_button
var _meteor_target_hint: Label
var _meteor_target_preview: MeshInstance3D
var _meteor_targeting_active := false
var _meteor_target_valid := false
var _meteor_target_position := Vector3.ZERO
var _meteor_target_invalid_reason := ""
var _meteor_target_invalid_message := ""
var _meteor_target_feedback_until_msec := 0
var _last_clock_refresh_key := ""
var _hud_frame_fit_pending := false
var _escape_alert_queue: Array[Dictionary] = []
var _npc_revived_alert_queue: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_resource_strip()
	_build_detail_panel()
	_build_wave_countdown_label()
	_build_piety_ability_button()
	_build_escape_warning_label()
	_build_game_over_panel()
	if speed_button != null:
		speed_button.focus_mode = Control.FOCUS_NONE
		speed_button.tooltip_text = SPEED_BUTTON_NORMAL_TOOLTIP
		speed_button.pressed.connect(_on_speed_button_pressed)
	if pause_button != null:
		pause_button.focus_mode = Control.FOCUS_NONE
		pause_button.pressed.connect(_on_pause_button_pressed)
	if escape_started_alert_dialog != null:
		escape_started_alert_dialog.confirmed.connect(_on_escape_alert_closed)
		escape_started_alert_dialog.close_requested.connect(_on_escape_alert_closed)
	if npc_revived_alert_dialog != null:
		npc_revived_alert_dialog.confirmed.connect(_on_npc_revived_alert_closed)
		npc_revived_alert_dialog.close_requested.connect(_on_npc_revived_alert_closed)
	var alarm_button := get_node_or_null("AlarmButton") as Button
	if alarm_button != null:
		alarm_button.focus_mode = Control.FOCUS_NONE
		alarm_button.pressed.connect(_on_alarm_button_pressed)
	var dismiss_rally_button := get_node_or_null("DismissRallyButton") as Button
	if dismiss_rally_button != null:
		dismiss_rally_button.focus_mode = Control.FOCUS_NONE
		dismiss_rally_button.pressed.connect(_on_dismiss_rally_button_pressed)
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
		if event_bus.has_signal("npc_escape_started"):
			event_bus.npc_escape_started.connect(_on_npc_escape_started)
		if event_bus.has_signal("npc_revived"):
			event_bus.npc_revived.connect(_on_npc_revived)
		if event_bus.has_signal("horse_state_changed"):
			event_bus.horse_state_changed.connect(_on_horse_state_changed)
		if event_bus.has_signal("horse_assignment_changed"):
			event_bus.horse_assignment_changed.connect(_on_horse_assignment_changed)
		if event_bus.has_signal("defense_device_state_changed"):
			event_bus.defense_device_state_changed.connect(_on_defense_device_state_changed)
		if event_bus.has_signal("piety_changed"):
			event_bus.piety_changed.connect(_on_piety_changed)
	_refresh_piety_ability()
	_refresh_escape_warning()
	_refresh_game_over_panel()
	_request_hud_frame_fit()


func _input(event: InputEvent) -> void:
	if _handle_meteor_targeting_input(event):
		get_viewport().set_input_as_handled()
		return
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
	_refresh_meteor_target_feedback()
	if _detail_panel != null and _detail_panel.visible and _detail_source_button != null and (_detail_drag_controller == null or not _detail_drag_controller.has_user_position()):
		_position_detail_panel_near(_detail_source_button)


func _on_time_changed(day: int, hour: int, minute: int, second: int) -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	var precise_seconds := (
		time_system != null
		and time_system.has_method("should_show_precise_display_seconds")
		and bool(time_system.should_show_precise_display_seconds())
	)
	var refresh_key := "%d:%d:%d:%d" % [day, hour, minute, second if precise_seconds else 0]
	if refresh_key == _last_clock_refresh_key:
		return
	_last_clock_refresh_key = refresh_key
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
	_refresh_open_inventory_detail("equipment")


func _on_npc_escape_started(_npc_id: String, escape_result: Dictionary) -> void:
	if not bool(escape_result.get("ok", false)) or not bool(escape_result.get("applied", false)):
		return
	_escape_alert_queue.append(escape_result.duplicate(true))
	_show_next_escape_alert()


func _show_next_escape_alert() -> void:
	if escape_started_alert_dialog == null or escape_started_alert_dialog.visible or _escape_alert_queue.is_empty():
		return
	var escape_result: Dictionary = _escape_alert_queue.pop_front()
	var npc_name := str(escape_result.get("npc_name", "该NPC"))
	escape_started_alert_dialog.dialog_text = "%s正在逃离驿站，请尽快挽留，否则该NPC将永远离开驿站！" % npc_name
	escape_started_alert_dialog.popup_centered()


func _on_escape_alert_closed() -> void:
	call_deferred("_show_next_escape_alert")


func _on_npc_revived(npc_id: String) -> void:
	if npc_id.is_empty():
		return
	_npc_revived_alert_queue.append(npc_id)
	_show_next_npc_revived_alert()


func _show_next_npc_revived_alert() -> void:
	if npc_revived_alert_dialog == null or npc_revived_alert_dialog.visible or _npc_revived_alert_queue.is_empty():
		return
	var npc_id: String = _npc_revived_alert_queue.pop_front()
	var npc_name: String = npc_id
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	if npc_system != null and npc_system.has_method("get_npc"):
		var profile: Dictionary = npc_system.get_npc(npc_id)
		npc_name = str(profile.get("name", npc_id))
	npc_revived_alert_dialog.dialog_text = "%s从昏迷中苏醒了。" % npc_name
	npc_revived_alert_dialog.popup_centered()


func _on_npc_revived_alert_closed() -> void:
	call_deferred("_show_next_npc_revived_alert")


func _on_horse_state_changed(_horse_id: String) -> void:
	_refresh_open_inventory_detail("equipment")


func _on_horse_assignment_changed(_horse_id: String, _npc_id: String) -> void:
	_refresh_open_inventory_detail("equipment")


func _on_defense_device_state_changed(_snapshot: Dictionary) -> void:
	_refresh_open_inventory_detail("devices")


func _refresh_open_inventory_detail(mode: String) -> void:
	if _detail_panel != null and _detail_panel.visible and _detail_mode == mode:
		_refresh_detail_panel()


func _on_piety_changed(
	_current_piety: float,
	_max_piety: float,
	_delta: float,
	_reason: String
) -> void:
	_refresh_piety_ability()


func _on_gameplay_pause_changed(_paused: bool) -> void:
	_refresh_time_buttons()


func _on_time_scale_changed(
	_player_scale: float,
	_effective_scale: float,
	_numeric_multiplier: float,
	_reason: String
) -> void:
	_last_clock_refresh_key = ""
	_refresh_time()
	_refresh_wave_countdown()
	_refresh_time_buttons()


func _on_game_over_changed(_result: String, _reason: String) -> void:
	_refresh_time_buttons()
	_refresh_game_over_panel()


func _on_speed_button_pressed() -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null or _is_external_time_constraint_active(time_system):
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


func _on_dismiss_rally_button_pressed() -> void:
	var combat_system := get_node_or_null("/root/Main/Systems/CombatSystem")
	if combat_system == null or not combat_system.has_method("dismiss_combat_rally"):
		return
	combat_system.dismiss_combat_rally("hud")


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
				label.text = "--"
		_request_hud_frame_fit()
		return

	if _resource_labels.is_empty():
		_build_resource_strip()

	for raw_resource_id in resource_system.get_resource_ids():
		var resource_id := str(raw_resource_id)
		var label := _resource_labels.get(resource_id, null) as Label
		if label == null:
			continue
		label.text = str(resource_system.get_resource(resource_id))
		var icon := _resource_icons.get(resource_id, null) as TextureRect
		_refresh_resource_capacity_tooltip(icon, resource_system, resource_id)

	if _detail_panel != null and _detail_panel.visible:
		_refresh_detail_panel()
	_request_hud_frame_fit()


func _refresh_backend_status() -> void:
	var llm_bridge := get_node_or_null("/root/Main/Systems/LLMBridge")
	if llm_bridge == null or not llm_bridge.has_method("get_last_backend_status"):
		backend_status_label.text = "后端：未检查"
		_request_hud_frame_fit()
		return
	var status: Dictionary = llm_bridge.get_last_backend_status()
	backend_status_label.text = str(status.get("status_text", "后端：未检查"))
	_request_hud_frame_fit()


func _refresh_time_buttons() -> void:
	if speed_button == null:
		return

	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null:
		speed_button.text = "速度 x1"
		speed_button.disabled = false
		speed_button.tooltip_text = SPEED_BUTTON_NORMAL_TOOLTIP
		if pause_button != null:
			pause_button.text = "暂停"
		return

	var constrained := _is_external_time_constraint_active(time_system)
	speed_button.disabled = constrained
	speed_button.text = "速度 %s" % (
		time_system.get_effective_speed_label()
		if constrained and time_system.has_method("get_effective_speed_label")
		else time_system.get_speed_label()
	)
	speed_button.tooltip_text = (
		_format_time_constraint_tooltip(time_system.get_time_scale_snapshot())
		if constrained and time_system.has_method("get_time_scale_snapshot")
		else SPEED_BUTTON_NORMAL_TOOLTIP
	)
	if pause_button != null:
		pause_button.text = time_system.get_pause_label()
	_request_hud_frame_fit()


func _toggle_pause() -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null:
		return

	time_system.toggle_paused()
	_refresh_time_buttons()


func _set_time_scale_from_shortcut(scale: float) -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system == null or _is_external_time_constraint_active(time_system):
		return
	time_system.set_time_scale(scale)
	_refresh_time_buttons()


func _is_external_time_constraint_active(time_system: Node) -> bool:
	if time_system == null or not time_system.has_method("get_time_scale_snapshot"):
		return false
	var snapshot: Dictionary = time_system.get_time_scale_snapshot()
	return (
		float(snapshot.get("effective_scale", 1.0)) + 0.0001
		< float(snapshot.get("player_scale", 1.0))
	)


func _format_time_constraint_tooltip(snapshot: Dictionary) -> String:
	var effective_scale := float(snapshot.get("effective_scale", 1.0))
	var reasons: Array[String] = []
	_append_effective_constraint_reasons(
		reasons,
		snapshot.get("slowdown_requests", {}),
		"scale",
		effective_scale
	)
	_append_effective_constraint_reasons(
		reasons,
		snapshot.get("time_scale_cap_requests", {}),
		"max_scale",
		effective_scale
	)
	if reasons.is_empty():
		reasons.append("系统限速")
	return "暂时降速：%s" % "、".join(reasons)


func _append_effective_constraint_reasons(
	reasons: Array[String],
	raw_requests: Variant,
	scale_key: String,
	effective_scale: float
) -> void:
	if not raw_requests is Dictionary:
		return
	for raw_request in (raw_requests as Dictionary).values():
		if not raw_request is Dictionary:
			continue
		var request := raw_request as Dictionary
		if float(request.get(scale_key, INF)) > effective_scale + 0.0001:
			continue
		var label := _format_time_constraint_reason(str(request.get("reason", "")))
		if not reasons.has(label):
			reasons.append(label)


func _format_time_constraint_reason(reason: String) -> String:
	if reason == "combat_enemy_presence":
		return "敌军在场"
	if reason == "npc_movement":
		return "人物移动中"
	if reason == "gm_manual":
		return "GM 减速"
	if reason.begins_with("llm_") or reason == "llm_wait":
		return "等待人物回应"
	return "系统限速"


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
		return "清晨"
	if hour >= 12 and hour < 18:
		return "白昼"
	if hour >= 18 and hour < 22:
		return "黄昏"
	return "夜间"


func _connect_llm_bridge() -> void:
	var llm_bridge := get_node_or_null("/root/Main/Systems/LLMBridge")
	if llm_bridge == null or not llm_bridge.has_signal("backend_status_changed"):
		return
	if not llm_bridge.backend_status_changed.is_connected(_on_backend_status_changed):
		llm_bridge.backend_status_changed.connect(_on_backend_status_changed)


func _on_backend_status_changed(status_text: String, _ok: bool) -> void:
	backend_status_label.text = status_text
	_request_hud_frame_fit()


func _build_resource_strip() -> void:
	if resource_strip == null:
		return

	for child in resource_strip.get_children():
		resource_strip.remove_child(child)
		child.free()
	_resource_labels.clear()
	_resource_icons.clear()

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
		var item := HBoxContainer.new()
		item.name = "%sResourceItem" % resource_id.to_pascal_case()
		item.layout_mode = 2
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 4)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.layout_mode = 2
		icon.custom_minimum_size = RESOURCE_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon_path := str(RESOURCE_ICON_PATHS.get(resource_id, ""))
		if not icon_path.is_empty():
			icon.texture = load(icon_path) as Texture2D
		item.add_child(icon)

		var label := Label.new()
		label.name = "%sResourceLabel" % resource_id.to_pascal_case()
		label.layout_mode = 2
		label.text = "--"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
		_refresh_resource_capacity_tooltip(icon, resource_system, resource_id)
		resource_strip.add_child(item)
		_resource_labels[resource_id] = label
		_resource_icons[resource_id] = icon

	var equipment_button := _make_detail_button("装备", "equipment")
	resource_strip.add_child(equipment_button)

	var devices_button := _make_detail_button("器械", "devices")
	resource_strip.add_child(devices_button)
	_request_hud_frame_fit()


func _request_hud_frame_fit() -> void:
	if _hud_frame_fit_pending or not is_inside_tree():
		return
	_hud_frame_fit_pending = true
	call_deferred("_fit_hud_frame_to_content")


func _fit_hud_frame_to_content() -> void:
	_hud_frame_fit_pending = false
	if hud_frame == null:
		return
	var content_end := _get_hud_frame_content_end()
	hud_frame.offset_right = content_end.x + HUD_FRAME_CONTENT_PADDING.x
	hud_frame.offset_bottom = content_end.y + HUD_FRAME_CONTENT_PADDING.y


func _get_hud_frame_content_end() -> Vector2:
	var content_end := Vector2.ZERO
	var content_controls: Array[Control] = []
	for path in [
		"TitleLabel",
		"DayLabel",
		"TimeLabel",
		"PhaseLabel",
		"ResourceStrip",
		"WaveCountdownLabel",
		"BackendStatusLabel",
		"SpeedButton",
		"PauseButton",
		"AlarmButton",
		"DismissRallyButton",
		"PietyAbilityButton"
	]:
		var control := get_node_or_null(path) as Control
		if control != null and control.visible:
			content_controls.append(control)
	var hud_origin := get_global_rect().position
	for control in content_controls:
		var local_position := control.get_global_rect().position - hud_origin
		var resolved_size := control.size.max(control.get_combined_minimum_size())
		content_end.x = maxf(content_end.x, local_position.x + resolved_size.x)
		content_end.y = maxf(content_end.y, local_position.y + resolved_size.y)
	return content_end


func debug_get_hud_frame_layout_snapshot() -> Dictionary:
	var frame_end := hud_frame.position + hud_frame.size if hud_frame != null else Vector2.ZERO
	var content_end := _get_hud_frame_content_end()
	return {
		"frame_position": hud_frame.position if hud_frame != null else Vector2.ZERO,
		"frame_size": hud_frame.size if hud_frame != null else Vector2.ZERO,
		"frame_end": frame_end,
		"content_end": content_end,
		"right_padding": frame_end.x - content_end.x,
		"bottom_padding": frame_end.y - content_end.y,
		"contains_content": (
			frame_end.x + 0.01 >= content_end.x
			and frame_end.y + 0.01 >= content_end.y
		)
	}


func _refresh_resource_capacity_tooltip(
	icon: Control,
	resource_system: Node,
	resource_id: String
) -> void:
	var resource_name := _resource_display_name(resource_id)
	if (
		icon == null
		or resource_system == null
		or not resource_system.has_method("get_resource_capacity")
	):
		if icon != null:
			icon.tooltip_text = resource_name
		return
	var capacity := int(resource_system.get_resource_capacity(resource_id))
	icon.tooltip_text = (
		"%s\n仓库储存上限：%d" % [resource_name, capacity]
		if capacity >= 0
		else resource_name
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
	wave_countdown_label.text = "下一波敌军时间未知"
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
	var dismiss_rally_button := get_node_or_null("DismissRallyButton") as Button
	if dismiss_rally_button != null:
		dismiss_rally_button.offset_top = 178.0
		dismiss_rally_button.offset_bottom = 210.0
	_request_hud_frame_fit()


func _build_piety_ability_button() -> void:
	if _piety_ability_button != null:
		return
	_piety_ability_button = PietyAbilityButtonClass.new()
	_piety_ability_button.name = "PietyAbilityButton"
	_piety_ability_button.position = Vector2(448.0, 172.0)
	_piety_ability_button.size = Vector2(48.0, 48.0)
	_piety_ability_button.ability_requested.connect(_begin_meteor_targeting)
	add_child(_piety_ability_button)

	_meteor_target_hint = Label.new()
	_meteor_target_hint.name = "MeteorTargetHint"
	_meteor_target_hint.visible = false
	_meteor_target_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meteor_target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meteor_target_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_meteor_target_hint.offset_left = 280.0
	_meteor_target_hint.offset_right = -280.0
	_meteor_target_hint.offset_top = 76.0
	_meteor_target_hint.offset_bottom = 108.0
	_meteor_target_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66, 1.0))
	_meteor_target_hint.add_theme_color_override("font_outline_color", Color(0.16, 0.04, 0.02, 1.0))
	_meteor_target_hint.add_theme_constant_override("outline_size", 5)
	_meteor_target_hint.text = "选择陨石落点：左键确认，右键或 Esc 取消"
	add_child(_meteor_target_hint)
	_request_hud_frame_fit()


func _refresh_piety_ability() -> void:
	if _piety_ability_button == null:
		return
	var piety_system := get_node_or_null("/root/Main/Systems/PietySystem")
	if piety_system == null or not piety_system.has_method("get_piety_snapshot"):
		_piety_ability_button.set_piety(0.0, 100.0)
		if _meteor_targeting_active:
			_end_meteor_targeting()
		return
	var snapshot: Dictionary = piety_system.get_piety_snapshot()
	_piety_ability_button.set_piety(
		float(snapshot.get("current_piety", 0.0)),
		float(snapshot.get("max_piety", 100.0))
	)
	if _meteor_targeting_active and not bool(snapshot.get("ready", false)):
		_end_meteor_targeting()


func _begin_meteor_targeting() -> void:
	var piety_system := get_node_or_null("/root/Main/Systems/PietySystem")
	if (
		piety_system == null
		or not piety_system.has_method("is_ready_to_cast")
		or not bool(piety_system.is_ready_to_cast())
	):
		_refresh_piety_ability()
		return
	_ensure_meteor_target_preview()
	_meteor_targeting_active = true
	_meteor_target_valid = false
	_meteor_target_invalid_reason = ""
	_meteor_target_invalid_message = ""
	_meteor_target_feedback_until_msec = 0
	if _piety_ability_button != null:
		_piety_ability_button.set_targeting(true)
	if _meteor_target_hint != null:
		_meteor_target_hint.visible = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	_update_meteor_target_from_screen(get_viewport().get_mouse_position())


func _handle_meteor_targeting_input(event: InputEvent) -> bool:
	if not _meteor_targeting_active:
		return false
	if event is InputEventMouseMotion:
		_update_meteor_target_from_screen((event as InputEventMouseMotion).position)
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_end_meteor_targeting()
		return true
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_end_meteor_targeting()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_meteor_target()
			return true
	return false


func _confirm_meteor_target() -> void:
	if not _meteor_targeting_active:
		return
	if not _meteor_target_valid:
		if _meteor_target_invalid_reason == "building_overlap":
			_show_meteor_target_feedback(
				_meteor_target_invalid_message
				if not _meteor_target_invalid_message.is_empty()
				else "赖天主仁慈，陨石不能砸到建筑"
			)
		return
	var piety_system := get_node_or_null("/root/Main/Systems/PietySystem")
	if piety_system == null or not piety_system.has_method("request_meteor_cast"):
		_end_meteor_targeting()
		return
	var result: Dictionary = piety_system.request_meteor_cast(_meteor_target_position)
	if bool(result.get("ok", false)):
		_end_meteor_targeting()
	else:
		_show_meteor_target_feedback(str(result.get("message", "陨石无法在此处释放。")))
		_refresh_piety_ability()


func _end_meteor_targeting() -> void:
	_meteor_targeting_active = false
	_meteor_target_valid = false
	_meteor_target_invalid_reason = ""
	_meteor_target_invalid_message = ""
	_meteor_target_feedback_until_msec = 0
	if _piety_ability_button != null:
		_piety_ability_button.set_targeting(false)
	if _meteor_target_hint != null:
		_meteor_target_hint.visible = false
	if _meteor_target_preview != null:
		_meteor_target_preview.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _update_meteor_target_from_screen(screen_position: Vector2) -> void:
	if not _meteor_targeting_active:
		return
	var camera := get_viewport().get_camera_3d()
	var piety_system := get_node_or_null("/root/Main/Systems/PietySystem")
	if camera == null or piety_system == null:
		_set_meteor_target_validation({"allowed": false, "reason": "no_ground"})
		return
	var targeting_snapshot: Dictionary = (
		piety_system.get_targeting_snapshot()
		if piety_system.has_method("get_targeting_snapshot")
		else {}
	)
	var ground_y := float(targeting_snapshot.get("ground_y", 0.0))
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.00001:
		_set_meteor_target_validation({"allowed": false, "reason": "no_ground"})
		return
	var distance := (ground_y - ray_origin.y) / ray_direction.y
	if distance <= 0.0:
		_set_meteor_target_validation({"allowed": false, "reason": "no_ground"})
		return
	var target_position := ray_origin + ray_direction * distance
	var validation: Dictionary = (
		piety_system.get_target_position_validation(target_position)
		if piety_system.has_method("get_target_position_validation")
		else {
			"allowed": bool(piety_system.is_target_position_allowed(target_position))
			if piety_system.has_method("is_target_position_allowed")
			else false
		}
	)
	_meteor_target_position = target_position
	_set_meteor_target_validation(validation)
	if _meteor_target_valid and _meteor_target_preview != null:
		_meteor_target_preview.global_position = target_position + Vector3(0.0, 0.055, 0.0)


func _set_meteor_target_validation(validation: Dictionary) -> void:
	_meteor_target_invalid_reason = str(validation.get("reason", ""))
	_meteor_target_invalid_message = str(validation.get("message", ""))
	_set_meteor_target_valid(bool(validation.get("allowed", false)))


func _set_meteor_target_valid(valid: bool) -> void:
	_meteor_target_valid = valid
	if _meteor_target_preview != null:
		_meteor_target_preview.visible = valid
	if _meteor_target_hint != null and _meteor_target_feedback_until_msec <= Time.get_ticks_msec():
		_meteor_target_hint.text = (
			"选择陨石落点：左键确认，右键或 Esc 取消"
			if valid
			else (
				"陨石范围与建筑区域重叠；左键查看提示，右键或 Esc 取消"
				if _meteor_target_invalid_reason == "building_overlap"
				else "当前没有可用地面落点；右键或 Esc 取消"
			)
		)


func _show_meteor_target_feedback(message: String) -> void:
	if _meteor_target_hint == null or message.is_empty():
		return
	_meteor_target_hint.visible = true
	_meteor_target_hint.text = message
	_meteor_target_feedback_until_msec = Time.get_ticks_msec() + 1600


func _refresh_meteor_target_feedback() -> void:
	if _meteor_target_feedback_until_msec <= 0 or Time.get_ticks_msec() < _meteor_target_feedback_until_msec:
		return
	_meteor_target_feedback_until_msec = 0
	if _meteor_targeting_active:
		_set_meteor_target_valid(_meteor_target_valid)


func _ensure_meteor_target_preview() -> void:
	if _meteor_target_preview != null:
		return
	var effects_root := get_node_or_null("/root/Main/WorldRoot/Station/Effects") as Node3D
	var piety_system := get_node_or_null("/root/Main/Systems/PietySystem")
	if effects_root == null or piety_system == null:
		return
	var targeting_snapshot: Dictionary = (
		piety_system.get_targeting_snapshot()
		if piety_system.has_method("get_targeting_snapshot")
		else {}
	)
	var radius := maxf(0.1, float(targeting_snapshot.get("radius", 5.0)))
	_meteor_target_preview = MeshInstance3D.new()
	_meteor_target_preview.name = "MeteorTargetPreview"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	mesh.radial_segments = 64
	_meteor_target_preview.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.42, 0.12, 0.25)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.22, 0.04, 1.0)
	material.emission_energy_multiplier = 1.35
	_meteor_target_preview.set_surface_override_material(0, material)
	_meteor_target_preview.visible = false
	effects_root.add_child(_meteor_target_preview)


func _refresh_wave_countdown() -> void:
	if wave_countdown_label == null:
		return
	var combat_system := get_node_or_null("/root/Main/Systems/CombatSystem")
	if combat_system == null or not combat_system.has_method("get_wave_hud_snapshot"):
		wave_countdown_label.text = "下一波敌军时间不可用"
		return
	var snapshot: Dictionary = combat_system.get_wave_hud_snapshot()
	var active_enemy_count := int(snapshot.get("active_enemy_count", 0))
	var prefix := ""
	if active_enemy_count > 0:
		var current_wave := int(snapshot.get("active_wave_number", 0))
		prefix = "当前第%d波 敌人%d | " % [current_wave, active_enemy_count] if current_wave > 0 else "当前敌人%d | " % active_enemy_count
	if bool(snapshot.get("all_waves_triggered", false)):
		wave_countdown_label.text = "%s敌军波次已结束" % prefix
		return
	var next_wave: Dictionary = snapshot.get("next_wave", {}) if snapshot.get("next_wave", {}) is Dictionary else {}
	if next_wave.is_empty():
		wave_countdown_label.text = "%s下一波敌军时间未知" % prefix
		return
	wave_countdown_label.text = "%s%s" % [
		prefix,
		_format_next_wave_arrival(float(next_wave.get("seconds_until", 0.0)))
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


func _format_next_wave_arrival(seconds_until: float) -> String:
	var countdown_text := _format_wave_countdown(seconds_until)
	if countdown_text == "即将来袭":
		return "下一波敌军即将来袭"
	return "下一波敌军还有 %s来袭" % countdown_text


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
	_detail_panel.custom_minimum_size = DETAIL_PANEL_MINIMUM_SIZE
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
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(30.0, 26.0)
	close_button.pressed.connect(func() -> void:
		_detail_panel.visible = false
		_detail_source_button = null
		_detail_mode = ""
	)
	header.add_child(close_button)
	_detail_drag_controller = DraggablePanelController.new()
	_detail_drag_controller.bind(_detail_panel, header)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "ResourceDetailScroll"
	_detail_scroll.custom_minimum_size = DETAIL_SCROLL_MINIMUM_SIZE
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(_detail_scroll)

	_detail_grid = GridContainer.new()
	_detail_grid.name = "ResourceDetailGrid"
	_detail_grid.columns = DETAIL_GRID_COLUMNS
	_detail_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_grid.add_theme_constant_override("h_separation", 8)
	_detail_grid.add_theme_constant_override("v_separation", 8)
	_detail_scroll.add_child(_detail_grid)


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
	if _detail_grid == null or _detail_title == null:
		return
	if _detail_mode == "equipment":
		_detail_title.text = "装备库存"
		_rebuild_detail_grid(_build_equipment_detail_items())
	elif _detail_mode == "devices":
		_detail_title.text = "器械库存"
		_rebuild_detail_grid(_build_device_detail_items())


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


func _rebuild_detail_grid(items: Array[Dictionary]) -> void:
	if _detail_grid == null:
		return
	var previous_scroll := _detail_scroll.scroll_vertical if _detail_scroll != null else 0
	for child in _detail_grid.get_children():
		_detail_grid.remove_child(child)
		child.free()
	_detail_item_snapshots = items.duplicate(true)
	for index in range(items.size()):
		var button := _make_detail_item_button(items[index], index)
		_detail_grid.add_child(button)
		_apply_detail_item_button_style(button)
	if _detail_scroll != null:
		_detail_scroll.set_deferred("scroll_vertical", previous_scroll)


func _make_detail_item_button(item: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "InventoryItem%03d" % index
	button.text = ""
	button.tooltip_text = str(item.get("tooltip", "未分配"))
	button.custom_minimum_size = DETAIL_ITEM_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", DETAIL_ITEM_ICON_MAX_WIDTH)
	var icon_path := str(item.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path) as Texture2D
	if bool(item.get("assigned", false)):
		button.self_modulate = ASSIGNED_ITEM_MODULATE
	button.set_meta("inventory_item", item.duplicate(true))
	return button


func _apply_detail_item_button_style(button: Button) -> void:
	# The shared button theme is text-oriented; its 11 px horizontal padding made
	# the square inventory art much smaller than the existing 68 px slot.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var source_style := button.get_theme_stylebox(state)
		if source_style == null:
			continue
		var compact_style := source_style.duplicate() as StyleBox
		compact_style.content_margin_left = DETAIL_ITEM_CONTENT_MARGIN
		compact_style.content_margin_top = DETAIL_ITEM_CONTENT_MARGIN
		compact_style.content_margin_right = DETAIL_ITEM_CONTENT_MARGIN
		compact_style.content_margin_bottom = DETAIL_ITEM_CONTENT_MARGIN
		if compact_style is StyleBoxFlat:
			(compact_style as StyleBoxFlat).set_border_width_all(DETAIL_ITEM_BORDER_WIDTH)
		button.add_theme_stylebox_override(state, compact_style)


func _build_equipment_detail_items() -> Array[Dictionary]:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	var equipment_system := get_node_or_null("/root/Main/Systems/EquipmentSystem")
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	var result: Array[Dictionary] = []
	var assigned_by_resource: Dictionary = {}
	if npc_system != null and npc_system.has_method("get_npc_ids"):
		for raw_npc_id in npc_system.get_npc_ids():
			var npc_id := str(raw_npc_id)
			var npc: Dictionary = npc_system.get_npc(npc_id)
			var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
			for slot in ["main_weapon", "helmet", "chest", "bracers", "greaves"]:
				var item: Dictionary = equipment.get(slot, {}) if equipment.get(slot, {}) is Dictionary else {}
				if item.is_empty():
					continue
				var resource_id := str(item.get("source_resource_id", ""))
				if resource_id.is_empty():
					resource_id = "item_%s" % str(item.get("id", ""))
				var assigned_items: Array = assigned_by_resource.get(resource_id, [])
				assigned_items.append(_make_inventory_item_snapshot(
					resource_id,
					str(item.get("icon", _resolve_equipment_resource_icon(equipment_system, resource_id))),
					true,
					str(item.get("name", _resource_display_name_from_system(resource_system, resource_id))),
					"已分配给%s" % _npc_display_name(npc_system, npc_id),
					"equipment",
					npc_id
				))
				assigned_by_resource[resource_id] = assigned_items

	if resource_system != null and resource_system.has_method("get_resource_ids"):
		for raw_resource_id in resource_system.get_resource_ids():
			var resource_id := str(raw_resource_id)
			var definition: Dictionary = resource_system.get_resource_definition(resource_id)
			var detail_group := str(definition.get("detail_group", ""))
			if not ["weapon", "armor"].has(detail_group):
				continue
			var icon_path := str(definition.get("icon", ""))
			if icon_path.is_empty():
				icon_path = _resolve_equipment_resource_icon(equipment_system, resource_id)
			_append_unassigned_inventory_items(
				result,
				resource_id,
				icon_path,
				int(resource_system.get_resource(resource_id)),
				detail_group,
				str(definition.get("name", _resource_display_name_from_system(resource_system, resource_id)))
			)
			for raw_assigned_item in assigned_by_resource.get(resource_id, []):
				if raw_assigned_item is Dictionary:
					result.append((raw_assigned_item as Dictionary).duplicate(true))
			assigned_by_resource.erase(resource_id)

	for raw_remaining_items in assigned_by_resource.values():
		if raw_remaining_items is Array:
			for raw_item in raw_remaining_items:
				if raw_item is Dictionary:
					result.append((raw_item as Dictionary).duplicate(true))

	var horse_system := get_node_or_null("/root/Main/Systems/HorseSystem")
	if horse_system != null and horse_system.has_method("get_horses_snapshot"):
		for raw_horse in horse_system.get_horses_snapshot():
			var horse: Dictionary = raw_horse if raw_horse is Dictionary else {}
			if horse.is_empty() or not bool(horse.get("alive", true)):
				continue
			var assigned_npc_id := str(horse.get("assigned_npc_id", horse.get("ridden_by_npc_id", "")))
			var assigned := not assigned_npc_id.is_empty()
			result.append(_make_inventory_item_snapshot(
				str(horse.get("horse_id", "")),
				str(horse.get("icon", "")),
				assigned,
				str(horse.get("name", "马匹")),
				"已分配给%s" % _npc_display_name(npc_system, assigned_npc_id) if assigned else "未分配",
				"horse",
				assigned_npc_id
			))
	return result


func _build_device_detail_items() -> Array[Dictionary]:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	var device_system := get_node_or_null("/root/Main/Systems/DefenseDeviceSystem")
	var result: Array[Dictionary] = []
	if device_system == null or not device_system.has_method("get_device_ids"):
		return result
	var deployments: Array = device_system.get_deployments() if device_system.has_method("get_deployments") else []
	for raw_device_id in device_system.get_device_ids():
		var device_id := str(raw_device_id)
		var definition: Dictionary = device_system.get_device_definition(device_id)
		var presentation: Dictionary = definition.get("presentation", {}) if definition.get("presentation", {}) is Dictionary else {}
		var icon_path := str(presentation.get("icon", ""))
		var inventory_cost: Dictionary = definition.get("inventory_cost", {}) if definition.get("inventory_cost", {}) is Dictionary else {}
		var resource_id := str(inventory_cost.keys()[0]) if not inventory_cost.is_empty() else ""
		var inventory_amount := (
			int(resource_system.get_resource(resource_id))
			if resource_system != null and not resource_id.is_empty() and resource_system.has_method("get_resource")
			else 0
		)
		_append_unassigned_inventory_items(
			result,
			resource_id,
			icon_path,
			inventory_amount,
			"defense_device",
			str(definition.get("name", _resource_display_name_from_system(resource_system, resource_id)))
		)
		for raw_deployment in deployments:
			var deployment: Dictionary = raw_deployment if raw_deployment is Dictionary else {}
			if str(deployment.get("device_id", "")) != device_id:
				continue
			result.append(_make_inventory_item_snapshot(
				str(deployment.get("deployment_id", "")),
				icon_path,
				true,
				str(definition.get("name", _resource_display_name_from_system(resource_system, resource_id))),
				"已部署到%s" % str(deployment.get("slot_name", deployment.get("slot_id", ""))),
				"defense_device",
				str(deployment.get("slot_id", ""))
			))
	return result


func _append_unassigned_inventory_items(
	target: Array[Dictionary],
	item_id: String,
	icon_path: String,
	amount: int,
	category: String,
	item_name: String
) -> void:
	for _index in range(maxi(0, amount)):
		target.append(_make_inventory_item_snapshot(
			item_id,
			icon_path,
			false,
			item_name,
			"未分配",
			category,
			""
		))


func _make_inventory_item_snapshot(
	item_id: String,
	icon_path: String,
	assigned: bool,
	item_name: String,
	status_text: String,
	category: String,
	assignment_target_id: String
) -> Dictionary:
	return {
		"item_id": item_id,
		"icon_path": icon_path,
		"assigned": assigned,
		"item_name": item_name,
		"tooltip": "%s %s" % [item_name, status_text],
		"category": category,
		"assignment_target_id": assignment_target_id
	}


func _resource_display_name_from_system(resource_system: Node, resource_id: String) -> String:
	if resource_system != null and resource_system.has_method("get_resource_name"):
		return str(resource_system.get_resource_name(resource_id))
	return resource_id


func _resolve_equipment_resource_icon(equipment_system: Node, resource_id: String) -> String:
	if equipment_system == null:
		return ""
	if equipment_system.has_method("get_weapon_ids") and equipment_system.has_method("get_weapon_def"):
		for raw_weapon_id in equipment_system.get_weapon_ids():
			var definition: Dictionary = equipment_system.get_weapon_def(str(raw_weapon_id))
			if str(definition.get("source_resource_id", "")) == resource_id:
				return str(definition.get("icon", ""))
	if equipment_system.has_method("get_armor_ids") and equipment_system.has_method("get_armor_def"):
		for raw_armor_id in equipment_system.get_armor_ids():
			var definition: Dictionary = equipment_system.get_armor_def(str(raw_armor_id))
			if str(definition.get("source_resource_id", "")) == resource_id:
				return str(definition.get("icon", ""))
	return ""


func _npc_display_name(npc_system: Node, npc_id: String) -> String:
	if npc_id.is_empty():
		return ""
	if npc_system != null and npc_system.has_method("get_npc"):
		var npc: Dictionary = npc_system.get_npc(npc_id)
		return str(npc.get("name", npc_id))
	return npc_id


func debug_get_resource_detail_snapshot() -> Dictionary:
	return {
		"visible": _detail_panel != null and _detail_panel.visible,
		"mode": _detail_mode,
		"panel_minimum_size": _detail_panel.custom_minimum_size if _detail_panel != null else Vector2.ZERO,
		"scroll_minimum_size": _detail_scroll.custom_minimum_size if _detail_scroll != null else Vector2.ZERO,
		"vertical_scroll_mode": _detail_scroll.vertical_scroll_mode if _detail_scroll != null else -1,
		"horizontal_scroll_mode": _detail_scroll.horizontal_scroll_mode if _detail_scroll != null else -1,
		"grid_columns": _detail_grid.columns if _detail_grid != null else 0,
		"item_count": _detail_item_snapshots.size(),
		"items": _detail_item_snapshots.duplicate(true)
	}


func _should_show_resource_in_main_hud(resource_system: Node, resource_id: String) -> bool:
	if resource_system == null or not resource_system.has_method("get_resource_definition"):
		return not ["weapons", "armor", "horse_readiness", "defense_devices"].has(resource_id)
	var definition: Dictionary = resource_system.get_resource_definition(resource_id)
	return bool(definition.get("show_in_main_hud", true))


func _resource_display_name(resource_id: String) -> String:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system != null and resource_system.has_method("get_resource_name"):
		var resource_name := str(resource_system.get_resource_name(resource_id)).strip_edges()
		if not resource_name.is_empty() and resource_name != resource_id:
			return resource_name
	return "未知资源"
