extends Control

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var phase_label: Label = %PhaseLabel
@onready var gold_label: Label = %GoldLabel
@onready var food_label: Label = %FoodLabel
@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var iron_label: Label = %IronLabel
@onready var backend_status_label: Label = %BackendStatusLabel
@onready var speed_button: Button = $SpeedButton
@onready var pause_button: Button = $PauseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		gold_label.text = "金钱 --"
		food_label.text = "粮食 --"
		wood_label.text = "木材 --"
		stone_label.text = "石料 --"
		iron_label.text = "铁 --"
		return

	gold_label.text = "金钱 %d" % resource_system.get_resource("money")
	food_label.text = "粮食 %d" % resource_system.get_resource("grain")
	wood_label.text = "木材 %d" % resource_system.get_resource("wood")
	stone_label.text = "石料 %d" % resource_system.get_resource("stone")
	iron_label.text = "铁 %d" % resource_system.get_resource("iron")


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
