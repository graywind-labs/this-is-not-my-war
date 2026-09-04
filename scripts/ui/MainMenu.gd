extends Control

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const SettingsPanelScene = preload("res://scenes/ui/SettingsPanel.tscn")
const SaveBrowserScene = preload("res://scenes/ui/SaveBrowserPanel.tscn")
const MenuHeroBackdropClass = preload("res://scripts/ui/MenuHeroBackdrop.gd")
const MenuEdgeFogClass = preload("res://scripts/ui/MenuEdgeFog.gd")
const MenuCoverScene = preload("res://scenes/art/MenuCoverPreview.tscn")
const FrontendStyles = preload("res://scripts/ui/FrontendStyles.gd")
const MENU_PANEL_HEIGHT := 320.0
const MENU_PANEL_BOTTOM_ANCHOR := 0.88
const MENU_COVER_RENDER_SIZE := Vector2i(1920, 1080)

var _settings_panel: Control
var _save_browser: Control
var _exit_dialog: ConfirmationDialog
var _start_button: Button
var _cover_viewport: SubViewport
var _cover_scene: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_settings_panel = SettingsPanelScene.instantiate()
	_settings_panel.name = "SettingsPanel"
	add_child(_settings_panel)
	_save_browser = SaveBrowserScene.instantiate()
	_save_browser.name = "SaveBrowserPanel"
	add_child(_save_browser)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("switch_music"):
		audio_manager.switch_music("music_menu", 1.2)
	_start_button.grab_focus()


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
		"button_order": ["开始游戏", "载入游戏", "设置", "退出游戏"],
		"settings_visible": _settings_panel != null and _settings_panel.visible,
		"save_browser_visible": _save_browser != null and _save_browser.visible,
		"exit_confirmation_visible": _exit_dialog != null and _exit_dialog.visible,
		"menu_music": str(get_node_or_null("/root/AudioManager").get_current_music_asset_id()) if get_node_or_null("/root/AudioManager") != null else "",
		"hero_animated": find_child("MenuHeroBackdrop", true, false) != null,
		"animated_cover_connected": _cover_scene != null and is_instance_valid(_cover_scene),
		"cover_render_size": _cover_viewport.size if _cover_viewport != null else Vector2i.ZERO,
		"edge_fog_connected": find_child("MenuEdgeFog", true, false) != null,
	}


func debug_open_settings() -> void:
	_on_settings_pressed()


func debug_open_load_browser() -> void:
	_on_load_pressed()


func debug_open_exit_confirmation() -> void:
	_on_exit_pressed()


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


func _make_menu_button(node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(275.0, 50.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	FrontendStyles.apply_button_focus(button)
	return button


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
	_start_button.disabled = true
	get_tree().call_deferred("change_scene_to_file", MAIN_SCENE)


func _on_load_pressed() -> void:
	_save_browser.open_panel(0, false)


func _on_settings_pressed() -> void:
	_settings_panel.open_panel(0)


func _on_exit_pressed() -> void:
	_exit_dialog.popup_centered(Vector2i(440, 160))
