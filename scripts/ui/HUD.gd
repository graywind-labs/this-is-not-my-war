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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_time()
	_refresh_resources()
	_refresh_backend_status()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.hour_started.connect(_on_hour_started)
		event_bus.resource_changed.connect(_on_resource_changed)


func _on_hour_started(_day: int, _hour: int) -> void:
	_refresh_time()


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	_refresh_resources()


func _refresh_time() -> void:
	var game_state := get_node_or_null("/root/GameState")
	var day := 1
	var hour := 6
	if game_state != null:
		day = game_state.current_day
		hour = game_state.current_hour

	day_label.text = "第 %d 天" % day
	time_label.text = "%02d:00" % hour
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
	backend_status_label.text = "后端：未连接（占位）"


func _get_phase_label(hour: int) -> String:
	if hour >= 5 and hour < 12:
		return "阶段：清晨"
	if hour >= 12 and hour < 18:
		return "阶段：白昼"
	if hour >= 18 and hour < 22:
		return "阶段：黄昏"
	return "阶段：夜间"
