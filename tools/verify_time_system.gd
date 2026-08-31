extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var game_state := root.get_node_or_null("GameState")
	var event_bus := root.get_node_or_null("EventBus")
	var hud := root.get_node_or_null("Main/UI/HUD")
	if time_system == null or game_state == null or event_bus == null or hud == null:
		push_error("Required time verification nodes not found")
		quit(1)
		return

	var hour_events: Array[String] = []
	var day_events: Array[int] = []
	var scale_events: Array[String] = []
	var logical_time_ticks: Array[Dictionary] = []
	event_bus.hour_started.connect(func(day: int, hour: int) -> void:
		hour_events.append("%d:%d" % [day, hour])
	)
	event_bus.day_started.connect(func(day: int) -> void:
		day_events.append(day)
	)
	event_bus.time_scale_changed.connect(func(player_scale: float, effective_scale: float, numeric_multiplier: float, reason: String) -> void:
		scale_events.append("%s:%.3f:%.3f:%.3f" % [reason, player_scale, effective_scale, numeric_multiplier])
	)
	event_bus.logical_time_tick.connect(func(game_delta_seconds: float, numeric_multiplier: float) -> void:
		logical_time_ticks.append({
			"game_delta_seconds": game_delta_seconds,
			"numeric_multiplier": numeric_multiplier
		})
	)

	time_system.set_current_time(1, 6, 0, 0)
	time_system.seconds_per_game_minute = 0.1
	time_system.set_time_scale(1.0)

	if not await _wait_until_second_changed(game_state, 30):
		push_error("Visible seconds did not advance at x1")
		quit(1)
		return
	if int(game_state.current_hour) != 6 or int(game_state.current_minute) <= 0:
		push_error("Continuous minute/second progression mismatch")
		quit(1)
		return

	time_system.set_paused(true)
	var paused_hour := int(game_state.current_hour)
	var paused_minute := int(game_state.current_minute)
	var paused_second := int(game_state.current_second)
	for frame in range(10):
		await process_frame
	if (
		int(game_state.current_hour) != paused_hour
		or int(game_state.current_minute) != paused_minute
		or int(game_state.current_second) != paused_second
	):
		push_error("Time advanced while paused")
		quit(1)
		return

	time_system.set_paused(false)
	time_system.set_current_time(1, 7, 59, 0)
	time_system.set_time_scale(4.0)
	if not is_equal_approx(float(time_system.get_combat_frame_delta_seconds(1.0)), 1.0):
		push_error("Combat presentation time must stay capped at authored x1 outside combat")
		quit(1)
		return
	if not await _wait_until_hour(game_state, 8, 30):
		push_error("Time did not advance after speed change")
		quit(1)
		return

	time_system.set_paused(true)
	time_system.set_current_time(1, 23, 0, 0)
	# Midnight normally starts eight real LLM daily-plan requests. This focused
	# TimeSystem test disconnects that external side effect while retaining all
	# authoritative clock and logical-time signals under test.
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var day_started_callback := Callable(daily_plan_system, "_on_day_started")
	if daily_plan_system != null and event_bus.day_started.is_connected(day_started_callback):
		event_bus.day_started.disconnect(day_started_callback)
	logical_time_ticks.clear()
	if not time_system.debug_advance_hour():
		push_error("Debug one-hour simulation advance was rejected")
		quit(1)
		return
	if (
		int(game_state.current_day) != 2
		or int(game_state.current_hour) != 0
		or int(game_state.current_minute) != 0
		or int(game_state.current_second) != 0
	):
		push_error("Day rollover failed")
		quit(1)
		return
	if not day_events.has(2) or not hour_events.has("2:0"):
		push_error("Time signals were not emitted for rollover")
		quit(1)
		return
	if (
		logical_time_ticks.size() != 1
		or not is_equal_approx(float(logical_time_ticks[0].get("game_delta_seconds", 0.0)), 3600.0)
		or not is_equal_approx(float(logical_time_ticks[0].get("numeric_multiplier", 0.0)), 1.0)
	):
		push_error("Debug one-hour advance should emit exactly one authoritative logical_time_tick: %s" % logical_time_ticks)
		quit(1)
		return
	if not time_system.is_paused:
		push_error("Debug simulation advance should not change the player's pause state")
		quit(1)
		return
	time_system.set_paused(false)

	var day_label := hud.get_node_or_null("DayLabel") as Label
	var time_label := hud.get_node_or_null("TimeLabel") as Label
	var speed_button := hud.get_node_or_null("SpeedButton") as Button
	var pause_button := hud.get_node_or_null("PauseButton") as Button
	if day_label == null or time_label == null:
		push_error("HUD time labels not found")
		quit(1)
		return
	if day_label.text != "第 2 天" or time_label.text != "00:00:00":
		push_error("HUD did not refresh time labels")
		quit(1)
		return
	time_system.set_current_time(2, 0, 12, 37)
	await process_frame
	if time_label.text != "00:12:00":
		push_error("Normal-speed HUD clock should freeze display seconds at 00: %s" % time_label.text)
		quit(1)
		return
	if str(time_system.format_game_duration(3661.2, true, true)) != "1小时2分00秒":
		push_error("Normal-speed duration should round up to a stable minute display")
		quit(1)
		return
	if str(hud._format_wave_countdown(61.2)) != "2分00秒":
		push_error("Normal-speed wave countdown should freeze seconds and avoid premature zero")
		quit(1)
		return
	if str(hud._format_next_wave_arrival(90061.2)) != "下一波敌军还有 1天01时来袭":
		push_error("HUD next-wave sentence should be concise and omit the wave number")
		quit(1)
		return
	if speed_button == null or pause_button == null:
		push_error("HUD time buttons not found")
		quit(1)
		return

	time_system.set_time_scale(1.0)
	time_system.set_paused(false)
	speed_button.pressed.emit()
	if float(time_system.time_scale) != 2.0 or time_system.is_paused:
		push_error("HUD speed button did not switch to x2")
		quit(1)
		return
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.pressed = true
	hud._input(space_event)
	if not time_system.is_paused or float(time_system.time_scale) != 2.0:
		push_error("Space key should only pause without changing speed")
		quit(1)
		return
	hud._input(space_event)
	if time_system.is_paused or float(time_system.time_scale) != 2.0:
		push_error("Space key should resume without changing speed")
		quit(1)
		return

	speed_button.pressed.emit()
	if float(time_system.time_scale) != 4.0 or time_system.is_paused:
		push_error("HUD speed button did not switch to x4")
		quit(1)
		return
	speed_button.pressed.emit()
	if float(time_system.time_scale) != 1.0 or time_system.is_paused:
		push_error("HUD speed button did not wrap to x1")
		quit(1)
		return

	time_system.seconds_per_game_minute = 1.0
	time_system.set_time_scale(4.0)
	time_system.request_time_slowdown("verify_llm_wait", -1.0, "llm_wait")
	if not time_system.has_time_slowdown():
		push_error("LLM slowdown request was not registered")
		quit(1)
		return
	if absf(float(time_system.get_effective_time_scale()) - (1.0 / 60.0)) > 0.001:
		push_error("LLM slowdown did not clamp effective time scale")
		quit(1)
		return
	if not speed_button.disabled or speed_button.text != "速度 x1/60" or speed_button.tooltip_text != "暂时降速：等待人物回应":
		push_error("HUD speed button should lock to the effective LLM rate with a concise reason: disabled=%s text=%s tooltip=%s" % [speed_button.disabled, speed_button.text, speed_button.tooltip_text])
		quit(1)
		return
	speed_button.pressed.emit()
	var locked_shortcut := InputEventKey.new()
	locked_shortcut.physical_keycode = KEY_1
	locked_shortcut.pressed = true
	hud._input(locked_shortcut)
	if not is_equal_approx(float(time_system.time_scale), 4.0):
		push_error("Locked HUD speed controls changed the stored player speed")
		quit(1)
		return
	if absf(float(time_system.get_numeric_delta_multiplier()) - (1.0 / 60.0)) > 0.001:
		push_error("Numeric multiplier did not follow effective time scale")
		quit(1)
		return
	if absf(float(time_system.get_game_delta_seconds(1.0)) - 1.0) > 0.001:
		push_error("LLM slowdown should make one real second equal one game second")
		quit(1)
		return
	if absf(float(time_system.get_combat_frame_delta_seconds(1.0)) - 1.0) > 0.001:
		push_error("Combat presentation time must not reapply the slowdown multiplier")
		quit(1)
		return
	var precise_clock_text := "%02d:%02d:%02d" % [
		int(game_state.current_hour),
		int(game_state.current_minute),
		int(game_state.current_second)
	]
	if time_label.text != precise_clock_text or time_label.text.ends_with(":00"):
		push_error("HUD should reveal actual seconds immediately during LLM slowdown: %s expected=%s" % [
			time_label.text,
			precise_clock_text
		])
		quit(1)
		return
	if str(time_system.format_game_duration(3661.2, true, true)) != "1小时1分02秒":
		push_error("LLM slowdown duration should reveal precise seconds")
		quit(1)
		return
	if str(hud._format_wave_countdown(61.2)) != "1分02秒":
		push_error("LLM slowdown wave countdown should reveal precise seconds")
		quit(1)
		return
	if str(hud._format_next_wave_arrival(0.0)) != "下一波敌军即将来袭":
		push_error("HUD zero countdown should use the concise imminent-arrival sentence")
		quit(1)
		return

	time_system.release_time_slowdown("verify_llm_wait")
	if time_system.has_time_slowdown() or absf(float(time_system.get_effective_time_scale()) - 4.0) > 0.001:
		push_error("LLM slowdown release did not restore player speed")
		quit(1)
		return
	if speed_button.disabled or speed_button.text != "速度 x4" or not speed_button.tooltip_text.contains("x1 / x2 / x4"):
		push_error("HUD speed button did not restore the player's chosen speed after slowdown")
		quit(1)
		return
	var stable_clock_text := "%02d:%02d:00" % [
		int(game_state.current_hour),
		int(game_state.current_minute)
	]
	if time_label.text != stable_clock_text:
		push_error("HUD should freeze seconds again immediately after LLM slowdown: %s expected=%s" % [
			time_label.text,
			stable_clock_text
		])
		quit(1)
		return
	time_system.request_time_scale_cap("verify_cap", 1.0, "verify_cap")
	if not time_system.has_time_scale_cap("verify_cap"):
		push_error("Time scale cap request was not registered")
		quit(1)
		return
	if absf(float(time_system.get_effective_time_scale()) - 1.0) > 0.001:
		push_error("Time scale cap did not clamp player x4 to x1")
		quit(1)
		return
	if not speed_button.disabled or speed_button.text != "速度 x1" or speed_button.tooltip_text != "暂时降速：系统限速":
		push_error("HUD speed button did not expose the active time cap")
		quit(1)
		return
	time_system.request_time_slowdown("verify_cap_llm_wait", -1.0, "llm_wait")
	if absf(float(time_system.get_effective_time_scale()) - (1.0 / 60.0)) > 0.001:
		push_error("LLM slowdown should be slower than a time scale cap")
		quit(1)
		return
	if speed_button.text != "速度 x1/60" or speed_button.tooltip_text != "暂时降速：等待人物回应":
		push_error("HUD speed button did not prioritize the strictest active slowdown")
		quit(1)
		return
	time_system.release_time_slowdown("verify_cap_llm_wait")
	time_system.release_time_scale_cap("verify_cap")
	if time_system.has_time_scale_cap("verify_cap") or absf(float(time_system.get_effective_time_scale()) - 4.0) > 0.001:
		push_error("Time scale cap release did not restore player speed")
		quit(1)
		return
	if speed_button.disabled or speed_button.text != "速度 x4":
		push_error("HUD speed button stayed locked after all constraints were released")
		quit(1)
		return
	if scale_events.is_empty():
		push_error("Time scale changes were not emitted")
		quit(1)
		return

	time_system.set_time_scale(1.0)

	pause_button.pressed.emit()
	if not time_system.is_paused:
		push_error("HUD pause button did not pause")
		quit(1)
		return
	if not is_zero_approx(float(time_system.get_combat_frame_delta_seconds(1.0))):
		push_error("Combat presentation time advanced while paused")
		quit(1)
		return
	pause_button.pressed.emit()
	if time_system.is_paused:
		push_error("HUD pause button did not resume")
		quit(1)
		return

	hud._unhandled_key_input(space_event)
	if not time_system.is_paused:
		push_error("Space key did not pause time")
		quit(1)
		return
	hud._unhandled_key_input(space_event)
	if time_system.is_paused:
		push_error("Space key did not resume time")
		quit(1)
		return

	if not await _verify_npc_movement_pauses(time_system):
		quit(1)
		return

	if not await _verify_action_settlement_pauses(time_system):
		quit(1)
		return

	print("T0401 time system verification passed.")
	quit(0)


