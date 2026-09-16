extends SceneTree

const ADA_NPC_ID := "veteran_deputy_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	var game_state := root.get_node_or_null("GameState")
	var tutorial := main.get_node_or_null("Systems/TutorialDirector")
	var npc_system := main.get_node_or_null("Systems/NPCSystem")
	var combat_system := main.get_node_or_null("Systems/CombatSystem")
	var time_system := main.get_node_or_null("Systems/TimeSystem")
	var panel := main.get_node_or_null("UI/NPCPanel")
	var hud := main.get_node_or_null("UI/HUD")
	var layout_controller := main.get_node_or_null("Presentation/StationLayoutController")
	var camera_rig := main.get_node_or_null("CameraRig")
	if startup == null or game_state == null or tutorial == null or npc_system == null or combat_system == null or time_system == null or panel == null or hud == null or layout_controller == null or camera_rig == null:
		_fail("tutorial regression dependencies missing")
		return
	var startup_result: Dictionary = startup.debug_apply_startup_mode(2, true, false)
	await process_frame
	if not bool(startup_result.get("tutorial_requested", false)):
		_fail("tutorial startup was not requested")
		return
	var preparation: Dictionary = tutorial.get_tutorial_snapshot().get("preparation", {})
	var ada_portrait: Dictionary = npc_system.get_npc_portrait_snapshot(ADA_NPC_ID)
	var ada_forward: Vector3 = ada_portrait.get("visual_forward", Vector3.ZERO)
	if not bool(preparation.get("ada_facing_applied", false)) or ada_forward.dot(Vector3(0.0, 0.0, 1.0)) < 0.98:
		_fail("Ada does not face the front gate during tutorial staging: %s / %s" % [str(preparation), str(ada_portrait)])
		return

	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.size() != 5:
		_fail("tutorial did not spawn five gate-pressure enemies")
		return
	var front_gate_position := Vector3(5.0, 0.0, 54.0)
	var enemy_positions_before: Dictionary = {}
	for raw_enemy_id in enemy_ids:
		var enemy_id := str(raw_enemy_id)
		var enemy_position: Vector3 = combat_system.get_enemy_world_position(enemy_id)
		enemy_positions_before[enemy_id] = enemy_position
		var gate_distance := Vector2(enemy_position.x, enemy_position.z).distance_to(Vector2(front_gate_position.x, front_gate_position.z))
		if gate_distance < 14.0 or gate_distance > 22.0:
			_fail("tutorial enemy did not start in the near-gate pressure zone: %s distance=%s" % [enemy_id, str(gate_distance)])
			return

	tutorial.call("_enter_step", "battlefield_explain")
	await process_frame
	await process_frame
	await process_frame
	var gate_focus_world := Vector3(1.5, 0.0, 54.0)
	var gate_focus_screen := (camera_rig.get_node("Camera3D") as Camera3D).unproject_position(gate_focus_world)
	var gate_viewport_center := get_root().get_visible_rect().size * 0.5
	if absf(float(camera_rig.get_zoom_distance()) - 20.0) > 0.01 or gate_focus_screen.distance_to(gate_viewport_center) > 1.0:
		_fail("battlefield gate camera did not use the configured nearest framing: projected=%s center=%s zoom=%s rig=%s camera=%s" % [str(gate_focus_screen), str(gate_viewport_center), str(camera_rig.get_zoom_distance()), str(camera_rig.global_position), str((camera_rig.get_node("Camera3D") as Camera3D).global_position)])
		return
	var gate_camera := camera_rig.get_node("Camera3D") as Camera3D
	var gate_ground_screen := gate_camera.unproject_position(Vector3(5.0, 0.0, 54.0))
	var gate_top_screen := gate_camera.unproject_position(Vector3(5.0, 4.5, 54.0))
	var tower_slot_screen := gate_camera.unproject_position(Vector3(-2.785, 3.55, 53.63))
	var front_space_screen := gate_camera.unproject_position(Vector3(5.0, 0.0, 60.0))
	var viewport_size := get_root().get_visible_rect().size
	if (
		gate_top_screen.y < 0.0
		or gate_ground_screen.y > viewport_size.y * 0.62
		or tower_slot_screen.x < 0.0
		or tower_slot_screen.x > viewport_size.x
		or tower_slot_screen.y < 0.0
		or tower_slot_screen.y > viewport_size.y
		or front_space_screen.y <= gate_ground_screen.y
		or front_space_screen.y > viewport_size.y
	):
		_fail("gate framing does not contain the gate, tower slot, and exterior foreground: gate_top=%s gate_ground=%s slot=%s foreground=%s viewport=%s" % [str(gate_top_screen), str(gate_ground_screen), str(tower_slot_screen), str(front_space_screen), str(viewport_size)])
		return
	if not bool(tutorial.get_tutorial_snapshot().get("detached_simulation_running", false)):
		_fail("tutorial battle presentation did not start on battlefield entry")
		return
	if bool(time_system.is_gameplay_paused()) or str(time_system.get_pause_label()) != "暂停":
		_fail("tutorial battle presentation is not exposed as running")
		return
	var pause_button := hud.get_node_or_null("PauseButton") as Button
	if pause_button == null or not pause_button.disabled or pause_button.text != "暂停":
		_fail("tutorial pause control is not visibly locked")
		return
	var clock_before := [game_state.current_day, game_state.current_hour, game_state.current_minute, game_state.current_second]
	hud.call("_toggle_pause")
	if not bool(time_system.is_paused):
		_fail("tutorial pause lock changed the isolated calendar state")
		return
	for _frame in range(18):
		await physics_frame
	var moved_enemy_count := 0
	for raw_enemy_id in enemy_ids:
		var enemy_id := str(raw_enemy_id)
		var current_position: Vector3 = combat_system.get_enemy_world_position(enemy_id)
		if current_position.distance_to(enemy_positions_before.get(enemy_id, current_position)) > 0.2:
			moved_enemy_count += 1
	if moved_enemy_count <= 0:
		_fail("near-gate enemies stayed frozen during the first battlefield page")
		return
	var clock_after := [game_state.current_day, game_state.current_hour, game_state.current_minute, game_state.current_second]
	if clock_after != clock_before:
		_fail("detached tutorial battle advanced the formal calendar")
		return
	await process_frame
	var building_bars: Dictionary = layout_controller.debug_get_strategic_building_health_bar_snapshot()
	if bool((building_bars.get("front_gate", {}) as Dictionary).get("local_visible", true)):
		_fail("front-gate health bar remained visible during tutorial raid")
		return
	var overlay_text := str(tutorial.get_tutorial_snapshot().get("overlay", {}).get("dialogue_text", ""))
	if overlay_text.find("敌人正在来袭") < 0:
		_fail("battlefield explanation text was not preserved")
		return

	tutorial.call("_enter_step", "select_slot")
	await process_frame
	var slot_focus_screen := (camera_rig.get_node("Camera3D") as Camera3D).unproject_position(gate_focus_world)
	if absf(float(camera_rig.get_zoom_distance()) - 20.0) > 0.01 or slot_focus_screen.distance_to(gate_viewport_center) > 1.0:
		_fail("slot selection did not preserve the gate framing")
		return
	var slot_text := str(tutorial.get_tutorial_snapshot().get("overlay", {}).get("dialogue_text", ""))
	if slot_text.find("部署箭塔") < 0 or slot_text.find("部署军械") >= 0:
		_fail("slot instruction did not use arrow-tower wording")
		return
	tutorial.call("_enter_step", "select_device")
	var device_text := str(tutorial.get_tutorial_snapshot().get("overlay", {}).get("dialogue_text", ""))
	if device_text.find("有一座箭塔") < 0 or device_text.find("只有") >= 0:
		_fail("arrow-tower inventory instruction retained exclusive wording")
		return
	tutorial.call("_enter_step", "sword_shield")
	var sword_text := str(tutorial.get_tutorial_snapshot().get("overlay", {}).get("dialogue_text", ""))
	if sword_text.find("有一套剑盾") < 0 or sword_text.find("唯一") >= 0:
		_fail("sword-shield instruction retained exclusive wording")
		return

	var zoom_before_ada_focus := float(camera_rig.get_zoom_distance())
	tutorial.call("_enter_step", "select_ada")
	await process_frame
	var ada_position: Vector3 = npc_system.get_npc_world_position(ADA_NPC_ID)
	var camera := camera_rig.get_node("Camera3D") as Camera3D
	var projected_ada_center := camera.unproject_position(ada_position + Vector3.UP * 0.85)
	var viewport_center := camera.get_viewport().get_visible_rect().size * 0.5
	if (
		absf(float(camera_rig.get_zoom_distance()) - 20.0) > 0.01
		or projected_ada_center.distance_to(viewport_center) > 1.0
	):
		_fail("Ada selection camera did not center and zoom: projected=%s viewport_center=%s zoom=%s" % [str(projected_ada_center), str(viewport_center), str(camera_rig.get_zoom_distance())])
		return
	var gesture_snapshot: Dictionary = tutorial.get_tutorial_snapshot().get("ada_equipment_gesture", {})
	if not bool(gesture_snapshot.get("active", false)) or int(gesture_snapshot.get("play_count", 0)) < 1:
		_fail("Ada equipment demonstration gesture did not start with the selection focus: %s" % str(gesture_snapshot))
		return
	var first_gesture_count := int(gesture_snapshot.get("play_count", 0))
	tutorial.call("_process", float(gesture_snapshot.get("remaining_seconds", 0.0)) + 0.1)
	gesture_snapshot = tutorial.get_tutorial_snapshot().get("ada_equipment_gesture", {})
	if int(gesture_snapshot.get("play_count", 0)) <= first_gesture_count:
		_fail("Ada equipment demonstration gesture did not loop: %s" % str(gesture_snapshot))
		return

	var occupied_beds: Array[String] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if npc_id == ADA_NPC_ID:
			if str(state.get("current_location", "")) != "plaza" or npc_system.is_npc_sleeping(npc_id):
				_fail("Ada was not staged awake in the plaza")
				return
			continue
		var workstation_id := str(state.get("current_workstation_id", ""))
		if (
			str(state.get("current_location", "")) != "dormitory"
			or str(state.get("current_action", "")) != "sleep_in_dormitory"
			or str(state.get("physical_location_phase", "")) != "occupant_anchor"
			or workstation_id.is_empty()
			or not npc_system.is_npc_sleeping(npc_id)
			or npc_system.is_npc_in_formal_combat_world(npc_id)
		):
			_fail("non-Ada NPC was not sleeping in a dormitory bed: %s / %s" % [npc_id, str(state)])
			return
		if occupied_beds.has(workstation_id):
			_fail("tutorial sleepers share a bed: %s" % workstation_id)
			return
		occupied_beds.append(workstation_id)
	if occupied_beds.size() != 7:
		_fail("expected seven occupied tutorial beds, got %d" % occupied_beds.size())
		return
	var formal_result: Dictionary = combat_system.get_tutorial_raid_snapshot().get("spawn_result", {}).get("formal_combat_world_result", {})
	if formal_result.get("requested_npc_ids", []) != [ADA_NPC_ID]:
		_fail("tutorial combat world did not scope migration to Ada: %s" % str(formal_result))
		return

	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		_fail("EventBus autoload missing")
		return
	event_bus.npc_clicked.emit(ADA_NPC_ID)
	tutorial.call("_enter_step", "equipment_button")
	var equipment_button := panel.get_tutorial_target_control("equipment_button") as Button
	if equipment_button == null:
		_fail("equipment button target missing")
		return
	equipment_button.pressed.emit()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "main_weapon":
		_fail("real equipment button did not advance tutorial")
		return
	var weapon_slot_button := panel.get_tutorial_target_control("main_weapon_slot") as Button
	if weapon_slot_button == null:
		_fail("main weapon slot target missing")
		return
	weapon_slot_button.pressed.emit()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "sword_shield":
		_fail("real main weapon slot did not advance tutorial")
		return
	var sword_button := panel.get_tutorial_target_control("sword_shield_item") as Button
	if sword_button == null:
		_fail("sword-shield item target missing")
		return
	sword_button.pressed.emit()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "equip_showcase":
		_fail("real sword-shield selection did not advance tutorial")
		return
	var completed_gesture_count := int(tutorial.get_tutorial_snapshot().get("ada_equipment_gesture", {}).get("play_count", 0))
	tutorial.call("_process", 2.0)
	if (
		bool(tutorial.get_tutorial_snapshot().get("ada_equipment_gesture", {}).get("active", true))
		or int(tutorial.get_tutorial_snapshot().get("ada_equipment_gesture", {}).get("play_count", 0)) != completed_gesture_count
	):
		_fail("Ada equipment demonstration gesture did not stop after sword-shield equip")
		return
	tutorial.call("_enter_step", "alarm")
	if absf(float(camera_rig.get_zoom_distance()) - zoom_before_ada_focus) > 0.01:
		_fail("Ada selection zoom was not restored before the alarm step")
		return

	# Re-enter the first equipment step with the weapon already equipped. The
	# authority-state reconciliation must recover without another proxy click.
	tutorial.call("_enter_step", "equipment_button")
	tutorial.call("_process", 0.016)
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "equip_showcase":
		_fail("equipped-state reconciliation did not recover the tutorial")
		return

	tutorial.call("_enter_step", "alarm")
	tutorial.call("_on_target_pressed", "alarm")
	var follow_snapshot: Dictionary = tutorial.get_tutorial_snapshot().get("ada_camera_follow", {})
	if (
		str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "battle"
		or not bool(follow_snapshot.get("active", false))
		or not bool(camera_rig.get_camera_control_lock_snapshot().get("locked", false))
	):
		_fail("alarm did not start the locked Ada camera follow: %s / %s" % [str(follow_snapshot), str(camera_rig.get_camera_control_lock_snapshot())])
		return
	var follow_zoom := float(camera_rig.get_zoom_distance())
	var follow_rig_position: Vector3 = camera_rig.global_position
	camera_rig._input(_make_key_event(KEY_S, true))
	camera_rig._process(0.25)
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.pressed = true
	camera_rig._unhandled_input(wheel_event)
	if not camera_rig.global_position.is_equal_approx(follow_rig_position) or not is_equal_approx(float(camera_rig.get_zoom_distance()), follow_zoom):
		_fail("Ada follow did not lock player camera pan and zoom")
		return
	var npc_path: NodePath = npc_system._npc_nodes.get(ADA_NPC_ID, NodePath(""))
	var ada_node := npc_system.get_node_or_null(npc_path) as Node3D
	if ada_node == null:
		_fail("Ada world node missing for follow verification")
		return
	ada_node.global_position += Vector3(1.5, 0.0, 1.5)
	var off_center_before := camera.unproject_position(ada_node.global_position + Vector3.UP * 0.85).distance_to(viewport_center)
	tutorial.call("_process", 0.25)
	var off_center_after := camera.unproject_position(ada_node.global_position + Vector3.UP * 0.85).distance_to(viewport_center)
	if off_center_after >= off_center_before or camera_rig.global_position.is_equal_approx(follow_rig_position):
		_fail("Ada follow camera did not move smoothly toward the displaced actor: before=%s after=%s" % [off_center_before, off_center_after])
		return
	npc_system.update_npc_state(ADA_NPC_ID, {
		"combat_attack_phase": "windup",
		"current_action": "attacking_tutorial_enemy"
	})
	tutorial.call("_process", 0.016)
	follow_snapshot = tutorial.get_tutorial_snapshot().get("ada_camera_follow", {})
	if bool(follow_snapshot.get("active", true)) or str(follow_snapshot.get("release_reason", "")) != "ada_attack_started" or bool(camera_rig.get_camera_control_lock_snapshot().get("locked", true)):
		_fail("Ada follow camera did not unlock at the first attack windup: %s / %s" % [str(follow_snapshot), str(camera_rig.get_camera_control_lock_snapshot())])
		return

	print("T1505 tutorial sleeper and equipment progression regressions passed.")
	quit(0)


func _make_key_event(key: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	return event


func _fail(message: String) -> void:
	push_error("T1505 regression verification failed: %s" % message)
	quit(1)
