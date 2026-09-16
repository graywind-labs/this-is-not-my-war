extends SceneTree


const GATE_ID := "front_gate"
const WALL_ID := "wall"
const EXPECTED_COSTS := {
	2: {"stone": 3},
	3: {"stone": 4},
	4: {"stone": 5, "wood": 1},
	5: {"stone": 6, "wood": 1},
	6: {"stone": 8, "wood": 2},
}
const EXPECTED_BASE_DURATIONS := {
	2: 3600.0,
	3: 5400.0,
	4: 7200.0,
	5: 9000.0,
	6: 10800.0,
}
const EXPECTED_HP_BY_LEVEL := {
	1: 160,
	2: 185,
	3: 230,
	4: 265,
	5: 320,
	6: 365,
}


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if building_system == null or resource_system == null:
		_fail("Building or resource system unavailable")
		return

	var gate: Dictionary = building_system.get_building(GATE_ID)
	var wall: Dictionary = building_system.get_building(WALL_ID)
	var back_gate: Dictionary = building_system.get_building("back_gate")
	if int(gate.get("level", 0)) != 1 or int((gate.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 6:
		_fail("Front gate is not configured for independent levels 1-6: %s" % JSON.stringify(gate))
		return
	if int(wall.get("level", 0)) != 1 or int((wall.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 6:
		_fail("Wall baseline changed unexpectedly")
		return
	if int((back_gate.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 2:
		_fail("Back gate max level changed unexpectedly")
		return

	for target_level in range(2, 7):
		gate = building_system.get_building(GATE_ID)
		wall = building_system.get_building(WALL_ID)
		var effect: Dictionary = building_system.get_upgrade_level_effect(GATE_ID, target_level)
		if not _cost_matches(effect.get("cost", {}), EXPECTED_COSTS[target_level]):
			_fail("Front gate level %d cost mismatch: %s" % [target_level, JSON.stringify(effect)])
			return
		if not is_equal_approx(float(effect.get("duration_seconds", 0.0)), EXPECTED_BASE_DURATIONS[target_level]):
			_fail("Front gate level %d base duration mismatch: %s" % [target_level, JSON.stringify(effect)])
			return
		for resource_id in ["stone", "wood"]:
			var capacity := int(resource_system.get_resource_capacity(resource_id))
			var current := int(resource_system.get_resource(resource_id))
			if current < capacity:
				resource_system.add_resource(resource_id, capacity - current)
		if not building_system.upgrade_building(GATE_ID):
			_fail("Could not start front gate level %d upgrade" % target_level)
			return
		if int(building_system.get_building(WALL_ID).get("level", 0)) != int(wall.get("level", 0)):
			_fail("Starting a front gate upgrade changed wall level")
			return
		building_system._on_logical_time_tick(1000000.0, 1.0)
		gate = building_system.get_building(GATE_ID)
		if (
			int(gate.get("level", 0)) != target_level
			or int(gate.get("max_hp", 0)) != EXPECTED_HP_BY_LEVEL[target_level]
			or int(gate.get("hp", 0)) != EXPECTED_HP_BY_LEVEL[target_level]
		):
			_fail("Front gate level %d completion mismatch: %s" % [target_level, JSON.stringify(gate)])
			return
		if int(building_system.get_building(WALL_ID).get("level", 0)) != 1:
			_fail("Completing a front gate upgrade changed wall level")
			return

	if building_system.can_upgrade_building(GATE_ID) or building_system.upgrade_building(GATE_ID):
		_fail("Front gate still accepts upgrades above level 6")
		return
	if not building_system.can_upgrade_building(WALL_ID):
		_fail("Independent wall upgrade became unavailable after front gate reached level 6")
		return

	print("T0424 independent front gate levels 1-6 verified")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _cost_matches(actual_value: Variant, expected: Dictionary) -> bool:
	if not actual_value is Dictionary:
		return false
	var actual: Dictionary = actual_value
	if actual.size() != expected.size():
		return false
	for resource_id in expected.keys():
		if not actual.has(resource_id) or int(actual.get(resource_id, -1)) != int(expected[resource_id]):
			return false
	return true
