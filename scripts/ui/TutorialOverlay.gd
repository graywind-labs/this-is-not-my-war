extends Control

const NPCPortraitViewport = preload("res://scripts/ui/NPCPortraitViewport.gd")
const SKIP_BUTTON_Z_INDEX := 4096
const HANDOFF_CARD_Z_INDEX := 4095
const STARTUP_INPUT_GUARD_MSEC := 350

signal continue_requested
signal target_pressed(target_id: String)
signal inspection_requested(kind: String, entity_id: String)
signal skip_confirmed
signal victory_acknowledged

const GOLD := Color(1.0, 0.76, 0.25, 1.0)
const RESPONSIVE_FONT_BASE_HEIGHT := 900.0
const RESPONSIVE_FONT_MAX_SCALE := 1.5
const FORMAL_VICTORY_DIALOG_SIZE := Vector2i(520, 160)

var _comic_texture: TextureRect
var _comic_fallback: ColorRect
var _blocker: ColorRect
var _top_hint_panel: PanelContainer
var _top_hint_label: Label
var _conversation_root: Control
var _conversation_panel: Panel
var _speaker_label: Label
var _dialogue_label: Label
var _continue_label: Label
var _portrait: Control
var _player_emblem: Label
var _skip_button: Button
var _skip_dialog: ConfirmationDialog
var _target_highlight: Panel
var _target_arrow: Label
var _target_proxy: Button
var _inspection_proxies: Dictionary = {}
var _target_id := ""
var _target_base_rect := Rect2()
var _target_pulse_strength := 1.0
var _pulse_elapsed := 0.0
var _continue_enabled := false
var _victory_dialog: AcceptDialog
var _handoff_root: ColorRect
var _handoff_label: Label
var _current_page: Dictionary = {}
var _responsive_font_scale := 1.0
var _full_screen_continue_enabled := false
var _comic_mode_active := false
var _ui_copy: Dictionary = {}
var _startup_input_guard_active := false
var _startup_input_guard_until_msec := 0
var _startup_guard_inputs_down: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900
	_build_overlay()
	_refresh_responsive_typography()
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_update_startup_input_guard()
	_pulse_elapsed += delta
	if _target_highlight.visible:
		var pulse := 0.72 + 0.28 * sin(_pulse_elapsed * (4.0 + _target_pulse_strength * 2.5))
		_target_highlight.modulate = Color(1.0, 1.0, 1.0, pulse)
		_target_arrow.modulate = Color(1.0, 1.0, 1.0, pulse)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _dialogue_label != null:
		call_deferred("_refresh_responsive_typography")
		if _portrait != null and _portrait.visible:
			call_deferred("_layout_dialogue_portrait")


func _input(event: InputEvent) -> void:
	if _consume_startup_input_guard(event):
		get_viewport().set_input_as_handled()
		return
	if _consume_static_frame_shortcut(event):
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if _consume_static_frame_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if not visible or not _continue_enabled or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		continue_requested.emit()
		get_viewport().set_input_as_handled()


func begin() -> void:
	visible = true
	_startup_input_guard_active = true
	_startup_input_guard_until_msec = Time.get_ticks_msec() + STARTUP_INPUT_GUARD_MSEC
	_startup_guard_inputs_down.clear()
	_raise_skip_button()
	_blocker.tooltip_text = ""
	_full_screen_continue_enabled = false
	_comic_mode_active = false
	_handoff_root.visible = false
	_victory_dialog.visible = false
	clear_target()
	set_inspection_targets([])
	_hide_dialogue_portrait()


