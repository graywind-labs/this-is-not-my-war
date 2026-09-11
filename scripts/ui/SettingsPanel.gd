extends Control

signal closed

const AudioSettingsPanelClass = preload("res://scripts/ui/AudioSettingsPanel.gd")
const FrontendStyles = preload("res://scripts/ui/FrontendStyles.gd")
const PANEL_SIZE := Vector2(840.0, 590.0)
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _audio_page: Control
var _display_mode: OptionButton
var _resolution: OptionButton
var _vsync: CheckButton
var _max_fps: OptionButton
var _ui_scale: HSlider
var _ui_scale_value: Label
var _blood_enabled: CheckButton
var _ai_mode: OptionButton
var _ai_provider: OptionButton
var _ai_model: LineEdit
var _ai_base_url: LineEdit
var _ai_key: LineEdit
var _ai_custom_fields: VBoxContainer
var _status_label: Label
var _selected_tab := 0
var _opening_audio_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_panel()
	_select_tab(0)


func open_panel(tab_index := 0) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	_opening_audio_snapshot = audio_manager.get_volume_snapshot() if audio_manager != null else {}
	_sync_controls()
	_status_label.text = ""
	visible = true
	move_to_front()
	_select_tab(clampi(tab_index, 0, _pages.size() - 1))
	if not _tab_buttons.is_empty():
		_tab_buttons[_selected_tab].grab_focus()


func close_panel(cancel_changes := true) -> void:
	if not visible:
		return
	if cancel_changes:
		_restore_opening_values()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func debug_select_tab(index: int) -> void:
	_select_tab(index)


func debug_press_apply() -> void:
	_apply_changes()


func debug_get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"selected_tab": _selected_tab,
		"tab_names": _tab_buttons.map(func(button: Button) -> String: return button.text),
		"page_visibility": _pages.map(func(page: Control) -> bool: return page.visible),
		"audio": _audio_page.debug_get_snapshot() if _audio_page != null else {},
		"display_mode": _display_mode.get_item_metadata(_display_mode.selected) if _display_mode != null else "",
		"resolution": _resolution.get_item_metadata(_resolution.selected) if _resolution != null else Vector2i.ZERO,
		"vsync": _vsync.button_pressed if _vsync != null else false,
		"max_fps": _max_fps.get_item_metadata(_max_fps.selected) if _max_fps != null else -1,
		"ui_scale": _ui_scale.value if _ui_scale != null else -1.0,
		"blood_enabled": _blood_enabled.button_pressed if _blood_enabled != null else true,
		"ai_mode": _ai_mode.get_item_metadata(_ai_mode.selected) if _ai_mode != null else "",
		"api_key_text_length": _ai_key.text.length() if _ai_key != null else -1,
		"api_key_secret": _ai_key.secret if _ai_key != null else false,
		"status": _status_label.text if _status_label != null else ""
	}


func _build_panel() -> void:
	var dim := ColorRect.new()
	dim.name = "Dimmer"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = FrontendStyles.make_overlay_color()
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "SettingsWindow"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -PANEL_SIZE * 0.5
	panel.size = PANEL_SIZE
	panel.custom_minimum_size = PANEL_SIZE
	add_child(panel)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 22)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_right", 22)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(outer_margin)

	var root_content := VBoxContainer.new()
	root_content.add_theme_constant_override("separation", 12)
	outer_margin.add_child(root_content)

	var header := HBoxContainer.new()
	root_content.add_child(header)
	var title := Label.new()
	title.text = "设置"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(42.0, 36.0)
	close_button.pressed.connect(close_panel.bind(true))
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.name = "TabButtons"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	root_content.add_child(tabs)
	for tab_name in ["音量", "画面", "AI"]:
		var button := Button.new()
		button.name = "%sTab" % tab_name
		button.text = tab_name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		var index := _tab_buttons.size()
		button.pressed.connect(_select_tab.bind(index))
		tabs.add_child(button)
		_tab_buttons.append(button)

	var page_frame := PanelContainer.new()
	page_frame.name = "PageFrame"
	page_frame.custom_minimum_size = Vector2(0.0, 420.0)
	page_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_content.add_child(page_frame)

	var page_stack := Control.new()
	page_stack.name = "PageStack"
	page_stack.custom_minimum_size = Vector2(0.0, 410.0)
	page_frame.add_child(page_stack)
	_audio_page = AudioSettingsPanelClass.new()
	_audio_page.name = "AudioSettingsPage"
	page_stack.add_child(_audio_page)
	_pages.append(_audio_page)
	var graphics_page := _build_graphics_page()
	page_stack.add_child(graphics_page)
	_pages.append(graphics_page)
	var ai_page := _build_ai_page()
	page_stack.add_child(ai_page)
	_pages.append(ai_page)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root_content.add_child(footer)
	var reset_button := Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "恢复默认"
	reset_button.pressed.connect(_reset_controls)
	footer.add_child(reset_button)
	_status_label = Label.new()
	_status_label.name = "SettingsStatus"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_status_label)
	var cancel_button := Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "取消"
	cancel_button.pressed.connect(close_panel.bind(true))
	footer.add_child(cancel_button)
	var apply_button := Button.new()
	apply_button.name = "ApplyButton"
	apply_button.text = "应用"
	apply_button.pressed.connect(_apply_changes)
	footer.add_child(apply_button)


