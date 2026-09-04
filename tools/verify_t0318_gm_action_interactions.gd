extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if startup == null or npc_system == null or action_system == null or time_system == null or gm_panel == null:
		_fail("T0318 required Main systems are missing")
		return
	time_system.set_paused(false)

	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var guard_button := gm_window.find_child("FormalGuardDialogueButton", true, false) as Button
	var guard_input := gm_window.find_child("FormalGuardDialogueInput", true, false) as LineEdit
	var action_select := gm_window.find_child("FormalActionNpcSelect", true, false) as OptionButton
	if guard_button == null or guard_input == null or action_select == null:
		_fail("Formal action tab is missing the NPC-to-guard dialogue controls")
		return
	_select_id(action_select, "stableman_01")
	guard_input.text = "守备官，我想验收这次主动交涉。"
	guard_button.pressed.emit()
	var proactive: Dictionary = npc_system.get_proactive_talk("stableman_01")
	if not bool(proactive.get("active", false)) or str(proactive.get("prompt_text", "")) != guard_input.text:
		_fail("Formal action guard-dialogue button did not use the existing proactive-talk authority")
		return
	npc_system.cancel_proactive_talk("stableman_01", "verify_t0318_cleanup")

	for npc_id in ["cook_01", "doctor_01"]:
		npc_system.update_npc_state(npc_id, {
			"current_action": "planning_day",
			"last_action_result": "daily_plan_pending"
		})
	startup.call("_release_failed_planning_states", "daily_plan_batch_failed", "真实 provider 失败。")
	for npc_id in ["cook_01", "doctor_01"]:
		var released_state: Dictionary = npc_system.get_npc_state(npc_id)
		if (
			str(released_state.get("current_action", "")) != "idle"
			or str(released_state.get("last_action_result", "")) != "daily_plan_failed"
			or str((released_state.get("last_action_failure_context", {}) as Dictionary).get("reason", "")) != "daily_plan_batch_failed"
		):
			_fail("Failed startup planning marker was not released for %s" % npc_id)
			return

	npc_system.update_npc_state("cook_01", {
		"current_action": "planning_day",
		"last_action_result": "daily_plan_pending"
	})
	npc_system.set_npc_llm_activity("cook_01", {
		"active": true,
		"kind": "plan",
		"request_id": "verify_t0318_active_plan",
		"cancellable": true
	})
	if not bool(action_system.call("_is_npc_plan_generation_busy", "cook_01", npc_system)):
		_fail("A real active plan request was not treated as busy")
		return
	npc_system.clear_npc_llm_activity("cook_01", "verify_t0318_active_plan")
	if bool(action_system.call("_is_npc_plan_generation_busy", "cook_01", npc_system)):
		_fail("A stale planning_day marker without a request still blocks NPC dialogue")
		return
	npc_system.update_npc_state("cook_01", {"current_action": "idle"})

	var damage_result: Dictionary = npc_system.debug_damage_npc("cook_01", 9999, "local_public")
	if not bool(damage_result.get("ok", false)):
		_fail("Could not prepare an unconscious GM healing target")
		return
	gm_panel.call("_refresh_options")
	var heal_select := gm_window.find_child("HealTargetSelect", true, false) as OptionButton
	if (
		heal_select == null
		or heal_select.get_item_count() == 0
		or str(heal_select.get_item_metadata(0)) != "cook_01"
		or not heal_select.get_item_text(0).contains("可治疗：昏迷")
	):
		_fail("GM healing selector does not prioritize and explain the unconscious target")
		return

	print("T0318 GM action interaction verification passed.")
	quit(0)


func _select_id(select: OptionButton, target_id: String) -> void:
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == target_id:
			select.select(index)
			return


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