func configure_copy(copy_config: Dictionary) -> void:
	_ui_copy = copy_config.duplicate(true)
	if _skip_button != null:
		_skip_button.text = _copy_value("skip", "button", "跳过序章")
	if _skip_dialog != null:
		_skip_dialog.title = _copy_value("skip", "title", "跳过序章")
		_skip_dialog.dialog_text = _copy_value("skip", "message", "跳过后将直接进入正式游戏。")
		_skip_dialog.ok_button_text = _copy_value("skip", "confirm", "跳过")
		_skip_dialog.cancel_button_text = _copy_value("skip", "cancel", "继续序章")
	if _victory_dialog != null:
		_victory_dialog.title = _copy_value("victory", "title", "成功守住敌袭")
		_victory_dialog.dialog_text = _copy_value("victory", "message", "恭喜守备官，您守住了这次夜袭！")
		_victory_dialog.ok_button_text = _copy_value("victory", "confirm", "太好了")


func finish() -> void:
	clear_target()
	set_inspection_targets([])
	_full_screen_continue_enabled = false
	_comic_mode_active = false
	_hide_dialogue_portrait()
	_startup_input_guard_active = false
	_startup_guard_inputs_down.clear()
	visible = false


func show_page(page: Dictionary, comic_mode: bool = true) -> void:
	_current_page = page.duplicate(true)
	_comic_mode_active = comic_mode
	_handoff_root.visible = false
	_victory_dialog.visible = false
	_comic_texture.visible = comic_mode
	_comic_fallback.visible = comic_mode
	if comic_mode:
		var image_path := str(page.get("image", ""))
		var texture := load(image_path) as Texture2D if not image_path.is_empty() and ResourceLoader.exists(image_path) else null
		_comic_texture.texture = texture
		_comic_texture.visible = texture != null
		_comic_fallback.visible = texture == null
	else:
		_comic_texture.texture = null
	_conversation_root.visible = true
	_continue_enabled = true
	_full_screen_continue_enabled = true
	_blocker.tooltip_text = ""
	var speaker := str(page.get("speaker", "system"))
	_apply_speaker_layout(speaker)
	_speaker_label.text = "" if speaker == "system" else str(page.get("speaker_name", _speaker_display_name(speaker)))
	_dialogue_label.text = _format_page_text(speaker, str(page.get("text", "")))
	_dialogue_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
		if speaker == "system"
		else HORIZONTAL_ALIGNMENT_RIGHT if speaker == "player" else HORIZONTAL_ALIGNMENT_LEFT
	)
	_speaker_label.horizontal_alignment = _dialogue_label.horizontal_alignment
	_speaker_label.visible = speaker != "system"
	_update_dialogue_portrait(speaker, comic_mode, str(page.get("portrait_npc_id", "")))
	if _player_emblem != null:
		_player_emblem.visible = false
	_continue_label.text = _copy_text("continue", "点击继续")
	clear_target()
	_raise_skip_button()


func _apply_speaker_layout(speaker: String) -> void:
	_speaker_label.anchor_left = 0.025
	_speaker_label.anchor_right = 0.975
	_dialogue_label.anchor_left = 0.025
	_dialogue_label.anchor_right = 0.975
	if speaker == "system":
		_dialogue_label.anchor_top = 0.18
		_dialogue_label.anchor_bottom = 0.76
	else:
		_dialogue_label.anchor_top = 0.25
		_dialogue_label.anchor_bottom = 0.78


func _format_page_text(speaker: String, text: String) -> String:
	var clean_text := text.strip_edges()
	if speaker == "system":
		return ">%s<" % clean_text
	if speaker in ["ada", "player"]:
		return "“%s”" % clean_text
	return clean_text


func show_instruction(text: String, top_hint: String = "", speaker: String = "system") -> void:
	show_page({
		"speaker": speaker,
		"speaker_name": _speaker_display_name(speaker),
		"text": text
	}, false)
	_continue_enabled = false
	_full_screen_continue_enabled = false
	_blocker.tooltip_text = ""
	_continue_label.text = _copy_text("complete_current_operation", "完成当前操作后继续")
	set_top_hint(top_hint)


func show_observation(text: String, top_hint: String = "") -> void:
	show_instruction(text, top_hint, "system")
	_continue_enabled = true
	_full_screen_continue_enabled = true
	_blocker.tooltip_text = ""
	_continue_label.text = _copy_text("continue", "点击继续")


func set_world_mouse_input_passthrough(enabled: bool) -> void:
	if _blocker != null:
		_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP


