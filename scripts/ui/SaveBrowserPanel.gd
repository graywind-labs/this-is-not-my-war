extends Control

signal closed

enum Mode { LOAD, SAVE }

const FrontendStyles = preload("res://scripts/ui/FrontendStyles.gd")
const GameSaveStore = preload("res://scripts/systems/GameSaveStore.gd")
const MAIN_SCENE := "res://scenes/main/Main.tscn"
const MAIN_LAUNCH_REQUEST_META := &"main_launch_request"
const LOAD_STARTUP_MODE := 3
const PANEL_SIZE := Vector2(980.0, 600.0)
const MANUAL_SLOT_COUNT := 10

var _mode := Mode.LOAD
var _warn_before_load := false
var _slots: Array[Dictionary] = []
var _slot_buttons: Dictionary = {}
var _selected_slot_id := ""
var _title: Label
var _mode_hint: Label
var _name_input: LineEdit
var _detail_label: Label
var _preview_texture: TextureRect
var _preview_label: Label
var _status_label: Label
var _action_button: Button
var _delete_button: Button
var _restore_point_selector: OptionButton
var _overwrite_dialog: ConfirmationDialog
var _load_dialog: ConfirmationDialog
var _delete_dialog: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_slot_model()
	_build_panel()
	_refresh_slot_list()


func open_panel(mode: int = Mode.LOAD, warn_before_load := false) -> void:
	_mode = Mode.SAVE if mode == Mode.SAVE else Mode.LOAD
	_warn_before_load = warn_before_load
	_build_slot_model()
	_selected_slot_id = "slot_01" if _mode == Mode.SAVE else _first_occupied_slot_id()
	_status_label.text = ""
	visible = true
	move_to_front()
	_refresh_mode()
	_refresh_slot_list()
	_refresh_details()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func debug_select_slot(slot_id: String) -> void:
	_select_slot(slot_id)


func debug_set_slot_preview(slot_id: String, data: Dictionary) -> void:
	for index in range(_slots.size()):
		if str(_slots[index].get("slot_id", "")) != slot_id:
			continue
		var updated: Dictionary = _slots[index].duplicate(true)
		updated.merge(data, true)
		updated["occupied"] = true
		_slots[index] = updated
		_refresh_slot_list()
		_refresh_details()
		return


func debug_press_action() -> void:
	_on_action_pressed()


func debug_get_snapshot() -> Dictionary:
	var occupied_count := 0
	for slot in _slots:
		if bool(slot.get("occupied", false)):
			occupied_count += 1
	return {
		"visible": visible,
		"mode": "save" if _mode == Mode.SAVE else "load",
		"slot_count": _slots.size(),
		"manual_slot_count": MANUAL_SLOT_COUNT,
		"occupied_count": occupied_count,
		"selected_slot_id": _selected_slot_id,
		"action_text": _action_button.text if _action_button != null else "",
		"action_disabled": _action_button.disabled if _action_button != null else true,
		"delete_disabled": _delete_button.disabled if _delete_button != null else true,
		"name_editable": _name_input.editable if _name_input != null else false,
		"status": _status_label.text if _status_label != null else "",
		"warn_before_load": _warn_before_load,
		"reads_spatial_checkpoint": false,
	}


func _build_slot_model() -> void:
	_slots = GameSaveStore.list_slot_records()


func _empty_slot(slot_id: String, display_name: String, quick: bool) -> Dictionary:
	return {
		"slot_id": slot_id,
		"display_name": display_name,
		"quick": quick,
		"occupied": false,
		"day": 0,
		"game_time": "--:--",
		"wave": 0,
		"saved_at": "尚未保存",
		"play_time": "--",
		"version": "--",
	}


