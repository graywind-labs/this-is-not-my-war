extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup.set("_startup_running", true)
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var front_gate := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt/GateArt/FrontGateArt") as FormalGateArtView
	var rear_gate := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt/GateArt/BackGateArt") as FormalGateArtView
	_check(combat != null and time_system != null and front_gate != null and rear_gate != null, "T0244 dependencies missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	front_gate.debug_set_open_fraction(0.0)
	rear_gate.debug_set_open_fraction(0.0)
	await physics_frame
	await physics_frame
	var peaceful := rear_gate.debug_get_snapshot()
	_check(bool(peaceful.get("disable_leaf_collision_while_enemy_present", false)), "T0244 rear-gate policy is not configured: %s" % peaceful)
	_check(int(peaceful.get("active_enemy_count", -1)) == 0, "T0244 peaceful rear gate detected enemies: %s" % peaceful)
	_check(bool(peaceful.get("leaf_collisions_enabled", false)), "T0244 intact peaceful rear gate did not block: %s" % peaceful)
	_check(_all_leaf_shapes_disabled(rear_gate, false), "T0244 peaceful rear-gate leaf shapes were disabled")

	var started: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0244 could not spawn a production enemy wave: %s" % started)
	for _frame in range(3):
		await physics_frame
	var wartime := rear_gate.debug_get_snapshot()
	var wartime_front := front_gate.debug_get_snapshot()
	_check(int(wartime.get("active_enemy_count", 0)) == 8, "T0244 rear gate did not observe all active enemies: %s" % wartime)
	_check(bool(wartime.get("enemy_presence_collision_override", false)), "T0244 rear-gate combat override did not activate: %s" % wartime)
	_check(not bool(wartime.get("leaf_collisions_enabled", true)), "T0244 rear-gate leaves still block during combat: %s" % wartime)
	_check(_all_leaf_shapes_disabled(rear_gate, true), "T0244 rear-gate CollisionShape3D nodes remained enabled")
	_check(bool(wartime_front.get("leaf_collisions_enabled", false)), "T0244 enemy presence incorrectly disabled the closed front gate: %s" % wartime_front)

	var enemy_probe := _make_actor_probe("RearGateEnemyPassageProbe", "enemy_id")
	root.add_child(enemy_probe)
	var enemy_passage := await _move_probe_through_gate(enemy_probe, rear_gate, -1.0)
	_check(bool(enemy_passage.get("passed", false)), "T0244 enemy actor could not pass rear door: %s" % enemy_passage)
	enemy_probe.queue_free()
	await process_frame

	var friendly_probe := _make_actor_probe("RearGateFriendlyPassageProbe", "npc_id")
	root.add_child(friendly_probe)
	var friendly_passage := await _move_probe_through_gate(friendly_probe, rear_gate, 1.0)
	_check(bool(friendly_passage.get("passed", false)), "T0244 friendly actor could not pass rear door: %s" % friendly_passage)
	friendly_probe.queue_free()
	await process_frame

	combat.clear_spawned_enemies()
	rear_gate.debug_set_open_fraction(0.0)
	for _frame in range(3):
		await physics_frame
	var restored := rear_gate.debug_get_snapshot()
	_check(int(restored.get("active_enemy_count", -1)) == 0, "T0244 enemy cleanup did not reach rear gate: %s" % restored)
	_check(not bool(restored.get("enemy_presence_collision_override", true)), "T0244 rear-gate combat override remained latched: %s" % restored)
	_check(bool(restored.get("leaf_collisions_enabled", false)), "T0244 rear-gate leaf collision did not restore: %s" % restored)
	_check(_all_leaf_shapes_disabled(rear_gate, false), "T0244 restored rear-gate leaf shapes stayed disabled")

	print("T0244_REAR_GATE_COMBAT_PASSTHROUGH_DIAGNOSTICS %s" % JSON.stringify({
		"peaceful": peaceful,
		"wartime": wartime,
		"enemy_passage": enemy_passage,
		"friendly_passage": friendly_passage,
		"restored": restored
	}))
	_finish()


func _make_actor_probe(node_name: String, identity_meta: String) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 1
	body.set_meta(identity_meta, node_name.to_snake_case())
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	body.add_child(collision)
	return body


func _move_probe_through_gate(probe: CharacterBody3D, gate: Node3D, from_sign: float) -> Dictionary:
	var start := gate.to_global(Vector3(0.0, 0.04, from_sign * 2.1))
	var finish := gate.to_global(Vector3(0.0, 0.04, -from_sign * 2.1))
	probe.global_position = start
	await physics_frame
	var collision := probe.move_and_collide(finish - start)
	var local_after := gate.to_local(probe.global_position)
	return {
		"passed": collision == null and local_after.z * from_sign < -1.5,
		"collision": str(collision.get_collider()) if collision != null else "",
		"local_after": local_after,
		"travelled": Vector2(probe.global_position.x - start.x, probe.global_position.z - start.z).length()
	}


func _all_leaf_shapes_disabled(gate: Node, expected_disabled: bool) -> bool:
	var shapes := gate.find_children("DoorLeafCollision", "CollisionShape3D", true, false)
	if shapes.size() != 2:
		return false
	for raw_shape in shapes:
		if bool((raw_shape as CollisionShape3D).disabled) != expected_disabled:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0244_REAR_GATE_COMBAT_PASSTHROUGH_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
