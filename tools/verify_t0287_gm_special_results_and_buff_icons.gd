extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel") as Control
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var success_dialog := root.get_node_or_null("Main/UI/DialogPanel/DialogSpecialSuccessDialog") as AcceptDialog
	var escape_alert := root.get_node_or_null("Main/UI/HUD/EscapeStartedAlertDialog") as AcceptDialog
	if npc_system == null or combat_system == null or dialog_system == null or memory_system == null or gm_panel == null or npc_panel == null or dialog_panel == null or success_dialog == null or escape_alert == null:
		_fail("T0287 required nodes not found")
		return

	var required_buttons := [
		"RecruitmentAcceptPreviewButton", "RecruitmentRejectPreviewButton", "RecruitmentNonePreviewButton",
		"MoraleBoostPreviewButton", "MoraleNonePreviewButton", "MoraleEscapePreviewButton",
		"WorkBoostPreviewButton", "WorkNonePreviewButton", "WorkEscapePreviewButton",
		"StrategyChangePreviewButton", "StrategyKeepPreviewButton", "ClearDialogueBuffsButton",
		"StartEscapePreviewButton", "EscapeStayPreviewButton", "EscapeLeavePreviewButton"
	]
	for button_name in required_buttons:
		if gm_panel.find_child(button_name, true, false) == null:
			_fail("Missing GM AI dialogue result button: %s" % button_name)
			return

	var npc_id := "cook_01"
	if not npc_system.debug_select_npc(npc_id):
		_fail("Failed to select NPC for buff icon verification")
		return
	await process_frame
	var morale_icon := npc_panel.find_child("NPCMoraleBoostIcon", true, false) as TextureRect
	var work_icon := npc_panel.find_child("NPCWorkBoostIcon", true, false) as TextureRect
	var close_button := npc_panel.find_child("NPCPanelCloseButton", true, false) as Button
	if morale_icon == null or work_icon == null or close_button == null:
		_fail("NPC buff icon controls not found")
		return
	if morale_icon.visible or work_icon.visible:
		_fail("NPC buff icons should be hidden without active buffs")
		return
	if morale_icon.get_index() != close_button.get_index() - 2 or work_icon.get_index() != close_button.get_index() - 1:
		_fail("NPC buff icons must be placed immediately before the close button")
		return

	var work_result: Dictionary = dialog_system.debug_preview_special_interaction_result(
		npc_id, "work_encouragement", "work_boost", "local_public"
	)
	await process_frame
	if not bool(work_result.get("ok", false)) or not work_icon.visible or morale_icon.visible:
		_fail("Work result did not activate only the work icon: %s" % JSON.stringify(work_result))
		return
	if not work_icon.tooltip_text.contains("全部工作产出效率 +20%") or not work_icon.tooltip_text.contains("当天 24:00"):
		_fail("Work buff tooltip mismatch: %s" % work_icon.tooltip_text)
		return
	if not success_dialog.visible or not success_dialog.dialog_text.contains("工作效率得到提升"):
		_fail("Work success preview did not display the formal success dialog")
		return
	success_dialog.get_ok_button().pressed.emit()
	await process_frame
	npc_system.debug_clear_work_encouragement_boost(npc_id)
	await process_frame
	if work_icon.visible:
		_fail("Work icon did not hide after the authoritative boost was cleared")
		return

	var morale_result: Dictionary = dialog_system.debug_preview_special_interaction_result(
		npc_id, "morale_encouragement", "morale_boost", "local_public"
	)
	await process_frame
	if not bool(morale_result.get("ok", false)) or not morale_icon.visible or work_icon.visible:
		_fail("Morale result did not activate only the morale icon: %s" % JSON.stringify(morale_result))
		return
	if not morale_icon.tooltip_text.contains("攻击力 +15%") or not morale_icon.tooltip_text.contains("移动速度 +15%") or not morale_icon.tooltip_text.contains("当天 24:00"):
		_fail("Morale buff tooltip mismatch: %s" % morale_icon.tooltip_text)
		return
	if not success_dialog.visible or not success_dialog.dialog_text.contains("士气受到鼓舞"):
		_fail("Morale success preview did not display the formal success dialog")
		return
	success_dialog.get_ok_button().pressed.emit()
	await process_frame
	combat_system.debug_clear_morale_boost(npc_id)
	await process_frame
	if morale_icon.visible:
		_fail("Morale icon did not hide after the authoritative boost was cleared")
		return

	var reject_count_before := _count_special_results(memory_system.get_npc_daily_events(npc_id), "recruitment", "reject")
	var reject_result: Dictionary = dialog_system.debug_preview_special_interaction_result(
		npc_id, "recruitment", "reject", "local_public"
	)
	await process_frame
	if not bool(reject_result.get("ok", false)) or success_dialog.visible:
		_fail("Recruitment rejection preview should not display a success dialog")
		return
	if _count_special_results(memory_system.get_npc_daily_events(npc_id), "recruitment", "reject") != reject_count_before + 1:
		_fail("Recruitment rejection preview was not written to the NPC event log")
		return
	var history_text := dialog_panel.find_child("DialogHistoryText", true, false) as RichTextLabel
	if history_text == null or not history_text.text.contains("拒绝了守备官的应征请求"):
		_fail("Recruitment rejection preview did not use the formal dialogue feedback: %s" % (history_text.text if history_text != null else "<missing>"))
		return

	var accept_result: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"gardener_01", "recruitment", "accept", "local_public"
	)
	await process_frame
	if not bool(accept_result.get("ok", false)) or not bool(npc_system.get_npc("gardener_01").get("recruited", false)) or not success_dialog.visible:
		_fail("Recruitment accept result gallery path failed: %s" % JSON.stringify(accept_result))
		return
	success_dialog.get_ok_button().pressed.emit()
	await process_frame
	var recruitment_none: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"gardener_01", "recruitment", "none", "local_public"
	)
	await process_frame
	if not bool(recruitment_none.get("ok", false)) or success_dialog.visible:
		_fail("Recruitment none result gallery path failed")
		return

	var recruit_and_equip_button := gm_panel.find_child("RecruitAndEquipAllButton", true, false) as Button
	if recruit_and_equip_button == null:
		_fail("RecruitAndEquipAllButton required for strategy result setup")
		return
	recruit_and_equip_button.pressed.emit()
	await process_frame
	var strategy_change: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"veteran_deputy_01", "combat_strategy", "change", "local_public"
	)
	await process_frame
	if not bool(strategy_change.get("ok", false)) or not bool((strategy_change.get("state_result", {}) as Dictionary).get("changed", false)) or not success_dialog.visible:
		_fail("Strategy change result gallery path failed: %s" % JSON.stringify(strategy_change))
		return
	success_dialog.get_ok_button().pressed.emit()
	await process_frame
	var strategy_keep: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"veteran_deputy_01", "combat_strategy", "keep", "local_public"
	)
	await process_frame
	if not bool(strategy_keep.get("ok", false)) or success_dialog.visible:
		_fail("Strategy keep result gallery path failed: %s" % JSON.stringify(strategy_keep))
		return

	var morale_none: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"priest_01", "morale_encouragement", "none", "local_public"
	)
	await process_frame
	if not bool(morale_none.get("ok", false)) or success_dialog.visible:
		_fail("Morale none result gallery path failed")
		return
	var morale_escape: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"priest_01", "morale_encouragement", "escape", "local_public"
	)
	await process_frame
	if not bool(morale_escape.get("ok", false)) or not bool(((morale_escape.get("escape_result", {}) as Dictionary).get("applied", false))) or not escape_alert.visible:
		_fail("Morale escape result gallery path failed: %s" % JSON.stringify(morale_escape))
		return
	escape_alert.get_ok_button().pressed.emit()
	await process_frame
	var priest_stay: Dictionary = dialog_system.debug_preview_escape_intervention_result("priest_01", "stay")
	await process_frame
	if not bool(priest_stay.get("ok", false)) or str(priest_stay.get("decision", "")) != "stay":
		_fail("Morale escape cleanup through stay failed")
		return
	dialog_system.end_dialogue("t0287_priest_stayed", {"suppress_plan_reevaluation": true})

	var work_none: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"doctor_01", "work_encouragement", "none", "local_public"
	)
	await process_frame
	if not bool(work_none.get("ok", false)) or success_dialog.visible:
		_fail("Work none result gallery path failed")
		return
	var work_escape: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"doctor_01", "work_encouragement", "escape", "local_public"
	)
	await process_frame
	if not bool(work_escape.get("ok", false)) or not bool(((work_escape.get("escape_result", {}) as Dictionary).get("applied", false))) or not escape_alert.visible:
		_fail("Work escape result gallery path failed: %s" % JSON.stringify(work_escape))
		return
	escape_alert.get_ok_button().pressed.emit()
	await process_frame
	var doctor_leave: Dictionary = dialog_system.debug_preview_escape_intervention_result("doctor_01", "leave")
	await process_frame
	if not bool(doctor_leave.get("ok", false)) or str(doctor_leave.get("decision", "")) != "continue":
		_fail("Escape leave result gallery path failed: %s" % JSON.stringify(doctor_leave))
		return
	history_text = dialog_panel.find_child("DialogHistoryText", true, false) as RichTextLabel
	if history_text == null or not history_text.text.contains("继续逃离驿站"):
		_fail("Escape leave preview did not display the formal result feedback")
		return
	dialog_system.end_dialogue("t0287_doctor_leave", {"suppress_plan_reevaluation": true})

	dialog_system.end_dialogue("t0287_before_escape", {"suppress_plan_reevaluation": true})
	var escape_result: Dictionary = combat_system.debug_start_npc_escape(npc_id, "t0287_escape")
	await process_frame
	if not bool(escape_result.get("applied", false)) or not escape_alert.visible:
		_fail("GM escape result did not start the authoritative behavior and alert")
		return
	escape_alert.get_ok_button().pressed.emit()
	await process_frame
	var stay_result: Dictionary = dialog_system.debug_preview_escape_intervention_result(npc_id, "stay")
	await process_frame
	if not bool(stay_result.get("ok", false)) or str(stay_result.get("decision", "")) != "stay":
		_fail("Escape stay preview failed: %s" % JSON.stringify(stay_result))
		return
	history_text = dialog_panel.find_child("DialogHistoryText", true, false) as RichTextLabel
	if history_text == null or not history_text.text.contains("成功挽留"):
		_fail("Escape stay preview did not display the formal result feedback")
		return
	var stayed_state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool((stayed_state.get("escape_intent", {}) as Dictionary).get("active", false)):
		_fail("Stay result did not stop the authoritative escape state")
		return

	dialog_system.end_dialogue("t0287_after_stay", {"suppress_plan_reevaluation": true})
	print("T0287_GM_SPECIAL_RESULTS_AND_BUFF_ICONS_OK")
	quit(0)


func _count_special_results(events: Array, special_type: String, outcome: String) -> int:
	var count := 0
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) != "dialogue_special_interaction_result":
			continue
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		if str(payload.get("special_type", "")) == special_type and str(payload.get("outcome", "")) == outcome:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
