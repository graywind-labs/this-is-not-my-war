extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"

var _current_npc_id := ""
var _drag_controller

@onready var title_label: Label = %OrderTitleLabel
@onready var metadata_label: Label = %OrderMetadataLabel
@onready var status_label: Label = %OrderStatusLabel
@onready var text_edit: TextEdit = %OrderTextEdit
@onready var publish_button: Button = %OrderPublishButton
@onready var close_button: Button = %OrderCloseButton


func _ready() -> void:
	visible = false
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, title_label)
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

	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("get_dialogue_state"):
		var dialogue_state: Dictionary = dialog_system.get_dialogue_state()
		if not dialogue_state.is_empty() and str(dialogue_state.get("dialogue_kind", "")) in ["player_npc", "escape_intervention"]:
			return _failure("player_dialogue_active", "请先完成或取消当前守备官对话。")
		if dialog_system.has_method("is_dialogue_active") and bool(dialog_system.is_dialogue_active()):
			dialog_system.end_dialogue("order_panel_opened")

	_current_npc_id = npc_id
	title_label.text = "给 %s 的指令" % str(npc.get("name", npc_id))
	_refresh_from_current_order()
	status_label.text = "驿站成员将尽量遵循守备官的指令行动。"
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
