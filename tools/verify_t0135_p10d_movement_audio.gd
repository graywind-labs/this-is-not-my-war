extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ACTOR_MOTION_SCENE := preload("res://scenes/debug/ActorMotionBody.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var controller := main.get_node("Presentation/MovementAudioController")
	var npc_system := main.get_node("Systems/NPCSystem")
	var horse_system := main.get_node("Systems/HorseSystem")
	var time_system := main.get_node("Systems/TimeSystem")
	var audio_manager := root.get_node("AudioManager")
	var npc_ids: Array[String] = npc_system.get_npc_ids()
	_assert(not npc_ids.is_empty(), "formal NPC list is empty")
	if npc_ids.is_empty():
		return
	var npc_id := npc_ids[0]
	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var npc_path: NodePath = npc_paths.get(npc_id, NodePath())
	_assert(not npc_path.is_empty(), "formal NPC node path is unavailable")
	if npc_path.is_empty():
		return
	var npc := npc_system.get_node(npc_path)

	_assert(bool(controller.get_debug_snapshot().get("initialized", false)), "controller did not initialize")
	_assert(audio_manager.has_asset("sfx_foley_run_unified_loop"), "unified run asset is missing")
	_assert(audio_manager.has_asset("sfx_horse_run"), "horse run asset is missing")
	_assert(int(controller.get_debug_snapshot().get("active_loop_count", -1)) == 0, "movement audio should start silent")
	_assert_exclusions(controller)

	npc.configure_navigation_motion(false)
	npc.set("_is_moving", true)
	npc.set("_locomotion_state", "walk")
	npc.set("_actual_horizontal_speed", 3.2)
	controller.debug_force_refresh()
	_assert(int(controller.get_debug_snapshot().get("active_loop_count", -1)) == 0, "NPC walking incorrectly played movement audio")

	npc.set("_locomotion_state", "run")
	npc.set("_actual_horizontal_speed", 5.0)
	controller.debug_force_refresh()
	_assert_loop(controller, "npc:%s" % npc_id, "sfx_foley_run_unified_loop", "npc")
	_assert_all_movement_players_are_positional(audio_manager)
	_assert_source_tracks_npc(controller, npc_system, npc_id)

	npc.set("_actual_horizontal_speed", 3.24)
	controller.debug_force_refresh()
	_assert(int(controller.get_debug_snapshot().get("active_loop_count", -1)) == 0, "run intent below the actual-speed threshold kept playing")
	_assert(not audio_manager.is_loop_active("movement_npc_%s" % npc_id), "NPC loop was not stopped immediately")

	npc_system.update_npc_state(npc_id, {
		"behavior_mode": "combat",
		"combat_mounted": true,
		"satiety": 50.0,
	})
	npc.set("_is_moving", true)
	npc.set("_locomotion_state", "run")
	npc.set("_actual_horizontal_speed", 5.0)
	controller.debug_force_refresh()
	_assert_loop(controller, "mounted_npc:%s" % npc_id, "sfx_horse_run", "mounted_npc")
	_assert(not (controller.get_debug_snapshot().get("active_loops", {}) as Dictionary).has("npc:%s" % npc_id), "mounted NPC also played humanoid footsteps")

	npc.set("_is_moving", false)
	npc.set("_actual_horizontal_speed", 0.0)
	npc_system.update_npc_state(npc_id, {"combat_mounted": false, "behavior_mode": "work"})
	var horse_ids: Array[String] = horse_system.get_horse_ids()
	_assert(not horse_ids.is_empty(), "formal horse list is empty")
	if horse_ids.is_empty():
		return
	var horse_id := horse_ids[0]
	var horse_actor := ACTOR_MOTION_SCENE.instantiate()
	horse_actor.name = "MovementAudioHorseProbe"
	horse_system.add_child(horse_actor)
	await process_frame
	horse_actor.global_position = Vector3(11.0, 0.0, 17.0)
	horse_actor.set("_motion_active", true)
	horse_actor.set("_motion_paused", false)
	horse_actor.set("_last_actual_speed", 7.0)
	var horse_motion_actors: Dictionary = horse_system.get("_horse_motion_actors")
	horse_motion_actors[horse_id] = horse_actor
	horse_system.set("_horse_motion_actors", horse_motion_actors)
	controller.debug_force_refresh()
	_assert_loop(controller, "horse:%s" % horse_id, "sfx_horse_run", "horse")
	_assert_horse_source_uses_motion_body(controller, horse_id, horse_actor)
	horse_actor.set("_last_actual_speed", 3.2)
	controller.debug_force_refresh()
	_assert(not (controller.get_debug_snapshot().get("active_loops", {}) as Dictionary).has("horse:%s" % horse_id), "horse walking kept the run loop active")
	horse_motion_actors.erase(horse_id)
	horse_system.set("_horse_motion_actors", horse_motion_actors)
	horse_actor.queue_free()
	npc_system.update_npc_state(npc_id, {
		"behavior_mode": "combat",
		"combat_mounted": true,
		"satiety": 50.0,
	})
	npc.set("_is_moving", true)
	npc.set("_locomotion_state", "run")
	npc.set("_actual_horizontal_speed", 5.0)
	controller.debug_force_refresh()
	_assert_loop(controller, "mounted_npc:%s" % npc_id, "sfx_horse_run", "mounted_npc")

	time_system.set_paused(true)
	controller.debug_force_refresh()
	_assert(int(controller.get_debug_snapshot().get("active_loop_count", -1)) == 0, "pause did not stop movement audio immediately")
	_assert(not audio_manager.is_loop_active("movement_mounted_npc_%s" % npc_id), "mounted loop survived pause")
	time_system.set_paused(false)

	_assert(not controller.debug_is_horse_running({"active": true, "paused": false, "actual_speed": 3.2}), "horse walking was classified as running")
	_assert(not controller.debug_is_horse_running({"active": true, "paused": true, "actual_speed": 7.0}), "paused horse was classified as running")
	_assert(controller.debug_is_horse_running({"active": true, "paused": false, "actual_speed": 7.0}), "actual horse run was not classified as running")

	npc.set("_is_moving", false)
	npc.set("_actual_horizontal_speed", 0.0)
	npc_system.update_npc_state(npc_id, {"combat_mounted": false, "behavior_mode": "work"})
	controller.debug_force_refresh()
	main.queue_free()
	await process_frame
	await process_frame
	for raw_key in audio_manager.get_loop_snapshot().keys():
		_assert(not str(raw_key).begins_with("movement_"), "movement loop survived Main teardown: %s" % str(raw_key))

	print("T0135_P10D_MOVEMENT_AUDIO_PASS actual_speed=pass immediate_stop=pass mounted=pass positional=pass pause=pass")
	quit(0)


func _assert_exclusions(controller: Node) -> void:
	var excluded: Array = controller.get_debug_snapshot().get("excluded_movement", [])
	for expected in ["npc_walk", "horse_walk", "horse_trot"]:
		_assert(excluded.has(expected), "missing movement exclusion: %s" % expected)
	_assert(str(controller.get_debug_snapshot().get("stop_mode", "")) == "immediate", "movement stop mode is not immediate")


func _assert_loop(controller: Node, source_key: String, asset_id: String, entity_kind: String) -> void:
	var loops: Dictionary = controller.get_debug_snapshot().get("active_loops", {})
	_assert(loops.has(source_key), "missing movement loop: %s" % source_key)
	var loop: Dictionary = loops.get(source_key, {})
	_assert(str(loop.get("asset_id", "")) == asset_id, "wrong asset for %s" % source_key)
	_assert(str(loop.get("entity_kind", "")) == entity_kind, "wrong entity kind for %s" % source_key)


func _assert_all_movement_players_are_positional(audio_manager: Node) -> void:
	for raw_key in audio_manager.get_loop_snapshot().keys():
		var loop_key := str(raw_key)
		if not loop_key.begins_with("movement_"):
			continue
		var loop: Dictionary = audio_manager.get_loop_snapshot().get(loop_key, {})
		_assert(str(loop.get("player_type", "")) == "AudioStreamPlayer3D", "movement loop is not positional")
		_assert(str(loop.get("bus", "")) == "Foley", "movement loop is not routed to Foley bus")


func _assert_source_tracks_npc(controller: Node, npc_system: Node, npc_id: String) -> void:
	var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
	_assert(raw_position is Vector3, "NPC world position is unavailable")
	if not raw_position is Vector3:
		return
	var sources: Dictionary = controller.get_debug_snapshot().get("sources", {})
	var source: Dictionary = sources.get("npc:%s" % npc_id, {})
	var source_position: Vector3 = source.get("global_position", Vector3.ZERO)
	_assert(is_equal_approx(source_position.x, raw_position.x), "movement source X does not follow NPC")
	_assert(is_equal_approx(source_position.z, raw_position.z), "movement source Z does not follow NPC")


func _assert_horse_source_uses_motion_body(controller: Node, horse_id: String, horse_actor: Node3D) -> void:
	var sources: Dictionary = controller.get_debug_snapshot().get("sources", {})
	var source: Dictionary = sources.get("horse:%s" % horse_id, {})
	var source_position: Vector3 = source.get("global_position", Vector3.ZERO)
	_assert(is_equal_approx(source_position.x, horse_actor.global_position.x), "horse source X does not follow motion body")
	_assert(is_equal_approx(source_position.z, horse_actor.global_position.z), "horse source Z does not follow motion body")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("T0135 P10D verification failed: %s" % message)
	quit(1)