func _build_panel() -> void:
	var dim := ColorRect.new()
	dim.name = "Dimmer"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = FrontendStyles.make_overlay_color()
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "SaveBrowserWindow"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -PANEL_SIZE * 0.5
	panel.size = PANEL_SIZE
	panel.custom_minimum_size = PANEL_SIZE
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading_stack)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	heading_stack.add_child(_title)
	_mode_hint = Label.new()
	_mode_hint.modulate = Color(0.76, 0.72, 0.62, 1.0)
	heading_stack.add_child(_mode_hint)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(42.0, 36.0)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(580.0, 0.0)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_panel)
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 10)
	list_margin.add_theme_constant_override("margin_top", 10)
	list_margin.add_theme_constant_override("margin_right", 10)
	list_margin.add_theme_constant_override("margin_bottom", 10)
	list_panel.add_child(list_margin)
	var scroll := ScrollContainer.new()
	scroll.name = "SlotScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_margin.add_child(scroll)
	var slot_list := VBoxContainer.new()
	slot_list.name = "SlotList"
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_list.add_theme_constant_override("separation", 7)
	scroll.add_child(slot_list)
	for slot in _slots:
		var button := Button.new()
		var slot_id := str(slot.get("slot_id", ""))
		button.name = "Slot_%s" % slot_id
		button.custom_minimum_size = Vector2(0.0, 62.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_slot.bind(slot_id))
		slot_list.add_child(button)
		_slot_buttons[slot_id] = button

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 16)
	detail_margin.add_theme_constant_override("margin_top", 14)
	detail_margin.add_theme_constant_override("margin_right", 16)
	detail_margin.add_theme_constant_override("margin_bottom", 14)
	detail_panel.add_child(detail_margin)
	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 12)
	detail_margin.add_child(detail_content)
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(0.0, 180.0)
	detail_content.add_child(preview)
	_preview_texture = TextureRect.new()
	_preview_texture.name = "SaveThumbnail"
	_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_preview_texture)
	_preview_label = Label.new()
	_preview_label.name = "SaveThumbnailPlaceholder"
	_preview_label.text = "存档缩略图\n当前恢复点未生成缩略图"
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_label.modulate = Color(0.58, 0.55, 0.48, 1.0)
	_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_preview_label)
	var name_label := Label.new()
	name_label.text = "存档名称"
	detail_content.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.name = "SaveNameInput"
	_name_input.max_length = 32
	detail_content.add_child(_name_input)
	_restore_point_selector = OptionButton.new()
	_restore_point_selector.name = "RestorePointSelector"
	_restore_point_selector.add_item("最新自动检查点", 0)
	_restore_point_selector.add_item("玩家固定检查点", 1)
	_restore_point_selector.item_selected.connect(_on_restore_point_selected)
	detail_content.add_child(_restore_point_selector)
	_detail_label = Label.new()
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(_detail_label)

	_status_label = Label.new()
	_status_label.name = "SaveStatus"
	_status_label.custom_minimum_size = Vector2(0.0, 38.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	content.add_child(footer)
	_delete_button = Button.new()
	_delete_button.name = "DeleteButton"
	_delete_button.text = "删除存档"
	_delete_button.pressed.connect(_on_delete_pressed)
	FrontendStyles.apply_danger_button(_delete_button)
	footer.add_child(_delete_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var cancel_button := Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "取消"
	cancel_button.pressed.connect(close_panel)
	footer.add_child(cancel_button)
	_action_button = Button.new()
	_action_button.name = "PrimaryActionButton"
	_action_button.custom_minimum_size = Vector2(128.0, 38.0)
	_action_button.pressed.connect(_on_action_pressed)
	footer.add_child(_action_button)

	_overwrite_dialog = _make_confirmation("覆盖固定检查点", "确定用最近一次自动检查点替换该槽位吗？当前检查点之后的进度不会保存。", "覆盖")
	_overwrite_dialog.confirmed.connect(_perform_save)
	add_child(_overwrite_dialog)
	_load_dialog = _make_confirmation("加载游戏", "加载后，当前未保存的游戏进度将会丢失。是否继续？", "加载")
	_load_dialog.confirmed.connect(_perform_load)
	add_child(_load_dialog)
	_delete_dialog = _make_confirmation("删除存档", "确定删除选中的存档吗？此操作无法撤销。", "删除")
	_delete_dialog.confirmed.connect(_perform_delete)
	add_child(_delete_dialog)


func _make_confirmation(title_text: String, body: String, ok_text: String) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title_text
	dialog.dialog_text = body
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = "取消"
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.unresizable = true
	return dialog


func _refresh_mode() -> void:
	if _mode == Mode.SAVE:
		_title.text = "固定最近检查点"
		_mode_hint.text = "只复制最近一次战后自动检查点；当前检查点之后的进度不会保存。"
	else:
		_title.text = "载入游戏"
		_mode_hint.text = "选择一个可用存档，然后点击加载。"


func _refresh_slot_list() -> void:
	for slot in _slots:
		var slot_id := str(slot.get("slot_id", ""))
		var button := _slot_buttons.get(slot_id) as Button
		if button == null:
			continue
		var point := _preferred_point(slot)
		var occupied := bool(slot.get("occupied", false)) and not point.is_empty()
		var prefix := "[快速] " if bool(slot.get("quick", false)) else ""
		button.text = "%s%s\n%s" % [
			prefix,
			str(slot.get("display_name", slot_id)),
			("第 %d 天 · %s · 第 %d 波" % [int(point.get("day", 1)), str(point.get("game_time", "06:00")), int(point.get("checkpoint_wave", 0))]) if occupied else "— 空槽 —"
		]
		button.button_pressed = slot_id == _selected_slot_id


func _refresh_details() -> void:
	var slot := _get_selected_slot()
	if slot.is_empty():
		_show_thumbnail_placeholder("尚未选择恢复点")
		_name_input.text = ""
		_name_input.editable = false
		_detail_label.text = "尚未选择存档。"
		_action_button.text = "加载" if _mode == Mode.LOAD else "保存"
		_action_button.disabled = true
		_delete_button.disabled = true
		return
	var occupied := bool(slot.get("occupied", false))
	var quick := bool(slot.get("quick", false))
	var point := _preferred_point(slot)
	_refresh_thumbnail(point)
	_name_input.text = str(slot.get("display_name", ""))
	_name_input.editable = _mode == Mode.SAVE and not quick
	_name_input.placeholder_text = "请输入存档名称"
	_restore_point_selector.visible = _mode == Mode.LOAD and occupied
	if _restore_point_selector.visible:
		_restore_point_selector.set_item_disabled(0, not bool((slot.get("auto", {}) as Dictionary).get("loadable", false)))
		_restore_point_selector.set_item_disabled(1, not bool((slot.get("manual", {}) as Dictionary).get("loadable", false)))
	_detail_label.text = (
		"第 %d 天　%s\n检查点：第 %d 波结束\n版本：%s\n%s"
		% [
			int(point.get("day", 0)), str(point.get("game_time", "--:--")),
			int(point.get("checkpoint_wave", 0)), str(point.get("game_version", "--")),
			"可加载" if bool(point.get("loadable", false)) else "不可加载：%s" % str(point.get("reason", "未知错误"))
		]
		if occupied
		else ("快速槽尚为空。\n游戏内会把最近检查点固定到这里。" if quick else "这是一个空槽。\n只能固定已经生成的开局或战后检查点。")
	)
	_delete_button.disabled = not occupied
	if _mode == Mode.LOAD:
		_action_button.text = "加载"
		_action_button.disabled = not occupied or not bool(point.get("loadable", false))
	else:
		_action_button.text = "覆盖" if occupied else "保存"
		var save_system := get_node_or_null("/root/Main/Systems/GameSaveSystem")
		_action_button.disabled = quick or save_system == null or not bool(save_system.has_automatic_checkpoint())


func _select_slot(slot_id: String) -> void:
	if not _slot_buttons.has(slot_id):
		return
	_selected_slot_id = slot_id
	_status_label.text = ""
	_refresh_slot_list()
	_refresh_details()


func _get_selected_slot() -> Dictionary:
	for slot in _slots:
		if str(slot.get("slot_id", "")) == _selected_slot_id:
			return slot
	return {}


func _on_action_pressed() -> void:
	var slot := _get_selected_slot()
	if slot.is_empty():
		return
	if _mode == Mode.SAVE:
		if bool(slot.get("occupied", false)):
			_overwrite_dialog.popup_centered(Vector2i(520, 180))
		else:
			_perform_save()
	elif bool(slot.get("occupied", false)):
		if _warn_before_load:
			_load_dialog.popup_centered(Vector2i(560, 190))
		else:
			_perform_load()


func _on_delete_pressed() -> void:
	if not _get_selected_slot().is_empty() and bool(_get_selected_slot().get("occupied", false)):
		_delete_dialog.popup_centered(Vector2i(520, 180))


func _perform_save() -> void:
	var save_system := get_node_or_null("/root/Main/Systems/GameSaveSystem")
	if save_system == null:
		_show_status("只能在游戏内固定检查点。", true)
		return
	var slot := _get_selected_slot()
	var result: Dictionary = save_system.pin_latest_checkpoint(_selected_slot_id, _name_input.text)
	_show_status("最近检查点已固定。" if bool(result.get("ok", false)) else "保存失败：%s" % str(result.get("reason", "未知错误")), not bool(result.get("ok", false)))
	_build_slot_model()
	_refresh_slot_list()
	_refresh_details()


func _perform_load() -> void:
	var slot := _get_selected_slot()
	var archive_id := str(slot.get("archive_id", ""))
	var point_name := "manual" if _restore_point_selector.selected == 1 else "auto"
	var point: Dictionary = slot.get(point_name, {}) if slot.get(point_name, {}) is Dictionary else {}
	if not bool(point.get("loadable", false)):
		point_name = "auto" if point_name == "manual" else "manual"
		point = slot.get(point_name, {}) if slot.get(point_name, {}) is Dictionary else {}
	if archive_id.is_empty() or not bool(point.get("loadable", false)):
		_show_status("该恢复点不可加载。", true)
		return
	get_tree().set_meta(MAIN_LAUNCH_REQUEST_META, {
		"source": "save_browser_load",
		"startup_mode": LOAD_STARTUP_MODE,
		"archive_id": archive_id,
		"restore_point": point_name,
	})
	GameSaveStore.set_last_active_archive(archive_id)
	var error := get_tree().change_scene_to_file(MAIN_SCENE)
	if error != OK:
		_show_status("无法创建游戏场景：%s" % error_string(error), true)


func _perform_delete() -> void:
	var result := GameSaveStore.delete_slot(_selected_slot_id)
	_show_status("存档槽位已删除。" if bool(result.get("ok", false)) else "删除失败。", not bool(result.get("ok", false)))
	_build_slot_model()
	_selected_slot_id = _first_occupied_slot_id()
	_refresh_slot_list()
	_refresh_details()


func _on_restore_point_selected(_index: int) -> void:
	_refresh_details()


func _preferred_point(slot: Dictionary) -> Dictionary:
	if _mode == Mode.LOAD and _restore_point_selector != null and _restore_point_selector.selected == 1:
		var manual: Dictionary = slot.get("manual", {}) if slot.get("manual", {}) is Dictionary else {}
		if not manual.is_empty():
			return manual
	var automatic: Dictionary = slot.get("auto", {}) if slot.get("auto", {}) is Dictionary else {}
	if not automatic.is_empty():
		return automatic
	return slot.get("manual", {}) if slot.get("manual", {}) is Dictionary else {}


func _first_occupied_slot_id() -> String:
	for slot in _slots:
		if bool(slot.get("occupied", false)):
			return str(slot.get("slot_id", ""))
	return ""


func _show_status(message: String, is_error: bool) -> void:
	_status_label.modulate = FrontendStyles.make_status_color(is_error)
	_status_label.text = message


func _refresh_thumbnail(point: Dictionary) -> void:
	if not str(point.get("thumbnail_error", "")).is_empty():
		_show_thumbnail_placeholder("缩略图损坏或无法读取")
		return
	if point.is_empty() or not bool(point.get("has_thumbnail", false)):
		_show_thumbnail_placeholder("当前恢复点未生成缩略图")
		return
	var archive_id := str(point.get("archive_id", ""))
	var restore_point := str(point.get("restore_point", "auto"))
	var bytes := GameSaveStore.read_thumbnail_bytes(archive_id, restore_point)
	if bytes.is_empty():
		_show_thumbnail_placeholder("当前恢复点未生成缩略图")
		return
	var image := Image.new()
	var load_error := image.load_webp_from_buffer(bytes)
	if load_error != OK or image.is_empty():
		_show_thumbnail_placeholder("缩略图损坏或无法读取")
		return
	_preview_texture.texture = ImageTexture.create_from_image(image)
	_preview_texture.visible = true
	_preview_label.visible = false


func _show_thumbnail_placeholder(message: String) -> void:
	if _preview_texture != null:
		_preview_texture.texture = null
		_preview_texture.visible = false
	if _preview_label != null:
		_preview_label.text = "存档缩略图\n%s" % message
		_preview_label.visible = true