func hide_conversation() -> void:
	_conversation_root.visible = false
	_hide_dialogue_portrait()
	_continue_enabled = false
	_full_screen_continue_enabled = false
	_comic_mode_active = false


func is_static_frame_input_locked() -> bool:
	return visible and _comic_mode_active


func _consume_static_frame_shortcut(event: InputEvent) -> bool:
	if not is_static_frame_input_locked():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and _continue_enabled
			and key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
		):
			continue_requested.emit()
		return true
	# A controller cancel/shortcut must not open an obscured menu either. Mouse
	# input stays on the full-screen blocker so clicking anywhere can continue.
	return event is InputEventJoypadButton


func set_top_hint(text: String) -> void:
	_top_hint_label.text = text
	_top_hint_panel.visible = false


func _update_top_hint_width() -> void:
	if _top_hint_panel == null or _top_hint_label == null:
		return
	var viewport_width := get_viewport_rect().size.x
	var font := _top_hint_label.get_theme_font("font")
	var font_size := _top_hint_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(_top_hint_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var panel_width := clampf(ceilf(text_width) + 48.0, 150.0, maxf(150.0, viewport_width - 32.0))
	_top_hint_panel.offset_left = -panel_width * 0.5
	_top_hint_panel.offset_right = panel_width * 0.5


func _refresh_responsive_typography() -> void:
	if _dialogue_label == null:
		return
	var viewport_height := get_viewport_rect().size.y
	_responsive_font_scale = clampf(
		viewport_height / RESPONSIVE_FONT_BASE_HEIGHT,
		1.0,
		RESPONSIVE_FONT_MAX_SCALE
	)
	_speaker_label.add_theme_font_size_override("font_size", roundi(21.0 * _responsive_font_scale))
	_dialogue_label.add_theme_font_size_override("font_size", roundi(22.0 * _responsive_font_scale))
	_continue_label.add_theme_font_size_override("font_size", roundi(15.0 * _responsive_font_scale))
	_speaker_label.add_theme_constant_override("outline_size", roundi(4.0 * _responsive_font_scale))
	_dialogue_label.add_theme_constant_override("outline_size", roundi(4.0 * _responsive_font_scale))
	_continue_label.add_theme_constant_override("outline_size", roundi(3.0 * _responsive_font_scale))
	_top_hint_label.add_theme_font_size_override("font_size", roundi(22.0 * _responsive_font_scale))
	_target_arrow.add_theme_font_size_override("font_size", roundi(30.0 * _responsive_font_scale))
	_handoff_label.add_theme_font_size_override("font_size", roundi(31.0 * _responsive_font_scale))
	_top_hint_panel.offset_bottom = roundf(54.0 * _responsive_font_scale)
	if _top_hint_panel.visible:
		_update_top_hint_width()


func set_target_rect(target_id: String, rect: Rect2, tooltip: String = "") -> void:
	if target_id.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		clear_target()
		return
	_target_id = target_id
	_target_base_rect = rect
	var viewport_rect := get_viewport_rect()
	var padded := rect.grow(7.0)
	padded.position.x = clampf(padded.position.x, 2.0, maxf(2.0, viewport_rect.size.x - padded.size.x - 2.0))
	padded.position.y = clampf(padded.position.y, 2.0, maxf(2.0, viewport_rect.size.y - padded.size.y - 2.0))
	_target_highlight.position = padded.position
	_target_highlight.size = padded.size
	_target_highlight.visible = true
	_target_arrow.position = Vector2(
		padded.position.x + padded.size.x * 0.5 - 16.0,
		maxf(54.0, padded.position.y - 38.0)
	)
	_target_arrow.visible = true
	_target_proxy.position = rect.position
	_target_proxy.size = rect.size.max(Vector2(20.0, 20.0))
	_target_proxy.tooltip_text = tooltip if not tooltip.is_empty() else _copy_text("target_tooltip", "执行当前指引")
	_target_proxy.visible = true
	_raise_skip_button()


func set_target_pulse_strength(strength: float) -> void:
	_target_pulse_strength = clampf(strength, 1.0, 3.0)


func clear_target() -> void:
	_target_id = ""
	_target_base_rect = Rect2()
	_target_highlight.visible = false
	_target_arrow.visible = false
	_target_proxy.visible = false


func set_inspection_targets(targets: Array) -> void:
	var active_keys: Array[String] = []
	for raw_target in targets:
		if not raw_target is Dictionary:
			continue
		var target := raw_target as Dictionary
		var kind := str(target.get("kind", ""))
		var entity_id := str(target.get("entity_id", ""))
		var rect: Variant = target.get("rect", Rect2())
		if kind.is_empty() or entity_id.is_empty() or not rect is Rect2 or (rect as Rect2).size.x <= 0.0:
			continue
		var key := "%s:%s" % [kind, entity_id]
		active_keys.append(key)
		var proxy := _inspection_proxies.get(key) as Button
		if proxy == null:
			proxy = Button.new()
			proxy.name = "Inspect_%s" % key.validate_node_name()
			proxy.flat = true
			proxy.focus_mode = Control.FOCUS_NONE
			proxy.mouse_filter = Control.MOUSE_FILTER_STOP
			proxy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			proxy.tooltip_text = (
				_copy_text("inspect_npc_tooltip", "查看人物状态")
				if kind == "npc"
				else _copy_text("inspect_enemy_tooltip", "查看敌人状态")
			)
			proxy.pressed.connect(_on_inspection_proxy_pressed.bind(kind, entity_id))
			add_child(proxy)
			move_child(proxy, _target_proxy.get_index())
			_inspection_proxies[key] = proxy
		proxy.position = (rect as Rect2).position
		proxy.size = (rect as Rect2).size
		proxy.visible = true
	for raw_key in _inspection_proxies.keys():
		var key := str(raw_key)
		if active_keys.has(key):
			continue
		var proxy := _inspection_proxies.get(raw_key) as Button
		if proxy != null:
			proxy.visible = false
	_raise_skip_button()


func show_victory() -> void:
	clear_target()
	set_top_hint("")
	_conversation_root.visible = false
	_hide_dialogue_portrait()
	_continue_enabled = false
	_victory_dialog.dialog_text = _copy_value("victory", "message", "恭喜守备官，您守住了这次夜袭！")
	_victory_dialog.popup_centered()


func show_handoff_card() -> void:
	clear_target()
	set_top_hint("")
	_conversation_root.visible = false
	_hide_dialogue_portrait()
	_victory_dialog.visible = false
	_continue_enabled = false
	_handoff_root.visible = true
	_handoff_label.text = _copy_text("handoff_card", "第 1 日　06:00\n\n在第 1 波敌军到达前组织驿站\n\n最终目标：守住 5 波敌袭")


func get_debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"page": _current_page.duplicate(true),
		"top_hint": _top_hint_label.text if _top_hint_label != null else "",
		"top_hint_visible": _top_hint_panel != null and _top_hint_panel.visible,
		"conversation_visible": _conversation_root != null and _conversation_root.visible,
		"continue_enabled": _continue_enabled,
		"full_screen_continue_enabled": _full_screen_continue_enabled,
		"static_frame_input_locked": is_static_frame_input_locked(),
		"startup_input_guard_active": _startup_input_guard_active,
		"startup_guard_inputs_down": _startup_guard_inputs_down.keys(),
		"continue_text": _continue_label.text if _continue_label != null else "",
		"continue_rect": _continue_label.get_global_rect() if _continue_label != null else Rect2(),
		"blocker_tooltip": _blocker.tooltip_text if _blocker != null else "",
		"world_mouse_input_passthrough": _blocker != null and _blocker.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"target_id": _target_id,
		"target_rect": _target_base_rect,
		"target_visible": _target_proxy != null and _target_proxy.visible,
		"inspection_target_count": _inspection_proxies.values().filter(func(proxy: Variant) -> bool: return proxy is Button and (proxy as Button).visible).size(),
		"victory_visible": _victory_dialog != null and _victory_dialog.visible,
		"victory_control_class": _victory_dialog.get_class() if _victory_dialog != null else "",
		"victory_title": _victory_dialog.title if _victory_dialog != null else "",
		"victory_dialog_text": _victory_dialog.dialog_text if _victory_dialog != null else "",
		"victory_ok_button_text": _victory_dialog.get_ok_button().text if _victory_dialog != null else "",
		"victory_size": _victory_dialog.size if _victory_dialog != null else Vector2i.ZERO,
		"victory_configured_size": FORMAL_VICTORY_DIALOG_SIZE,
		"victory_exclusive": _victory_dialog.exclusive if _victory_dialog != null else false,
		"victory_unresizable": _victory_dialog.unresizable if _victory_dialog != null else false,
		"handoff_visible": _handoff_root != null and _handoff_root.visible,
		"handoff_text": _handoff_label.text if _handoff_label != null else "",
		"handoff_z_index": _handoff_root.z_index if _handoff_root != null else 0,
		"handoff_z_as_relative": _handoff_root.z_as_relative if _handoff_root != null else true,
		"skip_button_text": _skip_button.text if _skip_button != null else "",
		"skip_z_index": _skip_button.z_index if _skip_button != null else 0,
		"skip_z_as_relative": _skip_button.z_as_relative if _skip_button != null else true,
		"skip_is_front_child": _skip_button != null and _skip_button.get_index() == get_child_count() - 1,
		"skip_title": _skip_dialog.title if _skip_dialog != null else "",
		"skip_dialog_text": _skip_dialog.dialog_text if _skip_dialog != null else "",
		"skip_ok_button_text": _skip_dialog.get_ok_button().text if _skip_dialog != null else "",
		"skip_cancel_button_text": _skip_dialog.get_cancel_button().text if _skip_dialog != null else "",
		"viewport_size": get_viewport_rect().size,
		"conversation_rect": _conversation_root.get_global_rect() if _conversation_root != null else Rect2(),
		"conversation_alpha": _get_conversation_alpha(),
		"speaker_rect": _speaker_label.get_global_rect() if _speaker_label != null else Rect2(),
		"speaker_text": _speaker_label.text if _speaker_label != null else "",
		"speaker_visible": _speaker_label != null and _speaker_label.visible,
		"dialogue_text": _dialogue_label.text if _dialogue_label != null else "",
		"dialogue_alignment": _dialogue_label.horizontal_alignment if _dialogue_label != null else HORIZONTAL_ALIGNMENT_LEFT,
		"dialogue_font_size": _dialogue_label.get_theme_font_size("font_size") if _dialogue_label != null else 0,
		"speaker_font_size": _speaker_label.get_theme_font_size("font_size") if _speaker_label != null else 0,
		"continue_font_size": _continue_label.get_theme_font_size("font_size") if _continue_label != null else 0,
		"top_hint_font_size": _top_hint_label.get_theme_font_size("font_size") if _top_hint_label != null else 0,
		"responsive_font_scale": _responsive_font_scale,
		"portrait_rect": _portrait.get_global_rect() if _portrait != null else Rect2(),
		"portrait_visible": _portrait != null and _portrait.visible,
		"portrait_snapshot": _portrait.call("debug_get_snapshot") if _portrait != null and _portrait.has_method("debug_get_snapshot") else {},
		"player_emblem_rect": _player_emblem.get_global_rect() if _player_emblem != null else Rect2(),
		"player_emblem_visible": _player_emblem != null and _player_emblem.visible,
		"skip_rect": _skip_button.get_global_rect() if _skip_button != null else Rect2(),
		"top_hint_rect": _top_hint_panel.get_global_rect() if _top_hint_panel != null else Rect2()
	}


