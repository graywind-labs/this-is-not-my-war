extends SceneTree

var _failures: PackedStringArray = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("Systems/GameStartupSystem").set("_startup_running", true)
	main.get_node("Systems/LLMBridge").set("_transport_shutdown_requested", true)
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame
	var combat := main.get_node("Systems/CombatSystem")
	var clock_system := main.get_node("Systems/TimeSystem")
	clock_system.set_paused(true)
	var spawn: Dictionary = combat.spawn_wave(5, true, "t0396_equivalence")
	_check(bool(spawn.get("ok", false)), "formal fifth wave spawn")
	var ids: Array = combat.get_active_enemy_ids()
	if ids.is_empty():
		_finish()
		return
	var kinds: Dictionary = {}
	var cases: Array[Dictionary] = []
	for enemy_id: String in ids:
		var enemy: Dictionary = combat.get_enemy(enemy_id)
		var actor := combat.get_node(combat._formal_first_wave_node_paths[enemy_id]) as ActorMotionBody
		var snapshot := actor.debug_get_motion_snapshot()
		_check(actor.get_body_radius() == float(snapshot.body_radius), "radius getter %s" % enemy_id)
		_check(actor.get_profile_base_speed() == float(snapshot.profile_base_speed), "speed getter %s" % enemy_id)
		var kind := "%s/%s" % [enemy.unit_type, enemy.weapon_type]
		if not kinds.has(kind):
			kinds[kind] = enemy_id
			for building_id in ["front_gate", "warehouse", "main_hall"]:
				var target: Dictionary = combat._make_building_target(building_id)
				cases.append_array(combat._get_enemy_attack_position_candidates(enemy_id, enemy, target))
	# Include exact cylinder horizontal/vertical boundaries around live bodies.
	var body_actor := combat.get_node(combat._formal_first_wave_node_paths[ids[1]]) as ActorMotionBody
	var body_profile: Dictionary = combat._get_enemy_guidance_body_profile(combat.get_enemy(ids[1]))
	for horizontal_offset in [0.0, float(body_profile.radius) + 0.42 - 0.0001, float(body_profile.radius) + 0.42, float(body_profile.radius) + 0.42 + 0.0001]:
		for vertical_offset in [-2.6001, -2.6, 0.0, float(body_profile.height), float(body_profile.height) + 0.0001]:
			cases.append({"position": body_actor.global_position + Vector3(horizontal_offset, vertical_offset, 0), "guidance_zone_radius": 0.42, "guidance_zone_height": 2.6})
	var legacy_usec := 0
	var optimized_usec := 0
	for exclusion in ["", str(ids[0]), str(ids[1])]:
		var started := Time.get_ticks_usec()
		var bodies: Array[Dictionary] = combat._collect_enemy_guidance_bodies(exclusion)
		var body_index: Dictionary = combat._index_enemy_guidance_bodies(bodies)
		optimized_usec += Time.get_ticks_usec() - started
		for candidate in cases:
			started = Time.get_ticks_usec()
			var expected := _reference_occupancy(combat, candidate, exclusion)
			legacy_usec += Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
			var actual: Dictionary = combat._measure_enemy_guidance_zone_occupancy(candidate, bodies)
			optimized_usec += Time.get_ticks_usec() - started
			_check(actual == expected, "occupancy equivalence at %s exclude=%s" % [candidate.position, exclusion])
			_check(combat._measure_enemy_guidance_zone_occupancy(candidate, combat._query_enemy_guidance_bodies(candidate, body_index)) == expected, "indexed occupancy equivalence")
	# No cross-call cache: changes are observable even without advancing a frame.
	var live_zone := {"position": body_actor.global_position, "guidance_zone_radius": 0.42, "guidance_zone_height": 2.6}
	for offset in [Vector3(100, 0, 0), Vector3.ZERO, Vector3(0, 100, 0)]:
		body_actor.global_position = live_zone.position + offset
		_check(combat._get_enemy_guidance_zone_occupancy(live_zone) == _reference_occupancy(combat, live_zone, ""), "same-frame move invalidation")
	body_actor.global_position = live_zone.position
	var enemy_state: Dictionary = combat._active_enemies[ids[1]]
	var original_hp: int = enemy_state.hp
	enemy_state.hp = 0
	_check(combat._get_enemy_guidance_zone_occupancy(live_zone) == _reference_occupancy(combat, live_zone, ""), "zero HP invalidation")
	enemy_state.hp = original_hp
	for representative in kinds.values():
		var enemy: Dictionary = combat.get_enemy(representative)
		for building_id in ["front_gate", "warehouse", "main_hall"]:
			var target: Dictionary = combat._make_building_target(building_id)
			for offset in [Vector3.ZERO, Vector3(10000, 0, 10000)]:
				target.position += offset
				var preview: Dictionary = combat._preview_enemy_target_opportunity(representative, enemy, target)
				var expected: bool = str(preview.get("reason", "")) != "invalid_target"
				_check(combat._is_enemy_fixed_target_present(representative, enemy, target) == expected, "guidance presence regardless of path reachability")
	var buildings := main.get_node("Systems/BuildingSystem")
	_verify_read_projections(main)
	_verify_probe_contract(combat, clock_system)
	_verify_spatial_index(combat)
	var started := Time.get_ticks_usec()
	for _index in range(100):
		buildings.get_building("front_gate")
	var building_projection_usec := Time.get_ticks_usec() - started
	print("T0396_EQUIVALENCE %s" % JSON.stringify({"checks": _checks, "zone_cases": cases.size(), "legacy_occupancy_ms": legacy_usec / 1000.0, "optimized_occupancy_ms": optimized_usec / 1000.0, "building_full_projection_100_ms": building_projection_usec / 1000.0}))
	combat.clear_spawned_enemies()
	_check(combat._collect_enemy_guidance_bodies("").is_empty(), "clear removes all occupancy bodies")
	# Clearing the final wave legitimately settles victory. This isolated lookup
	# fixture resets that test-only latch before exercising body reconstruction.
	root.get_node("GameState").set("game_over", false)
	var respawn: Dictionary = combat.spawn_wave(1, true, "t0396_lifecycle")
	_check(bool(respawn.get("ok", false)) and combat._collect_enemy_guidance_bodies("").size() == 8, "clear then respawn has only new bodies: %s" % respawn.get("reason", ""))
	combat.clear_spawned_enemies()
	main.queue_free()
	for _frame in range(4):
		await process_frame
	_finish()


