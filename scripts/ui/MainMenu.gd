extends Control

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const MAIN_LAUNCH_REQUEST_META := &"main_launch_request"
const NEW_GAME_TUTORIAL_MODE := 2
const SettingsPanelScene = preload("res://scenes/ui/SettingsPanel.tscn")
const SaveBrowserScene = preload("res://scenes/ui/SaveBrowserPanel.tscn")
const MenuHeroBackdropClass = preload("res://scripts/ui/MenuHeroBackdrop.gd")
const MenuEdgeFogClass = preload("res://scripts/ui/MenuEdgeFog.gd")
const MenuCoverScene = preload("res://scenes/art/MenuCoverCandidate.tscn")
const FrontendStyles = preload("res://scripts/ui/FrontendStyles.gd")
const GameSaveStore = preload("res://scripts/systems/GameSaveStore.gd")
const MENU_PANEL_HEIGHT := 320.0
const MENU_PANEL_BOTTOM_ANCHOR := 0.88
const MENU_COVER_RENDER_SIZE := Vector2i(1920, 1080)
const UI_BUTTON_ASSET_ID := "sfx_ui_button_primary"
const UI_TOGGLE_ASSET_ID := "sfx_ui_toggle"
const AUDIO_HISTORY_LIMIT := 32
const LOADING_DOT_INTERVAL_MSEC := 280

var _settings_panel: Control
var _save_browser: Control
var _exit_dialog: ConfirmationDialog
var _start_button: Button
var _continue_button: Button
var _cover_viewport: SubViewport
var _cover_scene: Node3D
var _loading_overlay: ColorRect
var _loading_status_label: Label
var _loading_dots_label: Label
var _launching_game := false
var _loading_started_msec := 0
var _audio_connected_button_ids: Dictionary = {}
var _audio_click_history: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	var node_added_callback := Callable(self, "_on_tree_node_added")
	if tree != null and not tree.node_added.is_connected(node_added_callback):
		tree.node_added.connect(node_added_callback)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_settings_panel = SettingsPanelScene.instantiate()
	_settings_panel.name = "SettingsPanel"
	add_child(_settings_panel)
	_save_browser = SaveBrowserScene.instantiate()
	_save_browser.name = "SaveBrowserPanel"
	add_child(_save_browser)
	_connect_ui_audio_for_subtree(self)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("switch_music"):
		audio_manager.switch_music("music_menu", 1.2)
	(_continue_button if _continue_button.visible else _start_button).grab_focus()
	set_process(true)


func _process(_delta: float) -> void:
	if _loading_overlay == null or not _loading_overlay.visible or _loading_dots_label == null:
		return
	var elapsed_msec := maxi(0, Time.get_ticks_msec() - _loading_started_msec)
	var phase := int(elapsed_msec / LOADING_DOT_INTERVAL_MSEC) % 3
	_loading_dots_label.text = ["●　○　○", "○　●　○", "○　○　●"][phase]


func _exit_tree() -> void:
	var tree := get_tree()
	var node_added_callback := Callable(self, "_on_tree_node_added")
	if tree != null and tree.node_added.is_connected(node_added_callback):
		tree.node_added.disconnect(node_added_callback)
	_audio_connected_button_ids.clear()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if _exit_dialog != null and _exit_dialog.visible:
		_exit_dialog.hide()
	elif _settings_panel != null and _settings_panel.visible:
		_settings_panel.close_panel(true)
	elif _save_browser != null and _save_browser.visible:
		_save_browser.close_panel()
	else:
		return
	get_viewport().set_input_as_handled()