func _get_conversation_alpha() -> float:
	if _conversation_panel == null:
		return 0.0
	var style := _conversation_panel.get_theme_stylebox("panel") as StyleBoxFlat
	return style.bg_color.a if style != null else 0.0


func _build_overlay() -> void:
	_comic_fallback = ColorRect.new()
	_comic_fallback.name = "ComicFallback"
	_comic_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_comic_fallback.color = Color(0.055, 0.05, 0.045, 1.0)
	_comic_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_comic_fallback)

	_comic_texture = TextureRect.new()
	_comic_texture.name = "ComicTexture"
	_comic_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_comic_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_comic_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_comic_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_comic_texture)

	_blocker = ColorRect.new()
	_blocker.name = "TutorialInputBlocker"
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocker.color = Color(0.0, 0.0, 0.0, 0.08)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.tooltip_text = ""
	_blocker.gui_input.connect(_on_blocker_gui_input)
	add_child(_blocker)

	_build_top_hint()
	_build_conversation()
	_build_target_focus()
	_build_skip_control()
	_build_victory_dialog()
	_build_handoff_card()


func _build_top_hint() -> void:
	_top_hint_panel = PanelContainer.new()
	_top_hint_panel.name = "TopHintPanel"
	_top_hint_panel.anchor_left = 0.5
	_top_hint_panel.anchor_top = 0.025
	_top_hint_panel.anchor_right = 0.5
	_top_hint_panel.anchor_bottom = 0.025
	_top_hint_panel.offset_left = -75.0
	_top_hint_panel.offset_right = 75.0
	_top_hint_panel.offset_bottom = 54.0
	_top_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.075, 0.07, 0.91)
	style.border_color = Color(0.76, 0.58, 0.25, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	_top_hint_panel.add_theme_stylebox_override("panel", style)
	add_child(_top_hint_panel)
	_top_hint_label = Label.new()
	_top_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_hint_label.add_theme_font_size_override("font_size", 22)
	_top_hint_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72, 1.0))
	_top_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_hint_panel.add_child(_top_hint_label)
	_top_hint_panel.visible = false


