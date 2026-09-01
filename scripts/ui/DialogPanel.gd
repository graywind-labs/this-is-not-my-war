extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const ORDER_PANEL_PATH := "/root/Main/UI/OrderPanel"
const NPC_PANEL_PATH := "/root/Main/UI/NPCPanel"
const EVENT_BUS_PATH := "/root/EventBus"
const RECRUITMENT_ACCEPT_COLOR := "#63D471"
const RECRUITMENT_REJECT_COLOR := "#FF6B6B"
const MORALE_CONTINUE_COLOR := "#D6C7A1"

@onready var npc_name_label: Label = %DialogNPCNameLabel
@onready var status_label: Label = %DialogStatusLabel
@onready var round_label: Label = %DialogRoundLabel
@onready var history_text: RichTextLabel = %DialogHistoryText
@onready var input_edit: LineEdit = %DialogInputEdit
@onready var send_button: Button = %DialogSendButton
@onready var end_button: Button = %DialogEndButton
@onready var cancel_button: Button = %DialogCancelButton
@onready var suspend_button: Button = %DialogSuspendButton
@onready var public_toggle: CheckBox = %DialogPublicToggle
@onready var private_visibility_radio: CheckBox = %DialogPrivateRadio
@onready var history_button: Button = %DialogHistoryButton
@onready var recruitment_toggle: CheckButton = %DialogRecruitmentToggle
@onready var work_encouragement_toggle: CheckButton = %DialogWorkEncouragementToggle
@onready var morale_encouragement_toggle: CheckButton = %DialogMoraleEncouragementToggle
@onready var combat_strategy_toggle: CheckButton = %DialogCombatStrategyToggle
@onready var attack_button: Button = %DialogAttackButton
@onready var attack_confirmation_dialog: ConfirmationDialog = %DialogAttackConfirmationDialog
@onready var special_success_dialog: AcceptDialog = %DialogSpecialSuccessDialog


func _ready() -> void:
	visible = false
	send_button.pressed.connect(_on_send_pressed)
	end_button.pressed.connect(_on_end_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	suspend_button.pressed.connect(_on_suspend_pressed)
	input_edit.text_submitted.connect(_on_text_submitted)
	_dialog_visibility_group = ButtonGroup.new()
	_dialog_visibility_group.allow_unpress = false
	public_toggle.button_group = _dialog_visibility_group
	private_visibility_radio.button_group = _dialog_visibility_group
	_apply_plain_radio_style(public_toggle)
	_apply_plain_radio_style(private_visibility_radio)
	for special_toggle in [
		recruitment_toggle,
		work_encouragement_toggle,
		morale_encouragement_toggle,
		combat_strategy_toggle
	]:
		_apply_plain_toggle_style(special_toggle)
	_apply_stable_input_style(input_edit)
	public_toggle.toggled.connect(_on_public_toggled)
	private_visibility_radio.toggled.connect(_on_private_visibility_toggled)
	history_button.pressed.connect(_on_history_pressed)
	recruitment_toggle.toggled.connect(_on_recruitment_toggled)
	work_encouragement_toggle.toggled.connect(_on_work_encouragement_toggled)
	morale_encouragement_toggle.toggled.connect(_on_morale_encouragement_toggled)
	combat_strategy_toggle.toggled.connect(_on_combat_strategy_toggled)
	attack_button.pressed.connect(_on_attack_pressed)
	attack_confirmation_dialog.confirmed.connect(_on_attack_confirmation_confirmed)
	special_success_dialog.confirmed.connect(_on_special_success_dialog_closed)
	special_success_dialog.close_requested.connect(_on_special_success_dialog_closed)
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null:
		dialog_system.dialogue_started.connect(_on_dialogue_started)
		dialog_system.dialogue_updated.connect(_on_dialogue_updated)
		dialog_system.dialogue_ended.connect(_on_dialogue_ended)
		if dialog_system.has_signal("special_interaction_result"):
			dialog_system.special_interaction_result.connect(_on_special_interaction_result)
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
var _special_success_queue: Array[Dictionary] = []
var _dialog_visibility_group: ButtonGroup


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


func _on_special_interaction_result(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		return
	_special_success_queue.append(result.duplicate(true))
	_show_next_special_success()


func _on_special_success_dialog_closed() -> void:
	call_deferred("_show_next_special_success")


func _show_next_special_success() -> void:
	if special_success_dialog == null or special_success_dialog.visible or _special_success_queue.is_empty():
		return
	var result: Dictionary = _special_success_queue.pop_front()
	var npc_name := str(result.get("npc_name", "NPC"))
	match str(result.get("special_type", "")):
		"recruitment":
			special_success_dialog.dialog_text = "成功说服了%s，%s同意入伍！" % [npc_name, npc_name]
		"morale_encouragement":
			special_success_dialog.dialog_text = "成功说服了%s，%s的士气受到鼓舞！" % [npc_name, npc_name]
		"work_encouragement":
			special_success_dialog.dialog_text = "成功说服了%s，%s的工作效率得到提升！" % [npc_name, npc_name]
		"combat_strategy":
			special_success_dialog.dialog_text = "成功说服了%s，将战斗策略改变为“%s”！" % [npc_name, str(result.get("strategy_label", "新策略"))]
		_:
			special_success_dialog.dialog_text = "成功说服了%s！" % npc_name
	special_success_dialog.popup_centered()


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


func _on_private_visibility_toggled(enabled: bool) -> void:
	if not enabled:
		return
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		return
	var result: Dictionary = dialog_system.set_dialogue_visibility("private")
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "无法修改对话公开性。"))


