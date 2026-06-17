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
	await process_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if time_system == null or combat_system == null:
		push_error("Combat time cap verification required systems not found")
		quit(1)
		return

	time_system.seconds_per_game_minute = 1.0
	time_system.set_paused(false)
	time_system.clear_time_slowdowns()
	time_system.clear_time_scale_caps()
	time_system.set_time_scale(4.0)

	if not _assert_close(float(time_system.get_effective_time_scale()), 4.0, "Player x4 should be effective before enemies"):
		quit(1)
		return
	if not _assert_close(float(time_system.get_game_delta_seconds(1.0)), 240.0, "x4 should advance 240 game seconds per real second before enemies"):
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	if int(combat_system.get_active_enemy_count()) <= 0:
		push_error("Enemy spawn did not create active enemies")
		quit(1)
		return
	if not time_system.has_time_scale_cap("combat_enemy_presence"):
		push_error("Active enemies should register combat time scale cap")
		quit(1)
		return
	if not _assert_close(float(time_system.time_scale), 4.0, "Combat cap should preserve player selected scale"):
		quit(1)
		return
	if not _assert_close(float(time_system.get_effective_time_scale()), 1.0, "Active enemies should cap effective scale to x1"):
		quit(1)
		return
	if not _assert_close(float(time_system.get_game_delta_seconds(1.0)), 60.0, "Active enemies should cap one real second to 60 game seconds"):
		quit(1)
		return

	time_system.request_time_slowdown("verify_llm_wait", 1.0 / 60.0, "verify_llm_wait")
	if not _assert_close(float(time_system.get_effective_time_scale()), 1.0 / 60.0, "LLM slowdown should remain slower than combat x1 cap"):
		quit(1)
		return
	if not _assert_close(float(time_system.get_game_delta_seconds(1.0)), 1.0, "LLM slowdown during combat should make one real second equal one game second"):
		quit(1)
		return

	time_system.release_time_slowdown("verify_llm_wait")
	if not _assert_close(float(time_system.get_effective_time_scale()), 1.0, "Combat cap should restore to x1 after LLM release while enemies remain"):
		quit(1)
		return

	var clear_result: Dictionary = combat_system.debug_clear_enemies()
	if not bool(clear_result.get("ok", false)):
		push_error("Enemy clear failed: %s" % JSON.stringify(clear_result))
		quit(1)
		return
	if time_system.has_time_scale_cap("combat_enemy_presence"):
		push_error("Combat time cap should be released after all enemies disappear")
		quit(1)
		return
	if not _assert_close(float(time_system.get_effective_time_scale()), 4.0, "Clearing enemies should restore player x4 effective scale"):
		quit(1)
		return
	if not _assert_close(float(time_system.get_game_delta_seconds(1.0)), 240.0, "Clearing enemies should restore normal x4 game delta"):
		quit(1)
		return

	var snapshot: Dictionary = time_system.get_time_scale_snapshot()
	if int(snapshot.get("time_scale_cap_count", -1)) != 0:
		push_error("Time snapshot should show no cap requests after clear: %s" % JSON.stringify(snapshot))
		quit(1)
		return

	print("Combat time cap verification passed.")
	quit(0)


func _assert_close(actual: float, expected: float, message: String) -> bool:
	if absf(actual - expected) <= 0.001:
		return true
	push_error("%s. expected=%.6f actual=%.6f" % [message, expected, actual])
	return false
