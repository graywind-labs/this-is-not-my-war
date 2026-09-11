extends SceneTree

## Run separately for each wave; never run two performance processes together.
## Exact player repro:
## godot --path . --script res://tools/benchmark_t0396_main_combat.gd -- --wave=3 --recruit=all --spawn=gm --gm=open --warmup=24 --seconds=10 --label=gm_wave3
var _options: Dictionary = {
	"wave": "3",
	"seconds": "8",
	"warmup": "2",
	"label": "sample",
	"stage": "approach",
	"camera": "default",
	"recruit": "none",
	"spawn": "natural",
	"gm": "closed",
}
var _combat_events: Dictionary = {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	call_deferred("_run")


func _run() -> void:
	seed(396)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("Systems/GameStartupSystem").set("_startup_running", true)
	# This fixture must never send provider requests, including later combat morale.
	main.get_node("Systems/LLMBridge").set("_transport_shutdown_requested", true)
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame
	var combat := main.get_node("Systems/CombatSystem")
	var clock_system := main.get_node("Systems/TimeSystem")
	clock_system.set_current_time(1, 12)
	clock_system.set_time_scale(1.0)
	clock_system.set_paused(false)
	var wave := clampi(int(_options.wave), 0, 5)
	var gm_panel := main.get_node("UI/GMPanel")
	if str(_options.get("recruit", "none")) == "all":
		gm_panel._run_recruit_and_equip_all()
	var spawn: Dictionary = {}
	var start_usec := Time.get_ticks_usec()
	if wave > 0:
		if str(_options.get("spawn", "natural")) == "gm":
			gm_panel._run_spawn_enemy_wave(wave)
			spawn = {
				"ok": combat.get_active_enemy_count() > 0,
				"spawned_count": combat.get_active_enemy_count(),
				"source": "gm_panel",
			}
		else:
			spawn = combat.spawn_wave(wave, true, "t0396_main_benchmark")
		if not bool(spawn.get("ok", false)):
			push_error("T0396 spawn failed: %s" % spawn)
			quit(1)
			return
	var spawn_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
	if str(_options.stage) == "gate" and wave > 0:
		_place_formation_near_gate(combat)
	if str(_options.camera) == "gate":
		var target: Dictionary = combat._make_building_target("front_gate")
		main.get_node("CameraRig").global_position = target.position + Vector3(0, 0, 5)
	var experiments := str(_options.get("experiment", "")).split(",", false)
	if experiments.has("hide_world"):
		# Diagnostic only, NEVER an accepted visual/performance result or a fix.
		main.get_node("CameraRig/Camera3D").cull_mask = 0
	if experiments.has("hide_environment"):
		# Diagnostic only: visibility does not disable the branch's gameplay nodes.
		main.get_node("WorldRoot/FormalStationLayout/FormalEnvironmentArtView").visible = false
	var environment_root := main.get_node("WorldRoot/FormalStationLayout/FormalEnvironmentArtView") as Node3D
	var environment_visibility_experiments := {
		"hide_terrain_topology": "FullMapTerrainTopology",
		"hide_dense_forest": "FullMapDenseForest",
		"hide_natural_scatter": "FullMapNaturalScatter",
		"hide_ground_surface": "GroundSurface",
		"hide_stylized_ground": "ApprovedStylizedGround",
		"hide_stylized_mountain": "ApprovedStylizedMountain",
		"hide_stylized_river": "ApprovedStylizedRiver",
		"hide_station_details": "StationLifeDetails",
		"hide_ground_contact": "BuildingGroundContact",
		"hide_station_ground_decor": "StationGroundDecor",
	}
	for experiment_name in environment_visibility_experiments:
		if experiments.has(experiment_name):
			# Diagnostic only: isolate render branches without changing production data.
			var branch := environment_root.get_node_or_null(environment_visibility_experiments[experiment_name]) as Node3D
			if branch != null:
				branch.visible = false
	if experiments.has("hide_buildings"):
		main.get_node("WorldRoot/FormalStationLayout/BuildingRoots").visible = false
	if experiments.has("hide_enemies"):
		main.get_node("WorldRoot/FormalStationLayout/FormalEnemies").visible = false
	if experiments.has("hide_friendlies"):
		main.get_node("WorldRoot/Station/NPCs").visible = false
	gm_panel._panel.visible = str(_options.get("gm", "closed")) == "open"
	await create_timer(clampf(float(_options.warmup), 0.2, 30.0)).timeout
	# Main's presentation setup may rebuild these generated child branches during
	# warmup. Reapply the diagnostic visibility cut to the final live nodes so an
	# early throwaway generation cannot make an A/B result look like a no-op.
	environment_root = main.get_node("WorldRoot/FormalStationLayout/FormalEnvironmentArtView") as Node3D
	var reapplied_environment_visibility := false
	for experiment_name in environment_visibility_experiments:
		if experiments.has(experiment_name):
			var branch := environment_root.get_node_or_null(environment_visibility_experiments[experiment_name]) as Node3D
			if branch != null:
				branch.visible = false
				reapplied_environment_visibility = true
	if reapplied_environment_visibility:
		await process_frame
		await process_frame
	if experiments.has("lock_camera"):
		# Diagnostic only: keep open/closed GM UI A/B on the same submitted world
		# view. The standalone benchmark window can otherwise inherit live camera
		# input and invalidate a UI-cost comparison with a different culling view.
		var camera_rig := main.get_node("CameraRig") as Node3D
		camera_rig.set_process(false)
		camera_rig.set_process_input(false)
		camera_rig.set_process_unhandled_input(false)
		camera_rig.global_position = Vector3(-2.0, 0.0, 18.0)
		await process_frame
	if experiments.has("directional_shadows_2_splits"):
		# Diagnostic A/B: shadows remain enabled with the same range and casters;
		# only the directional cascade count changes from four to two.
		for raw_light in environment_root.find_children("*", "DirectionalLight3D", true, false):
			var directional_light := raw_light as DirectionalLight3D
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if experiments.has("directional_shadows_1_split"):
		# Diagnostic only: quality floor, never accept without visual review.
		for raw_light in environment_root.find_children("*", "DirectionalLight3D", true, false):
			var directional_light := raw_light as DirectionalLight3D
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	if experiments.has("disable_actor_motion_physics"):
		# Diagnostic only: isolate CharacterBody/navigation physics after the fixture
		# has reached contact. This deliberately freezes actors and cannot be shipped.
		for node in main.find_children("*", "CharacterBody3D", true, false):
			if node is ActorMotionBody:
				node.set_physics_process(false)
	if experiments.has("disable_actor_collisions"):
		# Diagnostic only: preserve motion callbacks while removing body collision
		# queries. This changes crowd mechanics and can never be an accepted fix.
		for node in main.find_children("*", "CharacterBody3D", true, false):
			if node is ActorMotionBody:
				node.collision_layer = 0
				node.collision_mask = 0
	if experiments.has("disable_actor_pair_collisions"):
		# Diagnostic only: retain static-world collision and remove actor/actor
		# contacts to distinguish crowd broadphase cost from authored walls.
		for node in main.find_children("*", "CharacterBody3D", true, false):
			if node is ActorMotionBody:
				node.set_runtime_actor_collision_enabled(false, "t0396_diagnostic")
	if experiments.has("disable_world_collisions"):
		# Diagnostic only: retain actor/actor contacts while removing static-world
		# contacts. Collision-layer bit 2 is the configured actor body layer.
		for node in main.find_children("*", "CharacterBody3D", true, false):
			if node is ActorMotionBody:
				node.collision_mask = 2
	if experiments.has("disable_actor_avoidance"):
		# Diagnostic only: isolate NavigationServer RVO cost while retaining the
		# normal movement callback and physical collision path.
		for node in main.find_children("*", "CharacterBody3D", true, false):
			if node is ActorMotionBody:
				node.set_runtime_avoidance_enabled(false, "t0396_diagnostic")
	if experiments.has("disable_chibi_process"):
		# Diagnostic only: freeze character presentation pilots after contact while
		# leaving combat, navigation and physics authority running.
		for node in main.find_children("*", "Node3D", true, false):
			if node is ChibiCharacterPilot:
				node.set_process(false)
	var initial_ids: Array = combat.get_active_enemy_ids()
	var initial_position := Vector3.ZERO
	if not initial_ids.is_empty():
		initial_position = combat.get_enemy_world_position(str(initial_ids[0]))
	var simulation_start: float = clock_system.get("_seconds_into_day")
	var initial_combat := _combat_facts(combat, main.get_node("Systems/BuildingSystem"))
	root.get_node("EventBus").combat_audio_event.connect(_count_combat_event)
	var duration := clampf(float(_options.seconds), 1.0, 60.0)
	combat.debug_start_performance_capture(duration)
	await create_timer(duration + 0.1).timeout
	var report: Dictionary = combat.debug_get_performance_capture(true, true)
	report["fixture"] = _options.duplicate()
	report["engine_arguments"] = Array(OS.get_cmdline_args())
	report["combat_at_start"] = initial_combat
	report["combat_at_end"] = _combat_facts(combat, main.get_node("Systems/BuildingSystem"))
	report["combat_events_during_sample"] = _combat_events.duplicate()
	report["spawn_ms"] = spawn_ms
	report["simulation_advanced_seconds"] = float(clock_system.get("_seconds_into_day")) - simulation_start
	report["combat_frame_rate"] = clock_system.get_combat_frame_rate()
	report["enemy_displacement"] = initial_position.distance_to(combat.get_enemy_world_position(str(initial_ids[0]))) if not initial_ids.is_empty() and combat.get_active_enemy_ids().has(initial_ids[0]) else -1.0
	report["request_count"] = main.get_node("Systems/LLMBridge").get("_request_counter")
	var npc_system := main.get_node("Systems/NPCSystem")
	var recruited_count := 0
	var equipped_count := 0
	var behavior_modes: Dictionary = {}
	for npc_id in npc_system.get_npc_ids():
		var profile: Dictionary = npc_system.get_npc(npc_id)
		if bool(profile.get("recruited", false)):
			recruited_count += 1
		var equipment: Dictionary = profile.get("equipment", {}) if profile.get("equipment", {}) is Dictionary else {}
		var main_weapon: Dictionary = equipment.get("main_weapon", {}) if equipment.get("main_weapon", {}) is Dictionary else {}
		if not main_weapon.is_empty():
			equipped_count += 1
		behavior_modes[str(npc_id)] = npc_system.get_npc_behavior_mode(str(npc_id))
	report["recruited_count"] = recruited_count
	report["equipped_count"] = equipped_count
	report["friendly_behavior_modes"] = behavior_modes
	report["gm_panel_open_during_sample"] = gm_panel._panel.visible
	var directory := "res://artifacts/performance/t0396"
	DirAccess.make_dir_recursive_absolute(directory)
	var label := str(_options.label).validate_filename()
	var mode := "headless" if DisplayServer.get_name() == "headless" else "window"
	var path := "%s/%s_wave%d_%s.json" % [directory, label, wave, mode]
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("T0396 cannot write benchmark report")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	report.erase("raw_samples")
	print("T0396_MAIN_BENCHMARK %s" % JSON.stringify(report))
	var expected_count: int = [0, 8, 16, 24, 36, 48][wave]
	var valid: bool = float(report.simulation_advanced_seconds) > 0.0 and float(report.metrics.get("paused", {}).get("max", 1.0)) == 0.0 and int(report.request_count) == 0 and int(spawn.get("spawned_count", 0)) == expected_count
	if str(_options.get("recruit", "none")) == "all":
		valid = valid and recruited_count == 8 and equipped_count == 8
	if str(_options.stage) == "gate":
		valid = valid and int(_combat_events.get("attack_swing", 0)) + int(_combat_events.get("projectile_fired", 0)) + int(_combat_events.get("structure_damaged", 0)) + int(_combat_events.get("actor_damaged", 0)) > 0
	print("T0396_SAMPLE_VALID=%s report=%s" % [valid, path])
	combat.clear_spawned_enemies()
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if valid else 1)