func _build_conversation() -> void:
	_conversation_root = Control.new()
	_conversation_root.name = "ConversationRoot"
	_conversation_root.anchor_left = 0.04
	_conversation_root.anchor_top = 0.70
	_conversation_root.anchor_right = 0.96
	_conversation_root.anchor_bottom = 0.97
	_conversation_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_conversation_root)

	var advance_surface := Button.new()
	advance_surface.name = "DialogueAdvanceSurface"
	advance_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	advance_surface.flat = true
	advance_surface.focus_mode = Control.FOCUS_NONE
	advance_surface.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	advance_surface.pressed.connect(_on_continue_pressed)
	_conversation_root.add_child(advance_surface)

	_speaker_label = Label.new()
	_speaker_label.anchor_left = 0.025
	_speaker_label.anchor_top = 0.07
	_speaker_label.anchor_right = 0.975
	_speaker_label.anchor_bottom = 0.25
	_speaker_label.add_theme_font_size_override("font_size", 21)
	_speaker_label.add_theme_color_override("font_color", GOLD)
	_speaker_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.96))
	_speaker_label.add_theme_constant_override("outline_size", 4)
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conversation_root.add_child(_speaker_label)

	_portrait = NPCPortraitViewport.new()
	_portrait.name = "AdaDialoguePortrait"
	_portrait.call("configure_headshot")
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conversation_root.add_child(_portrait)
	_portrait.call("hide_preview")
	_portrait.visible = false

	_dialogue_label = Label.new()
	_dialogue_label.anchor_left = 0.025
	_dialogue_label.anchor_top = 0.25
	_dialogue_label.anchor_right = 0.975
	_dialogue_label.anchor_bottom = 0.78
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialogue_label.add_theme_font_size_override("font_size", 22)
	_dialogue_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.91, 1.0))
	_dialogue_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.96))
	_dialogue_label.add_theme_constant_override("outline_size", 4)
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conversation_root.add_child(_dialogue_label)

	_continue_label = Label.new()
	_continue_label.anchor_left = 0.70
	_continue_label.anchor_top = 0.80
	_continue_label.anchor_right = 0.99
	_continue_label.anchor_bottom = 0.99
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_label.add_theme_font_size_override("font_size", 15)
	_continue_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.96))
	_continue_label.add_theme_constant_override("outline_size", 3)
	_continue_label.modulate = Color(0.77, 0.74, 0.68, 1.0)
	_continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conversation_root.add_child(_continue_label)


