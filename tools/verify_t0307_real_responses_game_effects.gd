extends SceneTree


const AUDIT_PATH := "res://docs/audits/T0307_SPECIAL_INTERACTIONS_REAL/real_results.json"
const WITNESS_ID := "priest_01"

var _audit_cases: Array = []
var _dialog_system: Node
var _npc_system: Node
var _memory_system: Node
var _resource_system: Node
var _equipment_system: Node
var _combat_system: Node
var _llm_bridge: Node
var _success_dialog: AcceptDialog


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUDIT_PATH))
	if not parsed is Dictionary:
		_fail("T0307 real audit JSON is missing or invalid")
		return
	_audit_cases = (parsed as Dictionary).get("cases", [])
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	_dialog_system = root.get_node_or_null("Main/Systems/DialogSystem")
	_npc_system = root.get_node_or_null("Main/Systems/NPCSystem")
	_memory_system = root.get_node_or_null("Main/Systems/MemorySystem")
	_resource_system = root.get_node_or_null("Main/Systems/ResourceSystem")
	_equipment_system = root.get_node_or_null("Main/Systems/EquipmentSystem")
	_combat_system = root.get_node_or_null("Main/Systems/CombatSystem")
	_llm_bridge = root.get_node_or_null("Main/Systems/LLMBridge")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	_success_dialog = dialog_panel.find_child("DialogSpecialSuccessDialog", true, false) as AcceptDialog if dialog_panel != null else null
	if (
		_dialog_system == null or _npc_system == null or _memory_system == null
		or _resource_system == null or _equipment_system == null or _combat_system == null
		or _llm_bridge == null or _success_dialog == null
	):
		_fail("T0307 required runtime systems were not found")
		return

	# Peaceful recruitment: replay the exact realistic real-provider bodies through DialogSystem.
	if not await _replay_and_assert("recruitment_none", "recruitment", "none", "cook_01"):
		return
	if bool(_npc_system.get_npc("cook_01").get("recruited", false)):
		_fail("Real recruitment none response changed recruitment state")
		return
	if not await _replay_and_assert("recruitment_reject", "recruitment", "reject", "cook_01"):
		return
	if bool(_npc_system.get_npc("cook_01").get("recruited", false)):
		_fail("Real recruitment reject response changed recruitment state")
		return
	if not await _replay_and_assert("recruitment_accept", "recruitment", "accept", "cook_01"):
		return
	if not bool(_npc_system.get_npc("cook_01").get("recruited", false)):
		_fail("Real recruitment accept response was parsed but did not recruit cook_01")
		return

	# Prepare formal combat eligibility for strategy and morale paths.
	if not _prepare_combatant("blacksmith_01"):
		return
	_combat_system.debug_spawn_wave(1, true)
	_combat_system.debug_trigger_combat_alarm()
	await process_frame
	if not await _replay_and_assert("strategy_keep", "combat_strategy", "keep", "veteran_deputy_01"):
		return
	if str(_combat_system.get_npc_combat_strategy("veteran_deputy_01").get("id", "")) != "attack":
		_fail("Real strategy keep response changed the authoritative strategy")
		return
	if not await _replay_and_assert("strategy_change", "combat_strategy", "change", "veteran_deputy_01"):
		return
	if str(_combat_system.get_npc_combat_strategy("veteran_deputy_01").get("id", "")) != "avoid":
		_fail("Real strategy change response did not apply avoid")
		return

	if not await _replay_and_assert("morale_none", "morale_encouragement", "none", "veteran_deputy_01"):
		return
	var veteran_state: Dictionary = _npc_system.get_npc_state("veteran_deputy_01")
	if bool((veteran_state.get("morale_boost", {}) as Dictionary).get("active", false)):
		_fail("Real morale none response applied a buff")
		return
	if not await _replay_and_assert("morale_boost", "morale_encouragement", "morale_boost", "veteran_deputy_01"):
		return
	veteran_state = _npc_system.get_npc_state("veteran_deputy_01")
	var morale: Dictionary = veteran_state.get("morale_boost", {}) if veteran_state.get("morale_boost", {}) is Dictionary else {}
	if (
		not bool(morale.get("active", false))
		or not is_equal_approx(float(morale.get("attack_bonus", 0.0)), 0.15)
		or not is_equal_approx(float(morale.get("move_speed_bonus", 0.0)), 0.15)
		or float(morale.get("remaining_game_seconds", 0.0)) <= 0.0
	):
		_fail("Real morale_boost response did not apply the until-midnight 15% authoritative buff")
		return
	if not await _replay_and_assert("morale_escape", "morale_encouragement", "escape", "blacksmith_01"):
		return
	if not _assert_escape_started("blacksmith_01", "morale escape"):
		return

	# Work interaction requires a peaceful station.
	_combat_system.debug_clear_enemies()
	await process_frame
	if not await _replay_and_assert("work_none", "work_encouragement", "none", "gardener_01"):
		return
	if not is_equal_approx(_npc_system.get_npc_work_output_multiplier("gardener_01"), 1.0):
		_fail("Real work none response changed work output")
		return
	if not await _replay_and_assert("work_boost", "work_encouragement", "work_boost", "gardener_01"):
		return
	var gardener_state: Dictionary = _npc_system.get_npc_state("gardener_01")
	var work_boost: Dictionary = gardener_state.get("work_encouragement_boost", {}) if gardener_state.get("work_encouragement_boost", {}) is Dictionary else {}
	if (
		not bool(work_boost.get("active", false))
		or not is_equal_approx(_npc_system.get_npc_work_output_multiplier("gardener_01"), 1.2)
		or float(work_boost.get("remaining_game_seconds", 0.0)) <= 0.0
	):
		_fail("Real work_boost response did not apply the until-midnight 1.2 multiplier")
		return
	if not await _replay_and_assert("work_escape", "work_encouragement", "escape", "engineer_01"):
		return
	if not _assert_escape_started("engineer_01", "work escape"):
		return

	if not _verify_projection_preserves_special_events("veteran_deputy_01", false):
		return
	if not _verify_projection_preserves_special_events(WITNESS_ID, true):
		return
	print("T0307_REAL_RESPONSES_GAME_EFFECTS_OK: 11 realistic responses parsed; all authority effects, public witness events, dedup, and projection boundaries verified.")
	quit(0)