func _on_history_pressed() -> void:
	var npc_id := str(_displayed_dialogue_state.get("target_npc_id", ""))
	var npc_panel := get_node_or_null(NPC_PANEL_PATH)
	if npc_id.is_empty() or npc_panel == null or not npc_panel.has_method("open_dialogue_history"):
		status_label.text = "当前没有可查看的 NPC 对话记录。"
		return
	var result: Dictionary = npc_panel.open_dialogue_history(npc_id)
	if not bool(result.get("ok", false)):
		status_label.text = "无法打开对话记录。"


func _apply_plain_radio_style(radio: CheckBox) -> void:
	if radio == null:
		return
	radio.focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		radio.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var normal_color := Color(0.94, 0.87, 0.70, 1.0)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		radio.add_theme_color_override(color_name, normal_color)


func _apply_plain_toggle_style(toggle: BaseButton) -> void:
	if toggle == null:
		return
	toggle.focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		toggle.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var normal_color := Color(0.94, 0.87, 0.70, 1.0)
	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_disabled_color"
	]:
		toggle.add_theme_color_override(color_name, normal_color)


func _apply_stable_input_style(line_edit: LineEdit) -> void:
	if line_edit == null:
		return
	var normal_style := line_edit.get_theme_stylebox("normal")
	if normal_style == null:
		return
	var stable_normal := normal_style.duplicate(true) as StyleBox
	line_edit.add_theme_stylebox_override("normal", stable_normal)
	line_edit.add_theme_stylebox_override("focus", stable_normal.duplicate(true) as StyleBox)


func _on_recruitment_toggled(enabled: bool) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null:
		status_label.text = "对话系统不可用。"
		return
	var result: Dictionary = dialog_system.set_recruitment_request_pending(enabled)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "无法提出应征。"))
		recruitment_toggle.set_pressed_no_signal(not enabled)


func _on_morale_encouragement_toggled(enabled: bool) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("set_morale_encouragement_request_pending"):
		status_label.text = "对话系统不支持鼓舞士气。"
		morale_encouragement_toggle.set_pressed_no_signal(false)
		return
	var result: Dictionary = dialog_system.set_morale_encouragement_request_pending(enabled)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "当前不能鼓舞士气。"))
		morale_encouragement_toggle.set_pressed_no_signal(not enabled)