func _update_dialogue_portrait(speaker: String, comic_mode: bool, npc_id: String) -> void:
	if _portrait == null:
		return
	var show_ada_headshot := not comic_mode and speaker == "ada" and not npc_id.is_empty()
	_portrait.visible = show_ada_headshot
	if show_ada_headshot:
		_layout_dialogue_portrait()
		_portrait.call("show_npc", npc_id)
	else:
		_portrait.call("hide_preview")


func _hide_dialogue_portrait() -> void:
	if _portrait == null:
		return
	_portrait.call("hide_preview")
	_portrait.visible = false


func _layout_dialogue_portrait() -> void:
	if _portrait == null or _conversation_root == null:
		return
	var viewport_height := get_viewport_rect().size.y
	var side := clampf(roundf(viewport_height * 0.17), 132.0, 190.0)
	_portrait.position = Vector2(_conversation_root.size.x * 0.025, -side - 8.0)
	_portrait.size = Vector2(side, side)
	_portrait.custom_minimum_size = Vector2(side, side)

func _build_target_focus() -> void:
	_target_highlight = Panel.new()
	_target_highlight.name = "TargetHighlight"
	_target_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.70, 0.16, 0.10)
	style.border_color = GOLD
	style.set_border_width_all(4)
	style.set_corner_radius_all(9)
	_target_highlight.add_theme_stylebox_override("panel", style)
	add_child(_target_highlight)

	_target_arrow = Label.new()
	_target_arrow.name = "TargetArrow"
	_target_arrow.size = Vector2(32.0, 34.0)
	_target_arrow.text = "▼"
	_target_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_arrow.add_theme_font_size_override("font_size", 30)
	_target_arrow.add_theme_color_override("font_color", GOLD)
	_target_arrow.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 1.0))
	_target_arrow.add_theme_constant_override("outline_size", 5)
	_target_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_target_arrow)

	_target_proxy = Button.new()
	_target_proxy.name = "CurrentTargetProxy"
	_target_proxy.flat = true
	_target_proxy.focus_mode = Control.FOCUS_NONE
	_target_proxy.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_proxy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_target_proxy.pressed.connect(_on_target_proxy_pressed)
	add_child(_target_proxy)
	clear_target()


