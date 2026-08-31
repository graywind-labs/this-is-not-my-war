extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const ORDER_PANEL_PATH := "/root/Main/UI/OrderPanel"
const EVENT_BUS_PATH := "/root/EventBus"
const RECRUITMENT_ACCEPT_COLOR := "#63D471"
const RECRUITMENT_REJECT_COLOR := "#FF6B6B"

@onready var npc_name_label: Label = %DialogNPCNameLabel
@onready var status_label: Label = %DialogStatusLabel
@onready var round_label: Label = %DialogRoundLabel
@onready var history_text: RichTextLabel = %DialogHistoryText
@onready var input_edit: LineEdit = %DialogInputEdit
@onready var send_button: Button = %DialogSendButton
@onready var end_button: Button = %DialogEndButton
@onready var cancel_button: Button = %DialogCancelButton
@onready var suspend_button: Button = %DialogSuspendButton
@onready var public_toggle: CheckButton = %DialogPublicToggle
@onready var recruitment_toggle: CheckButton = %DialogRecruitmentToggle
@onready var attack_button: Button = %DialogAttackButton
@onready var attack_confirmation_dialog: ConfirmationDialog = %DialogAttackConfirmationDialog


func _ready() -> void:
	visible = false
	send_button.pressed.connect(_on_send_pressed)
	end_button.pressed.connect(_on_end_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	suspend_button.pressed.connect(_on_suspend_pressed)
	input_edit.text_submitted.connect(_on_text_submitted)
	public_toggle.toggled.connect(_on_public_toggled)
	recruitment_toggle.toggled.connect(_on_recruitment_toggled)
	attack_button.pressed.connect(_on_attack_pressed)
	attack_confirmation_dialog.confirmed.connect(_on_attack_confirmation_confirmed)
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null:
		dialog_system.dialogue_started.connect(_on_dialogue_started)
		dialog_system.dialogue_updated.connect(_on_dialogue_updated)
		dialog_system.dialogue_ended.connect(_on_dialogue_ended)
	var event_bus := get_node_or_null(EVENT_BUS_PATH)
	if event_bus != null and event_bus.has_signal("npc_dialogue_bubble_clicked"):
		event_bus.npc_dialogue_bubble_clicked.connect(_on_npc_dialogue_bubble_clicked)
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, get_node("PanelContainer/MarginContainer/Content/Header") as Control)


var _displayed_dialogue_id := ""
var _displayed_dialogue_state: Dictionary = {}
var _observer_mode := false
var _observer_dialogue_ended := false
var _drag_controller
var _attack_confirmed_for_current_open := false


func _input(event: InputEvent) -> void:
	if not _is_recruitment_shortcut(event):
		return
	recruitment_toggle.button_pressed = not recruitment_toggle.button_pressed
	get_viewport().set_input_as_handled()


func _on_dialogue_started(state: Dictionary) -> void:
	if not bool(state.get("ui_visible", true)):
		return
	_reset_attack_confirmation_for_open()
	_observer_mode = false
	_observer_dialogue_ended = false
	_displayed_dialogue_id = str(state.get("dialogue_id", ""))
	_displayed_dialogue_state = state.duplicate(true)
	var order_panel := get_node_or_null(ORDER_PANEL_PATH)
	if order_panel != null:
		order_panel.visible = false
	visible = true
	_refresh(state)
	input_edit.grab_focus()


func _on_dialogue_updated(state: Dictionary) -> void:
	var dialogue_id := str(state.get("dialogue_id", ""))
	if _observer_mode:
		if dialogue_id != _displayed_dialogue_id:
			return
		_displayed_dialogue_state = state.duplicate(true)
		_refresh(state)
		return
	if not bool(state.get("ui_visible", true)):
		if dialogue_id == _displayed_dialogue_id:
			visible = false
			_reset_attack_confirmation_for_open()
		return
	if not _displayed_dialogue_id.is_empty() and dialogue_id != _displayed_dialogue_id:
		return
	_displayed_dialogue_id = dialogue_id
	_displayed_dialogue_state = state.duplicate(true)
	if not visible:
		_reset_attack_confirmation_for_open()
	visible = true
	_refresh(state)