func _wait_until_hour(game_state: Node, expected_hour: int, max_frames: int) -> bool:
	for frame in range(max_frames):
		await process_frame
		if int(game_state.current_hour) == expected_hour:
			return true
	return false


func _wait_until_second_changed(game_state: Node, max_frames: int) -> bool:
	var initial_minute := int(game_state.current_minute)
	var initial_second := int(game_state.current_second)
	for frame in range(max_frames):
		await process_frame
		if int(game_state.current_minute) != initial_minute or int(game_state.current_second) != initial_second:
			return true
	return false


func _verify_npc_movement_pauses(time_system: Node) -> bool:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null or npc_root.get_child_count() == 0:
		push_error("NPC root not found for pause verification")
		return false

	var npc_node := npc_root.get_child(0)
	if not npc_node.has_method("move_to_location"):
		push_error("NPC node cannot move for pause verification")
		return false

	npc_node.move_speed = 100.0
	var start_position: Vector3 = npc_node.global_position
	npc_node.move_to_location("pause_verify_target", start_position + Vector3(10.0, 0.0, 0.0))
	time_system.set_paused(true)
	for frame in range(5):
		await process_frame
	if npc_node.global_position.distance_to(start_position) > 0.001:
		push_error("NPC moved while gameplay was paused")
		return false

	time_system.set_paused(false)
	for frame in range(5):
		await process_frame
	if npc_node.global_position.distance_to(start_position) <= 0.001:
		push_error("NPC did not resume movement after gameplay pause")
		return false

	npc_node.stop_movement()
	return true


