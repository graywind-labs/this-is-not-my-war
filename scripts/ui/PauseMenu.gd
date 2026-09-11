extends Control

const MAIN_MENU_SCENE := "res://scenes/frontend/MainMenu.tscn"
const SettingsPanelScene = preload("res://scenes/ui/SettingsPanel.tscn")
const SaveBrowserScene = preload("res://scenes/ui/SaveBrowserPanel.tscn")
const FrontendStyles = preload("res://scripts/ui/FrontendStyles.gd")
const MENU_SIZE := Vector2(460.0, 510.0)

var _paused_before_open := false
var _pause_applied_by_menu := false
var _settings_panel: Control
var _save_browser: Control
var _status_label: Label
var _return_menu_dialog: ConfirmationDialog
var _exit_desktop_dialog: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_settings_panel = SettingsPanelScene.instantiate()
	_settings_panel.name = "SettingsPanel"
	add_child(_settings_panel)
	_save_browser = SaveBrowserScene.instantiate()
	_save_browser.name = "SaveBrowserPanel"
	add_child(_save_browser)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if _return_menu_dialog.visible:
		_return_menu_dialog.hide()
	elif _exit_desktop_dialog.visible:
		_exit_desktop_dialog.hide()
	elif _settings_panel.visible:
		_settings_panel.close_panel(true)
	elif _save_browser.visible:
		_save_browser.close_panel()
	elif visible:
		close_menu()
	else:
		open_menu()
	get_viewport().set_input_as_handled()


func open_menu() -> void:
	if visible:
		return
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	_paused_before_open = bool(time_system.is_gameplay_paused()) if time_system != null and time_system.has_method("is_gameplay_paused") else false
	_pause_applied_by_menu = not _paused_before_open
	if _pause_applied_by_menu and time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(true)
	_status_label.text = "按 Esc 返回游戏"
	visible = true
	move_to_front()
	var quick_button := find_child("QuickSaveButton", true, false) as Button
	if quick_button != null:
		quick_button.grab_focus()


func close_menu() -> void:
	if not visible:
		return
	if _settings_panel.visible:
		_settings_panel.close_panel(true)
	if _save_browser.visible:
		_save_browser.close_panel()
	visible = false
	_restore_pause_state()


func is_open() -> bool:
	return visible


func debug_get_snapshot() -> Dictionary:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return {
		"visible": visible,
		"paused_before_open": _paused_before_open,
		"pause_applied_by_menu": _pause_applied_by_menu,
		"gameplay_paused": bool(time_system.is_gameplay_paused()) if time_system != null and time_system.has_method("is_gameplay_paused") else false,
		"button_order": ["快速保存", "保存游戏", "加载游戏", "设置", "退出到主菜单", "退出到桌面"],
		"settings_visible": _settings_panel != null and _settings_panel.visible,
		"save_browser_visible": _save_browser != null and _save_browser.visible,
		"save_browser": _save_browser.debug_get_snapshot() if _save_browser != null else {},
		"status": _status_label.text if _status_label != null else "",
	}


func debug_open_save() -> void:
	_on_save_pressed()


func debug_open_load() -> void:
	_on_load_pressed()


func debug_open_settings() -> void:
	_on_settings_pressed()


func debug_quick_save() -> void:
	_on_quick_save_pressed()


func _build_menu() -> void:
	var dim := ColorRect.new()
	dim.name = "PauseDimmer"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.18, 0.19, 0.20, 0.63)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "PauseWindow"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -MENU_SIZE * 0.5
	panel.size = MENU_SIZE
	panel.custom_minimum_size = MENU_SIZE
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "游戏暂停"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 27)
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(42.0, 36.0)
	FrontendStyles.apply_button_focus(close_button)
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)

	var divider := HSeparator.new()
	content.add_child(divider)
	var quick_button := _make_button("QuickSaveButton", "快速保存")
	quick_button.pressed.connect(_on_quick_save_pressed)
	content.add_child(quick_button)
	var save_button := _make_button("SaveGameButton", "保存游戏")
	save_button.pressed.connect(_on_save_pressed)
	content.add_child(save_button)
	var load_button := _make_button("LoadGameButton", "加载游戏")
	load_button.pressed.connect(_on_load_pressed)
	content.add_child(load_button)
	var settings_button := _make_button("SettingsButton", "设置")
	settings_button.pressed.connect(_on_settings_pressed)
	content.add_child(settings_button)
	var danger_divider := HSeparator.new()
	content.add_child(danger_divider)
	var return_button := _make_button("ReturnToMenuButton", "退出到主菜单")
	FrontendStyles.apply_danger_button(return_button)
	return_button.pressed.connect(_on_return_to_menu_pressed)
	content.add_child(return_button)
	var desktop_button := _make_button("ExitDesktopButton", "退出到桌面")
	FrontendStyles.apply_danger_button(desktop_button)
	desktop_button.pressed.connect(_on_exit_desktop_pressed)
	content.add_child(desktop_button)

	_status_label = Label.new()
	_status_label.name = "PauseStatus"
	_status_label.custom_minimum_size = Vector2(0.0, 28.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color(0.72, 0.68, 0.58, 1.0)
	content.add_child(_status_label)

	_return_menu_dialog = _make_confirmation(
		"退出到主菜单",
		"退出到主菜单后，未保存的游戏进度将会丢失。是否继续？",
		"退出到主菜单"
	)
	_return_menu_dialog.confirmed.connect(_confirm_return_to_menu)
	add_child(_return_menu_dialog)
	_exit_desktop_dialog = _make_confirmation(
		"退出到桌面",
		"退出游戏后，未保存的游戏进度将会丢失。是否继续？",
		"退出游戏"
	)
	_exit_desktop_dialog.confirmed.connect(func() -> void: get_tree().quit())
	add_child(_exit_desktop_dialog)


func _make_button(node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(380.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	FrontendStyles.apply_button_focus(button)
	return button


func _make_confirmation(title_text: String, message: String, ok_text: String) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title_text
	dialog.dialog_text = message
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = "取消"
	dialog.unresizable = true
	FrontendStyles.apply_danger_button(dialog.get_ok_button())
	return dialog


func _restore_pause_state() -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	var game_state := get_node_or_null("/root/GameState")
	var game_over := bool(game_state.get("game_over")) if game_state != null else false
	if _pause_applied_by_menu and not game_over and time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)
	_pause_applied_by_menu = false


func _on_quick_save_pressed() -> void:
	_status_label.modulate = FrontendStyles.make_status_color(true)
	_status_label.text = "快速存档将在 T0355 接入；本次没有写入任何文件。"


func _on_save_pressed() -> void:
	_save_browser.open_panel(1, false)


func _on_load_pressed() -> void:
	_save_browser.open_panel(0, true)


func _on_settings_pressed() -> void:
	_settings_panel.open_panel(0)


func _on_return_to_menu_pressed() -> void:
	_return_menu_dialog.popup_centered(Vector2i(590, 190))


func _on_exit_desktop_pressed() -> void:
	_exit_desktop_dialog.popup_centered(Vector2i(590, 190))


func _confirm_return_to_menu() -> void:
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