func _build_skip_control() -> void:
	_skip_button = Button.new()
	_skip_button.name = "SkipTutorialButton"
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.offset_left = -174.0
	_skip_button.offset_top = 18.0
	_skip_button.offset_right = -22.0
	_skip_button.offset_bottom = 58.0
	_skip_button.text = "跳过序章"
	_skip_button.z_as_relative = false
	_skip_button.z_index = SKIP_BUTTON_Z_INDEX
	_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.pressed.connect(_on_skip_pressed)
	add_child(_skip_button)

	_skip_dialog = ConfirmationDialog.new()
	_skip_dialog.name = "SkipTutorialConfirmation"
	_skip_dialog.title = "跳过序章"
	_skip_dialog.dialog_text = "跳过后将直接进入正式游戏。"
	_skip_dialog.ok_button_text = "跳过"
	_skip_dialog.cancel_button_text = "继续序章"
	_skip_dialog.confirmed.connect(func() -> void: skip_confirmed.emit())
	add_child(_skip_dialog)


func _build_victory_dialog() -> void:
	_victory_dialog = AcceptDialog.new()
	_victory_dialog.name = "TutorialVictoryDialog"
	_victory_dialog.title = "成功守住敌袭"
	_victory_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	_victory_dialog.size = FORMAL_VICTORY_DIALOG_SIZE
	_victory_dialog.exclusive = true
	_victory_dialog.unresizable = true
	_victory_dialog.dialog_text = "恭喜守备官，您守住了这次夜袭！"
	_victory_dialog.ok_button_text = "太好了"
	_victory_dialog.confirmed.connect(_on_victory_dialog_closed)
	_victory_dialog.close_requested.connect(_on_victory_dialog_closed)
	add_child(_victory_dialog)


