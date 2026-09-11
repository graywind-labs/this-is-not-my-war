extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const PILOT_NODE_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies/FormalEnemyFoot01"
const EXPECTED_STAGES := ["spawn", "reveal", "approach_mid", "contact", "front_gate"]

var _failed := false


func _init() -> void:
	var main_scene := load(MAIN_PATH) as PackedScene
	if main_scene == null:
		_fail("Main.tscn unavailable")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	if controller == null or combat_system == null or building_system == null:
		_fail("C3-P1 runtime dependencies unavailable")
		return

	var layout_snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var production: Dictionary = controller.debug_get_production_navigation_snapshot()
	if int(layout_snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Formal station layout config is invalid: %s" % layout_snapshot)
		return
	if int(layout_snapshot.get("enemy_route_stage_count", 0)) != 10:
		_fail("Formal enemy route must preserve all ten future C3 stages: %s" % layout_snapshot)
		return
	if str(production.get("enemy_exterior_mode", "")) != "shared_open_baked_space":
		_fail("Enemy exterior must use the shared collider-baked navigation space: %s" % production)
		return
	if (
		bool(production.get("enemy_approach_region_available", true))
		or int(production.get("enemy_approach_vertex_count", -1)) != 0
		or int(production.get("enemy_approach_polygon_count", -1)) != 0
	):
		_fail("Obsolete enemy approach corridor must not constrain production navigation: %s" % production)
		return
	if bool(production.get("roads_affect_navigation", true)):
		_fail("Road presentation must not affect navigation: %s" % production)
		return
	var production_bounds := production.get("production_bounds", []) as Array
	if production_bounds.size() < 4 or float(production_bounds[3]) < 344.0:
		_fail("Production NavMesh does not cover the formal enemy exterior: %s" % production)
		return
	if int(production.get("vertex_count", 0)) <= 0 or int(production.get("polygon_count", 0)) <= 0:
		_fail("Production station navigation bake is empty: %s" % production)
		return

	var front_gate_before: Dictionary = building_system.get_building("front_gate")
	var front_gate_hp_before := float(front_gate_before.get("hp", -1.0))
	var start_result: Dictionary = combat_system.debug_run_formal_enemy_navigation_pilot()
	if (
		not bool(start_result.get("ok", false))
		or str(start_result.get("actor_profile_id", "")) != "enemy_foot"
		or str(start_result.get("route_source", "")) != "formal_station_layout"
		or str(start_result.get("spawn_stage_id", "")) != "spawn"
		or str(start_result.get("stop_stage_id", "")) != "front_gate"
		or bool(start_result.get("combat_authority_committed", true))
	):
		_fail("Formal enemy pilot start contract failed: %s" % start_result)
		return
	await physics_frame

	var actor := root.get_node_or_null(PILOT_NODE_PATH) as ActorMotionBody
	if actor == null:
		_fail("Formal enemy pilot did not create an ActorMotionBody")
		return
	actor.configure_profile("enemy_foot", {
		"profile": {"base_speed": 20.0, "acceleration": 50.0},
		"navigation_agent": {"target_desired_distance": 1.0, "path_desired_distance": 0.8}
	})
	actor.navigation_agent.max_speed = 25.0
	var body_snapshot: Dictionary = actor.debug_get_motion_snapshot()
	if (
		int(body_snapshot.get("body_collision_layer", 0)) != 2
		or int(body_snapshot.get("body_collision_mask", 0)) != 3
		or int(body_snapshot.get("interaction_collision_layer", 0)) != 4
		or str(body_snapshot.get("profile_id", "")) != "enemy_foot"
	):
		_fail("Formal enemy physics profile drifted: %s" % body_snapshot)
		return
	var body_shape := actor.get_node_or_null("BodyCollision") as CollisionShape3D
	var capsule := body_shape.shape as CapsuleShape3D if body_shape != null else null
	if capsule == null or not is_equal_approx(capsule.radius, 0.42) or not is_equal_approx(capsule.height, 1.8):
		_fail("Formal enemy capsule must be radius 0.42 m / height 1.8 m")
		return

	var reached_front_gate := false
	for _frame in range(1200):
		await physics_frame
		var pilot: Dictionary = combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()
		if str(pilot.get("phase", "")) == "front_gate_reached":
			reached_front_gate = true
			break
		if str(pilot.get("phase", "")) == "navigation_failed":
			break
	if not reached_front_gate:
		_fail("Formal enemy did not physically reach the front gate: %s" % combat_system.debug_get_formal_enemy_navigation_pilot_snapshot())
		return

	var completed: Dictionary = combat_system.debug_get_formal_enemy_navigation_pilot_snapshot()
	var motion := completed.get("motion", {}) as Dictionary
	if completed.get("completed_stage_ids", []) != EXPECTED_STAGES:
		_fail("Formal enemy route stages were not committed in order: %s" % completed)
		return
	if (
		not bool(completed.get("completed", false))
		or bool(completed.get("combat_authority_committed", true))
		or int(completed.get("active_enemy_count", -1)) != 0
		or int(motion.get("avoidance_callback_count", 0)) <= 0
		or float(motion.get("minimum_target_distance", 99.0)) > 1.05
	):
		_fail("Formal enemy arrival evidence is incomplete: %s" % completed)
		return
	var front_gate_after: Dictionary = building_system.get_building("front_gate")
	if not is_equal_approx(float(front_gate_after.get("hp", -2.0)), front_gate_hp_before):
		_fail("C3-P1 must not commit front-gate damage")
		return

	var stop_result: Dictionary = combat_system.debug_stop_formal_enemy_navigation_pilot("verification_complete")
	await process_frame
	await process_frame
	if not bool(stop_result.get("ok", false)) or root.get_node_or_null(PILOT_NODE_PATH) != null:
		_fail("Formal enemy pilot cleanup failed: %s" % stop_result)
		return

	print("T0129C A4-P1 formal enemy navigation verification passed: %s" % JSON.stringify({
		"route": EXPECTED_STAGES,
		"capsule_radius": capsule.radius,
		"capsule_height": capsule.height,
		"avoidance_callbacks": int(motion.get("avoidance_callback_count", 0)),
		"minimum_target_distance": float(motion.get("minimum_target_distance", 0.0)),
		"front_gate_hp_unchanged": true,
		"active_enemy_count": int(completed.get("active_enemy_count", -1))
	}))
	quit(0)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
