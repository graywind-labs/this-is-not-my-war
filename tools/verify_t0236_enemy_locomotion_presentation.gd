extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const SAMPLE_DELTA_SECONDS := 0.1

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and time_system != null, "T0236 production systems are missing")
	if combat_system == null or time_system == null:
		_finish()
		return
	time_system.set_paused(false)
	var spawned: Dictionary = combat_system.spawn_wave(5, true, "t0236_enemy_locomotion", "front_gate")
	_check(bool(spawned.get("ok", false)), "T0236 could not spawn the fifth-wave presentation fixture: %s" % spawned)
	for _frame in range(6):
		await process_frame
		await physics_frame

	var foot_enemy_id := _find_enemy_id(combat_system, false)
	var mounted_enemy_id := _find_enemy_id(combat_system, true)
	_check(not foot_enemy_id.is_empty(), "T0236 fifth wave has no foot enemy")
	_check(not mounted_enemy_id.is_empty(), "T0236 fifth wave has no mounted enemy")
	if not foot_enemy_id.is_empty():
		_exercise_motion_projection(combat_system, foot_enemy_id, false)
	if not mounted_enemy_id.is_empty():
		_exercise_motion_projection(combat_system, mounted_enemy_id, true)

	combat_system.debug_clear_enemies()
	_finish()


