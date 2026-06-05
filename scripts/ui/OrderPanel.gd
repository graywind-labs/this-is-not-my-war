extends Control

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"

var _current_npc_id := ""

@onready var title_label: Label = %OrderTitleLabel
@onready var metadata_label: Label = %OrderMetadataLabel
@onready var status_label: Label = %OrderStatusLabel
@onready var text_edit: TextEdit = %OrderTextEdit
@onready var publish_button: Button = %OrderPublishButton
@onready var close_button: Button = %OrderCloseButton


func _ready() -> void:
	visible = false
	publish_button.pressed.connect(_on_publish_pressed)
	close_button.pressed.connect(_on_close_pressed)


func show_order(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return _failure("npc_system_missing", "NPC 系统不可用。")

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("unknown_npc", "NPC 不存在。")
	if not bool(npc.get("recruited", false)):
		return _failure("npc_not_recruited", "未入伍 NPC 不能接收个人指令。")

	_current_npc_id = npc_id
	title_label.text = "给 %s 的当前指令" % str(npc.get("name", npc_id))
	_refresh_from_current_order()
	status_label.text = "指令只会进入后续计划与判断，不会直接改变当前行动。"
	visible = true
	text_edit.grab_focus()
	return {"ok": true, "npc_id": npc_id}


func _refresh_from_current_order() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty():
		return
	var order: Dictionary = npc_system.get_current_order(_current_npc_id)
	text_edit.text = str(order.get("text", ""))
	metadata_label.text = _format_metadata(order)


func _format_metadata(order: Dictionary) -> String:
	var revision := int(order.get("revision", 0))
	if revision <= 0:
		return "尚未发布指令"
	return "修订 %d · 第 %d 天 %s" % [
		revision,
		int(order.get("issued_day", 0)),
		str(order.get("issued_time", ""))
	]


func _on_publish_pressed() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or _current_npc_id.is_empty():
		status_label.text = "NPC 系统不可用。"
		return

	var result: Dictionary = npc_system.publish_npc_order(_current_npc_id, text_edit.text)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "发布失败。"))
		return
	var current_order: Dictionary = result.get("current_order", {})
	text_edit.text = str(current_order.get("text", ""))
	metadata_label.text = _format_metadata(current_order)
	status_label.text = "已发布，并请求计划重评估。" if bool(result.get("changed", false)) else "内容未变化，未发布。"
	text_edit.grab_focus()


func _on_close_pressed() -> void:
	visible = false
	_current_npc_id = ""


func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}