func _on_dialogue_ended(state: Dictionary) -> void:
	if _observer_mode:
		if str(state.get("dialogue_id", "")) != _displayed_dialogue_id:
			return
		_observer_dialogue_ended = true
		_displayed_dialogue_state = state.duplicate(true)
		_refresh(state)
		return
	if not _displayed_dialogue_id.is_empty() and str(state.get("dialogue_id", "")) != _displayed_dialogue_id:
		return
	_reset_attack_confirmation_for_open()
	visible = false
	input_edit.clear()
	_displayed_dialogue_id = ""
	_displayed_dialogue_state.clear()
	_observer_mode = false
	_observer_dialogue_ended = false


func _on_npc_dialogue_bubble_clicked(npc_id: String, dialogue_id: String) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		return
	if dialog_system.has_method("resume_suspended_player_dialogue"):
		var resume_result: Dictionary = dialog_system.resume_suspended_player_dialogue(npc_id, dialogue_id)
		if bool(resume_result.get("ok", false)) and bool(resume_result.get("resumed", false)):
			return
	if not dialog_system.has_method("get_autonomous_dialogue_observer_state"):
		return
	var state: Dictionary = dialog_system.get_autonomous_dialogue_observer_state(npc_id, dialogue_id)
	if state.is_empty():
		return
	_observer_mode = true
	_observer_dialogue_ended = false
	_reset_attack_confirmation_for_open()
	_displayed_dialogue_id = dialogue_id
	_displayed_dialogue_state = state.duplicate(true)
	var order_panel := get_node_or_null(ORDER_PANEL_PATH)
	if order_panel != null:
		order_panel.visible = false
	visible = true
	_refresh(state)


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
	var state: Dictionary = dialog_system.get_display_dialogue_state() if dialog_system.has_method("get_display_dialogue_state") else dialog_system.get_dialogue_state()
	if bool(state.get("waiting", false)):
		status_label.text = "正在等待 NPC 回复。"
		return
	if text.is_empty():
		status_label.text = "请输入内容。"
		return
	input_edit.clear()
	var result: Dictionary = dialog_system.send_npc_message(text, true) if str(state.get("dialogue_kind", "player_npc")) == "npc_npc" else dialog_system.send_player_message(text, false, true)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "发送失败。"))
	input_edit.grab_focus()


func _on_end_pressed() -> void:
	if _observer_mode:
		_reset_attack_confirmation_for_open()
		visible = false
		input_edit.clear()
		_displayed_dialogue_id = ""
		_displayed_dialogue_state.clear()
		_observer_mode = false
		_observer_dialogue_ended = false
		return
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null:
		if dialog_system.has_method("complete_displayed_dialogue"):
			dialog_system.complete_displayed_dialogue(_displayed_dialogue_id)
		elif dialog_system.has_method("end_displayed_dialogue"):
			dialog_system.end_displayed_dialogue(_displayed_dialogue_id)
		else:
			dialog_system.end_dialogue()


func _on_cancel_pressed() -> void:
	if _observer_mode:
		return
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("cancel_displayed_dialogue"):
		status_label.text = "对话系统不支持取消会话。"
		return
	var result: Dictionary = dialog_system.cancel_displayed_dialogue(_displayed_dialogue_id)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "无法取消会话。"))


func _on_suspend_pressed() -> void:
	if _observer_mode:
		return
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("suspend_displayed_dialogue"):
		status_label.text = "对话系统不支持挂起会话。"
		return
	var result: Dictionary = dialog_system.suspend_displayed_dialogue(_displayed_dialogue_id)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "无法挂起会话。"))
	else:
		_reset_attack_confirmation_for_open()


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
	if not _attack_confirmed_for_current_open:
		attack_confirmation_dialog.popup_centered()
		return
	_commit_attack()


func _on_attack_confirmation_confirmed() -> void:
	if _commit_attack():
		_attack_confirmed_for_current_open = true


func _commit_attack() -> bool:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		status_label.text = "对话系统不可用。"
		return false
	var result: Dictionary = dialog_system.attack_target_npc(10, true)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "攻击失败。"))
	input_edit.grab_focus()
	return bool(result.get("ok", false))


func _reset_attack_confirmation_for_open() -> void:
	_attack_confirmed_for_current_open = false
	if attack_confirmation_dialog != null:
		attack_confirmation_dialog.hide()


