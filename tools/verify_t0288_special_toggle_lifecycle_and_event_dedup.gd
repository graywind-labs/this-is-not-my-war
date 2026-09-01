extends SceneTree


const SPECIAL_PAYLOAD_FIELDS := [
	"is_recruitment_request", "recruitment_result",
	"is_morale_encouragement_request", "wartime_reaction",
	"is_combat_strategy_request", "combat_strategy_result",
	"is_work_encouragement_request", "work_encouragement_reaction"
]
const SPECIAL_TURN_FIELDS := [
	"recruitment_result", "morale_encouragement_request", "wartime_reaction",
	"combat_strategy_request", "combat_strategy_result",
	"work_encouragement_request", "work_encouragement_reaction",
	"escape_intervention_result"
]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	if (
		dialog_system == null or npc_system == null or memory_system == null
		or resource_system == null or equipment_system == null or combat_system == null
		or dialog_panel == null
	):
		_fail("T0288 required systems were not found")
		return
	var recruitment_toggle := dialog_panel.find_child("DialogRecruitmentToggle", true, false) as CheckButton
	var work_toggle := dialog_panel.find_child("DialogWorkEncouragementToggle", true, false) as CheckButton
	var morale_toggle := dialog_panel.find_child("DialogMoraleEncouragementToggle", true, false) as CheckButton
	var strategy_toggle := dialog_panel.find_child("DialogCombatStrategyToggle", true, false) as CheckButton
	var cancel_button := dialog_panel.find_child("DialogCancelButton", true, false) as Button
	if recruitment_toggle == null or work_toggle == null or morale_toggle == null or strategy_toggle == null or cancel_button == null:
		_fail("T0288 dialogue controls were not found")
		return

	# Work: none keeps the toggle armed, but the sent marked message locks cancellation.
	var start_result: Dictionary = dialog_system.start_player_dialogue("cook_01", "private")
	if not bool(start_result.get("ok", false)) or not bool(dialog_system.set_work_encouragement_request_pending(true).get("ok", false)):
		_fail("Could not prepare work encouragement lifecycle")
		return
	var send_result: Dictionary = dialog_system.send_player_message("今晚食堂准备吃什么？", false, true)
	await process_frame
	if not bool(send_result.get("ok", false)) or not _assert_cancel_locked(dialog_system, cancel_button, "work"):
		return
	var pending: Dictionary = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "cook_01",
			"reply_text": "今晚还是按原来的安排准备晚餐。",
			"recruitment_result": "none",
			"work_encouragement_reaction": "none"
		}
	}, pending)
	await process_frame
	if not work_toggle.button_pressed or not bool(dialog_system.get_dialogue_state().get("work_encouragement_request_pending", false)):
		_fail("Work none result disarmed the sticky toggle")
		return
	if _count_special_results(memory_system.get_npc_daily_events("cook_01"), "work_encouragement", "none") != 1:
		_fail("Work none result did not enter the event library immediately")
		return
	var completion: Dictionary = dialog_system.end_dialogue("t0288_work_completed", {"suppress_plan_reevaluation": true})
	if not _assert_clean_dialogue_event(completion.get("dialogue_event", {}), ["今晚食堂准备吃什么？", "今晚还是按原来的安排准备晚餐。"]):
		return
	if _count_special_results(memory_system.get_npc_daily_events("cook_01"), "work_encouragement", "none") != 1:
		_fail("Completing work dialogue duplicated its special result event")
		return

	# Recruitment: reject keeps the toggle; accept closes it because the success invalidates eligibility.
	start_result = dialog_system.start_player_dialogue("gardener_01", "private")
	if not bool(start_result.get("ok", false)) or not bool(dialog_system.set_recruitment_request_pending(true).get("ok", false)):
		_fail("Could not prepare recruitment lifecycle")
		return
	send_result = dialog_system.send_player_message("请你加入守备队。", false, true)
	await process_frame
	if not bool(send_result.get("ok", false)) or not _assert_cancel_locked(dialog_system, cancel_button, "recruitment"):
		return
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "gardener_01",
			"reply_text": "不，我还不愿意加入。",
			"recruitment_result": "reject"
		}
	}, pending)
	await process_frame
	if not recruitment_toggle.button_pressed:
		_fail("Recruitment rejection disarmed the sticky toggle")
		return
	send_result = dialog_system.send_player_message("我会保护大家，请正式加入我们。", false, true)
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "gardener_01",
			"reply_text": "好，我同意加入守备队。",
			"recruitment_result": "accept"
		}
	}, pending)
	await process_frame
	if recruitment_toggle.button_pressed or bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", false)):
		_fail("Recruitment acceptance did not close the toggle")
		return
	completion = dialog_system.end_dialogue("t0288_recruitment_completed", {"suppress_plan_reevaluation": true})
	if not _assert_clean_dialogue_event(completion.get("dialogue_event", {}), []):
		return

	# Prepare an eligible wartime target for strategy and morale tests.
	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	if not bool(equip_result.get("ok", false)):
		_fail("Could not equip T0288 wartime target: %s" % JSON.stringify(equip_result))
		return
	combat_system.debug_spawn_wave(1, true)
	combat_system.debug_trigger_combat_alarm()

	# Strategy: keep remains armed; a real change closes it.
	start_result = dialog_system.start_player_dialogue("stableman_01", "private")
	if not bool(start_result.get("ok", false)) or not bool(dialog_system.set_combat_strategy_request_pending(true).get("ok", false)):
		_fail("Could not prepare strategy lifecycle")
		return
	send_result = dialog_system.send_player_message("先保持现在的打法。", false, true)
	await process_frame
	if not bool(send_result.get("ok", false)) or not _assert_cancel_locked(dialog_system, cancel_button, "strategy"):
		return
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "stableman_01",
			"reply_text": "明白，我会保持主动进攻。",
			"recruitment_result": "none",
			"combat_strategy_decision": {"decision": "keep", "strategy_id": "attack"}
		}
	}, pending)
	await process_frame
	if not strategy_toggle.button_pressed:
		_fail("Strategy keep result disarmed the sticky toggle")
		return
	send_result = dialog_system.send_player_message("改为避战，先保存实力。", false, true)
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "stableman_01",
			"reply_text": "明白，我会改为避战。",
			"recruitment_result": "none",
			"combat_strategy_decision": {"decision": "change", "strategy_id": "avoid"}
		}
	}, pending)
	await process_frame
	if strategy_toggle.button_pressed or bool(dialog_system.get_dialogue_state().get("combat_strategy_request_pending", false)):
		_fail("Successful strategy change did not close the toggle")
		return
	completion = dialog_system.end_dialogue("t0288_strategy_completed", {"suppress_plan_reevaluation": true})
	if not _assert_clean_dialogue_event(completion.get("dialogue_event", {}), []):
		return

	# Morale: none remains armed; an external eligibility loss closes it permanently.
	start_result = dialog_system.start_player_dialogue("stableman_01", "private")
	if not bool(start_result.get("ok", false)) or not bool(dialog_system.set_morale_encouragement_request_pending(true).get("ok", false)):
		_fail("Could not prepare morale lifecycle")
		return
	send_result = dialog_system.send_player_message("今晚吃什么？", false, true)
	await process_frame
	if not bool(send_result.get("ok", false)) or not _assert_cancel_locked(dialog_system, cancel_button, "morale"):
		return
	pending = dialog_system.get_dialogue_state().get("pending_llm", {})
	dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"replyer_id": "stableman_01",
			"reply_text": "先别谈吃的，我还在盯着敌人。",
			"recruitment_result": "none",
			"wartime_reaction": "none"
		}
	}, pending)
	await process_frame
	if not morale_toggle.button_pressed:
		_fail("Morale none result disarmed the sticky toggle")
		return
	var external_boost: Dictionary = combat_system.debug_start_morale_boost("stableman_01", "t0288_external_eligibility_loss")
	await process_frame
	if not bool(external_boost.get("ok", false)) or morale_toggle.button_pressed or bool(dialog_system.get_dialogue_state().get("morale_encouragement_request_pending", false)):
		_fail("Morale toggle did not close after its eligibility became invalid")
		return
	completion = dialog_system.end_dialogue("t0288_morale_completed", {"suppress_plan_reevaluation": true})
	if not _assert_clean_dialogue_event(completion.get("dialogue_event", {}), []):
		return

	print("T0288_SPECIAL_TOGGLE_LIFECYCLE_AND_EVENT_DEDUP_OK")
	quit(0)


