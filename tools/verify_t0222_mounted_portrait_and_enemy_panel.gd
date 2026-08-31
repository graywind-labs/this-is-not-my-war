extends SceneTree


var _failures: Array[String] = []


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	_check(packed != null, "Main.tscn could not be loaded")
	if packed == null:
		_finish()
		return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var main := packed.instantiate()
	root.add_child(main)
	for _frame in 8:
		await physics_frame
		await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var enemy_panel := root.get_node_or_null("Main/UI/EnemyPanel") as Control
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel") as Control
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var formal_enemies := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnemies") as Node3D
	_check(npc_system != null and combat_system != null and npc_panel != null and enemy_panel != null, "T0222 runtime dependencies are missing")
	if npc_system == null or combat_system == null or npc_panel == null or enemy_panel == null or formal_enemies == null:
		_finish()
		return

	npc_panel.debug_set_layout_viewport_override(Vector2(1280, 720))
	enemy_panel.debug_set_layout_viewport_override(Vector2(1280, 720))
	var npc_id := "veteran_deputy_01"
	var state_before: Dictionary = npc_system.get_npc_state(npc_id)
	_check(npc_system.debug_select_npc(npc_id), "Could not select the friendly portrait target")
	for _frame in 3:
		await process_frame
	var standing: Dictionary = npc_panel.debug_get_portrait_snapshot()
	var standing_target: Dictionary = standing.get("target_snapshot", {})
	_check(not bool(standing_target.get("mounted", true)), "Standing NPC portrait incorrectly reports mounted")
	var standing_focus := float(standing_target.get("focus_height", 0.0))
	var standing_camera := float(standing_target.get("camera_height", 0.0))

	_check(npc_system.update_npc_state(npc_id, {"combat_mounted": true, "combat_mount_phase": "mounted"}), "Could not enter mounted portrait state")
	for _frame in 3:
		await process_frame
	var mounted: Dictionary = npc_panel.debug_get_portrait_snapshot()
	var mounted_target: Dictionary = mounted.get("target_snapshot", {})
	_check(bool(mounted_target.get("mounted", false)), "Mounted NPC portrait did not read the live mounted state")
	_check(float(mounted_target.get("focus_height", 0.0)) > standing_focus + 0.5, "Mounted NPC portrait focus did not move up to the rider")
	_check(float(mounted_target.get("camera_height", 0.0)) > standing_camera + 0.5, "Mounted NPC portrait camera did not move up")

	_check(npc_system.update_npc_state(npc_id, {"combat_mounted": false, "combat_mount_phase": "unmounted"}), "Could not leave mounted portrait state")
	for _frame in 3:
		await process_frame
	var unmounted: Dictionary = npc_panel.debug_get_portrait_snapshot()
	var unmounted_target: Dictionary = unmounted.get("target_snapshot", {})
	_check(not bool(unmounted_target.get("mounted", true)), "NPC portrait remained mounted after dismount")
	_check(is_equal_approx(float(unmounted_target.get("focus_height", 0.0)), standing_focus), "NPC portrait did not restore standing focus height")
	_check(is_equal_approx(float(unmounted_target.get("camera_height", 0.0)), standing_camera), "NPC portrait did not restore standing camera height")

	var enemy_id := "t0222_mounted_enemy"
	var enemy := {
		"id": enemy_id,
		"enemy_id": enemy_id,
		"name": "检视骑兵",
		"hp": 42,
		"max_hp": 42,
		"alive": true,
		"unit_type": "cavalry",
		"weapon_type": "sword_shield",
		"attack_power": 7,
		"defense": 1,
		"penetration": 1.0,
		"attack_speed": 0.46,
		"attack_interval": 1.0 / 0.46,
		"attack_range": 1.8,
		"move_speed": 4.0,
		"current_action": "idle_no_target",
		"attack_sequence": 0,
		"attack_cycle_phase": "idle",
		"wave_number": 4,
	}
	var actor = combat_system._create_formal_enemy_actor(enemy, "T0222MountedEnemy", false)
	formal_enemies.add_child(actor)
	actor.global_position = Vector3(0.0, 0.0, 0.0)
	combat_system._active_enemies[enemy_id] = enemy.duplicate(true)
	combat_system._enemy_nodes[enemy_id] = actor.get_path()
	var interaction_area := actor.get_node_or_null("InteractionArea") as Area3D
	_check(interaction_area != null and interaction_area.input_event.get_connections().size() > 0, "Enemy InteractionArea is not wired for selection")
	if interaction_area != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		interaction_area.input_event.emit(null, click, actor.global_position, Vector3.UP, 0)
	for _frame in 4:
		await process_frame

	var panel_snapshot: Dictionary = enemy_panel.debug_get_snapshot()
	var portrait: Dictionary = panel_snapshot.get("portrait", {})
	var portrait_target: Dictionary = portrait.get("target_snapshot", {})
	var values: Dictionary = panel_snapshot.get("values", {})
	_check(bool(panel_snapshot.get("visible", false)) and str(panel_snapshot.get("enemy_id", "")) == enemy_id, "Clicking the enemy did not open its own panel")
	_check(not npc_panel.visible and (horse_panel == null or not horse_panel.visible) and (building_panel == null or not building_panel.visible), "Enemy selection did not replace other object panels")
	_check(str(panel_snapshot.get("name", "")) == "检视骑兵", "Enemy name is not sourced from CombatSystem")
	_check(str(values.get("hp", "")) == "HP：42 / 42", "Enemy HP text mismatch")
	_check(str(values.get("unit_type", "")) == "兵种：近战骑兵", "Enemy unit type text mismatch")
	_check(str(values.get("weapon", "")) == "武器：剑盾", "Enemy weapon text mismatch")
	_check(str(values.get("attack", "")) == "攻击：7" and str(values.get("defense", "")) == "防御：1", "Enemy combat attributes mismatch")
	_check(not bool(panel_snapshot.get("has_authority_note", true)), "Enemy panel contains redundant explanatory text")
	_check(bool(portrait.get("rendering_enabled", false)) and bool(portrait.get("shares_main_world", false)), "Enemy portrait is not using the live shared world")
	_check(str(portrait.get("target_kind", "")) == "enemy" and str(portrait.get("target_enemy_id", "")) == enemy_id, "Enemy portrait target mismatch")
	_check(bool(portrait_target.get("mounted", false)) and float(portrait_target.get("focus_height", 0.0)) > standing_focus + 0.5, "Mounted enemy portrait is not framed on the rider")
	var portrait_rect: Rect2 = portrait.get("frame_global_rect", Rect2())
	_check(portrait_rect.size.x >= 190.0 and portrait_rect.size.x <= 210.0, "Enemy portrait width does not match the NPC portrait contract")
	_check(portrait_rect.size.y >= 300.0 and portrait_rect.size.y <= 420.0, "Enemy portrait height does not match the NPC portrait contract")
	_check(combat_system.get_enemy(enemy_id).get("hp", 0) == 42, "Opening the enemy panel mutated combat authority")

	_check(npc_system.debug_select_npc(npc_id), "Could not switch back to NPC selection")
	await process_frame
	_check(npc_panel.visible and not enemy_panel.visible, "NPC selection did not replace EnemyPanel")
	var closed: Dictionary = enemy_panel.debug_get_snapshot()
	var closed_portrait: Dictionary = closed.get("portrait", {})
	_check(not bool(closed_portrait.get("rendering_enabled", true)), "Enemy portrait kept rendering after panel replacement")

	npc_system.update_npc_state(npc_id, state_before)
	combat_system._active_enemies.erase(enemy_id)
	combat_system._enemy_nodes.erase(enemy_id)
	actor.queue_free()
	main.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0222_MOUNTED_PORTRAIT_AND_ENEMY_PANEL PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0222_MOUNTED_PORTRAIT_AND_ENEMY_PANEL FAIL count=%d" % _failures.size())
	quit(1)
