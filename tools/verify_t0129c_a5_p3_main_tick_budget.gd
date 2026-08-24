extends SceneTree


const SAMPLE_COUNT := 600
const WARMUP_COUNT := 60
const MAX_P95_MAIN_TICK_MS := 16.67
const MAX_P95_ISOLATED_COMBAT_MS := 16.67


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var isolated := await _run_benchmark(false)
	if isolated.is_empty():
		return
	var integrated := await _run_benchmark(true)
	if integrated.is_empty():
		return
	if float(isolated.get("p95_ms", INF)) > MAX_P95_ISOLATED_COMBAT_MS:
		_fail("isolated CombatSystem exceeded 60 FPS budget: %s" % JSON.stringify(isolated))
		return
	if float(integrated.get("p95_ms", INF)) > MAX_P95_MAIN_TICK_MS:
		_fail("integrated Main tick exceeded 60 FPS budget: %s" % JSON.stringify(integrated))
		return
	print("A5-P3 Main tick budget verification passed: %s" % JSON.stringify({
		"sample_count": SAMPLE_COUNT,
		"isolated_combat": isolated,
		"integrated_main": integrated,
		"integrated_to_isolated_ratio": (
			float(integrated.get("p95_ms", 0.0)) / maxf(0.001, float(isolated.get("p95_ms", 0.0)))
		),
	}))
	quit(0)


func _run_benchmark(integrated_main: bool) -> Dictionary:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.game_over = false
		game_state.game_result = ""
		game_state.game_over_reason = ""
		game_state.failure_reason = ""
		game_state.settlement_snapshot = {}
		game_state.set_combat_active(false)
		game_state.set_time(1, 6, 0, 0)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return {}
	var main_instance := packed.instantiate()
	var startup := main_instance.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main_instance)
	await process_frame
	await physics_frame
	await physics_frame
	var combat := main_instance.get_node_or_null("Systems/CombatSystem")
	var time_system := main_instance.get_node_or_null("Systems/TimeSystem")
	if combat == null or time_system == null:
		_fail("benchmark systems are missing")
		return {}
	var spawn_result: Dictionary = combat.spawn_wave(5, true, "a5_p3_main_tick_budget")
	if not bool(spawn_result.get("ok", false)) or int(spawn_result.get("spawned_count", 0)) != 48:
		_fail("fifth wave spawn failed: %s" % JSON.stringify(spawn_result))
		return {}
	time_system.set_process(false)
	var hud_snapshot: Dictionary = combat.get_wave_hud_snapshot()
	if (
		not hud_snapshot.has("active_enemy_count")
		or int(hud_snapshot.get("active_enemy_count", 0)) != 48
		or hud_snapshot.has("last_auto_wave_result")
		or hud_snapshot.has("active_battle")
	):
		_fail("lightweight HUD wave snapshot contract failed: %s" % JSON.stringify(hud_snapshot))
		return {}
	var hud := main_instance.get_node_or_null("UI/HUD")
	var merchant := main_instance.get_node_or_null("Systems/MerchantSystem")
	if hud == null or merchant == null:
		_fail("time projection consumers are missing")
		return {}
	hud._last_clock_refresh_key = ""
	hud._on_time_changed(1, 6, 5, 11)
	if str(hud._last_clock_refresh_key) != "1:6:5:0":
		_fail("normal HUD refresh did not coalesce to game-minute precision")
		return {}
	time_system.request_time_slowdown("a5_p3_precision_contract")
	hud._on_time_changed(1, 6, 5, 12)
	if str(hud._last_clock_refresh_key) != "1:6:5:12":
		_fail("LLM slowdown HUD refresh lost precise-second display")
		return {}
	time_system.release_time_slowdown("a5_p3_precision_contract")
	merchant._last_evaluated_minute_key = ""
	merchant._on_time_changed(1, 6, 5, 11)
	if str(merchant._last_evaluated_minute_key) != "1:6:5":
		_fail("merchant refresh did not retain minute-level schedule checks")
		return {}
	for _index in range(30):
		await physics_frame
	var callback: Callable
	if integrated_main:
		callback = func() -> void: time_system._advance_simulation_time(1.0, 1.0)
	else:
		callback = func() -> void: combat._on_logical_time_tick(1.0, 1.0)
	for _index in range(WARMUP_COUNT):
		callback.call()
		await process_frame
	var samples: Array[float] = []
	for _index in range(SAMPLE_COUNT):
		var started := Time.get_ticks_usec()
		callback.call()
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		await process_frame
	samples.sort()
	var result := {
		"average_ms": _average(samples),
		"p50_ms": _percentile(samples, 0.50),
		"p95_ms": _percentile(samples, 0.95),
		"max_ms": samples[-1] if not samples.is_empty() else 0.0,
	}
	var clear_result: Dictionary = combat.clear_spawned_enemies()
	if not bool(clear_result.get("ok", false)):
		_fail("cleanup failed: %s" % JSON.stringify(clear_result))
		return {}
	main_instance.queue_free()
	await process_frame
	await process_frame
	return result


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(ceili(float(values.size()) * percentile) - 1, 0, values.size() - 1)
	return values[index]


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
