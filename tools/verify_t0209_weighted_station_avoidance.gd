extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const CIVILIAN_NPC_ID := "cook_01"
const EXPLICIT_AVOID_NPC_ID := "veteran_deputy_01"

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

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_check(combat_system != null and npc_system != null, "T0209 combat or NPC system missing")
	_check(time_system != null and station_controller != null, "T0209 time or station controller missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0209 formal wave failed to spawn: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() >= 3, "T0209 needs three production enemies")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(3, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	enemy_ids = combat_system.get_active_enemy_ids()
	var enemy_near := enemy_ids[0]
	var enemy_far := enemy_ids[1]
	var enemy_outside := enemy_ids[2]

	var avoidance_range: float = combat_system._get_avoidance_trigger_range()
	var enemy_detection_range: float = combat_system._get_enemy_target_detection_range({})
	_check(avoidance_range > enemy_detection_range, "T0209 avoidance range must exceed enemy detection range")
	_check(is_equal_approx(avoidance_range, enemy_detection_range + 2.0), "T0209 configured avoidance margin mismatch: %s" % avoidance_range)

	# A near enemy on +X and a farther enemy on +Z produce an inverse-square
	# result toward -X/-Z. At 10 m versus 20 m, the X contribution is 4x.
	var origin := Vector3(0.0, 0.0, 10.0)
	_set_enemy_position(combat_system, enemy_near, origin + Vector3(10.0, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_far, origin + Vector3(0.0, 0.0, 20.0))
	_set_enemy_position(combat_system, enemy_outside, origin + Vector3(avoidance_range + 0.2, 0.0, 0.0))
	var field: Dictionary = combat_system._build_avoidance_threat_field(origin, avoidance_range, CIVILIAN_NPC_ID)
	var direction: Vector3 = field.get("direction", Vector3.ZERO)
	var threats := field.get("threats", []) as Array
	_check(threats.size() == 2, "T0209 threat field did not exclude out-of-range enemy: %s" % field)
	_check(direction.x < 0.0 and direction.z < 0.0, "T0209 weighted direction is not opposite both enemies: %s" % direction)
	_check(absf(direction.x) > absf(direction.z), "T0209 nearer right enemy did not dominate direction: %s" % direction)
	var contribution_ratio := absf(direction.x / direction.z) if absf(direction.z) > 0.0001 else INF
	_check(contribution_ratio >= 3.9 and contribution_ratio <= 4.1, "T0209 inverse-square contribution ratio mismatch: %s" % contribution_ratio)

	# With one enemy in range, all four cardinal approaches must produce the
	# exact horizontal opposite direction.
	_set_enemy_position(combat_system, enemy_far, origin + Vector3(0.0, 0.0, avoidance_range + 0.2))
	for approach in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		_set_enemy_position(combat_system, enemy_near, origin + approach * 10.0)
		field = combat_system._build_avoidance_threat_field(origin, avoidance_range, CIVILIAN_NPC_ID)
		direction = field.get("direction", Vector3.ZERO)
		_check((field.get("threats", []) as Array).size() == 1, "T0209 single-enemy fixture contains extra threats: %s" % field)
		_check(direction.distance_to(-approach) <= 0.0001, "T0209 single enemy did not produce exact opposite direction for %s: %s" % [approach, direction])
	_set_enemy_position(combat_system, enemy_near, origin + Vector3(10.0, 0.0, 0.0))
	field = combat_system._build_avoidance_threat_field(origin, avoidance_range, CIVILIAN_NPC_ID)

	# The authored point remains one full avoidance radius away. Navigation may
	# shorten only the resolved destination when walls or entities obstruct it.
	_set_npc_position(npc_system, CIVILIAN_NPC_ID, origin)
	var selected: Dictionary = combat_system._select_avoidance_target(
		CIVILIAN_NPC_ID,
		field.get("nearest_encounter", {}) as Dictionary
	)
	var desired_position: Vector3 = selected.get("desired_position", origin)
	_check(absf(_horizontal_distance(origin, desired_position) - avoidance_range) <= 0.01, "T0209 authored target distance is not the avoidance radius: %s" % selected)
	_check(station_controller.is_world_position_inside_station(selected.get("position", Vector3.ZERO)), "T0209 selected navigation target left the station: %s" % selected)

	# A desired point beyond the east wall must be pulled back inside while
	# preserving an actual production NavigationMap destination.
	var boundary_origin := Vector3(40.0, 0.0, 10.0)
	var outside_desired := boundary_origin + Vector3(avoidance_range, 0.0, 0.0)
	_check(station_controller.is_world_position_inside_station(boundary_origin), "T0209 boundary fixture origin is outside")
	_check(not station_controller.is_world_position_inside_station(outside_desired), "T0209 boundary fixture desired point stayed inside")
	var boundary_resolution: Dictionary = station_controller.resolve_station_avoidance_navigation_target(
		boundary_origin,
		outside_desired,
		1.25
	)
	_check(bool(boundary_resolution.get("ok", false)), "T0209 outside target could not be resolved: %s" % boundary_resolution)
	_check(bool(boundary_resolution.get("boundary_limited", false)), "T0209 outside target was not marked boundary-limited: %s" % boundary_resolution)
	_check(station_controller.is_world_position_inside_station(boundary_resolution.get("position", Vector3.ZERO)), "T0209 boundary correction remained outside: %s" % boundary_resolution)

	# A raw target in the solid main hall must snap to reachable navigation beside
	# the entity, not remain inside its envelope.
	var building_origin := Vector3(0.0, 0.0, 31.2)
	var building_desired := Vector3(0.0, 0.0, -8.0)
	var desired_overlap: Dictionary = station_controller.get_building_area_overlap(building_desired, 0.35)
	_check(str(desired_overlap.get("building_id", "")) == "main_hall", "T0209 building fixture does not hit main hall: %s" % desired_overlap)
	var building_resolution: Dictionary = station_controller.resolve_station_avoidance_navigation_target(
		building_origin,
		building_desired,
		1.25
	)
	_check(bool(building_resolution.get("ok", false)), "T0209 building target could not be resolved: %s" % building_resolution)
	var building_target: Vector3 = building_resolution.get("position", building_desired)
	_check(bool(building_resolution.get("navigation_adjusted", false)), "T0209 building target was not navigation-adjusted: %s" % building_resolution)
	_check(station_controller.get_building_area_overlap(building_target, 0.35).is_empty(), "T0209 resolved target still overlaps an entity: %s" % building_resolution)
	_check(station_controller.is_world_position_inside_station(building_target), "T0209 building correction left the station: %s" % building_resolution)

	# Automatic civilian contact and an explicit avoid_combat unit both reuse the
	# existing ActorMotionBody navigation route and carry weighted diagnostics.
	_set_enemy_position(combat_system, enemy_near, origin + Vector3(10.0, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_far, origin + Vector3(0.0, 0.0, 20.0))
	npc_system.set_npc_behavior_mode(CIVILIAN_NPC_ID, "work", "t0209_civilian_fixture", {
		"force_idle": true,
		"request_plan_reevaluation": false
	})
	combat_system._advance_behavior_mode_contacts()
	await process_frame
	var civilian_avoidance := _find_avoidance(combat_system.get_active_avoidances(), CIVILIAN_NPC_ID)
	_check(_mode(npc_system, CIVILIAN_NPC_ID) == "avoid_combat", "T0209 noncombat NPC did not enter avoidance")
	_check(int(civilian_avoidance.get("threat_count", 0)) == 2, "T0209 civilian avoidance did not retain two weighted threats: %s" % civilian_avoidance)
	var civilian_actor := _get_npc_node(npc_system, CIVILIAN_NPC_ID)
	var civilian_motion: Dictionary = civilian_actor.debug_get_motion_snapshot() if civilian_actor != null and civilian_actor.has_method("debug_get_motion_snapshot") else {}
	_check(bool(civilian_motion.get("active", false)), "T0209 civilian did not start existing navigation movement: %s" % civilian_motion)
	_check(str(civilian_motion.get("request_id", "")) == "avoid_shelter_%s" % CIVILIAN_NPC_ID, "T0209 civilian avoidance did not use the existing movement request: %s" % civilian_motion)

	var explicit_origin := Vector3(0.0, 0.0, 20.0)
	_set_npc_position(npc_system, EXPLICIT_AVOID_NPC_ID, explicit_origin)
	npc_system.set_npc_behavior_mode(EXPLICIT_AVOID_NPC_ID, "avoid_combat", "t0209_explicit_fixture", {
		"force_idle": true,
		"request_plan_reevaluation": false
	})
	combat_system._active_avoidances.erase(EXPLICIT_AVOID_NPC_ID)
	combat_system._advance_avoidance_units()
	await process_frame
	var explicit_avoidance := _find_avoidance(combat_system.get_active_avoidances(), EXPLICIT_AVOID_NPC_ID)
	_check(not explicit_avoidance.is_empty(), "T0209 explicit avoid_combat mode did not route away from threats")
	_check(station_controller.is_world_position_inside_station(_dict_to_vector3(explicit_avoidance.get("target_position", {}))), "T0209 explicit avoidance target left station: %s" % explicit_avoidance)

	print("T0209_WEIGHTED_STATION_AVOIDANCE_DIAGNOSTICS %s" % JSON.stringify({
		"enemy_detection_range": enemy_detection_range,
		"avoidance_range": avoidance_range,
		"weighted_direction": field.get("direction", Vector3.ZERO),
		"boundary_resolution": boundary_resolution,
		"building_resolution": building_resolution,
		"civilian_avoidance": civilian_avoidance,
		"explicit_avoidance": explicit_avoidance
	}))
	combat_system.clear_spawned_enemies()
	_finish()


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	combat_system._active_enemies[enemy_id] = enemy
	var actor_path: NodePath = combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	var actor := combat_system.get_node_or_null(actor_path) as Node3D
	if actor != null:
		actor.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var actor := _get_npc_node(npc_system, npc_id) as Node3D
	if actor == null:
		_failures.append("T0209 NPC actor missing: %s" % npc_id)
		return
	if actor.has_method("stop_movement"):
		actor.stop_movement()
	actor.global_position = position


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _mode(npc_system: Node, npc_id: String) -> String:
	return str(npc_system.get_npc_behavior_mode_snapshot(npc_id).get("behavior_mode", ""))


func _find_avoidance(avoidances: Array[Dictionary], npc_id: String) -> Dictionary:
	for avoidance in avoidances:
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _dict_to_vector3(raw_value: Variant) -> Vector3:
	if raw_value is Vector3:
		return raw_value
	if raw_value is Dictionary:
		var value := raw_value as Dictionary
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0209_WEIGHTED_STATION_AVOIDANCE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
