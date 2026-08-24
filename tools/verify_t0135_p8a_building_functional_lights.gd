extends SceneTree


const ALWAYS_NIGHT := ["main_hall", "warehouse", "wall", "front_gate", "back_gate"]
const CONDITIONAL := [
	"blacksmith", "workshop", "chapel", "clinic", "dining_hall",
	"dormitory", "tavern", "garden", "training_ground", "stable",
]
const EXPECTED_FIXTURES := {
	"main_hall": 2,
	"warehouse": 2,
	"wall": 2,
	"front_gate": 2,
	"back_gate": 2,
	"blacksmith": 4,
	"workshop": 2,
	"chapel": 2,
	"clinic": 2,
	"dining_hall": 2,
	"dormitory": 3,
	"tavern": 2,
	"garden": 4,
	"training_ground": 4,
	"stable": 4,
}


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(16):
		await process_frame
		await physics_frame
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var controller := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView/BuildingFunctionalLightController"
	)
	if controller == null:
		controller = root.get_node_or_null(
			"Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView/CelestialCycleController/BuildingFunctionalLightController"
		)
	if time_system == null or npc_system == null or controller == null:
		_fail("P8A integration nodes are missing")
		return
	time_system.call("set_paused", true)
	for raw_npc_id in npc_system.call("get_npc_ids"):
		npc_system.call("update_npc_state", str(raw_npc_id), {
			"current_location": "plaza",
			"current_location_name": "广场",
			"current_action": "idle",
			"escaped": false,
		})

	_set_time(time_system, 17, 59, 59)
	var before_night := controller.call("get_debug_snapshot") as Dictionary
	if bool(before_night.get("is_night", true)) or int(before_night.get("active_light_count", -1)) != 0:
		_fail("Functional lights must remain off before 18:00: %s" % str(before_night))
		return

	_set_time(time_system, 18, 0, 0)
	var night_empty := controller.call("get_debug_snapshot") as Dictionary
	if not _verify_structure(night_empty):
		return
	if not _expect_lit_set(night_empty, ALWAYS_NIGHT):
		return
	if not await _verify_open_air_level_progression(controller, npc_system):
		return
	for building_id in CONDITIONAL:
		if building_id == "dormitory":
			continue
		npc_system.call("update_npc_state", "blacksmith_01", {
			"current_location": building_id,
			"current_location_name": building_id,
			"current_action": "idle",
		})
		var occupied_snapshot := controller.call("get_debug_snapshot") as Dictionary
		if not _building_lit(occupied_snapshot, building_id) or _occupants(occupied_snapshot, building_id) != 1:
			_fail("Conditional building did not follow authoritative occupancy: %s => %s" % [building_id, _building_state(occupied_snapshot, building_id)])
			return
		npc_system.call("update_npc_state", "blacksmith_01", {
			"current_location": "plaza",
			"current_location_name": "广场",
			"current_action": "idle",
		})

	npc_system.call("update_npc_state", "blacksmith_01", {
		"current_location": "blacksmith",
		"current_location_name": "铁匠铺",
		"current_action": "idle",
	})
	var occupied_smithy := controller.call("get_debug_snapshot") as Dictionary
	if not _building_lit(occupied_smithy, "blacksmith") or _occupants(occupied_smithy, "blacksmith") != 1:
		_fail("Occupied blacksmith did not light at night: %s" % str(_building_state(occupied_smithy, "blacksmith")))
		return
	npc_system.call("update_npc_state", "blacksmith_01", {
		"current_location": "plaza",
		"current_location_name": "广场",
		"current_action": "idle",
	})
	var empty_smithy := controller.call("get_debug_snapshot") as Dictionary
	if _building_lit(empty_smithy, "blacksmith"):
		_fail("Empty blacksmith remained lit at night")
		return

	npc_system.call("update_npc_state", "veteran_deputy_01", {
		"current_location": "dormitory",
		"current_location_name": "宿舍",
		"current_action": "idle",
	})
	var awake_dormitory := controller.call("get_debug_snapshot") as Dictionary
	if not _building_lit(awake_dormitory, "dormitory") or _awake_occupants(awake_dormitory, "dormitory") != 1:
		_fail("Dormitory did not light for an awake occupant")
		return
	npc_system.call("update_npc_state", "veteran_deputy_01", {
		"current_location": "dormitory",
		"current_location_name": "宿舍",
		"current_action": "sleep_in_dormitory",
	})
	var sleeping_dormitory := controller.call("get_debug_snapshot") as Dictionary
	if _building_lit(sleeping_dormitory, "dormitory") or _occupants(sleeping_dormitory, "dormitory") != 1 or _awake_occupants(sleeping_dormitory, "dormitory") != 0:
		_fail("Dormitory did not extinguish after every occupant slept: %s" % str(_building_state(sleeping_dormitory, "dormitory")))
		return

	_set_time(time_system, 5, 59, 59)
	var before_dawn := controller.call("get_debug_snapshot") as Dictionary
	if not bool(before_dawn.get("is_night", false)) or not _building_lit(before_dawn, "main_hall"):
		_fail("Night lighting ended before 06:00")
		return
	_set_time(time_system, 6, 0, 0)
	var dawn := controller.call("get_debug_snapshot") as Dictionary
	if bool(dawn.get("is_night", true)) or int(dawn.get("active_light_count", -1)) != 0:
		_fail("Functional lights did not extinguish at 06:00: %s" % str(dawn))
		return

	print("T0135-P8A building functional light verification passed: %s" % str({
		"configured_buildings": night_empty.get("configured_building_count"),
		"fixtures": night_empty.get("fixture_count"),
		"lights": night_empty.get("light_count"),
		"night_empty_active_buildings": night_empty.get("active_building_ids"),
		"occupied_blacksmith": _building_state(occupied_smithy, "blacksmith"),
		"awake_dormitory": _building_state(awake_dormitory, "dormitory"),
		"sleeping_dormitory": _building_state(sleeping_dormitory, "dormitory"),
	}))
	quit(0)