func _verify_read_projections(main: Node) -> void:
	var npcs := main.get_node("Systems/NPCSystem")
	for npc_id: String in npcs.get_npc_ids():
		var profile: Dictionary = npcs.get_npc(npc_id)
		var equipment: Dictionary = profile.get("equipment", {})
		var expected := {
			"name": str(profile.get("name", npc_id)),
			"recruited": bool(profile.get("recruited", false)),
			"has_main_weapon": not (equipment.get("main_weapon", {}) as Dictionary).is_empty(),
		}
		_check(npcs.get_npc_combat_identity(npc_id) == expected, "NPC combat identity projection")
		_check(npcs.get_npc_behavior_mode(npc_id) == str(npcs.get_npc_behavior_mode_snapshot(npc_id).behavior_mode), "NPC mode projection")
		var internal: Dictionary = npcs._profiles[npc_id]
		var original: Dictionary = internal.states.duplicate(true)
		for changes in [{}, {"unconscious": true}, {"escaped": true}, {"first_sleep_summary_active": true}, {"escape_intent": {"active": true, "status": "escaping"}}, {"escape_intent": {"active": true, "status": "paused_unconscious"}}]:
			internal.states = original.merged(changes, true)
			var state: Dictionary = npcs.get_npc_state(npc_id)
			var expected_can_act: bool = not bool(state.get("unconscious", false)) and not bool(state.get("escaped", false)) and not npcs._is_npc_escaping_state(state) and not bool(state.get("first_sleep_summary_active", false)) and not npcs._formal_navigation_pilots.has(npc_id)
			_check(npcs.can_npc_act(npc_id) == expected_can_act, "can_act same-frame state equality")
			_check(npcs.get_npc_behavior_mode(npc_id) == str(npcs.get_npc_behavior_mode_snapshot(npc_id).behavior_mode), "mode same-frame state equality")
		internal.states = original
		var original_equipment: Dictionary = internal.equipment.duplicate(true)
		for main_weapon in [{}, {"id": "sword_shield"}, {"id": "bow"}]:
			internal.equipment.main_weapon = main_weapon
			_check(bool(npcs.get_npc_combat_identity(npc_id).has_main_weapon) == not main_weapon.is_empty(), "weapon same-frame update")
		internal.equipment = original_equipment
		var identity: Dictionary = npcs.get_npc_combat_identity(npc_id)
		identity.name = "test_external_mutation"
		_check(npcs.get_npc_combat_identity(npc_id) == expected, "identity does not expose internal dictionary")
	var buildings := main.get_node("Systems/BuildingSystem")
	for building_id: String in buildings.get_building_ids():
		var full: Dictionary = buildings.get_building(building_id)
		var compact: Dictionary = buildings.get_building_combat_snapshot(building_id)
		_check(compact == {"id": building_id, "name": str(full.name), "hp": int(full.hp), "max_hp": int(full.max_hp)}, "building HP/identity equality")
		var internal: Dictionary = buildings._buildings[building_id]
		var hp: int = internal.hp
		internal.hp = 0
		_check(int(buildings.get_building_combat_snapshot(building_id).hp) == 0, "building HP same-frame update")
		internal.hp = hp
		compact.hp = -10
		_check(int(buildings.get_building_combat_snapshot(building_id).hp) == hp, "building projection isolation")
	_check(npcs.get_npc_combat_identity("missing").is_empty() and not npcs.can_npc_act("missing"), "unknown NPC remains invalid")
	_check(buildings.get_building_combat_snapshot("missing").is_empty(), "unknown building remains invalid")