func _verify_action_settlement_pauses(time_system: Node) -> bool:
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if npc_system == null or action_system == null or resource_system == null:
		push_error("Action pause verification systems not found")
		return false

	var npc_id := "gardener_01"
	npc_system.update_npc_state(npc_id, {
		"current_location": "garden",
		"current_action": "idle"
	})
	var starting_grain := int(resource_system.get_resource("grain"))

	time_system.set_paused(true)
	if not action_system.debug_assign_action(npc_id, "work_garden"):
		push_error("Paused action assignment should be accepted for later settlement")
		return false
	if int(resource_system.get_resource("grain")) != starting_grain:
		push_error("Action resources changed while gameplay was paused")
		return false
	if not action_system.has_pending_action(npc_id):
		push_error("Paused action was not kept pending")
		return false

	time_system.set_paused(false)
	await process_frame
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		push_error("EventBus not found for action settlement verification")
		return false
	event_bus.logical_time_tick.emit(7200.0, time_system.get_numeric_delta_multiplier())
	await process_frame
	var grain_after_resume := int(resource_system.get_resource("grain"))
	if grain_after_resume <= starting_grain:
		push_error("Pending action did not settle after gameplay resumed. before=%d after=%d" % [starting_grain, grain_after_resume])
		return false
	if action_system.has_pending_action(npc_id):
		push_error("Pending action was not cleared after gameplay resumed")
		return false

	return true
