extends Control

const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const ORDER_PANEL_PATH := "/root/Main/UI/OrderPanel"

@onready var npc_name_label: Label = %DialogNPCNameLabel
@onready var status_label: Label = %DialogStatusLabel
@onready var round_label: Label = %DialogRoundLabel
@onready var history_text: RichTextLabel = %DialogHistoryText
@onready var input_edit: LineEdit = %DialogInputEdit
@onready var send_button: Button = %DialogSendButton
@onready var end_button: Button = %DialogEndButton
@onready var public_toggle: CheckButton = %DialogPublicToggle
@onready var recruitment_toggle: CheckButton = %DialogRecruitmentToggle
@onready var attack_button: Button = %DialogAttackButton


func _ready() -> void:
	visible = false
	send_button.pressed.connect(_on_send_pressed)
	end_button.pressed.connect(_on_end_pressed)
	input_edit.text_submitted.connect(_on_text_submitted)
	public_toggle.toggled.connect(_on_public_toggled)
	recruitment_toggle.toggled.connect(_on_recruitment_toggled)
	attack_button.pressed.connect(_on_attack_pressed)
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null:
		dialog_system.dialogue_started.connect(_on_dialogue_started)
		dialog_system.dialogue_updated.connect(_on_dialogue_updated)
		dialog_system.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_started(state: Dictionary) -> void:
	var order_panel := get_node_or_null(ORDER_PANEL_PATH)
	if order_panel != null:
		order_panel.visible = false
	visible = true
	_refresh(state)
	input_edit.grab_focus()


func _on_dialogue_updated(state: Dictionary) -> void:
	_refresh(state)


func _on_dialogue_ended(_state: Dictionary) -> void:
	visible = false
	input_edit.clear()


func _on_send_pressed() -> void:
	_send_current_text()


func _on_text_submitted(_text: String) -> void:
	_send_current_text()


func _send_current_text() -> void:
	var text := input_edit.text.strip_edges()
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		status_label.text = "对话系统不可用。"
		return
	var state: Dictionary = dialog_system.get_dialogue_state()
	if bool(state.get("waiting", false)):
		status_label.text = "正在等待 NPC 回复。"
		return
	if text.is_empty():
		status_label.text = "请输入内容。"
		return
	input_edit.clear()
	var result: Dictionary = dialog_system.send_npc_message(text) if str(state.get("dialogue_kind", "player_npc")) == "npc_npc" else dialog_system.send_player_message(text, false, true)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "发送失败。"))
	input_edit.grab_focus()


func _on_end_pressed() -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null:
		dialog_system.end_dialogue()


func _on_public_toggled(enabled: bool) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		return
	var result: Dictionary = dialog_system.set_dialogue_visibility("local_public" if enabled else "private")
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "无法修改对话公开性。"))


func _on_recruitment_toggled(enabled: bool) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		status_label.text = "对话系统不可用。"
		return
	var result: Dictionary = dialog_system.set_recruitment_request_pending(enabled)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "无法提出应征。"))
		recruitment_toggle.set_pressed_no_signal(not enabled)


func _on_attack_pressed() -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		status_label.text = "对话系统不可用。"
		return
	var result: Dictionary = dialog_system.attack_target_npc(10, true)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "攻击失败。"))
	input_edit.grab_focus()


func _refresh(state: Dictionary) -> void:
	npc_name_label.text = "与 %s 对话" % str(state.get("target_npc_name", "NPC"))
	round_label.text = "轮次：不限" if str(state.get("dialogue_kind", "player_npc")) == "player_npc" else "轮次：%d / %d" % [int(state.get("current_round", 0)), int(state.get("max_rounds", 5))]
	var waiting := bool(state.get("waiting", false))
	var force_public := bool(state.get("force_local_public", false))
	public_toggle.set_pressed_no_signal(str(state.get("visibility", "private")) == "local_public")
	public_toggle.disabled = force_public or waiting or int(state.get("current_round", 0)) > 0
	send_button.disabled = waiting
	input_edit.editable = true
	var is_player_dialogue := str(state.get("dialogue_kind", "player_npc")) == "player_npc"
	var recruitment_pending := bool(state.get("recruitment_request_pending", false))
	recruitment_toggle.visible = is_player_dialogue
	recruitment_toggle.set_pressed_no_signal(recruitment_pending)
	recruitment_toggle.disabled = waiting or bool(state.get("target_recruited", false))
	recruitment_toggle.text = "提出应征"
	attack_button.visible = is_player_dialogue
	attack_button.disabled = waiting
	var last_error := str(state.get("last_error", ""))
	var recruitment_result := str(state.get("last_recruitment_result", "none"))
	var recruitment_status := "NPC 已接受应征。" if recruitment_result == "accept" else "NPC 拒绝了应征。" if recruitment_result == "reject" else ""
	status_label.text = last_error if not last_error.is_empty() else ("等待回复……" if waiting else "下次发送将提出应征。" if recruitment_pending else recruitment_status if not recruitment_status.is_empty() else "战时同地点公开对话" if force_public else "私人对话" if str(state.get("visibility", "private")) == "private" else "同地点公开对话")
	var lines: Array[String] = []
	for raw_turn in state.get("history", []):
		if not raw_turn is Dictionary:
			continue
		var turn: Dictionary = raw_turn
		lines.append("[b]%s[/b]：%s" % [str(turn.get("speaker_name", "")), str(turn.get("text", ""))])
	history_text.text = "\n\n".join(lines)
	history_text.scroll_to_line(maxi(0, lines.size() - 1))