func _is_recruitment_shortcut(event: InputEvent) -> bool:
	if (
		not visible
		or _observer_mode
		or not recruitment_toggle.visible
		or recruitment_toggle.disabled
		or attack_confirmation_dialog.visible
		or not (event is InputEventKey)
	):
		return false
	var key_event := event as InputEventKey
	if (
		not key_event.pressed
		or key_event.echo
		or key_event.ctrl_pressed
		or key_event.alt_pressed
		or key_event.meta_pressed
		or key_event.shift_pressed
	):
		return false
	var shortcut_key := key_event.physical_keycode
	if shortcut_key == KEY_NONE:
		shortcut_key = key_event.keycode
	return shortcut_key == KEY_TAB


func _refresh(state: Dictionary) -> void:
	var dialogue_kind := str(state.get("dialogue_kind", "player_npc"))
	if _observer_mode:
		var participant_names: Dictionary = state.get("participant_names", {}) if state.get("participant_names", {}) is Dictionary else {}
		var participant_ids: Array = state.get("participant_npc_ids", [])
		var display_names: Array[String] = []
		for raw_participant_id in participant_ids:
			var participant_id := str(raw_participant_id)
			display_names.append(str(participant_names.get(participant_id, participant_id)))
		if display_names.size() < 2:
			display_names = [str(state.get("speaker_name", "NPC")), str(state.get("target_npc_name", "NPC"))]
		npc_name_label.text = "旁听：%s 与 %s" % [display_names[0], display_names[1]]
	else:
		npc_name_label.text = "与 %s 对话" % str(state.get("target_npc_name", "NPC"))
	var default_max_rounds := 5
	if dialogue_kind == "player_npc":
		round_label.text = "轮次：不限"
	elif dialogue_kind == "npc_npc":
		var soft_round_threshold := int(state.get("soft_round_threshold", 5))
		round_label.text = "轮次：%d（无硬上限；第 %d 轮起建议收尾）" % [
			int(state.get("current_round", 0)),
			soft_round_threshold + 1
		]
	else:
		round_label.text = "轮次：%d / %d" % [int(state.get("current_round", 0)), int(state.get("max_rounds", default_max_rounds))]
	var waiting := bool(state.get("waiting", false))
	var force_public := bool(state.get("force_local_public", false))
	var round_limit_reached := dialogue_kind == "escape_intervention" and int(state.get("current_round", 0)) >= int(state.get("max_rounds", 5))
	public_toggle.visible = not _observer_mode
	public_toggle.set_pressed_no_signal(str(state.get("visibility", "private")) == "local_public")
	public_toggle.disabled = _observer_mode or force_public or waiting or int(state.get("current_round", 0)) > 0
	input_edit.visible = not _observer_mode
	send_button.visible = not _observer_mode
	send_button.disabled = _observer_mode or waiting or round_limit_reached
	input_edit.editable = not _observer_mode and not round_limit_reached
	var is_player_dialogue := dialogue_kind == "player_npc"
	var is_player_controlled_dialogue := ["player_npc", "escape_intervention"].has(dialogue_kind)
	var recruitment_pending := bool(state.get("recruitment_request_pending", false))
	recruitment_toggle.visible = is_player_dialogue and not _observer_mode
	recruitment_toggle.set_pressed_no_signal(recruitment_pending)
	recruitment_toggle.disabled = waiting or bool(state.get("target_recruited", false)) or str(state.get("last_recruitment_result", "none")) == "accept"
	recruitment_toggle.text = "提出应征"
	recruitment_toggle.tooltip_text = "快捷键：Tab"
	attack_button.visible = is_player_controlled_dialogue and not _observer_mode
	attack_button.disabled = waiting or round_limit_reached
	end_button.text = "关闭" if _observer_mode else "完成对话"
	end_button.tooltip_text = "只关闭旁听窗口，不会打断 NPC 的自主对话。" if _observer_mode else "保存本次会话；若正在等待回复，将放弃回复并以守备官最后一句话结束。"
	cancel_button.visible = is_player_controlled_dialogue and not _observer_mode
	var npc_initiated_proactive_talk := (
		is_player_dialogue
		and str(state.get("dialogue_initiator", "")) == "npc"
		and bool(state.get("proactive_talk", false))
	)
	var recruitment_request_sent := bool(state.get("session_had_recruitment_request", false))
	cancel_button.disabled = (
		npc_initiated_proactive_talk
		or bool(state.get("attack_committed", false))
		or recruitment_request_sent
	)
	cancel_button.tooltip_text = (
		"驿站成员主动交涉不可取消对话。"
		if npc_initiated_proactive_talk
		else (
			"本次会话发生过攻击，伤害事实不可撤销，因此不能取消。"
			if bool(state.get("attack_committed", false))
			else (
				"本次会话已经提出应征，只能完成对话。"
				if recruitment_request_sent
				else "丢弃本次会话，不入库，也不触发计划修改判别。"
			)
		)
	)
	suspend_button.visible = is_player_controlled_dialogue and not _observer_mode
	suspend_button.disabled = false
	suspend_button.tooltip_text = "暂时隐藏窗口并保持 NPC 对话状态；最多挂起 2 个游戏小时。"
	var last_error := str(state.get("last_error", ""))
	var recruitment_result := str(state.get("last_recruitment_result", "none"))
	var recruitment_status := "NPC 已接受应征。" if recruitment_result == "accept" else "NPC 拒绝了应征。" if recruitment_result == "reject" else ""
	var escape_result: Dictionary = state.get("last_escape_intervention_result", {}) if state.get("last_escape_intervention_result", {}) is Dictionary else {}
	var escape_decision := str(escape_result.get("decision", ""))
	var escape_status := "NPC 已停下，准备回到工作安排。" if escape_decision == "stay" else "NPC 仍在继续逃离。" if escape_decision == "continue" else "逃离挽留：剩余 %d 轮。" % maxi(0, int(state.get("max_rounds", 5)) - int(state.get("current_round", 0)))
	if _observer_mode:
		status_label.text = ("本轮自主对话已结束。" if last_error.is_empty() else "对话已结束：%s" % last_error) if _observer_dialogue_ended else ("等待第 %d 轮 LLM 回复……" % (int(state.get("current_round", 0)) + 1) if waiting else "旁听中 · %s" % ("公开" if str(state.get("visibility", "local_public")) == "local_public" else "私下"))
	else:
		status_label.text = last_error if not last_error.is_empty() else ("守备官消息已发送，正在等待回复……" if waiting else "逃离挽留轮次已用完。" if round_limit_reached else escape_status if dialogue_kind == "escape_intervention" else "下次发送将提出应征。" if recruitment_pending else recruitment_status if not recruitment_status.is_empty() else "战时公开对话" if force_public else "私下对话" if str(state.get("visibility", "private")) == "private" else "公开对话")
	var lines: Array[String] = []
	for raw_turn in state.get("history", []):
		if not raw_turn is Dictionary:
			continue
		var turn: Dictionary = raw_turn
		var turn_lines: Array[String] = [
			"[b]%s[/b]：%s" % [str(turn.get("speaker_name", "")), str(turn.get("text", ""))]
		]
		var turn_recruitment_result := str(turn.get("recruitment_result", "none"))
		var turn_speaker_name := str(turn.get("speaker_name", "NPC"))
		if turn_recruitment_result == "accept":
			turn_lines.append(
				"[color=%s]✓ %s接受了守备官的应征请求[/color]"
				% [RECRUITMENT_ACCEPT_COLOR, turn_speaker_name]
			)
		elif turn_recruitment_result == "reject":
			turn_lines.append(
				"[color=%s]× %s拒绝了守备官的应征请求[/color]"
				% [RECRUITMENT_REJECT_COLOR, turn_speaker_name]
			)
		if str(turn.get("wartime_reaction", "none")) == "morale_boost":
			turn_lines.append(
				"[color=%s]↑ %s受到了激励，进入斗志激昂状态[/color]"
				% [RECRUITMENT_ACCEPT_COLOR, turn_speaker_name]
			)
		lines.append("\n".join(turn_lines))
	if _observer_mode and waiting:
		var pending: Dictionary = state.get("pending_llm", {}) if state.get("pending_llm", {}) is Dictionary else {}
		if not pending.is_empty() and not bool(pending.get("speaker_text_already_recorded", false)):
			lines.append("[b]%s[/b]：%s" % [str(pending.get("speaker_name", "")), str(pending.get("clean_text", ""))])
	history_text.text = "\n\n".join(lines)
	history_text.scroll_to_line(maxi(0, history_text.get_line_count() - 1))
