extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/debug/ActorMotionSandbox.tscn")
const QUEUE_ID := "building_door:forward_resume_probe"


func _init() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	root.add_child(sandbox)
	for _frame in range(8):
		await physics_frame
	var crossed_actor := sandbox.debug_get_actor("route") as ActorMotionBody
	var not_crossed_actor := sandbox.debug_get_actor("avoid_right") as ActorMotionBody
	if crossed_actor == null or not_crossed_actor == null:
		_fail("Actor motion sandbox actors are missing")
		return
	if not await _stage_queue_resume_probe(crossed_actor, true):
		return
	if not await _stage_queue_resume_probe(not_crossed_actor, false):
		return

	var plane_actor := sandbox.debug_get_actor("avoid_left") as ActorMotionBody
	if plane_actor == null:
		_fail("Target-plane probe actor is missing")
		return
	plane_actor.set_door_queue_state(QUEUE_ID, 2, true)
	var plane_start := plane_actor.global_position
	var forward := Vector3(1.0, 0.0, 0.0)
	var target := plane_start + forward * 2.0
	var arrived_requests: Array[String] = []
	plane_actor.motion_arrived.connect(
		func(request_id: String, _target_position: Vector3) -> void:
			arrived_requests.append(request_id)
	)
	if not plane_actor.request_motion(target, "door_target_plane_probe", {
		"target_pass_forward_direction": forward,
		"target_pass_lateral_tolerance": 1.3,
		"target_pass_margin": 0.06,
	}):
		_fail("Could not start target-plane probe")
		return
	plane_actor.global_position = target + forward * 0.5
	plane_actor.set_door_queue_state(QUEUE_ID, 1, false)
	await physics_frame
	var plane_snapshot := plane_actor.debug_get_motion_snapshot()
	if (
		not arrived_requests.has("door_target_plane_probe")
		or str(plane_snapshot.get("last_result", "")) != "arrived"
		or int(plane_snapshot.get("target_plane_pass_completion_count", 0)) != 1
	):
		_fail("Passed formal door checkpoint was chased backward: %s" % JSON.stringify(plane_snapshot))
		return

	print("T1505-P6R51 door queue forward-resume verification passed")
	quit(0)


func _stage_queue_resume_probe(actor: ActorMotionBody, crossed: bool) -> bool:
	actor.set_door_queue_state(QUEUE_ID, 2, true)
	var path := actor.navigation_agent.get_current_navigation_path()
	var path_index := actor.navigation_agent.get_current_navigation_path_index()
	if path.size() < 2 or path_index < 0 or path_index >= path.size() - 1:
		_fail("Navigation path is not ready for queue-resume probe")
		return false
	var waypoint: Vector3 = path[path_index]
	var path_direction: Vector3 = (
		waypoint - path[path_index - 1]
		if path_index > 0
		else path[path_index + 1] - waypoint
	)
	path_direction.y = 0.0
	if path_direction.length_squared() <= 0.0001:
		_fail("Queue-resume path direction is degenerate")
		return false
	path_direction = path_direction.normalized()
	actor.global_position = waypoint + path_direction * (0.55 if crossed else -0.55)
	var request_id := str(actor.debug_get_motion_snapshot().get("request_id", ""))
	var target: Vector3 = actor.debug_get_motion_snapshot().get("target_position", Vector3.ZERO)
	var path_before_resume := actor.navigation_agent.get_current_navigation_path()
	actor.set_door_queue_state(QUEUE_ID, 1, false)
	var resumed := actor.debug_get_motion_snapshot()
	var catchup_count := int(resumed.get("door_queue_resume_path_catchup_count", 0))
	if crossed:
		if (
			catchup_count <= 0
			or actor.navigation_agent.get_current_navigation_path_index() <= path_index
			or str(resumed.get("request_id", "")) != request_id
			or (resumed.get("target_position", Vector3.ZERO) as Vector3).distance_to(target) > 0.001
			or actor.navigation_agent.get_current_navigation_path() != path_before_resume
		):
			_fail("Queue head did not advance the stale passed path point in place: %s" % JSON.stringify(resumed))
			return false
		var position_before_motion := actor.global_position
		await physics_frame
		var displacement := actor.global_position - position_before_motion
		displacement.y = 0.0
		if displacement.dot(path_direction) < -0.01:
			_fail("Promoted queue head moved backward after path catch-up: %s" % JSON.stringify(actor.debug_get_motion_snapshot()))
			return false
	elif catchup_count != 0 or actor.navigation_agent.get_current_navigation_path_index() != path_index:
		_fail("Queue resume advanced a path point that the actor had not crossed: %s" % JSON.stringify(resumed))
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