func debug_get_snapshot() -> Dictionary:
	return {
		"scene": scene_file_path,
		"has_main_instance": get_tree().root.get_node_or_null("Main") != null,
		"button_order": ["继续游戏", "开始游戏", "载入游戏", "设置", "退出游戏"],
		"settings_visible": _settings_panel != null and _settings_panel.visible,
		"save_browser_visible": _save_browser != null and _save_browser.visible,
		"exit_confirmation_visible": _exit_dialog != null and _exit_dialog.visible,
		"menu_music": str(get_node_or_null("/root/AudioManager").get_current_music_asset_id()) if get_node_or_null("/root/AudioManager") != null else "",
		"hero_animated": find_child("MenuHeroBackdrop", true, false) != null,
		"animated_cover_connected": _cover_scene != null and is_instance_valid(_cover_scene),
		"cover_render_size": _cover_viewport.size if _cover_viewport != null else Vector2i.ZERO,
		"edge_fog_connected": find_child("MenuEdgeFog", true, false) != null,
		"launching_game": _launching_game,
		"loading_visible": _loading_overlay != null and _loading_overlay.visible,
		"loading_message": _loading_status_label.text if _loading_status_label != null else "",
		"loading_mouse_filter": _loading_overlay.mouse_filter if _loading_overlay != null else Control.MOUSE_FILTER_IGNORE,
		"loading_z_index": _loading_overlay.z_index if _loading_overlay != null else 0,
		"audio_connected_button_count": _audio_connected_button_ids.size(),
		"audio_click_history": _audio_click_history.duplicate(true),
	}


func debug_open_settings() -> void:
	_on_settings_pressed()


func debug_open_load_browser() -> void:
	_on_load_pressed()


func debug_open_exit_confirmation() -> void:
	_on_exit_pressed()


func debug_publish_new_game_launch_request() -> void:
	_publish_new_game_launch_request()


func debug_show_start_loading_state() -> void:
	_show_start_loading_state()


func _build_menu() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.035, 0.031, 0.027, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var hero_frame := Control.new()
	hero_frame.name = "HeroFrame"
	hero_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero_frame)
	var hero := MenuHeroBackdropClass.new()
	hero.name = "MenuHeroBackdrop"
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_frame.add_child(hero)
	_attach_animated_cover(hero_frame, hero)

	var edge_fog := MenuEdgeFogClass.new()
	edge_fog.name = "MenuEdgeFog"
	add_child(edge_fog)

	var title_block := VBoxContainer.new()
	title_block.name = "TitleBlock"
	title_block.anchor_left = 0.055
	title_block.anchor_top = 0.045
	title_block.anchor_right = 0.70
	title_block.anchor_bottom = 0.045
	title_block.offset_bottom = 90.0
	title_block.add_theme_constant_override("separation", 0)
	add_child(title_block)
	var title := Label.new()
	title.name = "GameTitle"
	title.text = "这不是我的战争"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.60, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title_block.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "THIS IS NOT MY WAR · 边境驿站守备日志"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.modulate = Color(0.73, 0.66, 0.54, 1.0)
	title_block.add_child(subtitle)

	var menu_panel := PanelContainer.new()
	menu_panel.name = "MenuPanel"
	menu_panel.anchor_left = 0.055
	menu_panel.anchor_top = MENU_PANEL_BOTTOM_ANCHOR
	menu_panel.anchor_right = 0.31
	menu_panel.anchor_bottom = MENU_PANEL_BOTTOM_ANCHOR
	menu_panel.offset_top = -MENU_PANEL_HEIGHT
	menu_panel.custom_minimum_size = Vector2(320.0, MENU_PANEL_HEIGHT)
	add_child(menu_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	menu_panel.add_child(margin)
	var buttons := VBoxContainer.new()
	buttons.name = "MenuButtons"
	buttons.add_theme_constant_override("separation", 12)
	margin.add_child(buttons)
	_continue_button = _make_menu_button("ContinueButton", "继续游戏")
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.visible = _has_continue_checkpoint()
	_continue_button.disabled = not _continue_button.visible
	_continue_button.tooltip_text = "加载最后活动档案的最新自动检查点。" if not _continue_button.disabled else "尚无可继续的自动检查点。"
	buttons.add_child(_continue_button)
	_start_button = _make_menu_button("StartButton", "开始游戏")
	_start_button.pressed.connect(_on_start_pressed)
	buttons.add_child(_start_button)
	var load_button := _make_menu_button("LoadButton", "载入游戏")
	load_button.pressed.connect(_on_load_pressed)
	buttons.add_child(load_button)
	var settings_button := _make_menu_button("SettingsButton", "设置")
	settings_button.pressed.connect(_on_settings_pressed)
	buttons.add_child(settings_button)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 18.0)
	buttons.add_child(spacer)
	var exit_button := _make_menu_button("ExitButton", "退出游戏")
	FrontendStyles.apply_danger_button(exit_button)
	exit_button.pressed.connect(_on_exit_pressed)
	buttons.add_child(exit_button)

	var version := Label.new()
	version.name = "VersionLabel"
	version.anchor_left = 0.70
	version.anchor_top = 0.94
	version.anchor_right = 0.975
	version.anchor_bottom = 0.985
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.text = "版本 %s" % str(ProjectSettings.get_setting("application/config/version", "0.0.657-t0135-p7r6-organic-fog"))
	version.modulate = Color(0.52, 0.49, 0.44, 1.0)
	add_child(version)

	_build_loading_overlay()

	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.name = "ExitConfirmationDialog"
	_exit_dialog.title = "退出游戏"
	_exit_dialog.dialog_text = "确定退出游戏吗？"
	_exit_dialog.ok_button_text = "退出"
	_exit_dialog.cancel_button_text = "取消"
	_exit_dialog.unresizable = true
	_exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	add_child(_exit_dialog)
	FrontendStyles.apply_danger_button(_exit_dialog.get_ok_button())


