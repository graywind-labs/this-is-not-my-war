extends SceneTree


const ACTOR_SCENE := preload("res://scenes/debug/ActorMotionBody.tscn")
const QUEUE_SCRIPT := preload("res://scripts/world/DoorPassageQueueArea.gd")
const QUEUE_ID := "building_door:test"


func _init() -> void:
	var queue := Area3D.new()
	queue.set_script(QUEUE_SCRIPT)
	queue.call("configure", QUEUE_ID, "test", {
		"token_count": 8,
		"range_width": 2.6,
		"range_depth": 3.0,
		"range_height": 2.8,
		"release_grace_seconds": 0.12,
	})
	root.add_child(queue)
	await physics_frame

	var actors: Array[Node3D] = []
	for index in range(10):
		var actor := ACTOR_SCENE.instantiate() as Node3D
		var faction := "friendly" if index % 2 == 0 else "enemy"
		actor.call("configure_profile", "npc" if faction == "friendly" else "enemy_foot")
		actor.call("configure_avoidance_identity", "%s:queue_%02d" % [faction, index + 1], 0.5)
		actor.position = Vector3(float(index % 5 - 2) * 0.4, 0.0, -0.8 if index % 2 == 0 else 0.8)
		root.add_child(actor)
		actors.append(actor)
		await physics_frame
		await physics_frame

	var initial: Dictionary = queue.call("debug_get_snapshot")
	if int(initial.get("entry_count", 0)) != 10:
		_fail("Expected ten bidirectional entrants: %s" % JSON.stringify(initial))
		return
	if int(initial.get("held_token_count", 0)) != 8 or int(initial.get("overflow_count", 0)) != 2:
		_fail("Eight-token overflow contract failed: %s" % JSON.stringify(initial))
		return
	if not _validate_compact_tokens(initial, 10):
		return

	var second_actor := actors[1]
	var target := Vector3(0.0, 0.0, -6.0)
	second_actor.call("request_motion", target, "preserved_door_route", {"persistent_repath": true})
	await physics_frame
	var paused_motion: Dictionary = second_actor.call("debug_get_motion_snapshot")
	if (
		not bool(paused_motion.get("active", false))
		or not bool(paused_motion.get("door_queue_paused", false))
		or str(paused_motion.get("request_id", "")) != "preserved_door_route"
		or (paused_motion.get("target_position", Vector3.ZERO) as Vector3).distance_to(target) > 0.001
	):
		_fail("Queued actor did not preserve its active route: %s" % JSON.stringify(paused_motion))
		return

	actors[0].global_position = Vector3(0.0, 0.0, -5.0)
	for _frame in range(16):
		await physics_frame
	var compacted: Dictionary = queue.call("debug_get_snapshot")
	if int(compacted.get("entry_count", 0)) != 9 or not _validate_compact_tokens(compacted, 9):
		return
	var compacted_entries := compacted.get("entries", []) as Array
	if str((compacted_entries[0] as Dictionary).get("actor_id", "")) != "enemy:queue_02":
		_fail("Second arrival did not inherit token 1: %s" % JSON.stringify(compacted))
		return
	var resumed_motion: Dictionary = second_actor.call("debug_get_motion_snapshot")
	if (
		bool(resumed_motion.get("door_queue_paused", true))
		or str(resumed_motion.get("request_id", "")) != "preserved_door_route"
		or (resumed_motion.get("target_position", Vector3.ZERO) as Vector3).distance_to(target) > 0.001
	):
		_fail("Compacted token did not resume the unchanged route: %s" % JSON.stringify(resumed_motion))
		return

	print("T1505-P6R38 generic bidirectional door token queue verification passed: %s" % JSON.stringify({
		"initial_entry_count": initial.get("entry_count"),
		"initial_held_token_count": initial.get("held_token_count"),
		"initial_overflow_count": initial.get("overflow_count"),
		"compacted_entry_count": compacted.get("entry_count"),
		"new_head": (compacted_entries[0] as Dictionary).get("actor_id"),
		"preserved_request_id": resumed_motion.get("request_id"),
		"preserved_target": resumed_motion.get("target_position"),
	}))
	quit(0)


func _validate_compact_tokens(snapshot: Dictionary, expected_count: int) -> bool:
	var entries := snapshot.get("entries", []) as Array
	if entries.size() != expected_count:
		_fail("Unexpected queue size while validating tokens: %s" % JSON.stringify(snapshot))
		return false
	var moving_count := 0
	for index in range(entries.size()):
		var entry := entries[index] as Dictionary
		var expected_token := index + 1 if index < 8 else 0
		if int(entry.get("token_number", -1)) != expected_token:
			_fail("Door tokens were not compact: %s" % JSON.stringify(snapshot))
			return false
		if bool(entry.get("paused", false)) != (index > 0):
			_fail("Door queue pause ownership was invalid: %s" % JSON.stringify(snapshot))
			return false
		if not bool(entry.get("paused", false)):
			moving_count += 1
	if moving_count != 1:
		_fail("Door queue must have exactly one moving head: %s" % JSON.stringify(snapshot))
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
