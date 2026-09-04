extends SceneTree


const NPC_ID := "cook_01"
const BUILDING_ID := "dining_hall"
const ACTION_ID := "work_dining_hall"
const STATION_IDS := [
	"dining_kitchen_station_01",
	"dining_kitchen_station_02",
	"dining_kitchen_station_03"
]
const CHIMNEY_NAMES := [
	"WestKitchenChimney",
	"CenterKitchenChimney",
	"EastThirdKitchenChimney"
]

var _failed := false


func _init() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(10):
		await process_frame
		await physics_frame
	var hall := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall") as Node3D
	var art := hall.get_node_or_null("DiningHallArt") as Node3D if hall != null else null
	var fx := art.get_node_or_null("KitchenWorkFX") if art != null else null
	var fixture_visuals := hall.get_node_or_null("FixtureLayout/Visuals") if hall != null else null
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var bruno := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01") as CharacterBody3D
	if [hall, art, fx, fixture_visuals, action_system, npc_system, building_system, resource_system, time_system, bruno].has(null):
		_fail("P8AR4 dining kitchen runtime hierarchy is incomplete")
		return
	if not _verify_structure(art, fx, fixture_visuals):
		return
	if not await _verify_real_work(fx, action_system, npc_system, building_system, resource_system, time_system, bruno):
		return
	print("T0135-P8AR4 dining kitchen work FX verification passed")
	quit(0)


func _verify_structure(art: Node3D, fx: Node, fixture_visuals: Node) -> bool:
	var idle := fx.call("debug_force_refresh") as Dictionary
	if (
		int(idle.get("active_station_count", -1)) != 0
		or not bool(idle.get("building_signal_connected", false))
		or not bool(idle.get("npc_signal_connected", false))
		or bool(idle.get("meal_authority", true))
		or str(idle.get("activation_contract", "")) != "occupied_dining_kitchen_station_and_work_dining_hall"
	):
		return _fail_bool("Idle dining work observer contract is invalid: %s" % idle)
	var station_snapshots := idle.get("stations", {}) as Dictionary
	if station_snapshots.size() != 3:
		return _fail_bool("Dining hall must expose exactly three independent kitchen FX stations")
	for index in range(STATION_IDS.size()):
		var workstation_id: String = str(STATION_IDS[index])
		var station := fx.get_node_or_null("Station%02d" % (index + 1)) as Node3D
		var state := station_snapshots.get(workstation_id, {}) as Dictionary
		if station == null or state.is_empty():
			return _fail_bool("Kitchen FX station is missing: %s" % workstation_id)
		if (
			bool(state.get("active", true))
			or bool(state.get("fire_visible", true))
			or bool(state.get("food_visible", true))
			or bool(state.get("steam_emitting", true))
			or bool(state.get("chimney_smoke_emitting", true))
			or float(state.get("fire_light_energy", -1.0)) > 0.001
		):
			return _fail_bool("Idle kitchen station still emits work-only visuals: %s" % state)
		if str(state.get("chimney_name", "")) != CHIMNEY_NAMES[index]:
			return _fail_bool("Kitchen station/chimney pairing drifted: %s" % workstation_id)
		if int(state.get("required_level", 0)) != (3 if index == 2 else 1):
			return _fail_bool("Kitchen FX required level drifted: %s" % workstation_id)
		if station.get_node_or_null("FireVisuals/FlameCore") == null or station.get_node_or_null("FoodVisuals/StewSurface") == null:
			return _fail_bool("Kitchen station lacks modeled fire or stew: %s" % workstation_id)
		var food_visuals := station.get_node_or_null("FoodVisuals") as Node3D
		if food_visuals == null or food_visuals.get_child_count() < 5:
			return _fail_bool("Kitchen stew lacks readable multi-color ingredients: %s" % workstation_id)
		if absf(food_visuals.position.y + 0.18) > 0.001:
			return _fail_bool("Kitchen food visuals are no longer lowered inside the cauldron: %s / %s" % [workstation_id, food_visuals.position])
		var smoke := station.get_node_or_null("ChimneySmoke") as GPUParticles3D
		if smoke == null or absf(smoke.position.z + 0.82) > 0.01 or absf(smoke.position.y - 6.55) > 0.01:
			return _fail_bool("Kitchen chimney smoke outlet is not aligned with its flue: %s" % workstation_id)
		var chimney := _find_descendant_named(art, CHIMNEY_NAMES[index]) as Node3D
		if chimney == null or Vector2(chimney.position.x, chimney.position.z).distance_to(Vector2(station.position.x, station.position.z + smoke.position.z)) > 0.02:
			return _fail_bool("Kitchen station does not map one-to-one to a physical chimney: %s" % workstation_id)
		if (
			not bool(chimney.get_meta("hollow_flue", false))
			or chimney.get_node_or_null("OpenFlue") != null
			or not _chimney_center_is_open(chimney)
		):
			return _fail_bool("Kitchen chimney center is still modeled as a solid cap: %s" % CHIMNEY_NAMES[index])
		var fixture := _find_by_meta(fixture_visuals, "workstation_id", workstation_id) as Node3D
		var ember := fixture.get_node_or_null("Ember") as Node3D if fixture != null else null
		if ember == null or ember.visible or not bool(ember.get_meta("dining_work_heat", false)):
			return _fail_bool("Kitchen hearth ember is not a dormant per-station work visual: %s" % workstation_id)
	return true