func _build_loading_overlay() -> void:
	_loading_overlay = ColorRect.new()
	_loading_overlay.name = "StartGameLoadingOverlay"
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.color = Color(0.025, 0.022, 0.020, 0.94)
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.z_as_relative = false
	_loading_overlay.z_index = 4096
	add_child(_loading_overlay)

	var panel := PanelContainer.new()
	panel.name = "LoadingPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -92.0
	panel.offset_right = 280.0
	panel.offset_bottom = 92.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.06, 0.05, 0.96)
	panel_style.border_color = Color(0.58, 0.40, 0.17, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)
	_loading_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "正在进入驿站"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.60, 1.0))
	content.add_child(title)
	_loading_status_label = Label.new()
	_loading_status_label.text = "正在准备场景与新手教程，请稍候……"
	_loading_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status_label.add_theme_font_size_override("font_size", 17)
	_loading_status_label.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72, 1.0))
	content.add_child(_loading_status_label)
	_loading_dots_label = Label.new()
	_loading_dots_label.text = "●　○　○"
	_loading_dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_dots_label.add_theme_font_size_override("font_size", 18)
	_loading_dots_label.add_theme_color_override("font_color", Color(0.87, 0.63, 0.25, 1.0))
	content.add_child(_loading_dots_label)
	_loading_overlay.visible = false


func _make_menu_button(node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(275.0, 50.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	FrontendStyles.apply_button_focus(button)
	_connect_ui_audio_button(button)
	return button


func _on_tree_node_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node):
		_connect_ui_audio_button(node as BaseButton)


func _connect_ui_audio_for_subtree(root_node: Node) -> void:
	if root_node is BaseButton:
		_connect_ui_audio_button(root_node as BaseButton)
	for child in root_node.get_children(true):
		_connect_ui_audio_for_subtree(child)


func _connect_ui_audio_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	var instance_id := button.get_instance_id()
	if _audio_connected_button_ids.has(instance_id):
		return
	var callback := Callable(self, "_on_ui_audio_button_pressed").bind(button)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)
	_audio_connected_button_ids[instance_id] = true


