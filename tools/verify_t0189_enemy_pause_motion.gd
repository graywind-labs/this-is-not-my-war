extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const POSITION_EPSILON := 0.001

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	_check(time_system != null and combat_system != null, "T0189 systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_time_scale(1.0)
	time_system.set_paused(false)
	await _verify_navigation_pilot_pause(time_system, combat_system)
	await _verify_formal_wave_pause(time_system, combat_system)
	combat_system.clear_spawned_enemies()
	time_system.set_paused(false)
	_finish()


func _verify_navigation_pilot_pause(time_system: Node, combat_system: Node) -> void:
	var started: Dictionary = combat_system.debug_run_formal_enemy_navigation_pilot()
	_check(bool(started.get("ok", false)), "T0189 navigation pilot could not start: %s" % started)
	if not bool(started.get("ok", false)):
		return
	var initial: Dictionary = combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()
	var initial_position: Vector3 = initial.get("world_position", Vector3.ZERO)
	var moved := false
	for _frame in range(90):
		await process_frame
		await physics_frame
		var live: Dictionary = combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()
		if Vector3(live.get("world_position", initial_position)).distance_to(initial_position) > 0.08:
			moved = true
			break
	_check(moved, "T0189 navigation pilot did not begin physical movement")

	var before: Dictionary = combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()
	var motion_before: Dictionary = before.get("motion", {})
	var position_before: Vector3 = before.get("world_position", Vector3.ZERO)
	var request_before := str(motion_before.get("request_id", ""))
	var phase_before := str(before.get("phase", ""))
	time_system.set_paused(true)
	for _frame in range(75):
		await process_frame
		await physics_frame
	var paused: Dictionary = combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()
	var paused_motion: Dictionary = paused.get("motion", {})
	var paused_position: Vector3 = paused.get("world_position", Vector3.ZERO)
	_check(paused_position.distance_to(position_before) <= POSITION_EPSILON, "T0189 paused pilot slid: before=%s after=%s" % [position_before, paused_position])
	_check(bool(paused_motion.get("paused", false)), "T0189 paused pilot motion snapshot is not paused: %s" % paused_motion)
	_check(Vector3(paused_motion.get("velocity", Vector3.ZERO)).length() <= POSITION_EPSILON, "T0189 paused pilot retained velocity: %s" % paused_motion.get("velocity", Vector3.ZERO))
	_check(str(paused_motion.get("request_id", "")) == request_before, "T0189 paused pilot replaced its navigation request")
	_check(str(paused.get("phase", "")) == phase_before, "T0189 paused pilot route phase advanced")

	time_system.set_paused(false)
	var resumed := false
	for _frame in range(90):
		await process_frame
		await physics_frame
		var live: Dictionary = combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()
		if Vector3(live.get("world_position", paused_position)).distance_to(paused_position) > 0.08:
			resumed = true
			break
	_check(resumed, "T0189 navigation pilot did not resume its route")
	combat_system.debug_stop_formal_enemy_navigation_pilot("t0189_pilot_complete")
	for _frame in range(2):
		await process_frame
		await physics_frame


func _verify_formal_wave_pause(time_system: Node, combat_system: Node) -> void:
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(4)
	_check(bool(started.get("ok", false)), "T0189 mounted formal wave could not start: %s" % started)
	if not bool(started.get("ok", false)):
		return
	for _frame in range(45):
		await process_frame
		await physics_frame
	var before: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	var before_by_id := _index_slices(before.get("slices", []))
	_check(not before_by_id.is_empty(), "T0189 formal wave has no physical actors")
	_check(int((before.get("unit_type_counts", {}) as Dictionary).get("cavalry", 0)) > 0, "T0189 formal wave fixture has no mounted enemy")
	var any_moving := false
	for raw_slice in before_by_id.values():
		var slice := raw_slice as Dictionary
		var motion: Dictionary = slice.get("motion", {})
		if Vector3(motion.get("velocity", Vector3.ZERO)).length() > 0.05:
			any_moving = true
			break
	_check(any_moving, "T0189 formal wave did not enter physical movement before pause")

	time_system.set_paused(true)
	for _frame in range(75):
		await process_frame
		await physics_frame
	var paused: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	var paused_by_id := _index_slices(paused.get("slices", []))
	_check(paused_by_id.size() == before_by_id.size(), "T0189 enemy count changed while paused")
	for raw_enemy_id in before_by_id.keys():
		var enemy_id := str(raw_enemy_id)
		var before_slice: Dictionary = before_by_id[enemy_id]
		var paused_slice: Dictionary = paused_by_id.get(enemy_id, {})
		_check(not paused_slice.is_empty(), "T0189 paused wave lost actor %s" % enemy_id)
		if paused_slice.is_empty():
			continue
		var before_position: Vector3 = before_slice.get("world_position", Vector3.ZERO)
		var paused_position: Vector3 = paused_slice.get("world_position", Vector3.ZERO)
		var before_motion: Dictionary = before_slice.get("motion", {})
		var paused_motion: Dictionary = paused_slice.get("motion", {})
		var before_enemy: Dictionary = before_slice.get("enemy", {})
		var paused_enemy: Dictionary = paused_slice.get("enemy", {})
		_check(paused_position.distance_to(before_position) <= POSITION_EPSILON, "T0189 paused enemy %s slid: %.6f m" % [enemy_id, paused_position.distance_to(before_position)])
		_check(Vector3(paused_enemy.get("position", Vector3.ZERO)).distance_to(Vector3(before_enemy.get("position", Vector3.ZERO))) <= POSITION_EPSILON, "T0189 paused enemy authority position advanced: %s" % enemy_id)
		_check(bool(paused_motion.get("paused", false)), "T0189 enemy motion was not paused: %s" % enemy_id)
		_check(Vector3(paused_motion.get("velocity", Vector3.ZERO)).length() <= POSITION_EPSILON, "T0189 paused enemy retained velocity: %s" % enemy_id)
		_check(str(paused_motion.get("request_id", "")) == str(before_motion.get("request_id", "")), "T0189 paused enemy replaced motion request: %s" % enemy_id)
		_check(str(paused_slice.get("phase", "")) == str(before_slice.get("phase", "")), "T0189 paused enemy route phase changed: %s" % enemy_id)
		_check(int(paused_enemy.get("hp", -1)) == int(before_enemy.get("hp", -2)), "T0189 enemy HP changed while paused: %s" % enemy_id)
		_check(int(paused_enemy.get("attack_sequence", -1)) == int(before_enemy.get("attack_sequence", -2)), "T0189 enemy attack advanced while paused: %s" % enemy_id)

	time_system.set_paused(false)
	var resumed := false
	for _frame in range(120):
		await process_frame
		await physics_frame
		var live_by_id := _index_slices(combat_system.debug_get_formal_dynamic_wave_slice_snapshot().get("slices", []))
		for raw_enemy_id in paused_by_id.keys():
			var enemy_id := str(raw_enemy_id)
			if not live_by_id.has(enemy_id):
				continue
			var paused_position: Vector3 = (paused_by_id[enemy_id] as Dictionary).get("world_position", Vector3.ZERO)
			var live_position: Vector3 = (live_by_id[enemy_id] as Dictionary).get("world_position", paused_position)
			if live_position.distance_to(paused_position) > 0.08:
				resumed = true
				break
		if resumed:
			break
	_check(resumed, "T0189 formal wave did not resume its existing routes")

	# Global resume must not erase the independent combat stop used while an enemy
	# is in attack range. Lock one actor tactically, cycle pause, and verify that it
	# remains stopped until CombatSystem explicitly releases that tactical reason.
	var live: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	var live_by_id := _index_slices(live.get("slices", []))
	if not live_by_id.is_empty():
		var tactical_enemy_id := str(live_by_id.keys()[0])
		combat_system._set_formal_enemy_tactical_motion_paused(tactical_enemy_id, true)
		time_system.set_paused(true)
		await physics_frame
		time_system.set_paused(false)
		await physics_frame
		var tactical_by_id := _index_slices(combat_system.debug_get_formal_dynamic_wave_slice_snapshot().get("slices", []))
		var tactical_motion: Dictionary = (tactical_by_id.get(tactical_enemy_id, {}) as Dictionary).get("motion", {})
		_check(bool(tactical_motion.get("paused", false)), "T0189 global resume erased tactical attack-position pause")
		combat_system._set_formal_enemy_tactical_motion_paused(tactical_enemy_id, false)


func _index_slices(raw_slices: Variant) -> Dictionary:
	var indexed := {}
	if not raw_slices is Array:
		return indexed
	for raw_slice in raw_slices as Array:
		if not raw_slice is Dictionary:
			continue
		var slice := raw_slice as Dictionary
		indexed[str(slice.get("enemy_id", ""))] = slice
	return indexed


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0189_ENEMY_PAUSE_MOTION_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