func _verify_real_work(
	fx: Node,
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	resource_system: Node,
	time_system: Node,
	bruno: CharacterBody3D
) -> bool:
	time_system.call("set_paused", false)
	bruno.set("move_speed", 40.0)
	resource_system.call("add_resource", "grain", 10)
	npc_system.call("update_npc_state", NPC_ID, {"fatigue": 0, "satiety": 100, "current_action": "idle"})
	if not bool(action_system.call("debug_assign_work", NPC_ID, BUILDING_ID)):
		return _fail_bool("Real Bruno cooking action did not dispatch")
	for frame in range(1800):
		await physics_frame
		var runtime := action_system.call("get_runtime_action_snapshot", NPC_ID) as Dictionary
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
			break
		if frame == 1799:
			return _fail_bool("Bruno did not physically reach the first kitchen station")
	for _frame in range(4):
		await process_frame
	var active := fx.call("debug_force_refresh") as Dictionary
	var station_states := active.get("stations", {}) as Dictionary
	if int(active.get("active_station_count", 0)) != 1 or not (active.get("active_workstation_ids", []) as Array).has(STATION_IDS[0]):
		return _fail_bool("Real cooking did not activate exactly the occupied stove: %s" % active)
	for index in range(STATION_IDS.size()):
		var state := station_states.get(STATION_IDS[index], {}) as Dictionary
		var expected_active := index == 0
		if (
			bool(state.get("active", false)) != expected_active
			or bool(state.get("fire_visible", false)) != expected_active
			or bool(state.get("food_visible", false)) != expected_active
			or bool(state.get("steam_emitting", false)) != expected_active
			or bool(state.get("chimney_smoke_emitting", false)) != expected_active
			or (float(state.get("fire_light_energy", 0.0)) > 0.1) != expected_active
		):
			return _fail_bool("Kitchen station effects did not remain independent: %s" % state)
	if not bool(action_system.call("interrupt_npc_action", NPC_ID, "verify_p8ar4_cooking_stop", true)):
		return _fail_bool("Could not interrupt real dining work")
	for _frame in range(5):
		await process_frame
	var stopped := fx.call("debug_force_refresh") as Dictionary
	if int(stopped.get("active_station_count", -1)) != 0:
		return _fail_bool("Kitchen effects remained active after authoritative cooking stopped: %s" % stopped)
	for state_variant in (stopped.get("stations", {}) as Dictionary).values():
		var state := state_variant as Dictionary
		if bool(state.get("fire_visible", true)) or bool(state.get("food_visible", true)) or bool(state.get("steam_emitting", true)) or bool(state.get("chimney_smoke_emitting", true)):
			return _fail_bool("A kitchen station retained effects after interruption: %s" % state)
	if not _workstation_clear(building_system, STATION_IDS[0]):
		return _fail_bool("Cooking interruption left the first stove occupied")
	return true


func _find_by_meta(parent: Node, key: String, value: String) -> Node:
	if parent == null:
		return null
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			return child
	return null


func _find_descendant_named(parent: Node, node_name: String) -> Node:
	if parent == null:
		return null
	for raw_match in parent.find_children(node_name, "Node", true, false):
		return raw_match
	return null


func _chimney_center_is_open(chimney: Node3D) -> bool:
	for required_part in [
		"StoneShaftWestWall", "StoneShaftEastWall", "StoneShaftNorthWall", "StoneShaftSouthWall",
		"BrickCrownWestWall", "BrickCrownEastWall", "BrickCrownNorthWall", "BrickCrownSouthWall"
	]:
		if chimney.get_node_or_null(required_part) == null:
			return false
	var center_probe := Vector3(0.0, 6.15, 0.0)
	for raw_mesh in chimney.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_probe := mesh_instance.to_local(chimney.to_global(center_probe))
		if mesh_instance.mesh.get_aabb().has_point(local_probe):
			return false
	return true


func _workstation_clear(building_system: Node, workstation_id: String) -> bool:
	for raw_workstation in (building_system.call("get_building", BUILDING_ID) as Dictionary).get("workstations", []):
		var workstation := raw_workstation as Dictionary
		if str(workstation.get("id", "")) != workstation_id:
			continue
		return _clean_id(workstation.get("occupied_by", "")).is_empty() and _clean_id(workstation.get("reserved_by", "")).is_empty()
	return false


func _clean_id(value: Variant) -> String:
	if value == null:
		return ""
	var result := str(value)
	return "" if result in ["", "<null>", "null"] else result


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
