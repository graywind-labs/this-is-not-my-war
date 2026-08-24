extends SceneTree

const MAIN_PATH := "res://scenes/main/Main.tscn"
const ACTOR_PATH := "res://scenes/debug/ActorMotionBody.tscn"
const BUILDING_ID := "chapel"
const TARGET_IDS := ["chapel_prayer_seat_01", "chapel_prayer_seat_02", "chapel_prayer_seat_03"]


func _init() -> void:
	var main_scene := load(MAIN_PATH) as PackedScene
	var actor_scene := load(ACTOR_PATH) as PackedScene
	if main_scene == null or actor_scene == null:
		_fail("A3 door queue scenes unavailable")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in 5:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var chapel := formal.get_node_or_null("BuildingRoots/Chapel") as Node3D if formal != null else null
	var region := formal.get_node_or_null("SpatialContract/StationNavigation") as NavigationRegion3D if formal != null else null
	if controller == null or formal == null or chapel == null or region == null:
		_fail("A3 door queue hierarchy incomplete")
		return
	controller.debug_set_preview_enabled(true)
	for _frame in 4:
		await physics_frame
	var navigation_map := region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)

	var starts := [
		chapel.to_global(Vector3(-0.80, 0.0, 8.40)),
		chapel.to_global(Vector3(0.00, 0.0, 8.75)),
		chapel.to_global(Vector3(0.80, 0.0, 8.40)),
	]
	var actors: Array[ActorMotionBody] = []
	for index in TARGET_IDS.size():
		var actor := actor_scene.instantiate() as ActorMotionBody
		if actor == null:
			_fail("ActorMotionBody failed to instantiate")
			return
		actor.name = "DoorQueueActor%d" % (index + 1)
		formal.add_child(actor)
		actor.global_position = starts[index]
		actors.append(actor)
	await physics_frame

	for index in actors.size():
		var actor := actors[index]
		actor.navigation_agent.set_navigation_map(navigation_map)
		var route: Dictionary = controller.get_building_spatial_route(BUILDING_ID, TARGET_IDS[index])
		if route.is_empty() or str(route.get("target_fixture_id", "")).is_empty():
			_fail("Door queue target route unavailable: %s" % TARGET_IDS[index])
			return
		if not actor.request_motion(route.get("interior_target_position", Vector3.ZERO), "door_queue_%d" % index):
			_fail("Door queue actor rejected motion request: %d" % index)
			return

	var minimum_clearance := INF
	var maximum_lateral_convergence := 0.0
	var all_arrived := false
	for _frame in 900:
		await physics_frame
		for first in actors.size():
			for second in range(first + 1, actors.size()):
				minimum_clearance = minf(minimum_clearance, _horizontal_distance(actors[first].global_position, actors[second].global_position))
		for index in actors.size():
			maximum_lateral_convergence = maxf(maximum_lateral_convergence, absf(starts[index].x - actors[index].global_position.x))
		all_arrived = true
		for actor in actors:
			if str(actor.debug_get_motion_snapshot().get("state", "")) != "arrived":
				all_arrived = false
				break
		if all_arrived:
			break

	if not all_arrived:
		_fail("Three actors did not pass the chapel door: %s" % str(_actor_snapshots(actors)))
		return
	if minimum_clearance < 0.66:
		_fail("Door queue actors overlapped their physical capsules: %.3f" % minimum_clearance)
		return
	if maximum_lateral_convergence < 0.20:
		_fail("Door queue did not demonstrate lateral convergence through the 1.8m entrance: %.3f" % maximum_lateral_convergence)
		return
	for actor in actors:
		var snapshot := actor.debug_get_motion_snapshot()
		if int(snapshot.get("avoidance_callback_count", 0)) <= 0:
			_fail("Door queue actor did not receive avoidance velocity: %s" % str(snapshot))
			return

	print("T0129C A3 formal 1.8m door queue verification passed: %s" % JSON.stringify({
		"actors": actors.size(),
		"minimum_clearance": minimum_clearance,
		"maximum_lateral_convergence": maximum_lateral_convergence,
		"snapshots": _actor_snapshots(actors),
	}))
	quit(0)


func _actor_snapshots(actors: Array[ActorMotionBody]) -> Array:
	var snapshots: Array = []
	for actor in actors:
		snapshots.append(actor.debug_get_motion_snapshot())
	return snapshots


func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
