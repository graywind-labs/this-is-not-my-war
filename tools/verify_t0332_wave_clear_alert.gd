extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("T0332 could not load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var alert := root.get_node_or_null("Main/UI/HUD/WaveClearedAlertDialog") as AcceptDialog
	var event_bus := root.get_node_or_null("EventBus")
	var game_state := root.get_node_or_null("GameState")
	if combat_system == null or hud == null or alert == null or event_bus == null or game_state == null:
		_fail("T0332 required nodes not found")
		return
	if alert.visible or alert.get_ok_button().text != "太好了":
		_fail("T0332 alert initial state or button text mismatch")
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("T0332 could not spawn wave 1: %s" % JSON.stringify(spawn_result))
		return
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		_fail("T0332 wave 1 spawned no enemies")
		return
	for index in range(enemy_ids.size()):
		var enemy_id := enemy_ids[index]
		var enemy: Dictionary = combat_system.get_enemy(enemy_id)
		var actor_npc_id := "" if index == 0 else "veteran_deputy_01"
		var source_context := {
			"source_type": "defense_device" if actor_npc_id.is_empty() else "npc",
			"deployment_id": "verify_device"
		}
		var damage_result: Dictionary = combat_system._apply_damage_to_enemy(
			enemy_id,
			maxi(1, int(enemy.get("hp", 1))),
			actor_npc_id,
			source_context
		)
		if not bool(damage_result.get("defeated", false)):
			_fail("T0332 failed to defeat %s" % enemy_id)
			return
	var clear_result: Dictionary = combat_system._handle_all_enemies_cleared("verify_t0332_all_defeated")
	await process_frame
	if clear_result.get("wave_clear_notification_numbers", []) != [1]:
		_fail("T0332 authoritative clear did not notify wave 1: %s" % JSON.stringify(clear_result))
		return
	var snapshot: Dictionary = hud.debug_get_wave_cleared_alert_snapshot()
	if (
		not bool(snapshot.get("visible", false))
		or str(snapshot.get("dialog_text", "")) != "恭喜守备官守住了第1波敌军！"
		or str(snapshot.get("ok_button_text", "")) != "太好了"
	):
		_fail("T0332 wave 1 alert content mismatch: %s" % JSON.stringify(snapshot))
		return
	alert.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	if alert.visible:
		_fail("T0332 太好了 did not close the wave 1 alert")
		return

	var debug_spawn: Dictionary = combat_system.debug_spawn_wave(2, true, true)
	if not bool(debug_spawn.get("ok", false)):
		_fail("T0332 could not spawn wave 2 for debug-clear guard")
		return
	var debug_clear: Dictionary = combat_system.debug_clear_enemies()
	await process_frame
	var debug_mode_exit: Dictionary = debug_clear.get("mode_exit_result", {}) if debug_clear.get("mode_exit_result", {}) is Dictionary else {}
	if alert.visible or not (debug_mode_exit.get("wave_clear_notification_numbers", []) as Array).is_empty():
		_fail("T0332 GM clear must not produce a success alert: %s" % JSON.stringify(debug_clear))
		return

	event_bus.combat_wave_cleared.emit(2)
	event_bus.combat_wave_cleared.emit(2)
	event_bus.combat_wave_cleared.emit(3)
	await process_frame
	snapshot = hud.debug_get_wave_cleared_alert_snapshot()
	if int(snapshot.get("current_wave_number", 0)) != 2 or snapshot.get("queued_wave_numbers", []) != [3]:
		_fail("T0332 alert queue or duplicate guard mismatch: %s" % JSON.stringify(snapshot))
		return
	alert.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	if not alert.visible or alert.dialog_text != "恭喜守备官守住了第3波敌军！":
		_fail("T0332 queued wave 3 alert did not advance")
		return
	alert.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	if alert.visible:
		_fail("T0332 final queued alert did not close")
		return

	game_state.set_game_over("victory", "five_waves_survived")
	var victory_notifications: Array[int] = combat_system._emit_successful_wave_clear_events({
		"ok": true,
		"wave_number": 5,
		"started_enemy_count": 1,
		"resolved_defeated_enemy_count": 1,
		"remaining_enemy_count": 0,
		"additional_waves": []
	})
	await process_frame
	if victory_notifications != [5] or not alert.visible or alert.dialog_text != "恭喜守备官守住了第5波敌军！":
		_fail("T0332 final victory must retain the wave 5 alert")
		return
	alert.get_ok_button().pressed.emit()
	await process_frame
	await process_frame

	game_state.set_game_over("failure", "verify_t0332_failure")
	var failure_notifications: Array[int] = combat_system._emit_successful_wave_clear_events({
		"ok": true,
		"wave_number": 4,
		"started_enemy_count": 1,
		"resolved_defeated_enemy_count": 1,
		"remaining_enemy_count": 0,
		"additional_waves": []
	})
	await process_frame
	if not failure_notifications.is_empty() or alert.visible:
		_fail("T0332 failure state must suppress success alerts")
		return

	print("T0332_WAVE_CLEAR_ALERT_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
