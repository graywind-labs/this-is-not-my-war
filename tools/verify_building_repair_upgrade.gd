extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn")
	if main_scene == null:
		push_error("Main scene failed to load.")
		quit(1)
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if building_system == null or resource_system == null or panel == null:
		push_error("Required systems or building panel are missing.")
		quit(1)
		return

	var building_id := "wall"
	var original: Dictionary = building_system.get_building(building_id)
	var original_stone: int = resource_system.get_resource("stone")
	if original.is_empty() or original_stone < 8:
		push_error("Verify precondition failed.")
		quit(1)
		return
	for raw_building_id in building_system.get_building_ids():
		var current_id := str(raw_building_id)
		var current_building: Dictionary = building_system.get_building(current_id)
		if current_building.get("repair", {}).is_empty():
			push_error("Every building should be repairable, missing: %s" % current_id)
			quit(1)
			return
		if current_building.get("upgrade", {}).is_empty():
			push_error("Every building should have upgrade potential, missing: %s" % current_id)
			quit(1)
			return

	if not building_system.debug_damage_building(building_id, 40):
		push_error("Failed to damage building.")
		quit(1)
		return

	panel.show_building(building_id)
	var location_label := root.get_node_or_null("Main/UI/BuildingPanel/PanelContainer/MarginContainer/Content/BuildingLocationLabel") as Label
	if location_label == null:
		push_error("Building location label is missing.")
		quit(1)
		return
	if location_label.text.contains("消耗"):
		push_error("Building panel should not show repair or upgrade costs inline.")
		quit(1)
		return
	var repair_hint := str(panel._format_repair_hint())
	if not repair_hint.contains("消耗："):
		push_error("Repair cost hint should be available from the repair button hover content.")
		quit(1)
		return
	var edge_anchor := Button.new()
	edge_anchor.text = "边缘按钮"
	edge_anchor.custom_minimum_size = Vector2(80, 30)
	panel.add_child(edge_anchor)
	await process_frame
	var viewport_size := root.get_viewport().get_visible_rect().size
	edge_anchor.global_position = Vector2(viewport_size.x - edge_anchor.size.x - 2.0, 48.0)
	panel._show_action_hint(edge_anchor, "升级\n消耗：石料 x3\n条件：可执行")
	await process_frame
	var hint_panel: Control = panel._action_hint_panel
	if hint_panel.global_position.x + hint_panel.size.x > viewport_size.x:
		push_error("Building action hint should stay inside the viewport near screen edges.")
		quit(1)
		return
	panel._hide_action_hint()
	edge_anchor.queue_free()
	if not building_system.can_repair_building(building_id):
		push_error("Damaged building should be repairable.")
		quit(1)
		return
	if building_system.can_upgrade_building(building_id):
		push_error("Damaged building should not be upgradeable.")
		quit(1)
		return

	if not building_system.repair_building(building_id):
		push_error("Repair did not start.")
		quit(1)
		return
	if building_system.can_upgrade_building(building_id):
		push_error("Building under repair should not be upgradeable.")
		quit(1)
		return

	var started: Dictionary = building_system.get_building(building_id)
	if int(started.get("hp", 0)) != int(original.get("hp", 0)) - 40:
		push_error("Repair should not restore HP immediately.")
		quit(1)
		return
	if not building_system.is_repair_in_progress(building_id):
		push_error("Repair status was not created.")
		quit(1)
		return
	if resource_system.get_resource("stone") != original_stone - 1:
		push_error("Repair did not spend stone up front.")
		quit(1)
		return

	building_system._on_logical_time_tick(600.0, 1.0)
	var halfway: Dictionary = building_system.get_building(building_id)
	if int(halfway.get("hp", 0)) <= int(started.get("hp", 0)):
		push_error("Repair progress did not restore HP over time.")
		quit(1)
		return
	if not building_system.is_repair_in_progress(building_id):
		push_error("Repair finished too early.")
		quit(1)
		return

	building_system._on_logical_time_tick(600.0, 1.0)
	var repaired: Dictionary = building_system.get_building(building_id)
	if int(repaired.get("hp", 0)) != int(repaired.get("max_hp", 0)):
		push_error("Repair did not finish at max HP.")
		quit(1)
		return
	if building_system.is_repair_in_progress(building_id):
		push_error("Repair status did not clear after completion.")
		quit(1)
		return

	var before_upgrade_stone: int = resource_system.get_resource("stone")
	var before_upgrade_workstations: Array = repaired.get("workstations", [])
	if not before_upgrade_workstations.is_empty():
		push_error("Non-enterable wall should not expose internal workstations.")
		quit(1)
		return
	if not building_system.upgrade_building(building_id):
		push_error("Upgrade did not start.")
		quit(1)
		return

	var upgrade_started: Dictionary = building_system.get_building(building_id)
	if int(upgrade_started.get("level", 0)) != int(repaired.get("level", 0)):
		push_error("Upgrade should not increase level immediately.")
		quit(1)
		return
	if not building_system.is_upgrade_in_progress(building_id):
		push_error("Upgrade status was not created.")
		quit(1)
		return
	if str(upgrade_started.get("condition", "")) != "upgrading":
		push_error("Building condition should be upgrading during upgrade countdown.")
		quit(1)
		return
	if resource_system.get_resource("stone") != before_upgrade_stone - 3:
		push_error("Upgrade did not spend stone up front.")
		quit(1)
		return
	if building_system.can_repair_building(building_id):
		push_error("Building under upgrade should not be repairable.")
		quit(1)
		return

	building_system._on_logical_time_tick(1800.0, 1.0)
	var upgrade_halfway: Dictionary = building_system.get_building(building_id)
	if int(upgrade_halfway.get("level", 0)) != int(repaired.get("level", 0)) or not building_system.is_upgrade_in_progress(building_id):
		push_error("Upgrade should still be in progress halfway.")
		quit(1)
		return

	building_system._on_logical_time_tick(1800.0, 1.0)
	var upgraded: Dictionary = building_system.get_building(building_id)
	var upgraded_workstations: Array = upgraded.get("workstations", [])
	if int(upgraded.get("level", 0)) != int(repaired.get("level", 0)) + 1:
		push_error("Upgrade completion did not increase level.")
		quit(1)
		return
	if int(upgraded.get("max_hp", 0)) <= int(repaired.get("max_hp", 0)):
		push_error("Upgrade did not increase max HP.")
		quit(1)
		return
	if upgraded_workstations.size() != before_upgrade_workstations.size():
		push_error("Non-enterable wall upgrade should not add internal workstations.")
		quit(1)
		return
	if building_system.is_upgrade_in_progress(building_id):
		push_error("Upgrade status did not clear after completion.")
		quit(1)
		return

	var stone_before_failed_upgrade: int = resource_system.get_resource("stone")
	if building_system.upgrade_building(building_id):
		push_error("Upgrade should fail when stone is insufficient.")
		quit(1)
		return
	if resource_system.get_resource("stone") != stone_before_failed_upgrade:
		push_error("Failed upgrade changed stone.")
		quit(1)
		return

	print("T0205 repair and upgrade verification passed.")
	quit(0)
