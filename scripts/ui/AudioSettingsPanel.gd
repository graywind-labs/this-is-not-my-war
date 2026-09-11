extends Control

var _master_slider: HSlider
var _music_slider: HSlider
var _click_slider: HSlider
var _voice_slider: HSlider
var _combat_slider: HSlider
var _work_slider: HSlider
var _ambience_slider: HSlider
var _master_value: Label
var _music_value: Label
var _click_value: Label
var _voice_value: Label
var _combat_value: Label
var _work_value: Label
var _ambience_value: Label
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
	audio_manager.set_music_volume(float(snapshot.get("music", 0.28)), false)
	audio_manager.set_click_volume(float(snapshot.get("click", 0.8)), false)
	audio_manager.set_voice_volume(float(snapshot.get("voice", 0.8)), false)
	audio_manager.set_combat_volume(float(snapshot.get("combat", 0.8)), false)
	audio_manager.set_work_volume(float(snapshot.get("work", 0.8)), false)
	audio_manager.set_ambience_volume(float(snapshot.get("ambience", 0.8)), false)
	if persist:
		audio_manager.save_settings()


func debug_get_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"master": _master_slider.value if _master_slider != null else -1.0,
		"music": _music_slider.value if _music_slider != null else -1.0,
		"click": _click_slider.value if _click_slider != null else -1.0,
		"voice": _voice_slider.value if _voice_slider != null else -1.0,
		"combat": _combat_slider.value if _combat_slider != null else -1.0,
		"work": _work_slider.value if _work_slider != null else -1.0,
		"ambience": _ambience_slider.value if _ambience_slider != null else -1.0,
		"master_text": _master_value.text if _master_value != null else "",
		"music_text": _music_value.text if _music_value != null else "",
		"click_text": _click_value.text if _click_value != null else "",
		"voice_text": _voice_value.text if _voice_value != null else "",
		"combat_text": _combat_value.text if _combat_value != null else "",
		"work_text": _work_value.text if _work_value != null else "",
		"ambience_text": _ambience_value.text if _ambience_value != null else "",
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
	content.add_theme_constant_override("separation", 12)
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
	var click_row := _add_slider_row(content, "点击音效", "click")
	_click_slider = click_row[0] as HSlider
	_click_value = click_row[1] as Label
	var voice_row := _add_slider_row(content, "语气音效", "voice")
	_voice_slider = voice_row[0] as HSlider
	_voice_value = voice_row[1] as Label
	var combat_row := _add_slider_row(content, "战斗音效", "combat")
	_combat_slider = combat_row[0] as HSlider
	_combat_value = combat_row[1] as Label
	var work_row := _add_slider_row(content, "工作音效", "work")
	_work_slider = work_row[0] as HSlider
	_work_value = work_row[1] as Label
	var ambience_row := _add_slider_row(content, "环境音效", "ambience")
	_ambience_slider = ambience_row[0] as HSlider
	_ambience_value = ambience_row[1] as Label

	var hint := Label.new()
	hint.name = "PreviewHint"
	hint.text = "拖动音量后松开鼠标，会播放木质点击声作为操作确认。"
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
		float(snapshot.get("music", 0.28)),
		float(snapshot.get("click", 0.8)),
		float(snapshot.get("voice", 0.8)),
		float(snapshot.get("combat", 0.8)),
		float(snapshot.get("work", 0.8)),
		float(snapshot.get("ambience", 0.8))
	)


func _on_volumes_changed(master: float, music: float, click: float, voice: float, combat: float, work: float, ambience: float) -> void:
	if _master_slider == null:
		return
	_syncing = true
	_master_slider.value = master
	_music_slider.value = music
	_click_slider.value = click
	_voice_slider.value = voice
	_combat_slider.value = combat
	_work_slider.value = work
	_ambience_slider.value = ambience
	_master_value.text = "%d%%" % roundi(master * 100.0)
	_music_value.text = "%d%%" % roundi(music * 100.0)
	_click_value.text = "%d%%" % roundi(click * 100.0)
	_voice_value.text = "%d%%" % roundi(voice * 100.0)
	_combat_value.text = "%d%%" % roundi(combat * 100.0)
	_work_value.text = "%d%%" % roundi(work * 100.0)
	_ambience_value.text = "%d%%" % roundi(ambience * 100.0)
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
		"click": audio_manager.set_click_volume(value, false)
		"voice": audio_manager.set_voice_volume(value, false)
		"combat": audio_manager.set_combat_volume(value, false)
		"work": audio_manager.set_work_volume(value, false)
		"ambience": audio_manager.set_ambience_volume(value, false)


func _on_slider_drag_ended(_value_changed: bool, _kind: String) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		return
	audio_manager.save_settings()
	audio_manager.preview_sfx_volume()
