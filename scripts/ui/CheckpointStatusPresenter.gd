extends Control

const DISPLAY_SECONDS := 3.5

var _label: Label
var _remaining := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-390.0, 20.0)
	size = Vector2(370.0, 44.0)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)
	visible = false
	var save_system := get_node_or_null("/root/Main/Systems/GameSaveSystem")
	if save_system != null:
		save_system.checkpoint_completed.connect(_on_checkpoint_completed)
		save_system.restore_completed.connect(_on_restore_completed)


func _process(delta: float) -> void:
	if not visible:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		visible = false


func _on_checkpoint_completed(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		var meta: Dictionary = result.get("meta", {}) if result.get("meta", {}) is Dictionary else {}
		_show("已保存：%s" % str(meta.get("display_name", "稳定检查点")))
	else:
		_show("检查点保存失败：%s" % str(result.get("reason", "未知错误")))


func _on_restore_completed(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_show("检查点已恢复")
	else:
		_show("检查点恢复失败：%s" % str(result.get("reason", "未知错误")))


func _show(text: String) -> void:
	_label.text = text
	_remaining = DISPLAY_SECONDS
	visible = true
