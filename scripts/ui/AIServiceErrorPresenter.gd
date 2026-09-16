extends Control

const DISPLAY_SECONDS := 14.0

var _panel: PanelContainer
var _message_label: Label
var _timer: Timer
var _last_error: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("ai_service_error"):
		event_bus.ai_service_error.connect(_on_ai_service_error)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ErrorBanner"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-390.0, 16.0)
	_panel.size = Vector2(780.0, 0.0)
	_panel.custom_minimum_size = Vector2(780.0, 64.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.055, 0.045, 0.96)
	style.border_color = Color(0.9, 0.34, 0.22, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_message_label = Label.new()
	_message_label.name = "ErrorMessage"
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.78, 1.0))
	row.add_child(_message_label)
	var close_button := Button.new()
	close_button.name = "DismissButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38.0, 38.0)
	close_button.pressed.connect(dismiss)
	row.add_child(close_button)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(dismiss)
	add_child(_timer)


func _on_ai_service_error(error: Dictionary) -> void:
	_last_error = error.duplicate(true)
	var code := str(error.get("error_code", "ai_service_error"))
	var http_status := int(error.get("http_status", 0))
	var provider_http_status := int(error.get("provider_http_status", 0))
	var status_text := ""
	if http_status > 0:
		status_text += " / HTTP %d" % http_status
	if provider_http_status > 0 and provider_http_status != http_status:
		status_text += " / Provider HTTP %d" % provider_http_status
	var message := str(error.get("message", "AI 服务请求失败。"))
	if code == "provider_queue_timeout":
		message = "DeepSeek 模型排队超时，请稍后重试。"
	_message_label.text = "AI 服务错误 [%s]%s\n%s" % [code, status_text, message]
	_panel.visible = true
	_panel.move_to_front()
	_timer.start(DISPLAY_SECONDS)


func dismiss() -> void:
	if _timer != null:
		_timer.stop()
	if _panel != null:
		_panel.visible = false


func debug_get_snapshot() -> Dictionary:
	return {
		"visible": _panel != null and _panel.visible,
		"message": _message_label.text if _message_label != null else "",
		"last_error": _last_error.duplicate(true),
	}