func _build_graphics_page() -> Control:
	var page := MarginContainer.new()
	page.name = "GraphicsPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 28)
	page.add_theme_constant_override("margin_top", 22)
	page.add_theme_constant_override("margin_right", 28)
	page.add_theme_constant_override("margin_bottom", 18)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	page.add_child(content)
	var heading := Label.new()
	heading.text = "画面与显示"
	heading.add_theme_font_size_override("font_size", 21)
	content.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)

	_display_mode = OptionButton.new()
	_add_option(_display_mode, "窗口", "windowed")
	_add_option(_display_mode, "无边框窗口", "borderless")
	_add_option(_display_mode, "全屏", "fullscreen")
	_add_setting_row(grid, "显示模式", _display_mode)

	_resolution = OptionButton.new()
	for value in RESOLUTIONS:
		_add_option(_resolution, "%d × %d" % [value.x, value.y], value)
	_add_setting_row(grid, "分辨率", _resolution)

	_vsync = CheckButton.new()
	_vsync.text = "启用垂直同步"
	_add_setting_row(grid, "垂直同步", _vsync)

	_max_fps = OptionButton.new()
	for value in [0, 30, 60, 120, 144]:
		_add_option(_max_fps, "不限制" if value == 0 else "%d FPS" % value, value)
	_add_setting_row(grid, "最大帧率", _max_fps)

	var scale_row := HBoxContainer.new()
	_ui_scale = HSlider.new()
	_ui_scale.min_value = 0.8
	_ui_scale.max_value = 1.4
	_ui_scale.step = 0.05
	_ui_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_scale.value_changed.connect(_on_ui_scale_changed)
	scale_row.add_child(_ui_scale)
	_ui_scale_value = Label.new()
	_ui_scale_value.custom_minimum_size = Vector2(58.0, 0.0)
	_ui_scale_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scale_row.add_child(_ui_scale_value)
	_add_setting_row(grid, "界面缩放", scale_row)

	_blood_enabled = CheckButton.new()
	_blood_enabled.text = "显示血迹与血液粒子"
	_add_setting_row(grid, "战斗血迹", _blood_enabled)

	var hint := Label.new()
	hint.text = "战斗特效受同屏预算保护；关闭血迹不会影响伤害与战斗结算。"
	hint.modulate = Color(0.76, 0.72, 0.62, 1.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	return page


func _build_ai_page() -> Control:
	var page := MarginContainer.new()
	page.name = "AIPage"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 28)
	page.add_theme_constant_override("margin_top", 18)
	page.add_theme_constant_override("margin_right", 28)
	page.add_theme_constant_override("margin_bottom", 14)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	page.add_child(content)
	var heading := Label.new()
	heading.text = "AI 服务"
	heading.add_theme_font_size_override("font_size", 21)
	content.add_child(heading)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 14)
	content.add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = "服务模式"
	mode_label.custom_minimum_size = Vector2(120.0, 0.0)
	mode_row.add_child(mode_label)
	_ai_mode = OptionButton.new()
	_ai_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_option(_ai_mode, "试玩默认 API", "trial")
	_add_option(_ai_mode, "自定义 API", "custom")
	_ai_mode.item_selected.connect(_on_ai_mode_changed)
	mode_row.add_child(_ai_mode)

	_ai_custom_fields = VBoxContainer.new()
	_ai_custom_fields.add_theme_constant_override("separation", 9)
	content.add_child(_ai_custom_fields)
	_ai_provider = OptionButton.new()
	_add_option(_ai_provider, "OpenAI 兼容服务", "openai_compatible")
	_add_option(_ai_provider, "DeepSeek", "deepseek")
	_add_option(_ai_provider, "其他自建后端", "custom_backend")
	_add_labeled_control(_ai_custom_fields, "Provider", _ai_provider)
	_ai_model = LineEdit.new()
	_ai_model.placeholder_text = "例如：deepseek-v4-flash"
	_add_labeled_control(_ai_custom_fields, "模型", _ai_model)
	_ai_base_url = LineEdit.new()
	_ai_base_url.placeholder_text = "https://..."
	_add_labeled_control(_ai_custom_fields, "API Base URL", _ai_base_url)
	var key_row := HBoxContainer.new()
	_ai_key = LineEdit.new()
	_ai_key.name = "ApiKeyInput"
	_ai_key.secret = true
	_ai_key.placeholder_text = "API Key（本版本不会保存或提交）"
	_ai_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(_ai_key)
	var reveal := CheckButton.new()
	reveal.text = "显示"
	reveal.toggled.connect(func(enabled: bool) -> void: _ai_key.secret = not enabled)
	key_row.add_child(reveal)
	_add_labeled_control(_ai_custom_fields, "API Key", key_row)

	var test_button := Button.new()
	test_button.name = "TestAiConnectionButton"
	test_button.text = "测试连接"
	test_button.pressed.connect(_show_ai_connection_placeholder)
	content.add_child(test_button)
	var security_hint := Label.new()
	security_hint.text = "安全提示：API Key 不进入存档、普通配置或日志。凭据传递与试玩服务将在后续机制任务接入。"
	security_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	security_hint.modulate = Color(0.85, 0.67, 0.42, 1.0)
	content.add_child(security_hint)
	return page


