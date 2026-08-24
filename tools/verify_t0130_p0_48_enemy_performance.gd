extends SceneTree


const ENEMY_SCENE := preload("res://scenes/characters/EnemySwordShieldChibiPilot.tscn")
const ENEMY_COUNT := 48
const SAMPLE_FRAMES := 180
const MAX_SETUP_MILLISECONDS := 10000.0
const MAX_HEADLESS_FRAME_MILLISECONDS := 16.7

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run_benchmark")


func run_benchmark() -> void:
	var benchmark_root := Node3D.new()
	root.add_child(benchmark_root)
	var memory_before := float(Performance.get_monitor(Performance.MEMORY_STATIC))
	var setup_start := Time.get_ticks_usec()
	var enemies: Array[Node] = []
	var library_instance_id := 0
	for enemy_index in ENEMY_COUNT:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.position = Vector3(float(enemy_index % 8) * 1.5, 0.0, float(enemy_index / 8) * 1.5)
		benchmark_root.add_child(enemy)
		enemies.append(enemy)
		var player := enemy.get_node_or_null("PilotAnimationPlayer") as AnimationPlayer
		check(player != null, "enemy %d is missing AnimationPlayer" % enemy_index)
		if player != null:
			var library := player.get_animation_library("")
			if enemy_index == 0:
				library_instance_id = library.get_instance_id()
			else:
				check(library.get_instance_id() == library_instance_id, "enemy %d duplicated the shared animation library" % enemy_index)
		var state_name: String = ["idle", "walk", "attack", "hit_react"][enemy_index % 4]
		var result: Dictionary = enemy.call("debug_force_animation_state", state_name)
		check(bool(result.get("ready", false)), "enemy %d did not become ready" % enemy_index)
	var setup_milliseconds := float(Time.get_ticks_usec() - setup_start) / 1000.0
	await process_frame
	await process_frame

	var sample_start := Time.get_ticks_usec()
	for frame_index in SAMPLE_FRAMES:
		if frame_index == 60 or frame_index == 120:
			for enemy_index in enemies.size():
				var next_state: String = ["walk", "attack", "idle", "run"][(enemy_index + int(frame_index / 60)) % 4]
				enemies[enemy_index].call("debug_force_animation_state", next_state)
		await process_frame
	var sample_milliseconds := float(Time.get_ticks_usec() - sample_start) / 1000.0
	var average_frame_milliseconds := sample_milliseconds / float(SAMPLE_FRAMES)
	var memory_after := float(Performance.get_monitor(Performance.MEMORY_STATIC))
	var memory_delta_megabytes := (memory_after - memory_before) / (1024.0 * 1024.0)

	check(enemies.size() == ENEMY_COUNT, "enemy count mismatch")
	check(setup_milliseconds <= MAX_SETUP_MILLISECONDS, "48-enemy setup took %.2f ms" % setup_milliseconds)
	check(average_frame_milliseconds <= MAX_HEADLESS_FRAME_MILLISECONDS, "48-enemy headless frame average is %.3f ms" % average_frame_milliseconds)
	print("T0130_P0_48_ENEMY setup_ms=%.2f sample_frames=%d average_frame_ms=%.3f memory_delta_mb=%.2f shared_library_id=%d" % [
		setup_milliseconds,
		SAMPLE_FRAMES,
		average_frame_milliseconds,
		memory_delta_megabytes,
		library_instance_id,
	])
	if _failures.is_empty():
		print("T0130_P0_48_ENEMY PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("T0130_P0_48_ENEMY FAIL count=%d" % _failures.size())
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