func _count_combat_event(event: Dictionary) -> void:
	var kind := str(event.get("event_type", ""))
	_combat_events[kind] = int(_combat_events.get(kind, 0)) + 1


func _combat_facts(combat: Node, buildings: Node) -> Dictionary:
	var phases: Dictionary = {}
	var targets: Dictionary = {}
	var sequences := 0
	for enemy_id: String in combat.get_active_enemy_ids():
		var enemy: Dictionary = combat.get_enemy(enemy_id)
		var phase := str(enemy.get("attack_cycle_phase", ""))
		phases[phase] = int(phases.get(phase, 0)) + 1
		var target_id := str((enemy.get("target", {}) as Dictionary).get("id", ""))
		targets[target_id] = int(targets.get(target_id, 0)) + 1
		sequences += int(enemy.get("attack_sequence", 0))
	return {"attack_phases": phases, "targets": targets, "attack_sequence_sum": sequences,
		"front_gate_hp": int(buildings.get_building("front_gate").get("hp", 0))}


func _place_formation_near_gate(combat: Node) -> void:
	# Fixture setup only: translate the entire formal formation without changing
	# spacing, bodies, stats, targeting, or attack rules. Natural spawn is default.
	var ids: Array = combat.get_active_enemy_ids()
	var front_z := INF
	var min_x := INF
	var max_x := -INF
	for enemy_id: String in ids:
		var position: Vector3 = combat.get_enemy_world_position(enemy_id)
		front_z = minf(front_z, position.z)
		min_x = minf(min_x, position.x)
		max_x = maxf(max_x, position.x)
	var target: Dictionary = combat._make_building_target("front_gate")
	var translation := Vector3(target.position.x - (min_x + max_x) * 0.5, 0, target.position.z + 12.0 - front_z)
	for enemy_id: String in ids:
		var actor := combat.get_node(combat._formal_first_wave_node_paths[enemy_id]) as ActorMotionBody
		actor.cancel_motion("superseded")
		actor.global_position += translation
		actor.velocity = Vector3.ZERO
		combat._active_enemies[enemy_id]["position"] = actor.global_position