func _add_setting_row(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(label)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 360.0)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _add_labeled_control(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _add_option(option: OptionButton, text_value: String, metadata: Variant) -> void:
	option.add_item(text_value)
	option.set_item_metadata(option.item_count - 1, metadata)


func _select_tab(index: int) -> void:
	if _pages.is_empty():
		return
	_selected_tab = clampi(index, 0, _pages.size() - 1)
	for page_index in range(_pages.size()):
		_pages[page_index].visible = page_index == _selected_tab
	for button_index in range(_tab_buttons.size()):
		_tab_buttons[button_index].button_pressed = button_index == _selected_tab


func _sync_controls() -> void:
	if _audio_page != null:
		_audio_page.sync_from_manager()
	var client_settings := get_node_or_null("/root/ClientSettings")
	var snapshot: Dictionary = client_settings.get_snapshot() if client_settings != null else {}
	_select_option_by_metadata(_display_mode, str(snapshot.get("display_mode", "windowed")))
	_select_option_by_metadata(_resolution, snapshot.get("resolution", Vector2i(1280, 720)))
	_vsync.button_pressed = bool(snapshot.get("vsync", true))
	_select_option_by_metadata(_max_fps, int(snapshot.get("max_fps", 60)))
	_ui_scale.value = float(snapshot.get("ui_scale", 1.0))
	_blood_enabled.button_pressed = bool(snapshot.get("blood_enabled", true))
	_select_option_by_metadata(_ai_mode, str(snapshot.get("ai_mode", "trial")))
	_select_option_by_metadata(_ai_provider, str(snapshot.get("ai_provider", "openai_compatible")))
	_ai_model.text = str(snapshot.get("ai_model", ""))
	_ai_base_url.text = str(snapshot.get("ai_base_url", ""))
	_ai_key.clear()
	_on_ai_mode_changed(_ai_mode.selected)
	_on_ui_scale_changed(_ui_scale.value)


func _select_option_by_metadata(option: OptionButton, value: Variant) -> void:
	for index in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			return
	option.select(0)


func _on_ui_scale_changed(value: float) -> void:
	if _ui_scale_value != null:
		_ui_scale_value.text = "%d%%" % roundi(value * 100.0)


func _on_ai_mode_changed(_index: int) -> void:
	if _ai_custom_fields == null:
		return
	var custom: bool = str(_ai_mode.get_item_metadata(_ai_mode.selected)) == "custom"
	for child in _ai_custom_fields.get_children():
		if child is Control:
			(child as Control).modulate = Color.WHITE if custom else Color(0.55, 0.53, 0.48, 1.0)
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS if custom else Control.MOUSE_FILTER_IGNORE


func _collect_client_draft() -> Dictionary:
	return {
		"display_mode": _display_mode.get_item_metadata(_display_mode.selected),
		"resolution": _resolution.get_item_metadata(_resolution.selected),
		"vsync": _vsync.button_pressed,
		"max_fps": _max_fps.get_item_metadata(_max_fps.selected),
		"ui_scale": _ui_scale.value,
		"blood_enabled": _blood_enabled.button_pressed,
		"ai_mode": _ai_mode.get_item_metadata(_ai_mode.selected),
		"ai_provider": _ai_provider.get_item_metadata(_ai_provider.selected),
		"ai_model": _ai_model.text,
		"ai_base_url": _ai_base_url.text,
	}


func _apply_changes() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.save_settings()
		_opening_audio_snapshot = audio_manager.get_volume_snapshot()
	var client_settings := get_node_or_null("/root/ClientSettings")
	var result: Dictionary = client_settings.apply_settings(_collect_client_draft(), true) if client_settings != null else {"ok": false}
	var key_pending := not _ai_key.text.is_empty()
	_status_label.modulate = FrontendStyles.make_status_color(key_pending or not bool(result.get("ok", false)))
	_status_label.text = (
		"设置已应用；API Key 未保存，凭据机制尚未接入。"
		if key_pending
		else ("设置已应用。" if bool(result.get("ok", false)) else "设置无法写入本地配置。")
	)


func _reset_controls() -> void:
	var audio_defaults := {
		"master": 0.8,
		"music": 0.28,
		"click": 0.8,
		"voice": 0.8,
		"combat": 0.8,
		"work": 0.8,
		"ambience": 0.8,
	}
	_audio_page.set_audio_values(audio_defaults, false)
	var client_settings := get_node_or_null("/root/ClientSettings")
	var defaults: Dictionary = client_settings.get_default_snapshot() if client_settings != null else {}
	_select_option_by_metadata(_display_mode, defaults.get("display_mode", "windowed"))
	_select_option_by_metadata(_resolution, defaults.get("resolution", Vector2i(1280, 720)))
	_vsync.button_pressed = bool(defaults.get("vsync", true))
	_select_option_by_metadata(_max_fps, int(defaults.get("max_fps", 60)))
	_ui_scale.value = float(defaults.get("ui_scale", 1.0))
	_blood_enabled.button_pressed = bool(defaults.get("blood_enabled", true))
	_select_option_by_metadata(_ai_mode, str(defaults.get("ai_mode", "trial")))
	_select_option_by_metadata(_ai_provider, str(defaults.get("ai_provider", "openai_compatible")))
	_ai_model.text = ""
	_ai_base_url.text = ""
	_ai_key.clear()
	_on_ai_mode_changed(_ai_mode.selected)
	_status_label.modulate = FrontendStyles.make_status_color(false)
	_status_label.text = "已恢复默认预览；点击“应用”后保存。"


func _restore_opening_values() -> void:
	if not _opening_audio_snapshot.is_empty() and _audio_page != null:
		_audio_page.set_audio_values(_opening_audio_snapshot, true)


func _show_ai_connection_placeholder() -> void:
	_status_label.modulate = FrontendStyles.make_status_color(true)
	_status_label.text = "AI 连接与安全凭据机制尚未接入；本次没有发送请求或保存 Key。"