func _exercise_motion_projection(combat_system: Node, enemy_id: String, mounted: bool) -> void:
	var enemy_paths: Dictionary = combat_system.get("_enemy_nodes")
	var actor := combat_system.get_node_or_null(enemy_paths.get(enemy_id, NodePath(""))) as ActorMotionBody
	_check(actor != null, "T0236 actor is missing for %s" % enemy_id)
	if actor == null:
		return
	_check(actor.is_motion_active(), "T0236 spawned actor has no active movement intent for %s" % enemy_id)
	var enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = enemies.get(enemy_id, {}).duplicate(true)
	enemy["current_action"] = "waiting_for_attack_position"
	enemy["attack_cycle_phase"] = "idle"
	enemy["attack_cycle_elapsed"] = 0.0
	enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", enemies)

	var slices: Dictionary = combat_system.get("_formal_first_wave_slices")
	var slice: Dictionary = slices.get(enemy_id, {}).duplicate(true)
	slice["presentation_previous_position"] = actor.global_position - Vector3(0.006, 0.0, 0.0)
	slice["presentation_movement_active"] = false
	slice["presentation_stationary_seconds"] = 0.0
	slices[enemy_id] = slice
	combat_system.set("_formal_first_wave_slices", slices)
	combat_system._sync_formal_first_wave_presentation(SAMPLE_DELTA_SECONDS)

	var slow_art := _get_enemy_art_snapshot(combat_system, enemy_id)
	var expected_locomotion := "mounted_walk" if mounted else "run"
	var expected_locomotion_clip := "Mounted_Walk" if mounted else "Running_A"
	_check(bool(slow_art.get("logical_moving", false)), "T0236 %s slid during slow crowded travel" % enemy_id)
	_check(str(slow_art.get("desired_state", "")) == expected_locomotion, "T0236 %s ignored slow actual travel: %s" % [enemy_id, slow_art.get("desired_state", "")])
	_check(str(slow_art.get("current_clip", "")) == expected_locomotion_clip, "T0236 %s did not start locomotion clip: %s" % [enemy_id, slow_art.get("current_clip", "")])
	_check(bool(slow_art.get("current_animation_playing", false)), "T0236 %s locomotion AnimationPlayer is not playing" % enemy_id)
	_check(float(slow_art.get("locomotion_animation_speed_scale", 0.0)) > 0.0, "T0236 %s locomotion playback speed is zero" % enemy_id)
	_check(float(slow_art.get("movement_speed", 0.0)) >= 0.059, "T0236 %s did not project slow planar speed" % enemy_id)

	slices = combat_system.get("_formal_first_wave_slices")
	slice = slices.get(enemy_id, {}).duplicate(true)
	slice["presentation_previous_position"] = actor.global_position - Vector3(0.5, 0.0, 0.0)
	slice["presentation_movement_active"] = false
	slice["presentation_stationary_seconds"] = 0.0
	slices[enemy_id] = slice
	combat_system.set("_formal_first_wave_slices", slices)
	combat_system._sync_formal_first_wave_presentation(SAMPLE_DELTA_SECONDS)

	var moving_art := _get_enemy_art_snapshot(combat_system, enemy_id)
	_check(bool(moving_art.get("logical_moving", false)), "T0236 %s ignored actual displacement while action text was waiting" % enemy_id)
	_check(str(moving_art.get("desired_state", "")) == expected_locomotion, "T0236 %s slid without %s: %s" % [enemy_id, expected_locomotion, moving_art.get("desired_state", "")])
	_check(float(moving_art.get("movement_speed", 0.0)) >= 4.9, "T0236 %s did not project measured planar speed" % enemy_id)
	if mounted:
		_check(str(moving_art.get("horse_animation", "")) == "Walk", "T0236 mounted horse did not enter Walk")

	for _sample in range(3):
		slices = combat_system.get("_formal_first_wave_slices")
		slice = slices.get(enemy_id, {}).duplicate(true)
		slice["presentation_previous_position"] = actor.global_position
		slices[enemy_id] = slice
		combat_system.set("_formal_first_wave_slices", slices)
		combat_system._sync_formal_first_wave_presentation(SAMPLE_DELTA_SECONDS)
	var stopped_art := _get_enemy_art_snapshot(combat_system, enemy_id)
	var expected_stopped := "vehicle_seated" if mounted else "idle"
	_check(not bool(stopped_art.get("logical_moving", true)), "T0236 %s kept locomotion after actual movement stopped" % enemy_id)
	_check(str(stopped_art.get("desired_state", "")) == expected_stopped, "T0236 %s did not hand off to %s after stopping: %s" % [enemy_id, expected_stopped, stopped_art.get("desired_state", "")])
	if mounted:
		_check(str(stopped_art.get("horse_animation", "")) == "Idle", "T0236 mounted horse did not return to Idle")

	enemies = combat_system.get("_active_enemies")
	enemy = enemies.get(enemy_id, {}).duplicate(true)
	enemy["current_action"] = "winding_up_t0236_target"
	enemy["attack_cycle_phase"] = "windup"
	enemy["attack_cycle_elapsed"] = 0.1
	enemy["attack_sequence"] = int(enemy.get("attack_sequence", 0)) + 1
	enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", enemies)
	slices = combat_system.get("_formal_first_wave_slices")
	slice = slices.get(enemy_id, {}).duplicate(true)
	slice["presentation_previous_position"] = actor.global_position - Vector3(0.5, 0.0, 0.0)
	slices[enemy_id] = slice
	combat_system.set("_formal_first_wave_slices", slices)
	combat_system._sync_formal_first_wave_presentation(SAMPLE_DELTA_SECONDS)
	var attack_art := _get_enemy_art_snapshot(combat_system, enemy_id)
	var expected_attack := "mounted_attack" if mounted else "attack"
	_check(not bool(attack_art.get("logical_moving", true)), "T0236 %s movement projection overrode attack priority" % enemy_id)
	_check(str(attack_art.get("desired_state", "")) == expected_attack, "T0236 %s did not preserve %s priority: %s" % [enemy_id, expected_attack, attack_art.get("desired_state", "")])


func _find_enemy_id(combat_system: Node, mounted: bool) -> String:
	for enemy_id in combat_system.get_active_enemy_ids():
		var enemy: Dictionary = combat_system.get_enemy(enemy_id)
		var is_mounted := str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"]
		if is_mounted == mounted:
			return enemy_id
	return ""


func _get_enemy_art_snapshot(combat_system: Node, enemy_id: String) -> Dictionary:
	for entry in combat_system.debug_get_enemy_art_snapshots():
		if str(entry.get("enemy_id", "")) == enemy_id:
			return entry.get("art", {}) as Dictionary
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0236_ENEMY_LOCOMOTION_PRESENTATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0236_ENEMY_LOCOMOTION_PRESENTATION FAIL count=%d" % _failures.size())
	quit(1)