func _on_work_encouragement_toggled(enabled: bool) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("set_work_encouragement_request_pending"):
		status_label.text = "对话系统不支持鼓励工作。"
		work_encouragement_toggle.set_pressed_no_signal(false)
		return
	var result: Dictionary = dialog_system.set_work_encouragement_request_pending(enabled)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "当前不能鼓励工作。"))
		work_encouragement_toggle.set_pressed_no_signal(not enabled)


func _on_combat_strategy_toggled(enabled: bool) -> void:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("set_combat_strategy_request_pending"):
		status_label.text = "对话系统不支持调整战斗策略。"
		combat_strategy_toggle.set_pressed_no_signal(false)
		return
	var result: Dictionary = dialog_system.set_combat_strategy_request_pending(enabled)
	if not bool(result.get("ok", false)):
		status_label.text = str(result.get("message", "当前不能调整战斗策略。"))
		combat_strategy_toggle.set_pressed_no_signal(not enabled)


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
	var has_explicit_round_limit := dialogue_kind == "escape_intervention"
	round_label.visible = has_explicit_round_limit
	round_label.text = (
		"挽留轮次：%d / %d"
		% [int(state.get("current_round", 0)), int(state.get("max_rounds", 5))]
		if has_explicit_round_limit
		else ""
	)
	var waiting := bool(state.get("waiting", false))
	var force_public := bool(state.get("force_local_public", false))
	var round_limit_reached := dialogue_kind == "escape_intervention" and int(state.get("current_round", 0)) >= int(state.get("max_rounds", 5))
	public_toggle.visible = true
	public_toggle.set_pressed_no_signal(str(state.get("visibility", "private")) == "local_public")
	private_visibility_radio.visible = true
	private_visibility_radio.set_pressed_no_signal(str(state.get("visibility", "private")) == "private")
	var visibility_locked := _observer_mode or force_public or waiting or int(state.get("current_round", 0)) > 0
	public_toggle.disabled = visibility_locked
	private_visibility_radio.disabled = visibility_locked
	history_button.visible = not _observer_mode
	history_button.disabled = str(state.get("target_npc_id", "")).is_empty()
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
	recruitment_toggle.modulate = Color(1.0, 1.0, 1.0, 1.0 if not recruitment_toggle.disabled else 0.45)
	recruitment_toggle.text = "提出应征"
	recruitment_toggle.tooltip_text = "快捷键：Tab。只有明确谈到应征、入伍或加入防线时才判定；无关话题按普通对话处理。"
	var work_eligible := bool(state.get("work_encouragement_eligible", false))
	var work_pending := bool(state.get("work_encouragement_request_pending", false)) and work_eligible
	work_encouragement_toggle.visible = is_player_dialogue and not _observer_mode
	work_encouragement_toggle.set_pressed_no_signal(work_pending)
	work_encouragement_toggle.disabled = waiting or not work_eligible
	work_encouragement_toggle.modulate = Color(1.0, 1.0, 1.0, 1.0 if work_eligible else 0.45)
	work_encouragement_toggle.text = "鼓励工作"
	work_encouragement_toggle.tooltip_text = (
		"勾选后判断工作效率提升、无事发生或逃离驿站；增益为全部工作产出效率+20%，持续至当天24:00。无关话题按普通对话处理。"
		if work_eligible
		else str(state.get("work_encouragement_ineligible_reason", "当前场景不能鼓励工作。"))
	)
	var morale_eligible := bool(state.get("morale_encouragement_eligible", false))
	var morale_pending := bool(state.get("morale_encouragement_request_pending", false)) and morale_eligible
	morale_encouragement_toggle.visible = is_player_dialogue and not _observer_mode
	morale_encouragement_toggle.set_pressed_no_signal(morale_pending)
	morale_encouragement_toggle.disabled = waiting or not morale_eligible
	morale_encouragement_toggle.modulate = Color(1.0, 1.0, 1.0, 1.0 if morale_eligible else 0.45)
	morale_encouragement_toggle.text = "鼓舞士气"
	morale_encouragement_toggle.tooltip_text = (
		"勾选后让后续回复判断鼓舞、逃离或继续参战，直到手动关闭或鼓舞成功；无关话题不会获得增益。"
		if morale_eligible
		else str(state.get("morale_encouragement_ineligible_reason", "当前场景不能鼓舞士气。"))
	)
	var strategy_eligible := bool(state.get("combat_strategy_request_eligible", false))
	var strategy_pending := bool(state.get("combat_strategy_request_pending", false)) and strategy_eligible
	var strategy_context: Dictionary = state.get("combat_strategy_context", {}) if state.get("combat_strategy_context", {}) is Dictionary else {}
	var current_strategy: Dictionary = strategy_context.get("current_strategy", {}) if strategy_context.get("current_strategy", {}) is Dictionary else {}
	var strategy_labels: Array[String] = []
	for raw_strategy in strategy_context.get("available_strategies", []):
		if raw_strategy is Dictionary:
			strategy_labels.append(str((raw_strategy as Dictionary).get("label", "")))
	combat_strategy_toggle.visible = is_player_dialogue and not _observer_mode
	combat_strategy_toggle.set_pressed_no_signal(strategy_pending)
	combat_strategy_toggle.disabled = waiting or not strategy_eligible
	combat_strategy_toggle.modulate = Color(1.0, 1.0, 1.0, 1.0 if strategy_eligible else 0.45)
	combat_strategy_toggle.text = "调整战斗策略"
	combat_strategy_toggle.tooltip_text = (
		"当前：%s；可选：%s。四项特殊互动互斥；无关话题默认保持不变。"
		% [str(current_strategy.get("label", "无策略")), " / ".join(strategy_labels)]
		if strategy_eligible
		else str(state.get("combat_strategy_request_ineligible_reason", "当前场景不能调整战斗策略。"))
	)
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
	var special_interaction_request_sent := bool(state.get("session_had_special_interaction_request", false))
	var special_interaction_result_committed := bool(state.get("session_had_special_interaction_result", false))
	cancel_button.disabled = (
		npc_initiated_proactive_talk
		or bool(state.get("attack_committed", false))
		or special_interaction_request_sent
		or special_interaction_result_committed
	)
	cancel_button.tooltip_text = (
		"驿站成员主动交涉不可取消对话。"
		if npc_initiated_proactive_talk
		else (
			"本次会话发生过攻击，伤害事实不可撤销，因此不能取消。"
			if bool(state.get("attack_committed", false))
			else (
				"本次会话已经发送过特殊交互消息，只能完成对话。"
				if special_interaction_request_sent
				else (
					"本次会话已经产生特殊交互结果并写入事件库，只能完成对话。"
					if special_interaction_result_committed
					else "丢弃本次会话，不入库，也不触发计划修改判别。"
				)
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
	var escape_status := "NPC 已停下，准备回到工作安排。" if escape_decision == "stay" else "NPC 仍在继续逃离。" if escape_decision == "continue" else ""
	if _observer_mode:
		status_label.text = ("本轮自主对话已结束。" if last_error.is_empty() else "对话已结束：%s" % last_error) if _observer_dialogue_ended else ("正在等待 NPC 回复……" if waiting else "")
	else:
		status_label.text = last_error if not last_error.is_empty() else ("守备官消息已发送，正在等待回复……" if waiting else "逃离挽留轮次已用完。" if round_limit_reached else escape_status if dialogue_kind == "escape_intervention" else "下次发送将请求调整战斗策略。" if strategy_pending else "下次发送将尝试鼓舞士气。" if morale_pending else "下次发送将尝试鼓励工作。" if work_pending else "下次发送将提出应征。" if recruitment_pending else recruitment_status)
	status_label.visible = not status_label.text.is_empty()
	var lines: Array[String] = []
	for raw_turn in state.get("history", []):
		if not raw_turn is Dictionary:
			continue
		var turn: Dictionary = raw_turn
		var displayed_turn_text := str(turn.get("text", ""))
		var emotion_label := str(turn.get("emotion_label", "")).strip_edges()
		if not emotion_label.is_empty():
			displayed_turn_text += " [color=%s](%s)[/color]" % [MORALE_CONTINUE_COLOR, emotion_label]
		var turn_lines: Array[String] = [
			"[b]%s[/b]：%s" % [str(turn.get("speaker_name", "")), displayed_turn_text]
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
		if bool(turn.get("morale_encouragement_request", false)):
			match str(turn.get("wartime_reaction", "none")):
				"morale_boost":
					turn_lines.append(
						"[color=%s]✓ 守备官成功鼓舞了%s；持续至当天24:00，攻击力和移动速度提升15%%[/color]"
						% [RECRUITMENT_ACCEPT_COLOR, turn_speaker_name]
					)
				"escape":
					turn_lines.append(
						"[color=%s]× 鼓舞失败，%s决定逃离驿站[/color]"
						% [RECRUITMENT_REJECT_COLOR, turn_speaker_name]
					)
				_:
					turn_lines.append(
						"[color=%s]• %s未受到鼓舞，继续参战[/color]"
						% [MORALE_CONTINUE_COLOR, turn_speaker_name]
					)
		if bool(turn.get("combat_strategy_request", false)):
			var strategy_result: Dictionary = turn.get("combat_strategy_result", {}) if turn.get("combat_strategy_result", {}) is Dictionary else {}
			if bool(strategy_result.get("changed", false)):
				turn_lines.append(
					"[color=%s]✓ %s将战斗策略从“%s”调整为“%s”[/color]"
					% [RECRUITMENT_ACCEPT_COLOR, turn_speaker_name, str(strategy_result.get("previous_strategy_label", "")), str(strategy_result.get("strategy_label", ""))]
				)
			else:
				turn_lines.append(
					"[color=%s]• %s保持当前战斗策略：“%s”[/color]"
					% [MORALE_CONTINUE_COLOR, turn_speaker_name, str(strategy_result.get("strategy_label", "主动进攻"))]
				)
		if bool(turn.get("work_encouragement_request", false)):
			match str(turn.get("work_encouragement_reaction", "none")):
				"work_boost":
					turn_lines.append(
						"[color=%s]✓ 守备官成功鼓励了%s；持续至当天24:00，全部工作产出效率提升20%%[/color]"
						% [RECRUITMENT_ACCEPT_COLOR, turn_speaker_name]
					)
				"escape":
					turn_lines.append(
						"[color=%s]× 鼓励失败，%s决定逃离驿站[/color]"
						% [RECRUITMENT_REJECT_COLOR, turn_speaker_name]
					)
				_:
					turn_lines.append(
						"[color=%s]• %s未受工作鼓励影响，照常工作[/color]"
						% [MORALE_CONTINUE_COLOR, turn_speaker_name]
					)
		if turn.has("escape_intervention_result"):
			if str(turn.get("escape_intervention_result", "leave")) == "stay":
				turn_lines.append(
					"[color=%s]✓ 成功挽留%s，%s决定留在驿站[/color]"
					% [RECRUITMENT_ACCEPT_COLOR, turn_speaker_name, turn_speaker_name]
				)
			else:
				turn_lines.append(
					"[color=%s]× 挽留未成功，%s继续逃离驿站[/color]"
					% [RECRUITMENT_REJECT_COLOR, turn_speaker_name]
				)
		lines.append("\n".join(turn_lines))
	if _observer_mode and waiting:
		var pending: Dictionary = state.get("pending_llm", {}) if state.get("pending_llm", {}) is Dictionary else {}
		if not pending.is_empty() and not bool(pending.get("speaker_text_already_recorded", false)):
			lines.append("[b]%s[/b]：%s" % [str(pending.get("speaker_name", "")), str(pending.get("clean_text", ""))])
	history_text.text = "\n\n".join(lines)
	history_text.scroll_to_line(maxi(0, history_text.get_line_count() - 1))