func _on_ui_audio_button_pressed(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	var asset_id := UI_TOGGLE_ASSET_ID if button is CheckBox or button is CheckButton else UI_BUTTON_ASSET_ID
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_2d"):
		return
	var player: AudioStreamPlayer = audio_manager.play_2d(asset_id, &"UI")
	if player == null:
		return
	_audio_click_history.append({
		"button_path": str(button.get_path()),
		"asset_id": asset_id,
		"player_type": player.get_class(),
		"bus": str(player.bus),
	})
	while _audio_click_history.size() > AUDIO_HISTORY_LIMIT:
		_audio_click_history.pop_front()


func _attach_animated_cover(hero_frame: Control, hero: Control) -> void:
	_cover_viewport = SubViewport.new()
	_cover_viewport.name = "MenuCoverViewport"
	_cover_viewport.size = MENU_COVER_RENDER_SIZE
	_cover_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_cover_viewport.own_world_3d = true
	_cover_viewport.handle_input_locally = false
	hero_frame.add_child(_cover_viewport)
	_cover_scene = MenuCoverScene.instantiate() as Node3D
	_cover_scene.name = "AnimatedMenuCover"
	_cover_viewport.add_child(_cover_scene)
	if _cover_scene.has_method("configure_runtime_cover"):
		_cover_scene.call("configure_runtime_cover")
	hero.call("set_cover_texture", _cover_viewport.get_texture(), Vector2(0.68, 0.50))


func _on_start_pressed() -> void:
	if _launching_game:
		return
	_show_start_loading_state()
	_publish_new_game_launch_request()
	# The formal station is still built synchronously. Render the loading state
	# once before entering that blocking scene change so the last presented frame
	# gives immediate, unambiguous feedback instead of looking frozen.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var change_error := get_tree().change_scene_to_file(MAIN_SCENE)
	if change_error != OK:
		_launching_game = false
		_loading_overlay.visible = false
		_start_button.disabled = false
		_start_button.grab_focus()


func _on_continue_pressed() -> void:
	if _launching_game:
		return
	var archive_id := GameSaveStore.get_last_active_archive_id()
	var checkpoint := GameSaveStore.inspect_restore_point(archive_id, "auto")
	if archive_id.is_empty() or not bool(checkpoint.get("loadable", false)):
		_continue_button.disabled = true
		_continue_button.tooltip_text = "尚无可继续的自动检查点。"
		return
	_show_start_loading_state()
	get_tree().set_meta(MAIN_LAUNCH_REQUEST_META, {
		"source": "main_menu_continue",
		"startup_mode": 3,
		"archive_id": archive_id,
		"restore_point": "auto",
	})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var change_error := get_tree().change_scene_to_file(MAIN_SCENE)
	if change_error != OK:
		_launching_game = false
		_loading_overlay.visible = false
		_start_button.disabled = false
		_continue_button.disabled = not _has_continue_checkpoint()


func _show_start_loading_state() -> void:
	if _launching_game:
		return
	_launching_game = true
	_loading_started_msec = Time.get_ticks_msec()
	_start_button.disabled = true
	if _continue_button != null:
		_continue_button.disabled = true
	_start_button.release_focus()
	if _settings_panel != null and _settings_panel.visible:
		_settings_panel.close_panel(true)
	if _save_browser != null and _save_browser.visible:
		_save_browser.close_panel()
	if _exit_dialog != null and _exit_dialog.visible:
		_exit_dialog.hide()
	_loading_overlay.visible = true
	_loading_overlay.move_to_front()


func _publish_new_game_launch_request() -> void:
	get_tree().set_meta(MAIN_LAUNCH_REQUEST_META, {
		"source": "main_menu_new_game",
		"startup_mode": NEW_GAME_TUTORIAL_MODE,
	})


func _has_continue_checkpoint() -> bool:
	var archive_id := GameSaveStore.get_last_active_archive_id()
	return not archive_id.is_empty() and bool(GameSaveStore.inspect_restore_point(archive_id, "auto").get("loadable", false))


func _on_load_pressed() -> void:
	_save_browser.open_panel(0, false)


func _on_settings_pressed() -> void:
	_settings_panel.open_panel(0)


func _on_exit_pressed() -> void:
	_exit_dialog.popup_centered(Vector2i(440, 160))
