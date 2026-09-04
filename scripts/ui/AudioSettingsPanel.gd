extends Control

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _ambience_slider: HSlider
var _ui_slider: HSlider
var _master_value: Label
var _music_value: Label
var _sfx_value: Label
var _ambience_value: Label
var _ui_value: Label
var _syncing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_content()
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_signal("volumes_changed"):
		audio_manager.volumes_changed.connect(_on_volumes_changed)
	_sync_from_manager()


func open_panel() -> void:
	_sync_from_manager()
	visible = true


func close_panel() -> void:
	visible = false


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func sync_from_manager() -> void:
	_sync_from_manager()


func set_audio_values(snapshot: Dictionary, persist := false) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		return
	audio_manager.set_master_volume(float(snapshot.get("master", 0.8)), false)
	audio_manager.set_music_volume(float(snapshot.get("music", 0.56)), false)
	audio_manager.set_sfx_volume(float(snapshot.get("sfx", 0.8)), false)
	audio_manager.set_ambience_volume(float(snapshot.get("ambience", 0.8)), false)
	audio_manager.set_ui_volume(float(snapshot.get("ui", 0.8)), false)
	if persist:
		audio_manager.save_settings()


func debug_get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"master": _master_slider.value if _master_slider != null else -1.0,
		"music": _music_slider.value if _music_slider != null else -1.0,
		"sfx": _sfx_slider.value if _sfx_slider != null else -1.0,
		"ambience": _ambience_slider.value if _ambience_slider != null else -1.0,
		"ui": _ui_slider.value if _ui_slider != null else -1.0,
		"master_text": _master_value.text if _master_value != null else "",
		"music_text": _music_value.text if _music_value != null else "",
		"sfx_text": _sfx_value.text if _sfx_value != null else "",
		"ambience_text": _ambience_value.text if _ambience_value != null else "",
		"ui_text": _ui_value.text if _ui_value != null else ""
	}


func debug_finish_slider_drag(kind: String) -> void:
	_on_slider_drag_ended(false, kind)


func _build_content() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var content := VBoxContainer.new()
	content.name = "AudioContent"
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = "声音与音乐"
	heading.add_theme_font_size_override("font_size", 21)
	content.add_child(heading)

	var master_row := _add_slider_row(content, "主音量", "master")
	_master_slider = master_row[0] as HSlider
	_master_value = master_row[1] as Label
	var music_row := _add_slider_row(content, "音乐", "music")
	_music_slider = music_row[0] as HSlider
	_music_value = music_row[1] as Label
	var sfx_row := _add_slider_row(content, "音效", "sfx")
	_sfx_slider = sfx_row[0] as HSlider
	_sfx_value = sfx_row[1] as Label
	var ambience_row := _add_slider_row(content, "环境音效", "ambience")
	_ambience_slider = ambience_row[0] as HSlider
	_ambience_value = ambience_row[1] as Label
	var ui_row := _add_slider_row(content, "点击音效", "ui")
	_ui_slider = ui_row[0] as HSlider
	_ui_value = ui_row[1] as Label

	var hint := Label.new()
	hint.text = "拖动音量后松开鼠标，会播放木质点击声作为试听。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.78, 0.75, 0.68, 1.0)
	content.add_child(hint)


func _add_slider_row(parent: VBoxContainer, label_text: String, kind: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var label := Label.new()
	label.custom_minimum_size = Vector2(100.0, 0.0)
	label.text = label_text
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "%sSlider" % kind.capitalize()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(_on_slider_value_changed.bind(kind))
	slider.drag_ended.connect(_on_slider_drag_ended.bind(kind))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return [slider, value_label]


func _sync_from_manager() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null or _master_slider == null:
		return
	var snapshot: Dictionary = audio_manager.get_volume_snapshot()
	_on_volumes_changed(
		float(snapshot.get("master", 0.8)),
		float(snapshot.get("music", 0.56)),
		float(snapshot.get("sfx", 0.8)),
		float(snapshot.get("ambience", 0.8)),
		float(snapshot.get("ui", 0.8))
	)


func _on_volumes_changed(master: float, music: float, sfx: float, ambience: float, ui: float) -> void:
	if _master_slider == null:
		return
	_syncing = true
	_master_slider.value = master
	_music_slider.value = music
	_sfx_slider.value = sfx
	_ambience_slider.value = ambience
	_ui_slider.value = ui
	_master_value.text = "%d%%" % roundi(master * 100.0)
	_music_value.text = "%d%%" % roundi(music * 100.0)
	_sfx_value.text = "%d%%" % roundi(sfx * 100.0)
	_ambience_value.text = "%d%%" % roundi(ambience * 100.0)
	_ui_value.text = "%d%%" % roundi(ui * 100.0)
	_syncing = false


func _on_slider_value_changed(value: float, kind: String) -> void:
	if _syncing:
		return
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		return
	match kind:
		"master": audio_manager.set_master_volume(value, false)
		"music": audio_manager.set_music_volume(value, false)
		"sfx": audio_manager.set_sfx_volume(value, false)
		"ambience": audio_manager.set_ambience_volume(value, false)
		"ui": audio_manager.set_ui_volume(value, false)


func _on_slider_drag_ended(_value_changed: bool, _kind: String) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		return
	audio_manager.save_settings()
	audio_manager.preview_sfx_volume()