func _prepare_combatant(npc_id: String) -> bool:
	_npc_system.set_npc_recruited(npc_id, true)
	var state: Dictionary = _npc_system.get_npc_state(npc_id)
	var equipment: Dictionary = _npc_system.get_npc(npc_id).get("equipment", {}) if _npc_system.get_npc(npc_id).get("equipment", {}) is Dictionary else {}
	if not equipment.has("main_weapon"):
		_resource_system.add_resource("item_sword_shield", 1)
		var equip_result: Dictionary = _equipment_system.equip_npc_main_weapon(npc_id, "sword_shield", "private")
		if not bool(equip_result.get("ok", false)):
			_fail("Could not equip %s for T0307: %s" % [npc_id, JSON.stringify(equip_result)])
			return false
	if bool(state.get("escaped", false)):
		_fail("Combat target %s was already escaped" % npc_id)
		return false
	return true


func _replay_and_assert(case_id: String, special_type: String, expected_outcome: String, npc_id: String) -> bool:
	var case_record := _find_case("realistic", case_id)
	if case_record.is_empty() or not bool(case_record.get("passed", false)):
		_fail("Realistic audit case is unavailable or failed: %s" % case_id)
		return false
	var response: Dictionary = case_record.get("selected_response", {}) if case_record.get("selected_response", {}) is Dictionary else {}
	if str(response.get("replyer_id", "")) != npc_id:
		_fail("Real response target mismatch for %s: %s" % [case_id, JSON.stringify(response)])
		return false
	if not _dialog_system.get_dialogue_state().is_empty():
		_dialog_system.end_dialogue("t0307_replace", {"suppress_plan_reevaluation": true})
	_dismiss_success_dialog()
	_npc_system.debug_enter_location_immediately(npc_id, "plaza", false)
	_npc_system.debug_enter_location_immediately(WITNESS_ID, "plaza", false)
	var target_before := _count_special_results(_memory_system.get_npc_daily_events(npc_id), special_type, expected_outcome)
	var witness_before := _count_special_results(_memory_system.get_npc_witness_events(WITNESS_ID), special_type, expected_outcome)
	var start_result: Dictionary = _dialog_system.start_player_dialogue(npc_id, "local_public")
	if not bool(start_result.get("ok", false)):
		_fail("Could not start replay dialogue %s: %s" % [case_id, JSON.stringify(start_result)])
		return false
	var arm_result: Dictionary
	match special_type:
		"recruitment":
			arm_result = _dialog_system.set_recruitment_request_pending(true)
		"morale_encouragement":
			arm_result = _dialog_system.set_morale_encouragement_request_pending(true)
		"work_encouragement":
			arm_result = _dialog_system.set_work_encouragement_request_pending(true)
		"combat_strategy":
			arm_result = _dialog_system.set_combat_strategy_request_pending(true)
		_:
			_fail("Unknown replay special type: %s" % special_type)
			return false
	if not bool(arm_result.get("ok", false)):
		_fail("Could not arm %s for %s: %s" % [special_type, case_id, JSON.stringify(arm_result)])
		return false
	var player_text := str(case_record.get("selected_player_text", ""))
	var send_result: Dictionary = _dialog_system.send_player_message(player_text, false, true)
	if not bool(send_result.get("ok", false)):
		_fail("Could not create pending turn for %s: %s" % [case_id, JSON.stringify(send_result)])
		return false
	var pending: Dictionary = _dialog_system.get_dialogue_state().get("pending_llm", {})
	var apply_result: Dictionary = _dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": response.duplicate(true)
	}, pending)
	await process_frame
	if not bool(apply_result.get("ok", false)):
		_fail("DialogSystem rejected real response %s: %s" % [case_id, JSON.stringify(apply_result)])
		return false
	var target_after_apply := _count_special_results(_memory_system.get_npc_daily_events(npc_id), special_type, expected_outcome)
	var witness_after_apply := _count_special_results(_memory_system.get_npc_witness_events(WITNESS_ID), special_type, expected_outcome)
	if target_after_apply != target_before + 1 or witness_after_apply != witness_before + 1:
		_fail("Real response %s did not immediately create exactly one target and witness special event" % case_id)
		return false
	var completion: Dictionary = _dialog_system.end_dialogue("t0307_real_replay", {"suppress_plan_reevaluation": true})
	await process_frame
	if not bool(completion.get("ok", false)):
		_fail("Could not complete replay dialogue %s: %s" % [case_id, JSON.stringify(completion)])
		return false
	if _count_special_results(_memory_system.get_npc_daily_events(npc_id), special_type, expected_outcome) != target_after_apply:
		_fail("Completing %s duplicated its special result event" % case_id)
		return false
	if not _assert_clean_completed_dialogue(completion.get("dialogue_event", {})):
		return false
	_dismiss_success_dialog()
	return true


