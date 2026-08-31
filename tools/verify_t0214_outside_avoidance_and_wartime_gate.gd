extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const CIVILIAN_NPC_ID := "cook_01"

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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var gate_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FrontGate") as Node3D
	var gate_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt/GateArt/FrontGateArt") as Node3D
	_check(combat_system != null and npc_system != null and building_system != null, "T0214 core systems missing")
	_check(time_system != null and station_controller != null and gate_root != null and gate_art != null, "T0214 formal gate runtime missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0214 formal wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0214 active enemy fixture missing")
	if not _failures.is_empty():
		_finish()
		return

	var reentry: Dictionary = station_controller.get_front_gate_inside_avoidance_target()
	var reentry_position: Vector3 = reentry.get("position", Vector3.ZERO)
	_check(bool(reentry.get("ok", false)), "T0214 front-gate inside reentry target failed: %s" % reentry)
	_check(station_controller.is_world_position_inside_station(reentry_position), "T0214 reentry target is not inside station: %s" % reentry)
	_check(station_controller.get_building_area_overlap(reentry_position, 0.4).is_empty(), "T0214 reentry target overlaps a station entity: %s" % reentry)

	# Put one civilian and one threat outside the front gate. The avoidance target
	# must ignore the outward repulsion result until the civilian has re-entered.
	var outside_origin := gate_root.to_global(Vector3(0.0, 0.2, 7.5))
	var threat_position := gate_root.to_global(Vector3(0.0, 0.2, 17.5))
	_set_npc_position(npc_system, CIVILIAN_NPC_ID, outside_origin)
	for index in range(enemy_ids.size()):
		_set_enemy_position(
			combat_system,
			enemy_ids[index],
			threat_position if index == 0 else threat_position + Vector3(100.0 + index * 5.0, 0.0, 0.0)
		)
	npc_system.set_npc_behavior_mode(CIVILIAN_NPC_ID, "work", "t0214_outside_fixture", {
		"force_idle": true,
		"request_plan_reevaluation": false
	})
	combat_system._active_avoidances.erase(CIVILIAN_NPC_ID)
	combat_system._advance_behavior_mode_contacts()
	await process_frame
	var avoidance := _find_avoidance(combat_system.get_active_avoidances(), CIVILIAN_NPC_ID)
	_check(str(avoidance.get("movement_phase", "")) == "returning_to_station", "T0214 outside avoidance did not enter reentry phase: %s" % avoidance)
	_check(str(avoidance.get("target_policy", "")) == "front_gate_inside_reentry", "T0214 outside avoidance used the wrong target policy: %s" % avoidance)
	_check(str(avoidance.get("reentry_gate_id", "")) == "front_gate", "T0214 outside avoidance did not route through front gate: %s" % avoidance)
	_check(_to_vector3(avoidance.get("target_position", {})).distance_to(reentry_position) <= 0.05, "T0214 avoidance target differs from formal reentry point: %s / %s" % [avoidance, reentry])
	var civilian_actor := _get_npc_node(npc_system, CIVILIAN_NPC_ID)
	var motion: Dictionary = civilian_actor.debug_get_motion_snapshot() if civilian_actor != null else {}
	_check(bool(motion.get("active", false)), "T0214 outside civilian did not start existing navigation: %s" % motion)
	_check(str(motion.get("request_id", "")) == "avoid_shelter_%s" % CIVILIAN_NPC_ID, "T0214 reentry did not reuse the avoidance movement request: %s" % motion)
	var naturally_entered := false
	var natural_gate_max_open := 0.0
	time_system.set_paused(false)
	for _frame in range(480):
		await physics_frame
		natural_gate_max_open = maxf(
			natural_gate_max_open,
			float((gate_art.call("debug_get_snapshot") as Dictionary).get("open_fraction", 0.0))
		)
		if civilian_actor != null and station_controller.is_world_position_inside_station(civilian_actor.global_position):
			naturally_entered = true
			break
	time_system.set_paused(true)
	_check(naturally_entered, "T0214 outside avoidance NPC did not naturally cross the front gate")
	_check(natural_gate_max_open > 0.05, "T0214 natural reentry never requested the wartime gate to open")

	# An active enemy no longer locks the sensor. A friendly body inside the same
	# front-gate sensor opens the physical leaves; an enemy body alone still cannot.
	if civilian_actor != null:
		civilian_actor.stop_movement()
		civilian_actor.global_position = gate_root.to_global(Vector3(0.0, 0.2, -3.4))
	for _frame in range(24):
		await physics_frame
	var open_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	_check(combat_system.get_active_enemy_count() > 0, "T0214 wartime gate fixture lost all enemies")
	_check(bool(open_snapshot.get("friendly_near", false)), "T0214 friendly NPC was not detected near gate: %s" % open_snapshot)
	_check(not bool(open_snapshot.get("combat_locked", true)), "T0214 front gate remained combat-locked: %s" % open_snapshot)
	_check(float(open_snapshot.get("open_fraction", 0.0)) > 0.25, "T0214 friendly NPC did not open gate during combat: %s" % open_snapshot)

	var gate_target: Dictionary = combat_system._make_building_target("front_gate")
	var enemy_id := enemy_ids[0]
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var candidates_open: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(enemy_id, enemy, gate_target)
	_check(candidates_open.size() == 5, "T0214 open gate changed the five door-panel attack positions: %s" % [candidates_open])
	for candidate in candidates_open:
		_check(str(candidate.get("slot_id", "")).contains("building:front_gate"), "T0214 open gate candidate lost front-gate identity: %s" % candidate)

	# The fixed non-blocking contact area keeps physical damage authoritative even
	# while both moving door leaves are rotated away from the closed plane.
	gate_art.call("debug_set_open_fraction", 1.0)
	await physics_frame
	var contact_area := gate_art.get_node_or_null("FixedGateCombatContactArea") as Area3D
	_check(contact_area != null and bool(contact_area.get_meta("physical_blocking", true)) == false, "T0214 fixed non-blocking gate contact area missing")
	_check(contact_area != null and contact_area.collision_layer == 8, "T0214 gate contact area does not use the isolated enemy-gate layer")
	if contact_area != null:
		var contact_center := contact_area.global_position + Vector3.UP * 1.1
		var gate_forward: Vector3 = gate_root.global_basis * Vector3.BACK
		gate_forward.y = 0.0
		gate_forward = gate_forward.normalized()
		var excluded_rids: Array[RID] = []
		var contact: Dictionary = combat_system._query_melee_segment_contact(
			contact_center + gate_forward,
			contact_center - gate_forward,
			0.12,
			excluded_rids,
			"enemy",
			gate_target
		)
		_check(str(contact.get("status", "")) == "hit", "T0214 open-gate melee segment did not hit a combat contact: %s" % contact)
		_check(str(contact.get("actual_target_type", "")) == "building" and str(contact.get("actual_target_id", "")) == "front_gate", "T0214 open-gate contact was not classified as front_gate: %s" % contact)
		var friendly_contact: Dictionary = combat_system._query_melee_segment_contact(
			contact_center + gate_forward,
			contact_center - gate_forward,
			0.12,
			excluded_rids,
			"friendly",
			{"type": "enemy", "id": enemy_id}
		)
		_check(friendly_contact.is_empty(), "T0214 isolated gate contact layer blocked a friendly attack through the open gate: %s" % friendly_contact)
		var gate_before: Dictionary = building_system.get_building("front_gate")
		var hp_before := int(gate_before.get("hp", 0))
		var damage: Dictionary = combat_system._apply_enemy_melee_contact_damage(enemy, gate_target, contact)
		var hp_after := int(building_system.get_building("front_gate").get("hp", 0))
		_check(not damage.is_empty() and hp_after < hp_before, "T0214 open gate did not accept authoritative front-gate damage: %s / %s -> %s" % [damage, hp_before, hp_after])

	if civilian_actor != null:
		civilian_actor.global_position = gate_root.to_global(Vector3(0.0, 0.2, -12.0))
	gate_art.call("debug_set_open_fraction", 0.0)
	for _frame in range(120):
		await physics_frame
	var enemy_probe := _make_actor("EnemyGateProbe", "enemy_id")
	root.add_child(enemy_probe)
	enemy_probe.global_position = gate_root.to_global(Vector3(0.0, 0.2, 2.0))
	for _frame in range(40):
		await physics_frame
	var enemy_only_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	_check(not bool(enemy_only_snapshot.get("friendly_near", true)), "T0214 enemy body was misclassified as friendly: %s" % enemy_only_snapshot)
	_check(float(enemy_only_snapshot.get("open_fraction", 1.0)) <= 0.01, "T0214 enemy alone opened the front gate: %s" % enemy_only_snapshot)
	enemy_probe.queue_free()

	print("T0214_OUTSIDE_AVOIDANCE_AND_WARTIME_GATE_DIAGNOSTICS %s" % JSON.stringify({
		"reentry": reentry,
		"avoidance": avoidance,
		"open_gate": open_snapshot,
		"enemy_only_gate": enemy_only_snapshot,
		"natural_gate_max_open": natural_gate_max_open,
		"naturally_entered": naturally_entered,
		"open_gate_attack_position_count": candidates_open.size()
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
		_failures.append("T0214 NPC actor missing: %s" % npc_id)
		return
	if actor.has_method("stop_movement"):
		actor.stop_movement()
	actor.global_position = position


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _find_avoidance(avoidances: Array[Dictionary], npc_id: String) -> Dictionary:
	for avoidance in avoidances:
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _make_actor(node_name: String, identity_meta: String) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta(identity_meta, node_name)
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape_node.position.y = 0.9
	shape_node.shape = capsule
	body.add_child(shape_node)
	return body


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0214_OUTSIDE_AVOIDANCE_AND_WARTIME_GATE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
