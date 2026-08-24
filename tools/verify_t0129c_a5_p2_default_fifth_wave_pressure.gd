extends SceneTree


const EXPECTED_ENEMY_COUNT := 48
const EXPECTED_NPC_COUNT := 8
const PRESSURED_NONCOMBATANT_COUNT := 3
const BASELINE_FRAMES := 240
const PRESSURE_FRAMES := 420
const REFILL_FRAMES := 420
const PERFORMANCE_FRAMES := 600
const SAMPLE_INTERVAL := 6
const MAX_P95_CPU_FRAME_MS := 16.67
const INITIAL_MIN_CLEARANCE_TOLERANCE := -0.001
const MIN_AVOIDANCE_TRAVEL := 0.45


var _cpu_frame_samples_ms: Array[float] = []
var _physics_frame_samples_ms: Array[float] = []
var _navigation_frame_samples_ms: Array[float] = []
var _frame_pacing_samples_ms: Array[float] = []
var _minimum_clearance := INF
var _maximum_enemy_speed := 0.0
var _maximum_enemy_frame_displacement := 0.0
var _maximum_npc_frame_displacement := 0.0


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	var main_instance := packed.instantiate()
	# Windowed Main normally starts asynchronous day planning and pauses gameplay;
	# this combat-only verifier suppresses that deferred startup before _ready.
	var game_startup_system := main_instance.get_node_or_null("Systems/GameStartupSystem")
	if game_startup_system != null:
		game_startup_system._startup_running = true
	root.add_child(main_instance)
	await process_frame
	await physics_frame
	await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if combat_system == null or npc_system == null or time_system == null or controller == null:
		_fail("A5-P2 required systems are missing")
		return

	var original_positions: Dictionary = {}
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		original_positions[npc_id] = npc_system.get_npc_world_position(npc_id)
	var orphan_count_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var spawn_result: Dictionary = combat_system.spawn_wave(5, true, "a5_p2_default_pressure")
	if not bool(spawn_result.get("ok", false)) or int(spawn_result.get("spawned_count", 0)) != EXPECTED_ENEMY_COUNT:
		_fail("Default fifth wave spawn failed: %s" % JSON.stringify(spawn_result))
		return
	var migration := spawn_result.get("formal_combat_world_result", {}) as Dictionary
	var migrated_ids := migration.get("migrated_npc_ids", []) as Array
	var noncombatant_ids := migration.get("noncombatant_npc_ids", []) as Array
	var physics_contract: Dictionary = controller.debug_get_physics_navigation_snapshot()
	var collision_margin := float(physics_contract.get("collision_margin", 0.0))
	var dynamic_clearance_tolerance := -(collision_margin * 2.0 + 0.01)
	if migrated_ids.size() != EXPECTED_NPC_COUNT or noncombatant_ids.size() < PRESSURED_NONCOMBATANT_COUNT:
		_fail("Fifth wave did not migrate eight NPCs with enough noncombatants: %s" % JSON.stringify(migration))
		return

	# Logical combat is advanced explicitly so this test measures the same fixed
	# amount of AI work on every machine while physics and navigation stay live.
	time_system.set_process(false)
	var initial_snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	if int(initial_snapshot.get("formal_actor_count", 0)) != EXPECTED_ENEMY_COUNT:
		_fail("Fifth wave physical enemy population is incomplete: %s" % JSON.stringify(initial_snapshot))
		return
	_sample_spatial_contract(combat_system)
	if _minimum_clearance < INITIAL_MIN_CLEARANCE_TOLERANCE:
		_fail("Fifth-wave spawn formation overlaps physical capsules: clearance=%.3f" % _minimum_clearance)
		return

	for frame in range(BASELINE_FRAMES):
		await physics_frame
		if frame % SAMPLE_INTERVAL == 0:
			combat_system.debug_step_enemy_ai(0.1)
			_sample_spatial_contract(combat_system)

	var pressured_npc_starts: Dictionary = {}
	var pressure_setup := _prepare_contested_pressure(
		combat_system,
		npc_system,
		controller,
		noncombatant_ids,
		pressured_npc_starts,
		spawn_result.get("spawn_formation", {}) as Dictionary
	)
	if not bool(pressure_setup.get("ok", false)):
		_fail("Could not prepare the contested fifth-wave pressure: %s" % JSON.stringify(pressure_setup))
		return
	var pressured_npc_ids := pressure_setup.get("pressured_npc_ids", []) as Array
	var avoidance_sample_count := 0
	var pressure_sample_count := 0
	for frame in range(PRESSURE_FRAMES):
		await physics_frame
		if frame % SAMPLE_INTERVAL == 0:
			combat_system.debug_step_enemy_ai(0.1)
			_sample_spatial_contract(combat_system)
			pressure_sample_count += 1
			if _all_npcs_are_avoiding(combat_system, pressured_npc_ids):
				avoidance_sample_count += 1

	if _minimum_clearance < dynamic_clearance_tolerance:
		_fail("Fifth-wave pressure produced persistent capsule penetration: clearance=%.3f" % _minimum_clearance)
		return
	if avoidance_sample_count < int(pressure_sample_count * 0.5):
		_fail("Noncombatants did not sustain avoidance under fifth-wave pressure: %d/%d" % [avoidance_sample_count, pressure_sample_count])
		return
	for raw_npc_id in pressured_npc_ids:
		var npc_id := str(raw_npc_id)
		var start: Vector3 = pressured_npc_starts.get(npc_id, Vector3.ZERO)
		var current: Vector3 = npc_system.get_npc_world_position(npc_id)
		var avoidance_travel := _horizontal_distance(start, current)
		if avoidance_travel < MIN_AVOIDANCE_TRAVEL:
			_fail("Pressured noncombatant did not physically evade: %s travel=%.3f start=%s current=%s avoidance=%s actor=%s" % [
				npc_id,
				avoidance_travel,
				start,
				current,
				JSON.stringify(_find_avoidance(combat_system, npc_id)),
				JSON.stringify(_find_formal_npc_actor(combat_system, npc_id))
			])
			return

	var pressure_snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	if int(pressure_snapshot.get("navigation_failure_count", 0)) != 0:
		_fail("Fifth-wave pressure produced navigation failures: %s" % JSON.stringify(pressure_snapshot.get("phase_counts", {})))
		return
	var refill_setup := _select_front_contact_for_refill(pressure_snapshot)
	if not bool(refill_setup.get("ok", false)):
		_fail("Fifth wave did not form contact plus rear pressure: %s" % JSON.stringify(pressure_snapshot.get("phase_counts", {})))
		return
	var front_position: Vector3 = refill_setup.get("front_position", Vector3.ZERO)
	var pressing_ids := refill_setup.get("pressing_ids", {}) as Dictionary
	var defeated: Dictionary = combat_system.apply_enemy_area_damage(front_position, 0.12, 99999.0, {
		"max_targets": 1,
		"source_type": "a5_p2_refill_verification"
	})
	if int(defeated.get("defeated_count", 0)) != 1:
		_fail("Could not release one front contact: %s" % JSON.stringify(defeated))
		return
	var refill_enemy_id := ""
	for frame in range(REFILL_FRAMES):
		await physics_frame
		if frame % SAMPLE_INTERVAL == 0:
			combat_system.debug_step_enemy_ai(0.1)
			_sample_spatial_contract(combat_system)
			var refill_snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
			for raw_slice in refill_snapshot.get("slices", []):
				var slice := raw_slice as Dictionary
				var enemy_id := str(slice.get("enemy_id", ""))
				if pressing_ids.has(enemy_id) and str(slice.get("phase", "")).begins_with("attacking_"):
					refill_enemy_id = enemy_id
					break
		if not refill_enemy_id.is_empty():
			break
	if refill_enemy_id.is_empty():
		_fail("No rear fifth-wave actor refilled the released contact")
		return

	# Keep diagnostic snapshots and pairwise capsule audits out of this window.
	# The production-equivalent AI tick remains active at its 0.1 second cadence.
	_cpu_frame_samples_ms.clear()
	_physics_frame_samples_ms.clear()
	_navigation_frame_samples_ms.clear()
	_frame_pacing_samples_ms.clear()
	var budget_updated_ids: Dictionary = {}
	var previous_frame_usec := Time.get_ticks_usec()
	for frame in range(PERFORMANCE_FRAMES):
		await physics_frame
		var current_frame_usec := Time.get_ticks_usec()
		_frame_pacing_samples_ms.append(float(current_frame_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = current_frame_usec
		_sample_cpu_frame()
		# At x1, TimeSystem contributes roughly one game second per rendered frame.
		# Invoke only CombatSystem's production subscriber so this A5-P2 window does
		# not charge unrelated daily-plan subscribers to the combat movement budget.
		combat_system._on_logical_time_tick(1.0, 1.0)
		var current_budget := combat_system._last_ai_step_result as Dictionary
		for raw_target in current_budget.get("targets", []):
			var target_entry := raw_target as Dictionary
			budget_updated_ids[str(target_entry.get("enemy_id", ""))] = true
	var p95_cpu_ms := _percentile(_cpu_frame_samples_ms, 0.95)
	var p95_physics_ms := _percentile(_physics_frame_samples_ms, 0.95)
	var p95_navigation_ms := _percentile(_navigation_frame_samples_ms, 0.95)
	var average_frame_pacing_ms := _average(_frame_pacing_samples_ms)
	var p95_frame_pacing_ms := _percentile(_frame_pacing_samples_ms, 0.95)
	if p95_cpu_ms > MAX_P95_CPU_FRAME_MS:
		_fail("Fifth-wave CPU frame budget exceeded 60 FPS: p95=%.3f ms" % p95_cpu_ms)
		return
	var combat_snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	var budget_snapshot := combat_snapshot.get("last_ai_step_result", {}) as Dictionary
	if not bool(budget_snapshot.get("budgeted", false)) or int(budget_snapshot.get("updated_enemy_count", 0)) > 8:
		_fail("Formal fifth-wave AI budget was not active: %s" % JSON.stringify(budget_snapshot))
		return
	for active_enemy_id in combat_system.get_active_enemy_ids():
		if not budget_updated_ids.has(str(active_enemy_id)):
			_fail("Formal fifth-wave AI budget skipped a surviving enemy: %s" % active_enemy_id)
			return
	var final_snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	if int(final_snapshot.get("navigation_failure_count", 0)) != 0:
		_fail("Navigation failure appeared before cleanup")
		return

	var clear_result: Dictionary = combat_system.clear_spawned_enemies()
	await process_frame
	await physics_frame
	await process_frame
	if not bool(clear_result.get("ok", false)) or combat_system.get_active_enemy_count() != 0:
		_fail("Fifth-wave cleanup failed: %s" % JSON.stringify(clear_result))
		return
	if (
		not combat_system._formal_enemy_game_seconds_accumulator.is_empty()
		or not combat_system._formal_enemy_combat_seconds_accumulator.is_empty()
		or combat_system._formal_enemy_ai_cursor != 0
	):
		_fail("Fifth-wave cleanup left AI budget state behind")
		return
	var world_after: Dictionary = combat_system.debug_get_default_formal_combat_world_snapshot()
	if bool(world_after.get("active", true)) or int(world_after.get("formal_enemy_count", -1)) != 0:
		_fail("Formal combat world remained active after cleanup: %s" % JSON.stringify(world_after))
		return
	for raw_npc_id in migrated_ids:
		var npc_id := str(raw_npc_id)
		var restored: Vector3 = npc_system.get_npc_world_position(npc_id)
		var original: Vector3 = original_positions.get(npc_id, Vector3.INF)
		if restored.distance_to(original) > 0.01:
			_fail("NPC was not restored after fifth-wave pressure: %s" % npc_id)
			return
	var orphan_count_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphan_count_after > orphan_count_before:
		_fail("Fifth-wave cleanup leaked orphan nodes: %d -> %d" % [orphan_count_before, orphan_count_after])
		return

	print("A5-P2 default fifth-wave pressure verification passed: %s" % JSON.stringify({
		"enemy_count": EXPECTED_ENEMY_COUNT,
		"npc_count": EXPECTED_NPC_COUNT,
		"pressured_noncombatants": pressured_npc_ids.size(),
		"avoidance_samples": avoidance_sample_count,
		"pressure_samples": pressure_sample_count,
		"minimum_clearance": _minimum_clearance,
		"maximum_enemy_speed": _maximum_enemy_speed,
		"maximum_enemy_frame_displacement": _maximum_enemy_frame_displacement,
		"maximum_npc_frame_displacement": _maximum_npc_frame_displacement,
		"p95_cpu_frame_ms": p95_cpu_ms,
		"average_frame_pacing_ms": average_frame_pacing_ms,
		"p95_frame_pacing_ms": p95_frame_pacing_ms,
		"ai_updates_per_frame": int(budget_snapshot.get("updated_enemy_count", 0)),
		"budget_updated_enemy_count": budget_updated_ids.size(),
		"p95_physics_frame_ms": p95_physics_ms,
		"p95_navigation_frame_ms": p95_navigation_ms,
		"refill_enemy_id": refill_enemy_id,
		"orphan_count_before": orphan_count_before,
		"orphan_count_after": orphan_count_after
	}))
	quit(0)


func _prepare_contested_pressure(
	combat_system: Node,
	npc_system: Node,
	controller: Node,
	noncombatant_ids: Array,
	pressured_npc_starts: Dictionary,
	spawn_formation: Dictionary
) -> Dictionary:
	var route: Dictionary = controller.get_enemy_route_world()
	var stages := route.get("stages", []) as Array
	var front_gate_index := -1
	var contact_position := Vector3.ZERO
	var front_gate_position := Vector3.ZERO
	for index in range(stages.size()):
		var stage := stages[index] as Dictionary
		if str(stage.get("id", "")) == "contact":
			contact_position = stage.get("position", Vector3.ZERO)
		if str(stage.get("id", "")) == "front_gate":
			front_gate_index = index
			front_gate_position = stage.get("position", Vector3.ZERO)
	if front_gate_index < 0 or contact_position == Vector3.ZERO or front_gate_position == Vector3.ZERO:
		return {"ok": false, "reason": "formal_route_missing"}
	var approach_direction := front_gate_position - contact_position
	approach_direction.y = 0.0
	approach_direction = approach_direction.normalized()
	var lateral := Vector3(-approach_direction.z, 0.0, approach_direction.x)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	var threat_count := mini(PRESSURED_NONCOMBATANT_COUNT, mini(noncombatant_ids.size(), enemy_ids.size()))
	var pressured_npc_ids: Array[String] = []
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	var threat_offsets: Array[Vector3] = [
		Vector3(-3.2, 0.0, 0.0),
		Vector3(3.2, 0.0, 0.0),
		Vector3(0.0, 0.0, 3.2)
	]
	for index in range(threat_count):
		var npc_id := str(noncombatant_ids[index])
		var npc_position: Vector3 = npc_system.get_npc_world_position(npc_id)
		pressured_npc_starts[npc_id] = npc_position
		pressured_npc_ids.append(npc_id)
		var threat_offset: Vector3 = threat_offsets[index]
		var threat_position := NavigationServer3D.map_get_closest_point(navigation_map, npc_position + threat_offset)
		_teleport_enemy(combat_system, str(enemy_ids[index]), threat_position)

	var formation_spacing := float(spawn_formation.get("spacing", 0.0))
	if formation_spacing <= 0.0:
		return {"ok": false, "reason": "spawn_formation_contract_missing"}
	for index in range(threat_count, enemy_ids.size()):
		var formation_index := index - threat_count
		var column := formation_index % 3
		var row := formation_index / 3
		var staged_position := (
			front_gate_position
			- approach_direction * (6.0 + float(row) * formation_spacing)
			+ lateral * (float(column) - 1.0) * formation_spacing
		)
		staged_position = NavigationServer3D.map_get_closest_point(navigation_map, staged_position)
		var enemy_id := str(enemy_ids[index])
		_teleport_enemy(combat_system, enemy_id, staged_position)
		combat_system._request_formal_first_wave_stage(enemy_id, front_gate_index)

	for raw_enemy_id in enemy_ids:
		var enemy_id := str(raw_enemy_id)
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		enemy["attack_power"] = 1
		enemy["attack_interval"] = 10000.0
		enemy["attack_speed"] = 0.0001
		combat_system._active_enemies[enemy_id] = enemy
	combat_system.debug_step_enemy_ai(0.1)
	for npc_id in pressured_npc_ids:
		var result: Dictionary = combat_system.debug_trigger_npc_avoidance(npc_id)
		if not bool(result.get("ok", false)):
			return {"ok": false, "reason": "avoidance_start_failed", "npc_id": npc_id, "result": result}
	return {"ok": true, "pressured_npc_ids": pressured_npc_ids}


func _teleport_enemy(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var node_path: NodePath = combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	var actor := root.get_node_or_null(node_path) as ActorMotionBody
	if actor != null:
		actor.global_position = position
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["position"] = position
	combat_system._active_enemies[enemy_id] = enemy
	var slice: Dictionary = combat_system._formal_first_wave_slices.get(enemy_id, {})
	slice["previous_position"] = position
	combat_system._formal_first_wave_slices[enemy_id] = slice


func _sample_cpu_frame() -> void:
	var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var navigation_ms := float(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS)) * 1000.0
	_cpu_frame_samples_ms.append(process_ms)
	_physics_frame_samples_ms.append(physics_ms)
	_navigation_frame_samples_ms.append(navigation_ms)


func _sample_spatial_contract(combat_system: Node) -> void:
	var snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	var actors: Array[Dictionary] = []
	for raw_slice in snapshot.get("slices", []):
		var slice := raw_slice as Dictionary
		var motion := slice.get("motion", {}) as Dictionary
		var profile_speed := float(motion.get("profile_base_speed", 0.0))
		var observed_speed := float(motion.get("maximum_observed_speed", 0.0))
		var frame_displacement := float(motion.get("maximum_frame_displacement", 0.0))
		_maximum_enemy_speed = maxf(_maximum_enemy_speed, observed_speed)
		_maximum_enemy_frame_displacement = maxf(_maximum_enemy_frame_displacement, frame_displacement)
		if observed_speed > profile_speed + 0.02:
			_fail("Enemy exceeded its movement profile: %s" % JSON.stringify(slice))
			return
		var radius := float(motion.get("body_radius", 0.0))
		if frame_displacement > profile_speed / 60.0 + radius * 0.6:
			_fail("Enemy was displaced by a flight-like single-frame jump: %s" % JSON.stringify(slice))
			return
		actors.append({
			"id": str(slice.get("enemy_id", "")),
			"position": slice.get("world_position", Vector3.ZERO),
			"radius": radius
		})
	var world := combat_system.debug_get_default_formal_combat_world_snapshot().get("npc_world", {}) as Dictionary
	for raw_actor in world.get("actors", []):
		var actor := raw_actor as Dictionary
		var motion := actor.get("motion", {}) as Dictionary
		var frame_displacement := float(motion.get("maximum_frame_displacement", 0.0))
		_maximum_npc_frame_displacement = maxf(_maximum_npc_frame_displacement, frame_displacement)
		actors.append({
			"id": str(actor.get("npc_id", "")),
			"position": actor.get("world_position", Vector3.ZERO),
			"radius": float(motion.get("body_radius", 0.0))
		})
	for first_index in range(actors.size()):
		for second_index in range(first_index + 1, actors.size()):
			var first := actors[first_index] as Dictionary
			var second := actors[second_index] as Dictionary
			var first_position: Vector3 = first.get("position", Vector3.ZERO)
			var second_position: Vector3 = second.get("position", Vector3.ZERO)
			var clearance := (
				_horizontal_distance(first_position, second_position)
				- float(first.get("radius", 0.0))
				- float(second.get("radius", 0.0))
			)
			_minimum_clearance = minf(_minimum_clearance, clearance)


func _all_npcs_are_avoiding(combat_system: Node, npc_ids: Array) -> bool:
	var active_ids: Dictionary = {}
	for raw_avoidance in combat_system.get_active_avoidances():
		var avoidance := raw_avoidance as Dictionary
		active_ids[str(avoidance.get("npc_id", ""))] = true
	for raw_npc_id in npc_ids:
		if not active_ids.has(str(raw_npc_id)):
			return false
	return not npc_ids.is_empty()


func _find_avoidance(combat_system: Node, npc_id: String) -> Dictionary:
	for raw_avoidance in combat_system.get_active_avoidances():
		var avoidance := raw_avoidance as Dictionary
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _find_formal_npc_actor(combat_system: Node, npc_id: String) -> Dictionary:
	var npc_world := combat_system.debug_get_default_formal_combat_world_snapshot().get("npc_world", {}) as Dictionary
	for raw_actor in npc_world.get("actors", []):
		var actor := raw_actor as Dictionary
		if str(actor.get("npc_id", "")) == npc_id:
			return actor
	return {}


func _select_front_contact_for_refill(snapshot: Dictionary) -> Dictionary:
	var pressing_ids: Dictionary = {}
	var front_position := Vector3.ZERO
	var front_found := false
	for raw_slice in snapshot.get("slices", []):
		var slice := raw_slice as Dictionary
		var phase := str(slice.get("phase", ""))
		var targets_front_gate := (
			str(slice.get("combat_target_type", "")) == "building"
			and str(slice.get("combat_target_id", "")) == "front_gate"
		)
		if targets_front_gate and phase == "attacking_front_gate" and not front_found:
			front_position = slice.get("world_position", Vector3.ZERO)
			front_found = true
		elif targets_front_gate and phase != "attacking_front_gate":
			pressing_ids[str(slice.get("enemy_id", ""))] = true
	return {
		"ok": front_found and not pressing_ids.is_empty(),
		"front_position": front_position,
		"pressing_ids": pressing_ids
	}


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return INF
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * ratio)) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return INF
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