func _find_case(suite: String, case_id: String) -> Dictionary:
	for raw_case in _audit_cases:
		if raw_case is Dictionary and str(raw_case.get("suite", "")) == suite and str(raw_case.get("case_id", "")) == case_id:
			return (raw_case as Dictionary).duplicate(true)
	return {}


func _assert_escape_started(npc_id: String, label: String) -> bool:
	var state: Dictionary = _npc_system.get_npc_state(npc_id)
	var intent: Dictionary = state.get("escape_intent", {}) if state.get("escape_intent", {}) is Dictionary else {}
	if (
		str(state.get("behavior_mode", "")) != "escaped"
		or str(state.get("current_action", "")) != "escaping_station"
		or not bool(intent.get("active", false))
		or str(intent.get("status", "")) != "escaping"
	):
		_fail("Real %s response did not start the authoritative escape action: %s" % [label, JSON.stringify(state)])
		return false
	return true


func _assert_clean_completed_dialogue(raw_event: Variant) -> bool:
	var event: Dictionary = raw_event if raw_event is Dictionary else {}
	if str(event.get("type", "")) != "dialogue_turn":
		_fail("Completed real replay did not create dialogue_turn")
		return false
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	for field in [
		"recruitment_result", "wartime_reaction", "combat_strategy_result",
		"work_encouragement_reaction", "is_recruitment_request",
		"is_morale_encouragement_request", "is_combat_strategy_request",
		"is_work_encouragement_request"
	]:
		if payload.has(field):
			_fail("Completed real dialogue event retained special marker %s" % field)
			return false
	for raw_turn in payload.get("dialogue_text", []):
		if not raw_turn is Dictionary:
			continue
		for field in (raw_turn as Dictionary).keys():
			if not ["speaker_id", "speaker_name", "listener_id", "listener_name", "text"].has(field):
				_fail("Completed real dialogue transcript retained special field %s" % field)
				return false
	return true


func _verify_projection_preserves_special_events(npc_id: String, witnessed: bool) -> bool:
	var raw_events: Array = _memory_system.get_npc_witness_events(npc_id) if witnessed else _memory_system.get_npc_daily_events(npc_id)
	var raw_json := JSON.stringify(raw_events)
	var raw_special := _count_all_special_results(raw_events)
	var projection: Array = _llm_bridge.build_memory_event_projection(raw_events, "witnessed" if witnessed else "experienced")
	if JSON.stringify(raw_events) != raw_json:
		_fail("T0306 projection mutated the authoritative %s archive" % ("witness" if witnessed else "event"))
		return false
	var projected_special := _count_all_special_results(projection)
	if raw_special <= 0 or projected_special != raw_special:
		_fail("T0306 projection compressed or lost special interaction facts for %s: raw=%d projected=%d" % [npc_id, raw_special, projected_special])
		return false
	for raw_event in projection:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) == "dialogue_special_interaction_result":
			var details: Dictionary = event.get("details", {}) if event.get("details", {}) is Dictionary else {}
			if details.has("aggregation"):
				_fail("Special interaction event was incorrectly aggregated for %s" % npc_id)
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


func _count_all_special_results(events: Array) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str(raw_event.get("type", "")) == "dialogue_special_interaction_result":
			count += 1
	return count


func _dismiss_success_dialog() -> void:
	if _success_dialog != null and _success_dialog.visible:
		_success_dialog.hide()
	var escape_alert := root.find_child("EscapeStartedAlertDialog", true, false) as Window
	if escape_alert != null and escape_alert.visible:
		escape_alert.hide()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
