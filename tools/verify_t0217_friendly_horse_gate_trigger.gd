extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

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

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gate_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FrontGate") as Node3D
	var gate_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt/GateArt/FrontGateArt") as Node3D
	_check(horse_system != null and time_system != null, "T0217 horse/time systems missing")
	_check(gate_root != null and gate_art != null, "T0217 formal front gate missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)
	gate_art.call("debug_set_open_fraction", 0.0)

	var horse_ids: Array[String] = horse_system.get_horse_ids()
	_check(not horse_ids.is_empty(), "T0217 friendly horse fixture missing")
	if not _failures.is_empty():
		_finish()
		return
	var horse_id := horse_ids[0]
	var horse_start := gate_root.to_global(Vector3(0.0, 0.2, 7.5))
	var horse_target := gate_root.to_global(Vector3(0.0, 0.2, -10.0))
	var horse_actor := horse_system._request_horse_navigation(
		horse_id,
		horse_start,
		horse_target,
		3.2,
		"t0217_friendly_horse_gate_probe"
	) as CharacterBody3D
	_check(horse_actor != null, "T0217 production HorseSystem did not create an ActorMotionBody")
	if horse_actor != null:
		_check(str(horse_actor.get_meta("horse_id", "")) == horse_id, "T0217 horse ActorMotionBody lost horse_id identity")
		_check(not horse_actor.has_meta("enemy_id"), "T0217 friendly horse ActorMotionBody gained enemy identity")
		_check(horse_actor.collision_layer & 2 != 0, "T0217 horse ActorMotionBody is invisible to the actor sensor")

	time_system.set_paused(false)
	if horse_actor != null:
		horse_actor.set_motion_paused(false)
	var maximum_open_fraction := 0.0
	var maximum_frame_displacement := 0.0
	var previous_horse_position := horse_actor.global_position if horse_actor != null else horse_start
	var crossed_gate := false
	for _frame in range(360):
		await physics_frame
		if horse_actor != null:
			maximum_frame_displacement = maxf(maximum_frame_displacement, previous_horse_position.distance_to(horse_actor.global_position))
			previous_horse_position = horse_actor.global_position
			crossed_gate = gate_root.to_local(horse_actor.global_position).z < -1.0
		maximum_open_fraction = maxf(
			maximum_open_fraction,
			float((gate_art.call("debug_get_snapshot") as Dictionary).get("open_fraction", 0.0))
		)
		if crossed_gate:
			break
	time_system.set_paused(true)
	var friendly_horse_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	_check(crossed_gate, "T0217 friendly horse did not naturally pass through the front gate")
	_check(bool(friendly_horse_snapshot.get("friendly_near", false)), "T0217 friendly horse was not recognized by the gate sensor: %s" % friendly_horse_snapshot)
	_check(maximum_open_fraction > 0.25, "T0217 friendly horse did not open the front gate: %s" % friendly_horse_snapshot)
	_check(not bool(friendly_horse_snapshot.get("leaf_collisions_enabled", true)), "T0217 moving/open gate leaves retained physical collision: %s" % friendly_horse_snapshot)
	_check(_gate_leaf_shapes_disabled(gate_art), "T0217 moving/open gate CollisionShape3D nodes are still enabled")
	_check(maximum_frame_displacement <= 3.2 / 60.0 + 0.01, "T0217 opening leaves pushed the horse above its configured speed: %.4f" % maximum_frame_displacement)

	horse_system._release_horse_motion_actor(horse_id, "t0217_friendly_horse_probe_finished")
	for _frame in range(150):
		await physics_frame
	gate_art.call("debug_set_open_fraction", 0.0)

	# The enemy identity remains authoritative even if a mounted enemy or a test
	# fixture also carries horse metadata.
	var enemy_horse_probe := _make_enemy_horse_probe()
	root.add_child(enemy_horse_probe)
	enemy_horse_probe.global_position = gate_root.to_global(Vector3(0.0, 0.2, 2.0))
	for _frame in range(40):
		await physics_frame
	var enemy_horse_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	_check(not bool(enemy_horse_snapshot.get("friendly_near", true)), "T0217 enemy horse was misclassified as friendly: %s" % enemy_horse_snapshot)
	_check(float(enemy_horse_snapshot.get("open_fraction", 1.0)) <= 0.01, "T0217 enemy horse opened the front gate: %s" % enemy_horse_snapshot)
	_check(bool(enemy_horse_snapshot.get("leaf_collisions_enabled", false)), "T0217 fully closed gate did not restore leaf collision: %s" % enemy_horse_snapshot)
	_check(not _gate_leaf_shapes_disabled(gate_art), "T0217 fully closed gate CollisionShape3D nodes stayed disabled")
	enemy_horse_probe.queue_free()

	print("T0217_FRIENDLY_HORSE_GATE_TRIGGER_DIAGNOSTICS %s" % JSON.stringify({
		"horse_id": horse_id,
		"maximum_open_fraction": maximum_open_fraction,
		"maximum_frame_displacement": maximum_frame_displacement,
		"crossed_gate": crossed_gate,
		"friendly_horse_gate": friendly_horse_snapshot,
		"enemy_horse_gate": enemy_horse_snapshot
	}))
	_finish()


func _make_enemy_horse_probe() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "EnemyHorseGateProbe"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("horse_id", "enemy_horse_probe")
	body.set_meta("enemy_id", "enemy_horse_probe")
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape_node.position.y = 0.9
	shape_node.shape = capsule
	body.add_child(shape_node)
	return body


func _gate_leaf_shapes_disabled(gate_art: Node3D) -> bool:
	var left := gate_art.get_node_or_null("LeftDoorHinge/DoorLeafCollision") as CollisionShape3D
	var right := gate_art.get_node_or_null("RightDoorHinge/DoorLeafCollision") as CollisionShape3D
	return left != null and right != null and left.disabled and right.disabled


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0217_FRIENDLY_HORSE_GATE_TRIGGER_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