func _on_victory_dialog_closed() -> void:
	_victory_dialog.hide()
	victory_acknowledged.emit()


func _build_handoff_card() -> void:
	_handoff_root = ColorRect.new()
	_handoff_root.name = "TutorialHandoffCard"
	_handoff_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handoff_root.color = Color(0.025, 0.022, 0.020, 1.0)
	_handoff_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_handoff_root.z_as_relative = false
	_handoff_root.z_index = HANDOFF_CARD_Z_INDEX
	add_child(_handoff_root)
	_handoff_label = Label.new()
	_handoff_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_handoff_label.add_theme_font_size_override("font_size", 31)
	_handoff_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.67, 1.0))
	_handoff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handoff_root.add_child(_handoff_label)
	_handoff_root.visible = false


func _on_continue_pressed() -> void:
	if _continue_enabled:
		continue_requested.emit()


func _on_blocker_gui_input(event: InputEvent) -> void:
	if _startup_input_guard_active:
		accept_event()
		return
	if (
		_full_screen_continue_enabled
		and _continue_enabled
		and event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		and (event as InputEventMouseButton).pressed
	):
		continue_requested.emit()
		accept_event()


func _on_target_proxy_pressed() -> void:
	if not _target_id.is_empty():
		target_pressed.emit(_target_id)


func _on_inspection_proxy_pressed(kind: String, entity_id: String) -> void:
	if _full_screen_continue_enabled and _continue_enabled:
		continue_requested.emit()
		return
	inspection_requested.emit(kind, entity_id)


func _on_skip_pressed() -> void:
	if _startup_input_guard_active:
		return
	_skip_dialog.popup_centered(Vector2i(460, 170))


func _consume_startup_input_guard(event: InputEvent) -> bool:
	if not visible or not _startup_input_guard_active:
		return false
	var input_id := ""
	var pressed := false
	if event is InputEventMouseButton:
		input_id = "mouse:%d" % (event as InputEventMouseButton).button_index
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventKey:
		input_id = "key:%d" % (event as InputEventKey).physical_keycode
		pressed = (event as InputEventKey).pressed
	elif event is InputEventJoypadButton:
		input_id = "joy:%d:%d" % [(event as InputEventJoypadButton).device, (event as InputEventJoypadButton).button_index]
		pressed = (event as InputEventJoypadButton).pressed
	else:
		return false
	if pressed:
		_startup_guard_inputs_down[input_id] = true
	else:
		_startup_guard_inputs_down.erase(input_id)
	return true


func _update_startup_input_guard() -> void:
	if not _startup_input_guard_active:
		return
	if Time.get_ticks_msec() < _startup_input_guard_until_msec:
		return
	if not _startup_guard_inputs_down.is_empty():
		return
	_startup_input_guard_active = false


func _raise_skip_button() -> void:
	if _skip_button == null:
		return
	_skip_button.move_to_front()


func _speaker_display_name(speaker: String) -> String:
	var configured_names: Dictionary = _ui_copy.get("speaker_names", {}) if _ui_copy.get("speaker_names", {}) is Dictionary else {}
	if configured_names.has(speaker):
		return str(configured_names.get(speaker, ""))
	match speaker:
		"ada":
			return "艾达"
		"player":
			return "守备官"
		"order":
			return "军令"
		_:
			return "系统"


func _copy_text(key: String, fallback: String) -> String:
	var value := str(_ui_copy.get(key, fallback))
	return value if not value.is_empty() else fallback


func _copy_value(section: String, key: String, fallback: String) -> String:
	var values: Dictionary = _ui_copy.get(section, {}) if _ui_copy.get(section, {}) is Dictionary else {}
	var value := str(values.get(key, fallback))
	return value if not value.is_empty() else fallback
