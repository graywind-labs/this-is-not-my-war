extends SceneTree


func _init() -> void:
	var backend_url := OS.get_environment("TEST_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		push_error("TEST_BACKEND_URL is required for special dialogue interaction Mock verification")
		quit(1)
		return
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	var bridge := main.get_node_or_null("Systems/LLMBridge")
	bridge.set_backend_base_url(backend_url)
	root.add_child(main)
	await process_frame
	await physics_frame

	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var morale_toggle := dialog_panel.find_child("DialogMoraleEncouragementToggle", true, false) as CheckButton
	var strategy_toggle := dialog_panel.find_child("DialogCombatStrategyToggle", true, false) as CheckButton
	var work_toggle := dialog_panel.find_child("DialogWorkEncouragementToggle", true, false) as CheckButton
	var recruitment_toggle := dialog_panel.find_child("DialogRecruitmentToggle", true, false) as CheckButton
	var history_text := dialog_panel.find_child("DialogHistoryText", true, false) as RichTextLabel
	var special_success_dialog := dialog_panel.find_child("DialogSpecialSuccessDialog", true, false) as AcceptDialog
	if (
		dialog_system == null
		or combat_system == null
		or npc_system == null
		or memory_system == null
		or resource_system == null
		or equipment_system == null
		or morale_toggle == null
		or strategy_toggle == null
		or work_toggle == null
		or recruitment_toggle == null
		or history_text == null
		or special_success_dialog == null
		or gm_panel == null
		or gm_panel.find_child("MoraleEncouragementMockButton", true, false) == null
		or gm_panel.find_child("OpenMoraleEncouragementDialogueButton", true, false) == null
		or gm_panel.find_child("CombatStrategyDialogueMockButton", true, false) == null
		or gm_panel.find_child("OpenCombatStrategyDialogueButton", true, false) == null
		or gm_panel.find_child("WorkEncouragementDialogueMockButton", true, false) == null
		or gm_panel.find_child("OpenWorkEncouragementDialogueButton", true, false) == null
	):
		push_error("Special dialogue interaction Mock verification required nodes or GM entries not found")
		quit(1)
		return

	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	if not bool(equip_result.get("ok", false)):
		push_error("Failed to equip morale Mock target: %s" % JSON.stringify(equip_result))
		quit(1)
		return
	combat_system.debug_spawn_wave(1, true)
	combat_system.debug_trigger_combat_alarm()

	var start_result: Dictionary = dialog_system.start_player_dialogue("stableman_01", "private")
	if (
		not bool(start_result.get("ok", false))
		or morale_toggle.disabled
		or strategy_toggle.disabled
		or not work_toggle.disabled
		or work_toggle.modulate.a > 0.5
	):
		push_error("Eligible combat target did not expose enabled special interaction toggles")
		quit(1)
		return
	var plain_result: Dictionary = dialog_system.send_player_message("我们一起稳住阵线，坚持守住城门。")
	if not bool(plain_result.get("ok", false)) or str(plain_result.get("dialogue", {}).get("wartime_reaction", "")) != "none":
		push_error("Mock must suppress wartime reaction while toggle is off: %s" % JSON.stringify(plain_result))
		quit(1)
		return
	if (plain_result.get("dialogue", {}) as Dictionary).has("combat_strategy_decision"):
		push_error("Mock returned combat strategy structure while its toggle was off: %s" % JSON.stringify(plain_result))
		quit(1)
		return
	if (plain_result.get("dialogue", {}) as Dictionary).has("work_encouragement_reaction"):
		push_error("Mock returned work encouragement structure while its toggle was off: %s" % JSON.stringify(plain_result))
		quit(1)
		return

	var strategy_arm: Dictionary = dialog_system.set_combat_strategy_request_pending(true)
	if not bool(strategy_arm.get("ok", false)) or not strategy_toggle.button_pressed or morale_toggle.button_pressed:
		push_error("Failed to arm mutually exclusive strategy Mock toggle: %s" % JSON.stringify(strategy_arm))
		quit(1)
		return
	var unrelated_strategy: Dictionary = dialog_system.send_player_message("今晚食堂准备吃什么？")
	var unrelated_strategy_decision: Dictionary = (unrelated_strategy.get("dialogue", {}) as Dictionary).get("combat_strategy_decision", {})
	if (
		not bool(unrelated_strategy.get("ok", false))
		or str(unrelated_strategy_decision.get("decision", "")) != "keep"
		or str(combat_system.get_npc_combat_strategy("stableman_01").get("id", "")) != "attack"
		or not strategy_toggle.button_pressed
		or not history_text.text.contains("保持当前战斗策略：“主动进攻”")
		or _find_special_result(memory_system.get_npc_daily_events("stableman_01"), "combat_strategy", "keep").is_empty()
	):
		push_error("Unrelated strategy Mock did not keep the current strategy: %s" % JSON.stringify(unrelated_strategy))
		quit(1)
		return
	var changed_strategy: Dictionary = dialog_system.send_player_message("不要主动接敌，调整为避战并保存实力。")
	var changed_strategy_decision: Dictionary = (changed_strategy.get("dialogue", {}) as Dictionary).get("combat_strategy_decision", {})
	if (
		not bool(changed_strategy.get("ok", false))
		or str(changed_strategy_decision.get("decision", "")) != "change"
		or str(changed_strategy_decision.get("strategy_id", "")) != "avoid"
		or str(combat_system.get_npc_combat_strategy("stableman_01").get("id", "")) != "avoid"
		or strategy_toggle.button_pressed
		or not history_text.text.contains("将战斗策略从“主动进攻”调整为“避战”")
		or not special_success_dialog.visible
		or not special_success_dialog.dialog_text.contains("将战斗策略改变为“避战”")
		or special_success_dialog.get_ok_button().text != "太好了"
		or _find_special_result(memory_system.get_npc_daily_events("stableman_01"), "combat_strategy", "change").is_empty()
	):
		push_error("Relevant strategy Mock did not apply authoritative change: %s" % JSON.stringify(changed_strategy))
		quit(1)
		return
	special_success_dialog.get_ok_button().pressed.emit()
	await process_frame
	if special_success_dialog.visible:
		push_error("Special success popup did not close through the 太好了 button")
		quit(1)
		return

	var arm_result: Dictionary = dialog_system.set_morale_encouragement_request_pending(true)
	if not bool(arm_result.get("ok", false)) or strategy_toggle.button_pressed:
		push_error("Failed to arm morale Mock toggle: %s" % JSON.stringify(arm_result))
		quit(1)
		return
	var unrelated_result: Dictionary = dialog_system.send_player_message("今晚食堂准备吃什么？")
	if (
		not bool(unrelated_result.get("ok", false))
		or str(unrelated_result.get("dialogue", {}).get("wartime_reaction", "")) != "none"
		or not morale_toggle.button_pressed
		or not history_text.text.contains("未受到鼓舞，继续参战")
		or _find_special_result(memory_system.get_npc_daily_events("stableman_01"), "morale_encouragement", "none").is_empty()
	):
		push_error("Unrelated Mock reply gained morale or disarmed toggle: %s" % JSON.stringify(unrelated_result))
		quit(1)
		return

	var inspired_result: Dictionary = dialog_system.send_player_message("别怕，我们一起稳住阵线，坚持守住城门。")
	if (
		not bool(inspired_result.get("ok", false))
		or str(inspired_result.get("dialogue", {}).get("wartime_reaction", "")) != "morale_boost"
		or morale_toggle.button_pressed
		or not morale_toggle.disabled
		or not history_text.text.contains("守备官成功鼓舞了托马；持续至当天24:00，攻击力和移动速度提升15%")
		or not special_success_dialog.visible
		or not special_success_dialog.dialog_text.contains("托马的士气受到鼓舞")
		or _find_special_result(memory_system.get_npc_daily_events("stableman_01"), "morale_encouragement", "morale_boost").is_empty()
	):
		push_error("Relevant Mock reply did not produce locked success feedback: %s" % JSON.stringify(inspired_result))
		quit(1)
		return
	special_success_dialog.get_ok_button().pressed.emit()
	await process_frame

	var completion: Dictionary = dialog_system.complete_displayed_dialogue()
	var morale_state: Dictionary = npc_system.get_npc_state("stableman_01").get("morale_boost", {})
	if not bool(morale_state.get("active", false)):
		push_error("Completed Mock dialogue did not apply authoritative morale buff: %s" % JSON.stringify(completion))
		quit(1)
		return
	var active_buff_start: Dictionary = dialog_system.start_player_dialogue("stableman_01", "private")
	if not bool(active_buff_start.get("ok", false)) or not morale_toggle.disabled or morale_toggle.modulate.a > 0.5:
		push_error("Active Mock morale buff did not disable and fade toggle")
		quit(1)
		return
	dialog_system.complete_displayed_dialogue()
	combat_system.debug_clear_enemies()

	var work_start: Dictionary = dialog_system.start_player_dialogue("cook_01", "private")
	if not bool(work_start.get("ok", false)) or work_toggle.disabled:
		push_error("Unrecruited peaceful work target did not expose work encouragement toggle")
		quit(1)
		return
	var cook_location := str(npc_system.get_npc_state("cook_01").get("current_location", "plaza"))
	var witness_id := "priest_01"
	var witness_previous_location := str(npc_system.get_npc_state(witness_id).get("current_location", "plaza"))
	npc_system.update_npc_state(witness_id, {"current_location": cook_location})
	memory_system.move_npc_between_locations(witness_id, witness_previous_location, cook_location)
	var public_result: Dictionary = dialog_system.set_dialogue_visibility("local_public")
	if not bool(public_result.get("ok", false)):
		push_error("Failed to make work special interaction public: %s" % JSON.stringify(public_result))
		quit(1)
		return
	var witness_special_before := _count_special_results(memory_system.get_npc_witness_events(witness_id))
	var recruitment_arm: Dictionary = dialog_system.set_recruitment_request_pending(true)
	var unrelated_recruitment: Dictionary = dialog_system.send_player_message("今晚食堂准备吃什么？")
	if (
		not bool(unrelated_recruitment.get("ok", false))
		or str(unrelated_recruitment.get("dialogue", {}).get("recruitment_result", "")) != "none"
		or not recruitment_toggle.button_pressed
		or bool(npc_system.get_npc("cook_01").get("recruited", false))
		or _find_special_result(memory_system.get_npc_daily_events("cook_01"), "recruitment", "none").is_empty()
		or _count_special_results(memory_system.get_npc_witness_events(witness_id)) != witness_special_before + 1
	):
		push_error("Unrelated recruitment request was not ignored: %s" % JSON.stringify(unrelated_recruitment))
		quit(1)
		return
	var rejected_recruitment: Dictionary = dialog_system.send_player_message("你必须应征入伍，立刻拿起武器，不许拒绝，否则就受罚。")
	if (
		not bool(rejected_recruitment.get("ok", false))
		or str(rejected_recruitment.get("dialogue", {}).get("recruitment_result", "")) != "reject"
		or special_success_dialog.visible
		or _find_special_result(memory_system.get_npc_daily_events("cook_01"), "recruitment", "reject").is_empty()
		or _count_special_results(memory_system.get_npc_witness_events(witness_id)) != witness_special_before + 2
	):
		push_error("Rejected public recruitment did not enter event and witness logs without success popup: %s" % JSON.stringify(rejected_recruitment))
		quit(1)
		return
	var accepted_recruitment: Dictionary = dialog_system.send_player_message("我正式邀请你应征入伍，一起守卫驿站。")
	if (
		not bool(accepted_recruitment.get("ok", false))
		or str(accepted_recruitment.get("dialogue", {}).get("recruitment_result", "")) != "accept"
		or not bool(npc_system.get_npc("cook_01").get("recruited", false))
		or recruitment_toggle.button_pressed
		or not special_success_dialog.visible
		or not special_success_dialog.dialog_text.contains("布鲁诺同意入伍")
		or _find_special_result(memory_system.get_npc_daily_events("cook_01"), "recruitment", "accept").is_empty()
		or _count_special_results(memory_system.get_npc_witness_events(witness_id)) != witness_special_before + 3
	):
		push_error("Accepted public recruitment did not produce popup, event and same-location witness: %s" % JSON.stringify(accepted_recruitment))
		quit(1)
		return
	special_success_dialog.get_ok_button().pressed.emit()
	await process_frame
	var work_arm: Dictionary = dialog_system.set_work_encouragement_request_pending(true)
	if (
		not bool(recruitment_arm.get("ok", false))
		or not bool(work_arm.get("ok", false))
		or recruitment_toggle.button_pressed
		or morale_toggle.button_pressed
		or strategy_toggle.button_pressed
		or not work_toggle.button_pressed
	):
		push_error("Four-way special interaction mutual exclusion failed: %s" % JSON.stringify(work_arm))
		quit(1)
		return
	var unrelated_work: Dictionary = dialog_system.send_player_message("今晚食堂准备吃什么？")
	if (
		not bool(unrelated_work.get("ok", false))
		or str(unrelated_work.get("dialogue", {}).get("work_encouragement_reaction", "")) != "none"
		or not work_toggle.button_pressed
		or not history_text.text.contains("未受工作鼓励影响，照常工作")
		or not is_equal_approx(npc_system.get_npc_work_output_multiplier("cook_01"), 1.0)
		or _find_special_result(memory_system.get_npc_daily_events("cook_01"), "work_encouragement", "none").is_empty()
	):
		push_error("Unrelated work encouragement was not ignored: %s" % JSON.stringify(unrelated_work))
		quit(1)
		return
	var boosted_work: Dictionary = dialog_system.send_player_message("辛苦了，你的工作很重要，我相信你能把今天剩下的活做好。")
	if (
		not bool(boosted_work.get("ok", false))
		or str(boosted_work.get("dialogue", {}).get("work_encouragement_reaction", "")) != "work_boost"
		or work_toggle.button_pressed
		or not work_toggle.disabled
		or not history_text.text.contains("守备官成功鼓励了布鲁诺；持续至当天24:00，全部工作产出效率提升20%")
		or not special_success_dialog.visible
		or not special_success_dialog.dialog_text.contains("布鲁诺的工作效率得到提升")
		or _find_special_result(memory_system.get_npc_daily_events("cook_01"), "work_encouragement", "work_boost").is_empty()
	):
		push_error("Relevant work encouragement did not stage the expected feedback: %s" % JSON.stringify(boosted_work))
		quit(1)
		return
	special_success_dialog.get_ok_button().pressed.emit()
	await process_frame
	var work_completion: Dictionary = dialog_system.complete_displayed_dialogue()
	var work_boost: Dictionary = npc_system.get_npc_state("cook_01").get("work_encouragement_boost", {})
	if (
		not bool(work_completion.get("ok", false))
		or not bool(work_boost.get("active", false))
		or not is_equal_approx(npc_system.get_npc_work_output_multiplier("cook_01"), 1.2)
	):
		push_error("Completed work encouragement did not apply the authoritative 1.2 multiplier: %s" % JSON.stringify(work_completion))
		quit(1)
		return
	var active_work_start: Dictionary = dialog_system.start_player_dialogue("cook_01", "private")
	if not bool(active_work_start.get("ok", false)) or not work_toggle.disabled or work_toggle.modulate.a > 0.5:
		push_error("Active work encouragement buff did not disable and fade toggle")
		quit(1)
		return
	dialog_system.complete_displayed_dialogue()
	npc_system._advance_work_encouragement_boosts(float(work_boost.get("remaining_game_seconds", 0.0)) + 1.0)
	if not is_equal_approx(npc_system.get_npc_work_output_multiplier("cook_01"), 1.0):
		push_error("Work encouragement multiplier did not expire at its midnight duration")
		quit(1)
		return

	print("Morale, combat strategy and work encouragement Mock verification passed.")
	quit(0)


func _find_special_result(events: Array, special_type: String, outcome: String) -> Dictionary:
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) != "dialogue_special_interaction_result":
			continue
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		if str(payload.get("special_type", "")) == special_type and str(payload.get("outcome", "")) == outcome:
			return event
	return {}


func _count_special_results(events: Array) -> int:
	var count := 0
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) == "dialogue_special_interaction_result":
			count += 1
	return count
