extends SceneTree

const SANDBOX_SCENE_PATH := "res://scenes/debug/ActorMotionSandbox.tscn"
const EXPECTED_RESULTS := {
	"route": ["arrived", "arrived"],
	"avoid_left": ["arrived", "arrived"],
	"avoid_right": ["arrived", "arrived"],
	"stuck": ["failed", "stuck_timeout"],
	"unreachable": ["failed", "target_unreachable"]
}


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed_scene := load(SANDBOX_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("ActorMotionSandbox.tscn failed to load")
		return
	var sandbox := packed_scene.instantiate()
	root.add_child(sandbox)
	for _frame in range(900):
		await physics_frame
		var progress: Dictionary = sandbox.debug_get_sandbox_snapshot()
		if bool(progress.get("completed", false)):
			break

	var snapshot: Dictionary = sandbox.debug_get_sandbox_snapshot()
	if not bool(snapshot.get("completed", false)):
		_fail("Actor motion sandbox did not complete: %s" % str(snapshot))
		return
	if not (snapshot.get("configuration_errors", []) as Array).is_empty():
		_fail("Actor motion sandbox reported errors: %s" % str(snapshot.get("configuration_errors", [])))
		return
	if int(snapshot.get("actor_count", 0)) != 5 or int(snapshot.get("result_count", 0)) != 5:
		_fail("Expected five actors and five bounded results: %s" % str(snapshot))
		return
	if int(snapshot.get("navigation_region_count", 0)) != 1 or int(snapshot.get("static_body_count", 0)) != 2:
		_fail("Sandbox navigation/static geometry contract changed: %s" % str(snapshot))
		return

	var results: Dictionary = snapshot.get("results", {})
	for actor_id in EXPECTED_RESULTS.keys():
		var result: Dictionary = results.get(actor_id, {})
		var expected: Array = EXPECTED_RESULTS[actor_id]
		if str(result.get("outcome", "")) != str(expected[0]) or str(result.get("reason", "")) != str(expected[1]):
			_fail("Unexpected %s result. expected=%s actual=%s" % [actor_id, str(expected), str(result)])
			return

	if float(snapshot.get("maximum_route_lateral_deviation", 0.0)) < 2.0:
		_fail("Static path follower did not route around the excluded obstacle: %s" % str(snapshot))
		return
	if float(snapshot.get("minimum_avoidance_clearance", 0.0)) < 0.66:
		_fail("Head-on actors overlapped below their physical capsule envelope: %s" % str(snapshot))
		return
	if float(snapshot.get("maximum_avoidance_lateral_deviation", 0.0)) < 0.04:
		_fail("Head-on actors did not demonstrate lateral avoidance: %s" % str(snapshot))
		return
	if not bool(snapshot.get("route_pause_started", false)) or not bool(snapshot.get("route_resume_started", false)):
		_fail("Pause/resume branch was not exercised: %s" % str(snapshot))
		return
	if float(snapshot.get("pause_displacement", 1.0)) > 0.01:
		_fail("Paused actor drifted physically: %s" % str(snapshot))
		return
	if int(snapshot.get("authority_commit_count", -1)) != 0:
		_fail("Motion sandbox must not commit gameplay authority facts: %s" % str(snapshot))
		return

	var actors: Dictionary = snapshot.get("actors", {})
	for actor_id in actors.keys():
		var actor_snapshot: Dictionary = actors[actor_id]
		if (
			int(actor_snapshot.get("body_collision_layer", 0)) != 2
			or int(actor_snapshot.get("body_collision_mask", 0)) != 3
			or int(actor_snapshot.get("interaction_collision_layer", 0)) != 4
			or int(actor_snapshot.get("interaction_collision_mask", -1)) != 0
		):
			_fail("Body/interaction collision layers are not separated for %s: %s" % [actor_id, str(actor_snapshot)])
			return
		if (
			not is_equal_approx(float(actor_snapshot.get("body_radius", 0.0)), 0.35)
			or not is_equal_approx(float(actor_snapshot.get("body_height", 0.0)), 1.6)
		):
			_fail("NPC capsule profile mismatch for %s: %s" % [actor_id, str(actor_snapshot)])
			return
		if not (actor_snapshot.get("configuration_errors", []) as Array).is_empty():
			_fail("Actor configuration error for %s: %s" % [actor_id, str(actor_snapshot)])
			return
	if int((actors.get("stuck", {}) as Dictionary).get("repath_count", 0)) != 2:
		_fail("Stuck recovery should use its bounded two repaths: %s" % str(actors.get("stuck", {})))
		return
	for actor_id in ["route", "avoid_left", "avoid_right"]:
		if int((actors.get(actor_id, {}) as Dictionary).get("avoidance_callback_count", 0)) <= 0:
			_fail("Avoidance callback did not run for %s" % actor_id)
			return

	var ray_actor := sandbox.debug_get_actor("avoid_left") as ActorMotionBody
	if ray_actor == null or not ray_actor is CharacterBody3D:
		_fail("Reusable motion root must remain a CharacterBody3D")
		return
	var ray_from := ray_actor.global_position + Vector3(0.0, 3.0, 0.0)
	var ray_to := ray_actor.global_position + Vector3(0.0, -0.5, 0.0)
	var interaction_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 4)
	interaction_query.collide_with_areas = true
	interaction_query.collide_with_bodies = false
	var interaction_hit: Dictionary = sandbox.get_world_3d().direct_space_state.intersect_ray(interaction_query)
	if interaction_hit.is_empty() or not interaction_hit.get("collider") is Area3D:
		_fail("Interaction-only ray should hit the independent Area3D: %s" % str(interaction_hit))
		return
	var body_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 2)
	body_query.collide_with_areas = false
	body_query.collide_with_bodies = true
	var body_hit: Dictionary = sandbox.get_world_3d().direct_space_state.intersect_ray(body_query)
	if body_hit.is_empty() or body_hit.get("collider") != ray_actor:
		_fail("Actor-body ray should hit the CharacterBody3D, not the interaction Area: %s" % str(body_hit))
		return

	print("T0129C-A2 actor motion verification passed: %s" % JSON.stringify(snapshot))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