func _assert_cancel_locked(dialog_system: Node, cancel_button: Button, label: String) -> bool:
	var state: Dictionary = dialog_system.get_dialogue_state()
	if (
		not bool(state.get("session_had_special_interaction_request", false))
		or not cancel_button.disabled
		or bool(dialog_system.cancel_displayed_dialogue().get("ok", false))
	):
		_fail("%s marked message did not lock cancellation immediately" % label)
		return false
	return true


func _assert_clean_dialogue_event(raw_event: Variant, expected_texts: Array) -> bool:
	var event: Dictionary = raw_event if raw_event is Dictionary else {}
	if str(event.get("type", "")) != "dialogue_turn":
		_fail("Completed session did not create a dialogue_turn event")
		return false
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	for field in SPECIAL_PAYLOAD_FIELDS:
		if payload.has(field):
			_fail("Completed dialogue payload retained special marker: %s" % field)
			return false
	var observed_texts: Array[String] = []
	for raw_turn in payload.get("dialogue_text", []):
		if not raw_turn is Dictionary:
			_fail("Completed dialogue transcript contained a non-dictionary turn")
			return false
		var turn: Dictionary = raw_turn
		observed_texts.append(str(turn.get("text", "")))
		for field in SPECIAL_TURN_FIELDS:
			if turn.has(field):
				_fail("Completed dialogue transcript retained special marker: %s" % field)
				return false
		for field in turn.keys():
			if not ["speaker_id", "speaker_name", "listener_id", "listener_name", "text"].has(field):
				_fail("Completed dialogue transcript retained non-content field: %s" % field)
				return false
	for expected_text in expected_texts:
		if not observed_texts.has(str(expected_text)):
			_fail("Completed dialogue transcript lost real dialogue text: %s" % expected_text)
			return false
	return true


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