func _verify_structure(snapshot: Dictionary) -> bool:
	if int(snapshot.get("configured_building_count", 0)) != EXPECTED_FIXTURES.size() or int(snapshot.get("ready_building_count", 0)) != EXPECTED_FIXTURES.size():
		_fail("All fifteen building/gate hosts must be configured and ready: %s" % str(snapshot))
		return false
	if not (snapshot.get("missing_hosts", []) as Array).is_empty() or not (snapshot.get("missing_fixtures", {}) as Dictionary).is_empty():
		_fail("Functional fixture resolution is incomplete: %s" % str(snapshot))
		return false
	if not bool(snapshot.get("time_signal_connected", false)) or not bool(snapshot.get("npc_signal_connected", false)) or not bool(snapshot.get("building_signal_connected", false)) or bool(snapshot.get("maintains_second_clock", true)):
		_fail("Functional lighting is not connected as a read-only consumer")
		return false
	var states := snapshot.get("building_states", {}) as Dictionary
	var expected_total := 0
	for building_id in EXPECTED_FIXTURES:
		var state := states.get(building_id, {}) as Dictionary
		var expected_count := int(EXPECTED_FIXTURES[building_id])
		expected_total += expected_count
		if int(state.get("fixture_count", 0)) != expected_count or int(state.get("emitter_count", 0)) != expected_count:
			_fail("Unexpected fixture/emitter count for %s: %s; matching_names=%s" % [building_id, state, _matching_runtime_names(building_id)])
			return false
		if not str(state.get("host_path", "")).contains("/FormalStationLayout/"):
			_fail("Functional light bound outside formal layout for %s: %s" % [building_id, state])
			return false
		if not bool(state.get("all_shadowed", false)) or not bool(state.get("fog_energy_zero", false)) or not bool(state.get("distance_fade_disabled", false)):
			_fail("Functional light lacks contained shadow/fog settings for %s: %s" % [building_id, state])
			return false
		if building_id in ["garden", "training_ground", "stable"]:
			if float(state.get("designed_energy_total", 0.0)) < 11.1 or float(state.get("maximum_range", 0.0)) < 9.1:
				_fail("Open-air work site lighting is below the P8AR readability floor for %s: %s" % [building_id, state])
				return false
			for fixture in _fixtures_named_for(building_id):
				if not bool(fixture.get_meta("mounted_to_structure", false)):
					_fail("Open-air lantern is not mounted to a modeled support: %s" % fixture.get_path())
					return false
	for building_id in ["main_hall", "tavern"]:
		for fixture in _fixtures_named_for(building_id):
			if not bool(fixture.get_meta("mounted_to_structure", false)):
				_fail("Wall lantern is missing a modeled mount: %s" % fixture.get_path())
				return false
	if int(snapshot.get("fixture_count", 0)) != expected_total or int(snapshot.get("emitter_count", 0)) != expected_total:
		_fail("Functional fixture totals drifted: %s" % str(snapshot))
		return false
	for node in _all_descendants(root):
		if not (node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is NavigationLink3D or node is Area3D):
			continue
		if _has_functional_light_ancestor(node):
			_fail("Functional lighting introduced gameplay geometry: %s" % node.get_path())
			return false
	return true