func _verify_probe_contract(combat: Node, clock_system: Node) -> void:
	var enemy_count: int = combat.get_active_enemy_count()
	var paused: bool = clock_system.is_gameplay_paused()
	var started: Dictionary = combat.debug_start_performance_capture(1.0)
	_check(bool(started.get("ok", false)), "explicit capture starts")
	var probe: RefCounted = combat._performance_probe
	for index in range(3605):
		probe.record("fixture_ms", index)
	var report: Dictionary = combat.debug_get_performance_capture(true, true)
	_check(int(report.metrics.fixture_ms.count) == 3600 and int(report.dropped_samples.fixture_ms) == 5, "probe storage bounded and truncation explicit")
	probe.record("fixture_ms", 999)
	_check(combat.debug_get_performance_capture(false, true) == report, "stopped probe does not record")
	_check(combat.get_active_enemy_count() == enemy_count and clock_system.is_gameplay_paused() == paused, "capture does not mutate combat/pause")


func _verify_spatial_index(combat: Node) -> void:
	var bodies: Array[Dictionary] = []
	for x in [-8.00001, -4.0, -0.00001, 0.0, 3.99999, 4.0, 8.00001]:
		for z in [-8.0, -4.00001, 0.0, 3.99999, 8.0]:
			for radius in [0.1, 0.42, 0.65, 3.0]:
				bodies.append({"id": str(bodies.size()), "position": Vector3(x, 0, z), "radius": radius, "height": 1.8})
	var index: Dictionary = combat._index_enemy_guidance_bodies(bodies)
	for body in bodies:
		for radius in [0.1, 0.42, 0.65, 4.1]:
			for height_offset in [0.0, 1.8, 1.80001, -2.6]:
				var candidate := {"position": body.position + Vector3(0, height_offset, 0), "guidance_zone_radius": radius, "guidance_zone_height": 2.6}
				var expected: Dictionary = combat._measure_enemy_guidance_zone_occupancy(candidate, bodies)
				_check(combat._measure_enemy_guidance_zone_occupancy(candidate, combat._query_enemy_guidance_bodies(candidate, index)) == expected, "grid edge/negative coordinate/radius/height equality")


func _reference_occupancy(combat: Node, candidate: Dictionary, excluded: String) -> Dictionary:
	# Pre-T0396 per-candidate algorithm retained as an independent oracle.
	var zone: Vector3 = candidate.get("position", Vector3.ZERO)
	var radius := maxf(0.1, float(candidate.get("guidance_zone_radius", candidate.get("enemy_radius", 0.42))))
	var height := maxf(0.1, float(candidate.get("guidance_zone_height", combat._formal_attack_position_policy.get("guidance_zone_height", 2.6))))
	var occupants: Array[String] = []
	for raw_id in combat._active_enemies.keys():
		var enemy_id := str(raw_id)
		if not excluded.is_empty() and enemy_id == excluded:
			continue
		var enemy: Dictionary = combat._active_enemies.get(enemy_id, {})
		if enemy.is_empty() or int(enemy.get("hp", 0)) <= 0:
			continue
		var actor := combat.get_node_or_null(combat._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		var position: Vector3 = actor.global_position if actor != null else enemy.get("position", Vector3.INF)
		if position == Vector3.INF:
			continue
		var body: Dictionary = combat._get_enemy_guidance_body_profile(enemy)
		var body_radius := maxf(0.1, float(body.get("radius", 0.42)))
		var body_height := maxf(0.1, float(body.get("height", 1.8)))
		if position.y + body_height < zone.y or position.y > zone.y + height:
			continue
		if Vector2(position.x, position.z).distance_to(Vector2(zone.x, zone.z)) <= radius + body_radius:
			occupants.append(enemy_id)
	occupants.sort()
	return {"count": occupants.size(), "enemy_ids": occupants, "zone_radius": radius, "zone_height": height}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("T0396_OPTIMIZATION_%s checks=%d failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
