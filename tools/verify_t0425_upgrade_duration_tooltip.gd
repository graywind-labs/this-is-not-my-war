extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame

	var buildings := root.get_node_or_null("Main/Systems/BuildingSystem")
	var panel := root.get_node_or_null("Main/UI/BuildingPanel")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	if buildings == null or panel == null or resources == null:
		_fail("Required building upgrade nodes are missing")
		return

	var upgradeable_ids: Array[String] = []
	for raw_building_id in buildings.get_building_ids():
		var building_id := str(raw_building_id)
		var building: Dictionary = buildings.get_building(building_id)
		var upgrade: Dictionary = building.get("upgrade", {})
		if upgrade.is_empty() or int(building.get("level", 1)) >= int(upgrade.get("max_level", 1)):
			continue
		upgradeable_ids.append(building_id)
		var target_level := int(building.get("level", 1)) + 1
		var resolved: Dictionary = buildings.get_upgrade_level_effect(building_id, target_level)
		var configured := float(resolved.get("duration_seconds", 3600.0))
		if not resolved.has("duration_seconds"):
			configured = 3600.0 * (1.0 + float(int(building.get("level", 1)) - 1) * 0.35)
		var actual := float(buildings.get_upgrade_duration_seconds(building_id, target_level))
		if not is_equal_approx(actual, configured + 7200.0):
			_fail("Fixed two-hour surcharge mismatch: %s / %.1f / %.1f" % [building_id, configured, actual])
			return
		panel.show_building(building_id)
		var hint := str(panel.call("_format_upgrade_hint"))
		var expected_duration_text := str(panel.call("_format_game_duration", actual))
		if not hint.contains("工期：%s" % expected_duration_text):
			_fail("Upgrade tooltip does not match authoritative duration: %s / %s" % [building_id, hint])
			return

	if upgradeable_ids.is_empty():
		_fail("No upgradeable buildings were found")
		return

	var start_building_id := upgradeable_ids[0]
	var start_building: Dictionary = buildings.get_building(start_building_id)
	var start_target_level := int(start_building.get("level", 1)) + 1
	var expected_started_duration := float(buildings.get_upgrade_duration_seconds(start_building_id, start_target_level))
	var start_effect: Dictionary = buildings.get_upgrade_level_effect(start_building_id, start_target_level)
	var cost: Dictionary = start_effect.get("cost", {}) if start_effect.get("cost", {}) is Dictionary else {}
	for raw_resource_id in cost.keys():
		var resource_id := str(raw_resource_id)
		resources.debug_add_resource(resource_id, maxi(0, int(cost[raw_resource_id])))
	if not buildings.upgrade_building(start_building_id):
		_fail("Could not start representative building upgrade: %s" % start_building_id)
		return
	var status: Dictionary = buildings.get_upgrade_status(start_building_id)
	if not is_equal_approx(float(status.get("duration_seconds", 0.0)), expected_started_duration):
		_fail("Started upgrade duration differs from the tooltip quote: %s" % start_building_id)
		return

	print("T0425 upgrade duration and tooltip verified")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