func _verify_open_air_level_progression(controller: Node, npc_system: Node) -> bool:
	for building_id in ["garden", "training_ground", "stable"]:
		var host := _formal_art_host(building_id)
		if host == null or not host.has_method("debug_force_visual_level"):
			_fail("Missing formal open-air art host for level-light verification: %s" % building_id)
			return false
		npc_system.call("update_npc_state", "blacksmith_01", {
			"current_location": building_id,
			"current_location_name": building_id,
			"current_action": "idle",
		})
		for level in [1, 2, 3]:
			host.call("debug_force_visual_level", level)
			await process_frame
			var snapshot := controller.call("debug_force_refresh") as Dictionary
			var state := _building_state(snapshot, building_id)
			var expected_count: int = int(level) + 1
			if int(state.get("unlocked_fixture_count", -1)) != expected_count or int(state.get("active_light_count", -1)) != expected_count:
				_fail("Open-air lights did not progress 2/3/4 with level for %s Lv.%d: %s" % [building_id, level, state])
				return false
			if _visible_fixture_count(building_id) != expected_count:
				_fail("Open-air modeled fixtures did not match active lights for %s Lv.%d" % [building_id, level])
				return false
		var required_counts := _building_state(controller.call("get_debug_snapshot") as Dictionary, building_id).get("required_level_counts", {}) as Dictionary
		if int(required_counts.get(1, 0)) != 2 or int(required_counts.get(2, 0)) != 1 or int(required_counts.get(3, 0)) != 1:
			_fail("Open-air light level metadata drifted for %s: %s" % [building_id, required_counts])
			return false
		npc_system.call("update_npc_state", "blacksmith_01", {
			"current_location": "plaza",
			"current_location_name": "广场",
			"current_action": "idle",
		})
	return true


func _expect_lit_set(snapshot: Dictionary, expected: Array) -> bool:
	var expected_ids: Array[String] = []
	for raw_id in expected:
		expected_ids.append(str(raw_id))
	expected_ids.sort()
	var actual_ids: Array[String] = []
	for raw_id in snapshot.get("active_building_ids", []):
		actual_ids.append(str(raw_id))
	actual_ids.sort()
	if actual_ids != expected_ids:
		_fail("Unexpected empty-night lit buildings: expected=%s actual=%s" % [expected_ids, actual_ids])
		return false
	for building_id in CONDITIONAL:
		if _building_lit(snapshot, building_id):
			_fail("Empty conditional building was lit: %s" % building_id)
			return false
	return true


func _set_time(time_system: Node, hour: int, minute: int, second: int) -> void:
	time_system.call("set_current_time", 3, hour, minute, second)


func _building_state(snapshot: Dictionary, building_id: String) -> Dictionary:
	return ((snapshot.get("building_states", {}) as Dictionary).get(building_id, {}) as Dictionary)


func _building_lit(snapshot: Dictionary, building_id: String) -> bool:
	return bool(_building_state(snapshot, building_id).get("lit", false))


func _occupants(snapshot: Dictionary, building_id: String) -> int:
	return int(_building_state(snapshot, building_id).get("occupant_count", 0))


func _awake_occupants(snapshot: Dictionary, building_id: String) -> int:
	return int(_building_state(snapshot, building_id).get("awake_occupant_count", 0))


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children(true):
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _matching_runtime_names(building_id: String) -> Array[String]:
	var result: Array[String] = []
	for node in _all_descendants(root):
		if str(node.name).to_lower().contains("lantern") or str(node.name).to_lower().contains(building_id.to_lower()):
			result.append("%s :: %s" % [node.name, node.get_path()])
	return result


func _fixtures_named_for(building_id: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var expected_names: Array[String] = []
	match building_id:
		"garden":
			expected_names.assign(["GardenLanternWestRear", "GardenLanternEastRear", "GardenLanternWestFront", "GardenLanternEastFront"])
		"training_ground":
			expected_names.assign(["TrainingLanternWestRear", "TrainingLanternEastRear", "TrainingLanternWestFront", "TrainingLanternEastFront"])
		"stable":
			expected_names.assign(["StableLanternWestRear", "StableLanternEastRear", "StableLanternWestFront", "StableLanternEastFront"])
		"main_hall":
			expected_names.assign(["GateLanternWest", "GateLanternEast"])
		"tavern":
			expected_names.assign(["CellarLanternWest", "CellarLanternEast"])
	for node in _all_descendants(root):
		if node is Node3D and str(node.name) in expected_names:
			result.append(node as Node3D)
	if result.size() != expected_names.size():
		_fail("Could not resolve every authored fixture for %s: expected=%s actual=%s" % [building_id, expected_names, result.size()])
	return result


func _formal_art_host(building_id: String) -> Node3D:
	for raw_view in get_nodes_in_group("building_art_view"):
		var view := raw_view as Node3D
		if view != null and str(view.get("building_id")) == building_id and str(view.get_path()).contains("/FormalStationLayout/"):
			return view
	return null


func _visible_fixture_count(building_id: String) -> int:
	var count := 0
	for fixture in _fixtures_named_for(building_id):
		if fixture.is_visible_in_tree():
			count += 1
	return count


func _has_functional_light_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if bool(current.get_meta("functional_light_fixture", false)) or bool(current.get_meta("functional_light_emitter", false)) or str(current.name).begins_with("FunctionalLights_"):
			return true
		current = current.get_parent()
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
