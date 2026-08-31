extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ACTOR_SCENE := preload("res://scenes/debug/ActorMotionBody.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat != null and controller != null and formal_root != null and time_system != null, "T0241 production dependencies missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(false)
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	var stages: Array = controller.get_enemy_route_world().get("stages", [])
	_check(navigation_map.is_valid() and stages.size() >= 4, "T0241 production route/navigation fixture missing")
	if not _failures.is_empty():
		_finish()
		return

	var start_base: Vector3 = (stages[1] as Dictionary).get("position", Vector3(8.0, 0.0, 225.0))
	var first_target_base: Vector3 = (stages[2] as Dictionary).get("position", Vector3(10.0, 0.0, 165.0))
	var replacement_target_base: Vector3 = (stages[3] as Dictionary).get("position", Vector3(6.0, 0.0, 105.0))
	var results: Array[Dictionary] = []
	results.append(await _exercise_profile(
		combat,
		formal_root,
		navigation_map,
		"enemy_foot",
		start_base + Vector3(-1.2, 0.0, 0.0),
		first_target_base + Vector3(-1.2, 0.0, 0.0),
		replacement_target_base + Vector3(-1.2, 0.0, 0.0)
	))
	results.append(await _exercise_profile(
		combat,
		formal_root,
		navigation_map,
		"enemy_mounted",
		start_base + Vector3(1.2, 0.0, 0.0),
		first_target_base + Vector3(1.2, 0.0, 0.0),
		replacement_target_base + Vector3(1.2, 0.0, 0.0)
	))

	if _failures.is_empty():
		print("T0241_ENEMY_COMBAT_RETARGET_SPEED_OK %s" % JSON.stringify(results))
	_finish()


func _exercise_profile(
	combat: Node,
	formal_root: Node3D,
	navigation_map: RID,
	profile_id: String,
	start_position: Vector3,
	first_target: Vector3,
	replacement_target: Vector3
) -> Dictionary:
	var actor := ACTOR_SCENE.instantiate() as ActorMotionBody
	actor.name = "T0241_%s" % profile_id
	formal_root.add_child(actor)
	actor.configure_profile(profile_id)
	actor.set_navigation_map(navigation_map)
	actor.set_runtime_avoidance_enabled(false, "t0241_open_lane")
	actor.global_position = NavigationServer3D.map_get_closest_point(navigation_map, start_position)
	first_target = NavigationServer3D.map_get_closest_point(navigation_map, first_target)
	replacement_target = NavigationServer3D.map_get_closest_point(navigation_map, replacement_target)
	var options: Dictionary = combat._get_combat_motion_options("enemy_unit_approach")
	_check(bool(options.get("preserve_velocity_on_supersede", false)), "T0241 enemy combat motion did not enable retarget momentum preservation")
	_check(actor.request_motion(first_target, "t0241_%s_first" % profile_id, options), "T0241 %s first motion request failed" % profile_id)
	for _frame in range(35):
		await physics_frame
	var before := actor.debug_get_motion_snapshot()
	var speed_before := float(before.get("actual_speed", 0.0))
	var profile_speed := float(before.get("profile_base_speed", 0.0))
	_check(speed_before >= profile_speed * 0.80, "T0241 %s did not reach cruise speed before retarget: %.3f / %.3f" % [profile_id, speed_before, profile_speed])

	_check(actor.request_motion(replacement_target, "t0241_%s_retarget" % profile_id, options), "T0241 %s replacement request failed" % profile_id)
	var handoff := actor.debug_get_motion_snapshot()
	_check(bool(handoff.get("last_motion_preserved_velocity", false)), "T0241 %s replacement discarded active velocity" % profile_id)
	_check(float(handoff.get("last_preserved_velocity_speed", 0.0)) >= speed_before * 0.90, "T0241 %s preserved velocity was unexpectedly reduced: %s" % [profile_id, handoff])
	await physics_frame
	var after := actor.debug_get_motion_snapshot()
	var speed_after := float(after.get("actual_speed", 0.0))
	_check(speed_after >= speed_before * 0.75, "T0241 %s retarget restarted from near zero: %.3f -> %.3f" % [profile_id, speed_before, speed_after])
	_check(int(after.get("preserved_velocity_handoff_count", 0)) == 1, "T0241 %s preserved handoff counter mismatch: %s" % [profile_id, after])
	_check(str(after.get("speed_limit_reason", "")).is_empty() == false, "T0241 %s speed diagnostics lack a limit reason" % profile_id)

	# Momentum preservation does not bypass the authored final-target braking zone.
	var direction := replacement_target - actor.global_position
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var close_target := NavigationServer3D.map_get_closest_point(
		navigation_map,
		actor.global_position + direction * 0.65
	)
	_check(actor.request_motion(close_target, "t0241_%s_close" % profile_id, options), "T0241 %s close-target request failed" % profile_id)
	await physics_frame
	var braking := actor.debug_get_motion_snapshot()
	_check(float(braking.get("desired_speed", profile_speed)) < profile_speed, "T0241 %s final target did not retain braking: %s" % [profile_id, braking])
	_check(str(braking.get("speed_limit_reason", "")) in ["final_target_braking", "physical_collision_slide"], "T0241 %s braking reason is not observable: %s" % [profile_id, braking])

	var result := {
		"profile": profile_id,
		"profile_speed": profile_speed,
		"speed_before_retarget": speed_before,
		"speed_after_retarget": speed_after,
		"preserved_speed": handoff.get("last_preserved_velocity_speed", 0.0),
		"handoff_count": after.get("preserved_velocity_handoff_count", 0),
		"cruise_reason": after.get("speed_limit_reason", ""),
		"braking_reason": braking.get("speed_limit_reason", ""),
		"braking_desired_speed": braking.get("desired_speed", 0.0)
	}
	actor.queue_free()
	await process_frame
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
