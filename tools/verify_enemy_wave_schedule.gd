extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if combat_system == null or time_system == null or hud == null or gm_panel == null:
		push_error("Wave schedule verification required nodes not found")
		quit(1)
		return

	var initial_snapshot: Dictionary = combat_system.get_wave_schedule_snapshot()
	var next_wave: Dictionary = initial_snapshot.get("next_wave", {})
	if int(next_wave.get("wave_number", 0)) != 1:
		push_error("Initial next scheduled wave should be wave 1: %s" % JSON.stringify(initial_snapshot))
		quit(1)
		return
	if int(next_wave.get("trigger_day", 0)) != 3 or int(next_wave.get("trigger_hour", -1)) != 18:
		push_error("First wave should be scheduled for day 3 at 18:00")
		quit(1)
		return

	var wave_label := hud.get_node_or_null("WaveCountdownLabel") as Label
	if wave_label == null:
		push_error("HUD should expose WaveCountdownLabel")
		quit(1)
		return
	hud._refresh_wave_countdown()
	if not wave_label.text.contains("第1波"):
		push_error("HUD countdown should mention wave 1: %s" % wave_label.text)
		quit(1)
		return

	time_system.set_current_time(3, 17, 59, 30)
	combat_system._on_logical_time_tick(29.0, 1.0)
	if combat_system.get_active_enemy_count() != 0:
		push_error("Wave should not spawn before the configured trigger time")
		quit(1)
		return

	time_system.set_current_time(3, 17, 59, 59)
	combat_system._on_logical_time_tick(1.0, 1.0)
	var wave_one_count := _wave_enemy_count(combat_system.get_wave_config(1))
	if combat_system.get_active_enemy_count() != wave_one_count:
		push_error("Wave 1 should auto-spawn exactly at the configured trigger time")
		quit(1)
		return

	var after_auto: Dictionary = combat_system.get_wave_schedule_snapshot()
	var triggered: Array = after_auto.get("triggered_wave_numbers", [])
	if not triggered.has(1):
		push_error("Auto-spawned wave 1 should be marked as triggered")
		quit(1)
		return
	if int((after_auto.get("next_wave", {}) as Dictionary).get("wave_number", 0)) != 2:
		push_error("Next pending wave after auto wave 1 should be wave 2")
		quit(1)
		return

	time_system.set_current_time(3, 18, 5, 0)
	combat_system._on_logical_time_tick(60.0, 1.0)
	if combat_system.get_active_enemy_count() != wave_one_count:
		push_error("Auto scheduler should not duplicate an already triggered wave")
		quit(1)
		return

	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var gm_button := root.get_node_or_null("Main/UI/GMPanel/GMButton") as Button
	if gm_button == null:
		push_error("GM button missing")
		quit(1)
		return
	gm_button.pressed.emit()
	await process_frame
	gm_window = root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var next_wave_button := gm_window.find_child("TriggerNextWaveButton", true, false) as Button
	if next_wave_button == null:
		push_error("GMPanel should expose TriggerNextWaveButton")
		quit(1)
		return
	next_wave_button.pressed.emit()
	await process_frame
	var wave_two_count := _wave_enemy_count(combat_system.get_wave_config(2))
	if combat_system.get_active_enemy_count() != wave_one_count + wave_two_count:
		push_error("GM next wave button should spawn the next pending wave")
		quit(1)
		return
	if int((combat_system.get_wave_schedule_snapshot().get("next_wave", {}) as Dictionary).get("wave_number", 0)) != 3:
		push_error("Next pending wave after GM jump should be wave 3")
		quit(1)
		return

	gm_panel._execute_command("next_wave")
	await process_frame
	var wave_three_count := _wave_enemy_count(combat_system.get_wave_config(3))
	if combat_system.get_active_enemy_count() != wave_one_count + wave_two_count + wave_three_count:
		push_error("GM next_wave command should spawn the next pending wave")
		quit(1)
		return

	hud._refresh_wave_countdown()
	if not wave_label.text.contains("第4波"):
		push_error("HUD countdown should advance after manual wave jumps: %s" % wave_label.text)
		quit(1)
		return

	combat_system.debug_clear_enemies()
	print("Enemy wave schedule verification passed.")
	quit(0)


func _wave_enemy_count(wave: Dictionary) -> int:
	var total := 0
	for raw_enemy in (wave.get("enemies", []) as Array):
		var enemy: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
		total += int(enemy.get("count", 0))
	return total
